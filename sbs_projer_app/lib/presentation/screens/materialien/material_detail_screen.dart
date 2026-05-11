import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_artikel.dart';
import 'package:sbs_projer_app/data/models/material_verbrauch.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_artikel_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_kategorie_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_verbrauch_repository.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MaterialDetailScreen extends ConsumerWidget {
  final String materialId;

  const MaterialDetailScreen({super.key, required this.materialId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Lager?>(
      future: LagerRepository.getById(materialId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final lager = snapshot.data;
        if (lager == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Material nicht gefunden')),
          );
        }
        return _MaterialDetailContent(lager: lager);
      },
    );
  }
}

class _MaterialDetailContent extends ConsumerStatefulWidget {
  final Lager lager;
  const _MaterialDetailContent({required this.lager});

  @override
  ConsumerState<_MaterialDetailContent> createState() =>
      _MaterialDetailContentState();
}

class _MaterialDetailContentState
    extends ConsumerState<_MaterialDetailContent> {
  late Lager _lager;
  String? _kategorieName;
  List<MaterialVerbrauch>? _verbrauch;
  bool _loadingVerbrauch = true;
  MaterialArtikel? _artikel;
  String? _previewUrl;   // Geringe Auflösung (für Vorschaukarte)
  bool _uploadingFoto = false;

  @override
  void initState() {
    super.initState();
    _lager = widget.lager;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      if (_lager.kategorieId != null) {
        final kategorien = await MaterialKategorieRepository.getAll();
        _kategorieName = kategorien
            .where((k) => k.id == _lager.kategorieId)
            .map((k) => k.name)
            .firstOrNull;
      }
      // Artikel-Foto laden (nur Preview für schnelles Laden)
      if (_lager.materialId != null) {
        final artikel =
            await MaterialArtikelRepository.getById(_lager.materialId!);
        if (artikel != null && artikel.fotoStoragePath != null && mounted) {
          try {
            // Nur Preview laden — HighRes erst bei Tap auf Vollbild
            final previewUrl =
                await MaterialArtikelRepository.getSignedUrlPreview(
                    artikel.fotoStoragePath!);
            if (mounted) {
              setState(() {
                _artikel = artikel;
                _previewUrl = previewUrl;
              });
            }
          } catch (_) {
            if (mounted) setState(() => _artikel = artikel);
          }
        } else if (mounted) {
          setState(() => _artikel = artikel);
        }
      }
      final verbrauch =
          await MaterialVerbrauchRepository.getByLager(_lager.id);
      if (mounted) {
        setState(() {
          _verbrauch = verbrauch;
          _loadingVerbrauch = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVerbrauch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNiedrig = _lager.bestandNiedrig == true;
    final ratio = _lager.bestandOptimal > 0
        ? (_lager.bestandAktuell / _lager.bestandOptimal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_lager.name),
        actions: [
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Bestand anpassen',
              onPressed: _showBestandDialog,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () =>
                  context.push('/materialien/${_lager.id}/bearbeiten'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Artikel-Foto
          if (_artikel != null) _buildFotoCard(),

          // Bestand-Card
          _SectionCard(children: [
            const Text('Bestand',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                backgroundColor: AppColors.textSecondary.withAlpha(30),
                color: isNiedrig ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_lager.bestandAktuell.toStringAsFixed(0)} ${_lager.einheit}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isNiedrig ? AppColors.error : AppColors.success,
                  ),
                ),
                Text(
                  'Mindest: ${_lager.bestandMindest.toStringAsFixed(0)} · '
                  'Optimal: ${_lager.bestandOptimal.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (isNiedrig) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'Bestand niedrig – nachbestellen!',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // Info-Card
          _SectionCard(children: [
            const Text('Details',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            if (_kategorieName != null)
              _InfoRow('Kategorie', _kategorieName!),
            _InfoRow('Einheit', _lager.einheit),
            if (_lager.dboNr != null)
              _InfoRow('DBO-Nr.', _lager.dboNr!),
            if (_lager.beschreibung != null &&
                _lager.beschreibung!.isNotEmpty)
              _InfoRow('Beschreibung', _lager.beschreibung!),
            if (_lager.notizen != null && _lager.notizen!.isNotEmpty)
              _InfoRow('Notizen', _lager.notizen!),
          ]),
          const SizedBox(height: 12),

          // Verbrauchshistorie
          _SectionCard(children: [
            const Text('Verbrauchshistorie',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            if (_loadingVerbrauch)
              const Center(child: CircularProgressIndicator())
            else if (_verbrauch != null && _verbrauch!.isNotEmpty)
              ..._verbrauch!.map((v) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _serviceIcon(v.serviceTyp),
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_serviceLabel(v.serviceTyp)} · '
                            '${v.menge.toStringAsFixed(0)} ${v.einheit}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          v.verbrauchtAm != null
                              ? _formatDate(v.verbrauchtAm!)
                              : '',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ))
            else
              Text('Noch kein Verbrauch',
                  style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }

  Widget _buildFotoCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_previewUrl != null)
            GestureDetector(
              onTap: () => _showFullImage(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 300,
                ),
                child: Image.network(
                  _previewUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 150,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              ),
            )
          else if (_uploadingFoto)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!SupabaseService.isGuest)
            InkWell(
              onTap: _pickAndUploadFoto,
              child: Container(
                width: double.infinity,
                height: 120,
                color: AppColors.surface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 32, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text('Artikelfoto hinzufügen',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          if (_previewUrl != null && !SupabaseService.isGuest)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _pickAndUploadFoto,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Ändern'),
                  ),
                  TextButton.icon(
                    onPressed: _deleteFoto,
                    icon: Icon(Icons.delete, size: 16, color: AppColors.error),
                    label: Text('Löschen',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFoto() async {
    if (_artikel == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    // Auf 2400px begrenzen für flüssiges Crop-Erlebnis
    final file = await picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (file == null || !mounted) return;

    final imageBytes = await file.readAsBytes();

    // Crop/Rotate-Dialog — gibt zugeschnittene Bytes zurück
    if (!mounted) return;
    final croppedBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FotoCropDialog(
        imageBytes: imageBytes,
        onRetake: () {
          Navigator.pop(ctx, null);
          Future.microtask(() => _pickAndUploadFoto());
        },
      ),
    );
    if (croppedBytes == null || !mounted) return;

    // Zwei Auflösungen aus dem Crop-Ergebnis erzeugen
    setState(() => _uploadingFoto = true);
    try {
      final decoded = img.decodeImage(croppedBytes);
      if (decoded == null) throw Exception('Bild konnte nicht dekodiert werden');

      // High-Res: Crop-Ergebnis als JPEG (max ~2400px)
      final highResBytes =
          Uint8List.fromList(img.encodeJpg(decoded, quality: 88));

      // Preview: auf 400px verkleinert, niedrige Qualität
      final previewImage = decoded.width > 400
          ? img.copyResize(decoded, width: 400)
          : decoded;
      final previewBytes =
          Uint8List.fromList(img.encodeJpg(previewImage, quality: 60));

      debugPrint(
          'Foto: HighRes ${highResBytes.length} bytes, '
          'Preview ${previewBytes.length} bytes');

      await MaterialArtikelRepository.uploadFoto(
        _artikel!.id,
        highResBytes: highResBytes,
        previewBytes: previewBytes,
      );
      final updated =
          await MaterialArtikelRepository.getById(_artikel!.id);
      if (updated != null && updated.fotoStoragePath != null && mounted) {
        // Nur Preview-URL laden (HighRes erst bei Tap)
        final previewUrl =
            await MaterialArtikelRepository.getSignedUrlPreview(
                updated.fotoStoragePath!);
        setState(() {
          _artikel = updated;
          _previewUrl = previewUrl;
          _uploadingFoto = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto hochgeladen')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Upload: $e')),
        );
      }
    }
  }

  Future<void> _deleteFoto() async {
    if (_artikel == null || _artikel!.fotoStoragePath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foto löschen?'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => ctx.pop(true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await MaterialArtikelRepository.deleteFoto(
          _artikel!.id, _artikel!.fotoStoragePath!);
      if (mounted) {
        setState(() => _previewUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto gelöscht')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  /// Vollbild-Ansicht — lädt HighRes-URL erst bei Bedarf.
  Future<void> _showFullImage() async {
    if (_artikel?.fotoStoragePath == null) return;

    // HighRes-URL on-demand laden
    String? highResUrl;
    try {
      highResUrl = await MaterialArtikelRepository.getSignedUrl(
          _artikel!.fotoStoragePath!);
    } catch (_) {
      // Fallback auf Preview
      highResUrl = _previewUrl;
    }
    if (highResUrl == null || !mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(_lager.name),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                highResUrl!,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text('Volle Auflösung laden...',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  );
                },
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBestandDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bestand anpassen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Aktuell: ${_lager.bestandAktuell.toStringAsFixed(0)} ${_lager.einheit}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Neuer Bestand',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) ctx.pop(val);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await LagerRepository.update(
            _lager.id, {'bestand_aktuell': result});
        final updated = await LagerRepository.getById(_lager.id);
        if (mounted && updated != null) {
          ref.invalidate(materialienStreamProvider);
          setState(() => _lager = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bestand aktualisiert')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Material löschen?'),
        content: Text('«${_lager.name}» wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => ctx.pop(true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await LagerRepository.delete(_lager.id);
      if (mounted) {
        ref.invalidate(materialienStreamProvider);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material gelöscht')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  IconData _serviceIcon(String typ) {
    switch (typ) {
      case 'stoerung':
        return Icons.warning_amber;
      case 'reinigung':
        return Icons.cleaning_services;
      case 'montage':
        return Icons.build;
      default:
        return Icons.handyman;
    }
  }

  String _serviceLabel(String typ) {
    switch (typ) {
      case 'stoerung':
        return 'Störung';
      case 'reinigung':
        return 'Reinigung';
      case 'montage':
        return 'Montage';
      case 'eigenauftrag':
        return 'Eigenauftrag';
      default:
        return typ;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Mobil-optimierter Foto-Editor: Zuschneiden + Drehen.
/// Gibt die zugeschnittenen Bytes zurück oder null bei Abbruch.
///
/// UX-Prinzip: Fester Crop-Rahmen, Bild bewegen/zoomen (wie Instagram).
/// PopScope verhindert versehentliches Browser-Back.
class _FotoCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final VoidCallback onRetake;

  const _FotoCropDialog({
    required this.imageBytes,
    required this.onRetake,
  });

  @override
  State<_FotoCropDialog> createState() => _FotoCropDialogState();
}

class _FotoCropDialogState extends State<_FotoCropDialog> {
  late CropController _cropController;
  late Uint8List _currentBytes;
  bool _cropping = false;
  bool _rotating = false;

  @override
  void initState() {
    super.initState();
    _cropController = CropController();
    _currentBytes = widget.imageBytes;
  }

  /// Bild 90° im Uhrzeigersinn drehen via image-Package.
  Future<void> _rotate90() async {
    if (_rotating || _cropping) return;
    setState(() => _rotating = true);
    // UI-Update abwarten bevor schwere Arbeit startet
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      final decoded = img.decodeImage(_currentBytes);
      if (decoded == null) throw Exception('Bild nicht lesbar');
      final rotated = img.copyRotate(decoded, angle: 90);
      final rotatedBytes =
          Uint8List.fromList(img.encodeJpg(rotated, quality: 90));
      if (mounted) {
        setState(() {
          _currentBytes = rotatedBytes;
          _cropController = CropController();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drehen fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_cropping) {
          Navigator.pop(context, null);
        }
      },
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Foto bearbeiten'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cropping ? null : () => Navigator.pop(context, null),
            ),
          ),
          body: Column(
            children: [
              // Crop-Widget
              Expanded(
                child: _rotating
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Wird gedreht...',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      )
                    : Crop(
                        key: ValueKey(_currentBytes.length),
                        image: _currentBytes,
                        controller: _cropController,
                        onCropped: (result) {
                          if (!mounted) return;
                          setState(() => _cropping = false);
                          switch (result) {
                            case CropSuccess(:final croppedImage):
                              Navigator.pop(context, croppedImage);
                            case CropFailure(:final cause):
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Fehler: $cause')),
                              );
                          }
                        },
                        interactive: true,
                        fixCropRect: true,
                        baseColor: Colors.black,
                        maskColor: Colors.black54,
                        cornerDotBuilder: (size, edgeAlignment) =>
                            const SizedBox.shrink(),
                      ),
              ),
              // Werkzeug-Leiste
              Container(
                color: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ToolButton(
                      icon: Icons.rotate_right,
                      label: 'Drehen',
                      onTap: (_rotating || _cropping) ? null : _rotate90,
                    ),
                    const SizedBox(width: 32),
                    _ToolButton(
                      icon: Icons.camera_alt,
                      label: 'Neu aufnehmen',
                      onTap: (_rotating || _cropping) ? null : widget.onRetake,
                    ),
                  ],
                ),
              ),
              // Haupt-Button
              SafeArea(
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: FilledButton(
                    onPressed: (_cropping || _rotating)
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _cropController.crop();
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _cropping
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verwenden',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleiner Werkzeug-Button für die Foto-Bearbeitung.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: enabled ? Colors.white : Colors.white38, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white38,
                  fontSize: 11,
                )),
          ],
        ),
      ),
    );
  }
}
