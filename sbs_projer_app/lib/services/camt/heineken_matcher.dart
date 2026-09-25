import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Darf eine Bankgutschrift diese Heineken-Monatsrechnung auf «bezahlt»
/// setzen? Nur wenn sie **freigegeben** ist.
///
/// WARUM nicht schon ab `gesendet`: Erst die Freigabe bucht Debitor und
/// Ertrag (1100/3400). Setzt die Bank eine erst gesendete Rechnung direkt
/// auf «bezahlt», wird die Freigabe übersprungen — die Ertragsbuchung
/// entsteht dann nie, und 1100 läuft ins Minus (R3, App-Analyse 25.09.2026).
/// Eine gesendete Rechnung bleibt deshalb in der Prüfliste, bis sie
/// freigegeben ist.
bool heinekenZahlbar(Rechnung r) =>
    r.rechnungstyp == 'heineken_monat' && r.zahlungsstatus == 'freigegeben';

class HeinekenMatcher {
  /// Liefert die eindeutige zahlbare Heineken-Monatsrechnung
  /// ([heinekenZahlbar]) mit passendem Bruttobetrag, sonst null (→ Prüfliste).
  static Rechnung? match({
    required double zahlbetrag,
    required List<Rechnung> heinekenRechnungen,
  }) {
    int rappen(double v) => (v * 20).round();
    final ziel = rappen(zahlbetrag);
    final passende = heinekenRechnungen
        .where(heinekenZahlbar)
        .where((r) => rappen(r.betragBrutto) == ziel)
        .toList();
    return passende.length == 1 ? passende.first : null;
  }
}
