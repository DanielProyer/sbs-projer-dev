import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';

/// Arbeitstag-Karte auf dem Startbildschirm (Daniel 29.07.2026):
/// Arbeitsbeginn, Arbeitsende und km-Stand direkt dort erfassen, wo der Tag
/// beginnt und endet — nicht erst im Tourenplan.
///
/// «Jetzt starten» stempelt die aktuelle Uhrzeit UND die GPS-Position:
/// Der Tag beginnt nicht immer am festen Startort (Zuhause Domat/Ems),
/// sondern oft anderswo (Chur) — Anfahrt/Heimweg der Zeitachse rechnen
/// von der gestempelten Position. Schlägt GPS fehl, wird nur die Zeit
/// erfasst (die Zeitachse fällt auf den festen Startort zurück).
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
    ({double lat, double lng})? startPosition,
  }) async {
    ref.read(arbeitstagProvider(heute).notifier).state = neu;
    // Einträge bewusst leer: existiert schon eine Plan-Zeile, fasst
    // arbeitstagFelderSpeichern sie per update nicht an; fehlt sie, entsteht
    // sie mit leerem Plan — der Tourenplan füllt sie später selbst.
    await arbeitstagFelderSpeichern(
      heute,
      const [],
      arbeitsbeginn: neu.beginn,
      arbeitsende: neu.ende,
      kmStand: neu.km,
      startPosition: startPosition,
    );
    ref.invalidate(gespeicherterTagesplanProvider(heute));
  }

  Future<void> _startJetzt(BuildContext context, WidgetRef ref) async {
    final heute = _heute;
    final jetzt = DateTime.now();
    final beginn = hhmmAusMinuten(jetzt.hour * 60 + jetzt.minute);
    final messenger = ScaffoldMessenger.of(context);

    // GPS zuerst versuchen — ohne Position trotzdem die Zeit stempeln.
    ({double lat, double lng})? pos;
    try {
      final p = await GpsService.aktuellePosition();
      pos = (lat: p.latitude, lng: p.longitude);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ohne Standort gestartet ($e) — Anfahrt rechnet vom festen '
            'Startort.',
          ),
        ),
      );
    }

    final bisher = ref.read(arbeitstagProvider(heute));
    try {
      await _speichern(ref, heute, (
        beginn: beginn,
        ende: bisher.ende,
        km: bisher.km,
        lat: pos?.lat ?? bisher.lat,
        lng: pos?.lng ?? bisher.lng,
      ), startPosition: pos);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pos != null
                ? 'Arbeitsbeginn $beginn mit Standort erfasst'
                : 'Arbeitsbeginn $beginn erfasst',
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
    final messenger = ScaffoldMessenger.of(context);
    final ergebnis = await showModalBottomSheet<Arbeitstag>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ArbeitstagAbschlussSheet(aktuell: at),
    );
    if (ergebnis == null) return;
    try {
      await _speichern(ref, heute, ergebnis);
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
        lat: g.startLat,
        lng: g.startLng,
      );
    });
    final gespeichert = ref
        .watch(gespeicherterTagesplanProvider(heute))
        .valueOrNull;
    final at = ref.watch(arbeitstagProvider(heute));
    // «erfasst» heisst: in der DB steht ein Beginn — nicht der 06:00-Standard.
    final beginnErfasst = gespeichert?.arbeitsbeginn != null;
    final mitStandort = at.lat != null && at.lng != null;

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
                  const Text(
                    'Arbeitstag',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Start ${beginnErfasst ? at.beginn : '—'}'
                          ' · Ende ${at.ende ?? '—'}'
                          ' · ${at.km != null ? '${at.km} km' : '— km'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (mitStandort) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.location_on,
                          size: 13,
                          color: AppColors.success,
                        ),
                      ],
                    ],
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

/// Sheet «Arbeitstag abschliessen»: Arbeitsende + km-Stand.
///
/// Gemeinsam genutzt von Startbildschirm und Tourenplan. Leeres Feld heisst
/// «löschen» (null), ein unbrauchbarer Wert («12:xx», «abc») heisst
/// «unverändert lassen» — sonst liesse sich ein falsch erfasstes Arbeitsende
/// nie mehr entfernen.
class ArbeitstagAbschlussSheet extends StatefulWidget {
  final Arbeitstag aktuell;

  const ArbeitstagAbschlussSheet({super.key, required this.aktuell});

  @override
  State<ArbeitstagAbschlussSheet> createState() =>
      _ArbeitstagAbschlussSheetState();
}

class _ArbeitstagAbschlussSheetState extends State<ArbeitstagAbschlussSheet> {
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
    _ende.dispose();
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
              const Text(
                'Arbeitstag abschliessen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ende,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Arbeitsende (HH:mm)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'km-Stand',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  final endeText = _ende.text.trim();
                  final kmText = _km.text.trim();
                  final String? ende = endeText.isEmpty
                      ? null
                      : (minutenAusHhmm(endeText) != null
                            ? endeText
                            : widget.aktuell.ende);
                  final int? km = kmText.isEmpty
                      ? null
                      : (int.tryParse(kmText) ?? widget.aktuell.km);
                  Navigator.pop(context, (
                    beginn: widget.aktuell.beginn,
                    ende: ende,
                    km: km,
                    lat: widget.aktuell.lat,
                    lng: widget.aktuell.lng,
                  ));
                },
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
    );
  }
}
