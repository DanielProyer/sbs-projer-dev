import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart'
    show TagesFahrten;
import 'package:sbs_projer_app/core/util/tagesrand_position.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/providers/arbeitstag_providers.dart'
    show arbeitstageProvider;
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart'
    show tagesFahrtenProvider;
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/pause_pruefen_helfer.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';
import 'dart:async';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

/// Arbeitstag-Karte auf dem Startbildschirm (Daniel 29.07.2026):
/// Arbeitsbeginn, Arbeitsende und km-Stand direkt dort erfassen, wo der Tag
/// beginnt und endet — nicht erst im Tourenplan.
///
/// km wird an BEIDEN Tagesrändern erfasst (Start und Ende): Die Differenz
/// ergibt die Tages-km, unverfälscht von Privatfahrten ausserhalb des
/// Arbeitstags. GPS wird bei Start UND Feierabend gestempelt — damit liegen
/// alle Daten für spätere Auswertungen vor. Der Tag beginnt nicht immer am
/// festen Startort (Zuhause Domat/Ems), sondern oft anderswo (Chur):
/// Anfahrt/Heimweg der Zeitachse rechnen von der gestempelten Startposition;
/// schlägt GPS fehl, wird trotzdem gespeichert (Rückfall fester Startort).
class ArbeitstagKarte extends ConsumerStatefulWidget {
  const ArbeitstagKarte({super.key});

  @override
  ConsumerState<ArbeitstagKarte> createState() => _ArbeitstagKarteState();
}

class _ArbeitstagKarteState extends ConsumerState<ArbeitstagKarte> {
  /// Minutentakt, solange eine Pause läuft — lässt die mitlaufende Dauer im
  /// Balken («Pause seit 14:10 · 47 min») live vorrücken (Vorbild: der
  /// Live-Timer der Tourenplan-Zeitachse, `_liveTimerAktualisieren`).
  Timer? _pauseTimer;

  /// Läuft gerade der Feierabend-Ablauf (Speichern, dann Standort)? Solange
  /// bleibt die Zeile «Fahrten heute» weg und ihr Provider ungestartet —
  /// siehe [_fahrtenHeuteZeile].
  bool _feierabendLaeuft = false;

  DateTime get _heute {
    final jetzt = DateTime.now();
    return DateTime(jetzt.year, jetzt.month, jetzt.day);
  }

  @override
  void initState() {
    super.initState();
    final laeuft = ref.read(arbeitstagProvider(_heute)).pauseStart != null;
    _pauseTimerSicherstellen(laeuft);
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }

  void _pauseTimerSicherstellen(bool laeuft) {
    if (laeuft) {
      _pauseTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _pauseTimer?.cancel();
      _pauseTimer = null;
    }
  }

  /// Dauer der laufenden Pause in Minuten (0, wenn die Uhr über Mitternacht
  /// gelaufen ist statt eines negativen Werts).
  int _laufendePauseMinuten(String pauseStart) {
    final von = minutenAusHhmm(pauseStart) ?? 0;
    final jetzt = DateTime.now();
    final bis = jetzt.hour * 60 + jetzt.minute;
    final dauer = bis - von;
    return dauer < 0 ? 0 : dauer;
  }

