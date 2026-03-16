import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';

class StoerungDetailScreen extends ConsumerWidget {
  final String stoerungId;

  const StoerungDetailScreen({super.key, required this.stoerungId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<StoerungLocal?>(
      future: StoerungRepository.getById(stoerungId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final stoerung = snapshot.data;
        if (stoerung == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Störung nicht gefunden')),
          );
        }

        return _StoerungDetailContent(stoerung: stoerung);
      },
    );
  }
}

class _StoerungDetailContent extends ConsumerStatefulWidget {
  final StoerungLocal stoerung;

  const _StoerungDetailContent({required this.stoerung});

  @override
  ConsumerState<_StoerungDetailContent> createState() =>
      _StoerungDetailContentState();
}

class _StoerungDetailContentState
    extends ConsumerState<_StoerungDetailContent> {
  final Map<String, String> _materialNames = {};

  StoerungLocal get stoerung => widget.stoerung;

  @override
  void initState() {
    super.initState();
    _loadMaterialNames();
  }

  Future<void> _loadMaterialNames() async {
    final ids = [
      stoerung.material1Id,
      stoerung.material2Id,
      stoerung.material3Id,
      stoerung.material4Id,
      stoerung.material5Id,
    ].whereType<String>().toSet();
    if (ids.isEmpty) return;

    for (final id in ids) {
      try {
        final lager = await LagerRepository.getById(id);
        if (lager != null && mounted) {
          setState(() => _materialNames[id] = lager.name);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stoerung.stoerungsnummer),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport PDF',
            onPressed: () => _showRapportPdf(),
          ),
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () =>
                  context.push('/stoerungen/${stoerung.routeId}/bearbeiten'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status & Badges
          _StatusRow(stoerung: stoerung),
          const SizedBox(height: 16),

          // Betrieb & Anlage
          if (stoerung.betriebId != null)
            _BetriebAnlageCard(stoerung: stoerung),

          // Zeiterfassung
          _SectionCard(
            title: 'Zeiterfassung',
            icon: Icons.schedule,
            children: [
              _InfoRow('Datum', _formatDate(stoerung.datum)),
              if (stoerung.referenzNr != null)
                _InfoRow('Heineken-Nr', stoerung.referenzNr!),
              if (stoerung.uhrzeitStart != null)
                _InfoRow('Störungseingang', stoerung.uhrzeitStart!),
            ],
          ),

          // Störungsdetails
          _SectionCard(
            title: 'Störungsdetails',
            icon: Icons.warning_amber,
            children: [
              if (stoerung.stoerungBereich != null)
                _InfoRow('Bereich', _bereichLabel(stoerung.stoerungBereich!)),
              if (stoerung.anlageTyp != null)
                _InfoRow('Anlagetyp', stoerung.anlageTyp!),
              _InfoRow('Beschreibung', stoerung.problemBeschreibung),
            ],
          ),

          // Preis
          if (_hasPreis)
            _SectionCard(
              title: 'Preis',
              icon: Icons.attach_money,
              children: [
                if (stoerung.preisBasis != null)
                  _InfoRow('Grundtarif',
                      '${stoerung.preisBasis!.toStringAsFixed(2)} CHF'),
                if (stoerung.preisAnfahrt != null &&
                    stoerung.preisAnfahrt! > 0)
                  _InfoRow('Anfahrt',
                      '${stoerung.preisAnfahrt!.toStringAsFixed(2)} CHF'),
                if (stoerung.preisWochenende != null &&
                    stoerung.preisWochenende! > 0)
                  _InfoRow('Wochenende',
                      '${stoerung.preisWochenende!.toStringAsFixed(2)} CHF'),
                if (stoerung.komplexitaetZuschlag != null &&
                    stoerung.komplexitaetZuschlag! > 0)
                  _InfoRow('Zuschlag',
                      '${stoerung.komplexitaetZuschlag!.toStringAsFixed(2)} CHF'),
                if (stoerung.preisNetto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 130,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${stoerung.preisNetto!.toStringAsFixed(2)} CHF',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          // Zusatz-Infos
          if (stoerung.istBergkunde ||
              stoerung.istPikettEinsatz ||
              stoerung.istWochenende ||
              stoerung.anfahrtKm > 0)
            _SectionCard(
              title: 'Zusatzinformationen',
              icon: Icons.info_outline,
              children: [
                if (stoerung.istPikettEinsatz)
                  _InfoRow('Pikett-Einsatz', 'Ja'),
                if (stoerung.istBergkunde)
                  _InfoRow('Bergkunde', 'Ja'),
                if (stoerung.istWochenende)
                  _InfoRow('Wochenende', 'Ja'),
                if (stoerung.anfahrtKm > 0)
                  _InfoRow('Anfahrt', '${stoerung.anfahrtKm} km'),
              ],
            ),

          // Material
          if (_hasMaterial)
            _SectionCard(
              title: 'Material',
              icon: Icons.inventory_2,
              children: _buildMaterialRows(),
            ),

          // Notizen
          if (stoerung.notizen != null)
            _SectionCard(
              title: 'Notizen',
              icon: Icons.note,
              children: [_InfoRow('', stoerung.notizen!)],
            ),

          // Sync-Info
          if (!stoerung.isSynced)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      color: AppColors.warning, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Noch nicht synchronisiert',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  bool get _hasPreis =>
      stoerung.preisBasis != null || stoerung.preisBrutto != null;

  bool get _hasMaterial =>
      stoerung.material1Id != null ||
      stoerung.material2Id != null ||
      stoerung.material3Id != null ||
      stoerung.material4Id != null ||
      stoerung.material5Id != null;

  List<Widget> _buildMaterialRows() {
    final rows = <Widget>[];
    final ids = [
      stoerung.material1Id,
      stoerung.material2Id,
      stoerung.material3Id,
      stoerung.material4Id,
      stoerung.material5Id,
    ];
    final mengen = [
      stoerung.material1Menge,
      stoerung.material2Menge,
      stoerung.material3Menge,
      stoerung.material4Menge,
      stoerung.material5Menge,
    ];
    for (int i = 0; i < 5; i++) {
      if (ids[i] != null) {
        final name = _materialNames[ids[i]!] ?? 'Laden...';
        final menge = (mengen[i] ?? 1).toStringAsFixed(0);
        rows.add(_InfoRow('Position ${i + 1}', '$name (${menge}x)'));
      }
    }
    return rows;
  }

  String _bereichLabel(int bereich) {
    switch (bereich) {
      case 1:
        return '1 - Kühlung/Durchlaufkühler';
      case 2:
        return '2 - Schankanlage/Zapfhahn';
      case 3:
        return '3 - Kühlsystem';
      case 4:
        return '4 - Druckgasanlage';
      case 5:
        return '5 - Sonstiges';
      default:
        return 'Bereich $bereich';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _showRapportPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Betrieb-Name + Ort laden
      String kunde = '';
      String ort = '';
      if (stoerung.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(stoerung.betriebId!);
        if (betrieb != null) {
          kunde = betrieb.name;
          ort = '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim();
        }
      }

      // Material-Namen sammeln
      final materialien = <(String, double)>[];
      final ids = [
        stoerung.material1Id, stoerung.material2Id, stoerung.material3Id,
        stoerung.material4Id, stoerung.material5Id,
      ];
      final mengen = [
        stoerung.material1Menge, stoerung.material2Menge,
        stoerung.material3Menge, stoerung.material4Menge,
        stoerung.material5Menge,
      ];
      for (int i = 0; i < 5; i++) {
        if (ids[i] != null) {
          final name = _materialNames[ids[i]!] ?? ids[i]!;
          materialien.add((name, mengen[i] ?? 1));
        }
      }

      final pdfBytes = await HeinekenRapportService.generateStoerung(
        referenzNr: stoerung.referenzNr ?? stoerung.stoerungsnummer,
        stoerungsnummer: stoerung.stoerungsnummer,
        datum: stoerung.datum,
        kunde: kunde,
        ort: ort,
        stoerungBereich: stoerung.stoerungBereich,
        uhrzeitStart: stoerung.uhrzeitStart,
        istPikettEinsatz: stoerung.istPikettEinsatz,
        istBergkunde: stoerung.istBergkunde,
        anfahrtKm: stoerung.anfahrtKm,
        preisBasis: stoerung.preisBasis,
        preisAnfahrt: stoerung.preisAnfahrt,
        preisWochenende: stoerung.preisWochenende,
        komplexitaetZuschlag: stoerung.komplexitaetZuschlag,
        preisNetto: stoerung.preisNetto,
        materialien: materialien,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Rapport_Stoerung_${stoerung.stoerungsnummer}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Störung löschen'),
        content: Text(
          'Störung ${stoerung.stoerungsnummer} wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => ctx.pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await StoerungRepository.delete(stoerung.routeId);
        ref.invalidate(stoerungenStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Löschen nur mit Internetverbindung möglich')),
          );
        }
      }
    }
  }
}

class _BetriebAnlageCard extends StatelessWidget {
  final StoerungLocal stoerung;

  const _BetriebAnlageCard({required this.stoerung});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        stoerung.betriebId != null
            ? BetriebRepository.getByServerId(stoerung.betriebId!)
                .then((b) => b?.name)
            : Future.value(null),
        stoerung.anlageId != null
            ? AnlageRepository.getByServerId(stoerung.anlageId!)
                .then((a) => a?.bezeichnung ?? a?.typAnlage)
            : Future.value(null),
      ]),
      builder: (context, snapshot) {
        final betriebName = snapshot.data?[0];
        final anlageName = snapshot.data?[1];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.store, color: AppColors.primary),
                title: Text(betriebName ?? 'Laden...'),
                subtitle: const Text('Betrieb'),
                trailing:
                    const Icon(Icons.chevron_right, size: 20),
                onTap: stoerung.betriebId != null ? () async {
                  final betrieb = await BetriebRepository.getByServerId(
                      stoerung.betriebId!);
                  if (betrieb != null && context.mounted) {
                    context.push('/betriebe/${betrieb.routeId}');
                  }
                } : null,
              ),
              if (stoerung.anlageId != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.precision_manufacturing,
                      color: AppColors.info),
                  title: Text(anlageName ?? 'Laden...'),
                  subtitle: const Text('Anlage'),
                  trailing:
                      const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final anlage = await AnlageRepository.getByServerId(
                        stoerung.anlageId!);
                    if (anlage != null && context.mounted) {
                      context.push('/anlagen/${anlage.routeId}');
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final StoerungLocal stoerung;

  const _StatusRow({required this.stoerung});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: stoerung.status,
          color: stoerung.status == 'behoben'
              ? AppColors.success
              : stoerung.status == 'offen'
                  ? AppColors.warning
                  : AppColors.inaktiv,
        ),
        if (stoerung.stoerungBereich != null)
          _StatusChip(
            label: 'Bereich ${stoerung.stoerungBereich}',
            color: AppColors.info,
            icon: Icons.category,
          ),
        if (stoerung.istPikettEinsatz)
          _StatusChip(
            label: 'Pikett',
            color: AppColors.info,
            icon: Icons.nightlight_round,
          ),
        if (stoerung.istBergkunde)
          _StatusChip(
            label: 'Bergkunde',
            color: AppColors.primary,
            icon: Icons.terrain,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
