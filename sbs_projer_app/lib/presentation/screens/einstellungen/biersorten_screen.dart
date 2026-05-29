import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/biersorte.dart';
import 'package:sbs_projer_app/data/repositories/biersorte_repository.dart';
import 'package:sbs_projer_app/presentation/providers/biersorte_providers.dart';

class BiersortenScreen extends ConsumerStatefulWidget {
  const BiersortenScreen({super.key});

  @override
  ConsumerState<BiersortenScreen> createState() => _BiersortenScreenState();
}

class _BiersortenScreenState extends ConsumerState<BiersortenScreen> {
  static const _kategorien = ['eigen', 'fremd', 'mineral', 'wein'];

  static Color kategorieColor(String kategorie) {
    return switch (kategorie) {
      'eigen' => AppColors.primary,
      'fremd' => Colors.orange.shade700,
      'mineral' => AppColors.info,
      'wein' => Colors.purple.shade600,
      _ => AppColors.textSecondary,
    };
  }

  static String kategorieLabel(String kategorie) {
    return switch (kategorie) {
      'eigen' => 'Eigen (Heineken)',
      'fremd' => 'Fremd',
      'mineral' => 'Mineral/Softgetränke',
      'wein' => 'Wein',
      _ => kategorie,
    };
  }

  static String kategorieLabelKurz(String kategorie) {
    return switch (kategorie) {
      'eigen' => 'Eigen',
      'fremd' => 'Fremd',
      'mineral' => 'Mineral',
      'wein' => 'Wein',
      _ => kategorie,
    };
  }

  static IconData kategorieIcon(String kategorie) {
    return switch (kategorie) {
      'eigen' => Icons.star,
      'fremd' => Icons.sports_bar,
      'mineral' => Icons.water_drop,
      'wein' => Icons.wine_bar,
      _ => Icons.local_drink,
    };
  }

  Future<void> _addBiersorte() async {
    final nameController = TextEditingController();
    String kategorie = 'fremd';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Neue Biersorte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'z.B. Feldschlösschen',
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: kategorie,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                items: _kategorien
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Row(
                            children: [
                              Icon(kategorieIcon(k),
                                  size: 18, color: kategorieColor(k)),
                              const SizedBox(width: 8),
                              Text(kategorieLabelKurz(k)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => kategorie = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, {'name': name, 'kategorie': kategorie});
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      await BiersorteRepository.create(result);
      ref.invalidate(biersortenProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['name']} hinzugefügt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _changeKategorie(Biersorte biersorte) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(biersorte.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Kategorie wählen',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            ..._kategorien.map((k) {
              final isSelected = k == biersorte.kategorie;
              return ListTile(
                leading: Icon(kategorieIcon(k), color: kategorieColor(k)),
                title: Text(kategorieLabel(k)),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                selected: isSelected,
                onTap: () => Navigator.pop(ctx, k),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null || result == biersorte.kategorie) return;

    try {
      await BiersorteRepository.update(biersorte.id, {'kategorie': result});
      ref.invalidate(biersortenProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _deleteBiersorte(Biersorte biersorte) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Biersorte löschen'),
        content: Text(
            '«${biersorte.name}» wirklich löschen?\n\nUnbekannte Biersorten werden bei der Reinigung automatisch als «Fremd» gezählt.'),
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
      await BiersorteRepository.delete(biersorte.id);
      ref.invalidate(biersortenProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${biersorte.name} gelöscht')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final biersortenAsync = ref.watch(biersortenProvider);
    final countsAsync = ref.watch(biersorteLeitungenCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biersorten')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBiersorte,
        child: const Icon(Icons.add),
      ),
      body: biersortenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (biersorten) {
          if (biersorten.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_drink,
                      size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('Keine Biersorten vorhanden.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addBiersorte,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Erste Biersorte hinzufügen'),
                  ),
                ],
              ),
            );
          }

          final counts = countsAsync.valueOrNull ?? {};

          // Gruppiert nach Kategorie, alphabetisch sortiert
          final grouped = <String, List<Biersorte>>{};
          for (final k in _kategorien) {
            final list = biersorten.where((b) => b.kategorie == k).toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            grouped[k] = list;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              // Info-Hinweis
              Card(
                color: AppColors.info.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppColors.info.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Die Kategorie bestimmt den Reinigungspreis pro Hahn. '
                          'Unbekannte Biersorten werden als «Fremd» gezählt.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Kategorie-Gruppen
              for (final k in _kategorien)
                if (grouped[k]!.isNotEmpty)
                  _KategorieCard(
                    kategorie: k,
                    biersorten: grouped[k]!,
                    leitungenCounts: counts,
                    onChangeKategorie: _changeKategorie,
                    onDelete: _deleteBiersorte,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _KategorieCard extends StatelessWidget {
  final String kategorie;
  final List<Biersorte> biersorten;
  final Map<String, int> leitungenCounts;
  final ValueChanged<Biersorte> onChangeKategorie;
  final ValueChanged<Biersorte> onDelete;

  const _KategorieCard({
    required this.kategorie,
    required this.biersorten,
    required this.leitungenCounts,
    required this.onChangeKategorie,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _BiersortenScreenState.kategorieColor(kategorie);
    final label = _BiersortenScreenState.kategorieLabel(kategorie);
    final icon = _BiersortenScreenState.kategorieIcon(kategorie);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              leading: Icon(icon, color: color, size: 22),
              title: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${biersorten.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: color)),
              ),
            ),
          ),
          // Biersorten-Liste
          ...biersorten.map((b) {
            final count = leitungenCounts[b.name] ?? 0;
            return Dismissible(
                key: ValueKey(b.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: AppColors.error,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  onDelete(b);
                  return false; // Dialog übernimmt
                },
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  title: Text(b.name, style: const TextStyle(fontSize: 15)),
                  subtitle: count > 0
                      ? Text('$count ${count == 1 ? 'Leitung' : 'Leitungen'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    tooltip: 'Kategorie ändern',
                    color: AppColors.textSecondary,
                    onPressed: () => onChangeKategorie(b),
                  ),
                ),
              );
          }),
        ],
      ),
    );
  }
}
