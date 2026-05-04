import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_zuweisung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';

class HeinekenZuweisungenScreen extends ConsumerStatefulWidget {
  const HeinekenZuweisungenScreen({super.key});

  @override
  ConsumerState<HeinekenZuweisungenScreen> createState() =>
      _HeinekenZuweisungenScreenState();
}

class _HeinekenZuweisungenScreenState
    extends ConsumerState<HeinekenZuweisungenScreen> {
  Map<String, KontaktLocal?>? _zuweisungen;
  bool _saving = false;

  static const _funktionen = [
    ('monatsrechnung', 'Monatsrechnung', Icons.receipt_long),
    ('raster', 'Raster', Icons.grid_on),
    ('heigenie_service', 'Heigenie Service', Icons.build),
    ('materialbestellung', 'Materialbestellung', Icons.inventory),
  ];

  @override
  Widget build(BuildContext context) {
    final zuweisungenAsync = ref.watch(heinekenZuweisungenProvider);
    final heinekenKontakte = ref.watch(kontakteByKategorieProvider('heineken'));

    return Scaffold(
      appBar: AppBar(title: const Text('Heineken Zuweisungen')),
      body: zuweisungenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (zuweisungen) {
          _zuweisungen ??= Map.of(zuweisungen);

          return heinekenKontakte.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (kontakte) {
              if (kontakte.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.contacts, size: 64,
                            color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'Keine Heineken-Kontakte vorhanden',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Erstelle zuerst Kontakte mit Kategorie "Heineken" unter Kontakte.',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Wähle für jede Funktion den zuständigen Heineken-Kontakt.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  ..._funktionen.map((f) {
                    final (funktion, label, icon) = f;
                    final current = _zuweisungen![funktion];
                    return _ZuweisungCard(
                      funktion: funktion,
                      label: label,
                      icon: icon,
                      currentKontakt: current,
                      kontakte: kontakte,
                      saving: _saving,
                      onChanged: (kontakt) => _setZuweisung(funktion, kontakt),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _setZuweisung(String funktion, KontaktLocal? kontakt) async {
    setState(() => _saving = true);
    try {
      await KontaktRepository.setHeinekenZuweisung(
        funktion,
        kontakt?.routeId,
      );
      setState(() {
        _zuweisungen![funktion] = kontakt;
        _saving = false;
      });
      ref.invalidate(heinekenZuweisungenProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kontakt != null
                ? '${kontakt.vorname} ${kontakt.nachname ?? ''} zugewiesen'
                : 'Zuweisung entfernt'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }
}

class _ZuweisungCard extends StatelessWidget {
  final String funktion;
  final String label;
  final IconData icon;
  final KontaktLocal? currentKontakt;
  final List<KontaktLocal> kontakte;
  final bool saving;
  final ValueChanged<KontaktLocal?> onChanged;

  const _ZuweisungCard({
    required this.funktion,
    required this.label,
    required this.icon,
    required this.currentKontakt,
    required this.kontakte,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (currentKontakt?.rolle != null && currentKontakt!.rolle!.isNotEmpty)
        currentKontakt!.rolle!,
      if (currentKontakt?.email != null && currentKontakt!.email!.isNotEmpty)
        currentKontakt!.email!,
      if (currentKontakt?.telefon != null && currentKontakt!.telefon!.isNotEmpty)
        currentKontakt!.telefon!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: currentKontakt?.routeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Kein Kontakt zugewiesen',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic)),
                ),
                ...kontakte.map((k) {
                  final name =
                      '${k.vorname} ${k.nachname ?? ''}'.trim();
                  final rolle = k.rolle ?? '';
                  return DropdownMenuItem<String?>(
                    value: k.routeId,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                        if (rolle.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(rolle,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              onChanged: saving
                  ? null
                  : (id) {
                      if (id == null) {
                        onChanged(null);
                      } else {
                        final kontakt =
                            kontakte.firstWhere((k) => k.routeId == id);
                        onChanged(kontakt);
                      }
                    },
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                details.join('  ·  '),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
