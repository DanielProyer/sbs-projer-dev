import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_providers.dart';

class HeinekenRechnungenListScreen extends ConsumerWidget {
  const HeinekenRechnungenListScreen({super.key});

  static final _monatFormat = DateFormat('MMMM yyyy', 'de_CH');
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rechnungen = ref.watch(heinekenRechnungenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heineken Rechnungen'),
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
      body: rechnungen.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) {
          if (list.isEmpty) {
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              final monat = r.heinekenMonat;
              final monatsName = monat != null
                  ? _monatFormat.format(monat)
                  : 'Unbekannt';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(r.zahlungsstatus).withAlpha(30),
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
                        color: _statusColor(r.zahlungsstatus),
                      ),
                    ),
                    backgroundColor: _statusColor(r.zahlungsstatus).withAlpha(20),
                    side: BorderSide.none,
                  ),
                  onTap: () => context.push('/heineken/${r.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/heineken/neu'),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'gestellt': return 'Gestellt';
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
      case 'gestellt': return AppColors.textSecondary;
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
      case 'gestellt': return Icons.edit_note;
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
    return value.toStringAsFixed(2);
  }
}
