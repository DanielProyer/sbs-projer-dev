/// Schweizer Rundung für Rechnungsbeträge.
///
/// **Regel (Daniel, 15.07.2026):** Kundenrechnungen sind IMMER auf 5 Rappen
/// gerundet. Einzige Ausnahme ist die Heineken-Monatsrechnung — dort wird
/// ungerundet fakturiert, die MwSt kommt erst auf den Gesamtbetrag.
///
/// Warum das zentral gehört: Die Rundung war über fünf Dateien dupliziert und
/// wurde ausgerechnet erst bei der ANZEIGE angewandt. Gespeichert war 74.59,
/// angezeigt 74.60 — der Fehler blieb dadurch monatelang unsichtbar und liess
/// den camt-Betragsabgleich ins Leere laufen. Gerundet wird deshalb dort, wo
/// der Betrag entsteht, nicht dort, wo er angezeigt wird.
library;

/// Rundet auf 5 Rappen (0.05) kaufmännisch.
double rundeAuf5Rappen(double v) => (v * 20).roundToDouble() / 20;

/// Rundet auf Rappen (0.01) kaufmännisch.
double rundeAufRappen(double v) => (v * 100).roundToDouble() / 100;

/// Bruttobetrag einer Kundenrechnung aus dem Netto: auf 5 Rappen gerundet.
/// [mwstFaktor] ist der Satz als Faktor (8.1% → 0.081).
double bruttoKundenrechnung(double netto, double mwstFaktor) =>
    rundeAuf5Rappen(netto * (1 + mwstFaktor));

/// Liegt der Betrag exakt auf 5 Rappen? (Für Prüfungen/Tests.)
bool istAuf5Rappen(double v) => (v * 20) == (v * 20).roundToDouble();
