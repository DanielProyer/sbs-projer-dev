import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
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
          // Zeiterfassung
          _ZeiterfassungCard(reinigung: reinigung),

          // Preis + Rechnungsart
          _PreisCard(reinigung: reinigung),

          // Protokoll (mit Voransicht)
          if (reinigung.protokollFotoPfad != null)
            _ProtokollFotoCard(fotoPfad: reinigung.protokollFotoPfad!),

          // Alte Checkliste (Rückwärtskompatibilität für bestehende Reinigungen)
          if (_hasChecklisteData(reinigung))
            _ChecklisteCard(reinigung: reinigung),

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

String _fmtDatum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Zeiterfassung: Datum, Start/Ende, Dauer-Badge + Service-Art.
class _ZeiterfassungCard extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _ZeiterfassungCard({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    final start = reinigung.uhrzeitStart;
    final ende = reinigung.uhrzeitEnde;
    final dauer = (start != null && ende != null)
        ? _ReinigungDetailContent._berechneDauer(start, ende)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Zeiterfassung',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _ReinigungDetailContent._serviceArtLabel(
                        reinigung.serviceArt ?? 'standardservice'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _CompactInfo('Datum', _fmtDatum(reinigung.datum))),
                if (start != null)
                  Expanded(
                      child: _CompactInfo(
                          'Start', _ReinigungDetailContent._kurzZeit(start))),
                if (ende != null)
                  Expanded(
                      child: _CompactInfo(
                          'Ende', _ReinigungDetailContent._kurzZeit(ende))),
                if (dauer != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Text('$dauer',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const Text('Minuten',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preis mit Rechnungsart und prominentem Total.
class _PreisCard extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _PreisCard({required this.reinigung});

  String _rechnungsart() {
    if (reinigung.istKulanz) return 'Kulanz (keine Verrechnung)';
    if (reinigung.istHeinekenMonteur || reinigung.istBergkunde) {
      return 'Heineken-Monatsrechnung';
    }
    return 'Kundenrechnung';
  }

  Widget _preisZeile(String label, double betrag) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text('${betrag.toStringAsFixed(2)} CHF',
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasPreis =
        reinigung.preisNetto != null || reinigung.preisBrutto != null;
    if (!hasPreis && !reinigung.istKulanz) return const SizedBox.shrink();

    final kulanz = reinigung.istKulanz;
    final artColor = kulanz
        ? AppColors.warning
        : (reinigung.istHeinekenMonteur || reinigung.istBergkunde)
            ? AppColors.info
            : AppColors.primary;

    final brutto = reinigung.preisBrutto != null
        ? _ReinigungDetailContent._roundTo5Rappen(reinigung.preisBrutto!)
        : null;
    final mwst = (brutto != null && reinigung.preisNetto != null)
        ? brutto - reinigung.preisNetto!
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Preis',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: artColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: artColor.withAlpha(60)),
                  ),
                  child: Text(_rechnungsart(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: artColor)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (reinigung.preisGrundtarif != null)
              _preisZeile('Grundtarif', reinigung.preisGrundtarif!),
            if (reinigung.preisZusatzHaehne != null &&
                reinigung.preisZusatzHaehne! > 0)
              _preisZeile('Zusatz Hähne', reinigung.preisZusatzHaehne!),
            if (reinigung.preisNetto != null)
              _preisZeile('Netto', reinigung.preisNetto!),
            if (mwst != null)
              _preisZeile(
                  'MwSt (${reinigung.mwstSatz?.toStringAsFixed(1) ?? '8.1'}%)',
                  mwst),
            if (brutto != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (kulanz ? AppColors.warning : AppColors.primary)
                      .withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kulanz ? 'Total (Kulanz)' : 'Total',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${brutto.toStringAsFixed(2)} CHF',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color:
                              kulanz ? AppColors.warning : AppColors.primary,
                          decoration:
                              kulanz ? TextDecoration.lineThrough : null,
                        )),
                  ],
                ),
              ),
            ],
            if (kulanz && brutto != null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Kulanz — wird dem Kunden nicht verrechnet.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ),
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
