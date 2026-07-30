import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';
import 'dart:async';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';

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
class ArbeitstagKarte extends ConsumerWidget {
  const ArbeitstagKarte({super.key});

  DateTime get _heute {
    final jetzt = DateTime.now();
    return DateTime(jetzt.year, jetzt.month, jetzt.day);
  }

  Future<void> _speichern(
    WidgetRef ref,
    DateTime heute,
    Arbeitstag neu, {
    // In der DB erfasster Beginn — `null` heisst «kein Beginn erfasst» und
    // löscht einen vorhandenen. Bewusst getrennt von `neu.beginn`, das als
    // Achsen-Fallback immer einen Wert trägt (Standard 06:00).
    required String? beginnDb,
    ({double lat, double lng})? startPosition,
    ({double lat, double lng})? endPosition,
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
    );
    ref.invalidate(gespeicherterTagesplanProvider(heute));
  }

  /// GPS holen; Fehler → null plus Hinweis (Zeit/km werden trotzdem erfasst).
  Future<({double lat, double lng})?> _gps(
    ScaffoldMessengerState messenger,
    String wofuer,
  ) async {
    try {
      final p = await GpsService.aktuellePosition();
      return (lat: p.latitude, lng: p.longitude);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$wofuer ohne Standort erfasst ($e).')),
      );
      return null;
    }
  }

  Future<void> _startJetzt(BuildContext context, WidgetRef ref) async {
    final heute = _heute;
    final bisher = ref.read(arbeitstagProvider(heute));
    final messenger = ScaffoldMessenger.of(context);

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
      if (ok != true || !context.mounted) return;
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
    final pos = await _gps(messenger, 'Arbeitsbeginn');

    try {
      await _speichern(
        ref,
        heute,
        (
          beginn: beginn,
          ende: bisher.ende,
          km: bisher.km,
          kmStart: km ?? bisher.kmStart,
          lat: pos?.lat ?? bisher.lat,
          lng: pos?.lng ?? bisher.lng,
          endLat: bisher.endLat,
          endLng: bisher.endLng,
        ),
        beginnDb: beginn,
        startPosition: pos,
      );
      // Wegpunkt in den Routen-Datenstrom (Position ist schon geholt).
      unawaited(
        WegpunktRepository.stempeln(quelle: 'arbeitsbeginn', position: pos),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Arbeitsbeginn $beginn erfasst'
            '${pos != null ? ' (mit Standort)' : ''}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _feierabend(BuildContext context, WidgetRef ref) async {
    final heute = _heute;
    final at = ref.read(arbeitstagProvider(heute));
    final erfassterBeginn = ref
        .read(gespeicherterTagesplanProvider(heute))
        .valueOrNull
        ?.arbeitsbeginn;
    final messenger = ScaffoldMessenger.of(context);
    final eingabe = await showModalBottomSheet<ArbeitstagEingabe>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ArbeitstagAbschlussSheet(
        aktuell: at,
        erfassterBeginn: erfassterBeginn,
      ),
    );
    if (eingabe == null) return;
    // End-Position beim Feierabend stempeln — vervollständigt den Datensatz.
    final pos = await _gps(messenger, 'Feierabend');
    try {
      await _speichern(
        ref,
        heute,
        (
          beginn: eingabe.beginn ?? '06:00',
          ende: eingabe.ende,
          km: eingabe.km,
          kmStart: eingabe.kmStart,
          lat: at.lat,
          lng: at.lng,
          endLat: pos?.lat ?? at.endLat,
          endLng: pos?.lng ?? at.endLng,
        ),
        beginnDb: eingabe.beginn,
        endPosition: pos,
      );
      unawaited(
        WegpunktRepository.stempeln(quelle: 'feierabend', position: pos),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Arbeitstag gespeichert')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      );
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

    String zeile1 = beginnErfasst ? 'Start ${at.beginn}' : 'Start —';
    if (at.kmStart != null) zeile1 += ' · ${at.kmStart} km';
    String zeile2 = 'Ende ${at.ende ?? '—'}';
    if (at.km != null) zeile2 += ' · ${at.km} km';
    if (tagesKm != null) zeile2 += ' · Tag: $tagesKm km';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
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
                        const Icon(Icons.flag, size: 13, color: AppColors.info),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    zeile1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    zeile2,
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
            _KnopfKlein(
              text: beginnErfasst ? 'Neu starten' : 'Jetzt starten',
              farbe: beginnErfasst
                  ? AppColors.textSecondary
                  : AppColors.primary,
              onTap: () => _startJetzt(context, ref),
            ),
            const SizedBox(width: 6),
            _KnopfKlein(
              text: 'Feierabend',
              farbe: AppColors.info,
              onTap: () => _feierabend(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

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