  Future<void> _speichern(
    DateTime heute,
    Arbeitstag neu, {
    // In der DB erfasster Beginn — `null` heisst «kein Beginn erfasst» und
    // löscht einen vorhandenen. Bewusst getrennt von `neu.beginn`, das als
    // Achsen-Fallback immer einen Wert trägt (Standard 06:00).
    required String? beginnDb,
    ({double lat, double lng})? startPosition,
    ({double lat, double lng})? endPosition,
    bool pauseSchreiben = false,
  }) async {
    ref.read(arbeitstagProvider(heute).notifier).state = neu;
    // Einträge bewusst leer: existiert schon eine Plan-Zeile, fasst
    // arbeitstagFelderSpeichern sie per update nicht an; fehlt sie, entsteht
    // sie mit leerem Plan — der Tourenplan füllt sie später selbst.
    await arbeitstagFelderSpeichern(
      heute,
      const [],
      arbeitsbeginn: beginnDb,
      arbeitsende: neu.ende,
      kmStand: neu.km,
      kmStart: neu.kmStart,
      startPosition: startPosition,
      endPosition: endPosition,
      pauseMinuten: neu.pauseMinuten,
      pauseStart: neu.pauseStart,
      pauseSchreiben: pauseSchreiben,
    );
    ref.invalidate(gespeicherterTagesplanProvider(heute));
    // Die Monatsrahmen der Fahrten-Kontrolle («Fahrten heute» unten, die
    // Auswertung) liegen in einem eigenen, NICHT autoDispose-Cache — ohne
    // das hier zeigte die Zeile nach dem Feierabend den km-Stand von vorher
    // (oder gar keinen). Ohne Zuhörer kostet das nichts: geladen wird erst
    // beim nächsten Lesen.
    ref.invalidate(arbeitstageProvider((jahr: heute.year, monat: heute.month)));
  }

