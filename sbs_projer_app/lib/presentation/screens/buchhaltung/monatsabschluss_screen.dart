import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/monats_pruef_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

/// Der Monatsabschluss als Liste — reine Darstellung, testbar ohne Provider.
///
/// WARUM: Der Monat ist der Takt des Geschäfts, und «Kette bricht ab» (zwei
/// fehlende Ertragsbuchungen am 03./04.09.2026) fällt monatlich auf, bevor
/// es teuer wird. Gleiche Bauart wie die Jahresprüfung, nur zehn Regeln
/// statt siebzehn (B4).
class MonatsabschlussInhalt extends StatelessWidget {
  final List<Pruefbefund> befunde;
  final int jahr, monat;
  final List<int> jahre;
  final ValueChanged<int> onJahr;
  final ValueChanged<int> onMonat;
  final ValueChanged<Pruefbefund> onZeile;

  const MonatsabschlussInhalt({
    super.key,
    required this.befunde,
    required this.jahr,
    required this.monat,
    required this.jahre,
    required this.onJahr,
    required this.onMonat,
    required this.onZeile,
  });

  static Color farbe(PruefStatus s) => switch (s) {
    PruefStatus.rot => AppColors.error,
    PruefStatus.gelb => AppColors.warning,
    PruefStatus.gruen => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final offen = befunde.where((b) => b.status != PruefStatus.gruen).length;
    final gruppen = <String, List<Pruefbefund>>{};
    for (final b in befunde) {
      gruppen.putIfAbsent(b.gruppe, () => []).add(b);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Monatsabschluss')),
      body: Column(
        children: [
          AppJahrMonatLeiste(
            jahre: jahre,
            selectedJahr: jahr,
            onJahrChanged: onJahr,
            selectedMonat: monat,
            onMonatChanged: onMonat,
            trailing: Text(
              offen == 0
                  ? 'Alles erledigt 🎉'
                  : '$offen von ${befunde.length} offen',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: offen == 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final g in gruppen.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                    child: Text(
                      g.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final b in g.value) _zeile(b),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// CanvasKit: `InkWell` + `Container` + `Row`, kein `ListTile`.
  Widget _zeile(Pruefbefund b) => InkWell(
    onTap: b.aktionRoute == null ? null : () => onZeile(b),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: farbe(b.status),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.titel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (b.ist.isNotEmpty || b.soll.isNotEmpty)
                  Text(
                    'Ist: ${b.ist}${b.soll.isEmpty ? '' : ' · Soll: ${b.soll}'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (b.hinweis.isNotEmpty)
                  Text(
                    b.hinweis,
                    style: TextStyle(fontSize: 11, color: farbe(b.status)),
                  ),
              ],
            ),
          ),
          if (b.aktionRoute != null)
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    ),
  );
}

/// Angebunden: hält die Monatswahl und lädt die Befunde.
class MonatsabschlussScreen extends ConsumerStatefulWidget {
  const MonatsabschlussScreen({super.key});

  @override
  ConsumerState<MonatsabschlussScreen> createState() =>
      _MonatsabschlussScreenState();
}

class _MonatsabschlussScreenState extends ConsumerState<MonatsabschlussScreen> {
  late MonatsSchluessel _m;

  @override
  void initState() {
    super.initState();
    // Der Vormonat ist die sinnvolle Vorgabe: Den laufenden kann man noch
    // nicht abschliessen.
    _m = vormonat(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final befunde = ref.watch(monatsPruefungProvider(_m));
    final jetzt = DateTime.now();
    final jahre = [for (var j = jetzt.year; j >= jetzt.year - 3; j--) j];

    return befunde.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Monatsabschluss')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Monatsabschluss')),
        body: Center(child: Text('Prüfung nicht möglich: $e')),
      ),
      data: (liste) => MonatsabschlussInhalt(
        befunde: liste,
        jahr: _m.jahr,
        monat: _m.monat,
        jahre: jahre,
        onJahr: (j) => setState(() => _m = (jahr: j, monat: _m.monat)),
        onMonat: (mo) => setState(
          () => _m = (jahr: _m.jahr, monat: mo == 0 ? _m.monat : mo),
        ),
        onZeile: (b) => context.push(b.aktionRoute!),
      ),
    );
  }
}
