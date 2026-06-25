import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

/// Liefert die für das Rechnungs-/Mahnungs-PDF zu verwendende Rechnungsadresse:
/// Ein pro-Rechnung gesetzter [override] (siehe `Rechnung.rechnungsadresse`) hat
/// Vorrang vor der Stamm-Rechnungsadresse des Betriebs [betriebAdresse].
/// Reine Funktion — testbar, ohne IO.
BetriebRechnungsadresse? effektiveRechnungsadresse(
  Map<String, dynamic>? override,
  BetriebRechnungsadresse? betriebAdresse, {
  String betriebId = '',
}) {
  if (override == null || override.isEmpty) return betriebAdresse;
  return BetriebRechnungsadresse.fromAdressSnapshot(override,
      betriebId: betriebId);
}
