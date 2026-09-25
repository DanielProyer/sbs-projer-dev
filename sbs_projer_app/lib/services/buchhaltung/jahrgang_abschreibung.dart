import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Reine Logik des Abschluss-Schritts «Jahrgang abschreiben»: welche
/// Rechnungen dran sind, wie sie sich aufteilen und was gebucht wird.
///
/// Gebucht wird NICHT hier, sondern in der SQL-Funktion
/// `abschreibung_jahrgang_buchen` (Migration 194) — in einer Transaktion,
/// damit 160 Rechnungen nie halb abgeschrieben stehen bleiben. Diese Datei
/// zeigt vorher, was die Funktion tun wird, aus denselben Spalten.
///
/// Konzept und Entscheide: docs/buchhaltung/abschreibungen-jahrgaenge.md.

/// Verjährung von Forderungen aus Dienstleistung — Art. 128 Ziff. 3 OR.
const kVerjaehrungJahre = 5;

/// Jahrgänge bis und mit diesem sind per 31.12. des Geschäftsjahres
/// verjährt: Abschluss 2026 → 2021 (also 2020 und 2021).
int verjaehrtBisJahrgang(int geschaeftsjahr) =>
    geschaeftsjahr - kVerjaehrungJahre;

/// Wie eine offene Rechnung zustande kam — für die Bewertung wichtig:
/// Tresen und Gestellt sind echte Debitorenverluste, Nie gestellt ist
/// nie fakturierter Ertrag (der Kunde hat die Rechnung nie gesehen).
enum AbschreibKategorie { tresen, gestellt, nieGestellt }

extension AbschreibKategorieText on AbschreibKategorie {
  String get label => switch (this) {
    AbschreibKategorie.tresen => 'Tresen',
    AbschreibKategorie.gestellt => 'Gestellt',
    AbschreibKategorie.nieGestellt => 'Nie gestellt',
  };

  String get erklaerung => switch (this) {
    AbschreibKategorie.tresen => 'am Tresen übergeben, nie bezahlt',
    AbschreibKategorie.gestellt => 'per Mail/Post versandt, nie bezahlt',
    AbschreibKategorie.nieGestellt =>
      'kein Versanddatum in der App — der Kunde hat sie nie erhalten',
  };

  /// Wert in `abschreibung_positionen.kategorie`.
  String get dbWert => switch (this) {
    AbschreibKategorie.tresen => 'tresen',
    AbschreibKategorie.gestellt => 'gestellt',
    AbschreibKategorie.nieGestellt => 'nie_gestellt',
  };
}

/// Dieselbe Regel wie `abschreibung_kategorie()` in der Datenbank.
AbschreibKategorie kategorieFuer({
  required String? versandart,
  required DateTime? uebergebenAm,
  required DateTime? versendetAm,
}) {
  if (versandart == 'rechnung_tresen' || uebergebenAm != null) {
    return AbschreibKategorie.tresen;
  }
  if (versendetAm != null) return AbschreibKategorie.gestellt;
  return AbschreibKategorie.nieGestellt;
}

/// Eine Rechnung, wie sie im Lauf gebucht würde.
class AbschreibPosition {
  final String id;
  final String nummer;
  final String betrieb;
  final DateTime datum;
  final double netto;
  final double mwst;
  final double brutto;
  final AbschreibKategorie kategorie;

  const AbschreibPosition({
    required this.id,
    required this.nummer,
    required this.betrieb,
    required this.datum,
    required this.netto,
    required this.mwst,
    required this.brutto,
    required this.kategorie,
  });

  int get jahrgang => datum.year;

  /// Satz der Leistung, aus den gespeicherten Beträgen — 7.7 bis 2023,
  /// 8.1 ab 2024. Nie der Satz des Buchungstages.
  double get satz => netto > 0 ? (mwst / netto * 1000).round() / 10 : 0;
}

/// Eine Rechnung, die zwar alt genug wäre, aber nicht gebucht werden darf.
class AbschreibAusschluss {
  final String id;
  final String nummer;
  final String betrieb;
  final DateTime datum;
  final double brutto;
  final String grund;

