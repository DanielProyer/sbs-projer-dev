import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';

/// Alle Betriebe — jeder MIT seinen Ferien-Perioden
/// ([BetriebLocal.ferienPerioden] ist nie `null`).
///
/// WARUM die Ferien schon hier und nicht erst in [betriebeProvider]
/// (27.09.2026, Abschalten des Altspalten-Rueckfalls): Bis dahin kamen die
/// Betriebe vor den Ferien an; in der Zwischenzeit lasen alle Leser die
/// eingefrorenen Altspalten. Ohne diesen Rueckfall haette der Tourenplan in
/// diesem Fenster (und bei einem Ladefehler der Ferien dauerhaft) Betriebe
/// ohne Ferien geplant. Jetzt gibt es Betriebe nur zusammen mit ihren
/// Ferien:
/// - Beide Abfragen laufen parallel; die Liste erscheint, wenn beide da sind.
/// - Schlaegt das Laden der Ferien fehl, schlaegt dieser Provider fehl —
///   wie bei einem Ladefehler der Betriebe selbst. Lieber keine Betriebe als
///   Betriebe mit still vergessenen Ferien. `tourenplanNeuLaden` laedt
///   beide neu.
/// - Wer `betriebeStreamProvider.future` abwartet (Mahnlauf, Fahrten),
///   bekommt die Ferien automatisch mit.
///
/// [ferienPeriodenProvider] neu laden (invalidate) baut auch diese Liste neu.
final betriebeStreamProvider = StreamProvider<List<BetriebLocal>>((ref) {
  // Beide Quellen sofort anstossen — sie laden parallel.
  return betriebeMitFerien(
    BetriebRepository.watchAll(),
    ref.watch(ferienPeriodenProvider.future),
  );
});

/// Ferien-Perioden aus der Tabelle `betrieb_ferien`, gruppiert nach
/// `betriebId` (== [BetriebLocal.serverId]). Die einzige Ferien-Quelle —
/// die Altspalten `ferien*_start/ende` auf `betriebe` liest seit 27.09.2026
/// niemand mehr (siehe core/util/betrieb_ferien.dart).
final ferienPeriodenProvider = FutureProvider<FerienPeriodenMap>((ref) async {
  final alle = await BetriebFerienRepository.getAll();
  final FerienPeriodenMap map = {};
  for (final f in alle) {
    (map[f.betriebId] ??= []).add((von: f.von, bis: f.bis));
  }
  return map;
});

final betriebeProvider = Provider<List<BetriebLocal>>((ref) {
  // Die Ferien haengen schon am Stream (siehe betriebeStreamProvider).
  final list = ref.watch(betriebeStreamProvider).valueOrNull ?? [];
  return [...list]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

final betriebNameMapProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null) b.serverId!: b.name,
  };
});

/// «Name, Ort» je Betrieb — für Stellen, an denen ein Betrieb neben einer
/// Person oder Rechnung steht (gleichnamige Betriebe, Daniel 23.09.2026).
final betriebAnzeigeMapProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null) b.serverId!: betriebMitOrt(b.name, b.ort),
  };
});

final betriebOrtMapProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null && b.ort != null) b.serverId!: b.ort!,
  };
});

final betriebRegionIdMapProvider = Provider<Map<String, String?>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null) b.serverId!: b.regionId,
  };
});
