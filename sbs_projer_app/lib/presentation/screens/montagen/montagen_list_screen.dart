import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MontagenListScreen extends ConsumerStatefulWidget {
  const MontagenListScreen({super.key});

  @override
  ConsumerState<MontagenListScreen> createState() =>
      _MontagenListScreenState();
}

class _MontagenListScreenState extends ConsumerState<MontagenListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final montagen = ref.watch(montagenProvider);
    final betriebe = ref.watch(betriebeProvider);

    // Betrieb-Name Lookup
    final betriebNames = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
      }
    }

    // Sortieren nach Datum (neueste zuerst)
    final sorted = List<MontageLocal>.from(montagen)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    // Suche
    final filtered = sorted.where((m) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName = betriebNames[m.betriebId]?.toLowerCase() ?? '';
        return betriebName.contains(query) ||
            _montageTypLabel(m.montageTyp).toLowerCase().contains(query) ||
            m.beschreibung.toLowerCase().contains(query) ||
            (m.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Montagen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Montage suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Montagen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final montage = filtered[index];
                      return _MontageListItem(
                        montage: montage,
                        betriebName: betriebNames[montage.betriebId],
                        onTap: () =>
                            context.push('/montagen/${montage.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/montagen/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Montagen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Tippe auf + um eine Montage zu erfassen',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

String _montageTypLabel(String typ) {
  switch (typ) {
    case 'neu_installation':
      return 'Neu-Installation';
    case 'umbau':
      return 'Umbau';
    case 'erweiterung':
      return 'Erweiterung';
    case 'abbau':
      return 'Abbau';
    case 'heigenie_service':
      return 'HeiGenie Service';
    case 'anlass_mitarbeit':
      return 'Anlass-Mitarbeit';
    case 'mehraufwand':
      return 'Mehraufwand';
    case 'spesen':
      return 'Spesen';
    case 'sonstiges':
      return 'Sonstiges';
    default:
      return typ;
  }
}

IconData _montageTypIcon(String typ) {
  switch (typ) {
    case 'neu_installation':
      return Icons.add_circle;
    case 'umbau':
      return Icons.swap_horiz;
    case 'erweiterung':
      return Icons.expand;
    case 'abbau':
      return Icons.remove_circle;
    case 'heigenie_service':
      return Icons.cleaning_services;
    case 'anlass_mitarbeit':
      return Icons.festival;
    case 'mehraufwand':
      return Icons.add_task;
    case 'spesen':
      return Icons.receipt;
    case 'sonstiges':
      return Icons.build;
    default:
      return Icons.build;
  }
}

class _MontageListItem extends StatelessWidget {
  final MontageLocal montage;
  final String? betriebName;
  final VoidCallback onTap;

  const _MontageListItem({
    required this.montage,
    this.betriebName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: Icon(_montageTypIcon(montage.montageTyp),
              color: AppColors.primary, size: 20),
        ),
        title: Text(
          _montageTypLabel(montage.montageTyp),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!montage.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (betriebName != null) parts.add(betriebName!);
    parts.add(_formatDate(montage.datum));
    if (montage.dauerStunden != null) {
      parts.add('${montage.dauerStunden!.toStringAsFixed(1)} h');
    }
    if (montage.kostenArbeit != null) {
      parts.add('${montage.kostenArbeit!.toStringAsFixed(2)} CHF');
    }
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
