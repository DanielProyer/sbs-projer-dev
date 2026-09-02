import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb;

/// Abschlussprüfung: 14 Regeln je Geschäftsjahr, gruppiert und nach Ampel
/// sortiert. Grüne Befunde sind eingeklappt — offen bleibt, was zu tun ist.
class AuditScreen extends ConsumerStatefulWidget {
  final int? jahr;
  const AuditScreen({super.key, this.jahr});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  /// Unsinniges Jahr aus der URL (altes Lesezeichen, Tippfehler) fällt aufs
  /// laufende Jahr zurück, statt eine leere Prüfung zu zeigen.
  late int _jahr = _gueltig(widget.jahr) ? widget.jahr! : DateTime.now().year;
  bool _grueneZeigen = false;

  static bool _gueltig(int? j) =>
      j != null && j >= kSteuerJahrAb && j <= DateTime.now().year;

  @override
  void didUpdateWidget(AuditScreen alt) {
    super.didUpdateWidget(alt);
    // Zurück-Navigation oder neuer ?jahr=-Link auf derselben Seite: der State
    // überlebt, das Jahr muss deshalb nachgezogen werden.
    if (widget.jahr != alt.jahr && _gueltig(widget.jahr)) {
      setState(() => _jahr = widget.jahr!);
    }
  }

  Color _farbe(PruefStatus s) => switch (s) {
    PruefStatus.rot => AppColors.error,
    PruefStatus.gelb => AppColors.warning,
    PruefStatus.gruen => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(abschlussPruefungProvider(_jahr));
    return Scaffold(
      appBar: AppBar(title: const Text('Abschlussprüfung')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterDropdown<int>(
                    hint: 'Jahr',
                    value: _jahr,
                    nullable: false,
                    isExpanded: true,
                    options: [
                      for (var j = DateTime.now().year; j >= kSteuerJahrAb; j--)
                        (j, '$j'),
                    ],
                    onChanged: (v) => setState(() => _jahr = v ?? _jahr),
                  ).build(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              // Nach jeder Buchung rechnet die Prüfung neu — ohne das fiele
              // die Liste dabei jedes Mal auf den Spinner zurück.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _fehler(e),
              data: (befunde) {
                int n(PruefStatus s) =>
                    befunde.where((b) => b.status == s).length;
                final gruppen = <String, List<Pruefbefund>>{};
                for (final b in befunde) {
                  if (b.status == PruefStatus.gruen && !_grueneZeigen) continue;
                  gruppen.putIfAbsent(b.gruppe, () => []).add(b);
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    InkWell(
                      onTap: () =>
                          setState(() => _grueneZeigen = !_grueneZeigen),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Wrap statt fester Texte: bei 375 px Breite und
                            // zweistelligen Zählern läuft eine Row sonst über.
                            Expanded(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _zaehler(PruefStatus.rot, n, 'rot'),
                                  _zaehler(PruefStatus.gelb, n, 'gelb'),
                                  _zaehler(PruefStatus.gruen, n, 'grün'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _grueneZeigen
                                  ? 'grüne ausblenden'
                                  : 'grüne zeigen',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (gruppen.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('Alles im Lot — keine offenen Befunde.'),
                        ),
                      ),
                    for (final g in gruppen.entries)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const Divider(),
                            for (final b in g.value) _zeile(b),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fehler(Object e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Fehler: $e', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => ref.invalidate(abschlussPruefungProvider(_jahr)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Erneut laden',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _zaehler(PruefStatus s, int Function(PruefStatus) n, String label) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [_punkt(s), const SizedBox(width: 4), Text('${n(s)} $label')],
      );

  Widget _punkt(PruefStatus s) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _farbe(s)),
  );

  Widget _zeile(Pruefbefund b) => InkWell(
    onTap: b.aktionRoute == null ? null : () => context.push(b.aktionRoute!),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _punkt(b.status),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.titel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (b.ist.isNotEmpty || b.soll.isNotEmpty)
                  Text(
                    'Ist: ${b.ist}${b.soll.isEmpty ? '' : ' · Soll: ${b.soll}'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (b.hinweis.isNotEmpty)
                  Text(
                    b.hinweis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
