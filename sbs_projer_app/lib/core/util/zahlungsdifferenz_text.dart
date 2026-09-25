import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';

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

  /// Hinweis zum Kundenguthaben (Konto 2030) oder leer (v0.137.0).
  final String guthabenHinweis;

  const DifferenzInfo(this.art, this.betrag, this.istBagatelle,
      {this.guthabenHinweis = ''});

  bool get istMinder => art == DifferenzArt.minder;
  bool get istKeine => art == DifferenzArt.keine;

  /// Etwas anzuzeigen? Auch ohne Differenz, wenn Guthaben im Spiel ist.
  bool get zeigen => !istKeine || guthabenHinweis.isNotEmpty;

  String get text {
    final diff = _differenzText;
    if (guthabenHinweis.isEmpty) return diff;
    if (diff.isEmpty) return guthabenHinweis;
    return '$diff. $guthabenHinweis';
  }

  String get _differenzText {
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
///
/// [forderung] = Summe «zu zahlen» der gewählten Rechnungen, [guthaben] =
/// Summe ihres verrechneten Kundenguthabens. Zahlt der Kunde trotz Guthaben
/// den vollen Betrag, wird nicht verrechnet und gegen das Brutto verglichen
/// — dieselbe Regel wie beim Buchen ([guthabenWirdVerrechnet]).
DifferenzInfo bewerteDifferenz(double zahlung, double forderung,
    {double guthaben = 0}) {
  if (forderung <= 0 || zahlung <= 0) {
    return const DifferenzInfo(DifferenzArt.keine, 0, false);
  }
  var hinweis = '';
  var vergleich = forderung;
  if (guthaben > 0) {
    final g = guthaben.toStringAsFixed(2);
    if (guthabenWirdVerrechnet(
        zahlung: zahlung, summeZuZahlen: forderung, summeGuthaben: guthaben)) {
      hinweis = 'Kundenguthaben CHF $g wird verrechnet '
          '($kKontoKundenguthaben)';
    } else {
      vergleich = forderung + guthaben;
      hinweis = 'Zahlung deckt den vollen Betrag — Kundenguthaben CHF $g '
          'wird nicht verrechnet und bleibt bestehen';
    }
  }
  final diff = ((zahlung - vergleich) * 20).roundToDouble() / 20;
  if (diff.abs() < 0.01) {
    return DifferenzInfo(DifferenzArt.keine, 0, false,
        guthabenHinweis: hinweis);
  }
  if (diff < 0) {
    final betrag = double.parse(diff.abs().toStringAsFixed(2));
    return DifferenzInfo(
        DifferenzArt.minder, betrag, betrag <= kBagatellGrenze,
        guthabenHinweis: hinweis);
  }
  return DifferenzInfo(
      DifferenzArt.mehr, double.parse(diff.toStringAsFixed(2)), false,
      guthabenHinweis: hinweis);
}
