import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_korrektur_service.dart';
import 'package:sbs_projer_app/data/repositories/bergkundenpauschale_repository.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';

class ReinigungDetailScreen extends ConsumerWidget {
  final String reinigungId;

  const ReinigungDetailScreen({super.key, required this.reinigungId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ReinigungLocal?>(
      future: ReinigungRepository.getById(reinigungId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final reinigung = snapshot.data;
        if (reinigung == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Reinigung nicht gefunden')),
          );
        }

        return _ReinigungDetailContent(reinigung: reinigung);
      },
    );
  }
}

class _ReinigungDetailContent extends ConsumerWidget {
  final ReinigungLocal reinigung;

  const _ReinigungDetailContent({required this.reinigung});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reinigung ${_formatDate(reinigung.datum)}'),
        actions: [
          if (!SupabaseService.isGuest) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Bearbeiten',
                onPressed: () =>
                    context.push('/reinigungen/${reinigung.routeId}/bearbeiten'),
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
          // Status & Info
          _StatusRow(reinigung: reinigung),
          const SizedBox(height: 16),

          // Betrieb & Anlage
          _BetriebAnlageCard(reinigung: reinigung),

          // Zeiterfassung
          _SectionCard(
            title: 'Zeiterfassung',
            icon: Icons.schedule,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _CompactInfo('Datum', _formatDate(reinigung.datum)),
                  ),
                  if (reinigung.uhrzeitStart != null)
                    Expanded(
                      flex: 3,
                      child: _CompactInfo(
                          'Start', _kurzZeit(reinigung.uhrzeitStart!)),
                    ),
                  if (reinigung.uhrzeitEnde != null)
                    Expanded(
                      flex: 3,
                      child: _CompactInfo(
                          'Ende', _kurzZeit(reinigung.uhrzeitEnde!)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (reinigung.uhrzeitStart != null &&
                  reinigung.uhrzeitEnde != null)
                Builder(builder: (_) {
                  final dauer = _berechneDauer(
                      reinigung.uhrzeitStart!, reinigung.uhrzeitEnde!);
                  if (dauer != null) {
                    return _InfoRow('Dauer', '$dauer Min.');
                  }
                  return const SizedBox.shrink();
                }),
              _InfoRow('Service-Art',
                  _serviceArtLabel(reinigung.serviceArt ?? 'standardservice')),
            ],
          ),

          // Protokoll-Foto
          if (reinigung.protokollFotoPfad != null)
            _ProtokollFotoCard(fotoPfad: reinigung.protokollFotoPfad!),

          // Alte Checkliste (Rückwärtskompatibilität für bestehende Reinigungen)
          if (_hasChecklisteData(reinigung))
            _ChecklisteCard(reinigung: reinigung),

          // Preis
          if (reinigung.preisNetto != null || reinigung.preisBrutto != null)
            _SectionCard(
              title: 'Preis',
              icon: Icons.payments,
              children: [
                if (reinigung.anzahlHaehneEigen > 0)
                  _InfoRow('Hähne Eigen', '${reinigung.anzahlHaehneEigen}'),
                if (reinigung.anzahlHaehneOrion > 0)
                  _InfoRow('Hähne Orion', '${reinigung.anzahlHaehneOrion}'),
                if (reinigung.anzahlHaehneFremd > 0)
                  _InfoRow('Hähne Fremd', '${reinigung.anzahlHaehneFremd}'),
                if (reinigung.anzahlHaehneWein > 0)
                  _InfoRow('Hähne Wein', '${reinigung.anzahlHaehneWein}'),
                if (reinigung.anzahlHaehneAndererStandort > 0)
                  _InfoRow('Anderer Standort',
                      '${reinigung.anzahlHaehneAndererStandort}'),
                if (reinigung.istBergkunde)
                  _InfoRow('Bergkunde', 'Ja (Heineken)'),
                const Divider(),
                if (reinigung.preisGrundtarif != null)
                  _InfoRow('Grundtarif',
                      '${reinigung.preisGrundtarif!.toStringAsFixed(2)} CHF'),
                if (reinigung.preisZusatzHaehne != null &&
                    reinigung.preisZusatzHaehne! > 0)
                  _InfoRow('Zusatz Hähne',
                      '${reinigung.preisZusatzHaehne!.toStringAsFixed(2)} CHF'),
                if (reinigung.preisNetto != null) ...[
                  _InfoRow('Netto',
                      '${reinigung.preisNetto!.toStringAsFixed(2)} CHF'),
                  if (reinigung.preisBrutto != null) ...[
                    Builder(builder: (_) {
                      final brutto = _roundTo5Rappen(reinigung.preisBrutto!);
                      final mwst = brutto - reinigung.preisNetto!;
                      return _InfoRow(
                        'MwSt (${reinigung.mwstSatz?.toStringAsFixed(1) ?? '8.1'}%)',
                        '${mwst.toStringAsFixed(2)} CHF',
                      );
                    }),
                  ],
                ],
                if (reinigung.preisBrutto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 130,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${_roundTo5Rappen(reinigung.preisBrutto!).toStringAsFixed(2)} CHF',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          // Alte Unterschriften (Rückwärtskompatibilität)
          if (reinigung.unterschriftTechniker != null ||
              reinigung.unterschriftKunde != null)
            _SectionCard(
              title: 'Unterschriften (alt)',
              icon: Icons.draw,
              children: [
                if (reinigung.unterschriftTechniker != null) ...[
                  const Text('Techniker',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        base64Decode(reinigung.unterschriftTechniker!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (reinigung.unterschriftKunde != null) ...[
                  Text(
                    reinigung.unterschriftKundeName != null
                        ? 'Kunde: ${reinigung.unterschriftKundeName}'
                        : 'Kunde',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        base64Decode(reinigung.unterschriftKunde!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ],
            ),

          // Notizen
          if (reinigung.notizen != null)
            _SectionCard(
              title: 'Notizen',
              icon: Icons.note,
              children: [_InfoRow('', reinigung.notizen!)],
            ),

          // Sync-Info
          if (!reinigung.isSynced)
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

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Prüft ob die Reinigung alte Checkliste-Daten hat (vor der Umstellung).
  static bool _hasChecklisteData(ReinigungLocal r) {
    return r.begleitkuehlungKontrolliert ||
        r.installationAllgemeinKontrolliert ||
        r.aligalAnschluesseKontrolliert ||
        r.durchlaufkuehlerAusgeblasen ||
        r.wasserstandKontrolliert ||
        r.wasserGewechselt ||
        r.leitungWasserVorgespuelt ||
        r.leitungsreinigungReinigungsmittel ||
        r.foerderdruckKontrolliert ||
        r.zapfhahnZerlegtGereinigt ||
        r.zapfkopfZerlegtGereinigt ||
        r.servicekarteAusgefuellt;
  }

  static double _roundTo5Rappen(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  static String _serviceArtLabel(String serviceArt) {
    return switch (serviceArt) {
      'endreinigung' => 'Endreinigung',
      'eroeffnungsservice' => 'Eröffnungsservice',
      _ => 'Standardservice',
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _kurzZeit(String zeit) {
    if (zeit.length >= 5) return zeit.substring(0, 5);
    return zeit;
  }

  static int? _berechneDauer(String start, String ende) {
    try {
      final sParts = start.split(':');
      final eParts = ende.split(':');
      if (sParts.length < 2 || eParts.length < 2) return null;
      final startMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final endeMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      final diff = endeMin - startMin;
      return diff > 0 ? diff : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reinigung löschen'),
        content: Text(
          'Reinigung vom ${_formatDate(reinigung.datum)} wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
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
        // Buchhaltung aufräumen (Rechnung + Buchungen) falls vorhanden
        if (reinigung.serverId != null &&
            reinigung.status == 'abgeschlossen') {
          await ReinigungKorrekturService.cleanupBuchhaltung(
              reinigung.serverId!);
        }

        // Bergkundenpauschale löschen falls vorhanden
        if (reinigung.serverId != null && reinigung.istBergkunde) {
          await BergkundenpauschaleRepository.deleteByReinigungId(
              reinigung.serverId!);
          ref.invalidate(bergkundenpauschaleStreamProvider);
        }

        await ReinigungRepository.delete(reinigung.routeId);
        ref.invalidate(reinigungenStreamProvider);
        ref.invalidate(anlagenStreamProvider);
        ref.invalidate(rechnungenStreamProvider);
        ref.invalidate(buchungenStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
          );
        }
      }
    }
  }
}

class _ProtokollFotoCard extends StatelessWidget {
  final String fotoPfad;

  const _ProtokollFotoCard({required this.fotoPfad});

  @override
  Widget build(BuildContext context) {
    final isPdf = ProtokollFotoStorage.isPdf(fotoPfad);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isPdf ? Icons.picture_as_pdf : Icons.photo_camera,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  isPdf ? 'Protokoll (PDF)' : 'Protokoll-Foto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (!isPdf) ...[
                  const Spacer(),
                  const Text('Tippen zum Vergrössern',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.zoom_in,
                      size: 16, color: AppColors.textSecondary),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (isPdf)
              _buildPdfPreview()
            else
              _buildImagePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreview() {
    return FutureBuilder<String>(
      future: ProtokollFotoStorage.getSignedUrl(fotoPfad),
      builder: (context, snapshot) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf,
                    size: 40, color: AppColors.error),
                const SizedBox(height: 8),
                if (snapshot.hasData)
                  FilledButton.icon(
                    onPressed: () {
                      launchUrl(Uri.parse(snapshot.data!),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('PDF öffnen'),
                  )
                else if (snapshot.hasError)
                  const Text('PDF nicht verfügbar',
                      style: TextStyle(color: AppColors.textSecondary))
                else
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return FutureBuilder<String>(
      future: ProtokollFotoStorage.getSignedUrl(fotoPfad),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () => _showFullscreenFoto(context, snapshot.data!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                snapshot.data!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Foto konnte nicht geladen werden',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('Foto nicht verfügbar',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  void _showFullscreenFoto(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Protokoll'),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text('Foto konnte nicht geladen werden',
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetriebAnlageCard extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _BetriebAnlageCard({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BetriebAnlagenData>(
      future: _loadData(),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              if (data?.betriebName != null)
                ListTile(
                  leading:
                      const Icon(Icons.store, color: AppColors.primary),
                  title: Text(data!.betriebName!),
                  subtitle: const Text('Betrieb'),
                  dense: true,
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    final b = await BetriebRepository.getByServerId(
                        reinigung.betriebId);
                    if (b != null && context.mounted) {
                      context.push('/betriebe/${b.routeId}');
                    }
                  },
                ),
              if (data != null)
                ...data.anlagen.map((anlage) => ListTile(
                  leading: const Icon(Icons.precision_manufacturing,
                      color: AppColors.info),
                  title: Text(anlage.label),
                  subtitle: const Text('Anlage'),
                  dense: true,
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    final a = await AnlageRepository.getByServerId(anlage.serverId);
                    if (a != null && context.mounted) {
                      context.push('/anlagen/${a.routeId}');
                    }
                  },
                )),
            ],
          ),
        );
      },
    );
  }

  Future<_BetriebAnlagenData> _loadData() async {
    final betrieb = await BetriebRepository.getByServerId(reinigung.betriebId);
    final anlagen = <_AnlageInfo>[];

    // anlageIdsJson hat Priorität (Multi-Anlagen)
    if (reinigung.anlageIdsJson != null) {
      final ids = (jsonDecode(reinigung.anlageIdsJson!) as List)
          .map((e) => e.toString()).toList();
      for (final id in ids) {
        final a = await AnlageRepository.getByServerId(id);
        if (a != null) {
          anlagen.add(_AnlageInfo(
            serverId: id,
            label: a.bezeichnung ?? a.typAnlage,
          ));
        }
      }
    } else if (reinigung.anlageId.isNotEmpty) {
      // Fallback: einzelne anlageId
      final a = await AnlageRepository.getByServerId(reinigung.anlageId);
      if (a != null) {
        anlagen.add(_AnlageInfo(
          serverId: reinigung.anlageId,
          label: a.bezeichnung ?? a.typAnlage,
        ));
      }
    }

    return _BetriebAnlagenData(betriebName: betrieb?.name, anlagen: anlagen);
  }
}

class _BetriebAnlagenData {
  final String? betriebName;
  final List<_AnlageInfo> anlagen;
  _BetriebAnlagenData({this.betriebName, this.anlagen = const []});
}

class _AnlageInfo {
  final String serverId;
  final String label;
  _AnlageInfo({required this.serverId, required this.label});
}

/// Rückwärtskompatibilität: Zeigt Checkliste für alte Reinigungen (vor Foto-Umstellung).
class _ChecklisteCard extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _ChecklisteCard({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    final notizen = reinigung.checklisteNotizenJson != null
        ? Map<String, String>.from(
            jsonDecode(reinigung.checklisteNotizenJson!))
        : <String, String>{};

    final items = [
      ('Begleitkühlung kontrolliert', reinigung.begleitkuehlungKontrolliert,
          'begleitkuehlung_kontrolliert'),
      ('Installation allgemein kontrolliert',
          reinigung.installationAllgemeinKontrolliert,
          'installation_allgemein_kontrolliert'),
      ('Aligal-Anschlüsse kontrolliert',
          reinigung.aligalAnschluesseKontrolliert,
          'aligal_anschluesse_kontrolliert'),
      ('Durchlaufkühler ausgeblasen', reinigung.durchlaufkuehlerAusgeblasen,
          'durchlaufkuehler_ausgeblasen'),
      ('Wasserstand kontrolliert', reinigung.wasserstandKontrolliert,
          'wasserstand_kontrolliert'),
      ('Wasser gewechselt', reinigung.wasserGewechselt,
          'wasser_gewechselt'),
      ('Leitung mit Wasser vorgespült', reinigung.leitungWasserVorgespuelt,
          'leitung_wasser_vorgespuelt'),
      ('Leitungsreinigung mit Reinigungsmittel',
          reinigung.leitungsreinigungReinigungsmittel,
          'leitungsreinigung_reinigungsmittel'),
      ('Förderdruck kontrolliert', reinigung.foerderdruckKontrolliert,
          'foerderdruck_kontrolliert'),
      ('Zapfhahn zerlegt & gereinigt', reinigung.zapfhahnZerlegtGereinigt,
          'zapfhahn_zerlegt_gereinigt'),
      ('Zapfkopf zerlegt & gereinigt', reinigung.zapfkopfZerlegtGereinigt,
          'zapfkopf_zerlegt_gereinigt'),
      ('Servicekarte ausgefüllt', reinigung.servicekarteAusgefuellt,
          'servicekarte_ausgefuellt'),
    ];

    final anlagenItems = [
      ('Durchlaufkühler', reinigung.hatDurchlaufkuehler,
          'hat_durchlaufkuehler'),
      ('Buffetanstich', reinigung.hatBuffetanstich, 'hat_buffetanstich'),
      ('Kühlkeller', reinigung.hatKuehlkeller, 'hat_kuehlkeller'),
      ('Fasskühler', reinigung.hatFasskuehler, 'hat_fasskuehler'),
    ];

    final checkedCount = items.where((i) => i.$2).length +
        anlagenItems.where((i) => i.$2).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Checkliste ($checkedCount/${items.length + anlagenItems.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                _ProgressIndicator(
                    value: checkedCount /
                        (items.length + anlagenItems.length)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _CheckItem(
                  label: item.$1,
                  checked: item.$2,
                  note: notizen[item.$3],
                )),
            if (anlagenItems.any((i) => i.$2)) ...[
              const Divider(),
              const Text(
                'Anlagen-Checks',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...anlagenItems
                  .where((i) => i.$2)
                  .map((item) => _CheckItem(
                        label: item.$1,
                        checked: item.$2,
                        note: notizen[item.$3],
                      )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final double value;

  const _ProgressIndicator({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 1.0
        ? AppColors.success
        : value >= 0.5
            ? AppColors.warning
            : AppColors.inaktiv;

    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: 3,
        backgroundColor: color.withAlpha(25),
        color: color,
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool checked;
  final String? note;

  const _CheckItem(
      {required this.label, required this.checked, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                checked ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: checked ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: checked ? null : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (note != null && note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2, bottom: 4),
              child: Text(
                note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _StatusRow({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: reinigung.status,
          color: _statusColor(reinigung.status),
          icon: _statusIcon(reinigung.status),
        ),
        if (reinigung.istKulanz)
          const _StatusChip(
            label: 'Kulanz',
            color: AppColors.warning,
            icon: Icons.volunteer_activism,
          ),
        if (reinigung.istHeinekenMonteur)
          const _StatusChip(
            label: 'Heineken-Monteur',
            color: AppColors.info,
            icon: Icons.engineering,
          ),
        if (reinigung.istBergkunde)
          const _StatusChip(
            label: 'Bergkunde',
            color: AppColors.info,
            icon: Icons.terrain,
          ),
        if (reinigung.wasserKuehlerGewechselt)
          const _StatusChip(
            label: 'Wasser gewechselt',
            color: AppColors.info,
            icon: Icons.water_drop,
          ),
        if (reinigung.protokollFotoPfad != null)
          const _StatusChip(
            label: 'Protokoll',
            color: AppColors.success,
            icon: Icons.description,
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'offen':
        return AppColors.warning;
      case 'abgeschlossen':
        return AppColors.success;
      case 'abgebrochen':
        return AppColors.inaktiv;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'offen':
        return Icons.hourglass_top;
      case 'abgeschlossen':
        return Icons.check_circle;
      case 'abgebrochen':
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip(
      {required this.label, required this.color, this.icon});

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

class _CompactInfo extends StatelessWidget {
  final String label;
  final String value;

  const _CompactInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
