import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EroeffnungsreinigungListScreen extends ConsumerStatefulWidget {
  const EroeffnungsreinigungListScreen({super.key});

  @override
  ConsumerState<EroeffnungsreinigungListScreen> createState() =>
      _EroeffnungsreinigungListScreenState();
}

class _EroeffnungsreinigungListScreenState
    extends ConsumerState<EroeffnungsreinigungListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(eroeffnungsreinigungenProvider);
    final betriebe = ref.watch(betriebeProvider);

    final betriebNames = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
      }
    }

    final sorted = List<EroeffnungsreinigungLocal>.from(items)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    final filtered = sorted.where((e) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            (e.betriebId != null ? betriebNames[e.betriebId!] : null)
                    ?.toLowerCase() ??
                '';
        return betriebName.contains(query) ||
            e.stoerungsnummer.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eröffnungsreinigungen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Suchen...',
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
                '${filtered.length} Einträge',
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
                      final er = filtered[index];
                      return _ListItem(
                        item: er,
                        betriebName: er.betriebId != null
                            ? betriebNames[er.betriebId!]
                            : null,
                        onTap: () => context.push(
                            '/eroeffnungsreinigungen/${er.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  context.push('/eroeffnungsreinigungen/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cleaning_services_outlined,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Eröffnungsreinigungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Erfasse eine neue Eröffnungsreinigung mit dem + Button',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  final EroeffnungsreinigungLocal item;
  final String? betriebName;
  final VoidCallback onTap;

  const _ListItem({
    required this.item,
    this.betriebName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: Icon(Icons.cleaning_services_outlined,
              color: AppColors.primary, size: 20),
        ),
        title: Text(
          item.stoerungsnummer,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.istBergkunde)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.terrain, size: 16, color: AppColors.warning),
              ),
            if (!item.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.cloud_upload_outlined,
                    size: 16, color: AppColors.warning),
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
    parts.add(_formatDate(item.datum));
    if (item.preis != null) {
      parts.add('${item.preis!.toStringAsFixed(2)} CHF');
    }
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
