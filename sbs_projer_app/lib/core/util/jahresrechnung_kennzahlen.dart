/// Kennzahlen der Jahresrechnung: Anhang (OR 959c) und Steuerbeilage.
///
/// WARUM rein und hier: Fassung 1 und 2 der Jahresrechnung 2025 entstanden
/// mit Zahlen, die per SQL abgefragt und von Hand ins Beilage-Skript
/// (`Datenbank/wartung/jahresrechnung_beilage.py`) getippt wurden. Ab dem
/// Abschluss 2026 macht Daniel das ohne SQL — die Zahlen kommen deshalb aus
/// denselben Saldi wie die App-Bilanz, und diese Rechnung ist ohne Datenbank
/// testbar.
library;

import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/core/util/steuerrueckstellung.dart'
    show kKontenBussen;
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

class JahresrechnungKennzahlen {
  final int jahr;

  /// Jahresergebnis des Jahrs (positiv = Gewinn).
  final double gewinn;

  /// Kumuliertes Ergebnis bis 31.12. des Vorjahrs.
  final double gewinnvortrag;

  /// −Saldo 2800.
  final double stammkapital;

  /// Saldo 1100 per 31.12.
  final double debitoren;

  /// −Saldo 1109 (Delkredere, im Haben).
  final double delkredere;

  /// −Saldo 2208 (Steuerrückstellung, im Haben).
  final double rueckstellung;

  /// Saldo 1020 / 1000 per 31.12.
  final double bank, kasse;

  /// Nicht abzugsfähige Bussen des Jahrs — werden ohne Zutun aufgerechnet:
  /// Aufwand 6280/6281 ([kKontenBussen]) und Steuerbussen auf 8900 (bis
  /// Migration 203 dort gebucht; `bussenAuf8900`). Dieselbe Rechnung wie
  /// die Rückstellungs-Regel der Abschlussprüfung, damit Vorschlag und
  /// Steuerbeilage vom selben steuerbaren Gewinn ausgehen.
  final double aufrechnungenAuto;

  /// Weitere Aufrechnungen, die Daniel im Dialog einträgt (z. B. Bussen,
  /// die vor Migration 203 auf 8900 gebucht wurden).
  final double aufrechnungenManuell;

  /// «Jahrgang 2020: 76 Rechnungen, 7'216.30» je gebuchtem Lauf des Jahrs.
  final List<String> abschreibungen;

  /// Ein gebuchter Lauf des Jahrs holt die MWST erst im Folgejahr zurück
  /// (`mwstJahr > jahr`): Die Abschreibung wurde nach dem Stichtag
  /// beschlossen und zurückdatiert. Nur dann gilt der Standardtext
  /// «Ereignisse nach dem Bilanzstichtag» des Beilage-Skripts.
  final bool abschreibungNachStichtag;

  /// Freitext «Ereignisse nach dem Bilanzstichtag» (optional).
  final String? ereignisse;

  const JahresrechnungKennzahlen({
    required this.jahr,
    required this.gewinn,
    required this.gewinnvortrag,
    required this.stammkapital,
    required this.debitoren,
    required this.delkredere,
    required this.rueckstellung,
    required this.bank,
    required this.kasse,
    required this.aufrechnungenAuto,
    this.aufrechnungenManuell = 0,
    this.abschreibungen = const [],
    this.abschreibungNachStichtag = false,
    this.ereignisse,
  });

  /// Tatsächlicher Satz des Delkredere auf den Debitoren, eine
  /// Nachkommastelle («5.3 %»). WARUM nicht fest «5 %»: Nach einer
  /// Abschreibung ohne Nachführung stimmt die Pauschale nicht mehr — der
  /// Anhang soll zeigen, was gebucht ist.
  String get delkredereSatzText {
    final satz = debitoren > 0.005 ? delkredere / debitoren * 100 : 0.0;
    return '${satz.toStringAsFixed(1)} %';
  }

  double get eigenkapital =>
      rundeAufRappen(stammkapital + gewinnvortrag + gewinn);
  double get aufrechnungen =>
      rundeAufRappen(aufrechnungenAuto + aufrechnungenManuell);
  double get steuerbarerGewinn => rundeAufRappen(gewinn + aufrechnungen);

