import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart'
    show MahnPosten;

/// Daten der Mahnlauf-Seite (v0.134.0, Spec
/// docs/superpowers/specs/2026-09-23-mahnwesen-design.md, Abschnitte 3–4).
///
/// WARUM die Aufbereitung rein ist ([baueMahnlauf]): Hier wird entschieden,
/// welche Betriebe Daniel überhaupt zum Mahnen angeboten bekommt. Oberstes
/// Ziel: NIE eine bezahlte Rechnung mahnen (Daniel 23.09.2026). Jede
/// Sicherung (Bankauszug aktuell und lückenlos, ungeklärte Gutschrift,
/// gebuchter Zahlungseingang) muss ohne Datenbank prüfbar sein.

/// Stammdaten eines Betriebs, soweit der Mahnlauf sie braucht.
typedef MahnBetriebStamm = ({
  String name,
  String? ort,
  List<String> aliase,
  String? raMail,
  String? betriebMail,
});

/// Offene Bankgutschrift aus der camt-Prüfliste — mit Datum, damit der
/// Sperrgrund sagen kann, WELCHE Zahlung ungeklärt ist.
typedef MahnlaufGutschrift = ({String? partei, double betrag, DateTime datum});

class MahnBetrieb {
  final String betriebId;

  /// «Name, Ort» — gleichnamige Betriebe (Daniel 23.09.2026).
  final String anzeige;

  /// Mahnfällige Rechnungen mit ihrer fälligen Stufe.
  final List<MahnPosten> faellig;

  /// null = frei; sonst der Grund, der auf der Karte steht.
  final String? sperrgrund;

  /// Offene Rechnungen des Betriebs im Mahnbereich (ohne solche mit
  /// gebuchter Zahlung) — entscheidet über die Kontoauszug-Beilage.
  final List<Rechnung> offeneImMahnbereich;

  /// Alle Rechnungen des Betriebs mit Rechnungsdatum im laufenden Jahr,
  /// INKLUSIVE bezahlter — Inhalt des Kontoauszugs.
  final List<Rechnung> rechnungenDesJahres;

  /// Jüngster vermerkter Zahlungseingang des Betriebs (Vorschau, Sicherung 4).
  final ({DateTime datum, double betrag})? letzteZahlung;

  /// Kanal der höchsten fälligen Stufe (Karte, Spec Abschnitt 4) — gleiche
  /// Regel wie Vorschau und Versand (`mahnKanal`).
  final MahnKanal kanal;

  MahnBetrieb({
    required this.betriebId,
    required this.anzeige,
    required this.faellig,
    required this.sperrgrund,
    required this.offeneImMahnbereich,
    required this.rechnungenDesJahres,
    required this.letzteZahlung,
    required this.kanal,
  });

  bool get gesperrt => sperrgrund != null;
  double get summeFaellig =>
      faellig.fold(0.0, (s, p) => s + p.rechnung.betragBrutto);
  MahnStufe get hoechste => hoechsteStufe(faellig.map((p) => p.stufe));
  DateTime get aeltestesDatum => faellig
      .map((p) => p.rechnung.rechnungsdatum)
      .reduce((a, b) => a.isBefore(b) ? a : b);
}

class MahnlaufDaten {
  final DateTime? letzterAuszug;
  final bool bankGesperrt;

  /// Text der roten Bankkarte (null, wenn frei).
  final String? bankSperrgrund;

  /// Betriebe mit Fälligem, sortiert: höchste Stufe, dann ältestes Datum.
  final List<MahnBetrieb> betriebe;

  /// Gemahnt, nächste Stufe noch nicht fällig (Frist läuft).
  final List<Rechnung> inFrist;

  /// Im Mahnbereich, aber ohne Zustellnachweis — wird nie gemahnt.
  final List<Rechnung> erstZustellen;

  /// Zahlungseingang gebucht, Status aber noch offen/gemahnt — Status prüfen.
  final List<Rechnung> zahlungGebucht;

  /// Hinweis ohne Sperre, z. B. «Saldo einer Auszugsdatei fehlt —
  /// Vollständigkeit ungeprüft» (gelb auf der Bankkarte).
  final String? auszugHinweis;

  /// Nur bei gesperrter Bank: So viele Betriebe WÄREN fällig (gemessen am
  /// letzten Auszug bzw. heute). Für die Aufgabe «zuerst Bankauszug
  /// einlesen» — ohne sie bliebe die Glocke bei altem Auszug einfach still.
  final int betriebeHinterBanksperre;

