import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/steuern/steuer_ampel.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');

class SteuernScreen extends ConsumerWidget {
  const SteuernScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(steuernUebersichtProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Steuern')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fehler: $e'),
              const SizedBox(height: 8),
              TapKnopf(
                text: 'Erneut laden',
                primaer: false,
                onTap: () => invalidateSteuern(ref),
              ),
            ],
          ),
        ),
        data: (zeilen) {
          final total = zeilen.fold(0.0, (s, z) => s + z.sollIst.totalBezahlt);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total bezahlte Steuern $kSteuerJahrAb–heute',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${_chf.format(total)} CHF',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (zeilen.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Noch keine Steuerjahre erfasst.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              for (final z in zeilen) _JahrCard(z),
              const SizedBox(height: 12),
              SafeArea(
                top: false,
                child: TapKnopf(
                  text: 'Jahr anlegen',
                  icon: Icons.add,
                  primaer: false,
                  onTap: () => _jahrAnlegen(context, zeilen),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _jahrAnlegen(
    BuildContext context,
    List<SteuerjahrZeile> zeilen,
  ) async {
    final vorhanden = zeilen.map((z) => z.jahr.jahr).toSet();
    final kandidat = [
      for (var j = DateTime.now().year; j >= kSteuerJahrAb; j--)
        if (!vorhanden.contains(j)) j,
    ];
    if (kandidat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alle Jahre seit $kSteuerJahrAb sind vorhanden.'),
        ),
      );
      return;
    }
    final jahr = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jahr anlegen'),
        children: [
          for (final j in kandidat)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, j),
              child: Text('$j'),
            ),
        ],
      ),
    );
    if (jahr != null && context.mounted) {
      context.push('/buchhaltung/steuern/$jahr');
    }
  }
}

class _JahrCard extends StatelessWidget {
  final SteuerjahrZeile z;
  const _JahrCard(this.z);

  @override
  Widget build(BuildContext context) {
    final s = z.sollIst;
    final unvollstaendig = s.sollUnvollstaendig;
    final definitiv = s.totalDefinitivOderNull;
    // Vor der Veranlagung steht nur die provisorische Rechnung — die zeigen
    // wir dann statt eines nichtssagenden «—».
    final provisorisch = [
      s.zeile('bund').provisorisch,
      s.zeile('kanton').provisorisch,
    ].whereType<double>();
    final zeigeProvisorisch = definitiv == null && provisorisch.isNotEmpty;
    return InkWell(
      onTap: () => context.push('/buchhaltung/steuern/${z.jahr.jahr}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${z.jahr.jahr}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    Steuerjahr.statusLabel(z.jahr.status),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.folder,
                  size: 16,
                  color: z.dossier.fehlend.isEmpty
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${z.dossier.vorhanden}/${z.dossier.total}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _z('Gewinn', z.buchhaltungsgewinn),
                _z('steuerbar', z.jahr.steuerbarerGewinn),
                _z(
                  zeigeProvisorisch ? 'Steuern prov.' : 'Steuern def.',
                  zeigeProvisorisch
                      ? provisorisch.reduce((a, b) => a + b)
                      : definitiv,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                AmpelPunkt(
                  farbe: unvollstaendig
                      ? AppColors.warning
                      : ampelFarbe(s.ampel),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _ampelText(s, unvollstaendig),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ampelText(SollIst s, bool unvollstaendig) {
    final bezahlt = 'bezahlt ${_chf.format(s.totalBezahlt)}';
    if (unvollstaendig) return '$bezahlt · Veranlagung fehlt';
    return switch (s.ampel) {
      SteuerAmpel.ausgeglichen => '$bezahlt · ausgeglichen',
      SteuerAmpel.guthaben =>
        '$bezahlt · Guthaben ${_chf.format(s.totalOffen.abs())}',
      SteuerAmpel.schuld => '$bezahlt · offen ${_chf.format(s.totalOffen)}',
    };
  }

  Widget _z(String label, double? v) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        // Lange Beträge (siebenstellig) sprengen bei 375 px sonst die Spalte;
        // skalieren statt kürzen, damit die Zahl lesbar bleibt.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            v == null ? '—' : _chf.format(v),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
