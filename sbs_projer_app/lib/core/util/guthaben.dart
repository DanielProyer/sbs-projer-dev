/// Kundenguthaben (Konto 2030) — reine Logik, testbar.
///
/// Eine Überzahlung wird als Soll 1020 / Haben 2030 gebucht, `beleg_id` =
/// die überzahlte Rechnung. Verrechnet wird das Guthaben bei der nächsten
/// Kundenrechnung desselben Betriebs (Plan 2026-09-25-kundenguthaben).
library;

import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
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

/// Abzug für eine neue Rechnung: min(guthaben, brutto), auf 5 Rappen,
/// nie negativ.
double guthabenAbzug({required double guthaben, required double brutto}) {
  if (guthaben <= 0 || brutto <= 0) return 0;
  final gerundet = rundeAuf5Rappen(guthaben);
  final abzug = gerundet < brutto ? gerundet : brutto;
  return abzug < 0 ? 0 : abzug;
}
