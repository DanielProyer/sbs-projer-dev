import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart'
    show nurDatum;
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';
import 'package:sbs_projer_app/presentation/providers/arbeitstag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

// «Fahrten aus der Kette» (Fahrtenerkennung Stufe 1, 27.09.2026): Die
// Provider beschaffen nur die Daten eines Monats; die Regeln stehen rein in
// `core/util/fahrten_aus_kette.dart`. Nichts wird gespeichert.

/// Einsätze und Wegpunkt-Stempel eines Monats — Reinigungen, Störungen,
/// Montagen und Stempel parallel (vier kleine Abfragen, je < 200 Zeilen).
final fahrtenEinsaetzeProvider = FutureProvider.autoDispose
    .family<
      ({List<EinsatzRoh> einsaetze, List<StempelRoh> stempel}),
      AuswertungsMonat
    >((ref, m) async {
      final teile = await Future.wait<List<Object>>([
        ReinigungRepository.getEinsaetzeImMonat(m.jahr, m.monat),
        StoerungRepository.getEinsaetzeImMonat(m.jahr, m.monat),
        MontageRepository.getEinsaetzeImMonat(m.jahr, m.monat),
        WegpunktRepository.getStempelImMonat(m.jahr, m.monat),
      ]);
      return (
        einsaetze: [
          ...teile[0] as List<EinsatzRoh>,
          ...teile[1] as List<EinsatzRoh>,
          ...teile[2] as List<EinsatzRoh>,
        ],
        stempel: teile[3] as List<StempelRoh>,
      );
    });

/// Tages-Fahrten eines Monats (Schlüssel: Datum ohne Uhrzeit).
///
/// Alle Quellen werden VOR dem ersten `await` beobachtet: Ändert sich eine
/// (etwa die Fahrzeiten nach dem Nachrouten), rechnet der Provider neu, ohne
/// die übrigen Abfragen zu wiederholen — die liegen in ihren eigenen
/// Providern.
///
/// Betriebe über `betriebeStreamProvider.future` statt
/// `betriebLookupProvider`: Der Lookup liefert eine leere Map, solange die
/// Stammdaten laden — die Fahrten wären dann kurz ohne Koordinaten
/// gerechnet und angezeigt worden.
final monatsFahrtenProvider = FutureProvider.autoDispose
    .family<Map<DateTime, TagesFahrten>, AuswertungsMonat>((ref, m) async {
      final container = ref.container;
      final quellen = await Future.wait<Object>([
        ref.watch(arbeitstageProvider(m).future),
        ref.watch(fahrtenEinsaetzeProvider(m).future),
        ref.watch(anfahrtsDistanzenProvider.future),
        ref.watch(fahrzeitenMapProvider.future),
        ref.watch(betriebeStreamProvider.future),
      ]);
      final tage = quellen[0] as List<ArbeitstagRohdaten>;
      final einsaetze =
          quellen[1]
              as ({List<EinsatzRoh> einsaetze, List<StempelRoh> stempel});
      final anfahrten = quellen[2] as Map<String, Map<String, double>>;
      final fahrzeiten = quellen[3] as Map<String, FahrzeitEintrag>;
      final betriebe = quellen[4] as List<BetriebLocal>;

      final ergebnis = monatsFahrtenBauen(
        tagesplaene: {
          for (final t in tage)
            nurDatum(t.datum): (
              beginn: t.beginn,
              ende: t.ende,
              kmStart: t.kmStart,
              kmEnde: t.kmEnde,
              startPosition: t.startPosition,
              endPosition: t.endPosition,
            ),
        },
        einsaetze: einsaetze.einsaetze,
        stempel: einsaetze.stempel,
        betriebe: betriebOrte(betriebe),
        anfahrten: anfahrten,
        routen: {
          for (final e in fahrzeiten.entries)
            if (e.value.distanzKm != null) e.key: e.value.distanzKm!,
        },
        startorte: kStartorte,
        startortFuer: startortSchluessel,
      );

      // Neueste Tage zuerst nachrouten — die sieht man oben in der Liste.
      final neuesteZuerst = ergebnis.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      _routenNachholen(
        container,
        fehlendeRoutenPaare([for (final t in neuesteZuerst) ergebnis[t]!]),
      );
      return ergebnis;
    });

/// Fahrten eines einzelnen Tages (aus dem Monats-Provider); `null`, wenn
/// für den Tag nichts erfasst ist.
final tagesFahrtenProvider = FutureProvider.autoDispose
    .family<TagesFahrten?, DateTime>((ref, datum) async {
      final tag = nurDatum(datum);
      final monat = await ref.watch(
        monatsFahrtenProvider((jahr: tag.year, monat: tag.month)).future,
      );
      return monat[tag];
    });

