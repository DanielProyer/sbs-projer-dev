// lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/filter_chrome.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

class MwstAbrechnungScreen extends ConsumerStatefulWidget {
  const MwstAbrechnungScreen({super.key});
  @override
  ConsumerState<MwstAbrechnungScreen> createState() => _MwstAbrechnungScreenState();
}

class _MwstAbrechnungScreenState extends ConsumerState<MwstAbrechnungScreen> {
  int _jahr = DateTime.now().year;
  late int _quartal = ((DateTime.now().month - 1) ~/ 3) + 1;

  static const _abgabefristen = {1: '31.05.', 2: '31.08.', 3: '30.11.', 4: '28.02.'};

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(mwstQuartalDetailProvider(_jahr));
    return Scaffold(
      appBar: AppBar(
        title: const Text('MwSt-Abrechnung'),
        actions: [
          TextButton(
            onPressed: _pickJahr,
            child: FilterChrome(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_jahr',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rows) {
          final sel = rows.firstWhere((r) => r['quartal'] == _quartal,
              orElse: () => <String, dynamic>{});
          final umsatz = _d(sel['umsatz']);
          final umsatzsteuer = _d(sel['umsatzsteuer']);
          final vstMaterial = _d(sel['vorsteuer_material']);
          final vstBetrieb = _d(sel['vorsteuer_betrieb']);
          final netto = _d(sel['netto_mwst_schuld']);
          final fristJahr = _quartal == 4 ? _jahr + 1 : _jahr;
          final frist = '${_abgabefristen[_quartal]}$fristJahr';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Q1')),
                  ButtonSegment(value: 2, label: Text('Q2')),
                  ButtonSegment(value: 3, label: Text('Q3')),
                  ButtonSegment(value: 4, label: Text('Q4')),
                ],
                selected: {_quartal},
                onSelectionChanged: (s) => setState(() => _quartal = s.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q$_quartal $_jahr',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _z('Umsatz (Ziff. 200)', umsatz, AppColors.success),
                      _z('Umsatzsteuer (Ziff. 382)', umsatzsteuer, AppColors.error),
                      const SizedBox(height: 4),
                      _z('Vorsteuer Material (Ziff. 400)', vstMaterial, AppColors.success),
                      _z('Vorsteuer Betrieb (Ziff. 405)', vstBetrieb, AppColors.success),
                      const Divider(),
                      _z('Zu bezahlen (Ziff. 500)', netto,
                          netto > 0 ? AppColors.error : AppColors.success, bold: true),
                      const SizedBox(height: 8),
                      Text('Abgabefrist: $frist',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _pickJahr() {
    final jetzt = DateTime.now().year;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jahr wählen'),
        children: [
          for (int y = jetzt; y >= 2019; y--)
            SimpleDialogOption(
              onPressed: () {
                setState(() => _jahr = y);
                Navigator.pop(ctx);
              },
              child: Text('$y', style: TextStyle(fontWeight: y == _jahr ? FontWeight.w700 : null)),
            ),
        ],
      ),
    );
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Widget _z(String label, double betrag, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: 14)),
            Text('${chf(betrag)} CHF',
                style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: 14, color: color)),
          ],
        ),
      );
}