  /// Dieselben Zahlen mit den Eingaben aus dem Erzeugen-Dialog.
  JahresrechnungKennzahlen mit({
    double? aufrechnungenManuell,
    String? ereignisse,
  }) => JahresrechnungKennzahlen(
    jahr: jahr,
    gewinn: gewinn,
    gewinnvortrag: gewinnvortrag,
    stammkapital: stammkapital,
    debitoren: debitoren,
    delkredere: delkredere,
    rueckstellung: rueckstellung,
    bank: bank,
    kasse: kasse,
    aufrechnungenAuto: aufrechnungenAuto,
    aufrechnungenManuell: aufrechnungenManuell ?? this.aufrechnungenManuell,
    abschreibungen: abschreibungen,
    abschreibungNachStichtag: abschreibungNachStichtag,
    ereignisse: ereignisse ?? this.ereignisse,
  );
}

/// Eine Zeile je gebuchtem Abschreibungslauf des Geschäftsjahrs [jahr].
///
/// Zurückgenommene Läufe zählen nicht — ihre Buchungen sind gelöscht, die
/// Rechnungen wieder offen.
List<String> abschreibungsZeilen(int jahr, List<AbschreibungLauf> laeufe) {
  final gebucht =
      laeufe.where((l) => l.geschaeftsjahr == jahr && l.gebucht).toList()
        ..sort((a, b) {
          final ja = a.jahrgaenge.isEmpty ? 0 : a.jahrgaenge.first;
          final jb = b.jahrgaenge.isEmpty ? 0 : b.jahrgaenge.first;
          return ja.compareTo(jb);
        });
  return [
    for (final l in gebucht)
      '${l.jahrgaenge.length == 1 ? 'Jahrgang' : 'Jahrgänge'} '
          '${l.jahrgaenge.join(', ')}: ${l.anzahl} Rechnungen, '
          '${chf(l.brutto)}',
  ];
}

/// Kennzahlen aus den Saldi per 31.12.[jahr] ([saldiJahr]) und per
/// 31.12. des Vorjahrs ([saldiVorjahr]) — beide aus
/// `BilanzService.saldiPerStichtag`, also kumuliert seit Buchhaltungsbeginn.
///
/// [bussen8900] = `bussenAuf8900(journal, jahr)`: Steuerbussen auf 8900
/// lassen sich im Saldo nicht von den Steuern trennen (dafür braucht es
/// die `steuerart` der Buchung) und kommen darum von aussen dazu.
JahresrechnungKennzahlen kennzahlenAus({
  required int jahr,
  required Map<int, double> saldiJahr,
  required Map<int, double> saldiVorjahr,
  double bussen8900 = 0,
  required List<AbschreibungLauf> laeufe,
  double aufrechnungenManuell = 0,
  String? ereignisse,
}) {
  double s(int konto) => saldiJahr[konto] ?? 0;
  final vortrag = BilanzService.kumuliertesErgebnis(saldiVorjahr);
  final bussen = kKontenBussen.fold<double>(
    bussen8900,
    (sum, k) => sum + s(k) - (saldiVorjahr[k] ?? 0),
  );
  return JahresrechnungKennzahlen(
    jahr: jahr,
    gewinn: rundeAufRappen(
      BilanzService.kumuliertesErgebnis(saldiJahr) - vortrag,
    ),
    gewinnvortrag: rundeAufRappen(vortrag),
    stammkapital: rundeAufRappen(-s(2800)),
    debitoren: rundeAufRappen(s(1100)),
    delkredere: rundeAufRappen(-s(1109)),
    rueckstellung: rundeAufRappen(-s(2208)),
    bank: rundeAufRappen(s(1020)),
    kasse: rundeAufRappen(s(1000)),
    aufrechnungenAuto: rundeAufRappen(bussen),
    aufrechnungenManuell: rundeAufRappen(aufrechnungenManuell),
    abschreibungen: abschreibungsZeilen(jahr, laeufe),
    abschreibungNachStichtag: laeufe.any(
      (l) => l.geschaeftsjahr == jahr && l.gebucht && l.mwstJahr > jahr,
    ),
    ereignisse: (ereignisse == null || ereignisse.trim().isEmpty)
        ? null
        : ereignisse.trim(),
  );
}
