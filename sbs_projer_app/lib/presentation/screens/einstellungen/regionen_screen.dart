import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Regionen verwalten (Stammdaten). Heute pro Nutzer; siehe
/// [RegionRepository.createName] zur Franchise-Zukunft (geteilter Katalog).
class RegionenScreen extends ConsumerStatefulWidget {
  const RegionenScreen({super.key});

  @override
  ConsumerState<RegionenScreen> createState() => _RegionenScreenState();
}

class _RegionenScreenState extends ConsumerState<RegionenScreen> {
  /// Ob Regionen bearbeitet werden dürfen. Heute immer true (Einzelbetrieb).
  /// Franchise-Zukunft: geteilte Regionen werden zentral gepflegt → für
  /// Nicht-Admins auf false (nur Auswahl, kein Neu/Umbenennen/Löschen).
  static const _kannBearbeiten = true;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addRegion() async {
    final name = await _nameDialog(titel: 'Neue Region');
    if (name == null) return;
    try {
      await RegionRepository.createName(name);
      ref.invalidate(regionenStreamProvider);
      _snack('«$name» hinzugefügt');
    } catch (e) {
      _snack('Fehler: $e');
    }
  }

  Future<void> _renameRegion(RegionLocal region) async {
    final name = await _nameDialog(titel: 'Region umbenennen', start: region.name);
    if (name == null || name == region.name) return;
    try {
      await RegionRepository.renameRegion(region.serverId!, name);
      ref.invalidate(regionenStreamProvider);
      _snack('Umbenannt in «$name»');
    } catch (e) {
      _snack('Fehler: $e');
    }
  }

  Future<void> _deleteRegion(RegionLocal region, int betriebCount) async {
    if (betriebCount > 0) {
      // Geschützte Stammdaten: nicht löschen solange Betriebe zugeordnet sind.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Region nicht löschbar'),
          content: Text(
              '«${region.name}» hat noch $betriebCount ${betriebCount == 1 ? 'zugeordneten Betrieb' : 'zugeordnete Betriebe'}.\n\n'
              'Ordne diese Betriebe zuerst einer anderen Region zu, dann kann die Region gelöscht werden.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Region löschen'),
        content: Text('«${region.name}» wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RegionRepository.delete(region.serverId!);
      ref.invalidate(regionenStreamProvider);
      _snack('«${region.name}» gelöscht');
    } catch (e) {
      _snack('Fehler: $e');
    }
  }

  Future<String?> _nameDialog({required String titel, String? start}) {
    final controller = TextEditingController(text: start ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titel),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z.B. Prättigau',
          ),
          onSubmitted: (v) {
            final n = v.trim();
            if (n.isNotEmpty) Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final n = controller.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionen = List<RegionLocal>.from(ref.watch(regionenProvider))
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Betriebe je Region zählen (für Löschschutz + Anzeige).
    final betriebRegion = ref.watch(betriebRegionIdMapProvider);
    final counts = <String, int>{};
    for (final regionId in betriebRegion.values) {
      if (regionId != null) {
        counts[regionId] = (counts[regionId] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Regionen')),
      floatingActionButton: _kannBearbeiten
          ? FloatingActionButton(
              onPressed: _addRegion,
              child: const Icon(Icons.add),
            )
          : null,
      body: regionen.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('Keine Regionen vorhanden.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  if (_kannBearbeiten) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _addRegion,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Erste Region hinzufügen'),
                    ),
                  ],
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                Card(
                  color: AppColors.info.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18,
                            color: AppColors.info.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Regionen gruppieren Betriebe für Filter, Touren und '
                            'Karte. Eine Region lässt sich nur löschen, wenn ihr '
                            'kein Betrieb zugeordnet ist.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final r in regionen)
                        _RegionTile(
                          region: r,
                          betriebCount: counts[r.serverId] ?? 0,
                          kannBearbeiten: _kannBearbeiten,
                          onRename: () => _renameRegion(r),
                          onDelete: () =>
                              _deleteRegion(r, counts[r.serverId] ?? 0),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  final RegionLocal region;
  final int betriebCount;
  final bool kannBearbeiten;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _RegionTile({
    required this.region,
    required this.betriebCount,
    required this.kannBearbeiten,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.map, color: AppColors.primary),
      title: Text(region.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        betriebCount == 0
            ? 'Keine Betriebe'
            : '$betriebCount ${betriebCount == 1 ? 'Betrieb' : 'Betriebe'}',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: kannBearbeiten
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Umbenennen',
                  color: AppColors.textSecondary,
                  onPressed: onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Löschen',
                  color: betriebCount > 0
                      ? AppColors.textSecondary.withValues(alpha: 0.4)
                      : AppColors.error,
                  onPressed: onDelete,
                ),
              ],
            )
          : null,
      onTap: kannBearbeiten ? onRename : null,
    );
  }
}
