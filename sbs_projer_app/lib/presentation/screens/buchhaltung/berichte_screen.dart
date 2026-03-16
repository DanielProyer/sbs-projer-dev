import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

class BerichteScreen extends ConsumerStatefulWidget {
  const BerichteScreen({super.key});

  @override
  ConsumerState<BerichteScreen> createState() => _BerichteScreenState();
}

class _BerichteScreenState extends ConsumerState<BerichteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedJahr = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Berichte'),
        actions: [
          TextButton(
            onPressed: _showJahrPicker,
            child: Text(
              '$_selectedJahr',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Erfolgsrechnung'),
            Tab(text: 'MwSt-Abrechnung'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ErfolgsrechnungTab(jahr: _selectedJahr),
          _MwstTab(jahr: _selectedJahr),
        ],
      ),
    );
  }

  void _showJahrPicker() {
    final currentYear = DateTime.now().year;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jahr wählen'),
        children: [
          for (int y = currentYear; y >= currentYear - 3; y--)
            SimpleDialogOption(
              onPressed: () {
                setState(() => _selectedJahr = y);
                Navigator.pop(ctx);
              },
              child: Text(
                '$y',
                style: TextStyle(
                  fontWeight: y == _selectedJahr ? FontWeight.w700 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErfolgsrechnungTab extends ConsumerWidget {
  final int jahr;

  const _ErfolgsrechnungTab({required this.jahr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(erfolgsrechnungProvider(jahr));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'Keine Daten für $jahr',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        // Jahrestotale berechnen
        double totalErtrag = 0;
        double totalMaterial = 0;
        double totalPersonal = 0;
        double totalBetrieb = 0;
        for (final row in rows) {
          totalErtrag += _d(row['ertrag']);
          totalMaterial += _d(row['materialaufwand']);
          totalPersonal += _d(row['personalaufwand']);
          totalBetrieb += _d(row['betriebsaufwand']);
        }
        final totalErgebnis = totalErtrag - totalMaterial - totalPersonal - totalBetrieb;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Jahreszusammenfassung
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jahresübersicht $jahr',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _SummenZeile('Ertrag', totalErtrag, AppColors.success),
                    _SummenZeile('Materialaufwand', -totalMaterial, AppColors.error),
                    _SummenZeile('Personalaufwand', -totalPersonal, AppColors.error),
                    _SummenZeile('Betriebsaufwand', -totalBetrieb, AppColors.error),
                    const Divider(),
                    _SummenZeile(
                      'Betriebsergebnis',
                      totalErgebnis,
                      totalErgebnis >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Monatliche Details
            Text(
              'Monatliche Übersicht',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...rows.map((row) {
              final monat = row['monat'] as int;
              final ertrag = _d(row['ertrag']);
              final ergebnis = _d(row['betriebsergebnis']);
              return Card(
                child: ListTile(
                  title: Text(
                    _monatName(monat),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ertrag: ${ertrag.toStringAsFixed(2)} CHF',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${ergebnis.toStringAsFixed(2)} CHF',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ergebnis >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;

  static String _monatName(int m) {
    const namen = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return namen[m];
  }
}

class _MwstTab extends ConsumerWidget {
  final int jahr;

  const _MwstTab({required this.jahr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(mwstAbrechnungProvider(jahr));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'Keine MwSt-Daten für $jahr',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: rows.map((row) {
            final quartal = row['quartal'] as int;
            final umsatzsteuer = _d(row['umsatzsteuer']);
            final vorsteuerInv = _d(row['vorsteuer_investitionen']);
            final vorsteuerBetrieb = _d(row['vorsteuer_betrieb']);
            final netto = _d(row['netto_mwst_schuld']);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q$quartal $jahr',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _SummenZeile('Umsatzsteuer (geschuldet)', umsatzsteuer, AppColors.error),
                    _SummenZeile('Vorsteuer Investitionen', -vorsteuerInv, AppColors.success),
                    _SummenZeile('Vorsteuer Betriebsaufwand', -vorsteuerBetrieb, AppColors.success),
                    const Divider(),
                    _SummenZeile(
                      'Netto MwSt-Schuld',
                      netto,
                      netto > 0 ? AppColors.error : AppColors.success,
                      bold: true,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;
}

class _SummenZeile extends StatelessWidget {
  final String label;
  final double betrag;
  final Color color;
  final bool bold;

  const _SummenZeile(this.label, this.betrag, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
          Text(
            '${betrag.toStringAsFixed(2)} CHF',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
