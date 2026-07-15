import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_regel_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_regel_providers.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';
import 'package:sbs_projer_app/services/camt/pruefliste_buchung.dart';
import 'package:sbs_projer_app/services/camt/regel_matcher.dart';

/// Dialog zum Anlegen einer neuen camt-Regel.
///
/// Als Top-Level-Funktion, damit auch die Prüfliste den Dialog mit
/// vorausgefülltem Match-Namen und vorausgefüllter IBAN öffnen kann.
///
/// Wird [buchenFuer] gesetzt (Aufruf aus der Prüfliste), bucht der Dialog nach
/// dem Speichern der Regel diese eine Transaktion direkt mit der gewählten
/// Vorlage und hakt den Prüflisten-Eintrag ab. Das ist kein Komfort, sondern
/// nötig: Eine Transaktion in der Prüfliste wird bei jedem weiteren Import über
/// ihren txKey übersprungen — die neue Regel würde sie also nie erfassen, und
/// die Zahlung bliebe für immer ungebucht.
Future<void> showRegelDialog(
  BuildContext context,
  WidgetRef ref, {
  String? vorausgefuelltMatchName,
  String? vorausgefuellteIban,
  CamtPrueflisteEintrag? buchenFuer,
}) async {
  final vorlagen = ref.read(buchungsVorlagenProvider);
  final bezeichnungController = TextEditingController(
    text: vorausgefuelltMatchName ?? '',
  );
  final matchNameController = TextEditingController(
    text: vorausgefuelltMatchName ?? '',
  );
  final ibanController = TextEditingController(
    text: vorausgefuellteIban ?? '',
  );
  String? selectedVorlageId =
      vorlagen.isNotEmpty ? vorlagen.first.id : null;
  String? hint;
  bool speichertGerade = false;

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
                  if (buchenFuer != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Diese Zahlung wird beim Speichern gleich mit der '
                        'gewählten Vorlage gebucht: '
                        '${buchenFuer.parteiName ?? 'Unbekannt'} · '
                        '${buchenFuer.betrag.toStringAsFixed(2)} CHF',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                onPressed: speichertGerade
                    ? null
                    : () async {
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
                  setState(() {
                    speichertGerade = true;
                    hint = null;
                  });

                  try {
                    await CamtRegelRepository.insert(
                      CamtRegel(
                        bezeichnung: bezeichnung,
                        matchName: matchName.isEmpty ? null : matchName,
                        // Normalisiert speichern, damit die Regel auch dann
                        // greift, wenn die IBAN gruppiert eingetippt wurde.
                        matchIban: RegelMatcher.normIban(iban),
                        buchungsVorlageId: selectedVorlageId!,
                        prioritaet: 10,
                      ),
                    );
                    ref.invalidate(camtRegelnProvider);

                    var meldung = 'Regel gespeichert';
                    if (buchenFuer != null) {
                      meldung = await _bucheAusPruefliste(
                        ref: ref,
                        eintrag: buchenFuer,
                        vorlage: vorlagen
                            .firstWhere((v) => v.id == selectedVorlageId),
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(meldung)),
                      );
                    }
                  } catch (err) {
                    setState(() {
                      speichertGerade = false;
                      hint = 'Fehler: $err';
                    });
                  }
                },
                child: Text(
                  buchenFuer != null ? 'Speichern & buchen' : 'Speichern',
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Bucht die Transaktion eines Prüflisten-Eintrags mit [vorlage] und hakt den
/// Eintrag ab. Liefert die Meldung für die SnackBar.
///
/// Wirft bei einem Fehler weiter — der Eintrag bleibt dann bewusst offen,
/// damit die Zahlung nicht still aus der Buchhaltung verschwindet.
Future<String> _bucheAusPruefliste({
  required WidgetRef ref,
  required CamtPrueflisteEintrag eintrag,
  required BuchungsVorlage vorlage,
}) async {
  // Schutz vor einer zweiten Buchung derselben Zahlung.
  if (await BuchungRepository.existiertCamtTxKey(eintrag.txKey)) {
    await CamtPrueflisteRepository.setStatus(eintrag.id!, 'erledigt');
    ref.invalidate(camtPrueflisteProvider);
    return 'Regel gespeichert — Zahlung war bereits gebucht, Eintrag abgehakt';
  }

  await CamtAusgabeBooker.book(txAusPrueflisteEintrag(eintrag), vorlage);
  await CamtPrueflisteRepository.setStatus(eintrag.id!, 'erledigt');
  ref.invalidate(camtPrueflisteProvider);
  return 'Regel gespeichert und ${eintrag.betrag.toStringAsFixed(2)} CHF '
      'auf ${vorlage.sollKonto} gebucht';
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
