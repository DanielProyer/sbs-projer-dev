import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class PikettDiensteListScreen extends ConsumerStatefulWidget {
  const PikettDiensteListScreen({super.key});

  @override
  ConsumerState<PikettDiensteListScreen> createState() =>
      _PikettDiensteListScreenState();
}

class _PikettDiensteListScreenState
    extends ConsumerState<PikettDiensteListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dienste = ref.watch(pikettDiensteProvider);

    // Sortieren: neueste zuerst
    final sorted = List<PikettDienstLocal>.from(dienste)
      ..sort((a, b) => b.datumStart.compareTo(a.datumStart));

    // Suche
    final filtered = sorted.where((p) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final kw = _kw(p.datumStart);
        return 'kw $kw'.contains(query) ||
            '$kw'.contains(query) ||
            _formatDate(p.datumStart).contains(query) ||
            _formatDate(p.datumEnde).contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pikett-Dienste'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'KW suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Pikett-Dienste',
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
                      final pikett = filtered[index];
                      return _PikettListItem(
                        pikett: pikett,
                        onTap: () =>
                            context.push('/pikett/${pikett.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/pikett/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.nightlight_round,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Pikett-Dienste',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Tippe auf + um einen Pikett-Dienst zu erfassen',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

int _kw(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  final wday = date.weekday;
  return ((dayOfYear - wday + 10) / 7).floor();
}

class _PikettListItem extends StatelessWidget {
  final PikettDienstLocal pikett;
  final VoidCallback onTap;

  const _PikettListItem({
    required this.pikett,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: const Icon(
            Icons.nightlight_round,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          'KW ${_kw(pikett.datumStart)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!pikett.isSynced)
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
    parts.add('Fr ${_formatDate(pikett.datumStart)} / Sa ${_formatDate(pikett.datumEnde)}');
    if (pikett.pauschaleGesamt != null) {
      parts.add('${pikett.pauschaleGesamt!.toStringAsFixed(2)} CHF');
    } else if (pikett.pauschale != null) {
      parts.add('${pikett.pauschale!.toStringAsFixed(2)} CHF');
    }
    return parts.join(' · ');
  }
}
