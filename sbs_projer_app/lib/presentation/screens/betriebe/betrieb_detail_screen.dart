import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/anlage_local.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

class BetriebDetailScreen extends ConsumerWidget {
  final int betriebId;

  const BetriebDetailScreen({super.key, required this.betriebId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<BetriebLocal?>(
      future: BetriebRepository.getById(betriebId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final betrieb = snapshot.data;
        if (betrieb == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Betrieb nicht gefunden')),
          );
        }

        return _BetriebDetailContent(betrieb: betrieb);
      },
    );
  }
}

class _BetriebDetailContent extends StatelessWidget {
  final BetriebLocal betrieb;

  const _BetriebDetailContent({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(betrieb.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Bearbeiten',
            onPressed: () => context.push('/betriebe/${betrieb.id}/bearbeiten'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status & Badges
          _StatusRow(betrieb: betrieb),
          const SizedBox(height: 16),

          // Adresse
          _SectionCard(
            title: 'Adresse',
            icon: Icons.location_on,
            children: [
              if (betrieb.strasse != null)
                _InfoRow('Strasse', '${betrieb.strasse} ${betrieb.nr ?? ''}'),
              if (betrieb.plz != null || betrieb.ort != null)
                _InfoRow('Ort', '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim()),
            ],
          ),

          // Kontakt
          _SectionCard(
            title: 'Kontakt',
            icon: Icons.contact_phone,
            children: [
              if (betrieb.email != null) _InfoRow('E-Mail', betrieb.email!),
              if (betrieb.website != null) _InfoRow('Website', betrieb.website!),
            ],
          ),

          // Details
          _SectionCard(
            title: 'Details',
            icon: Icons.info_outline,
            children: [
              if (betrieb.heinekenNr != null)
                _InfoRow('Heineken-Nr.', betrieb.heinekenNr!),
              _InfoRow('Status', betrieb.status),
              _InfoRow('Mein Kunde', betrieb.istMeinKunde ? 'Ja' : 'Nein'),
              _InfoRow('Bergkunde', betrieb.istBergkunde ? 'Ja' : 'Nein'),
              _InfoRow('Saisonbetrieb', betrieb.istSaisonbetrieb ? 'Ja' : 'Nein'),
              _InfoRow('Rechnungsstellung', betrieb.rechnungsstellung),
            ],
          ),

          // Saison-Info (wenn Saisonbetrieb)
          if (betrieb.istSaisonbetrieb)
            _SectionCard(
              title: 'Saison',
              icon: Icons.calendar_month,
              children: [
                if (betrieb.winterSaisonAktiv)
                  _InfoRow('Winter', 'Monat ${betrieb.winterStartMonat} - ${betrieb.winterEndeMonat}'),
                if (betrieb.sommerSaisonAktiv)
                  _InfoRow('Sommer', 'Monat ${betrieb.sommerStartMonat} - ${betrieb.sommerEndeMonat}'),
                if (betrieb.ferienStart != null)
                  _InfoRow('Ferien', '${_formatDate(betrieb.ferienStart!)} - ${_formatDate(betrieb.ferienEnde!)}'),
              ],
            ),

          // Zugang & Notizen
          if (betrieb.zugangNotizen != null || betrieb.notizen != null)
            _SectionCard(
              title: 'Notizen',
              icon: Icons.note,
              children: [
                if (betrieb.zugangNotizen != null)
                  _InfoRow('Zugang', betrieb.zugangNotizen!),
                if (betrieb.notizen != null)
                  _InfoRow('Notizen', betrieb.notizen!),
              ],
            ),

          // Anlagen
          if (betrieb.serverId != null)
            _AnlagenSection(betrieb: betrieb),

          // Sync-Info
          if (!betrieb.isSynced)
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

          const SizedBox(height: 80), // Platz für FAB
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _AnlagenSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _AnlagenSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnlageLocal>>(
      stream: AnlageRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final anlagen = snapshot.data ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Anlagen (${anlagen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Anlage'),
                      onPressed: () => context.push(
                        '/anlagen/neu?betriebId=${betrieb.serverId}',
                      ),
                    ),
                  ],
                ),
                if (anlagen.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...anlagen.map((a) => _AnlageRow(anlage: a)),
                ],
                if (anlagen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Anlagen erfasst',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnlageRow extends StatelessWidget {
  final AnlageLocal anlage;

  const _AnlageRow({required this.anlage});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/anlagen/${anlage.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.precision_manufacturing,
                  size: 16, color: AppColors.info),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anlage.bezeichnung ?? anlage.typAnlage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${anlage.typAnlage} · ${anlage.anzahlHaehne} Hähne',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final BetriebLocal betrieb;

  const _StatusRow({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: betrieb.status,
          color: _statusColor(betrieb.status),
        ),
        if (betrieb.istBergkunde)
          _StatusChip(label: 'Bergkunde', color: AppColors.info, icon: Icons.terrain),
        if (betrieb.istSaisonbetrieb)
          _StatusChip(label: 'Saisonbetrieb', color: AppColors.saisonpause, icon: Icons.calendar_month),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aktiv':
        return AppColors.aktiv;
      case 'inaktiv':
        return AppColors.inaktiv;
      case 'saisonpause':
        return AppColors.saisonpause;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({required this.label, required this.color, this.icon});

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
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