/// Lädt die Quellen eines Monats neu — auch die, die bei einem Fehler in
/// ihrem Fehlerzustand stehen blieben (ein reines Invalidieren des
/// Monats-Providers würde denselben Fehler nur wieder abholen).
void fahrtenNeuLaden(WidgetRef ref, AuswertungsMonat m) {
  ref.invalidate(arbeitstageProvider(m));
  ref.invalidate(fahrtenEinsaetzeProvider(m));
  // Die Abfrage selbst (die Distanzen sind nur eine Sicht darauf).
  ref.invalidate(anfahrtenProvider);
  ref.invalidate(fahrzeitenMapProvider);
  if (ref.read(betriebeStreamProvider).hasError) {
    ref.invalidate(betriebeStreamProvider);
  }
}

/// Name und Koordinaten je Betrieb, über routeId UND serverId auffindbar
/// (Einsätze tragen die Server-Id; Muster `betriebLookupProvider`).
Map<String, BetriebOrt> betriebOrte(List<BetriebLocal> betriebe) {
  final map = <String, BetriebOrt>{};
  for (final b in betriebe) {
    final ort = (name: b.name, lat: b.latitude, lng: b.longitude);
    map[b.routeId] = ort;
    final sid = b.serverId;
    if (sid != null) map[sid] = ort;
  }
  return map;
}

// ── Fehlende Betrieb→Betrieb-Distanzen nachholen ──────────────────────────
//
// WARUM gedeckelt und gedrosselt: Die Edge Function `fahrzeit-route` fragt
// den öffentlichen OSRM-Demo-Server — höchstens eine Anfrage pro Sekunde,
// keine Massenabfragen. Vorher lud jeder Erfolg den Monat neu und holte die
// nächsten zehn Paare (bis der ganze Monat durch war), ein Monatswechsel
// startete einen zweiten Lauf parallel, und Zurückblättern löste 80–130
// Anfragen je Monat aus (Logs 27.09.2026: 3 Anfragen/s). Jetzt:
// - höchstens `kRoutenJeLauf` Paare je Lauf und `kRoutenJeSitzung` je
//   Sitzung (`routenAuswahl`) — ist der Sitzungsdeckel erreicht, startet
//   kein Lauf mehr; der Rest bleibt Luftlinie, bis die App neu lädt;
// - nur Tage mit Zählerstand (`fehlendeRoutenPaare`) — nur dort zählen km;
// - alle Anfragen durch EINE serielle Warteschlange mit ≥ 1,1 s Pause
//   (`FahrzeitRepository.routeAnfordern`); ein neuer Lauf stellt sich an.

/// Schon angefragte Paare dieser Sitzung (richtungslos) — jedes Paar geht
/// höchstens einmal an die Edge Function, auch wenn der Monat neu rechnet
/// oder das Routing scheitert. Seine Grösse ist der Sitzungszähler.
final _routeAngefragt = <String>{};

/// Fire-and-forget: fragt die von [routenAuswahl] freigegebenen Paare nach
/// und lädt bei mindestens einer gelieferten Distanz die Fahrzeiten neu.
/// Über den Container statt `ref`, weil der (autoDispose-)Monats-Provider
/// bis dahin schon verworfen sein kann; die Fahrzeiten sind app-weit (auch
/// der Tourenplan profitiert).
void _routenNachholen(
  ProviderContainer container,
  List<RoutenPaar> kandidaten,
) {
  final neu = routenAuswahl(
    kandidaten: kandidaten,
    schonAngefragt: _routeAngefragt,
  );
  if (neu.isEmpty) return; // nichts Neues — oder Sitzungsdeckel erreicht
  for (final p in neu) {
    _routeAngefragt.add(routenPaarSchluessel(p.von, p.nach));
  }

  unawaited(() async {
    // Alle Paare des Laufs auf einmal einreihen (kein await dazwischen):
    // So stellt sich ein späterer Lauf hinten an, statt sich einzuflechten.
    final antworten = await Future.wait([
      for (final p in neu) FahrzeitRepository.routeAnfordern(p.von, p.nach),
    ]);
    // routeAnfordern liefert bei Fehlern still null — die Luftlinien-
    // Schätzung bleibt dann stehen.
    if (!antworten.any((r) => r?.distanzKm != null)) return;
    try {
      container.invalidate(fahrzeitenMapProvider);
    } catch (e) {
      // StateError, wenn der Container inzwischen abgebaut ist (App neu
      // geladen, Test zu Ende) — dann gibt es nichts mehr neu zu rechnen.
      debugPrint('[Fahrten] Fahrzeiten nicht neu geladen: $e');
    }
  }());
}
