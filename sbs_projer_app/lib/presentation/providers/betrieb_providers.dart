import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';

/// Woher die rohen Betriebe kommen: Web einmal aus Supabase, nativ der
/// Isar-Strom. Eine Funktion statt eines Stroms, damit jeder Neuaufbau von
/// [betriebeStreamProvider] frisch abonniert (der Web-Strom ist
/// einmalig) — und damit Tests die Quelle ersetzen koennen.
final betriebeQuelleProvider =
    Provider<Stream<List<BetriebLocal>> Function()>(
      (ref) => BetriebRepository.watchAll,
    );

/// Alle Betriebe — jeder MIT seinen Ferien-Perioden aus `betrieb_ferien`.
///
/// WARUM die Ferien schon hier und nicht erst in [betriebeProvider]
/// (27.09.2026, Abschalten des Altspalten-Rueckfalls): Bis dahin kamen die
/// Betriebe vor den Ferien an; in der Zwischenzeit lasen alle Leser die
/// eingefrorenen Altspalten. Ohne diesen Rueckfall haette der Tourenplan in
/// diesem Fenster Betriebe ohne Ferien geplant. Jetzt:
/// - Beide Abfragen laufen parallel; die Liste erscheint, wenn beide fertig
///   sind — normal mit gesetztem [BetriebLocal.ferienPerioden].
/// - Schlaegt das Laden der Ferien fehl, kommen die Betriebe trotzdem, mit
///   `ferienPerioden = null` (Betriebe sind der Kern der App: Stoerung,
///   Rechnung, Suche). Das bleibt nicht still: Jede Ferien-Auswertung meldet
///   den Rueckfall, und [ferienLadefehlerProvider] stellt die dringende
///   Aufgabe «Ferien nicht geladen» auf Heute-Karte und Glocke.
/// - Wer `betriebeStreamProvider.future` abwartet (Mahnlauf, Fahrten),
///   bekommt die Ferien automatisch mit.
///
/// [ferienPeriodenProvider] neu laden (invalidate) baut auch diese Liste neu.
final betriebeStreamProvider = StreamProvider<List<BetriebLocal>>((ref) {
  // Beide Quellen sofort anstossen — sie laden parallel.
  return betriebeMitFerien(
    ref.watch(betriebeQuelleProvider)(),
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

/// Fehlertext, solange der letzte Ladeversuch der Ferien-Tabelle
/// fehlgeschlagen ist — sonst `null`. Dann tragen die Betriebe aus
/// [betriebeStreamProvider] KEINE Ferien (`ferienPerioden = null`), und der
/// Tourenplan koennte zu einem geschlossenen Betrieb schicken. Speist die
/// dringende Aufgabe «Ferien nicht geladen» (`ferienLadefehlerAufgabe`).
/// Bleibt waehrend eines erneuten Ladeversuchs stehen, bis er gelingt.
final ferienLadefehlerProvider = Provider<String?>((ref) {
  final ferien = ref.watch(ferienPeriodenProvider);
  return ferien.hasError ? '${ferien.error}' : null;
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
