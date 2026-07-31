import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/core/util/pause_pruefung.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/pause_pruefen_sheet.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';

/// Gemeinsamer Einstiegspunkt für die «vergessene Pause»-Prüfung
/// (Daniel 31.07.2026): wird beim Abschliessen einer Reinigung, beim
/// Erfassen einer Störung/Montage und beim Feierabend aufgerufen — überall
/// dort, wo ein Ereignis mit Zeit + Ort anfällt, an dem sich eine seit dem
/// Znüni vergessene Pause auffangen lässt.
///
/// Läuft KEINE Pause, kehrt die Funktion sofort zurück. Läuft eine, wird die
/// aktuelle Position (bestmöglich, GPS darf fehlen) mit der Position des
/// letzten `pause_start`-Wegpunkts des Tages verglichen ([pausePruefen]).
/// Bei `bewegt`/`zuLang` erscheint die Nachfrage — bei `unauffaellig`
/// passiert nichts.
///
/// NIE blockierend: Ruft niemals einen Fehler nach aussen weiter. Aufrufer
/// binden trotzdem einen eigenen try/catch ein (wie bei der Ferienfrage in
/// reinigung_form_screen.dart) — Fehlerbehandlung ist hier zusätzlich, kein
/// Ersatz.
Future<void> pausePruefenNachEreignis(
  BuildContext context,
  WidgetRef ref, {
  ({double lat, double lng})? position,
}) async {
  try {
    final heute = DateTime.now();
    final tag = DateTime(heute.year, heute.month, heute.day);
    final at = ref.read(arbeitstagProvider(tag));
    final pauseStart = at.pauseStart;
    if (pauseStart == null) return; // keine Pause aktiv

    final pauseStartMinuten = minutenAusHhmm(pauseStart);
    if (pauseStartMinuten == null) return;

    final jetztMinuten = heute.hour * 60 + heute.minute;

    // Aktuelle Position bestmoeglich holen — ohne GPS bleibt distanzKm null,
    // die Pruefung faellt dann auf die reine Dauer zurueck.
    var aktuellePosition = position;
    if (aktuellePosition == null) {
      try {
        final p = await GpsService.aktuellePosition();
        aktuellePosition = (lat: p.latitude, lng: p.longitude);
      } catch (_) {
        aktuellePosition = null;
      }
    }

    double? distanzKm;
    if (aktuellePosition != null) {
      try {
        final wegpunkte = await ref.read(wegpunkteFuerTagProvider(tag).future);
        // Der zuletzt gestempelte 'pause_start' gehoert zur laufenden Pause
        // — es kann nur eine gleichzeitig geben.
        WegpunktTag? letzterPausenStart;
        for (final w in wegpunkte) {
          if (w.quelle != 'pause_start') continue;
          if (letzterPausenStart == null ||
              w.zeitpunkt.isAfter(letzterPausenStart.zeitpunkt)) {
            letzterPausenStart = w;
          }
        }
        if (letzterPausenStart != null &&
            letzterPausenStart.lat != null &&
            letzterPausenStart.lng != null) {
          distanzKm = haversineKm(
            letzterPausenStart.lat!,
            letzterPausenStart.lng!,
            aktuellePosition.lat,
            aktuellePosition.lng,
          );
        }
      } catch (e) {
        debugPrint('[Pause-Pruefung] Wegpunkte laden fehlgeschlagen: $e');
        distanzKm = null;
      }
    }

    final ergebnis = pausePruefen(
      pauseStartMinuten: pauseStartMinuten,
      jetztMinuten: jetztMinuten,
      distanzKm: distanzKm,
    );
    if (ergebnis.befund == PauseBefund.unauffaellig) return;
    if (!context.mounted) return;

    final antwort = await zeigePausePruefenSheet(
      context,
      pauseStart: pauseStart,
      befund: ergebnis.befund,
      vorschlagMinuten: ergebnis.endeMinuten!,
    );
    if (antwort == null) return; // weggetippt: Pause laeuft einfach weiter

    final bisherigeSumme = at.pauseMinuten ?? 0;
    var neueSumme = bisherigeSumme;
    if (antwort is PausePruefenEnde) {
      final dauer = antwort.endeMinuten > pauseStartMinuten
          ? antwort.endeMinuten - pauseStartMinuten
          : 0;
      neueSumme = bisherigeSumme + dauer;
    }
    // PausePruefenVerwerfen: Summe bleibt unveraendert — die Dauer ist nicht
    // mehr verlaesslich rekonstruierbar, darum wird sie nicht gezaehlt.

    final neu = (
      beginn: at.beginn,
      ende: at.ende,
      km: at.km,
      kmStart: at.kmStart,
      lat: at.lat,
      lng: at.lng,
      endLat: at.endLat,
      endLng: at.endLng,
      pauseMinuten: neueSumme,
      pauseStart: null,
    );
    ref.read(arbeitstagProvider(tag).notifier).state = neu;

    final beginnDb = ref
        .read(gespeicherterTagesplanProvider(tag))
        .valueOrNull
        ?.arbeitsbeginn;
    await arbeitstagFelderSpeichern(
      tag,
      const [],
      arbeitsbeginn: beginnDb,
      arbeitsende: neu.ende,
      kmStand: neu.km,
      kmStart: neu.kmStart,
      pauseMinuten: neu.pauseMinuten,
      pauseStart: neu.pauseStart,
      pauseSchreiben: true,
    );
    ref.invalidate(gespeicherterTagesplanProvider(tag));
    unawaited(WegpunktRepository.stempeln(quelle: 'pause_ende'));
  } catch (e) {
    debugPrint('[Pause-Pruefung] uebersprungen, Fehler: $e');
  }
}
