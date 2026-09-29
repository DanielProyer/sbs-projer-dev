/// Steuerrückstellung im Jahresabschluss (Schritt D): Vorschlag aus dem
/// Gewinn, Erkennung der schon gebuchten Rückstellung, Buchungsbetrag.
///
/// Reine Logik — die Abschlussprüfung (`RueckstellungRegel`), der Dialog und
/// `SteuerrueckstellungService` rechnen damit dasselbe. Bis 29.09.2026 wurde
/// die Rückstellung per SQL gebucht (docs/buchhaltung/jahresabschluss-2025.md
/// Abschnitt 9d); Entscheid Daniel: «die Schritte in die App, damit ich das
/// in späteren Jahren direkt machen kann».
library;

import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

/// Effektiver Steuersatz auf den steuerbaren Gewinn (Bund 8.5 % + Kanton GR/Gemeinde
/// Domat/Ems/Kultus ≈ 9.7 %), kalibriert an der Veranlagung 2024 (Bund 2'405.50 auf
/// 28'300 steuerbar; Kanton definitiv 2'748.00). Jährlich an der letzten Veranlagung
/// nachprüfen (Steuern → Jahr).
const kSteuersatzEffektiv = 0.182;

/// Steueraufwand (Gegenkonto der Rückstellung).
const kKontoSteueraufwand = 8900;

/// Steuerrückstellung (Passivkonto).
const kKontoSteuerrueckstellung = 2208;

/// Bussen sind steuerlich nicht abzugsfähig und werden dem Gewinn
/// aufgerechnet: 6280 Verkehrsbussen, 6281 Übrige Bussen (dorthin kontiert
/// der camt-Import Steuerbussen, `steuerKontoFuer`).
const kKontenBussen = {6280, 6281};

/// Vorschlag der Rückstellung: R = s · (G + A − R)  ⇒  R = s · (G + A) / (1 + s),
/// auf 100 gerundet, nie negativ. [gewinnVorRueckstellung] = Jahresergebnis OHNE die
/// Rückstellungsbuchungen des Jahres; [aufrechnungen] = nicht abzugsfähige Aufwände
/// (Bussen 6280 + manuell).
///
/// WARUM die Gleichung: Die Rückstellung ist selbst Aufwand und senkt den
/// steuerbaren Gewinn, auf den sie berechnet wird. 18.2 % auf den Gewinn
/// VOR Rückstellung überschätzte die Steuer um den Faktor 1 + s.
double rueckstellungVorschlag({
  required double gewinnVorRueckstellung,
  required double aufrechnungen,
  double satz = kSteuersatzEffektiv,
}) {
  final basis = gewinnVorRueckstellung + aufrechnungen;
  if (basis <= 0 || satz <= 0) return 0;
  final r = satz * basis / (1 + satz);
  // Kaufmännisch auf 100 wie im Abschluss 2025 (2'826 → 2'800) — die
  // definitive Veranlagung gleicht die Differenz ohnehin aus.
  return (r / 100).roundToDouble() * 100;
}

/// Steuerbarer Gewinn = Gewinn nach Rückstellung + Aufrechnungen.
double steuerbarerGewinn({
  required double gewinnNachRueckstellung,
  required double aufrechnungen,
}) => rundeAufRappen(gewinnNachRueckstellung + aufrechnungen);

/// Stand der Rückstellung eines Jahres.
///
/// [gewinnVorRueckstellung]: Jahresergebnis laut Journal plus die schon
/// gebuchte Rückstellung des Jahres — damit der Vorschlag nicht von sich
/// selbst abhängt. [aufrechnungenAuto]: Bussen-Aufwand des Jahres
/// ([kKontenBussen]). [gebucht]: Rückstellung des Jahres netto
/// ([rueckstellungGebucht]).
typedef SteuerrueckstellungLage = ({
  double gewinnVorRueckstellung,
  double aufrechnungenAuto,
  double gebucht,
});

/// Zählt [b] als Rückstellungsbuchung des Jahres [jahr]?
///
/// Nur die Abschlussbuchung selbst: 8900 ↔ 2208, `beleg_typ` «abschluss»,
/// Geschäftsjahr [jahr] UND per 31.12.[jahr]. WARUM das Datum: Die
/// Umbuchungen der provisorischen Steuerzahlungen 2025 (`JA2025_D_U1/U2`,
/// 2208 an 8900 im April/Mai 2026) tragen ebenfalls `beleg_typ` «abschluss»
/// und Geschäftsjahr 2026 — ohne den Stichtag zählten sie für 2026 als
/// Auflösung von 5'153.50. Zahlungen gegen 2208 (Bank im Haben) zählen nie.
/// Stornierte Buchungen und Storno-Gegenbuchungen fallen heraus.
bool istRueckstellungsbuchung(Buchung b, int jahr) {
  if (!zaehltFuerSaldo(
    istStorniert: b.istStorniert,
    stornoVonId: b.stornoVonId,
  )) {
    return false;
  }
  if (b.belegTyp != 'abschluss' || b.geschaeftsjahr != jahr) return false;
  if (b.datum.year != jahr || b.datum.month != 12 || b.datum.day != 31) {
    return false;
  }
  final aufbau =
      b.sollKonto == kKontoSteueraufwand &&
      b.habenKonto == kKontoSteuerrueckstellung;
  final abbau =
      b.sollKonto == kKontoSteuerrueckstellung &&
      b.habenKonto == kKontoSteueraufwand;
  return aufbau || abbau;
}

/// Rückstellung des Jahres netto: Σ 8900 an 2208 − Σ 2208 an 8900 (nur
/// [istRueckstellungsbuchung]).
double rueckstellungGebucht(Iterable<Buchung> journal, int jahr) {
  var summe = 0.0;
  for (final b in journal) {
    if (!istRueckstellungsbuchung(b, jahr)) continue;
    summe += b.sollKonto == kKontoSteueraufwand
        ? b.betragBrutto
        : -b.betragBrutto;
  }
  return rundeAufRappen(summe);
}

/// Lage aus den Saldi per 31.12. des Jahres ([saldiBis]) und per 31.12. des
/// Vorjahres ([saldiVor]) — gleiche Rechnung wie die Bilanz
/// (`BilanzService.erstelle`: Jahresergebnis = kumuliertes Ergebnis bis
/// Stichtag − bis Vorjahr, Gewinn positiv).
SteuerrueckstellungLage rueckstellungLageAusSaldi({
  required Map<int, double> saldiBis,
  required Map<int, double> saldiVor,
  required double gebucht,
}) {
  final ergebnis =
      BilanzService.kumuliertesErgebnis(saldiBis) -
      BilanzService.kumuliertesErgebnis(saldiVor);
  var bussen = 0.0;
  for (final k in kKontenBussen) {
    // Aufwandkonto: Roh-Saldo Soll − Haben, Aufwand positiv.
    bussen += (saldiBis[k] ?? 0) - (saldiVor[k] ?? 0);
  }
  return (
    gewinnVorRueckstellung: rundeAufRappen(ergebnis + gebucht),
    aufrechnungenAuto: rundeAufRappen(bussen),
    gebucht: rundeAufRappen(gebucht),
  );
}

/// Buchung, die die Rückstellung von [gebucht] auf [ziel] bringt:
/// [aufbau] = 8900 an 2208, sonst 2208 an 8900. [betrag] < 0.01 heisst
/// «nichts zu buchen».
({double betrag, bool aufbau}) rueckstellungBuchung({
  required double ziel,
  required double gebucht,
}) {
  final diff = rundeAufRappen(ziel - gebucht);
  return (betrag: diff.abs(), aufbau: diff > 0);
}