  /// Pause starten oder beenden. Beim Beenden wird die Dauer zur Tagessumme
  /// addiert — mehrere Pausen am Tag sind also möglich.
  ///
  /// Warum überhaupt: Eine nicht erfasste Pause landet sonst in der
  /// Arbeitszeit UND verdirbt die Fahrzeit zwischen zwei Besuchen (Daniel
  /// 30.07.2026: 25 min zwischen Migros Golfpark und Restaurant Linden).
  Future<void> _pause() async {
    final heute = _heute;
    final messenger = ScaffoldMessenger.of(context);
    // Ladefehler ist nicht «kein Beginn erfasst»: das Speichern unten
    // schreibt den Beginn immer mit und löschte ihn sonst (Review 26.09.2026).
    if (!arbeitstagStandBereit(ref, heute, messenger)) return;
    final beginnDb = ref
        .read(gespeicherterTagesplanProvider(heute))
        .valueOrNull
        ?.arbeitsbeginn;
    final at = ref.read(arbeitstagProvider(heute));
    final jetzt = DateTime.now();
    final jetztText = hhmmAusMinuten(jetzt.hour * 60 + jetzt.minute);
    final laeuft = at.pauseStart;

    if (laeuft == null) {
      await _speichern(
        heute,
        (
          beginn: at.beginn,
          ende: at.ende,
          km: at.km,
          kmStart: at.kmStart,
          lat: at.lat,
          lng: at.lng,
          endLat: at.endLat,
          endLng: at.endLng,
          pauseMinuten: at.pauseMinuten,
          pauseStart: jetztText,
        ),
        beginnDb: beginnDb,
        pauseSchreiben: true,
      );
      unawaited(WegpunktRepository.stempeln(quelle: 'pause_start'));
      messenger.showSnackBar(
        SnackBar(content: Text('Pause ab $jetztText läuft')),
      );
      return;
    }

    // Beenden: Dauer aus der laufenden Pause, negative Werte (Tagwechsel
    // über Mitternacht) verwerfen statt die Summe zu verfälschen.
    final von = minutenAusHhmm(laeuft);
    final bis = jetzt.hour * 60 + jetzt.minute;
    final dauer = (von == null || bis <= von) ? 0 : bis - von;
    final summe = (at.pauseMinuten ?? 0) + dauer;

    await _speichern(
      heute,
      (
        beginn: at.beginn,
        ende: at.ende,
        km: at.km,
        kmStart: at.kmStart,
        lat: at.lat,
        lng: at.lng,
        endLat: at.endLat,
        endLng: at.endLng,
        pauseMinuten: summe,
        pauseStart: null,
      ),
      beginnDb: beginnDb,
      pauseSchreiben: true,
    );
    unawaited(WegpunktRepository.stempeln(quelle: 'pause_ende'));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          dauer > 0
              ? 'Pause beendet — $dauer min (Tagessumme $summe min)'
              : 'Pause beendet',
        ),
      ),
    );
  }

  /// GPS holen; Fehler → null plus Hinweis (Zeit/km werden trotzdem erfasst).
  /// Standort holen. Schlägt NIE fehl nach aussen — der Aufrufer entscheidet,
  /// was ohne Koordinate passiert. [melden] aus, wenn der Aufrufer selbst eine
  /// passendere Meldung zeigt (z. B. den Rückfall auf den Startort).
  Future<({double lat, double lng})?> _gps(
    ScaffoldMessengerState messenger,
    String wofuer, {
    bool melden = true,
  }) async {
    try {
      final p = await GpsService.aktuellePosition();
      return (lat: p.latitude, lng: p.longitude);
    } catch (e) {
      if (melden) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$wofuer ohne Standort erfasst (${kurzeFehlermeldung(e)}).',
            ),
          ),
        );
      }
      return null;
    }
  }

  /// Standort NACH dem Speichern nachtragen (Reihenfolge-Fix 11.08.2026).
  ///
  /// [startortErlaubt] nur beim Feierabend: fehlt GPS, gilt der hinterlegte
  /// Startort (zuhause). Siehe `core/util/tagesrand_position.dart`.
  /// Gibt die tatsächlich verwendete Position zurück (für Folgeschritte wie
  /// die Pausen-Prüfung — spart eine zweite GPS-Abfrage).
  Future<({double lat, double lng})?> _positionNachtragen(
    DateTime tag,
    ScaffoldMessengerState messenger,
    String wofuer, {
    required bool istEnde,
    required String? beginnDb,
  }) async {
    final startort = ref.read(startortProvider);
    final gps = await _gps(messenger, wofuer, melden: false);
    final wahl = tagesrandPosition(
      gps: gps,
      startort: startort,
      startortErlaubt: istEnde,
    );

    if (wahl.position == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$wofuer gespeichert, aber ohne Standort — '
            '${istEnde ? 'kein GPS und kein hinterlegter Startort' : 'kein GPS'}.',
          ),
        ),
      );
      return null;
    }
    if (wahl.quelle == PositionsQuelle.startort) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kein GPS — Standort auf den Startort gesetzt.'),
        ),
      );
    }

    try {
      final at = ref.read(arbeitstagProvider(tag));
      await _speichern(
        tag,
        (
          beginn: at.beginn,
          ende: at.ende,
          km: at.km,
          kmStart: at.kmStart,
          lat: istEnde ? at.lat : wahl.position!.lat,
          lng: istEnde ? at.lng : wahl.position!.lng,
          endLat: istEnde ? wahl.position!.lat : at.endLat,
          endLng: istEnde ? wahl.position!.lng : at.endLng,
          pauseMinuten: at.pauseMinuten,
          pauseStart: at.pauseStart,
        ),
        beginnDb: beginnDb,
        startPosition: istEnde ? null : wahl.position,
        endPosition: istEnde ? wahl.position : null,
      );
      unawaited(
        WegpunktRepository.stempeln(
          quelle: istEnde ? 'feierabend' : 'arbeitsbeginn',
          position: wahl.position,
        ),
      );
    } catch (e) {
      // Die Arbeitszeit steht bereits — nur der Standort fehlt.
      messenger.showSnackBar(
        SnackBar(
          content: Text('Standort nicht gespeichert: ${kurzeFehlermeldung(e)}'),
        ),
      );
    }
    return wahl.position;
  }

  Future<void> _startJetzt() async {
    final heute = _heute;
    final messenger = ScaffoldMessenger.of(context);
    // Ohne geladenen Stand fehlte unten die Rückfrage «bereits erfasst» —
    // und ein bestehender Arbeitstag würde still ersetzt (Review 26.09.2026).
    if (!arbeitstagStandBereit(ref, heute, messenger)) return;
    final bisher = ref.read(arbeitstagProvider(heute));

    // Fehleingabe-Schutz (31.07.2026: versehentlicher Neustart 19:29 hat den
    // Tag überschrieben): Läuft der Tag schon oder ist er gar abgeschlossen,
    // erst bestätigen lassen.
    final gespeichert = ref
        .read(gespeicherterTagesplanProvider(heute))
        .valueOrNull;
    final beginnBisher = gespeichert?.arbeitsbeginn;
    final endeBisher = gespeichert?.arbeitsende;
    if (beginnBisher != null || endeBisher != null) {
      final frage = beginnBisher != null
          ? 'Arbeitsbeginn $beginnBisher ist bereits erfasst. '
                'Durch «jetzt» ersetzen?'
          : 'Feierabend $endeBisher ist bereits erfasst. '
                'Arbeitsbeginn trotzdem auf «jetzt» setzen?';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Arbeitstag neu starten?'),
          content: Text(frage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ersetzen'),
            ),
          ],
        ),
      );
      // State.mounted (nicht context.mounted): Seit dem Umbau auf
      // ConsumerStatefulWidget ist das der zustaendige Check nach einem await.
      if (ok != true || !mounted) return;
    }

    final km = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _KmSheet(
        titel: 'Arbeitsbeginn',
        hinweis:
            'km-Stand des Autos jetzt — Uhrzeit und Standort werden '
            'automatisch erfasst.',
        vorbefuellung: bisher.kmStart,
      ),
    );
    if (km == null && bisher.kmStart == null) {
      // Abgebrochen ohne km: gar nicht starten — halbe Datensätze bringen
      // für die Auswertung nichts.
      return;
    }

    final jetzt = DateTime.now();
    final beginn = hhmmAusMinuten(jetzt.hour * 60 + jetzt.minute);

    // ZUERST speichern, Standort danach (11.08.2026): Die GPS-Abfrage stand
    // vorher davor und blieb auf Geräten ohne Standortdienst wortlos stehen —
    // Zeit und km gingen verloren, ohne dass eine Meldung erschien.
    try {
      await _speichern(heute, (
        beginn: beginn,
        ende: bisher.ende,
        km: bisher.km,
        kmStart: km ?? bisher.kmStart,
        lat: bisher.lat,
        lng: bisher.lng,
        endLat: bisher.endLat,
        endLng: bisher.endLng,
        pauseMinuten: bisher.pauseMinuten,
        pauseStart: bisher.pauseStart,
      ), beginnDb: beginn);
      messenger.showSnackBar(
        SnackBar(content: Text('Arbeitsbeginn $beginn erfasst')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Fehler: ${kurzeFehlermeldung(e)}')),
      );
      return;
    }

    await _positionNachtragen(
      heute,
      messenger,
      'Arbeitsbeginn',
      istEnde: false,
      beginnDb: beginn,
    );
  }

  Future<void> _feierabend() async {
    final heute = _heute;
    final messenger = ScaffoldMessenger.of(context);
    // Ohne geladenen Stand stünde der Beginn leer im Sheet — Speichern
    // hiesse dann «Beginn löschen» (Review 26.09.2026).
    if (!arbeitstagStandBereit(ref, heute, messenger)) return;
    final at = ref.read(arbeitstagProvider(heute));
    final erfassterBeginn = ref
        .read(gespeicherterTagesplanProvider(heute))
        .valueOrNull
        ?.arbeitsbeginn;
    final eingabe = await showModalBottomSheet<ArbeitstagEingabe>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ArbeitstagAbschlussSheet(
        aktuell: at,
        erfassterBeginn: erfassterBeginn,
      ),
    );
    if (eingabe == null || !mounted) return;

    // «Fahrten heute» erst nach dem ganzen Ablauf rechnen: Die Zeile würde
    // sonst schon beim ersten Speichern erscheinen, den Monat mit dem Stand
    // VOR dem Schreiben laden und nach dem Standort ein zweites Mal —
    // jedesmal mit einem eigenen Nachrouten-Lauf (siehe
    // [_fahrtenHeuteZeile]).
    setState(() => _feierabendLaeuft = true);
    final ({double lat, double lng})? pos;
    try {
      // ZUERST speichern (Fall Daniel 11.08.2026): Am PC ohne Standortdienst
      // blieb die GPS-Abfrage hier stehen — Arbeitsende und km-Stand wurden
      // wortlos verworfen, zweimal. Die Arbeitszeit darf nie davon abhängen,
      // ob eine Koordinate zustande kommt.
      try {
        await _speichern(heute, (
          beginn: eingabe.beginn ?? '06:00',
          ende: eingabe.ende,
          km: eingabe.km,
          kmStart: eingabe.kmStart,
          lat: at.lat,
          lng: at.lng,
          endLat: at.endLat,
          endLng: at.endLng,
          pauseMinuten: at.pauseMinuten,
          pauseStart: at.pauseStart,
        ), beginnDb: eingabe.beginn);
        messenger.showSnackBar(
          const SnackBar(content: Text('Arbeitstag gespeichert')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Fehler: ${kurzeFehlermeldung(e)}')),
        );
        return;
      }

      // Standort danach — ohne GPS gilt der hinterlegte Startort (zuhause).
      pos = await _positionNachtragen(
        heute,
        messenger,
        'Feierabend',
        istEnde: true,
        beginnDb: eingabe.beginn,
      );
    } finally {
      if (mounted) setState(() => _feierabendLaeuft = false);
    }

    // Vergessene Pause abfangen (Daniel 31.07.2026): Lief die Pause noch,
    // wuerde sie sonst bis in alle Ewigkeit weiterlaufen — Feierabend ist
    // das letzte Ereignis des Tages, an dem sich das noch auffangen laesst.
    // NIE blockierend, eigener try/catch: ein Fehler hier darf den bereits
    // gespeicherten Feierabend nicht antasten (analog Ferienfrage in
    // reinigung_form_screen.dart).
    if (mounted) {
      try {
        await pausePruefenNachEreignis(context, ref, position: pos);
      } catch (e) {
        debugPrint('[Pause-Pruefung] uebersprungen, Fehler: $e');
      }
    }
  }

  /// «Fahrten heute: 7 · 143 km · Zähler 148 km (+5)» nach dem Feierabend
  /// — der Tag in einer Zeile, Tipp führt zu den Fahrten des Tages.
  ///
  /// `null` (keine Zeile), solange die Fahrten laden, bei einem Fehler und
  /// an Tagen ohne Erfassung — nie eine erfundene «0 km».
  ///
  /// Nachrouten: [tagesFahrtenProvider] liest den Monats-Provider, und der
  /// fragt fehlende Strecken nach — seit Migration 213 auch Anfahrt und
  /// Heimweg von/zu Startort oder GPS-Position (gedeckelt je Lauf und
  /// Sitzung — `kRoutenJeLauf`/`kRoutenJeSitzung` —, seriell gedrosselt,
  /// `fahrten_providers.dart`). Das ist
  /// erwünscht, aber nur einmal: Der Provider wird erst beobachtet, wenn der
  /// Feierabend-Ablauf ganz durch ist ([_feierabendLaeuft]); Auswertung und
  /// Fahrten-Screen teilen sich denselben Monats-Provider (Record-Schlüssel),
  /// und ein Paar geht je Sitzung höchstens einmal an die Edge Function.
  Widget? _fahrtenHeuteZeile(DateTime heute) {
    final fahrten = ref.watch(tagesFahrtenProvider(heute));
    // Nachrechnen (neue Distanzen) behält den bisherigen Wert — die Zeile
    // bleibt stehen; ein Fehler blendet sie aus.
    final f = fahrten.hasError ? null : fahrten.valueOrNull;
    if (f == null) return null;
    final text = fahrtenHeuteText(f);
    const grau = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(fahrtenPfad(heute)),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.route, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: grau,
                  children: [
                    TextSpan(text: text.basis),
                    if (text.delta != null)
                      TextSpan(
                        text: ' ${text.delta}',
                        style: f.differenzAuffaellig
                            ? const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              )
                            : null,
                      ),
                  ],
                ),
                // Zwei Zeilen: Mit «(N ohne Strecke)» wird die Zeile auf
                // 360 px zu lang — einzeilig verschwand der Zähler hinter «…».
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heute = _heute;
    // Beim App-Start den gespeicherten Stand des Tages in den State holen
    // (gleiche Übernahme-Regel wie im Tourenplan: Zeile ist massgebend).
    ref.listen(gespeicherterTagesplanProvider(heute), (vorher, nachher) {
      final g = nachher.valueOrNull;
      if (g == null) return;
      final aktuell = ref.read(arbeitstagProvider(heute));
      ref.read(arbeitstagProvider(heute).notifier).state = (
        beginn: g.arbeitsbeginn ?? aktuell.beginn,
        ende: g.arbeitsende,
        km: g.kmStand,
        kmStart: g.kmStart,
        lat: g.startLat,
        lng: g.startLng,
        endLat: g.endLat,
        endLng: g.endLng,
        pauseMinuten: g.pauseMinuten,
        pauseStart: g.pauseStart,
      );
    });
    // Pause-Balken: Minutentakt starten/stoppen, sobald sich der Lauf-Status
    // ändert (Timer-Start beim allerersten Build übernimmt initState).
    ref.listen(arbeitstagProvider(heute), (vorher, nachher) {
      final vorherLief = vorher?.pauseStart != null;
      final laeuftJetzt = nachher.pauseStart != null;
      if (vorherLief != laeuftJetzt) _pauseTimerSicherstellen(laeuftJetzt);
    });
    final gespeichert = ref
        .watch(gespeicherterTagesplanProvider(heute))
        .valueOrNull;
    final at = ref.watch(arbeitstagProvider(heute));
    // «erfasst» heisst: in der DB steht ein Beginn — nicht der 06:00-Standard.
    final beginnErfasst = gespeichert?.arbeitsbeginn != null;
    final tagesKm =
        (at.km != null && at.kmStart != null && at.km! >= at.kmStart!)
        ? at.km! - at.kmStart!
        : null;

    // Eine kompakte Statuszeile statt zwei (Daniel 31.07.2026: Startbildschirm
    // ohne Scrollen) — die km-Stände im Detail zeigt das Arbeitstag-Sheet.
    String status;
    if (beginnErfasst && at.ende != null) {
      status = '${at.beginn}–${at.ende}';
    } else if (beginnErfasst) {
      status = 'ab ${at.beginn}';
    } else if (at.ende != null) {
      status = 'bis ${at.ende}';
    } else {
      status = 'noch nicht gestartet';
    }
    if (tagesKm != null) {
      status += ' · $tagesKm km';
    } else if (beginnErfasst && at.kmStart != null) {
      status += ' · ${at.kmStart} km';
    }
    final pauseLaeuft = at.pauseStart != null;
    // «Pause ab HH:mm» steht jetzt im auffälligen Balken unten — in der
    // kompakten Statuszeile nur noch die abgeschlossene Tagessumme.
    if (!pauseLaeuft && (at.pauseMinuten ?? 0) > 0) {
      status += ' · ${at.pauseMinuten} min Pause';
    }
    final fahrtenZeile = at.ende != null && !_feierabendLaeuft
        ? _fahrtenHeuteZeile(heute)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Arbeitstag',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (at.lat != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: AppColors.success,
                            ),
                          ],
                          if (at.endLat != null)
                            const Icon(
                              Icons.flag,
                              size: 13,
                              color: AppColors.info,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // CanvasKit-Regel: tappbare Flächen als GestureDetector+Container.
                // Knopfgrösse bewusst unverändert (Daniel: nicht zu klein).
                _KnopfKlein(
                  text: beginnErfasst ? 'Neu starten' : 'Jetzt starten',
                  farbe: beginnErfasst
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  onTap: _startJetzt,
                ),
                const SizedBox(width: 6),
                // Pause: läuft eine, wird der Knopf zum Beenden — die
                // Beschriftung ist damit immer die nächste Handlung, nicht
                // der Zustand.
                _KnopfKlein(
                  text: pauseLaeuft ? 'Pause aus' : 'Pause',
                  farbe: pauseLaeuft
                      ? AppColors.warning
                      : AppColors.textSecondary,
                  onTap: _pause,
                ),
                const SizedBox(width: 6),
                _KnopfKlein(
                  text: 'Feierabend',
                  farbe: AppColors.info,
                  onTap: _feierabend,
                ),
              ],
            ),
            // Bewusst kein `?fahrtenZeile` (analysis_options.yaml: der
            // isar_generator kann die Syntax nicht parsen).
            if (fahrtenZeile != null) fahrtenZeile,
            // Auffälliger Balken mit mitlaufender Dauer, solange eine Pause
            // läuft (Daniel 31.07.2026: sonst wird das Ausstempeln beim
            // Weiterfahren vergessen — die Minuten laufen sonst unbemerkt
            // weiter in Arbeitszeit UND Fahrzeit-Lernkurve).
            if (pauseLaeuft) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(38),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pause_circle_filled,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pause seit ${at.pauseStart} · '
                        '${_laufendePauseMinuten(at.pauseStart!)} min',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Die Zeile «Fahrten heute» in zwei Teilen: [basis] grau, [delta] (Zähler
/// − Fahrten) getrennt, damit die Karte es bei einer auffälligen Differenz
/// rot färben kann.
///
/// «Fahrten heute: 7 · 143 km · Zähler 148 km» + «(+5)». Ohne Zählerstand
/// fehlen Zähler und Δ. Rundung wie in der Auswertung: erst auf ganze km,
/// dann das Vorzeichen — sonst stünde bei −0.4 ein «(−0)»; Null ist «±0».
///
/// Fahrten ohne Strecke (seit 29.09.2026 keine Luftlinien-km) werden
/// genannt: «Fahrten heute: 3 · 40 km (1 ohne Strecke) · Zähler 55 km» —
/// dann ohne Δ, denn die Lücke erschiene sonst als «unerklärte» km.
({String basis, String? delta}) fahrtenHeuteText(TagesFahrten f) {
  final ohne = f.fahrtenOhneKm;
  final basis =
      'Fahrten heute: ${f.fahrten.length} · ${f.kmFahrten.round()} km'
      '${ohne > 0 ? ' ($ohne ohne Strecke)' : ''}';
  final zaehler = f.kmZaehler;
  if (zaehler == null) return (basis: basis, delta: null);
  final mitZaehler = '$basis · Zähler $zaehler km';
  // `null`, solange nicht jede Fahrt eine Strecke hat (kmVollstaendig).
  final d = f.differenz;
  if (d == null) return (basis: mitZaehler, delta: null);
  final km = d.round();
  final delta = km == 0 ? '±0' : '${km < 0 ? '−' : '+'}${km.abs()}';
  return (basis: mitZaehler, delta: '($delta)');
}

/// Route der Fahrten eines Tages: `/auswertungen/arbeitstage/2026-09-27/fahrten`.
String fahrtenPfad(DateTime tag) =>
    '/auswertungen/arbeitstage/'
    '${tag.year}-${tag.month.toString().padLeft(2, '0')}-'
    '${tag.day.toString().padLeft(2, '0')}/fahrten';

class _KnopfKlein extends StatelessWidget {
  final String text;
  final Color farbe;
  final VoidCallback onTap;

  const _KnopfKlein({
    required this.text,
    required this.farbe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: farbe.withAlpha(28),
          border: Border.all(color: farbe),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: farbe,
          ),
        ),
      ),
    );
  }
}

