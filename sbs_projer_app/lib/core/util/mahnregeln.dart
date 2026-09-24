/// Die Regeln des Mahnwesens (v0.134.0) — rein, ohne I/O.
///
/// WARUM rein: Hier entscheidet sich, ob ein Kunde gemahnt wird. Der Fehler,
/// den es um jeden Preis zu vermeiden gilt, ist eine Mahnung für Bezahltes
/// (Daniel 23.09.2026). Das muss ohne Datenbank und Widget prüfbar sein.
/// Spec: docs/superpowers/specs/2026-09-23-mahnwesen-design.md
library;

import 'package:sbs_projer_app/core/util/bank_waechter.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Rechnungen davor sind Altlast (jahrgangsweise Abschreibung, Entscheid
/// 19.09.2026) und kommen nie ins Mahnsystem.
final kMahnStart = DateTime.utc(2026, 1, 1);

/// Zahlungserinnerung frühestens so viele Tage nach Fälligkeit.
const kErinnerungNachTagen = 10;

/// Nächste Stufe frühestens so viele Tage nach Ablauf der gesetzten Frist.
const kNaechsteStufeNachFrist = 5;

/// Frist im Mahnschreiben.
const kMahnFristTage = 10;

/// Der Mahnlauf ist gesperrt, wenn der letzte Bankauszug älter ist.
const kAuszugHoechstensAltTage = 2;

/// Eine Stufe ist erst fällig, wenn ihre Bedingung so viele Tage VOR dem
/// Auszug-Stichtag erfüllt war — eine Zahlung vom letzten Fristtag steht
/// sicher im Auszug.
const kPufferVorStichtagTage = 3;

enum MahnStufe { erinnerung, mahnung1, letzte }

extension MahnStufeX on MahnStufe {
  int get wert => index;

  /// Wert von `rechnungen.zahlungsstatus` nach dieser Stufe.
  String get status => switch (this) {
        MahnStufe.erinnerung => 'erinnert',
        MahnStufe.mahnung1 => 'mahnung_1',
        MahnStufe.letzte => 'mahnung_2',
      };

  String get titel => switch (this) {
        MahnStufe.erinnerung => 'Zahlungserinnerung',
        MahnStufe.mahnung1 => '1. Mahnung',
        MahnStufe.letzte => 'Letzte Mahnung',
      };
}

