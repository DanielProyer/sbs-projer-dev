import 'package:sbs_projer_app/data/models/rechnung.dart';

class HeinekenMatcher {
  /// Liefert die eindeutige Heineken-Monatsrechnung mit passendem Bruttobetrag,
  /// sonst null (→ Prüfliste).
  static Rechnung? match({
    required double zahlbetrag,
    required List<Rechnung> heinekenRechnungen,
  }) {
    int rappen(double v) => (v * 20).round();
    final ziel = rappen(zahlbetrag);
    final passende = heinekenRechnungen
        .where((r) => r.rechnungstyp == 'heineken_monat')
        .where((r) => r.zahlungsstatus != 'bezahlt')
        .where((r) => rappen(r.betragBrutto) == ziel)
        .toList();
    return passende.length == 1 ? passende.first : null;
  }
}
