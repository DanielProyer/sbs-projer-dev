import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anlage_pdf_util.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/anlage_pdf_service.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/data/models/anlage_foto.dart';
import 'package:sbs_projer_app/data/repositories/anlage_foto_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_steckbrief_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb/einsaetze_akte_karte.dart';

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Steckbrief',
            onSelected: (v) {
              if (v == 'oeffnen') _steckbriefOeffnen(context, anlage);
              if (v == 'rsl') _steckbriefAnRsl(context, anlage);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'oeffnen', child: Text('Öffnen')),
              PopupMenuItem(value: 'rsl', child: Text('Mail RSL')),
            ],
          ),
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () =>
                  context.push('/anlagen/${anlage.routeId}/bearbeiten'),
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
          DetailKarte(
            titel: 'Grunddaten',
            icon: Icons.precision_manufacturing,
            kinder: [
              InfoZeile('Typ', anlage.typAnlage),
              if (anlage.bezeichnung != null)
                InfoZeile('Bezeichnung', anlage.bezeichnung!),
              if (anlage.seriennummer != null)
                InfoZeile('Seriennummer', anlage.seriennummer!),
              if (anlage.typSaeule != null)
                InfoZeile('Säulen-Typ', anlage.typSaeule!),
              InfoZeile('Anzahl Hähne', '${anlage.anzahlHaehne}'),
            ],
          ),

          // Kühlung & Gas
          DetailKarte(
            titel: 'Kühlung & Gas',
            icon: Icons.ac_unit,
            kinder: [
              InfoZeile('Vorkühler', _vorkuehlerLabel(anlage.vorkuehler)),
              if (anlage.durchlaufkuehler != null)
                InfoZeile('Durchlaufkühler', anlage.durchlaufkuehler!),
              InfoZeile('Backpython', anlage.backpython ? 'Ja' : 'Nein'),
              InfoZeile('Booster', anlage.booster ? 'Ja' : 'Nein'),
              InfoZeile('Eissäule', anlage.eissaeule ? 'Ja' : 'Nein'),
              if (anlage.gasTyp1 != null)
                InfoZeile('Gas Typ 1', anlage.gasTyp1!),
              if (anlage.gasTyp2 != null)
                InfoZeile('Gas Typ 2', anlage.gasTyp2!),
              if (anlage.hauptdruckBar != null)
                InfoZeile('Hauptdruck', '${anlage.hauptdruckBar} bar'),
              InfoZeile('Niederdruck', anlage.hatNiederdruck ? 'Ja' : 'Nein'),
            ],
          ),

          // Reinigung
          DetailKarte(
            titel: 'Reinigung',
            icon: Icons.cleaning_services,
            kinder: [
              InfoZeile('Rhythmus', anlage.reinigungRhythmus),
              if (anlage.letzteReinigung != null)
                InfoZeile(
                  'Letzte Reinigung',
                  _formatDate(anlage.letzteReinigung!),
                ),
              if (anlage.naechsteReinigung != null)
                InfoZeile(
                  'Nächste Reinigung',
                  _formatDate(anlage.naechsteReinigung!),
                ),
              if (anlage.letzterWasserwechsel != null)
                InfoZeile(
                  'Letzter Wasserwechsel',
                  _formatDate(anlage.letzterWasserwechsel!),
                ),
            ],
          ),

          // Bierleitungen
          if (anlage.serverId != null) _BierleitungenSection(anlage: anlage),

          // Einsätze dieser Anlage: Reinigungen, Störungen, Montagen,
          // Eigenaufträge in einer Liste (Akte, T10)
          if (anlage.serverId != null && anlage.betriebId.isNotEmpty)
            EinsaetzeAkteKarte(
              betriebId: anlage.betriebId,
              anlageId: anlage.serverId,
            ),

          // Notizen
          if (anlage.notizen != null)
            DetailKarte(
              titel: 'Notizen',
              icon: Icons.note,
              kinder: [InfoZeile('', anlage.notizen!)],
            ),

          // Zuletzt geändert
          if (anlage.updatedAt != null || anlage.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Zuletzt geändert: ${_formatDateTime(anlage.updatedAt ?? anlage.createdAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
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
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
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

  String _vorkuehlerLabel(String value) {
    if (value == 'keiner') return 'Keiner';
    return value; // DB-Werte sind bereits lesbar (Fasskühler, Kühlzelle, Buffet)
  }

  /// Baut das Steckbrief-PDF (Betrieb, Bierleitungen + Foto-Bytes aus Storage).
  Future<Uint8List> _buildSteckbrief(AnlageLocal anlage) async {
    final sid = anlage.serverId;
    final betrieb = await BetriebRepository.getByServerId(anlage.betriebId);
    final bierleitungen = sid == null
        ? <BierleitungLocal>[]
        : await BierleitungRepository.getByAnlage(sid);
    final fotoBytes = <Uint8List>[];
    if (sid != null) {
      final fotos = await AnlageFotoRepository.getByAnlage(sid);
      for (final f in fotos) {
        try {
          final bytes = await SupabaseService.client.storage
              .from('anlagen-fotos')
              .download(f.fotoUrl);
          fotoBytes.add(bytes);
        } catch (_) {
          /* Foto fehlt -> überspringen */
        }
      }
    }
    return AnlagePdfService.steckbrief(
      anlage: anlage,
      betrieb: betrieb,
      fotos: fotoBytes,
      bierleitungen: bierleitungen,
    );
  }

  Future<void> _steckbriefOeffnen(
    BuildContext context,
    AnlageLocal anlage,
  ) async {
    try {
      final betrieb = await BetriebRepository.getByServerId(anlage.betriebId);
      final pdf = await _buildSteckbrief(anlage);
      await Printing.layoutPdf(
        onLayout: (_) => pdf,
        name: anlageSteckbriefDateiname(
          betrieb?.name ?? '',
          anlage.bezeichnung ?? '',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF fehlgeschlagen: ${kurzeFehlermeldung(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _steckbriefAnRsl(
    BuildContext context,
    AnlageLocal anlage,
  ) async {
    try {
      final betrieb = await BetriebRepository.getByServerId(anlage.betriebId);
      final rsl = await KontaktRepository.getHeinekenZuweisung('rsl');
      final pdf = await _buildSteckbrief(anlage);
      if (!context.mounted) return;
      final betriebName = betrieb?.name ?? '';
      final bez =
          anlage.bezeichnung ??
          (anlage.typAnlage.isEmpty ? 'Anlage' : anlage.typAnlage);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AnlageSteckbriefSheet(
          betriebName: betriebName,
          anlageBezeichnung: bez,
          rslMail: rsl?.email,
          betreff: anlageMailBetreff(betriebName, bez),
          dateiname: anlageSteckbriefDateiname(betriebName, bez),
          pdf: pdf,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF fehlgeschlagen: ${kurzeFehlermeldung(e)}'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
          TapKnopf(text: 'Löschen', gefahr: true, onTap: () => ctx.pop(true)),
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
            const SnackBar(
              content: Text('Löschen nur mit Internetverbindung möglich'),
            ),
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
      await AnlageFotoRepository.upload(
        widget.anlageId,
        fotoNummer,
        bytes,
        null,
      );
      await _loadFotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload fehlgeschlagen: ${kurzeFehlermeldung(e)}'),
          ),
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
          TapKnopf(text: 'Löschen', gefahr: true, onTap: () => ctx.pop(true)),
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
          SnackBar(
            content: Text('Löschen fehlgeschlagen: ${kurzeFehlermeldung(e)}'),
          ),
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
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
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
                const Icon(
                  Icons.photo_camera,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fotos ($fotoCount/4)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
          border: Border.all(
            color: AppColors.divider,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 24,
              color: AppColors.textSecondary,
            ),
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
                    const Icon(
                      Icons.local_drink,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bierleitungen (${leitungen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (leitungen.length < 5)
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
                  ...leitungen.map(
                    (l) => _BierleitungRow(
                      leitung: l,
                      anlageRouteId: widget.anlage.routeId,
                      onDeleted: _refresh,
                    ),
                  ),
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
    final isInaktiv = !leitung.istAktiv;

    return Opacity(
      opacity: isInaktiv ? 0.5 : 1.0,
      child: InkWell(
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
                  color: isInaktiv
                      ? AppColors.textSecondary.withAlpha(25)
                      : AppColors.info.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${leitung.leitungsNummer}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isInaktiv
                          ? AppColors.textSecondary
                          : AppColors.info,
                    ),
                  ),
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
                          leitung.biersorte ?? 'Keine Biersorte',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (isInaktiv) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Inaktiv',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (leitung.hahnTyp != null ||
                        leitung.niederdruckBar != null)
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
                  child: Icon(
                    Icons.stop_circle_outlined,
                    size: 16,
                    color: AppColors.info,
                  ),
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
          TapKnopf(
            text: 'Abbrechen',
            primaer: false,
            onTap: () => ctx.pop(false),
          ),
          TapKnopf(text: 'Löschen', gefahr: true, onTap: () => ctx.pop(true)),
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
          color: switch (anlage.status) {
            'aktiv' => AppColors.aktiv,
            'stillgelegt' => AppColors.geschlossen,
            'demontiert' => AppColors.demontiert,
            _ => AppColors.inaktiv,
          },
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

