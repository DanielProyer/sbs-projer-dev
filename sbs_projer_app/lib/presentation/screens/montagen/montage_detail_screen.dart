import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';

class MontageDetailScreen extends ConsumerWidget {
  final String montageId;

  const MontageDetailScreen({super.key, required this.montageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<MontageLocal?>(
      future: MontageRepository.getById(montageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final montage = snapshot.data;
        if (montage == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Montage nicht gefunden')),
          );
        }

        return _MontageDetailContent(montage: montage);
      },
    );
  }
}

class _MontageDetailContent extends ConsumerStatefulWidget {
  final MontageLocal montage;

  const _MontageDetailContent({required this.montage});

  @override
  ConsumerState<_MontageDetailContent> createState() =>
      _MontageDetailContentState();
}

class _MontageDetailContentState
    extends ConsumerState<_MontageDetailContent> {
  final Map<String, String> _materialNames = {};

  MontageLocal get montage => widget.montage;

  @override
  void initState() {
    super.initState();
    _loadMaterialNames();
  }

  Future<void> _loadMaterialNames() async {
    final ids = [
      montage.material1Id, montage.material2Id, montage.material3Id,
      montage.material4Id, montage.material5Id,
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
        title: Text(_montageTypLabel(montage.montageTyp)),
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
                  context.push('/montagen/${montage.routeId}/bearbeiten'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Loeschen',
              onPressed: () => _confirmDelete(),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Typ-Chip
          Wrap(
            spacing: 8,
            children: [
              _TypeChip(
                label: _montageTypLabel(montage.montageTyp),
                icon: _montageTypIcon(montage.montageTyp),
                color: _montageTypColor(montage.montageTyp),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Betrieb & Anlage (nur wenn vorhanden)
          if (montage.betriebId != null)
            _BetriebAnlageCard(montage: montage),

          // Datum & Aufwand
          _SectionCard(
            title: 'Datum & Aufwand',
            icon: Icons.schedule,
            children: [
              _InfoRow('Datum', _formatDate(montage.datum)),
              if (montage.dauerStunden != null)
                _InfoRow('Stunden', '${montage.dauerStunden!.toStringAsFixed(2)} h'),
            ],
          ),

          // Details
          _SectionCard(
            title: 'Beschreibung',
            icon: Icons.description,
            children: [
              _InfoRow('', montage.beschreibung),
            ],
          ),

          // Kosten
          if (_hasKosten)
            _SectionCard(
              title: 'Kosten',
              icon: Icons.attach_money,
              children: [
                if (montage.stundensatz != null)
                  _InfoRow('Stundensatz',
                      '${montage.stundensatz!.toStringAsFixed(2)} CHF/h'),
                if (montage.dauerStunden != null)
                  _InfoRow('Stunden',
                      '${montage.dauerStunden!.toStringAsFixed(2)} h'),
                if (montage.kostenArbeit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            montage.montageTyp == 'heigenie_service'
                                ? 'Total inkl. MwSt'
                                : 'Arbeitskosten',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${montage.kostenArbeit!.toStringAsFixed(2)} CHF',
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

          // Material / Anlass-Tage
          if (_hasMaterial)
            _SectionCard(
              title: montage.montageTyp == 'anlass' ? 'Tage & Spesen' : 'Material',
              icon: montage.montageTyp == 'anlass' ? Icons.event_note : Icons.inventory_2,
              children: _buildMaterialRows(),
            ),

          // Notizen
          if (montage.notizen != null)
            _SectionCard(
              title: 'Notizen',
              icon: Icons.note,
              children: [_InfoRow('', montage.notizen!)],
            ),

          // Sync-Info
          if (!montage.isSynced)
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

  bool get _hasKosten =>
      montage.stundensatz != null || montage.kostenArbeit != null;

  bool get _hasMaterial =>
      montage.material1Id != null || montage.material2Id != null ||
      montage.material3Id != null || montage.material4Id != null ||
      montage.material5Id != null;

  List<Widget> _buildMaterialRows() {
    final rows = <Widget>[];
    final ids = [
      montage.material1Id, montage.material2Id, montage.material3Id,
      montage.material4Id, montage.material5Id,
    ];
    final mengen = [
      montage.material1Menge, montage.material2Menge, montage.material3Menge,
      montage.material4Menge, montage.material5Menge,
    ];
    final isAnlass = montage.montageTyp == 'anlass';
    for (int i = 0; i < 5; i++) {
      if (ids[i] != null) {
        if (isAnlass) {
          // Bei Anlass: Freitext + Stunden
          final stunden = (mengen[i] ?? 0).toStringAsFixed(2);
          rows.add(_InfoRow(ids[i]!, '${stunden} h'));
        } else {
          final name = _materialNames[ids[i]!] ?? 'Laden...';
          final menge = (mengen[i] ?? 1).toStringAsFixed(0);
          rows.add(_InfoRow('Position ${i + 1}', '$name (${menge}x)'));
        }
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
      if (montage.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(montage.betriebId!);
        if (betrieb != null) {
          kunde = betrieb.name;
          ort = '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim();
        }
      }

      final materialien = <(String, double)>[];
      final ids = [
        montage.material1Id, montage.material2Id, montage.material3Id,
        montage.material4Id, montage.material5Id,
      ];
      final mengen = [
        montage.material1Menge, montage.material2Menge,
        montage.material3Menge, montage.material4Menge,
        montage.material5Menge,
      ];
      for (int i = 0; i < 5; i++) {
        if (ids[i] != null) {
          final name = _materialNames[ids[i]!] ?? ids[i]!;
          materialien.add((name, mengen[i] ?? 1));
        }
      }

      final pdfBytes = await HeinekenRapportService.generateMontage(
        referenzNr: montage.referenzNr ?? _montageTypLabel(montage.montageTyp),
        datum: montage.datum,
        kunde: kunde,
        ort: ort,
        montageTyp: montage.montageTyp,
        beschreibung: montage.beschreibung,
        stundensatz: montage.stundensatz,
        dauerStunden: montage.dauerStunden,
        kostenArbeit: montage.kostenArbeit,
        materialien: materialien,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Rapport_Montage_${_montageTypLabel(montage.montageTyp)}',
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
        title: const Text('Montage loeschen'),
        content: const Text(
          'Diese Montage wirklich loeschen?\n\nDiese Aktion kann nicht rueckgaengig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => ctx.pop(true),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await MontageRepository.delete(montage.routeId);
        ref.invalidate(montagenStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Loeschen nur mit Internetverbindung moeglich')),
          );
        }
      }
    }
  }
}

String _montageTypLabel(String typ) {
  switch (typ) {
    case 'neumontage':
      return 'Neumontage';
    case 'demontage':
      return 'Demontage';
    case 'abaenderung':
      return 'Abänderung';
    case 'heigenie_service':
      return 'HeiGenie Service';
    case 'anlass':
      return 'Anlass';
    case 'spesen':
      return 'Spesen';
    case 'aufwandsentschaedigung':
      return 'Aufwandsentsch.';
    // Legacy
    case 'neu_installation': case 'montage': return 'Neumontage';
    case 'umbau': case 'erweiterung': return 'Abänderung';
    case 'abbau': return 'Demontage';
    case 'anlass_mitarbeit': return 'Anlass';
    default:
      return typ;
  }
}

IconData _montageTypIcon(String typ) {
  switch (typ) {
    case 'neumontage': case 'neu_installation': case 'montage':
      return Icons.add_circle_outline;
    case 'demontage': case 'abbau':
      return Icons.remove_circle_outline;
    case 'abaenderung': case 'umbau': case 'erweiterung':
      return Icons.tune;
    case 'heigenie_service':
      return Icons.cleaning_services;
    case 'anlass': case 'anlass_mitarbeit':
      return Icons.celebration;
    case 'spesen':
      return Icons.receipt_long;
    case 'aufwandsentschaedigung':
      return Icons.account_balance_wallet;
    default:
      return Icons.build;
  }
}

Color _montageTypColor(String typ) {
  switch (typ) {
    case 'neumontage': case 'neu_installation': case 'montage':
      return const Color(0xFF16A34A); // Grün
    case 'demontage': case 'abbau':
      return const Color(0xFFDC2626); // Rot
    case 'abaenderung': case 'umbau': case 'erweiterung':
      return const Color(0xFF2563EB); // Blau
    case 'heigenie_service':
      return const Color(0xFF0D9488); // Teal
    case 'anlass': case 'anlass_mitarbeit':
      return const Color(0xFF7C3AED); // Violett
    case 'spesen':
      return const Color(0xFFD97706); // Amber
    case 'aufwandsentschaedigung':
      return const Color(0xFF64748B); // Grau
    default:
      return const Color(0xFF6B7280);
  }
}

class _BetriebAnlageCard extends StatelessWidget {
  final MontageLocal montage;

  const _BetriebAnlageCard({required this.montage});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        BetriebRepository.getByServerId(montage.betriebId!)
            .then((b) => b?.name),
        if (montage.anlageId != null)
          AnlageRepository.getByServerId(montage.anlageId!)
              .then((a) => a?.bezeichnung ?? a?.typAnlage)
        else
          Future.value(null),
      ]),
      builder: (context, snapshot) {
        final betriebName = snapshot.data?[0];
        final anlageName = snapshot.data != null && snapshot.data!.length > 1
            ? snapshot.data![1]
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.store, color: AppColors.primary),
                title: Text(betriebName ?? 'Laden...'),
                subtitle: const Text('Betrieb'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  final betrieb = await BetriebRepository.getByServerId(
                      montage.betriebId!);
                  if (betrieb != null && context.mounted) {
                    context.push('/betriebe/${betrieb.routeId}');
                  }
                },
              ),
              if (montage.anlageId != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.precision_manufacturing,
                      color: AppColors.info),
                  title: Text(anlageName ?? 'Laden...'),
                  subtitle: const Text('Anlage'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final anlage = await AnlageRepository.getByServerId(
                        montage.anlageId!);
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

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
  });

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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
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
