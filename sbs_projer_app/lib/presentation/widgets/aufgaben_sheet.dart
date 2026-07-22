import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';

/// Öffnet das Aufgaben-Sheet (von Dashboard-Karte und Glocke genutzt).
void zeigeAufgabenSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AufgabenSheet(),
  );
}

class _AufgabenSheet extends ConsumerWidget {
  const _AufgabenSheet();

  Future<void> _aktion(WidgetRef ref, Future<void> Function() f,
      BuildContext context) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      ref.invalidate(aufgabenProvider);
    }
  }

  Widget _zeile(BuildContext context, WidgetRef ref, Aufgabe a,
      {String? eigeneId}) {
    final farbe = a.dringend ? AppColors.error : AppColors.warning;
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: farbe),
      title: Text(a.titel, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.route != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Dorthin',
              onPressed: () {
                Navigator.pop(context);
                router.push(a.route!);
              },
            ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.snooze, size: 18),
            tooltip: 'Später erinnern',
            onSelected: (tage) => _aktion(
                ref, () => AufgabenRepository.snooze(a.key, tage), context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('1 Tag')),
              PopupMenuItem(value: 3, child: Text('3 Tage')),
              PopupMenuItem(value: 7, child: Text('7 Tage')),
            ],
          ),
          if (a.manuellErledigbar)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              tooltip: 'Erledigt',
              onPressed: () => _aktion(ref, () async {
                if (eigeneId != null) {
                  await AufgabenRepository.eigeneErledigen(eigeneId);
                } else {
                  await AufgabenRepository.markerSetzen(a.key);
                }
              }, context),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(aufgabenProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: stand.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(24), child: Text('Fehler: $e')),
          data: (s) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('Aufgaben',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Neue Aufgabe'),
                    onPressed: () => _neueAufgabeDialog(context, ref),
                  ),
                ],
              ),
              if (s.badge == 0)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Alles erledigt 🎉'),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...s.offene.map((a) => _zeile(context, ref, a)),
                    ...s.eigene.map(
                        (e) => _zeile(context, ref, e.aufgabe, eigeneId: e.id)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _neueAufgabeDialog(BuildContext context, WidgetRef ref) async {
    final titelCtrl = TextEditingController();
    DateTime? faellig;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Neue Aufgabe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titelCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titel *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(faellig == null
                        ? 'Ohne Fälligkeitsdatum'
                        : 'Fällig: ${faellig!.day.toString().padLeft(2, '0')}.${faellig!.month.toString().padLeft(2, '0')}.${faellig!.year}'),
                  ),
                  TextButton(
                    child: const Text('Datum'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: DateTime.now(),
                      );
                      if (d != null) setDialogState(() => faellig = d);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Speichern')),
          ],
        ),
      ),
    );
    if (ok == true && titelCtrl.text.trim().isNotEmpty && context.mounted) {
      await _aktion(
          ref,
          () =>
              AufgabenRepository.eigeneAnlegen(titelCtrl.text.trim(), faellig),
          context);
    }
  }
}