  const AbschreibAusschluss({
    required this.id,
    required this.nummer,
    required this.betrieb,
    required this.datum,
    required this.brutto,
    required this.grund,
  });
}

class AbschreibAuswahl {
  final int geschaeftsjahr;
  final List<AbschreibPosition> positionen;
  final List<AbschreibAusschluss> ausgeschlossen;

  const AbschreibAuswahl({
    required this.geschaeftsjahr,
    required this.positionen,
    required this.ausgeschlossen,
  });

  int get grenze => verjaehrtBisJahrgang(geschaeftsjahr);
  DateTime get buchungsdatum => DateTime(geschaeftsjahr, 12, 31);
  List<String> get rechnungIds => [for (final p in positionen) p.id];
  bool get leer => positionen.isEmpty;
}

/// Wählt aus den offenen Rechnungen die verjährten Kundenrechnungen aus.
/// Heineken-Monatsrechnungen bleiben stumm draussen (anderer Workflow);
/// alles andere, was nicht buchbar ist, wird mit Grund ausgewiesen — die
/// SQL-Funktion würde es ohnehin abweisen, aber dann mit 160 Nummern in
/// einer Fehlermeldung.
AbschreibAuswahl auswahlFuer(
  List<Rechnung> offene, {
  required int geschaeftsjahr,
  required Map<String, String> betriebNamen,
}) {
  final grenze = verjaehrtBisJahrgang(geschaeftsjahr);
  final positionen = <AbschreibPosition>[];
  final ausgeschlossen = <AbschreibAusschluss>[];
  for (final r in offene) {
    if (r.rechnungstyp != 'kundenrechnung') continue;
    if (r.rechnungsdatum.year > grenze) continue;
    if (r.zahlungsstatus == 'bezahlt' || r.zahlungsstatus == 'abgeschrieben') {
      continue;
    }
    final nummer = r.rechnungsnummer ?? r.id.substring(0, 8);
    final betrieb = betriebNamen[r.betriebId] ?? '';
    final grund = _ausschlussGrund(r);
    if (grund != null) {
      ausgeschlossen.add(
        AbschreibAusschluss(
          id: r.id,
          nummer: nummer,
          betrieb: betrieb,
          datum: r.rechnungsdatum,
          brutto: r.betragBrutto,
          grund: grund,
        ),
      );
      continue;
    }
    positionen.add(
      AbschreibPosition(
        id: r.id,
        nummer: nummer,
        betrieb: betrieb,
        datum: r.rechnungsdatum,
        netto: r.betragNetto,
        mwst: r.mwstBetrag,
        brutto: r.betragBrutto,
        kategorie: kategorieFuer(
          versandart: r.versandart,
          uebergebenAm: r.uebergebenAm,
          versendetAm: r.versendetAm,
        ),
      ),
    );
  }
  int nachDatum(DateTime a, DateTime b) => a.compareTo(b);
  positionen.sort((a, b) {
    final d = nachDatum(a.datum, b.datum);
    return d != 0 ? d : a.id.compareTo(b.id);
  });
  ausgeschlossen.sort((a, b) => nachDatum(a.datum, b.datum));
  return AbschreibAuswahl(
    geschaeftsjahr: geschaeftsjahr,
    positionen: positionen,
    ausgeschlossen: ausgeschlossen,
  );
}

String? _ausschlussGrund(Rechnung r) {
  if (r.zahlungEingegangenAm != null || (r.zahlungBetrag ?? 0) > 0) {
    return 'Zahlung vermerkt — zuerst klären, dann bezahlt setzen';
  }
  if (r.betragBrutto <= 0) return 'Betrag 0';
  // Die Datenbank-Funktion des Jahrgangs schreibt das volle Brutto ab und
  // kennt die Guthaben-Verrechnung (2030/1100) nicht — solche Rechnungen
  // einzeln über das Mahnwesen abschreiben (Review Kundenguthaben I3).
  if (r.guthabenVerrechnet > 0) {
    return 'Kundenguthaben verrechnet — einzeln abschreiben (Rechnungsliste)';
  }
  if ((r.betragBrutto - r.betragNetto - r.mwstBetrag).abs() > 0.011) {
    return 'Netto + MWST ergibt nicht Brutto — Rechnung prüfen';
  }
  return null;
}

