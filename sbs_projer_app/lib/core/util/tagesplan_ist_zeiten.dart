// Gemessene Ist-Zeiten je Tagesplan-Eintrag — geteilt von der Zeitachse
// (erledigte Blöcke laufen mit echten Zeiten) und vom Verschieben eines
// ganzen Tages (erledigte Stopps bleiben am alten Tag, Daniel 26.09.2026).
// Die Schlüssel der Ergebnis-Map sind damit zugleich «die erledigten ids».

import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Ermittelt die Ist-Zeiten (Minuten ab Mitternacht) der Einträge von
/// [datum]. Ohne [erledigtePruefen] (künftiger Tag) bleibt die Map leer.
///
/// - Reinigungs-Besuch erledigt = am Plantag abgeschlossene Reinigung
///   desselben Betriebs mit brauchbaren Zeiten.
/// - `hist_`-Einträge (tatsächliche Reinigungen vergangener Tage) matchen
///   exakt über ihre Reinigungs-Id — zwei Besuche am selben Betrieb behalten
///   so je ihre eigenen Zeiten.
/// - Störung/Montage erledigt = Wegpunkt-Stempel desselben Betriebs am Tag;
///   der Stempel markiert das ENDE, als Start dient Stempel minus Dauer.
Map<String, ({int von, int bis})> ermittleIstZeiten({
  required List<TourEintrag> eintraege,
  required DateTime datum,
  required bool erledigtePruefen,
  required List<ReinigungLocal> reinigungen,
  required List<WegpunktTag> wegpunkte,
  required int Function(TourEintrag) dauerFuer,
}) {
  final istZeiten = <String, ({int von, int bis})>{};
  if (!erledigtePruefen) return istZeiten;

  final heutigeJeBetrieb = <String, ({int von, int bis})>{};
  final jeReinigung = <String, ({int von, int bis})>{};
  for (final r in reinigungen) {
    if (r.status != 'abgeschlossen' || r.betriebId.isEmpty) continue;
    if (r.datum.year != datum.year ||
        r.datum.month != datum.month ||
        r.datum.day != datum.day) {
      continue;
    }
    final von = minutenAusHhmm(r.uhrzeitStart);
    final bis = minutenAusHhmm(r.uhrzeitEnde);
    if (von == null || bis == null || bis <= von) continue;
    heutigeJeBetrieb[r.betriebId] = (von: von, bis: bis);
    if (r.serverId != null) {
      jeReinigung[r.routeId] = (von: von, bis: bis);
    }
  }
  for (final e in eintraege) {
    if (e.id.startsWith('hist_')) {
      final ist = jeReinigung[e.id.substring(5)];
      if (ist != null) istZeiten[e.id] = ist;
    } else if (e.typ == TourEintragTyp.reinigung) {
      final ist = e.betriebId != null ? heutigeJeBetrieb[e.betriebId!] : null;
      if (ist != null) istZeiten[e.id] = ist;
    } else {
      // Uhrzeiten werden bei Störung/Montage nicht erfasst — grobe, aber
      // ehrliche Annahme über die geplante Dauer.
      final quelle = e.typ == TourEintragTyp.stoerung ? 'stoerung' : 'montage';
      for (final w in wegpunkte) {
        if (w.quelle != quelle ||
            w.betriebId == null ||
            w.betriebId != e.betriebId) {
          continue;
        }
        final bis = w.zeitpunkt.hour * 60 + w.zeitpunkt.minute;
        final von = (bis - dauerFuer(e)).clamp(0, 1439);
        istZeiten[e.id] = (von: von, bis: bis);
        break;
      }
    }
  }
  return istZeiten;
}
