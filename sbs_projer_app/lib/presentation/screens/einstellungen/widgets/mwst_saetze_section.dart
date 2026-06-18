// lib/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/mwst_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

/// Eigenständige MwSt-Sätze-Sektion (datumsabhängig, entkoppelt von Preisen).
class MwstSaetzeSection extends ConsumerWidget {
  const MwstSaetzeSection({super.key});

  static final _df = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mwstSaetzeProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.percent, color: AppColors.primary),
        title: const Text('MwSt-Sätze', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Normal & reduziert, datumsabhängig'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Fehler: $e'),
            data: (saetze) {
              if (saetze.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8), child: Text('Keine Sätze erfasst.'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < saetze.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'ab ${_df.format(saetze[i].gueltigAb)} — Normal ${saetze[i].satz.toStringAsFixed(1)} % · '
                        'Reduziert ${saetze[i].satzReduziert.toStringAsFixed(1)} %'
                        '${i == 0 ? '  (aktuell)' : ''}',
                        style: TextStyle(fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neuen Satz hinzufügen'),
                      onPressed: () => _addDialog(context, ref),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final datumCtrl = TextEditingController();
    final normalCtrl = TextEditingController();
    final reduziertCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuer MwSt-Satz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: datumCtrl,
              decoration: const InputDecoration(
                  labelText: 'Gültig ab (TT.MM.JJJJ)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: normalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Normal (%)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reduziertCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Reduziert (%)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok != true) return;
    final datum = _parseDatum(datumCtrl.text);
    final normal = double.tryParse(normalCtrl.text.replaceAll(',', '.'));
    final reduziert = double.tryParse(reduziertCtrl.text.replaceAll(',', '.'));
    if (datum == null || normal == null || reduziert == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ungültige Eingabe (Datum TT.MM.JJJJ, Sätze als Zahl).')));
      }
      return;
    }
    try {
      await MwstSatzService.hinzufuegen(gueltigAb: datum, satz: normal, satzReduziert: reduziert);
      ref.invalidate(mwstSaetzeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('MwSt-Satz hinzugefügt')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  static DateTime? _parseDatum(String text) {
    final p = text.trim().split('.');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }
}
