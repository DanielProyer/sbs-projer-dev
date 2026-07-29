/// Besuchs-Bündelung fürs Übernehmen aus der Fällig-Liste (Spec 2026-07-29 §1).
///
/// Ein Reinigungs-Eintrag im Tagesplan ist ein Besuch beim Betrieb, keine
/// einzelne Anlage. Tippt Daniel eine fällige Anlage in den Plan:
/// - existiert im Plan bereits ein Reinigungs-Besuch desselben Betriebs,
///   werden die neuen Anlagen dort ergänzt statt einen zweiten Block
///   anzulegen (kein doppelter Besuch am selben Tag);
/// - sonst entsteht ein neuer Besuch, der automatisch ALLE heute fälligen
///   Geschwister-Anlagen des Betriebs mitnimmt (nicht nur die angetippte) —
///   sonst müsste Daniel jede Anlage einzeln antippen.
/// Störung/Montage/HeiGenie sind je Eintrag eigenständig und werden immer
/// unverändert angehängt, auch wenn derselbe Betrieb schon einen
/// Reinigungs-Besuch im Plan hat.
library;

import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Anlagen eines Eintrags: `anlageIds` ist führend, `anlageId` das
/// Kompatibilitäts-Altfeld für Einträge, die noch keine Liste tragen.
List<String> _anlagenVon(TourEintrag e) => e.anlageIds.isNotEmpty
    ? e.anlageIds
    : [if (e.anlageId != null) e.anlageId!];

/// Fügt [neu] in [plan] ein. Reine Funktion — mutiert weder [plan] noch
/// [neu]; liefert immer eine neue Liste (der bestehende Plan bleibt
/// unangetastet für den Aufrufer).
List<TourEintrag> buendleInPlan({
  required List<TourEintrag> plan,
  required TourEintrag neu,
  required List<String> faelligeAnlagenDesBetriebs,
}) {
  // Nur Reinigungen sind Besuchs-Blöcke, die gebündelt werden. Störung,
  // Montage und HeiGenie sind eigenständige Termine.
  if (neu.typ != TourEintragTyp.reinigung) {
    return [...plan, neu];
  }

  final neuAnlagen = _anlagenVon(neu);

  final indexBestehend = plan.indexWhere(
    (e) =>
        e.typ == TourEintragTyp.reinigung &&
        neu.betriebId != null &&
        e.betriebId == neu.betriebId,
  );

  if (indexBestehend >= 0) {
    final bestehend = plan[indexBestehend];
    final ergaenzt = [..._anlagenVon(bestehend)];
    for (final id in neuAnlagen) {
      if (!ergaenzt.contains(id)) ergaenzt.add(id);
    }
    final aktualisiert = bestehend.copyWith(
      anlageIds: ergaenzt,
      // anlageId bleibt die erste Anlage — unverändert, falls sich an
      // Position 0 nichts geändert hat.
      anlageId: ergaenzt.isNotEmpty ? ergaenzt.first : bestehend.anlageId,
    );
    final ergebnis = [...plan];
    ergebnis[indexBestehend] = aktualisiert;
    return ergebnis;
  }

  // Neuer Besuch: mindestens die angetippte(n) Anlage(n), plus alle heute
  // fälligen Geschwister-Anlagen desselben Betriebs — dedupliziert, gewählte
  // Anlage bleibt an erster Stelle (Reihenfolge stabil).
  final alle = [...neuAnlagen];
  for (final id in faelligeAnlagenDesBetriebs) {
    if (!alle.contains(id)) alle.add(id);
  }
  final neuerEintrag = neu.copyWith(
    anlageIds: alle,
    anlageId: alle.isNotEmpty ? alle.first : neu.anlageId,
  );
  return [...plan, neuerEintrag];
}
