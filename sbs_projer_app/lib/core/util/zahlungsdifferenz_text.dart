// Plausibilitätsprüfungen einer Zahlungszuordnung im camt-Abgleich:
// Betragsdifferenz (Minder-/Mehrzahlung) und Datumsfolge.

/// Rechnungen, die NACH dem Zahlungseingang ausgestellt wurden — die konnte
/// der Kunde damals noch gar nicht bezahlen. Deutet fast immer auf einen
/// Fehlgriff in der Liste hin (Fall Marsöl 28.07.2026: Zahlung vom 25.03. auf
/// eine Rechnung vom 12.05. gebucht, obwohl ältere offene Posten vorlagen).
///
/// Ein Tag Toleranz, weil Buchungs- und Valutadatum um einen Tag abweichen
/// können. Gibt die betroffenen Bezeichnungen zurück; leer = plausibel.
List<String> rechnungenNachZahlung(
  DateTime zahlungsdatum,
  List<({String bezeichnung, DateTime rechnungsdatum})> forderungen,
) {
  final grenze = zahlungsdatum.add(const Duration(days: 1));
  return [
    for (final f in forderungen)
      if (f.rechnungsdatum.isAfter(grenze)) f.bezeichnung,
  ];
}

enum DifferenzArt { keine, minder, mehr }

class DifferenzInfo {
  final DifferenzArt art;

  /// Immer positiv — die Richtung steckt in [art].
  final double betrag;

  /// Kleinbetrag, den Daniel nicht nachfordert (Rundung, Spesenabzug).
  final bool istBagatelle;

  const DifferenzInfo(this.art, this.betrag, this.istBagatelle);

  bool get istMinder => art == DifferenzArt.minder;
  bool get istKeine => art == DifferenzArt.keine;

  String get text {
    switch (art) {
      case DifferenzArt.keine:
        return '';
      case DifferenzArt.minder:
        final basis = 'Minderzahlung CHF ${betrag.toStringAsFixed(2)}';
        return istBagatelle
            ? '$basis — geringe Abweichung, keine Nachforderung. '
                'Wird als Debitorenverlust (3805) gebucht'
            : '$basis — wird als Debitorenverlust (3805) gebucht';
      case DifferenzArt.mehr:
        return 'Mehrzahlung CHF ${betrag.toStringAsFixed(2)} — '
            'wird als a.o. Ertrag (8000) gebucht';
    }
  }
}

/// Bis zu diesem Betrag gilt eine Minderzahlung als Bagatelle.
const double kBagatellGrenze = 1.00;

/// Vergleicht Zahlung und Forderung (5-Rappen-gerundet, wie die Buchung).
///
/// Ohne zugeordnete Forderung gibt es **keine** Differenz: Solange nichts
/// angehakt ist, wäre die Zahlung sonst als Mehrzahlung in voller Höhe
/// ausgewiesen (gemeldet Daniel 28.07.2026, Fall Sartons 74.30).
DifferenzInfo bewerteDifferenz(double zahlung, double forderung) {
  if (forderung <= 0 || zahlung <= 0) {
    return const DifferenzInfo(DifferenzArt.keine, 0, false);
  }
  final diff = ((zahlung - forderung) * 20).roundToDouble() / 20;
  if (diff.abs() < 0.01) {
    return const DifferenzInfo(DifferenzArt.keine, 0, false);
  }
  if (diff < 0) {
    final betrag = double.parse(diff.abs().toStringAsFixed(2));
    return DifferenzInfo(
        DifferenzArt.minder, betrag, betrag <= kBagatellGrenze);
  }
  return DifferenzInfo(
      DifferenzArt.mehr, double.parse(diff.toStringAsFixed(2)), false);
}
