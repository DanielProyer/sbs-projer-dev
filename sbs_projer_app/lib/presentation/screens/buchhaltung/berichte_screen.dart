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
          for (int y = currentYear; y >= 2019; y--)
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
    final dataAsync = ref.watch(erfolgsrechnungStufenProvider(jahr));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (er) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Erfolgsrechnung $jahr (KMU-Stufengliederung)',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),

                    // Stufe 1: Nettoerlös − Materialaufwand = Bruttoergebnis 1
                    _SummenZeile('Nettoerlös (3)', er.nettoerloes, AppColors.success),
                    _SummenZeile('− Materialaufwand (4)', -er.materialaufwand, AppColors.error),
                    const Divider(),
                    _SummenZeile(
                      'Bruttoergebnis 1',
                      er.bruttoergebnis1,
                      er.bruttoergebnis1 >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),

                    // Stufe 2: − Personalaufwand = Bruttoergebnis 2
                    _SummenZeile('− Personalaufwand (5)', -er.personalaufwand, AppColors.error),
                    const Divider(),
                    _SummenZeile(
                      'Bruttoergebnis 2',
                      er.bruttoergebnis2,
                      er.bruttoergebnis2 >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),

                    // Stufe 3: − Übriger Aufwand = EBITDA
                    _SummenZeile('− Übriger Aufwand (6000–6799)', -er.uebrigerAufwand, AppColors.error),
                    const Divider(),
                    _SummenZeile(
                      'EBITDA',
                      er.ebitda,
                      er.ebitda >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),

                    // Stufe 4: − Abschreibungen = EBIT
                    _SummenZeile('− Abschreibungen (6800)', -er.abschreibungen, AppColors.error),
                    const Divider(),
                    _SummenZeile(
                      'EBIT',
                      er.ebit,
                      er.ebit >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),

                    // Stufe 5: ± Finanzerfolg = EBT
                    _SummenZeile(
                      '± Finanzerfolg (6900)',
                      er.finanzerfolg,
                      er.finanzerfolg >= 0 ? AppColors.success : AppColors.error,
                    ),
                    const Divider(),
                    _SummenZeile(
                      'EBT (vor Steuern)',
                      er.ebt,
                      er.ebt >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),

                    // Stufe 6: ± Nebenerfolg − Steuern = Jahresergebnis
                    _SummenZeile(
                      '± Betriebsfremd/a.o. (7/8000–8800)',
                      er.nebenerfolg,
                      er.nebenerfolg >= 0 ? AppColors.success : AppColors.error,
                    ),
                    _SummenZeile('− Direkte Steuern (8900)', -er.steuern, AppColors.error),
                    const Divider(thickness: 2),
                    _SummenZeile(
                      'Jahresergebnis',
                      er.jahresergebnis,
                      er.jahresergebnis >= 0 ? AppColors.success : AppColors.error,
                      bold: true,
                    ),
                    if (er.nettoerloes == 0 && er.jahresergebnis == 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Keine Buchungen für $jahr erfasst.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MwstTab extends ConsumerStatefulWidget {
  final int jahr;

  const _MwstTab({required this.jahr});

  @override
  ConsumerState<_MwstTab> createState() => _MwstTabState();
}

class _MwstTabState extends ConsumerState<_MwstTab> {
  late int _selectedQuartal;

  static const _abgabefristen = {
    1: '31.05.',
    2: '31.08.',
    3: '30.11.',
    4: '28.02.',
  };

  @override
  void initState() {
    super.initState();
    _selectedQuartal = ((DateTime.now().month - 1) ~/ 3) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(mwstQuartalDetailProvider(widget.jahr));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (rows) {
        final selected = rows.firstWhere(
          (r) => r['quartal'] == _selectedQuartal,
          orElse: () => <String, dynamic>{},
        );

        final umsatz = _d(selected['umsatz']);
        final umsatzsteuer = _d(selected['umsatzsteuer']);
        final vorsteuerMaterial = _d(selected['vorsteuer_material']);
        final vorsteuerBetrieb = _d(selected['vorsteuer_betrieb']);
        final netto = _d(selected['netto_mwst_schuld']);
        final fristJahr = _selectedQuartal == 4 ? widget.jahr + 1 : widget.jahr;
        final frist = '${_abgabefristen[_selectedQuartal]}$fristJahr';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quartal-Auswahl
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Q1')),
                ButtonSegment(value: 2, label: Text('Q2')),
                ButtonSegment(value: 3, label: Text('Q3')),
                ButtonSegment(value: 4, label: Text('Q4')),
              ],
              selected: {_selectedQuartal},
              onSelectionChanged: (sel) =>
                  setState(() => _selectedQuartal = sel.first),
            ),
            const SizedBox(height: 16),

            // MwSt-Detail-Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q$_selectedQuartal ${widget.jahr}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _SummenZeile('Umsatz (Ziff. 200)', umsatz, AppColors.success),
                    _SummenZeile('Umsatzsteuer (Ziff. 382)', umsatzsteuer, AppColors.error),
                    const SizedBox(height: 4),
                    _SummenZeile('Vorsteuer Material (Ziff. 400)', vorsteuerMaterial, AppColors.success),
                    _SummenZeile('Vorsteuer Betrieb (Ziff. 405)', vorsteuerBetrieb, AppColors.success),
                    const Divider(),
                    _SummenZeile(
                      'Zu bezahlen (Ziff. 500)',
                      netto,
                      netto > 0 ? AppColors.error : AppColors.success,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Abgabefrist: $frist',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
