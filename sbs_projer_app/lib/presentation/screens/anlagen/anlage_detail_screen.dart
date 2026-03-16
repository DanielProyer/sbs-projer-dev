import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/data/models/anlage_foto.dart';
import 'package:sbs_projer_app/data/repositories/anlage_foto_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';

class AnlageDetailScreen extends ConsumerWidget {
  final String anlageId;

  const AnlageDetailScreen({super.key, required this.anlageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AnlageLocal?>(
      future: AnlageRepository.getById(anlageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final anlage = snapshot.data;
        if (anlage == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Anlage nicht gefunden')),
          );
        }

        return _AnlageDetailContent(anlage: anlage);
      },
    );
  }
}

class _AnlageDetailContent extends ConsumerWidget {
  final AnlageLocal anlage;

  const _AnlageDetailContent({required this.anlage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(anlage.bezeichnung ?? anlage.typAnlage),
        actions: [
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () => context.push('/anlagen/${anlage.routeId}/bearbeiten'),
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
          _StatusRow(anlage: anlage),
          const SizedBox(height: 16),

          // Betrieb-Info
          _BetriebCard(betriebId: anlage.betriebId),

          // Fotos
          if (anlage.serverId != null)
            _FotosSection(anlageId: anlage.serverId!),

          // Grunddaten
          _SectionCard(
            title: 'Grunddaten',
            icon: Icons.precision_manufacturing,
            children: [
              _InfoRow('Typ', anlage.typAnlage),
              if (anlage.bezeichnung != null)
                _InfoRow('Bezeichnung', anlage.bezeichnung!),
              if (anlage.seriennummer != null)
                _InfoRow('Seriennummer', anlage.seriennummer!),
              if (anlage.typSaeule != null)
                _InfoRow('Säulen-Typ', anlage.typSaeule!),
              _InfoRow('Anzahl Hähne', '${anlage.anzahlHaehne}'),
            ],
          ),

          // Kühlung & Gas
          _SectionCard(
            title: 'Kühlung & Gas',
            icon: Icons.ac_unit,
            children: [
              _InfoRow('Vorkühler', _vorkuehlerLabel(anlage.vorkuehler)),
              if (anlage.durchlaufkuehler != null)
                _InfoRow('Durchlaufkühler', anlage.durchlaufkuehler!),
              _InfoRow('Backpython', anlage.backpython ? 'Ja' : 'Nein'),
              _InfoRow('Booster', anlage.booster ? 'Ja' : 'Nein'),
              if (anlage.gasTyp1 != null) _InfoRow('Gas Typ 1', anlage.gasTyp1!),
              if (anlage.gasTyp2 != null) _InfoRow('Gas Typ 2', anlage.gasTyp2!),
              if (anlage.hauptdruckBar != null)
                _InfoRow('Hauptdruck', '${anlage.hauptdruckBar} bar'),
              _InfoRow('Niederdruck', anlage.hatNiederdruck ? 'Ja' : 'Nein'),
            ],
          ),

          // Servicezeiten
          if (_hasServicezeiten)
            _SectionCard(
              title: 'Servicezeiten',
              icon: Icons.schedule,
              children: [
                if (anlage.servicezeitMorgenAb != null)
                  _InfoRow('Morgen',
                      '${anlage.servicezeitMorgenAb} - ${anlage.servicezeitMorgenBis ?? '?'}'),
                if (anlage.servicezeitNachmittagAb != null)
                  _InfoRow('Nachmittag',
                      '${anlage.servicezeitNachmittagAb} - ${anlage.servicezeitNachmittagBis ?? '?'}'),
              ],
            ),

          // Reinigung
          _SectionCard(
            title: 'Reinigung',
            icon: Icons.cleaning_services,
            children: [
              _InfoRow('Rhythmus', anlage.reinigungRhythmus),
              if (anlage.letzteReinigung != null)
                _InfoRow('Letzte Reinigung', _formatDate(anlage.letzteReinigung!)),
              if (anlage.naechsteReinigung != null)
                _InfoRow('Nächste Reinigung', _formatDate(anlage.naechsteReinigung!)),
              if (anlage.letzterWasserwechsel != null)
                _InfoRow('Letzter Wasserwechsel',
                    _formatDate(anlage.letzterWasserwechsel!)),
            ],
          ),

          // Bierleitungen
          if (anlage.serverId != null)
            _BierleitungenSection(anlage: anlage),

          // Reinigungen
          if (anlage.serverId != null)
            _ReinigungenSection(anlage: anlage),

          // Störungen
          if (anlage.serverId != null)
            _StoerungenSection(anlage: anlage),

          // Notizen
          if (anlage.notizen != null)
            _SectionCard(
              title: 'Notizen',
              icon: Icons.note,
              children: [_InfoRow('', anlage.notizen!)],
            ),

          // Sync-Info
          if (!anlage.isSynced)
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

  bool get _hasServicezeiten =>
      anlage.servicezeitMorgenAb != null ||
      anlage.servicezeitNachmittagAb != null;

  String _vorkuehlerLabel(String value) {
    if (value == 'keiner') return 'Keiner';
    return value; // DB-Werte sind bereits lesbar (Fasskühler, Kühlzelle, Buffet)
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anlage löschen'),
        content: Text(
          '${anlage.bezeichnung ?? anlage.typAnlage} und alle zugehörigen Reinigungen, Störungen und Bierleitungen werden unwiderruflich gelöscht.',
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
        await AnlageRepository.delete(anlage.routeId);
        ref.invalidate(anlagenStreamProvider);
        if (context.mounted) context.pop();
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

class _BetriebCard extends StatelessWidget {
  final String betriebId;

  const _BetriebCard({required this.betriebId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getBetriebName(),
      builder: (context, snapshot) {
        final name = snapshot.data;
        if (name == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.store, color: AppColors.primary),
            title: Text(name),
            subtitle: const Text('Betrieb'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              final betrieb = await BetriebRepository.getByServerId(betriebId);
              if (betrieb != null && context.mounted) {
                context.push('/betriebe/${betrieb.routeId}');
              }
            },
          ),
        );
      },
    );
  }

  Future<String?> _getBetriebName() async {
    final betrieb = await BetriebRepository.getByServerId(betriebId);
    return betrieb?.name;
  }
}

class _FotosSection extends StatefulWidget {
  final String anlageId;

  const _FotosSection({required this.anlageId});

  @override
  State<_FotosSection> createState() => _FotosSectionState();
}

class _FotosSectionState extends State<_FotosSection> {
  List<AnlageFoto>? _fotos;
  Map<int, String> _signedUrls = {};
  bool _isLoading = true;
  int? _uploadingSlot;

  @override
  void initState() {
    super.initState();
    _loadFotos();
  }

  Future<void> _loadFotos() async {
    try {
      final fotos = await AnlageFotoRepository.getByAnlage(widget.anlageId);
      final urls = await AnlageFotoRepository.getSignedUrls(fotos);
      if (mounted) {
        setState(() {
          _fotos = fotos;
          _signedUrls = urls;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUpload(int fotoNummer) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (xFile == null) return;

      setState(() => _uploadingSlot = fotoNummer);

      final bytes = await xFile.readAsBytes();
      await AnlageFotoRepository.upload(widget.anlageId, fotoNummer, bytes, null);
      await _loadFotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSlot = null);
    }
  }

  Future<void> _deleteFoto(int fotoNummer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foto löschen'),
        content: Text('Foto $fotoNummer wirklich löschen?'),
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

    if (confirmed != true) return;

    try {
      await AnlageFotoRepository.delete(widget.anlageId, fotoNummer);
      await _loadFotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
        );
      }
    }
  }

  void _showFullImage(String url, int fotoNummer) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Foto $fotoNummer'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image, size: 48, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotoCount = _fotos?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Fotos ($fotoCount/4)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(4, (i) => _buildSlot(i + 1)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(int fotoNummer) {
    final url = _signedUrls[fotoNummer];
    final isUploading = _uploadingSlot == fotoNummer;

    if (isUploading) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withAlpha(100)),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (url != null) {
      // Foto vorhanden
      return GestureDetector(
        onTap: () => _showFullImage(url, fotoNummer),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => const Icon(
                    Icons.broken_image,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => _deleteFoto(fotoNummer),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Leerer Slot
    return GestureDetector(
      onTap: () => _pickAndUpload(fotoNummer),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 24, color: AppColors.textSecondary),
            SizedBox(height: 4),
            Text(
              'Hinzufügen',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReinigungenSection extends StatelessWidget {
  final AnlageLocal anlage;

  const _ReinigungenSection({required this.anlage});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReinigungLocal>>(
      stream: ReinigungRepository.watchByAnlage(anlage.serverId!),
      builder: (context, snapshot) {
        final reinigungen = snapshot.data ?? [];
        // Sortieren: neueste zuerst, max 5 anzeigen
        reinigungen.sort((a, b) => b.datum.compareTo(a.datum));
        final display = reinigungen.take(5).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cleaning_services,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Reinigungen (${reinigungen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Reinigung'),
                      onPressed: () => context.push(
                        '/reinigungen/neu?anlageId=${anlage.serverId}&betriebId=${anlage.betriebId}',
                      ),
                    ),
                  ],
                ),
                if (display.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...display.map((r) => _ReinigungRow(reinigung: r)),
                  if (reinigungen.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${reinigungen.length - 5} weitere',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                if (display.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Reinigungen erfasst',
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

class _ReinigungRow extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _ReinigungRow({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/reinigungen/${reinigung.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              reinigung.status == 'abgeschlossen'
                  ? Icons.check_circle
                  : Icons.hourglass_top,
              size: 18,
              color: reinigung.status == 'abgeschlossen'
                  ? AppColors.success
                  : AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${reinigung.datum.day.toString().padLeft(2, '0')}.${reinigung.datum.month.toString().padLeft(2, '0')}.${reinigung.datum.year}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              reinigung.status,
              style: TextStyle(
                fontSize: 12,
                color: reinigung.status == 'abgeschlossen'
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StoerungenSection extends StatelessWidget {
  final AnlageLocal anlage;

  const _StoerungenSection({required this.anlage});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoerungLocal>>(
      stream: StoerungRepository.watchByAnlage(anlage.serverId!),
      builder: (context, snapshot) {
        final stoerungen = snapshot.data ?? [];
        // Sortieren: neueste zuerst, max 5 anzeigen
        stoerungen.sort((a, b) => b.datum.compareTo(a.datum));
        final display = stoerungen.take(5).toList();

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
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Störung'),
                      onPressed: () => context.push(
                        '/stoerungen/neu?anlageId=${anlage.serverId}&betriebId=${anlage.betriebId}',
                      ),
                    ),
                  ],
                ),
                if (display.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...display.map((s) => _StoerungRow(stoerung: s)),
                  if (stoerungen.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${stoerungen.length - 5} weitere',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                if (display.isEmpty) ...[
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/stoerungen/${stoerung.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              stoerung.status == 'abgeschlossen'
                  ? Icons.check_circle
                  : Icons.warning_amber,
              size: 18,
              color: stoerung.status == 'abgeschlossen'
                  ? AppColors.success
                  : AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stoerung.stoerungsnummer,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${stoerung.datum.day.toString().padLeft(2, '0')}.${stoerung.datum.month.toString().padLeft(2, '0')}.${stoerung.datum.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              stoerung.status,
              style: TextStyle(
                fontSize: 12,
                color: stoerung.status == 'abgeschlossen'
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _BierleitungenSection extends StatefulWidget {
  final AnlageLocal anlage;

  const _BierleitungenSection({required this.anlage});

  @override
  State<_BierleitungenSection> createState() => _BierleitungenSectionState();
}

class _BierleitungenSectionState extends State<_BierleitungenSection> {
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BierleitungLocal>>(
      key: ValueKey(_refreshKey),
      stream: BierleitungRepository.watchByAnlage(widget.anlage.serverId!),
      builder: (context, snapshot) {
        final leitungen = snapshot.data ?? []
          ..sort((a, b) => a.leitungsNummer.compareTo(b.leitungsNummer));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_drink,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Bierleitungen (${leitungen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (leitungen.length < 4)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Neue Leitung'),
                        onPressed: () => context.push(
                          '/anlagen/${widget.anlage.routeId}/bierleitungen/neu',
                        ),
                      ),
                  ],
                ),
                if (leitungen.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...leitungen.map((l) => _BierleitungRow(
                        leitung: l,
                        anlageRouteId: widget.anlage.routeId,
                        onDeleted: _refresh,
                      )),
                ],
                if (leitungen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Bierleitungen erfasst',
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

class _BierleitungRow extends StatelessWidget {
  final BierleitungLocal leitung;
  final String anlageRouteId;
  final VoidCallback? onDeleted;

  const _BierleitungRow({
    required this.leitung,
    required this.anlageRouteId,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/anlagen/$anlageRouteId/bierleitungen/${leitung.routeId}/bearbeiten',
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${leitung.leitungsNummer}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.info,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leitung.biersorte ?? 'Keine Biersorte',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (leitung.hahnTyp != null || leitung.niederdruckBar != null)
                    Text(
                      [
                        if (leitung.hahnTyp != null) leitung.hahnTyp!,
                        if (leitung.niederdruckBar != null)
                          '${leitung.niederdruckBar} bar',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (leitung.hatFobStop)
              const Tooltip(
                message: 'FOB-Stop',
                child: Icon(Icons.stop_circle_outlined,
                    size: 16, color: AppColors.info),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.textSecondary,
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bierleitung löschen'),
        content: Text(
          'Leitung ${leitung.leitungsNummer}${leitung.biersorte != null ? ' (${leitung.biersorte})' : ''} wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await BierleitungRepository.delete(leitung.routeId);
      onDeleted?.call();
    }
  }
}

class _StatusRow extends StatelessWidget {
  final AnlageLocal anlage;

  const _StatusRow({required this.anlage});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: anlage.status,
          color: anlage.status == 'aktiv' ? AppColors.aktiv : AppColors.inaktiv,
        ),
        _StatusChip(
          label: anlage.typAnlage,
          color: AppColors.info,
          icon: Icons.precision_manufacturing,
        ),
        _StatusChip(
          label: '${anlage.anzahlHaehne} Hähne',
          color: AppColors.primary,
          icon: Icons.local_drink,
        ),
      ],
    );
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
