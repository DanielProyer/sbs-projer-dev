import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/konto.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/data/repositories/kreditor_regel_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/konto_providers.dart';

/// Verwaltungs-Screen für Lieferanten-Lernregeln (Kreditor-Vorbelegung).
///
/// Zeigt alle Regeln (aktiv + inaktiv) und erlaubt Bearbeiten, Neu-Anlegen
/// und Löschen. Jede Regel ordnet einem Lieferanten (Name-Substring, optional
/// Referenz-Präfix) ein Aufwandskonto + MwSt-/Vorsteuer-Logik zu.
class KreditorRegelnScreen extends ConsumerWidget {
  const KreditorRegelnScreen({super.key});

  /// Sucht die Konto-Bezeichnung zur Kontonummer (für Anzeige).
  String _kontoLabel(List<Konto> konten, int? nummer) {
    if (nummer == null) return '–';
    final treffer = konten.where((k) => k.kontonummer == nummer).firstOrNull;
    if (treffer == null) return '$nummer';
    return '$nummer ${treffer.bezeichnung}';
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    KreditorRegel regel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regel löschen?'),
        content: Text('„${regel.lieferantNamePattern}“ wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await KreditorRegelRepository.delete(regel.id);
      ref.invalidate(kreditorRegelnProvider);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $err')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kreditorRegelnProvider);
    final konten = ref.watch(kontenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lieferantenregeln')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showKreditorRegelDialog(context, ref, konten: konten),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Fehler beim Laden: $err',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (regeln) {
          if (regeln.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rule,
                    size: 64,
                    color: AppColors.primary.withAlpha(120),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine Lieferantenregeln',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: regeln.length,
            itemBuilder: (context, index) {
              final r = regeln[index];
              return _RegelCard(
                regel: r,
                aufwandLabel: _kontoLabel(konten, r.aufwandskonto),
                vorsteuerLabel: r.vorsteuerKonto == null
                    ? 'keine Vorsteuer'
                    : _kontoLabel(konten, r.vorsteuerKonto),
                onEdit: () => showKreditorRegelDialog(
                  context,
                  ref,
                  konten: konten,
                  bestehend: r,
                ),
                onDelete: () => _delete(context, ref, r),
                onToggleAktiv: (val) async {
                  try {
                    await KreditorRegelRepository.update(
                      r.id,
                      {'ist_aktiv': val},
                    );
                    ref.invalidate(kreditorRegelnProvider);
                  } catch (err) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: $err')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Eine Regel-Karte in der Liste.
class _RegelCard extends StatelessWidget {
  const _RegelCard({
    required this.regel,
    required this.aufwandLabel,
    required this.vorsteuerLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAktiv,
  });

  final KreditorRegel regel;
  final String aufwandLabel;
  final String vorsteuerLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAktiv;

  @override
  Widget build(BuildContext context) {
    final r = regel;
    final titel = r.lieferantNamePattern.trim().isEmpty
        ? '(ohne Name)'
        : r.lieferantNamePattern.trim();
    final refTeil = (r.referenzPraefix?.trim().isNotEmpty ?? false)
        ? ' · Ref ${r.referenzPraefix!.trim()}'
        : '';
    final mwstTeil = r.mwstPflichtig
        ? 'MwSt ${(r.mwstSatzPercent ?? 0).toStringAsFixed(1)}%'
        : 'hoheitlich (keine MwSt)';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$titel$refTeil',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        _QuelleChip(lernquelle: r.lernquelle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aufwand: $aufwandLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vorsteuer: $vorsteuerLabel · $mwstTeil',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onToggleAktiv(!r.istAktiv),
                child: Switch(
                  value: r.istAktiv,
                  onChanged: onToggleAktiv,
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleines Chip-Label für die Lernquelle (seed/scan).
class _QuelleChip extends StatelessWidget {
  const _QuelleChip({required this.lernquelle});

  final String? lernquelle;

  @override
  Widget build(BuildContext context) {
    final ist = lernquelle ?? 'seed';
    final farbe = ist == 'scan' ? AppColors.info : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        ist,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: farbe,
        ),
      ),
    );
  }
}

/// Dialog zum Anlegen / Bearbeiten einer Lieferantenregel.
///
/// Top-Level-Funktion, damit der Aufruf aus der Liste (FAB) wie auch aus den
/// Karten (Bearbeiten) identisch erfolgt. `bestehend == null` => Neu-Anlegen.
Future<void> showKreditorRegelDialog(
  BuildContext context,
  WidgetRef ref, {
  required List<Konto> konten,
  KreditorRegel? bestehend,
}) async {
  final istNeu = bestehend == null;

  final nameController =
      TextEditingController(text: bestehend?.lieferantNamePattern ?? '');
  final referenzController =
      TextEditingController(text: bestehend?.referenzPraefix ?? '');
  final mwstSatzController = TextEditingController(
    text: bestehend?.mwstSatzPercent != null
        ? bestehend!.mwstSatzPercent!.toString()
        : '',
  );

  // Aufwandskonto-Auswahl (Kontonummer als int). Default = bestehender Wert
  // oder erstes aktives Konto.
  final aktiveKonten = konten.where((k) => k.istAktiv).toList()
    ..sort((a, b) => a.kontonummer.compareTo(b.kontonummer));
  int? selectedAufwand = bestehend?.aufwandskonto;
  if (selectedAufwand == 0) selectedAufwand = null;

  // Vorsteuer-Konto: 1170, 1171 oder keines (null).
  int? selectedVorsteuer = bestehend?.vorsteuerKonto;
  bool mwstPflichtig = bestehend?.mwstPflichtig ?? true;
  bool istAktiv = bestehend?.istAktiv ?? true;
  String? hint;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(istNeu ? 'Neue Lieferantenregel' : 'Regel bearbeiten'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name-Pattern (Substring)',
                      helperText: 'Teil des Lieferantennamens, klein/groß egal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenzController,
                    decoration: const InputDecoration(
                      labelText: 'Referenz-Präfix (optional)',
                      helperText: 'z.B. 98 oder 00473 für Multi-Konto',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedAufwand,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Aufwandskonto',
                    ),
                    items: aktiveKonten
                        .map((k) => DropdownMenuItem<int>(
                              value: k.kontonummer,
                              child: Text(
                                '${k.kontonummer} ${k.bezeichnung}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => selectedAufwand = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedVorsteuer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vorsteuer-Konto',
                    ),
                    items: const [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('keines'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 1170,
                        child: Text('1170 Vorsteuer Material/DL'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 1171,
                        child: Text('1171 Vorsteuer Investitionen'),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedVorsteuer = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mwstSatzController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'MwSt-Satz %',
                      helperText: 'z.B. 8.1 — 0 bei hoheitlich',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('MwSt-pflichtig'),
                    value: mwstPflichtig,
                    onChanged: (val) =>
                        setState(() => mwstPflichtig = val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktiv'),
                    value: istAktiv,
                    onChanged: (val) => setState(() => istAktiv = val),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      hint!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final referenz = referenzController.text.trim();
                  final satzText =
                      mwstSatzController.text.trim().replaceAll(',', '.');

                  if (name.isEmpty) {
                    setState(() => hint = 'Name-Pattern ist nötig.');
                    return;
                  }
                  if (selectedAufwand == null) {
                    setState(() => hint = 'Aufwandskonto wählen.');
                    return;
                  }
                  final double? satz =
                      satzText.isEmpty ? null : double.tryParse(satzText);
                  if (satzText.isNotEmpty && satz == null) {
                    setState(() => hint = 'MwSt-Satz ungültig.');
                    return;
                  }

                  final fields = <String, dynamic>{
                    'lieferant_name_pattern': name,
                    'referenz_praefix': referenz.isEmpty ? null : referenz,
                    'aufwandskonto': selectedAufwand,
                    'vorsteuer_konto': selectedVorsteuer,
                    'mwst_satz_percent': satz,
                    'mwst_pflichtig': mwstPflichtig,
                    'ist_aktiv': istAktiv,
                  };

                  try {
                    if (istNeu) {
                      fields['lernquelle'] = 'scan';
                      await KreditorRegelRepository.create(fields);
                    } else {
                      await KreditorRegelRepository.update(
                        bestehend.id,
                        fields,
                      );
                    }
                    ref.invalidate(kreditorRegelnProvider);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Regel gespeichert')),
                      );
                    }
                  } catch (err) {
                    setState(() => hint = 'Fehler: $err');
                  }
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      );
    },
  );
}
