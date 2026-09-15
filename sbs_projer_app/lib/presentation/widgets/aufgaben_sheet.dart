import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';

bool _sheetOffen = false;

/// Öffnet das Aufgaben-Sheet (von Dashboard-Karte und Glocke genutzt).
/// Re-Entry-Guard: die Glocke liegt als Stack-Sibling über dem
/// Navigator-Overlay und bleibt bei offenem Sheet tippbar — ohne Guard
/// würde ein erneuter Tap ein zweites Sheet stapeln.
void zeigeAufgabenSheet(BuildContext context) {
  if (_sheetOffen) return;
  _sheetOffen = true;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AufgabenSheet(),
  ).whenComplete(() => _sheetOffen = false);
}

/// Das Sheet zeigt den Ausschnitt «jetzt fällig» der einen Liste (B6) —
/// dieselben Zeilen und Aktionen wie der Screen.
class _AufgabenSheet extends ConsumerWidget {
  const _AufgabenSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(aufgabenListeProvider);
    final heute = DateTime.now();
    final aktionen = AufgabenAktionen(ref);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: liste.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Fehler: $e'),
          ),
          data: (alle) {
            final jetzt = alle.where((a) => jetztFaellig(a, heute)).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        'Aufgaben',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Aufgabe'),
                      onPressed: () => neueAufgabeDialog(context, ref),
                    ),
                    TextButton(
                      key: const Key('aufgaben_alle'),
                      onPressed: () {
                        Navigator.pop(context);
                        router.push('/aufgaben');
                      },
                      child: Text(
                        alle.length > jetzt.length
                            ? 'Alle (${alle.length})'
                            : 'Alle',
                      ),
                    ),
                  ],
                ),
                if (jetzt.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Alles erledigt 🎉'),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in jetzt)
                        AufgabeZeile(
                          eintrag: a,
                          heute: heute,
                          onDorthin: () =>
                              aktionen.dorthin(context, a, imSheet: true),
                          onSnooze: (t) => aktionen.snooze(context, a, t),
                          onErledigt: () => aktionen.erledigt(context, a),
                          onEinplanen: () => aktionen.einplanen(context, a),
                          onBestaetigen: () => aktionen.bestaetigen(context, a),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
