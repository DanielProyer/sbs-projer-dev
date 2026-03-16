import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';

class EroeffnungsreinigungDetailScreen extends ConsumerWidget {
  final String eroeffnungsreinigungId;

  const EroeffnungsreinigungDetailScreen(
      {super.key, required this.eroeffnungsreinigungId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<EroeffnungsreinigungLocal?>(
      future: EroeffnungsreinigungRepository.getById(eroeffnungsreinigungId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final er = snapshot.data;
        if (er == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(
                child: Text('Eröffnungsreinigung nicht gefunden')),
          );
        }
        return _DetailContent(item: er);
      },
    );
  }
}

class _DetailContent extends ConsumerWidget {
  final EroeffnungsreinigungLocal item;
  const _DetailContent({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.stoerungsnummer),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport PDF',
            onPressed: () => _showRapportPdf(context),
          ),
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () => context.push(
                  '/eroeffnungsreinigungen/${item.routeId}/bearbeiten'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bergkunde Badge
          if (item.istBergkunde)
            Wrap(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.warning.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terrain,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text('Bergkunde',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          if (item.istBergkunde) const SizedBox(height: 16),

          // Betrieb
          if (item.betriebId != null) _BetriebCard(betriebId: item.betriebId!),

          // Info
          _SectionCard(
            title: 'Details',
            icon: Icons.cleaning_services_outlined,
            children: [
              _InfoRow('Störungsnummer', item.stoerungsnummer),
              _InfoRow('Datum', _formatDate(item.datum)),
              if (item.preis != null)
                _InfoRow('Preis', '${item.preis!.toStringAsFixed(2)} CHF'),
            ],
          ),

          // Sync-Info
          if (!item.isSynced)
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _showRapportPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String kunde = '';
      String ort = '';
      if (item.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(item.betriebId!);
        if (betrieb != null) {
          kunde = betrieb.name;
          ort = '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim();
        }
      }

      final pdfBytes = await HeinekenRapportService.generateEEReinigung(
        referenzNr: item.stoerungsnummer,
        stoerungsnummer: item.stoerungsnummer,
        datum: item.datum,
        kunde: kunde,
        ort: ort,
        istBergkunde: item.istBergkunde,
        preis: item.preis ?? 0,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Rapport_EEReinigung_${item.stoerungsnummer}',
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eröffnungsreinigung löschen'),
        content: Text(
          'Eröffnungsreinigung ${item.stoerungsnummer} wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
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
        await EroeffnungsreinigungRepository.delete(item.routeId);
        ref.invalidate(eroeffnungsreinigungenStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Löschen nur mit Internetverbindung möglich')),
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
      future:
          BetriebRepository.getByServerId(betriebId).then((b) => b?.name),
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
