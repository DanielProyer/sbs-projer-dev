/// MwSt-Normalsatz einer Leistung — immer **pro Aufruf** ermittelt.
///
/// Bis Runde 4 (26.09.2026) hielten `RechnungService`, `JahresrechnungService`,
/// `ReinigungBuchungService` und `HeinekenRechnungService` den Satz in einem
/// statischen Feld: ein Aufruf setzte ihn, der nächste las ihn. Liefen zwei
/// Reinigungen mit verschiedenem Datum (7.7 % bis 2023, 8.1 % ab 2024)
/// nacheinander oder gleichzeitig, konnte der Satz der jeweils anderen gelten.
/// Heute holt jeder Aufruf den Satz selbst und reicht ihn als Argument an die
/// reinen Rechenfunktionen weiter.
library;

/// Rückfall, wenn für ein Datum keine Preisliste existiert (Normalsatz ab
/// 01.01.2024). Die **einzige** Stelle im Code, an der dieser Wert steht —
/// als Prozent `kMwstFaktorFallback * 100` (ergibt exakt 8.1).
const double kMwstFaktorFallback = 0.081;

/// Ein MwSt-Satz in beiden Schreibweisen, wie er in Rechnungen landet:
/// [prozent] für `mwst_satz` der Positionen (8.1), [faktor] zum Rechnen
/// (0.081).
class MwstAngabe {
  final double prozent;
  final double faktor;

  const MwstAngabe({required this.prozent, required this.faktor});

  /// Der Rückfall-Satz ([kMwstFaktorFallback]).
  static const fallback = MwstAngabe(
    prozent: kMwstFaktorFallback * 100,
    faktor: kMwstFaktorFallback,
  );

  /// Anzeige wie `Preis.mwstLabel`, z. B. «8.1%».
  String get label => '${prozent.toStringAsFixed(1)}%';
}

/// Satz einer **gespeicherten** Rechnung/Reinigung für die Anzeige («8.1»),
/// aus ihren Beträgen abgeleitet — so zeigt eine Rechnung von 2023 7.7 statt
/// eines fest eingetragenen 8.1. Ohne Netto gilt der Rückfall.
String mwstProzentAusBetraegen(double netto, double mwst) =>
    (netto > 0 ? mwst / netto * 100 : kMwstFaktorFallback * 100)
        .toStringAsFixed(1);
