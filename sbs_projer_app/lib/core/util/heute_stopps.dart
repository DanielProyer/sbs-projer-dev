import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Gilt der Stopp [e] als erledigt?
///
/// Reinigungen über ihre Anlagen: erledigt ist ein Besuch erst, wenn **alle**
/// gebündelten Anlagen an diesem Tag gereinigt wurden. Wäre schon eine genug,
/// verschwände ein halb erledigter Besuch aus der Liste und die restlichen
/// Anlagen mit ihm — derselbe Fehlertyp, der am 03./04.09.2026 zwei
/// Ertragsbuchungen gekostet hat.
///
/// Störungen und Montagen über ihre Einsatz-Id, weil sie ihren Status am
/// Einsatz selbst tragen.
bool stoppErledigt(
  TourEintrag e, {
  required Set<String> gereinigteAnlageIds,
  required Set<String> erledigteEinsatzIds,
}) {
  if (e.typ == TourEintragTyp.reinigung) {
    final anlagen = e.anlageIds.isNotEmpty
        ? e.anlageIds
        : [if (e.anlageId != null) e.anlageId!];
    // Ohne Anlagenbezug lässt sich nichts abgleichen — dann lieber stehen
    // lassen als fälschlich abhaken.
    if (anlagen.isEmpty) return false;
    return anlagen.every(gereinigteAnlageIds.contains);
  }
  return erledigteEinsatzIds.contains(e.id);
}

/// Die offenen Stopps des Tages, in der Reihenfolge des Plans.
List<TourEintrag> offeneStopps({
  required List<TourEintrag> plan,
  required Set<String> gereinigteAnlageIds,
  required Set<String> erledigteEinsatzIds,
}) => [
      for (final e in plan)
        if (!stoppErledigt(e,
            gereinigteAnlageIds: gereinigteAnlageIds,
            erledigteEinsatzIds: erledigteEinsatzIds))
          e,
    ];

/// Zähler für die Kopfzeile: «3 von 10».
({int erledigt, int gesamt}) erledigtZaehler({
  required List<TourEintrag> plan,
  required Set<String> gereinigteAnlageIds,
  required Set<String> erledigteEinsatzIds,
}) {
  final offen = offeneStopps(
    plan: plan,
    gereinigteAnlageIds: gereinigteAnlageIds,
    erledigteEinsatzIds: erledigteEinsatzIds,
  ).length;
  return (erledigt: plan.length - offen, gesamt: plan.length);
}
