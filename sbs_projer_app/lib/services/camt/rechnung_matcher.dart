import 'package:sbs_projer_app/data/models/rechnung.dart';

class MatchErgebnis {
  final bool eindeutig;
  final List<Rechnung> rechnungen;
  MatchErgebnis(this.eindeutig, this.rechnungen);
}

class RechnungMatcher {
  static int _cents(double v) => (v * 100).round(); // Rappen (exakt)

  /// Findet die eindeutige Teilmenge offener Rechnungen, deren Summe dem
  /// Zahlbetrag entspricht. Eindeutig = genau eine Kombination passt.
  static MatchErgebnis match({
    required double zahlbetrag,
    required List<Rechnung> offeneRechnungen,
  }) {
    final ziel = _cents(zahlbetrag);
    final items = offeneRechnungen.where((r) => r.betragBrutto > 0).take(20).toList(); // Schutz gegen Kombinatorik
    final treffer = <List<Rechnung>>[];

    void suche(int start, List<Rechnung> akku, int summe) {
      if (summe == ziel && akku.isNotEmpty) { treffer.add(List.of(akku)); return; }
      if (summe > ziel || akku.length >= 4) return;
      for (var i = start; i < items.length; i++) {
        akku.add(items[i]);
        suche(i + 1, akku, summe + _cents(items[i].betragBrutto));
        akku.removeLast();
      }
    }
    suche(0, [], 0);

    if (treffer.length == 1) return MatchErgebnis(true, treffer.first);
    return MatchErgebnis(false, const []);
  }
}
