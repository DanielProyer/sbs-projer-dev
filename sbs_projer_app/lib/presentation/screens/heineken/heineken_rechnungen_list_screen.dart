import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_reiter.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_leiste.dart';

class HeinekenRechnungenListScreen extends ConsumerStatefulWidget {
  const HeinekenRechnungenListScreen({super.key});

  @override
  ConsumerState<HeinekenRechnungenListScreen> createState() =>
      _HeinekenRechnungenListScreenState();
}

class _HeinekenRechnungenListScreenState
    extends ConsumerState<HeinekenRechnungenListScreen> {
  static final _monatFormat = DateFormat('MMMM yyyy', 'de_CH');
  static final _dateFormat = DateFormat('dd.MM.yyyy');
  static final _nf = NumberFormat('#,##0.00', 'de_CH');

  int _selectedYear = DateTime.now().year;

  /// Sortier-Datum: primär der Monat, sonst das Rechnungsdatum.
  DateTime _sortDatum(Rechnung r) => r.heinekenMonat ?? r.rechnungsdatum;

  @override
  Widget build(BuildContext context) {
    final rechnungen = ref.watch(heinekenRechnungenProvider);

    return Scaffold(
      appBar: AppBar(
        // Wie in der Betriebe-/Kontakte-Liste: Nach einem Reiterwechsel (go)
        // gibt es nichts zum Zurückgehen — ohne eigenen Pfeil fehlte er
        // (Präzedenz Commit a0bd72d3).
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/mehr'),
        ),
        title: const Text('Heineken Rechnungen'),
        bottom: const BereichReiter(
          reiter: kReiterRechnungen,
          aktiverPfad: '/heineken',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Monatsraster',
            onPressed: () => context.push('/heineken/raster'),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Zuweisungen',
            onPressed: () => context.push('/heineken/zuweisungen'),
          ),
        ],
      ),
      // Bergkundenpauschalen stehen als festes erstes Kind ÜBER dem
      // `when(...)` — sonst war /bergkundenpauschalen beim Laden, bei einem
      // Fehler oder ganz ohne Heineken-Rechnungen (leere Liste) über die
      // Oberfläche gar nicht erreichbar (Review 22.09.2026).
      body: Column(
        children: [
          const _BergkundenKarte(),
          Expanded(
            child: rechnungen.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmpty();
                }

                // Verfügbare Jahre (absteigend), Auswahl absichern.
                final jahre =
                    (list.map((r) => _sortDatum(r).year).toSet().toList()
                      ..sort((a, b) => b.compareTo(a)));
                if (jahre.isEmpty) jahre.add(DateTime.now().year);
                if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

                // Absteigend sortieren (neuste zuoberst).
                final sorted = List<Rechnung>.from(list)
                  ..sort((a, b) => _sortDatum(b).compareTo(_sortDatum(a)));

                final filtered = sorted
                    .where((r) => _sortDatum(r).year == _selectedYear)
                    .toList();

                final jahrSumme =
                    filtered.fold(0.0, (sum, r) => sum + r.betragBrutto);

                return Column(
                  children: [
                    AppJahrLeiste(
                      jahre: jahre,
                      selectedJahr: _selectedYear,
                      onJahrChanged: (y) => setState(() => _selectedYear = y),
                      trailing: Text(
                        jahrSumme > 0
                            ? '${filtered.length} – ${_chf(jahrSumme)} CHF'
                            : '${filtered.length} Rechnungen',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Keine Rechnungen für $_selectedYear',
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final r = filtered[index];
                                final monat = r.heinekenMonat;
                                final monatsName = monat != null
                                    ? _monatFormat.format(monat)
                                    : 'Unbekannt';

                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          _statusColor(r.zahlungsstatus)
                                              .withAlpha(30),
                                      child: Icon(
                                        _statusIcon(r.zahlungsstatus),
                                        color: _statusColor(r.zahlungsstatus),
                                      ),
                                    ),
                                    title: Text(monatsName),
                                    subtitle: Text(
                                      '${_dateFormat.format(r.rechnungsdatum)} · ${_chf(r.betragBrutto)} CHF',
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        _statusLabel(r.zahlungsstatus),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              _statusColor(r.zahlungsstatus),
                                        ),
                                      ),
                                      backgroundColor:
                                          _statusColor(r.zahlungsstatus)
                                              .withAlpha(20),
                                      side: BorderSide.none,
                                    ),
                                    onTap: () =>
                                        context.push('/heineken/${r.id}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/heineken/neu'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Noch keine Heineken-Rechnungen',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Erstelle eine neue Monatsrechnung über den + Button.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'offen': return 'Offen';
      case 'bezahlt': return 'Bezahlt';
      case 'erinnert': return 'Erinnert';
      case 'mahnung_1': return 'Mahnung 1';
      case 'mahnung_2': return 'Mahnung 2';
      case 'abgeschrieben': return 'Abgeschrieben';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'offen': return AppColors.warning;
      case 'bezahlt': return AppColors.success;
      case 'erinnert': return const Color(0xFFE65100);
      case 'mahnung_1': return AppColors.error;
      case 'mahnung_2': return const Color(0xFF8B0000);
      case 'abgeschrieben': return AppColors.inaktiv;
      default: return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'offen': return Icons.hourglass_empty;
      case 'bezahlt': return Icons.check_circle;
      case 'erinnert': return Icons.notifications;
      case 'mahnung_1': return Icons.warning;
      case 'mahnung_2': return Icons.gavel;
      case 'abgeschrieben': return Icons.block;
      default: return Icons.receipt;
    }
  }

  String _chf(double value) {
    return _nf.format(value);
  }
}

/// Bergkundenpauschalen werden mit der Heineken-Monatsrechnung verrechnet —
/// hier werden sie gesucht (v0.132.0). Eigenes Widget, damit die Karte in
/// jedem Zweig von `rechnungen.when(...)` (Laden, Fehler, leer, Liste) exakt
/// einmal steht, statt in jedem Zweig einzeln kopiert zu werden.
class _BergkundenKarte extends StatelessWidget {
  const _BergkundenKarte();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: InkWell(
        onTap: () => context.push('/bergkundenpauschalen'),
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.landscape, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bergkundenpauschalen',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
