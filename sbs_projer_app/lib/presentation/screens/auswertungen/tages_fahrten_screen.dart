import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart'
    show kurzeFehlermeldung;
import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart'
    show nurDatum;
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart'
    show hhmmAusMinuten;
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/rueckweg_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Fahrten eines Arbeitstags, abgeleitet aus Arbeitsbeginn, Einsätzen und
/// Feierabend («Fahrten aus der Kette», Stufe 1, 27.09.2026) — mit der
/// Kontrolle gegen den Zählerstand. Nur Anzeige: nichts davon ist
/// gespeichert, und es ist kein Fahrtenbuch.
///
/// Knöpfe aus `TapKnopf`/GestureDetector, keine Material-Buttons
/// (CanvasKit-Falle, CLAUDE.md).
class TagesFahrtenScreen extends ConsumerWidget {
  final DateTime datum;

  const TagesFahrtenScreen({super.key, required this.datum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = nurDatum(datum);
    final fahrten = ref.watch(tagesFahrtenProvider(tag));

    return Scaffold(
      appBar: AppBar(
        leading: const RueckwegKnopf(fallback: '/auswertungen/arbeitstage'),
        title: Text('Fahrten · ${tagesTitel(tag)}'),
      ),
      // skipLoadingOnReload: Kommen nachgeroutete Distanzen herein, rechnet
      // der Monat neu — die bisherigen Fahrten bleiben so lange stehen,
      // statt kurz einem Ladekreis zu weichen.
      body: fahrten.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Fehler(
          meldung: kurzeFehlermeldung(e),
          onNeuLaden: () =>
              fahrtenNeuLaden(ref, (jahr: tag.year, monat: tag.month)),
        ),
        data: (t) => t == null ? const _NichtsErfasst() : _Inhalt(t: t),
      ),
    );
  }
}

const _wochentagKurz = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// «Fr 25.09.» — Wochentag und Datum ohne Jahr, wie in der Auswertung.
String tagesTitel(DateTime tag) =>
    '${_wochentagKurz[tag.weekday - 1]} '
    '${tag.day.toString().padLeft(2, '0')}.'
    '${tag.month.toString().padLeft(2, '0')}.';

/// Zähler − Fahrten mit Vorzeichen: «+16.4 km» / «−3.0 km». Erst auf die
/// angezeigte Stelle runden, dann das Vorzeichen wählen — sonst stünde bei
/// −0.04 ein «−0.0 km»; Null heisst «±0.0 km».
String differenzText(double differenz) {
  final gerundet = (differenz * 10).round() / 10;
  if (gerundet == 0) return '±${kmText(0)}';
  return '${gerundet < 0 ? '−' : '+'}${kmText(gerundet.abs())}';
}

/// Herkunft der km einer Fahrt, kurz für die Karte.
String kmQuelleText(String? quelle) => switch (quelle) {
  kKmQuelleAnfahrt => 'Anfahrt',
  kKmQuelleRoute => 'geroutet',
  kKmQuelleLuftlinie => '≈ Luftlinie',
  _ => 'ohne Distanz',
};

class _Inhalt extends StatelessWidget {
  final TagesFahrten t;

  const _Inhalt({required this.t});

  @override
  Widget build(BuildContext context) {
    final differenz = t.differenz;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        DetailKarte(
          titel: 'Tag im Überblick',
          icon: Icons.route,
          kinder: [
            InfoZeile('Fahrten-km', kmText(t.kmFahrten), labelBreite: 110),
            InfoZeile(
              'Zähler-km',
              t.kmZaehler == null ? 'nicht erfasst' : '${t.kmZaehler} km',
              labelBreite: 110,
            ),
            if (differenz != null)
              _DifferenzZeile(
                differenz: differenz,
                auffaellig: t.differenzAuffaellig,
              ),
            InfoZeile(
              'Fahrten',
              t.fahrtenNurLuftlinie > 0
                  ? '${t.fahrten.length} (davon ${t.fahrtenNurLuftlinie} '
                        'geschätzt)'
                  : '${t.fahrten.length}',
              labelBreite: 110,
            ),
          ],
        ),
        DetailKarte(
          titel: 'Befunde',
          icon: Icons.warning_amber_rounded,
          kinder: [for (final b in t.befunde) _BefundZeile(text: b)],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Fahrten',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (t.fahrten.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Keine Fahrten — für eine Fahrt braucht es mindestens zwei '
              'verschiedene Orte (Arbeitsbeginn, Einsätze, Feierabend).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        for (final f in t.fahrten) _FahrtKarte(f: f),
        if (t.ohneZeit.isNotEmpty) ...[
          const SizedBox(height: 6),
          DetailKarte(
            titel: 'Einsätze ohne Zeit',
            icon: Icons.schedule,
            kinder: [
              for (final e in t.ohneZeit)
                InfoZeile(
                  einsatzTypName(e.typ),
                  e.betriebName ?? 'ohne Betrieb',
                  labelBreite: 90,
                ),
            ],
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Abgeleitet aus Arbeitsbeginn, Einsätzen und Feierabend; km aus '
            'gerouteten Strecken, sonst aus der Luftlinie geschätzt. Nichts '
            'davon ist gespeichert — kein Fahrtenbuch.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _DifferenzZeile extends StatelessWidget {
  final double differenz;
  final bool auffaellig;

  const _DifferenzZeile({required this.differenz, required this.auffaellig});

  @override
  Widget build(BuildContext context) {
    // Die Richtung steht dabei: Ohne sie ist «+16 km» mehrdeutig (mehr
    // gefahren oder mehr erklärt?).
    const grau = TextStyle(color: AppColors.textSecondary, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Differenz', style: grau),
                Text(
                  '(Zähler − Fahrten)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auffaellig
                      ? '${differenzText(differenz)} — auffällig'
                      : '${differenzText(differenz)} — im Rahmen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: auffaellig
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: auffaellig ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                const Text(
                  '+ = mehr gefahren als erklärt',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BefundZeile extends StatelessWidget {
  final String text;

  const _BefundZeile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _FahrtKarte extends StatelessWidget {
  final Fahrt f;

  const _FahrtKarte({required this.f});

  @override
  Widget build(BuildContext context) {
    final ab = f.abfahrtMin, an = f.ankunftMin, dauer = f.dauerMin;
    final zeiten = [
      '${ab == null ? '?' : hhmmAusMinuten(ab)} → '
          '${an == null ? '?' : hhmmAusMinuten(an)}',
      if (dauer != null) '$dauer min',
    ].join(' · ');
    final km = f.km;
    final geschaetzt = f.kmQuelle == kKmQuelleLuftlinie;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              zeiten,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${f.von.name} → ${f.nach.name}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  km == null ? '– km' : kmText(km),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: km == null || geschaetzt
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kmQuelleText(f.kmQuelle),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fehler extends StatelessWidget {
  final String meldung;
  final VoidCallback onNeuLaden;

  const _Fehler({required this.meldung, required this.onNeuLaden});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Fahrten konnten nicht geladen werden.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              meldung,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TapKnopf(
              text: 'Erneut laden',
              icon: Icons.refresh,
              onTap: onNeuLaden,
            ),
          ],
        ),
      ),
    );
  }
}

class _NichtsErfasst extends StatelessWidget {
  const _NichtsErfasst();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Für diesen Tag ist weder ein Arbeitstag noch ein Einsatz erfasst.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
