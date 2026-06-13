import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditBefundeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Audit / Verdächtige Buchungen')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (befunde) {
          if (befunde.isEmpty) {
            return const Center(child: Text('Keine Auffälligkeiten gefunden.'));
          }
          final gruppen = <String, List<AuditBefund>>{};
          for (final b in befunde) {
            gruppen.putIfAbsent(b.kategorie, () => []).add(b);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in gruppen.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.key} (${entry.value.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const Divider(),
                        for (final b in entry.value)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${b.konto} · ${b.bezeichnung}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(b.hinweis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text('${b.saldo.toStringAsFixed(2)} CHF',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: b.saldo < 0
                                            ? AppColors.error
                                            : AppColors.textPrimary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
