import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/data/repositories/camt_regel_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_regel_providers.dart';

/// Dialog zum Anlegen einer neuen camt-Regel.
///
/// Als Top-Level-Funktion, damit auch die Prüfliste den Dialog mit
/// vorausgefülltem Match-Namen öffnen kann.
Future<void> showRegelDialog(
  BuildContext context,
  WidgetRef ref, {
  String? vorausgefuelltMatchName,
}) async {
  final vorlagen = ref.read(buchungsVorlagenProvider);
  final bezeichnungController = TextEditingController(
    text: vorausgefuelltMatchName ?? '',
  );
  final matchNameController = TextEditingController(
    text: vorausgefuelltMatchName ?? '',
  );
  final ibanController = TextEditingController();
  String? selectedVorlageId =
      vorlagen.isNotEmpty ? vorlagen.first.id : null;
  String? hint;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Neue Regel'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: bezeichnungController,
                    decoration: const InputDecoration(
                      labelText: 'Bezeichnung',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: matchNameController,
                    decoration: const InputDecoration(
                      labelText: 'Match Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ibanController,
                    decoration: const InputDecoration(
                      labelText: 'Match IBAN (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVorlageId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Buchungsvorlage',
                    ),
                    items: vorlagen
                        .map((v) => DropdownMenuItem<String>(
                              value: v.id,
                              child: Text(
                                v.bezeichnung,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => selectedVorlageId = val),
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
                  final bezeichnung = bezeichnungController.text.trim();
                  final matchName = matchNameController.text.trim();
                  final iban = ibanController.text.trim();

                  if (bezeichnung.isEmpty ||
                      selectedVorlageId == null ||
                      (matchName.isEmpty && iban.isEmpty)) {
                    setState(() {
                      hint =
                          'Bezeichnung, eine Vorlage und mindestens Name oder IBAN sind nötig.';
                    });
                    return;
                  }

                  try {
                    await CamtRegelRepository.insert(
                      CamtRegel(
                        bezeichnung: bezeichnung,
                        matchName: matchName.isEmpty ? null : matchName,
                        matchIban: iban.isEmpty ? null : iban,
                        buchungsVorlageId: selectedVorlageId!,
                        prioritaet: 10,
                      ),
                    );
                    ref.invalidate(camtRegelnProvider);
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

class CamtRegelnTab extends ConsumerWidget {
  const CamtRegelnTab({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CamtRegel regel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regel löschen?'),
        content: Text('„${regel.bezeichnung}“ wirklich löschen?'),
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
      await CamtRegelRepository.delete(regel.id!);
      ref.invalidate(camtRegelnProvider);
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
    final async = ref.watch(camtRegelnProvider);
    final vorlagen = ref.watch(buchungsVorlagenProvider);

    return async.when(
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
                  'Noch keine Regeln',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: regeln.length,
          itemBuilder: (context, index) {
            final r = regeln[index];
            final vorlageName = vorlagen
                    .where((v) => v.id == r.buchungsVorlageId)
                    .map((v) => v.bezeichnung)
                    .firstOrNull ??
                r.buchungsVorlageId;

            final matchParts = <String>[
              if (r.matchName != null && r.matchName!.isNotEmpty)
                'Name: ${r.matchName}',
              if (r.matchIban != null && r.matchIban!.isNotEmpty)
                'IBAN: ${r.matchIban}',
            ];

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.bezeichnung,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (matchParts.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              matchParts.join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            'Vorlage: $vorlageName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: r.istAktiv,
                      onChanged: (val) async {
                        try {
                          await CamtRegelRepository.setAktiv(r.id!, val);
                          ref.invalidate(camtRegelnProvider);
                        } catch (err) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $err')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.error,
                      onPressed: () => _delete(context, ref, r),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
