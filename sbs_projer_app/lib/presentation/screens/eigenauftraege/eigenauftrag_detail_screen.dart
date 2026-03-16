import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/repositories/eigenauftrag_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';

class EigenauftragDetailScreen extends ConsumerWidget {
  final String eigenauftragId;

  const EigenauftragDetailScreen({super.key, required this.eigenauftragId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<EigenauftragLocal?>(
      future: EigenauftragRepository.getById(eigenauftragId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final ea = snapshot.data;
        if (ea == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Eigenauftrag nicht gefunden')),
          );
        }
        return _DetailContent(eigenauftrag: ea);
      },
    );
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  final EigenauftragLocal eigenauftrag;
  const _DetailContent({required this.eigenauftrag});

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  final Map<String, String> _materialNames = {};
  EigenauftragLocal get ea => widget.eigenauftrag;

  @override
  void initState() {
    super.initState();
    _loadMaterialNames();
  }

  Future<void> _loadMaterialNames() async {
    final ids = [ea.material1Id, ea.material2Id, ea.material3Id]
        .whereType<String>()
        .toSet();
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
        title: Text(ea.stoerungsnummer),
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
                  context.push('/eigenauftraege/${ea.routeId}/bearbeiten'),
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
          // Status
          _StatusRow(eigenauftrag: ea),
          const SizedBox(height: 16),

          // Betrieb
          if (ea.betriebId != null) _BetriebCard(betriebId: ea.betriebId!),

          // Auftragsinfo
          _SectionCard(
            title: 'Auftragsinfo',
            icon: Icons.build_circle_outlined,
            children: [
              _InfoRow('Störungsnummer', ea.stoerungsnummer),
              _InfoRow('Datum', _formatDate(ea.datum)),
              _InfoRow('Beschreibung', ea.problemBeschreibung),
            ],
          ),

          // Preis
          if (ea.pauschale != null)
            _SectionCard(
              title: 'Preis',
              icon: Icons.attach_money,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 130,
                        child: Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Expanded(
                        child: Text(
                          '${ea.pauschale!.toStringAsFixed(2)} CHF',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // Material
          if (_hasMaterial)
            _SectionCard(
              title: 'Material',
              icon: Icons.inventory_2,
              children: _buildMaterialRows(),
            ),

          // Sync-Info
          if (!ea.isSynced)
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
                  Text('Noch nicht synchronisiert',
                      style: TextStyle(color: AppColors.warning)),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  bool get _hasMaterial =>
      ea.material1Id != null ||
      ea.material2Id != null ||
      ea.material3Id != null;

  List<Widget> _buildMaterialRows() {
    final rows = <Widget>[];
    final ids = [ea.material1Id, ea.material2Id, ea.material3Id];
    final mengen = [ea.material1Menge, ea.material2Menge, ea.material3Menge];
    for (int i = 0; i < 3; i++) {
      if (ids[i] != null) {
        final name = _materialNames[ids[i]!] ?? 'Laden...';
        final menge = (mengen[i] ?? 1).toStringAsFixed(0);
        rows.add(_InfoRow('Position ${i + 1}', '$name (${menge}x)'));
      }
    }
    return rows;
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
      String kunde = '';
      String ort = '';
      if (ea.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(ea.betriebId!);
        if (betrieb != null) {
          kunde = betrieb.name;
          ort = '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim();
        }
      }

      final materialien = <(String, double)>[];
      final ids = [ea.material1Id, ea.material2Id, ea.material3Id];
      final mengen = [ea.material1Menge, ea.material2Menge, ea.material3Menge];
      for (int i = 0; i < 3; i++) {
        if (ids[i] != null) {
          final name = _materialNames[ids[i]!] ?? ids[i]!;
          materialien.add((name, mengen[i] ?? 1));
        }
      }

      final pdfBytes = await HeinekenRapportService.generateEigenauftrag(
        referenzNr: ea.referenzNr ?? ea.stoerungsnummer,
        stoerungsnummer: ea.stoerungsnummer,
        datum: ea.datum,
        kunde: kunde,
        ort: ort,
        problemBeschreibung: ea.problemBeschreibung,
        loesungBeschreibung: ea.loesungBeschreibung,
        pauschale: ea.pauschale,
        materialien: materialien,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Rapport_Eigenauftrag_${ea.stoerungsnummer}',
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
        title: const Text('Eigenauftrag löschen'),
        content: Text(
          'Eigenauftrag ${ea.stoerungsnummer} wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
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
        await EigenauftragRepository.delete(ea.routeId);
        ref.invalidate(eigenauftraegeStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Löschen nur mit Internetverbindung möglich')),
          );
        }
      }
    }
  }
}

class _BetriebCard extends StatelessWidget {
  final String betriebId;
  const _BetriebCard({required this.betriebId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: BetriebRepository.getByServerId(betriebId).then((b) => b?.name),
      builder: (context, snapshot) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.store, color: AppColors.primary),
            title: Text(snapshot.data ?? 'Laden...'),
            subtitle: const Text('Betrieb'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              final betrieb =
                  await BetriebRepository.getByServerId(betriebId);
              if (betrieb != null && context.mounted) {
                context.push('/betriebe/${betrieb.routeId}');
              }
            },
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final EigenauftragLocal eigenauftrag;
  const _StatusRow({required this.eigenauftrag});

  @override
  Widget build(BuildContext context) {
    final color = switch (eigenauftrag.status) {
      'behoben' => AppColors.success,
      'nicht_behebbar' => AppColors.inaktiv,
      'nachbearbeitung_noetig' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Text(
            eigenauftrag.status,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ],
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
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
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
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
