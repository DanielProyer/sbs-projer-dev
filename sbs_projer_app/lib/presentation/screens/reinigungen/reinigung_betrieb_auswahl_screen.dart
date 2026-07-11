import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/betrieb_status.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

/// Betriebsauswahl-Screen für neue Reinigungen.
/// Wird angezeigt wenn /reinigungen/neu ohne betriebId aufgerufen wird.
class ReinigungBetriebAuswahlScreen extends ConsumerStatefulWidget {
  const ReinigungBetriebAuswahlScreen({super.key});

  @override
  ConsumerState<ReinigungBetriebAuswahlScreen> createState() =>
      _ReinigungBetriebAuswahlScreenState();
}

class _ReinigungBetriebAuswahlScreenState
    extends ConsumerState<ReinigungBetriebAuswahlScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider)
        .where((b) => b.serverId != null && istBetriebOperativ(b.status))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final filtered = _searchQuery.isEmpty
        ? betriebe
        : betriebe.where((b) {
            final query = _searchQuery.toLowerCase();
            return b.name.toLowerCase().contains(query) ||
                (b.ort?.toLowerCase().contains(query) ?? false) ||
                (b.betriebNr?.toLowerCase().contains(query) ?? false);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Betrieb auswählen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Betrieb suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Keine Betriebe gefunden'
                          : 'Keine Betriebe vorhanden',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final b = filtered[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withAlpha(25),
                            child: const Icon(Icons.store,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Text(b.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: b.ort != null ? Text(b.ort!) : null,
                          trailing:
                              const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            // Zur Reinigung-Form navigieren mit betriebId
                            context.pushReplacement(
                                '/reinigungen/neu?betriebId=${b.serverId}');
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