/// Kleines Sheet mit einem km-Feld (Arbeitsbeginn).
class _KmSheet extends StatefulWidget {
  final String titel;
  final String hinweis;
  final int? vorbefuellung;

  const _KmSheet({
    required this.titel,
    required this.hinweis,
    this.vorbefuellung,
  });

  @override
  State<_KmSheet> createState() => _KmSheetState();
}

class _KmSheetState extends State<_KmSheet> {
  late final TextEditingController _km = TextEditingController(
    text: widget.vorbefuellung?.toString() ?? '',
  );

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.titel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.hinweis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _km,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'km-Stand',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () =>
                    Navigator.pop(context, int.tryParse(_km.text.trim())),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Starten',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rückgabe des Arbeitstag-Sheets. `null` heisst hier «nicht erfasst /
/// gelöscht» — anders als im Arbeitstag-Record, dessen `beginn` als
/// Achsen-Fallback immer einen Wert trägt (Standard 06:00).
typedef ArbeitstagEingabe = ({
  String? beginn,
  String? ende,
  int? km,
  int? kmStart,
});

/// Sheet «Arbeitstag»: alle vier Rahmen-Felder (Beginn, km Start, Ende,
/// km Abend) — damit lassen sich Fehleingaben direkt korrigieren oder
/// löschen (31.07.2026: versehentlicher 19:29-Start liess sich in der App
/// nicht entfernen).
///
/// Gemeinsam genutzt von Startbildschirm und Tourenplan. Leeres Feld heisst
/// «löschen» (null), ein unbrauchbarer Wert («12:xx», «abc») heisst
/// «unverändert lassen» — sonst liesse sich ein falsch erfasster Wert nie
/// mehr entfernen.
class ArbeitstagAbschlussSheet extends StatefulWidget {
  final Arbeitstag aktuell;

