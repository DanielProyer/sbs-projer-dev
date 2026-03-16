import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';

class BestelllisteScreen extends ConsumerWidget {
  const BestelllisteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Lager>>(
      future: LagerRepository.getBestellliste(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bestellliste'),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'In Zwischenablage kopieren',
                  onPressed: () => _copyToClipboard(context, items),
                ),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 64,
                          color: AppColors.success.withAlpha(150)),
                      const SizedBox(height: 16),
                      Text(
                        'Alle Bestände OK',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.success),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kein Material unter Mindestbestand',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${items.length} Artikel nachbestellen',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    final lager = items[index - 1];
                    final fehlmenge =
                        lager.bestandOptimal - lager.bestandAktuell;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.error.withAlpha(25),
                          child: Icon(Icons.warning,
                              color: AppColors.error, size: 20),
                        ),
                        title: Text(lager.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Bestand: ${lager.bestandAktuell.toStringAsFixed(0)} · '
                          'Mindest: ${lager.bestandMindest.toStringAsFixed(0)} · '
                          'Optimal: ${lager.bestandOptimal.toStringAsFixed(0)}'
                          '${lager.dboNr != null ? ' · DBO ${lager.dboNr}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          '+${fehlmenge.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, List<Lager> items) {
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final buffer =
        StringBuffer('Bestellliste SBS Projer ($date)\n\n');
    for (final item in items) {
      final fehlmenge = item.bestandOptimal - item.bestandAktuell;
      buffer.write('- ${item.name}: ${fehlmenge.toStringAsFixed(0)} ${item.einheit}');
      if (item.dboNr != null) buffer.write(' (DBO: ${item.dboNr})');
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bestellliste in Zwischenablage kopiert')),
    );
  }
}
