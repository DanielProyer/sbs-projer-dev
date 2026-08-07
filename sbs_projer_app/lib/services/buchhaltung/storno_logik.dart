/// Reine Storno-Logik (Reparatur B6, Buchhaltungsprüfung 06.08.2026).
///
/// Modell: Ein Storno nimmt Original UND Gegenbuchung aus allen
/// Saldo-Berechnungen (Ausschluss-Modell, wie `BilanzService.saldiPerStichtag`
/// seit v0.16.15). Die Gegenbuchung bleibt als Journal-Beleg stehen
/// (GeBüV-Nachvollziehbarkeit), rechnet aber nirgends mit.
library;

import 'package:sbs_projer_app/data/models/buchung.dart';

/// Zählt diese Buchung in Salden/Auswertungen?
/// Stornierte Originale UND Storno-Gegenbuchungen zählen nicht.
bool zaehltFuerSaldo({required bool istStorniert, String? stornoVonId}) =>
    !istStorniert && stornoVonId == null;

/// Baut die Gegenbuchung zum [original] (als Insert-Map).
///
/// - **Datum = Original-Datum** (B6.2): Ein Storno korrigiert die Periode des
///   Originals, nicht die heutige — sonst verfälscht er zwei Perioden.
/// - **Kein `mwst_konto`** (B6.1): Die Original-MwSt verschwindet durch den
///   Ausschluss des Originals; eine Gegenbuchung mit kopiertem `mwst_konto`
///   würde in der MWST-View (Filter `mwst_konto IS NOT NULL`) fälschlich
///   nochmals auftauchen.
/// - Beträge werden 1:1 dokumentiert (Invariante brutto = netto + mwst bleibt
///   erhalten, `SaldoExpansion`-Assert sicher).
Map<String, dynamic> gegenbuchungFuer(Buchung original) {
  final datumStr = original.datum.toIso8601String().split('T').first;
  return {
    'datum': datumStr,
    'belegnummer':
        'STORNO-${original.belegnummer ?? original.id.substring(0, 8)}',
    'vorlage_id': original.vorlageId,
    'soll_konto': original.habenKonto,
    'haben_konto': original.sollKonto,
    'mwst_konto': null,
    'betrag_netto': original.betragNetto,
    'mwst_satz': original.mwstSatz,
    'mwst_betrag': original.mwstBetrag,
    'betrag_brutto': original.betragBrutto,
    'beschreibung': 'Storno: ${original.beschreibung}',
    'zahlungsweg': original.zahlungsweg,
    'belegordner': original.belegordner,
    'beleg_typ': original.belegTyp,
    'beleg_id': original.belegId,
    // Geschäftsjahr aus dem Original-DATUM — die Gegenbuchung gehört in die
    // Periode des Originals (B6.2), nicht ins Jahr des Storno-Klicks.
    'geschaeftsjahr': original.datum.year,
    'storno_von_id': original.id,
    'notizen': 'Stornierung von Buchung ${original.belegnummer ?? original.id}',
  };
}

/// Gehört [kandidat] als MwSt-Trennbuchung zum [original] und muss beim
/// Storno mitgenommen werden (B6.3)? Trennbuchungen (beleg_typ 'mwst')
/// desselben Belegs vom selben Tag — Zahlungen und fremde Belege nie.
bool istZugehoerigeTrennbuchung(
    {required Buchung original, required Buchung kandidat}) {
  if (original.belegTyp == 'mwst') return false; // Trennbuchung zieht nichts nach
  if (kandidat.id == original.id) return false;
  if (kandidat.belegTyp != 'mwst') return false;
  if (kandidat.istStorniert || kandidat.stornoVonId != null) return false;
  if (original.belegId == null || kandidat.belegId != original.belegId) {
    return false;
  }
  return kandidat.datum.year == original.datum.year &&
      kandidat.datum.month == original.datum.month &&
      kandidat.datum.day == original.datum.day;
}
