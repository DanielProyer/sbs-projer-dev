import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Rückgabe: das angelegte Dokument oder null (abgebrochen).
Future<Dokument?> showDokumentUploadDialog(
  BuildContext context, {
  required String bereich,
  bool bereichFix = true,
  int? jahr,
  List<Buchung> buchungen = const [],
}) => showDialog<Dokument>(
  context: context,
  builder: (_) => _UploadDialog(
    bereich: bereich,
    bereichFix: bereichFix,
    jahr: jahr,
    buchungen: buchungen,
  ),
);

class _UploadDialog extends StatefulWidget {
  final String bereich;
  final bool bereichFix;
  final int? jahr;
  final List<Buchung> buchungen;

  const _UploadDialog({
    required this.bereich,
    required this.bereichFix,
    this.jahr,
    required this.buchungen,
  });

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late String _bereich = widget.bereich;
  late String _typ = dokumentTypen(widget.bereich).first;
  String? _kategorie;
  late final _jahr = TextEditingController(text: widget.jahr?.toString() ?? '');
  final _titel = TextEditingController();
  final _betrag = TextEditingController();
  final _referenz = TextEditingController();
  final _notizen = TextEditingController();
  DateTime? _datum;
  String? _buchungId;
  Uint8List? _bytes;
  String? _dateiname;
  String? _dateityp;
  bool _laeuft = false;

  static const _maxBytes = 20 * 1024 * 1024; // Bucket-Limit

  @override
  void dispose() {
    _jahr.dispose();
    _titel.dispose();
    _betrag.dispose();
    _referenz.dispose();
    _notizen.dispose();
    super.dispose();
  }

  Future<void> _pdfWaehlen() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final f = r?.files.single;
    if (f?.bytes == null || !mounted) return;
    _uebernehmen(f!.bytes!, f.name, 'application/pdf');
  }

  Future<void> _bildWaehlen(ImageSource q) async {
    final x = await ImagePicker().pickImage(
      source: q,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    final mime = x.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    _uebernehmen(bytes, x.name, mime);
  }

  void _uebernehmen(Uint8List bytes, String name, String mime) {
    if (bytes.length > _maxBytes) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Datei grösser als 20 MB.')));
      return;
    }
    setState(() {
      _bytes = bytes;
      _dateiname = name;
      _dateityp = mime;
      if (_titel.text.isEmpty) {
        _titel.text = name.replaceAll(
          RegExp(r'\.(pdf|jpe?g|png)$', caseSensitive: false),
          '',
        );
      }
    });
  }

  Future<void> _speichern() async {
    if (_bytes == null || _titel.text.trim().isEmpty) return;
    setState(() => _laeuft = true);
    try {
      final d = await DokumentRepository.upload(
        bereich: _bereich,
        typ: _typ,
        kategorie: _kategorie,
        jahr: int.tryParse(_jahr.text),
        dokumentDatum: _datum,
        betrag: double.tryParse(
          _betrag.text.replaceAll("'", '').replaceAll(',', '.'),
        ),
        referenz: _referenz.text.trim().isEmpty ? null : _referenz.text.trim(),
        titel: _titel.text.trim(),
        notizen: _notizen.text.trim().isEmpty ? null : _notizen.text.trim(),
        dateiname: _dateiname!,
        dateityp: _dateityp!,
        bytes: _bytes!,
        buchungId: _buchungId,
      );
      if (mounted) Navigator.pop(context, d);
    } catch (e) {
      if (mounted) {
        setState(() => _laeuft = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload fehlgeschlagen: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    return AlertDialog(
      title: const Text('Dokument hochladen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.bereichFix)
              DropdownButtonFormField<String>(
                initialValue: _bereich,
                decoration: const InputDecoration(labelText: 'Bereich'),
                items: [
                  for (final e in dokumentBereiche.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() {
                  _bereich = v!;
                  _typ = dokumentTypen(v).first;
                  _kategorie = null;
                }),
              ),
            DropdownButtonFormField<String>(
              initialValue: _typ,
              decoration: const InputDecoration(labelText: 'Typ'),
              items: [
                for (final t in dokumentTypen(_bereich))
                  DropdownMenuItem(value: t, child: Text(dokumentTypLabel(t))),
              ],
              onChanged: (v) => setState(() => _typ = v!),
            ),
            if (_bereich == 'steuern')
              DropdownButtonFormField<String?>(
                initialValue: _kategorie,
                decoration: const InputDecoration(labelText: 'Steuerart'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final e in steuerarten.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _kategorie = v),
              )
            else
              TextField(
                decoration: const InputDecoration(labelText: 'Kategorie'),
                onChanged: (v) =>
                    _kategorie = v.trim().isEmpty ? null : v.trim(),
              ),
            TextField(
              controller: _jahr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jahr'),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Datum: ${_datum == null ? '—' : df.format(_datum!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _datum ?? DateTime.now(),
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2035),
                    );
                    if (p != null) setState(() => _datum = p);
                  },
                  child: const Text('wählen'),
                ),
              ],
            ),
            TextField(
              controller: _betrag,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Betrag CHF (Guthaben negativ)',
              ),
            ),
            TextField(
              controller: _referenz,
              decoration: const InputDecoration(
                labelText: 'Referenz / Rechnungs-Nr.',
              ),
            ),
            TextField(
              controller: _titel,
              decoration: const InputDecoration(labelText: 'Titel *'),
            ),
            TextField(
              controller: _notizen,
              decoration: const InputDecoration(labelText: 'Notizen'),
              maxLines: 2,
            ),
            if (widget.buchungen.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _buchungId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Zahlung verknüpfen',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final b in widget.buchungen)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        '${df.format(b.datum)} '
                        '${b.betragBrutto.toStringAsFixed(2)} '
                        '${b.beschreibung}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _buchungId = v),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TapKnopf(
                  text: 'PDF',
                  icon: Icons.picture_as_pdf,
                  primaer: false,
                  onTap: _pdfWaehlen,
                ),
                TapKnopf(
                  text: 'Galerie',
                  icon: Icons.photo,
                  primaer: false,
                  onTap: () => _bildWaehlen(ImageSource.gallery),
                ),
                TapKnopf(
                  text: 'Kamera',
                  icon: Icons.camera_alt,
                  primaer: false,
                  onTap: () => _bildWaehlen(ImageSource.camera),
                ),
              ],
            ),
            if (_dateiname != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Datei: $_dateiname'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _laeuft ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        TapKnopf(
          text: _laeuft ? 'Lädt…' : 'Speichern',
          onTap: (_laeuft || _bytes == null) ? null : _speichern,
        ),
      ],
    );
  }
}
