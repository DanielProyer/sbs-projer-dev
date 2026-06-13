import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';

class DebitorenHeader extends ConsumerStatefulWidget {
  const DebitorenHeader({super.key});

  @override
  ConsumerState<DebitorenHeader> createState() => _DebitorenHeaderState();
}

class _DebitorenHeaderState extends ConsumerState<DebitorenHeader> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(debitorenUebersichtProvider);
    return Card(
      child: ExpansionTile(
        title: const Text('Debitoren / Abschreibungen'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Fehler: $e'),
            data: (d) => Column(
              children: [
                _zeileCard('Debitoren gesamt (1100)', d['debitoren_total']!),
                _zeileCard('davon native offene Rechnungen', d['native_offen']!),
                _zeileCard(
                    'davon historischer Aggregat', d['historisch_aggregat']!),
                _zeileCard('Delkredere (1109)', d['delkredere']!),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Historische Sammel-Abschreibung'),
                  onPressed: () => _sammelDialog(d['historisch_aggregat']!),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.percent),
                  label: const Text('Delkredere auf 5 % setzen'),
                  onPressed: () => _delkredere(d['debitoren_total']!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zeileCard(String label, double v) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text('${v.toStringAsFixed(2)} CHF',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  Future<void> _delkredere(double debitorenTotal) async {
    try {
      await AbschreibungService.delkredereSetzen(
        zielWertberichtigung:
            (debitorenTotal * 0.05 * 100).roundToDouble() / 100,
        datum: DateTime.now(),
      );
      ref.invalidate(debitorenUebersichtProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Delkredere gesetzt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _sammelDialog(double historischAggregat) async {
    final betragC = TextEditingController();
    final bezC =
        TextEditingController(text: 'Sammel-Abschreibung alte Debitoren');
    DateTime datum = DateTime(2024, 12, 31);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Historische Sammel-Abschreibung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: betragC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Betrag brutto (CHF)'),
              ),
              TextField(
                  controller: bezC,
                  decoration:
                      const InputDecoration(labelText: 'Bezeichnung')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Text(
                        'Datum: ${datum.toIso8601String().split('T').first}')),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: ctx,
                        initialDate: datum,
                        firstDate: DateTime(2019),
                        lastDate: DateTime.now());
                    if (p != null) setS(() => datum = p);
                  },
                  child: const Text('wählen'),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Abschreiben')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final brutto = double.tryParse(betragC.text.replaceAll(',', '.'));
    if (brutto == null || brutto <= 0) return;
    try {
      await AbschreibungService.abschreiben(
          brutto: brutto,
          datum: datum,
          beschreibung: bezC.text,
          belegnummer: 'ABSCHR-HIST');
      ref.invalidate(debitorenUebersichtProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${brutto.toStringAsFixed(2)} CHF abgeschrieben')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