DateTime _tag(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _plus(DateTime d, int tage) => _tag(d).add(Duration(days: tage));

bool imMahnbereich(Rechnung r) =>
    (r.rechnungstyp == 'kundenrechnung' || r.rechnungstyp == 'jahresrechnung') &&
    !_tag(r.rechnungsdatum).isBefore(kMahnStart) &&
    r.zahlungsstatus != 'bezahlt' &&
    r.zahlungsstatus != 'abgeschrieben' &&
    // I-3 (Review 23.09.2026): Ein bereits vermerkter Zahlungseingang darf
    // nie ins Mahnsystem, auch wenn der Status noch nicht auf «bezahlt»
    // nachgezogen wurde — sonst mahnt der Lauf schneller, als der Mensch
    // den Status pflegt.
    r.zahlungEingegangenAm == null &&
    (r.zahlungBetrag ?? 0) == 0;

/// Nachweislich beim Kunden: per Mail, am Tresen übergeben (mit Datum) oder
/// Versandart Tresen — das Übergabedatum wird erst seit v0.71.0 gespeichert,
/// davor gilt das Rechnungsdatum (Entscheid Daniel 23.09.2026).
bool istZugestellt(Rechnung r) =>
    r.versendetAm != null ||
    r.uebergebenAm != null ||
    r.versandart == 'rechnung_tresen';

DateTime zustelldatum(Rechnung r) =>
    _tag(r.versendetAm ?? r.uebergebenAm ?? r.rechnungsdatum);

/// Ist die Rechnung erst nach ihrem Fälligkeitsdatum zugestellt worden
/// (z. B. «erneut senden»), laufen die 30 Tage ab der Zustellung — sonst
/// würde eine eben zugestellte Rechnung sofort gemahnt.
DateTime massgebendeFaelligkeit(Rechnung r) {
  final z = zustelldatum(r);
  final f = _tag(r.faelligkeitsdatum);
  return z.isAfter(f) ? _plus(z, 30) : f;
}

/// Stufe, die jetzt fällig ist — oder null. [stichtag] ist das Ende des
/// letzten eingelesenen Bankauszugs, NICHT heute.
MahnStufe? faelligeStufe(Rechnung r, {required DateTime stichtag}) {
  if (!imMahnbereich(r) || !istZugestellt(r)) return null;
  final grenze = _plus(stichtag, -kPufferVorStichtagTage);
  bool erreicht(DateTime ab) => !ab.isAfter(grenze);

  switch (r.zahlungsstatus) {
    case 'erinnert':
      final frist = r.mahnFristBis ??
          (r.erinnerungAm != null ? _plus(r.erinnerungAm!, kMahnFristTage) : null);
      if (frist == null) return null;
      return erreicht(_plus(frist, kNaechsteStufeNachFrist)) ? MahnStufe.mahnung1 : null;
    case 'mahnung_1':
      final frist = r.mahnFristBis ??
          (r.mahnung1Am != null ? _plus(r.mahnung1Am!, kMahnFristTage) : null);
      if (frist == null) return null;
      return erreicht(_plus(frist, kNaechsteStufeNachFrist)) ? MahnStufe.letzte : null;
    case 'mahnung_2':
      return null; // weiter mit Heineken (Teil 2)
    case 'offen':
    case 'gesendet':
      return erreicht(_plus(massgebendeFaelligkeit(r), kErinnerungNachTagen))
          ? MahnStufe.erinnerung
          : null;
    default:
      // I-4 (Review 23.09.2026): Nur bekannte Status lösen die erste Stufe
      // aus. Ein unbekannter oder abweichender Status (z. B. «storniert»,
      // «freigegeben») ist immer ein Zeichen, dass hier NICHT stur nach
      // Fälligkeit gemahnt werden darf.
      return null;
  }
}

/// Ist die Frist der letzten Mahnung + [kNaechsteStufeNachFrist] Tage vor dem
/// Puffer-Stichtag vorbei? Dann schlägt die App vor, Heineken einzuschalten
/// (Mahnwesen Teil 2, Spec §2/§5). Gleicher Stichtag wie [faelligeStufe]:
/// Ende des letzten Bankauszugs, nicht heute.
bool eskalationFaellig(Rechnung r, {required DateTime stichtag}) {
  if (!imMahnbereich(r) || r.zahlungsstatus != 'mahnung_2') return false;
  final frist = r.mahnFristBis ??
      (r.mahnung2Am != null ? _plus(r.mahnung2Am!, kMahnFristTage) : null);
  if (frist == null) return false;
  final grenze = _plus(stichtag, -kPufferVorStichtagTage);
  return !_plus(frist, kNaechsteStufeNachFrist).isAfter(grenze);
}

bool bankSperre(
  DateTime? letzterAuszug, {
  required DateTime heute,
  // M-4 (Review 23.09.2026): Eine erkannte Lücke in der Auszugskette
  // (Bank-Wächter) heisst, dass Zahlungen fehlen könnten, die den Mahnlauf
  // stoppen würden — auch wenn der letzte Auszug scheinbar aktuell ist.
  bool auszugLuecke = false,
}) {
  if (letzterAuszug == null || auszugLuecke) return true;
  return _tag(heute).difference(_tag(letzterAuszug)).inDays > kAuszugHoechstensAltTage;
}

typedef OffeneGutschrift = ({String? partei, double betrag});

/// Toleranz beim Betragsvergleich: Kunden zahlen oft auf 5 Rappen gerundet
/// oder mit kleinen Bankspesen-Abweichungen (Review 23.09.2026, I-2).
/// Lieber zu vorsichtig sperren als eine bezahlte Rechnung mahnen.
const kBetragsToleranz = 0.10;

bool _gleich(double a, double b) => (a - b).abs() < kBetragsToleranz;

/// Höchstzahl offener Beträge, bis zu der die Teilsummen-Prüfung per
/// Bitmaske noch vertretbar ist (2^12 = 4096 Kombinationen).
const kMaxBetraegeFuerTeilsumme = 12;

/// Trifft der normalisierte Zahlername einen der bekannten Namen, exakt
/// oder als Teilstring (in beide Richtungen)? Der kürzere Teil muss
/// mindestens 4 Zeichen haben (Review 23.09.2026, M-2) — sonst würde z. B.
/// «Bar» jeden Zahler mit «bar» irgendwo im Namen treffen.
bool _nameTrifft(Set<String> namen, String zahler) {
  if (zahler.isEmpty) return false;
  for (final n in namen) {
    if (n == zahler) return true;
    final kurz = n.length <= zahler.length ? n : zahler;
    final lang = n.length <= zahler.length ? zahler : n;
    if (kurz.length >= 4 && lang.contains(kurz)) return true;
  }
  return false;
}

/// Prüft, ob eine (beliebige, nicht-leere) Teilmenge der offenen Beträge in
/// der Summe dem Gutschriftsbetrag entspricht — z. B. wenn eine Sammel-
/// zahlung 2 von 3 offenen Rechnungen deckt (Review 23.09.2026, I-1).
///
/// WARUM Bitmaske bis [kMaxBetraegeFuerTeilsumme]: Ein Betrieb hat praktisch
/// nie mehr offene Rechnungen; 2^12 Kombinationen sind trivial zu prüfen.
/// Bei mehr offenen Beträgen wird — weil sich keine vollständige Prüfung
/// mehr lohnt — aus Vorsicht IMMER gesperrt (sicherer Rückfall): lieber ein
/// Betrieb zu viel zurückgehalten als eine Mahnung für Bezahltes.
bool _teilsummeTrifft(List<double> betraege, double ziel) {
  if (betraege.isEmpty) return false;
  if (betraege.length > kMaxBetraegeFuerTeilsumme) return true;
  final n = betraege.length;
  for (var maske = 1; maske < (1 << n); maske++) {
    var summe = 0.0;
    for (var i = 0; i < n; i++) {
      if (maske & (1 << i) != 0) summe += betraege[i];
    }
    if (_gleich(summe, ziel)) return true;
  }
  return false;
}

/// Welche offene Gutschrift sperrt den Betrieb — und warum?
///
/// [index] zeigt in [gutschriften] (der Aufrufer kennt dazu Datum und
/// Zahler). [rueckfall] = true heisst: Gesperrt wurde nicht wegen eines
/// echten Treffers, sondern weil der Betrieb mehr als
/// [kMaxBetraegeFuerTeilsumme] offene Beträge hat und die Teilsummen nicht
/// mehr vollständig geprüft werden (sicherer Rückfall). Die Oberfläche
/// braucht das, um Daniel den richtigen Grund zu zeigen.
typedef GutschriftTreffer = ({int index, bool rueckfall});

/// Wie [gutschriftSperre], liefert aber die ERSTE treffende Gutschrift —
/// damit die Mahnlauf-Seite sagen kann, welche Zahlung ungeklärt ist
/// (Review 23.09.2026). Die Regel ist dieselbe: [gutschriftSperre] ruft
/// genau diese Funktion.
GutschriftTreffer? passendeGutschrift({
  required String betriebName,
  required List<String> aliase,
  required List<double> offeneBetraege,
  required List<OffeneGutschrift> gutschriften,
}) {
  final namen = {
    zahlernameNorm(betriebName),
    for (final a in aliase) zahlernameNorm(a),
  }..remove('');
  for (var i = 0; i < gutschriften.length; i++) {
    final g = gutschriften[i];
    final p = zahlernameNorm(g.partei ?? '');
    if (_nameTrifft(namen, p)) return (index: i, rueckfall: false);
    if (_teilsummeTrifft(offeneBetraege, g.betrag)) {
      return (
        index: i,
        rueckfall: offeneBetraege.length > kMaxBetraegeFuerTeilsumme,
      );
    }
  }
  return null;
}

/// Gibt es eine noch nicht zugeordnete Bankgutschrift, die zu diesem
/// Betrieb gehören könnte? Dann wird er nicht gemahnt.
///
/// Bewusst grosszügig: Ein Betrag, der zu irgendeiner offenen Rechnung
/// passt, sperrt — auch bei gängigen Preisen wie 94.05. Lieber ein Betrieb
/// zu viel zurückgehalten als eine Mahnung für Bezahltes.
bool gutschriftSperre({
  required String betriebName,
  required List<String> aliase,
  required List<double> offeneBetraege,
  required List<OffeneGutschrift> gutschriften,
}) =>
    passendeGutschrift(
      betriebName: betriebName,
      aliase: aliase,
      offeneBetraege: offeneBetraege,
      gutschriften: gutschriften,
    ) !=
    null;

/// Zeitraum und Saldi eines eingelesenen Bankauszugs (camt_dateien).
typedef AuszugInfo = ({
  DateTime von,
  DateTime bis,
  double? anfangssaldo,
  double? schlusssaldo,
});

/// Ergebnis der Auszugsketten-Prüfung.
/// - [AuszugKette.luecke]: fehlende Tage oder Saldosprung — SPERRT den Lauf.
/// - [AuszugKette.ungeprueft]: nahtloser Anschluss, aber ein Saldo fehlt
///   (ältere Importe ohne OPBD/CLBD) — Vollständigkeit nicht belegbar,
///   nur ein Hinweis (Review 23.09.2026, M-1). Eine Sperre hier würde den
///   Mahnlauf wegen alter Importe dauerhaft blockieren.
enum AuszugKette { ok, ungeprueft, luecke }

typedef AuszugKettenBefund = ({AuszugKette status, String? text});

/// Prüft die Kette der Bankauszüge seit dem Mahnstart.
///
/// WARUM: Fehlt ein Stück Kontoauszug, fehlen womöglich genau die Zahlungen,
/// die eine Mahnung verhindern würden — auch wenn der letzte Auszug aktuell
/// ist (Review 23.09.2026, M-4). Dieselbe Prüfung wie der Bank-Wächter in
/// der Abschlussprüfung (`CamtKetteRegel`): fehlende Tage zwischen dem
/// bisher abgedeckten Zeitraum und dem nächsten Auszug, und bei nahtlosem
/// Anschluss OPBD ≠ CLBD (Saldosprung). Überlappungen sind harmlos. Nur
/// Auszüge, die in den Mahnbereich reichen, zählen — eine alte Lücke von
/// 2025 darf den Mahnlauf nicht dauerhaft sperren. Eine Lücke geht immer
/// vor «ungeprüft».
AuszugKettenBefund pruefeAuszugKette(List<AuszugInfo> auszuege) {
  final l = auszuege.where((a) => !_tag(a.bis).isBefore(kMahnStart)).toList()
    ..sort((a, b) => a.von.compareTo(b.von));
  if (l.length < 2) return (status: AuszugKette.ok, text: null);
  var abgedecktBis = l.first.bis;
  var abgedecktSaldo = l.first.schlusssaldo;
  var ungeprueft = false;
  for (var i = 1; i < l.length; i++) {
    final c = l[i];
    final luecke = BankWaechter.luecke(letztesBis: abgedecktBis, neuesVon: c.von);
    if (luecke != null) return (status: AuszugKette.luecke, text: luecke);
    final nahtlos = _tag(c.von).difference(_tag(abgedecktBis)).inDays == 1;
    final opbd = c.anfangssaldo;
    if (nahtlos && (opbd == null || abgedecktSaldo == null)) {
      ungeprueft = true;
    } else if (nahtlos && (opbd! - abgedecktSaldo!).abs() > 0.005) {
      return (
        status: AuszugKette.luecke,
        text: 'Saldosprung zwischen zwei Auszügen '
            '(${abgedecktSaldo.toStringAsFixed(2)} → ${opbd.toStringAsFixed(2)})',
      );
    }
    if (c.bis.isAfter(abgedecktBis)) {
      abgedecktBis = c.bis;
      abgedecktSaldo = c.schlusssaldo;
    }
  }
  return ungeprueft
      ? (
          status: AuszugKette.ungeprueft,
          text: 'Saldo einer Auszugsdatei fehlt — Vollständigkeit ungeprüft',
        )
      : (status: AuszugKette.ok, text: null);
}

/// Kanal eines Mahnschreibens: [mail] ist die Adresse, an die es geht
/// (Rechnungsadresse vor Betrieb, wie die Rechnung), [druck], ob zusätzlich
/// bzw. nur ein PDF zum Ausdrucken entsteht.
typedef MahnKanal = ({String kanal, String? mail, bool druck});

/// EINE Regel für Vorschau, Karte und Versand (Review 23.09.2026, M-3) —
/// sonst zeigt die Vorschau einen anderen Kanal, als der Service wählt.
/// Die letzte Mahnung geht IMMER zusätzlich als Druck (Einschreiben,
/// Beweismittel für eine Betreibung).
MahnKanal mahnKanal({
  required String? raMail,
  required String? betriebMail,
  required MahnStufe stufe,
}) {
  final ra = (raMail ?? '').trim();
  final b = (betriebMail ?? '').trim();
  final mail = ra.isNotEmpty ? ra : (b.isNotEmpty ? b : null);
  if (mail == null) return (kanal: 'druck', mail: null, druck: true);
  final druck = stufe == MahnStufe.letzte;
  return (kanal: druck ? 'mail_und_druck' : 'mail', mail: mail, druck: druck);
}

MahnStufe hoechsteStufe(Iterable<MahnStufe> stufen) {
  if (stufen.isEmpty) {
    // M-5 (Review 23.09.2026): Ein leerer Aufruf ist ein Programmierfehler
    // beim Aufrufer (kein Schreiben ohne Stufe) — lieber laut scheitern als
    // still eine falsche Stufe erraten.
    throw ArgumentError('hoechsteStufe: Liste darf nicht leer sein');
  }
  return stufen.reduce((a, b) => a.index >= b.index ? a : b);
}

DateTime mahnFrist(DateTime versand) => _plus(versand, kMahnFristTage);

/// Eine noch nicht mit einer Rechnung verknüpfte Kundenzahlung (Buchung
/// Soll 1000/1020, Haben 1100, ohne `beleg_id`) — Eingabe für
/// [unverknuepfteZahlungenAuswerten].
///
/// WARUM diese Sperre: Excel-Importzahlungen (bis 11.03.2026) landeten ohne
/// `beleg_id` in der Buchhaltung; der Rechnungsstatus blieb «offen». Ohne
/// diese Prüfung hätte der Mahnlauf am 24.09.2026 8 bereits bezahlte
/// Betriebe gemahnt.
typedef UnverknuepfteZahlung = ({
  DateTime datum,
  double betrag,
  String? belegnummer,
  String beschreibung,
});

/// Betrieb, soweit die Zuordnung unverknüpfter Zahlungen ihn braucht.
typedef ZahlungsBetrieb = ({String id, String? heinekenNr});

/// Ergebnis von [unverknuepfteZahlungenAuswerten]:
/// - [betriebsSperren]: Betrieb-Id → Sperrgrund, wenn genau ein Betrieb per
///   Kürzel in der Belegnummer getroffen wurde (analog zur Gutschrift-Sperre).
/// - [ungeklaert]: Zahlungen ohne eindeutigen Betrieb — sperren den GANZEN
///   Mahnlauf (analog zur Bank-Sperre, Sicherheit vor Bequemlichkeit).
typedef ZahlungsSperren = ({
  Map<String, String> betriebsSperren,
  List<UnverknuepfteZahlung> ungeklaert,
});

/// Heineken-Zahlungen laufen über einen eigenen, geprüften Weg (Belegnummer
/// `022_...` bzw. Beschreibung «Zahlungseingang Heineken…») — nie eine
/// Kundenzahlungs-Sperre.
bool _istHeinekenZahlung(UnverknuepfteZahlung z) =>
    (z.belegnummer ?? '').startsWith('022_') ||
    z.beschreibung.startsWith('Zahlungseingang Heineken');

/// Kürzel aus der Belegnummer `020_JJJJ_MM_TT_KKKK_BETRAG` (5. Segment,
/// Index 4) — oder null, wenn das Format nicht passt (z. B. `XXX`).
String? _kuerzelAusBelegnummer(String? belegnummer) {
  final teile = (belegnummer ?? '').split('_');
  if (teile.length < 5) return null;
  final kuerzel = teile[4];
  return kuerzel.isEmpty ? null : kuerzel;
}

String _datumMahnPunkt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Wertet unverknüpfte Kundenzahlungen ab [ab] (Default [kMahnStart]) aus.
///
/// Für jede Zahlung wird über das Kürzel im 5. Segment der Belegnummer
/// versucht, GENAU EINEN Betrieb zu finden (`betriebe.heinekenNr`). Gelingt
/// das, wird nur dieser Betrieb gesperrt. Gelingt es nicht (kein/ungültiges
/// Kürzel, kein oder mehr als ein passender Betrieb), sperrt die Zahlung den
/// ganzen Mahnlauf — lieber zu vorsichtig als eine Mahnung für Bezahltes.
ZahlungsSperren unverknuepfteZahlungenAuswerten({
  required List<UnverknuepfteZahlung> zahlungen,
  required List<ZahlungsBetrieb> betriebe,
  DateTime? ab,
}) {
  final start = _tag(ab ?? kMahnStart);
  final relevante = zahlungen
      .where((z) => !_tag(z.datum).isBefore(start))
      .where((z) => !_istHeinekenZahlung(z));

  final nachKuerzel = <String, List<ZahlungsBetrieb>>{};
  for (final b in betriebe) {
    final nr = b.heinekenNr;
    if (nr == null || nr.isEmpty) continue;
    (nachKuerzel[nr] ??= []).add(b);
  }

  final betriebsSperren = <String, String>{};
  final ungeklaert = <UnverknuepfteZahlung>[];

  for (final z in relevante) {
    final kuerzel = _kuerzelAusBelegnummer(z.belegnummer);
    final treffer = kuerzel == null ? null : nachKuerzel[kuerzel];
    if (treffer == null || treffer.length != 1) {
      ungeklaert.add(z);
      continue;
    }
    betriebsSperren[treffer.single.id] =
        'Zahlung vom ${_datumMahnPunkt(z.datum)} über '
        'CHF ${z.betrag.toStringAsFixed(2)} ist keiner Rechnung zugeordnet '
        '— zuerst zuordnen';
  }

  return (betriebsSperren: betriebsSperren, ungeklaert: ungeklaert);
}
