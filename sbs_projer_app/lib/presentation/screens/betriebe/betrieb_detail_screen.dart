import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eigenauftrag_repository.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class BetriebDetailScreen extends ConsumerWidget {
  final String betriebId;

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

class _BetriebDetailContent extends ConsumerWidget {
  final BetriebLocal betrieb;

  const _BetriebDetailContent({required this.betrieb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(betrieb.name),
        actions: [
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () => context.push('/betriebe/${betrieb.routeId}/bearbeiten'),
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
              if (betrieb.telefon != null)
                _LinkRow('Telefon', betrieb.telefon!, Uri.parse('tel:${betrieb.telefon!.replaceAll(' ', '')}')),
              if (betrieb.email != null)
                _LinkRow('E-Mail', betrieb.email!, Uri.parse('mailto:${betrieb.email!}')),
              if (betrieb.website != null)
                _LinkRow('Website', betrieb.website!, Uri.parse(
                  betrieb.website!.startsWith('http') ? betrieb.website! : 'https://${betrieb.website!}',
                )),
            ],
          ),

          // Details
          _SectionCard(
            title: 'Details',
            icon: Icons.info_outline,
            children: [
              if (betrieb.betriebNr != null)
                _InfoRow('Betrieb Nr.', betrieb.betriebNr!),
              _InfoRow('Status', betrieb.status),
              _InfoRow('Zapfsysteme', betrieb.zapfsysteme.isEmpty ? '–' : betrieb.zapfsysteme.join(', ')),
              _InfoRow('Mein Kunde', betrieb.istMeinKunde ? 'Ja' : 'Nein'),
              _InfoRow('Bergkunde', betrieb.istBergkunde ? 'Ja' : 'Nein'),
              _InfoRow('Saisonbetrieb', betrieb.istSaisonbetrieb ? 'Ja' : 'Nein'),
              _InfoRow('Rechnungsstellung', _rechnungsstellungLabel(betrieb.rechnungsstellung)),
            ],
          ),

          // Saison (nur bei Saisonbetrieb)
          if (betrieb.istSaisonbetrieb)
            _SectionCard(
              title: 'Saison',
              icon: Icons.calendar_month,
              children: [
                if (betrieb.winterSaisonAktiv && betrieb.winterStartDatum != null)
                  _InfoRow('Winter', '${_formatDate(betrieb.winterStartDatum!)} – ${betrieb.winterEndeDatum != null ? _formatDate(betrieb.winterEndeDatum!) : '?'}'),
                if (betrieb.sommerSaisonAktiv && betrieb.sommerStartDatum != null)
                  _InfoRow('Sommer', '${_formatDate(betrieb.sommerStartDatum!)} – ${betrieb.sommerEndeDatum != null ? _formatDate(betrieb.sommerEndeDatum!) : '?'}'),
              ],
            ),

          // Ruhetage & Ferien (für alle Betriebe)
          if (betrieb.ruhetage.isNotEmpty || betrieb.ferienStart != null ||
              betrieb.ferien2Start != null || betrieb.ferien3Start != null ||
              betrieb.keineBetriebsferien)
            _SectionCard(
              title: 'Ruhetage & Ferien',
              icon: Icons.event_busy,
              children: [
                if (betrieb.ruhetage.isNotEmpty)
                  _InfoRow('Ruhetage', betrieb.ruhetage.contains('keine')
                      ? 'Keine'
                      : betrieb.ruhetage.join(', ')),
                if (betrieb.keineBetriebsferien)
                  const _InfoRow('Betriebsferien', 'Keine'),
                if (!betrieb.keineBetriebsferien && betrieb.ferienStart != null)
                  _InfoRow('Ferien 1', '${_formatDate(betrieb.ferienStart!)} – ${betrieb.ferienEnde != null ? _formatDate(betrieb.ferienEnde!) : '?'}'),
                if (!betrieb.keineBetriebsferien && betrieb.ferien2Start != null)
                  _InfoRow('Ferien 2', '${_formatDate(betrieb.ferien2Start!)} – ${betrieb.ferien2Ende != null ? _formatDate(betrieb.ferien2Ende!) : '?'}'),
                if (!betrieb.keineBetriebsferien && betrieb.ferien3Start != null)
                  _InfoRow('Ferien 3', '${_formatDate(betrieb.ferien3Start!)} – ${betrieb.ferien3Ende != null ? _formatDate(betrieb.ferien3Ende!) : '?'}'),
              ],
            ),

          // Öffnungszeiten
          if (_hasOeffnungszeiten(betrieb))
            _SectionCard(
              title: 'Öffnungszeiten',
              icon: Icons.access_time,
              children: [
                if (betrieb.oeffnungMorgenVon != null || betrieb.oeffnungMorgenBis != null)
                  _InfoRow('Morgen', '${_formatTimeStr(betrieb.oeffnungMorgenVon)} – ${_formatTimeStr(betrieb.oeffnungMorgenBis)}'),
                if (betrieb.oeffnungNachmittagVon != null || betrieb.oeffnungNachmittagBis != null)
                  _InfoRow('Nachmittag', '${_formatTimeStr(betrieb.oeffnungNachmittagVon)} – ${_formatTimeStr(betrieb.oeffnungNachmittagBis)}'),
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

          // Kontaktpersonen
          if (betrieb.serverId != null)
            _KontakteSection(betrieb: betrieb),

          // Rechnungsadresse
          if (betrieb.serverId != null)
            _RechnungsadresseSection(betrieb: betrieb),

          // Anlagen
          if (betrieb.serverId != null)
            _AnlagenSection(betrieb: betrieb),

          // Störungen
          if (betrieb.serverId != null)
            _StoerungenSection(betrieb: betrieb),

          // Eigenaufträge
          if (betrieb.serverId != null)
            _EigenauftraegeSection(betrieb: betrieb),

          // Eröffnungsreinigungen
          if (betrieb.serverId != null)
            _EroeffnungsreinigungenSection(betrieb: betrieb),

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

  bool _hasOeffnungszeiten(BetriebLocal b) {
    return b.oeffnungMorgenVon != null ||
        b.oeffnungMorgenBis != null ||
        b.oeffnungNachmittagVon != null ||
        b.oeffnungNachmittagBis != null;
  }

  String _formatTimeStr(String? time) {
    if (time == null) return '–';
    // "HH:mm:ss" from Supabase → "HH:mm"
    return time.length > 5 ? time.substring(0, 5) : time;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _rechnungsstellungLabel(String value) {
    switch (value) {
      case 'rechnung_mail': return 'Per E-Mail';
      case 'rechnung_post': return 'Per Post';
      case 'rechnung_tresen': return 'Rechnung Tresen';
      case 'barzahlung': return 'Barzahlung';
      case 'jahresrechnung': return 'Jahresrechnung';
      case 'heineken': return 'Via Heineken';
      default: return value;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Betrieb löschen'),
        content: Text(
          '«${betrieb.name}» und alle zugehörigen Anlagen, Reinigungen, Störungen, Kontakte und Rechnungsadressen werden unwiderruflich gelöscht.',
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
        await BetriebRepository.delete(betrieb.routeId);
        ref.invalidate(betriebeStreamProvider);
        if (context.mounted) context.go('/betriebe');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Löschen nur mit Internetverbindung möglich')),
          );
        }
      }
    }
  }
}

class _KontakteSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _KontakteSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BetriebKontaktLocal>>(
      stream: BetriebKontaktRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final kontakte = snapshot.data ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Kontakte (${kontakte.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neuer Kontakt'),
                      onPressed: () => context.push(
                        '/betriebe/${betrieb.routeId}/kontakte/neu',
                      ),
                    ),
                  ],
                ),
                if (kontakte.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...kontakte.map((k) => _KontaktRow(
                        kontakt: k,
                        betriebRouteId: betrieb.routeId,
                      )),
                ],
                if (kontakte.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Kontaktpersonen erfasst',
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

class _KontaktRow extends StatelessWidget {
  final BetriebKontaktLocal kontakt;
  final String betriebRouteId;

  const _KontaktRow({required this.kontakt, required this.betriebRouteId});

  @override
  Widget build(BuildContext context) {
    final name = kontakt.nachname != null && kontakt.nachname!.isNotEmpty
        ? '${kontakt.vorname} ${kontakt.nachname}'
        : kontakt.vorname;

    return InkWell(
      onTap: () {
        final id = kontakt.serverId ?? kontakt.id.toString();
        context.push('/betriebe/$betriebRouteId/kontakte/$id/bearbeiten');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.aktiv.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                kontakt.istHauptkontakt ? Icons.star : Icons.person,
                size: 16,
                color: AppColors.aktiv,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      if (kontakt.istHauptkontakt) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.aktiv.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Haupt',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.aktiv,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    [
                      if (kontakt.funktion != null) kontakt.funktion!,
                      if (kontakt.telefon != null) kontakt.telefon!,
                    ].join(' · '),
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

class _RechnungsadresseSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _RechnungsadresseSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BetriebRechnungsadresseLocal>>(
      stream:
          BetriebRechnungsadresseRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final adressen = snapshot.data ?? [];
        final adresse = adressen.isNotEmpty ? adressen.first : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Rechnungsadresse',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: Icon(
                          adresse != null ? Icons.edit : Icons.add, size: 18),
                      label: Text(
                          adresse != null ? 'Bearbeiten' : 'Hinzufügen'),
                      onPressed: () => context.push(
                        '/betriebe/${betrieb.routeId}/rechnungsadresse',
                      ),
                    ),
                  ],
                ),
                if (adresse != null) ...[
                  const SizedBox(height: 8),
                  if (adresse.firma != null)
                    Text(
                      adresse.firma!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  Text(
                    [
                      if (adresse.vorname != null)
                        '${adresse.vorname} ${adresse.nachname}'
                      else
                        adresse.nachname,
                      '${adresse.strasse}${adresse.nr != null ? " ${adresse.nr}" : ""}',
                      '${adresse.plz} ${adresse.ort}',
                    ].join('\n'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (adresse.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      adresse.email!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
                if (adresse == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Keine Rechnungsadresse hinterlegt',
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

class _StoerungenSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _StoerungenSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoerungLocal>>(
      stream: StoerungRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final stoerungen = snapshot.data ?? [];
        final sorted = List<StoerungLocal>.from(stoerungen)
          ..sort((a, b) => b.datum.compareTo(a.datum));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Störungen (${stoerungen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (!SupabaseService.isGuest)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Neue Störung'),
                        onPressed: () => context.push(
                          '/stoerungen/neu?betriebId=${betrieb.serverId}',
                        ),
                      ),
                  ],
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...sorted.take(5).map((s) => _StoerungRow(stoerung: s)),
                  if (sorted.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${sorted.length - 5} weitere',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                if (stoerungen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Störungen erfasst',
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

class _StoerungRow extends StatelessWidget {
  final StoerungLocal stoerung;

  const _StoerungRow({required this.stoerung});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (stoerung.status) {
      'offen' => AppColors.warning,
      'behoben' => AppColors.success,
      'nicht_behebbar' => AppColors.inaktiv,
      _ => AppColors.textSecondary,
    };

    return InkWell(
      onTap: () => context.push('/stoerungen/${stoerung.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber, size: 16, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stoerung.stoerungsnummer,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    [
                      if (stoerung.referenzNr != null) 'HN-${stoerung.referenzNr}',
                      _formatDate(stoerung.datum),
                      stoerung.status,
                    ].join(' · '),
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

class _EigenauftraegeSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _EigenauftraegeSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EigenauftragLocal>>(
      stream: EigenauftragRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final eigenauftraege = snapshot.data ?? [];
        final sorted = List<EigenauftragLocal>.from(eigenauftraege)
          ..sort((a, b) => b.datum.compareTo(a.datum));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.build_circle_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Eigenaufträge (${eigenauftraege.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (!SupabaseService.isGuest)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Neuer Eigenauftrag'),
                        onPressed: () => context.push(
                          '/eigenauftraege/neu?betriebId=${betrieb.serverId}',
                        ),
                      ),
                  ],
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...sorted.take(5).map((e) => _EigenauftragRow(eigenauftrag: e)),
                  if (sorted.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${sorted.length - 5} weitere',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                if (eigenauftraege.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Eigenaufträge erfasst',
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

class _EigenauftragRow extends StatelessWidget {
  final EigenauftragLocal eigenauftrag;

  const _EigenauftragRow({required this.eigenauftrag});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (eigenauftrag.status) {
      'behoben' => AppColors.success,
      'nicht_behebbar' => AppColors.inaktiv,
      'nachbearbeitung_noetig' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    return InkWell(
      onTap: () => context.push('/eigenauftraege/${eigenauftrag.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.build_circle_outlined,
                  size: 16, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eigenauftrag.stoerungsnummer,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    [
                      _formatDate(eigenauftrag.datum),
                      if (eigenauftrag.pauschale != null)
                        '${eigenauftrag.pauschale!.toStringAsFixed(2)} CHF',
                      eigenauftrag.status,
                    ].join(' · '),
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

class _EroeffnungsreinigungenSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _EroeffnungsreinigungenSection({required this.betrieb});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EroeffnungsreinigungLocal>>(
      future: EroeffnungsreinigungRepository.getByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final sorted = List<EroeffnungsreinigungLocal>.from(items)
          ..sort((a, b) => b.datum.compareTo(a.datum));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cleaning_services_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Eröffnungsreinigungen',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    Text('${items.length}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...sorted.take(5).map((e) => InkWell(
                        onTap: () => context.push(
                            '/eroeffnungsreinigungen/${e.routeId}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                    Icons.cleaning_services_outlined,
                                    size: 16,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.stoerungsnummer,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      [
                                        _formatDate(e.datum),
                                        if (e.preis != null)
                                          '${e.preis!.toStringAsFixed(2)} CHF',
                                        if (e.istBergkunde) 'Bergkunde',
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      )),
                ],
                if (!SupabaseService.isGuest) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                          '/eroeffnungsreinigungen/neu?betriebId=${betrieb.serverId}'),
                      icon: const Icon(Icons.add, size: 18),
                      label:
                          const Text('Neue Eröffnungsreinigung'),
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

  Color get _statusColor {
    switch (anlage.status) {
      case 'aktiv':
        return AppColors.aktiv;
      case 'inaktiv':
        return AppColors.warning;
      case 'stillgelegt':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/anlagen/${anlage.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.precision_manufacturing,
                  size: 16, color: _statusColor),
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

class _LinkRow extends StatelessWidget {
  final String label;
  final String text;
  final Uri uri;

  const _LinkRow(this.label, this.text, this.uri);

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
            child: GestureDetector(
              onTap: () => launchUrl(uri),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
