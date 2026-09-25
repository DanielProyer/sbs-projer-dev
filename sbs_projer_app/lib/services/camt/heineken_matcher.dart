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

/// Warum eine Bankzahlung die (frisch gelesene) Heineken-Rechnung [r]
/// NICHT auf «bezahlt» setzen darf — `null` = darf.
String? heinekenSperrgrund(Rechnung? r) {
  if (r == null) return 'Heineken-Rechnung nicht mehr vorhanden — nicht gebucht.';
  if (heinekenZahlbar(r)) return null;
  final nr = r.rechnungsnummer ?? r.id;
  if (r.zahlungsstatus == 'bezahlt') {
    return 'Heineken-Rechnung $nr ist schon bezahlt — nicht gebucht.';
  }
  return 'Heineken-Rechnung $nr ist nicht freigegeben '
      '(Status «${r.zahlungsstatus}») — erst freigeben, dann Zahlung buchen.';
}

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

/// Abbruch, wenn eine bestätigte Heineken-Zahlung beim Buchen nicht mehr
/// zahlbar ist. `toString` ist die Meldung selbst — sie landet über
/// `kurzeFehlermeldung` direkt in der Snackbar, ohne «Bad state:».
class HeinekenZahlungGesperrt implements Exception {
  final String grund;
  const HeinekenZahlungGesperrt(this.grund);
  @override
  String toString() => grund;
}
