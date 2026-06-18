// lib/presentation/screens/buchhaltung/widgets/bilanz_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

class BilanzView extends ConsumerWidget {
  final DateTime stichtag;
  const BilanzView({super.key, required this.stichtag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bilanzStichtagProvider(stichtag));
    final df = DateFormat('dd.MM.yyyy');
    final provisorisch = !stichtag.isBefore(DateTime(DateTime.now().year, 1, 1));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (b) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Bilanz per ${df.format(stichtag)}',
                  style: Theme.of(context).textTheme.titleMedium),
              if (provisorisch) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('provisorisch',
                      style: TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _seite('Aktiven', b.aktiven, b.totalAktiven),
          const SizedBox(height: 16),
          _seite('Passiven', b.passiven, b.totalPassiven),
          const SizedBox(height: 16),
          _differenz(b.differenz),
        ],
      ),
    );
  }

  Widget _seite(String titel, List<BilanzGruppe> gruppen, double total) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Divider(),
              for (final g in gruppen) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(g.titel, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                for (final p in g.posten)
                  _zeile('${p.kontonummer}  ${p.bezeichnung}', p.summe),
                _zeile('Total ${g.titel}', g.summe, fett: true),
              ],
              const Divider(thickness: 2),
              _zeile('Total $titel', total, fett: true),
            ],
          ),
        ),
      );

  Widget _zeile(String label, double betrag, {bool fett = false}) {
    final style = TextStyle(
        fontWeight: fett ? FontWeight.w700 : FontWeight.w400,
        color: betrag < 0 ? AppColors.error : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${chf(betrag)} CHF',
              style: style.copyWith(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _differenz(double diff) {
    final ok = diff.abs() < 0.005;
    return Card(
      color: ok ? AppColors.success.withAlpha(25) : AppColors.error.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ok ? 'Aktiven = Passiven ✓' : 'Differenz (nicht ausgeglichen)',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? AppColors.success : AppColors.error)),
            Text('${chf(diff)} CHF',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? AppColors.success : AppColors.error)),
          ],
        ),
      ),
    );
  }
}
