// lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';

class GeschaeftForm extends ConsumerStatefulWidget {
  final GeschaeftEinstellungen geschaeft;
  const GeschaeftForm({super.key, required this.geschaeft});

  @override
  ConsumerState<GeschaeftForm> createState() => _GeschaeftFormState();
}

class _GeschaeftFormState extends ConsumerState<GeschaeftForm> {
  late final Map<String, TextEditingController> _c;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.geschaeft;
    _c = {
      'firma_name': TextEditingController(text: g.firmaName ?? ''),
      'strasse': TextEditingController(text: g.strasse ?? ''),
      'plz_ort': TextEditingController(text: g.plzOrt ?? ''),
      'mwst_nummer': TextEditingController(text: g.mwstNummer ?? ''),
      'uid_nummer': TextEditingController(text: g.uidNummer ?? ''),
      'gf_vorname': TextEditingController(text: g.gfVorname ?? ''),
      'gf_name': TextEditingController(text: g.gfName ?? ''),
      'telefon': TextEditingController(text: g.telefon ?? ''),
      'mail_geschaeft': TextEditingController(text: g.mailGeschaeft ?? ''),
      'mail_privat': TextEditingController(text: g.mailPrivat ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await GeschaeftRepository.save(
          {for (final e in _c.entries) e.key: e.value.text.trim()});
      ref.invalidate(geschaeftProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geschäft gespeichert')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label, {TextInputType? kb}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _c[key],
          keyboardType: kb,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Firma'),
        _field('firma_name', 'Name'),
        _field('strasse', 'Strasse / Nr.'),
        _field('plz_ort', 'PLZ Ort'),
        _field('mwst_nummer', 'MWST-Nummer'),
        _field('uid_nummer', 'UID-Nummer'),
        _label('Geschäftsführer'),
        _field('gf_vorname', 'Vorname'),
        _field('gf_name', 'Name'),
        _label('Kontakt'),
        _field('telefon', 'Telefon', kb: TextInputType.phone),
        _field('mail_geschaeft', 'Mail Geschäft', kb: TextInputType.emailAddress),
        _field('mail_privat', 'Mail Privat', kb: TextInputType.emailAddress),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: const Text('Geschäft speichern'),
          ),
        ),
      ],
    );
  }
}
