/// Ein Start-Weg für einen Stopp aus dem Tagesplan (V3/V4/V10, Runde 5).
///
/// Bis v0.143.0 stand die Start-Logik dreimal (Heute, Tourenplan-Block,
/// Diktat) — und alle Kopien hatten denselben Fehler: Der Start einer
/// **geplanten** Störung oder Montage öffnete `/stoerungen/neu`, also ein
/// neues Formular statt des geplanten Einsatzes. Folge: eine doppelte
/// Störung, die neue sofort «erledigt», und der geplante Stopp blieb in Heute
/// ewig offen, weil «erledigt» am Status des ALTEN Einsatzes hängt
/// (`erledigteEinsatzIdsProvider`). Ausserdem musste Daniel bei Saison-
/// Reinigungen die Service-Art jedes Mal von Hand umstellen.
///
/// Rein (keine Flutter-/Provider-Abhängigkeit), damit jede Route getestet ist.
/// `test/einsatz_start_waechter_test.dart` hält die Aufrufer auf diesem Weg.
library;

import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Die Einsatz-Id eines geplanten Stopps, sonst `null`.
///
/// Stopps aus offenen Störungen tragen `s_<routeId>`, Montagen und HeiGenie
/// `m_<routeId>` (beide aus der `montagen`-Tabelle, siehe
/// `tourEintraegeProvider` in `tour_providers.dart`). Andere Ids — `u_…` aus
/// einer Plan-Übernahme, `hist_…`, `r_…` — zeigen auf keinen Einsatz, den man
/// öffnen könnte.
String? geplanteEinsatzId(TourEintrag e) {
  final praefix = switch (e.typ) {
    TourEintragTyp.stoerung => 's_',
    TourEintragTyp.montage || TourEintragTyp.heigenie => 'm_',
    TourEintragTyp.reinigung => null,
  };
  if (praefix == null || !e.id.startsWith(praefix)) return null;
  final id = e.id.substring(praefix.length);
  return id.isEmpty ? null : id;
}

/// Service-Art des Reinigungsformulars (Werte aus dessen Dropdown), die ein
/// Saison-Stopp vorgibt — `null` für eine gewöhnliche Reinigung (das Formular
/// bleibt dann bei `standardservice`).
String? serviceArtAusPlan(TourEintrag e) => switch (e.faelligkeit) {
  FaelligkeitsStatus.eroeffnungFaellig => 'eroeffnungsservice',
  FaelligkeitsStatus.endreinigungFaellig => 'endreinigung',
  _ => null,
};

/// Route, die den Stopp [e] beginnt.
///
/// - Reinigung → `/reinigungen/neu` mit Betrieb, gebündelten Anlagen, der
///   Service-Art eines Saison-Stopps und [notiz] (z.B. ein Diktat).
/// - Störung/Montage/HeiGenie mit geplantem Einsatz → dessen Formular
///   (`/…/<id>/bearbeiten`, dort steht «Arbeit beginnen»).
/// - ohne geplanten Einsatz → ein neues Formular für den Betrieb.
String startRoute(TourEintrag e, {String? notiz}) {
  final notizTeil = (notiz != null && notiz.trim().isNotEmpty)
      ? '&notiz=${Uri.encodeQueryComponent(notiz.trim())}'
      : '';
  switch (e.typ) {
    case TourEintragTyp.reinigung:
      if (e.betriebId == null) return '/reinigungen/neu';
      final ids = e.anlageIds.isNotEmpty
          ? e.anlageIds
          : [if (e.anlageId != null) e.anlageId!];
      final anlagenTeil = ids.isEmpty ? '' : '&anlageIds=${ids.join(',')}';
      final art = serviceArtAusPlan(e);
      final artTeil = art == null ? '' : '&serviceArt=$art';
      return '/reinigungen/neu?betriebId=${e.betriebId}'
          '$anlagenTeil$artTeil$notizTeil';
    case TourEintragTyp.stoerung:
    case TourEintragTyp.montage:
    case TourEintragTyp.heigenie:
      final basis = e.typ == TourEintragTyp.stoerung
          ? '/stoerungen'
          : '/montagen';
      final geplant = geplanteEinsatzId(e);
      if (geplant != null) return '$basis/$geplant/bearbeiten';
      if (e.betriebId == null) return '$basis/neu';
      final anlageTeil = e.anlageId != null ? '&anlageId=${e.anlageId}' : '';
      if (e.typ == TourEintragTyp.stoerung) {
        return '/stoerungen/neu?betriebId=${e.betriebId}$anlageTeil';
      }
      return '/montagen/neu?betriebId=${e.betriebId}$anlageTeil';
  }
}
