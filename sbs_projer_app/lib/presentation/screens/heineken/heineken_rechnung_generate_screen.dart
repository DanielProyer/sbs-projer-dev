import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/heineken_monats_daten.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_providers.dart';
import 'package:sbs_projer_app/services/rechnung/heineken_rechnung_service.dart';

class HeinekenRechnungGenerateScreen extends ConsumerStatefulWidget {
  const HeinekenRechnungGenerateScreen({super.key});

  @override
  ConsumerState<HeinekenRechnungGenerateScreen> createState() =>
      _HeinekenRechnungGenerateScreenState();
}

class _HeinekenRechnungGenerateScreenState
    extends ConsumerState<HeinekenRechnungGenerateScreen> {
  late DateTime _selectedMonat;
  HeinekenMonatsDaten? _daten;
  bool _loading = false;
  bool _generating = false;
  String? _error;

  static const _monatNamen = [
    '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  @override
  void initState() {
    super.initState();
    // Default: letzter Monat
    final now = DateTime.now();
    _selectedMonat = DateTime(now.year, now.month - 1, 1);
    _loadDaten();
  }

  Future<void> _loadDaten() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final daten =
          await HeinekenRechnungService.sammleMonatsDaten(_selectedMonat);
      setState(() {
        _daten = daten;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generate() async {
    if (_daten == null) return;
    setState(() => _generating = true);
    try {
      final rechnung =
          await HeinekenRechnungService.erstelleMonatsrechnung(_daten!);
      if (mounted) {
        ref.invalidate(heinekenRechnungenProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rechnung erstellt!')),
        );
        context.pushReplacement('/heineken/${rechnung.id}');
      }
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _pickMonat() {
    final now = DateTime.now();
    // Jahre von 2024 bis aktuell
    final jahre = <int>[];
    for (int y = now.year; y >= 2024; y--) {
      jahre.add(y);
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        int tempJahr = _selectedMonat.year;
        int tempMonat = _selectedMonat.month;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Maximal wählbarer Monat
            final maxMonat = tempJahr == now.year ? now.month : 12;
            if (tempMonat > maxMonat) {
              tempMonat = maxMonat;
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Monat wählen',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  // Jahr
                  SegmentedButton<int>(
                    segments: jahre
                        .map((y) => ButtonSegment(value: y, label: Text('$y')))
                        .toList(),
                    selected: {tempJahr},
                    onSelectionChanged: (sel) {
                      setSheetState(() => tempJahr = sel.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Monate als Grid
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final enabled = m <= maxMonat;
                      final selected = m == tempMonat;
                      return FilledButton(
                        onPressed: enabled
                            ? () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedMonat = DateTime(tempJahr, m, 1);
                                });
                                _loadDaten();
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: selected
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          foregroundColor: selected
                              ? Theme.of(ctx).colorScheme.onPrimary
                              : Theme.of(ctx).colorScheme.onSurface,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          _monatNamen[m].substring(0, 3),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neue Heineken-Rechnung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Monat-Auswahl
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Rechnungsperiode'),
              subtitle: Text(
                '${_monatNamen[_selectedMonat.month]} ${_selectedMonat.year}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.edit),
              onTap: _pickMonat,
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Fehler beim Laden der Daten',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadDaten,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            )
          else if (_daten != null) ...[
            // Übersicht der Kategorien
            Text(
              'Übersicht',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            ...(_daten!.kategorien.map((k) {
              final (name, positionen, total) = k;
              return _KategorieCard(
                name: name,
                anzahl: positionen.length,
                total: total,
              );
            })),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // Totale
            _TotalRow(label: 'Total', value: _daten!.totalNetto),
            _TotalRow(
                label: 'Mehrwertsteuer (8.1%)', value: _daten!.mwstBetrag),
            _TotalRow(
              label: 'GESAMTTOTAL INKL. MWST',
              value: _daten!.totalBrutto,
              bold: true,
            ),

            const SizedBox(height: 24),

            // Generieren-Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long),
                label: Text(_generating
                    ? 'Wird generiert...'
                    : 'Rechnung generieren'),
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _KategorieCard extends StatelessWidget {
  final String name;
  final int anzahl;
  final double total;

  const _KategorieCard({
    required this.name,
    required this.anzahl,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14)),
                  Text(
                    '$anzahl Einträge',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '${total.toStringAsFixed(2)} CHF',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} CHF', style: style),
        ],
      ),
    );
  }
}