  MahnlaufDaten({
    required this.letzterAuszug,
    required this.bankGesperrt,
    required this.bankSperrgrund,
    required this.betriebe,
    required this.inFrist,
    required this.erstZustellen,
    required this.zahlungGebucht,
    this.betriebeHinterBanksperre = 0,
    this.auszugHinweis,
  });
}

String _datum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

const _gemahnt = {'erinnert', 'mahnung_1', 'mahnung_2'};

MahnlaufDaten baueMahnlauf({
  required List<Rechnung> rechnungen,
  required Map<String, MahnBetriebStamm> betriebe,
  required List<MahnlaufGutschrift> gutschriften,
  required DateTime? letzterAuszug,
  required DateTime heute,
  AuszugKettenBefund auszugKette = (status: AuszugKette.ok, text: null),
  Set<String> mitGebuchterZahlung = const {},
}) {
  final luecke = auszugKette.status == AuszugKette.luecke;
  final gesperrt = bankSperre(letzterAuszug, heute: heute, auszugLuecke: luecke);
  final String? bankGrund;
  if (letzterAuszug == null) {
    bankGrund = 'Noch kein Bankauszug eingelesen — zuerst den aktuellen Auszug einlesen';
  } else if (luecke) {
    bankGrund = 'Lücke zwischen den Bankauszügen — zuerst fehlenden Auszug '
        'einlesen (${auszugKette.text})';
  } else if (gesperrt) {
    bankGrund = 'Bankauszug bis ${_datum(letzterAuszug)} — zuerst den '
        'aktuellen Auszug einlesen';
  } else {
    bankGrund = null;
  }

  final imBereich = rechnungen.where(imMahnbereich).toList();
  final zahlungGebucht =
      imBereich.where((r) => mitGebuchterZahlung.contains(r.id)).toList();
  // Ab hier nur noch Rechnungen OHNE gebuchten Zahlungseingang: Eine
  // gebuchte Zahlung heisst «bezahlt, Status hinkt nach» — genau der Fall,
  // der nie gemahnt werden darf (Review 23.09.2026).
  final kandidaten =
      imBereich.where((r) => !mitGebuchterZahlung.contains(r.id)).toList();

  final erstZustellen = kandidaten.where((r) => !istZugestellt(r)).toList();

  final faelligJeBetrieb = <String, List<MahnPosten>>{};
  final faelligeIds = <String>{};
  if (!gesperrt) {
    for (final r in kandidaten) {
      final stufe = faelligeStufe(r, stichtag: letzterAuszug!);
      if (stufe == null) continue;
      faelligeIds.add(r.id);
      (faelligJeBetrieb[r.betriebId ?? ''] ??= []).add((rechnung: r, stufe: stufe));
    }
  }

  // Bei gesperrter Bank trotzdem zählen, was fällig WÄRE — nur für den
  // Hinweis in der Glocke, nie für eine Karte.
  final hinterSperre = !gesperrt
      ? 0
      : {
          for (final r in kandidaten)
            if (faelligeStufe(r, stichtag: letzterAuszug ?? heute) != null) r.betriebId,
        }.length;

  final inFrist = kandidaten
      .where((r) =>
          _gemahnt.contains(r.zahlungsstatus) &&
          istZugestellt(r) &&
          !faelligeIds.contains(r.id))
      .toList();

  final gs = [for (final g in gutschriften) (partei: g.partei, betrag: g.betrag)];

  final karten = <MahnBetrieb>[];
  for (final e in faelligJeBetrieb.entries) {
    final id = e.key;
    final stamm = betriebe[id];
    final offene = kandidaten.where((r) => r.betriebId == id).toList();
    String? grund;
    if (stamm == null) {
      grund = 'Betrieb nicht gefunden — Rechnung prüfen';
    } else {
      final t = passendeGutschrift(
        betriebName: stamm.name,
        aliase: stamm.aliase,
        offeneBetraege: offene.map((r) => r.betragBrutto).toList(),
        gutschriften: gs,
      );
      if (t != null) {
        if (t.rueckfall) {
          grund = 'viele offene Rechnungen und eine ungeklärte Zahlung — '
              'zuerst Prüfliste klären';
        } else {
          final g = gutschriften[t.index];
          final zahler = (g.partei ?? '').trim().isEmpty ? 'unbekannter Zahler' : g.partei!.trim();
          grund = 'Zahlung ungeklärt: $zahler · CHF ${g.betrag.toStringAsFixed(2)} · '
              '${_datum(g.datum)} — zuerst in der Bankauszug-Prüfliste zuordnen';
        }
      }
    }

    final desBetriebs = rechnungen.where((r) => r.betriebId == id);
    ({DateTime datum, double betrag})? letzte;
    for (final r in desBetriebs) {
      final am = r.zahlungEingegangenAm;
      if (am == null) continue;
      if (letzte == null || am.isAfter(letzte.datum)) {
        letzte = (datum: am, betrag: r.zahlungBetrag ?? r.betragBrutto);
      }
    }

    final posten = e.value
      ..sort((a, b) => a.rechnung.rechnungsdatum.compareTo(b.rechnung.rechnungsdatum));
    karten.add(MahnBetrieb(
      betriebId: id,
      anzeige: stamm == null ? 'Unbekannter Betrieb' : betriebMitOrt(stamm.name, stamm.ort),
      faellig: posten,
      sperrgrund: grund,
      offeneImMahnbereich: offene,
      rechnungenDesJahres: desBetriebs
          .where((r) =>
              r.rechnungstyp != 'heineken_monat' && r.rechnungsdatum.year == heute.year)
          .toList(),
      letzteZahlung: letzte,
      kanal: mahnKanal(
        raMail: stamm?.raMail,
        betriebMail: stamm?.betriebMail,
        stufe: hoechsteStufe(posten.map((p) => p.stufe)),
      ),
    ));
  }
  karten.sort((a, b) {
    final s = b.hoechste.index.compareTo(a.hoechste.index);
    return s != 0 ? s : a.aeltestesDatum.compareTo(b.aeltestesDatum);
  });

  return MahnlaufDaten(
    letzterAuszug: letzterAuszug,
    bankGesperrt: gesperrt,
    bankSperrgrund: bankGrund,
    betriebe: karten,
    inFrist: inFrist,
    erstZustellen: erstZustellen,
    zahlungGebucht: zahlungGebucht,
    betriebeHinterBanksperre: hinterSperre,
    auszugHinweis:
        auszugKette.status == AuszugKette.ungeprueft ? auszugKette.text : null,
  );
}