  /// In der DB erfasster Beginn (`null` = nie erfasst) — bewusst nicht
  /// `aktuell.beginn`, das den 06:00-Standard trägt und ein leeres Feld
  /// fälschlich vorbefüllen würde.
  final String? erfassterBeginn;

  const ArbeitstagAbschlussSheet({
    super.key,
    required this.aktuell,
    required this.erfassterBeginn,
  });

  @override
  State<ArbeitstagAbschlussSheet> createState() =>
      _ArbeitstagAbschlussSheetState();
}

class _ArbeitstagAbschlussSheetState extends State<ArbeitstagAbschlussSheet> {
  late final TextEditingController _beginn = TextEditingController(
    text: widget.erfassterBeginn ?? '',
  );
  late final TextEditingController _kmStart = TextEditingController(
    text: widget.aktuell.kmStart?.toString() ?? '',
  );
  late final TextEditingController _ende = TextEditingController(
    // Vorbefüllung mit «jetzt», wenn noch kein Ende erfasst ist — der Knopf
    // wird typischerweise genau beim Feierabend gedrückt.
    text:
        widget.aktuell.ende ??
        hhmmAusMinuten(DateTime.now().hour * 60 + DateTime.now().minute),
  );
  late final TextEditingController _km = TextEditingController(
    text: widget.aktuell.km?.toString() ?? '',
  );

  @override
  void dispose() {
    _beginn.dispose();
    _kmStart.dispose();
    _ende.dispose();
    _km.dispose();
    super.dispose();
  }

  /// Leer = löschen (null), unparsbar = unverändert ([fallback]).
  String? _zeitAus(TextEditingController c, String? fallback) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return minutenAusHhmm(text) != null ? text : fallback;
  }

  int? _kmAus(TextEditingController c, int? fallback) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arbeitstag',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Feld leeren = Wert löschen.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _beginn,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Beginn (HH:mm)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _kmStart,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'km-Stand Start',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ende,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Arbeitsende (HH:mm)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _km,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'km-Stand Abend',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context, (
                    beginn: _zeitAus(_beginn, widget.erfassterBeginn),
                    ende: _zeitAus(_ende, widget.aktuell.ende),
                    km: _kmAus(_km, widget.aktuell.km),
                    kmStart: _kmAus(_kmStart, widget.aktuell.kmStart),
                  )),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Speichern',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
