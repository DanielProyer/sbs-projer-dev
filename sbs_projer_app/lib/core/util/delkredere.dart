/// Delkredere (pauschale Wertberichtigung auf Debitoren, Konto 1109):
/// Zielwert und Korrekturbuchung — reine Logik für die Abschlussprüfung
/// (`DelkredereRegel`) und `AbschreibungService.delkredereSetzenPerStichtag`.
library;

import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

/// Pauschalsatz Inland, steuerlich üblich anerkannt (Abschluss 2025).
const kDelkredereSatz = 0.05;

/// Soll-Delkredere zu [debitoren]: 5 %, auf Rappen; ohne Debitoren 0.
double delkredereZiel(double debitoren) =>
    debitoren <= 0 ? 0 : rundeAufRappen(debitoren * kDelkredereSatz);

/// Buchung, die das Delkredere von [bisher] (positive Wertberichtigung) auf
/// [delkredereZiel] von [debitoren] bringt: [aufbau] = 3805 an 1109, sonst
/// 1109 an 3805. [betrag] < 0.01 heisst «nichts zu buchen».
({double betrag, bool aufbau}) delkredereBuchung({
  required double debitoren,
  required double bisher,
}) {
  final diff = rundeAufRappen(delkredereZiel(debitoren) - bisher);
  return (betrag: diff.abs(), aufbau: diff > 0);
}

/// Debitoren (1100), bisheriges Delkredere (−1109) und Ziel per 31.12.
/// [jahr] aus dem Journal — dieselben Saldi, die die Abschlussprüfung für
/// ein abgeschlossenes Jahr nimmt (`AbschlussKontext.saldiPer`, Stichtag
/// 31.12.).
({double debitoren, double wertberichtigung, double ziel}) delkredereStichtag(
  List<Buchung> journal,
  int jahr,
) {
  final saldi = BilanzService.saldiPerStichtag(
    journal.map(BuchungSaldo.ausBuchung).toList(),
    DateTime(jahr, 12, 31),
  );
  final debitoren = rundeAufRappen(saldi[1100] ?? 0);
  // 1109 ist Klasse 1 → Roh-Saldo Soll − Haben; die Wertberichtigung steht
  // im Haben und erscheint negativ.
  final wertberichtigung = rundeAufRappen(-(saldi[1109] ?? 0));
  return (
    debitoren: debitoren,
    wertberichtigung: wertberichtigung,
    ziel: delkredereZiel(debitoren),
  );
}
