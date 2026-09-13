/// Startseiten-Tageskarte (A1): «welche Stopps des heutigen Tagesplans sind
/// noch offen?»
///
/// Verdrahtet die reinen Funktionen aus `core/util/heute_stopps.dart` mit dem
/// gespeicherten Tagesplan (`gespeicherterTagesplanProvider`) und den beiden
/// Einsatzquellen (Reinigungen, Störungen/Montagen/HeiGenie). Das Widget
/// selbst ist Task 9 — hier entsteht nur die Datenseite.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/heute_stopps.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Heute schneidet die Uhrzeit ab — `gespeicherterTagesplanProvider` ist eine
/// `family` über `DateTime`, und ein Wert mit Uhrzeit erzeugte bei jedem
/// Aufruf einen neuen Cache-Eintrag.
DateTime tagHeute() {
  final j = DateTime.now();
  return DateTime(j.year, j.month, j.day);
}

/// Anlagen, die heute bereits gereinigt wurden.
///
/// `ReinigungLocal.anlageIds` ist ein reguläres `List<String>`-Feld (bereits
/// entpackt, kein JSON) — `anlageIdsJson` daneben existiert nur für die
/// Supabase-Synchronisation (`jsonb`-Spalte), nicht zum Lesen hier. Fällt es
/// leer aus (Alt-Reinigung ohne Bündelung), greift das Kompatibilitäts-Feld
/// `anlageId` — genau das Muster aus
/// `tatsaechlicheReinigungenAlsEintraegeProvider` (tour_providers.dart).
final gereinigteAnlagenHeuteProvider = Provider<Set<String>>((ref) {
  final heute = tagHeute();
  final ids = <String>{};
  for (final r in ref.watch(reinigungenProvider)) {
    if (r.status != 'abgeschlossen') continue;
    if (r.datum.year != heute.year ||
        r.datum.month != heute.month ||
        r.datum.day != heute.day) {
      continue;
    }
    if (r.anlageIds.isNotEmpty) {
      ids.addAll(r.anlageIds);
    } else if (r.anlageId.isNotEmpty) {
      ids.add(r.anlageId);
    }
  }
  return ids;
});

/// Störungen und Montagen (inkl. HeiGenie), die nicht mehr offen sind — als
/// TourEintrag-Ids.
///
/// Die Ids im Tagesplan sind präfixiert und aus der `routeId` gebildet
/// (`s_${routeId}`, `m_${routeId}`, siehe tour_providers.dart) — nicht aus
/// `serverId`. Im Web sind beide identisch, nativ nicht: dort gälte sonst nie
/// etwas als erledigt und die Liste würde nie kürzer. HeiGenie-Einträge
/// laufen über dieselbe `m_`-Vorsilbe wie Montagen — sie kommen aus derselben
/// `montagen`-Tabelle/-Liste und unterscheiden sich nur über `montageTyp`
/// (`istHeiGenie`), nicht über ein eigenes Id-Präfix.
final erledigteEinsatzIdsProvider = Provider<Set<String>>((ref) {
  final ids = <String>{};
  for (final s in ref.watch(stoerungenProvider)) {
    if (!stoerungOffen(s.status)) ids.add('s_${s.routeId}');
  }
  for (final m in ref.watch(montagenProvider)) {
    if (!montageOffen(m.status)) ids.add('m_${m.routeId}');
  }
  return ids;
});

/// Der heutige Tagesplan, auf die offenen Stopps eingedampft.
///
/// Fehlt der gespeicherte Plan (z.B. noch nie im Tourenplan geöffnet), ist
/// die Liste leer statt eines Fehlers — «kein Plan» ist ein gültiger Zustand.
final heuteOffeneStoppsProvider = Provider<AsyncValue<List<TourEintrag>>>((
  ref,
) {
  final planAsync = ref.watch(gespeicherterTagesplanProvider(tagHeute()));
  final gereinigteAnlageIds = ref.watch(gereinigteAnlagenHeuteProvider);
  final erledigteEinsatzIds = ref.watch(erledigteEinsatzIdsProvider);
  return planAsync.whenData(
    (plan) => offeneStopps(
      plan: plan?.eintraege ?? const [],
      gereinigteAnlageIds: gereinigteAnlageIds,
      erledigteEinsatzIds: erledigteEinsatzIds,
    ),
  );
});

/// Zähler für die Kopfzeile — `null`, solange der Plan lädt oder fehlt.
final heuteZaehlerProvider = Provider<({int erledigt, int gesamt})?>((ref) {
  final plan = ref
      .watch(gespeicherterTagesplanProvider(tagHeute()))
      .valueOrNull;
  if (plan == null) return null;
  return erledigtZaehler(
    plan: plan.eintraege,
    gereinigteAnlageIds: ref.watch(gereinigteAnlagenHeuteProvider),
    erledigteEinsatzIds: ref.watch(erledigteEinsatzIdsProvider),
  );
});
