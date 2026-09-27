// Gemessene Ist-Zeiten je Tagesplan-Eintrag — geteilt von der Zeitachse
// (erledigte Blöcke laufen mit echten Zeiten) und vom Verschieben eines
// ganzen Tages (erledigte Stopps bleiben am alten Tag, Daniel 26.09.2026).
// Die Schlüssel der Ergebnis-Map sind damit zugleich «die erledigten ids».

import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Erfasste Arbeitszeit eines Einsatzes (Minuten ab Mitternacht) samt dem
/// Kalendertag des Einsatzes ([tag] = sein `datum`). Die Zeiten gelten nur
/// an diesem Tag — siehe [ermittleIstZeiten].
typedef EinsatzArbeitszeit = ({DateTime tag, int von, int bis});

/// Ermittelt die Ist-Zeiten (Minuten ab Mitternacht) der Einträge von
/// [datum]. Ohne [erledigtePruefen] (künftiger Tag) bleibt die Map leer.
///
/// - Reinigungs-Besuch erledigt = am Plantag abgeschlossene Reinigung
///   desselben Betriebs mit brauchbaren Zeiten.
/// - `hist_`-Einträge (tatsächliche Reinigungen vergangener Tage) matchen
///   exakt über ihre Reinigungs-Id — zwei Besuche am selben Betrieb behalten
///   so je ihre eigenen Zeiten.
/// - Störung/Montage erledigt = erfasste Arbeitszeit `arbeit_von/bis` aus
///   [arbeitszeiten] (Schlüssel = Plan-Id `s_<id>`/`m_<id>`, Werte aus
///   [arbeitszeitMinuten]) — NUR wenn der Einsatz an [datum] stattfand.
///   Steht er noch im Plan eines anderen Tages (Entfernen nach dem
///   Abschluss gescheitert, alter Plan), zeichnete die Zeitachse sonst
///   dort die Uhrzeiten eines fremden Tages (Review K4, 27.09.2026).
///   Nur ohne sie der Rückfall auf den Wegpunkt-
///   Stempel desselben Betriebs am Tag: Der Stempel markiert das ENDE, als
///   Start dient Stempel minus Dauer — eine Schätzung, die danebenliegt,
///   wenn der Stempel erst abends zuhause entstand (seit 27.09.2026 fragt
///   das Formular beim Abschliessen nach der Zeit).
Map<String, ({int von, int bis})> ermittleIstZeiten({
  required List<TourEintrag> eintraege,
  required DateTime datum,
  required bool erledigtePruefen,
  required List<ReinigungLocal> reinigungen,
  required List<WegpunktTag> wegpunkte,
  required Map<String, EinsatzArbeitszeit> arbeitszeiten,
  required int Function(TourEintrag) dauerFuer,
}) {
  final istZeiten = <String, ({int von, int bis})>{};
  if (!erledigtePruefen) return istZeiten;

  bool amPlantag(DateTime d) =>
      d.year == datum.year && d.month == datum.month && d.day == datum.day;

  final heutigeJeBetrieb = <String, ({int von, int bis})>{};
  final jeReinigung = <String, ({int von, int bis})>{};
  for (final r in reinigungen) {
    if (r.status != 'abgeschlossen' || r.betriebId.isEmpty) continue;
    if (!amPlantag(r.datum)) continue;
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
      final erfasst = arbeitszeiten[e.id];
      if (erfasst != null && amPlantag(erfasst.tag)) {
        istZeiten[e.id] = (von: erfasst.von, bis: erfasst.bis);
        continue;
      }
      // Ohne erfasste Arbeitszeit — grobe, aber ehrliche Annahme über die
      // geplante Dauer.
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

/// `arbeit_von/bis` ('HH:mm' oder 'HH:mm:ss') → Minuten ab Mitternacht;
/// `null`, wenn eine Zeit fehlt oder das Ende nicht nach dem Beginn liegt
/// (über Mitternacht — dann bleibt der Stempel-Rückfall).
({int von, int bis})? arbeitszeitMinuten(String? von, String? bis) {
  final v = minutenAusHhmm(von), b = minutenAusHhmm(bis);
  if (v == null || b == null || b <= v) return null;
  return (von: v, bis: b);
}
