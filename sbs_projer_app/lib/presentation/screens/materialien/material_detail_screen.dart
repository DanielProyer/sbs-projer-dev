import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String? _fotoUrl;
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
      // Artikel-Foto laden
      if (_lager.materialId != null) {
        final artikel =
            await MaterialArtikelRepository.getById(_lager.materialId!);
        if (artikel != null && artikel.fotoStoragePath != null && mounted) {
          try {
            final url = await MaterialArtikelRepository.getSignedUrl(
                artikel.fotoStoragePath!);
            if (mounted) {
              setState(() {
                _artikel = artikel;
                _fotoUrl = url;
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
          if (_fotoUrl != null)
            GestureDetector(
              onTap: () => _showFullImage(_fotoUrl!),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  _fotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 48),
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
          if (_fotoUrl != null && !SupabaseService.isGuest)
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
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingFoto = true);
    try {
      final bytes = await file.readAsBytes();
      await MaterialArtikelRepository.uploadFoto(_artikel!.id, bytes);
      // Reload article to get updated foto_storage_path
      final updated =
          await MaterialArtikelRepository.getById(_artikel!.id);
      if (updated != null && updated.fotoStoragePath != null && mounted) {
        final url = await MaterialArtikelRepository.getSignedUrl(
            updated.fotoStoragePath!);
        setState(() {
          _artikel = updated;
          _fotoUrl = url;
          _uploadingFoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto hochgeladen')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
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
        setState(() => _fotoUrl = null);
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

  void _showFullImage(String url) {
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
            child: Center(
              child: Image.network(
                url,
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