/// Einzelmahnung aus der Rechnung (`?rechnung=<id>`): nur der Betrieb dieser
/// Rechnung — und nur, wenn sie selbst fällig ist. Alle Sicherungen sind
/// schon in [daten] eingerechnet (Bank, Gutschrift, gebuchte Zahlung); die
/// Einzelmahnung ist bewusst KEIN Umweg daran vorbei.
MahnlaufDaten fuerEinzelmahnung(MahnlaufDaten daten, String rechnungId) {
  final karte = daten.betriebe
      .where((b) => b.faellig.any((p) => p.rechnung.id == rechnungId))
      .toList();
  bool betrifft(Rechnung r) => r.id == rechnungId;
  return MahnlaufDaten(
    letzterAuszug: daten.letzterAuszug,
    bankGesperrt: daten.bankGesperrt,
    bankSperrgrund: daten.bankSperrgrund,
    betriebe: karte,
    inFrist: daten.inFrist.where(betrifft).toList(),
    erstZustellen: daten.erstZustellen.where(betrifft).toList(),
    zahlungGebucht: daten.zahlungGebucht.where(betrifft).toList(),
    auszugHinweis: daten.auszugHinweis,
  );
}


/// Prüft direkt vor dem Erstellen, ob die Vorschau noch stimmt
/// (Review 23.09.2026, I-1). [frisch] ist frisch aus der Datenbank gebaut —
/// damit sind auch Kontoauszug-Inhalt, offene Rechnungen und die Gutschrift-
/// Sperre neu. Liefert die frische Karte samt Posten in derselben Stufe,
/// oder eine Meldung, wenn sich IRGENDETWAS geändert hat: Bank gesperrt,
/// Betrieb gesperrt, eine gewählte Rechnung nicht mehr fällig oder in
/// einer anderen Stufe. Im Zweifel wird nichts erstellt.
({MahnBetrieb? karte, List<MahnPosten> posten, String? fehler}) pruefeVorErstellen({
  required MahnlaufDaten frisch,
  required String betriebId,
  required List<MahnPosten> gewaehlt,
}) {
  const geaendert = 'Daten haben sich geändert — bitte neu prüfen';
  ({MahnBetrieb? karte, List<MahnPosten> posten, String? fehler}) nein(String grund) =>
      (karte: null, posten: const <MahnPosten>[], fehler: '$geaendert ($grund).');

  if (frisch.bankGesperrt) return nein('Bankauszug');
  final karte = frisch.betriebe.where((k) => k.betriebId == betriebId).firstOrNull;
  if (karte == null) return nein('nichts mehr fällig');
  if (karte.gesperrt) return nein(karte.sperrgrund!);
  final posten = <MahnPosten>[];
  for (final g in gewaehlt) {
    final f = karte.faellig.where((p) => p.rechnung.id == g.rechnung.id).firstOrNull;
    if (f == null || f.stufe != g.stufe) {
      return nein('${g.rechnung.rechnungsnummer ?? 'Rechnung'} nicht mehr als '
          '${g.stufe.titel} fällig');
    }
    posten.add(f);
  }
  return (karte: karte, posten: posten, fehler: null);
}

