import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/presentation/providers/jahresrechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/preis_providers.dart';
import 'package:sbs_projer_app/services/rechnung/jahresrechnung_service.dart';

class JahresrechnungGenerateScreen extends ConsumerStatefulWidget {
  const JahresrechnungGenerateScreen({super.key});

  @override
  ConsumerState<JahresrechnungGenerateScreen> createState() =>
      _JahresrechnungGenerateScreenState();
}

class _JahresrechnungGenerateScreenState
    extends ConsumerState<JahresrechnungGenerateScreen> {
  late int _selectedJahr;
  final Map<String, List<ReinigungLocal>> _reinigungen = {};
  final Map<String, String> _generiert = {}; // betriebId → rechnungId
  bool _loading = false;
  bool _generatingAll = false;
  String? _generatingBetriebId;
  String? _error;

  static double _round5Rappen(double v) => (v * 20).roundToDouble() / 20;
  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  @override
  void initState() {
    super.initState();
    _selectedJahr = DateTime.now().year;
  }

  Future<void> _loadReinigungen(List<BetriebLocal> betriebe) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _reinigungen.clear();
      for (final b in betriebe) {
        final reinigungen = await JahresrechnungService.sammleReinigungen(
            b.serverId!, _selectedJahr);
        _reinigungen[b.serverId!] = reinigungen;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generateForBetrieb(BetriebLocal betrieb) async {
    final reinigungen = _reinigungen[betrieb.serverId!];
    if (reinigungen == null || reinigungen.isEmpty) return;

    setState(() => _generatingBetriebId = betrieb.serverId);
    try {
      final rechnung = await JahresrechnungService.erstelleJahresrechnung(
        betrieb: betrieb,
        reinigungen: reinigungen,
        jahr: _selectedJahr,
      );
      if (mounted) {
        setState(() {
          _generiert[betrieb.serverId!] = rechnung.id;
          _generatingBetriebId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jahresrechnung ${betrieb.name} erstellt')),
        );
        context.push('/rechnungen/${rechnung.id}');
      }
    } catch (e) {
      setState(() => _generatingBetriebId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _generateAll(List<BetriebLocal> betriebe) async {
    setState(() => _generatingAll = true);
    int count = 0;
    for (final b in betriebe) {
      if (_generiert.containsKey(b.serverId)) continue;
      final reinigungen = _reinigungen[b.serverId!];
      if (reinigungen == null || reinigungen.isEmpty) continue;

      try {
        final rechnung = await JahresrechnungService.erstelleJahresrechnung(
          betrieb: b,
          reinigungen: reinigungen,
          jahr: _selectedJahr,
        );
        setState(() => _generiert[b.serverId!] = rechnung.id);
        count++;
      } catch (e) {
        debugPrint('Jahresrechnung ${b.name} fehlgeschlagen: $e');
      }
    }
    setState(() => _generatingAll = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count Jahresrechnungen erstellt')),
      );
      ref.invalidate(jahresrechnungBetriebeProvider);
    }
  }

  /// Berechnet Totale über alle Betriebe.
  ({int anzahlBetriebe, int anzahlReinigungen, double netto, double mwst, double brutto})
      _berechneTotale() {
    int betriebe = 0;
    int reinigungen = 0;
    double netto = 0;

    for (final entry in _reinigungen.entries) {
      if (_generiert.containsKey(entry.key)) continue;
      if (entry.value.isEmpty) continue;
      betriebe++;
      reinigungen += entry.value.length;
      for (final r in entry.value) {
        netto += JahresrechnungService.calcNetto(r);
      }
    }

    final preise = ref.read(aktuellePreiseProvider).valueOrNull;
    final mwstFaktor = preise?.mwstFaktor ?? 0.081;
    final mwst = _round2(netto * mwstFaktor);
    final brutto = _round5Rappen(netto + mwst);
    return (
      anzahlBetriebe: betriebe,
      anzahlReinigungen: reinigungen,
      netto: netto,
      mwst: mwst,
      brutto: brutto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final betriebeAsync = ref.watch(jahresrechnungBetriebeProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Jahresrechnungen')),
      body: betriebeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Fehler: $e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (betriebe) {
          if (betriebe.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      'Keine Betriebe mit Rechnungsstellung\n"Jahresrechnung" gefunden.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          // Reinigungen laden wenn noch nicht geladen
          if (_reinigungen.isEmpty && !_loading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadReinigungen(betriebe);
            });
          }

          final totale = _berechneTotale();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Jahr-Auswahl ──
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withAlpha(25),
                    child: const Icon(Icons.calendar_today,
                        color: AppColors.primary, size: 20),
                  ),
                  title: const Text('Geschäftsjahr'),
                  subtitle: Text(
                    '$_selectedJahr',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.unfold_more),
                  onTap: () => _showJahrPicker(betriebe, now),
                ),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else ...[
                // ── Zusammenfassung ──
                if (_reinigungen.isNotEmpty) ...[
                  _buildSummaryCard(totale),
                  const SizedBox(height: 20),
                ],

                // ── Betrieb-Liste ──
                Text(
                  'Betriebe (${betriebe.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                ...betriebe.map((b) => _buildBetriebCard(b)),

                const SizedBox(height: 20),

                // ── Alle generieren ──
                if (totale.anzahlBetriebe > 0)
                  _buildGenerateAllButton(betriebe, totale),
              ],
            ],
          );
        },
      ),
    );
  }

  // ─── WIDGETS ───

  Widget _buildSummaryCard(
    ({int anzahlBetriebe, int anzahlReinigungen, double netto, double mwst, double brutto}) totale,
  ) {
    return Card(
      color: AppColors.primary.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Zusammenfassung $_selectedJahr',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SummaryChip(
                  label: 'Betriebe',
                  value: '${totale.anzahlBetriebe}',
                  icon: Icons.store,
                ),
                const SizedBox(width: 12),
                _SummaryChip(
                  label: 'Reinigungen',
                  value: '${totale.anzahlReinigungen}',
                  icon: Icons.cleaning_services,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _TotalRow(label: 'Netto', value: totale.netto),
            _TotalRow(label: 'MwSt ${ref.read(aktuellePreiseProvider).valueOrNull?.mwstLabel ?? '8.1%'}', value: totale.mwst),
            const Divider(height: 16),
            _TotalRow(
                label: 'Gesamttotal', value: totale.brutto, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBetriebCard(BetriebLocal b) {
    final reinigungen = _reinigungen[b.serverId] ?? [];
    final istGeneriert = _generiert.containsKey(b.serverId);
    final istAktiv = _generatingBetriebId == b.serverId;
    final netto = reinigungen.fold<double>(
        0, (sum, r) => sum + JahresrechnungService.calcNetto(r));
    final mwstF = ref.read(aktuellePreiseProvider).valueOrNull?.mwstFaktor ?? 0.081;
    final brutto = _round5Rappen(netto + _round2(netto * mwstF));
    final dateFormat = DateFormat('dd.MM.');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Betriebname + Status
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: istGeneriert
                      ? AppColors.success.withAlpha(25)
                      : reinigungen.isEmpty
                          ? AppColors.inaktiv.withAlpha(25)
                          : AppColors.primary.withAlpha(25),
                  child: Icon(
                    istGeneriert
                        ? Icons.check
                        : reinigungen.isEmpty
                            ? Icons.do_not_disturb
                            : Icons.store,
                    color: istGeneriert
                        ? AppColors.success
                        : reinigungen.isEmpty
                            ? AppColors.inaktiv
                            : AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (b.ort != null && b.ort!.isNotEmpty)
                        Text(
                          b.ort!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (istGeneriert)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Erstellt',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success),
                    ),
                  )
                else if (reinigungen.isEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.inaktiv.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Keine',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),

            // ── Generiert: Anzeigen-Button ──
            if (istGeneriert) ...[
              const Divider(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/rechnungen/${_generiert[b.serverId]}'),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Rechnung anzeigen'),
                ),
              ),
            ],

            if (reinigungen.isNotEmpty && !istGeneriert) ...[
              const Divider(height: 20),

              // Reinigungen Zusammenfassung
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reinigungen.length} Reinigungen',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reinigungen.length <= 4
                              ? reinigungen
                                  .map((r) => dateFormat.format(r.datum))
                                  .join(', ')
                              : '${reinigungen.take(3).map((r) => dateFormat.format(r.datum)).join(', ')} +${reinigungen.length - 3}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${brutto.toStringAsFixed(2)} CHF',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'inkl. MwSt',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Button
              SizedBox(
                width: double.infinity,
                child: istAktiv
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _generatingAll
                            ? null
                            : () => _generateForBetrieb(b),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Jahresrechnung erstellen'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateAllButton(
    List<BetriebLocal> betriebe,
    ({int anzahlBetriebe, int anzahlReinigungen, double netto, double mwst, double brutto}) totale,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _generatingAll ? null : () => _generateAll(betriebe),
        icon: _generatingAll
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.playlist_add_check),
        label: Text(
          _generatingAll
              ? 'Wird generiert...'
              : 'Alle erstellen (${totale.anzahlBetriebe} Betriebe · ${totale.brutto.toStringAsFixed(2)} CHF)',
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Fehler beim Laden',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final betriebe =
                  ref.read(jahresrechnungBetriebeProvider).valueOrNull ?? [];
              _loadReinigungen(betriebe);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }

  void _showJahrPicker(List<BetriebLocal> betriebe, DateTime now) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Geschäftsjahr wählen',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  for (int y = now.year; y >= now.year - 2; y--)
                    ButtonSegment(value: y, label: Text('$y')),
                ],
                selected: {_selectedJahr},
                onSelectionChanged: (sel) {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedJahr = sel.first;
                    _reinigungen.clear();
                    _generiert.clear(); // Map.clear()
                  });
                  _loadReinigungen(betriebe);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ─── Helper Widgets ───

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
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
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: bold ? null : AppColors.textSecondary,
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
