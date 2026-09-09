import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Eine Zeile der Auswertung: eine Route, getrennt nach Gerät.
class NutzungZeile {
  final String route;
  final int handy;
  final int desktop;

  const NutzungZeile({
    required this.route,
    required this.handy,
    required this.desktop,
  });

  int get gesamt => handy + desktop;
}

class NutzungStand {
  final List<NutzungZeile> zeilen;
  final DateTime? von;
  final DateTime? bis;
  final int tage;

  const NutzungStand({
    required this.zeilen,
    required this.von,
    required this.bis,
    required this.tage,
  });

  int get gesamt => zeilen.fold(0, (s, z) => s + z.gesamt);
}

/// Fasst `route_nutzung` (Migration 190) je Route zusammen.
final nutzungProvider = FutureProvider<NutzungStand>((ref) async {
  final rows = await SupabaseService.client
      .from('route_nutzung')
      .select('route, geraet, tag, anzahl')
      .order('route')
      .order('tag');

  final handy = <String, int>{};
  final desktop = <String, int>{};
  final tage = <String>{};
  DateTime? von, bis;

  for (final r in rows) {
    final route = r['route'] as String;
    final anzahl = (r['anzahl'] as num).toInt();
    if (r['geraet'] == 'handy') {
      handy[route] = (handy[route] ?? 0) + anzahl;
    } else {
      desktop[route] = (desktop[route] ?? 0) + anzahl;
    }
    final tag = r['tag'] as String;
    tage.add(tag);
    final d = DateTime.parse(tag);
    if (von == null || d.isBefore(von)) von = d;
    if (bis == null || d.isAfter(bis)) bis = d;
  }

  final zeilen = <NutzungZeile>[
    for (final route in {...handy.keys, ...desktop.keys})
      NutzungZeile(
        route: route,
        handy: handy[route] ?? 0,
        desktop: desktop[route] ?? 0,
      ),
  ]..sort((a, b) => b.gesamt.compareTo(a.gesamt));

  return NutzungStand(zeilen: zeilen, von: von, bis: bis, tage: tage.length);
});

/// Zeigt, welcher Bereich tatsächlich geöffnet wird — die Grundlage für die
/// Frage, was aus dem Hauptmenü verschwinden kann (Punkt 5 der App-Analyse).
class NutzungScreen extends ConsumerWidget {
  const NutzungScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(nutzungProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutzung der App'),
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(nutzungProvider),
          ),
        ],
      ),
      body: stand.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Konnte nicht geladen werden: $e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TapKnopf(
                  text: 'Erneut versuchen',
                  primaer: false,
                  onTap: () => ref.invalidate(nutzungProvider),
                ),
              ],
            ),
          ),
        ),
        data: (s) => s.zeilen.isEmpty
            ? const _NochNichts()
            : _Liste(stand: s),
      ),
    );
  }
}

class _NochNichts extends StatelessWidget {
  const _NochNichts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.query_stats, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Noch nichts gemessen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Die Messung läuft ab jetzt mit. Nach ein paar Arbeitstagen '
              'steht hier, welcher Bereich wie oft geöffnet wurde — '
              'getrennt nach Handy und PC.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  final NutzungStand stand;
  const _Liste({required this.stand});

  @override
  Widget build(BuildContext context) {
    final hoechster =
        stand.zeilen.isEmpty ? 1 : stand.zeilen.first.gesamt.clamp(1, 1 << 30);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Kopf(stand: stand),
        const SizedBox(height: 12),
        for (final z in stand.zeilen)
          _Zeile(zeile: z, hoechster: hoechster),
        const SizedBox(height: 16),
        // Zum Weitergeben: die Zahlen als Text, ohne Screenshot-Abtippen.
        TapKnopf(
          text: 'Als Text kopieren',
          primaer: false,
          icon: Icons.copy,
          onTap: () async {
            final b = StringBuffer()
              ..writeln('Nutzung der App (v$kAppVersion)')
              ..writeln('${stand.tage} Tage, ${stand.gesamt} Aufrufe')
              ..writeln('Route\tHandy\tPC\tGesamt');
            for (final z in stand.zeilen) {
              b.writeln('${z.route}\t${z.handy}\t${z.desktop}\t${z.gesamt}');
            }
            await Clipboard.setData(ClipboardData(text: b.toString()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zahlen kopiert')),
              );
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Kopf extends StatelessWidget {
  final NutzungStand stand;
  const _Kopf({required this.stand});

  String _d(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

  @override
  Widget build(BuildContext context) {
    final handy = stand.zeilen.fold(0, (s, z) => s + z.handy);
    final desktop = stand.zeilen.fold(0, (s, z) => s + z.desktop);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${stand.gesamt} Aufrufe an ${stand.tage} Tagen',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${_d(stand.von)} bis ${_d(stand.bis)} · ${stand.zeilen.length} verschiedene Bereiche',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          // Wrap statt Row: Auf schmalem Schirm oder mit vergrösserter
          // Systemschrift rutscht die zweite Angabe in die nächste Zeile,
          // statt abgeschnitten zu werden.
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Anteil(
                  label: 'Handy',
                  wert: handy,
                  gesamt: stand.gesamt,
                  farbe: AppColors.primary),
              _Anteil(
                  label: 'PC',
                  wert: desktop,
                  gesamt: stand.gesamt,
                  farbe: AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _Anteil extends StatelessWidget {
  final String label;
  final int wert;
  final int gesamt;
  final Color farbe;
  const _Anteil({
    required this.label,
    required this.wert,
    required this.gesamt,
    required this.farbe,
  });

  @override
  Widget build(BuildContext context) {
    final p = gesamt == 0 ? 0 : (wert * 100 / gesamt).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: farbe),
        const SizedBox(width: 6),
        Text('$label $wert ($p %)', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  final NutzungZeile zeile;
  final int hoechster;
  const _Zeile({required this.zeile, required this.hoechster});

  @override
  Widget build(BuildContext context) {
    final anteilHandy = zeile.gesamt == 0 ? 0.0 : zeile.handy / zeile.gesamt;
    final breite = zeile.gesamt / hoechster;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  zeile.route,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${zeile.gesamt}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Ein Balken je Route, in sich geteilt nach Handy und PC — so ist
          // auf einen Blick zu sehen, ob ein Bereich zur Werkstatt oder ins
          // Büro gehört (Befund 4 der Analyse).
          LayoutBuilder(
            builder: (context, c) {
              final voll = c.maxWidth * breite;
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: voll * anteilHandy,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: voll * (1 - anteilHandy),
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