/// Rechnungs-Ids, auf die ein Zahlungseingang gebucht ist: Haben 1100 mit
/// `beleg_id` = Rechnung, nicht storniert — dieselbe Quelle wie die
/// Abschlussprüfung («Status offen trotz Zahlung», `abschlussPruefungProvider`).
///
/// Anders als dort genügt hier JEDE gebuchte Zahlung, auch eine Teilzahlung:
/// Die Abschlussprüfung sucht falsche Status, der Mahnlauf darf im Zweifel
/// nicht mahnen — eine Mahnung über den vollen Betrag nach einer
/// Teilzahlung wäre ebenso falsch.
Set<String> rechnungenMitGebuchterZahlung(Iterable<Buchung> buchungen) => {
      for (final b in buchungen)
        if (b.habenKonto == 1100 &&
            b.belegId != null &&
            zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId))
          b.belegId!,
    };

/// Alles für die Mahnlauf-Seite, die Kundenliste und die Glocke.
///
/// WARUM alles direkt aus der Datenbank statt über die geteilten Provider
/// (Review 23.09.2026, I-3): Die Seite lädt vor dem Erstellen neu
/// (`ref.invalidate(mahnlaufProvider)`). Hinge sie an `camtPrueflisteProvider`
/// oder `rechnungenStreamProvider`, müsste sie diese mit invalidieren — und
/// die Glocke rechnete jedes Mal alle anderen Detektoren mit. So trifft ein
/// Neuladen nur diesen Provider. Die Rechnungsquelle ist dabei schlank:
/// nur Kunden-/Jahresrechnungen ab dem Mahnstart statt aller seit 2019.
/// `autoDispose`: beim nächsten Öffnen frisch (neu eingelesene Auszüge).
final mahnlaufProvider = FutureProvider.autoDispose<MahnlaufDaten>((ref) async {
  final (rechnungen, buchungen, pruefliste, dateien) = await (
    RechnungRepository.getKundenrechnungenAb(kMahnStart),
    // Gezielt nur die Zahlungseingänge seit dem Mahnstart, nicht das ganze
    // Journal.
    BuchungRepository.getZahlungseingaengeAb(kMahnStart),
    CamtPrueflisteRepository.getOffen(),
    CamtDateiRepository.getAll(),
  ).wait;
  // Erst warten, bis die Betriebe geladen sind — sonst stünde jede Karte
  // kurz als «Betrieb nicht gefunden» gesperrt da.
  await ref.watch(betriebeStreamProvider.future);
  final betriebe = ref.watch(betriebeProvider);

  // Mailadressen der Rechnungsadressen nur für Betriebe mit offenen
  // Rechnungen im Mahnbereich — für den Kanal auf der Karte.
  final offeneBetriebe = {
    for (final r in rechnungen)
      if (imMahnbereich(r) && r.betriebId != null) r.betriebId!,
  };
  final raMails =
      await BetriebRechnungsadresseRepository.getMailadressen(offeneBetriebe.toList());

  DateTime? letzter;
  for (final d in dateien) {
    final bis = d.zeitraumBis;
    if (bis != null && (letzter == null || bis.isAfter(letzter))) letzter = bis;
  }

  return baueMahnlauf(
    rechnungen: rechnungen,
    betriebe: {
      for (final b in betriebe)
        if (b.serverId != null)
          b.serverId!: (
            name: b.name,
            ort: b.ort,
            aliase: b.zahlerAliase,
            raMail: raMails[b.serverId!],
            betriebMail: b.email,
          ),
    },
    // Die Prüfliste liefert nur Einträge mit Status «offen»
    // (`CamtPrueflisteRepository.getOffen`) — hier nur noch Gutschriften.
    gutschriften: [
      for (final e in pruefliste)
        if (e.istGutschrift)
          (partei: e.parteiName, betrag: e.betrag, datum: e.bookingDatum),
    ],
    letzterAuszug: letzter,
    auszugKette: pruefeAuszugKette([
      for (final d in dateien)
        if (d.zeitraumVon != null && d.zeitraumBis != null)
          (
            von: d.zeitraumVon!,
            bis: d.zeitraumBis!,
            anfangssaldo: d.anfangssaldo,
            schlusssaldo: d.schlusssaldo,
          ),
    ]),
    mitGebuchterZahlung: rechnungenMitGebuchterZahlung(buchungen),
    heute: DateTime.now(),
  );
});
