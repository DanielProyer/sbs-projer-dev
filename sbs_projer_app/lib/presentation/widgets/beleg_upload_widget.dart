import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchungs_beleg.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_beleg_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_beleg_providers.dart';

/// Wiederverwendbares Widget zum Anzeigen und Hochladen von Belegen.
class BelegUploadWidget extends ConsumerStatefulWidget {
  final String buchungId;

  const BelegUploadWidget({super.key, required this.buchungId});

  @override
  ConsumerState<BelegUploadWidget> createState() => _BelegUploadWidgetState();
}

class _BelegUploadWidgetState extends ConsumerState<BelegUploadWidget> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final belegeAsync = ref.watch(buchungsBelegeProvider(widget.buchungId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Belege',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (_uploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Beleg hinzufügen',
                    onSelected: _onUploadOption,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'pdf',
                        child: ListTile(
                          leading: Icon(Icons.picture_as_pdf),
                          title: Text('PDF-Datei'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'foto',
                        child: ListTile(
                          leading: Icon(Icons.photo_library),
                          title: Text('Foto aus Galerie'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'kamera',
                        child: ListTile(
                          leading: Icon(Icons.camera_alt),
                          title: Text('Foto aufnehmen'),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(),
            belegeAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Fehler: $e'),
              data: (belege) {
                if (belege.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Keine Belege vorhanden',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return Column(
                  children: belege.map((b) => _BelegTile(
                    beleg: b,
                    onDelete: () => _deleteBeleg(b),
                    onTap: () => _openBeleg(b),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onUploadOption(String option) async {
    Uint8List? bytes;
    String? filename;
    String? dateityp;

    try {
      if (option == 'pdf') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          bytes = result.files.single.bytes!;
          filename = result.files.single.name;
          dateityp = 'pdf';
        }
      } else if (option == 'foto' || option == 'kamera') {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: option == 'kamera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2000,
        );
        if (image != null) {
          bytes = await image.readAsBytes();
          filename = image.name;
          dateityp = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        }
      }

      if (bytes != null && filename != null && dateityp != null) {
        setState(() => _uploading = true);
        await BuchungsBelegRepository.upload(
          buchungId: widget.buchungId,
          dateiname: filename,
          dateityp: dateityp,
          bytes: bytes,
        );
        ref.invalidate(buchungsBelegeProvider(widget.buchungId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Beleg hochgeladen')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteBeleg(BuchungsBeleg beleg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beleg löschen?'),
        content: Text('Soll "${beleg.dateiname}" gelöscht werden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BuchungsBelegRepository.delete(beleg.id, beleg.storagePfad);
        ref.invalidate(buchungsBelegeProvider(widget.buchungId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Beleg gelöscht')),
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

  Future<void> _openBeleg(BuchungsBeleg beleg) async {
    try {
      final url = await BuchungsBelegRepository.getSignedUrl(beleg.storagePfad);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(beleg.dateiname),
            content: SelectableText(url),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Schliessen'),
              ),
            ],
          ),
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

class _BelegTile extends StatelessWidget {
  final BuchungsBeleg beleg;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BelegTile({
    required this.beleg,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = beleg.dateityp == 'pdf'
        ? Icons.picture_as_pdf
        : Icons.image;
    final color = beleg.dateityp == 'pdf'
        ? AppColors.error
        : AppColors.info;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(25),
        radius: 16,
        child: Icon(icon, size: 16, color: color),
      ),
      title: Text(
        beleg.dateiname,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _quelleLabel(beleg.belegQuelle),
        style: const TextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: onDelete,
        tooltip: 'Löschen',
      ),
      onTap: onTap,
    );
  }

  String _quelleLabel(String quelle) {
    switch (quelle) {
      case 'camt053':
        return 'Auto-Bankbeleg';
      case 'rechnung':
        return 'Rechnung';
      default:
        return 'Manuell hochgeladen';
    }
  }
}
