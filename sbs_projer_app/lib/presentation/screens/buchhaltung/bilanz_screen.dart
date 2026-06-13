import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

class BilanzScreen extends ConsumerStatefulWidget {
  const BilanzScreen({super.key});
  @override
  ConsumerState<BilanzScreen> createState() => _BilanzScreenState();
}

class _BilanzScreenState extends ConsumerState<BilanzScreen> {
  int _jahr = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bilanzProvider(_jahr));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilanz'),
        actions: [
          TextButton(
            onPressed: _pickJahr,
            child: Text('$_jahr',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (b) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                _jahr >= DateTime.now().year
                    ? 'Per 31.12.$_jahr (provisorisch)'
                    : 'Per 31.12.$_jahr',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _seite('Aktiven', b.aktiven, b.totalAktiven),
            const SizedBox(height: 16),
            _seite('Passiven', b.passiven, b.totalPassiven),
            const SizedBox(height: 16),
            _differenz(b.differenz),
          ],
        ),
      ),
    );
  }

  Widget _seite(String titel, List<BilanzGruppe> gruppen, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titel,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const Divider(),
            for (final g in gruppen) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(g.titel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final p in g.posten)
                _zeile('${p.kontonummer} ${p.bezeichnung}', p.summe),
              _zeile('Total ${g.titel}', g.summe, fett: true),
            ],
            const Divider(),
            _zeile('Total $titel', total, fett: true),
          ],
        ),
      ),
    );
  }

  Widget _zeile(String label, double betrag, {bool fett = false}) {
    final style = TextStyle(
        fontWeight: fett ? FontWeight.w700 : FontWeight.w400,
        color: betrag < 0 ? AppColors.error : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${betrag.toStringAsFixed(2)} CHF', style: style),
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
            Text('${diff.toStringAsFixed(2)} CHF',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? AppColors.success : AppColors.error)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickJahr() async {
    final jetzt = DateTime.now().year;
    final jahr = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Geschäftsjahr'),
        children: [
          for (int j = jetzt; j >= 2019; j--)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, j),
              child: Text('$j'),
            ),
        ],
      ),
    );
    if (jahr != null) setState(() => _jahr = jahr);
  }
}
