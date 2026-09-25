/// Kundenguthaben (Konto 2030) — reine Logik, testbar.
///
/// Eine Überzahlung wird als Soll 1020 / Haben 2030 gebucht, `beleg_id` =
/// die überzahlte Rechnung. Verrechnet wird das Guthaben bei der nächsten
/// Kundenrechnung desselben Betriebs (Plan 2026-09-25-kundenguthaben).
library;

import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

/// Konto für Kundenguthaben (Überzahlungen).
const int kKontoKundenguthaben = 2030;

/// Offenes Guthaben je Betrieb aus Buchungen auf 2030:
/// Haben 2030 = Guthaben entstanden, Soll 2030 = verrechnet/ausbezahlt.
/// [betriebVonRechnung]: beleg_id (Rechnung) → betrieb_id.
///
/// Stornierte Buchungen und Storno-Gegenbuchungen zählen nicht
/// (`zaehltFuerSaldo`). Buchungen ohne `beleg_id` oder ohne bekannte
/// Rechnung landen unter dem Schlüssel `''`, damit eine Übersicht sie
/// melden kann, statt sie still zu verlieren.
Map<String, double> offenesGuthabenJeBetrieb(
  List<Buchung> buchungen2030,
  Map<String, String> betriebVonRechnung,
) {
  final summe = <String, double>{};
  for (final b in buchungen2030) {
    if (!zaehltFuerSaldo(
      istStorniert: b.istStorniert,
      stornoVonId: b.stornoVonId,
    )) {
      continue;
    }
    if (b.habenKonto != kKontoKundenguthaben &&
        b.sollKonto != kKontoKundenguthaben) {
      continue;
    }
    var wert = 0.0;
    if (b.habenKonto == kKontoKundenguthaben) wert += b.betragBrutto;
    if (b.sollKonto == kKontoKundenguthaben) wert -= b.betragBrutto;
    final betrieb = b.belegId == null ? null : betriebVonRechnung[b.belegId];
    final schluessel = betrieb ?? '';
    summe[schluessel] = (summe[schluessel] ?? 0) + wert;
  }
  // Rundungsrauschen aus Double-Summen entfernen.
  return summe.map((k, v) => MapEntry(k, (v * 100).roundToDouble() / 100));
}

/// Abzug für eine neue Rechnung: min(guthaben, brutto), auf 5 Rappen
/// **ab**gerundet (nie mehr verrechnen als vorhanden: 30.03 → 30.00),
/// nie negativ.
double guthabenAbzug({required double guthaben, required double brutto}) {
  if (guthaben <= 0 || brutto <= 0) return 0;
  // Kleiner Zuschlag gegen Double-Rauschen (30.05 * 20 = 600.9999…).
  final gerundet = (guthaben * 20 + 1e-6).floorToDouble() / 20;
  final abzug = gerundet < brutto ? gerundet : brutto;
  return abzug < 0 ? 0 : abzug;
}

/// Verfügbares Guthaben für eine NEUE Rechnung: Saldo 2030 des Betriebs
/// minus das Guthaben, das offene Rechnungen schon reserviert haben.
///
/// WARUM: Das Guthaben verlässt 2030 erst, wenn die Verrechnungsbuchung
/// (2030/1100) steht — also beim Zahlungseingang. Bis dahin zeigt der Saldo
/// das volle Guthaben, und die nächste Rechnung würde es ein zweites Mal
/// abziehen (Review Kundenguthaben, C1).
///
/// Reserviert = Rechnung weder bezahlt noch abgeschrieben, mit
/// `guthabenVerrechnet > 0` und OHNE aktive Verrechnungsbuchung
/// ([verrechneteIds] = beleg_ids dieser Buchungen). Filter in Dart, nie
/// per `.neq` in der Abfrage (NULL-Falle).
double verfuegbaresGuthaben(
  double saldo,
  List<Rechnung> offeneRechnungen,
  Set<String> verrechneteIds,
) {
  var reserviert = 0.0;
  for (final r in offeneRechnungen) {
    if (r.zahlungsstatus == 'bezahlt' || r.zahlungsstatus == 'abgeschrieben') {
      continue;
    }
    if (r.guthabenVerrechnet <= 0 || verrechneteIds.contains(r.id)) continue;
    reserviert += r.guthabenVerrechnet;
  }
  final rest = ((saldo - reserviert) * 100).roundToDouble() / 100;
  return rest < 0 ? 0 : rest;
}