/// Summen einer Gruppe (Jahrgang, Kategorie oder Satz).
class AbschreibSumme {
  final int anzahl;
  final double netto;
  final double mwst;
  final double brutto;

  const AbschreibSumme({
    required this.anzahl,
    required this.netto,
    required this.mwst,
    required this.brutto,
  });

  static const leer = AbschreibSumme(anzahl: 0, netto: 0, mwst: 0, brutto: 0);

  static AbschreibSumme aus(Iterable<AbschreibPosition> p) {
    var n = 0;
    var netto = 0.0, mwst = 0.0, brutto = 0.0;
    for (final x in p) {
      n++;
      netto += x.netto;
      mwst += x.mwst;
      brutto += x.brutto;
    }
    return AbschreibSumme(
      anzahl: n,
      netto: rundeAufRappen(netto),
      mwst: rundeAufRappen(mwst),
      brutto: rundeAufRappen(brutto),
    );
  }
}

class JahrgangSumme {
  final int jahrgang;
  final AbschreibSumme total;
  final Map<AbschreibKategorie, AbschreibSumme> jeKategorie;

  const JahrgangSumme({
    required this.jahrgang,
    required this.total,
    required this.jeKategorie,
  });
}

class SatzSumme {
  final double satz;
  final AbschreibSumme summe;
  const SatzSumme({required this.satz, required this.summe});

  /// Zeile im ESTV-Formular (Stand Q2/2026): 302 = 7.7 %, 303 = 8.1 %.
  String get formularZeile => switch (satz) {
    7.7 => 'Zeile 302',
    8.1 => 'Zeile 303',
    _ => '',
  };
}

/// Was der Lauf buchen würde — je Jahrgang, je Kategorie, je Satz.
class AbschreibVorschau {
  final AbschreibAuswahl auswahl;
  final AbschreibSumme total;
  final List<JahrgangSumme> jahrgaenge;
  final List<SatzSumme> saetze;

  const AbschreibVorschau({
    required this.auswahl,
    required this.total,
    required this.jahrgaenge,
    required this.saetze,
  });

  factory AbschreibVorschau.aus(AbschreibAuswahl a) {
    final p = a.positionen;
    final jahrgaenge = <JahrgangSumme>[];
    for (final j in (p.map((x) => x.jahrgang).toSet().toList()..sort())) {
      final imJahr = p.where((x) => x.jahrgang == j);
      jahrgaenge.add(
        JahrgangSumme(
          jahrgang: j,
          total: AbschreibSumme.aus(imJahr),
          jeKategorie: {
            for (final k in AbschreibKategorie.values)
              k: AbschreibSumme.aus(imJahr.where((x) => x.kategorie == k)),
          },
        ),
      );
    }
    final saetze = <SatzSumme>[];
    for (final s in (p.map((x) => x.satz).toSet().toList()..sort())) {
      saetze.add(
        SatzSumme(
          satz: s,
          summe: AbschreibSumme.aus(p.where((x) => x.satz == s)),
        ),
      );
    }
    return AbschreibVorschau(
      auswahl: a,
      total: AbschreibSumme.aus(p),
      jahrgaenge: jahrgaenge,
      saetze: saetze,
    );
  }

  int get geschaeftsjahr => auswahl.geschaeftsjahr;

  /// «2020, 2021» — für Knopf und Dialog.
  String get jahrgangText => jahrgaenge.map((j) => '${j.jahrgang}').join(', ');
}

/// Text der Buchung, wie ihn die SQL-Funktion schreibt — damit Vorschau und
/// Journal dasselbe sagen und ein Test beide zusammenhält.
String debitorenverlustText({
  required String nummer,
  required String betrieb,
  required int jahrgang,
}) =>
    'Debitorenverlust $nummer $betrieb '
    '(Abschreibung Jahrgang $jahrgang, verjährt Art. 128 OR)';
