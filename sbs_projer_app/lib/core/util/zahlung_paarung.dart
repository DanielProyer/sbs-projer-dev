// Paarung von Zahlungseingängen mit Forderungen bei Mehrfachauswahl.

/// Ordnet Zahlungen und Forderungen paarweise zu: **neueste Zahlung zur
/// neuesten Forderung**, dann die zweitneueste zur zweitneuesten und so fort
/// (Regel Daniel 28.07.2026).
///
/// Vorher trugen alle Rechnungen einer Sammelzahlung die Werte der zuerst
/// markierten Zahlung — Datum und camt-Schlüssel inbegriffen. Bei Zahlungen
/// von verschiedenen Tagen stand damit an einer Rechnung ein Datum, an dem sie
/// gar nicht bezahlt wurde.
///
/// Gibt je Forderung (Schlüssel = Forderungs-Id) die zugeordnete Zahlung
/// zurück. Sind es mehr Forderungen als Zahlungen, erhalten die übrigen — die
/// ältesten — die älteste Zahlung: Sie wurden mit demselben Geldeingang
/// beglichen.
Map<String, T> paareNachDatum<T>({
  required List<T> zahlungen,
  required DateTime Function(T) datumVon,
  required List<({String id, DateTime rechnungsdatum})> forderungen,
}) {
  if (zahlungen.isEmpty || forderungen.isEmpty) return {};

  final sortierteZahlungen = [...zahlungen]
    ..sort((a, b) => datumVon(b).compareTo(datumVon(a)));
  final sortierteForderungen = [...forderungen]
    ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));

  final ergebnis = <String, T>{};
  for (var i = 0; i < sortierteForderungen.length; i++) {
    ergebnis[sortierteForderungen[i].id] = i < sortierteZahlungen.length
        ? sortierteZahlungen[i]
        : sortierteZahlungen.last;
  }
  return ergebnis;
}
