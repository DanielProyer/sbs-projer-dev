import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';

/// Aufgaben-Screen (B6): die eine Aufgabenliste, vollständig — auch das,
/// was erst nächste Woche ansteht. Der Aufbau der Liste liegt in
/// `aufgabenListeProvider`; hier nur Darstellung und Aktionen.
class AufgabenInhalt extends StatelessWidget {
  final List<AufgabenEintrag> eintraege;
  final DateTime heute;
  final ValueChanged<AufgabenEintrag> onDorthin;
  final void Function(AufgabenEintrag, int tage) onSnooze;
  final ValueChanged<AufgabenEintrag> onErledigt;
  final ValueChanged<AufgabenEintrag> onEinplanen;
  final ValueChanged<AufgabenEintrag> onBestaetigen;
  final VoidCallback onNeu;

  const AufgabenInhalt({
    super.key,
    required this.eintraege,
    required this.heute,
    required this.onDorthin,
    required this.onSnooze,
    required this.onErledigt,
    required this.onEinplanen,
    required this.onBestaetigen,
    required this.onNeu,
  });

  String _gruppe(DateTime? d, DateTime heuteTag) {
    if (d == null) return 'Ohne Datum';
    final tag = DateTime(d.year, d.month, d.day);
    if (tag.isBefore(heuteTag)) return 'Überfällig';
    if (tag == heuteTag) return 'Heute';
    if (tag == heuteTag.add(const Duration(days: 1))) return 'Morgen';
    return DateFormat('EE, dd.MM.yyyy', 'de_CH').format(tag);
  }

  @override
  Widget build(BuildContext context) {
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final kinder = <Widget>[];
    String? letzte;
    for (final a in eintraege) {
      final g = _gruppe(a.faellig, heuteTag);
      if (g != letzte) {
        letzte = g;
        kinder.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              g,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: g == 'Überfällig'
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }
      kinder.add(
        AufgabeZeile(
          eintrag: a,
          heute: heute,
          onDorthin: () => onDorthin(a),
          onSnooze: (t) => onSnooze(a, t),
          onErledigt: () => onErledigt(a),
          onEinplanen: () => onEinplanen(a),
          onBestaetigen: () => onBestaetigen(a),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: eintraege.isEmpty
          ? const Center(
              child: Text(
                'Keine anstehenden Aufgaben.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: kinder,
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('aufgabe_neu'),
        onPressed: onNeu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AufgabenScreen extends ConsumerWidget {
  const AufgabenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(aufgabenListeProvider);
    final aktionen = AufgabenAktionen(ref);
    return liste.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Aufgaben')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Aufgaben')),
        body: Center(child: Text('Aufgaben konnten nicht geladen werden: $e')),
      ),
      data: (eintraege) => AufgabenInhalt(
        eintraege: eintraege,
        heute: DateTime.now(),
        onDorthin: (a) => aktionen.dorthin(context, a),
        onSnooze: (a, t) => aktionen.snooze(context, a, t),
        onErledigt: (a) => aktionen.erledigt(context, a),
        onEinplanen: (a) => aktionen.einplanen(context, a),
        onBestaetigen: (a) => aktionen.bestaetigen(context, a),
        onNeu: () => neueAufgabeDialog(context, ref),
      ),
    );
  }
}

// --- bis Task 7 (B6): wird noch von home_screen.dart gebraucht ---
/// Offene EIGENE Aufgaben — ALLE, auch mit Fälligkeitsdatum in der Zukunft.
/// Bewusst nicht `aufgabenProvider`: der filtert für die Erinnerungs-Glocke
/// auf «jetzt sichtbar» — ein Planungs-Screen braucht auch das, was erst
/// nächste Woche ansteht (Daniel 31.07.2026).
final offeneEigeneAufgabenProvider =
    FutureProvider<List<({String id, String titel, DateTime? faellig})>>((
      ref,
    ) async {
      final zeilen = await AufgabenRepository.alleZeilen();
      final offene = [
        for (final z in zeilen)
          if (z['typ'] == 'eigene' && z['erledigt_am'] == null)
            (
              id: z['id'] as String,
              titel: (z['titel'] ?? '?') as String,
              faellig: DateTime.tryParse(z['faellig_am'] as String? ?? ''),
            ),
      ];
      offene.sort((a, b) {
        if (a.faellig == null && b.faellig == null) return 0;
        if (a.faellig == null) return 1;
        if (b.faellig == null) return -1;
        return a.faellig!.compareTo(b.faellig!);
      });
      return offene;
    });
