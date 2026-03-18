import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/services/phone_contact_service.dart';

class BetriebKontaktFormScreen extends ConsumerStatefulWidget {
  final String betriebId;
  final String? kontaktId;

  const BetriebKontaktFormScreen({
    super.key,
    required this.betriebId,
    this.kontaktId,
  });

  @override
  ConsumerState<BetriebKontaktFormScreen> createState() =>
      _BetriebKontaktFormScreenState();
}

class _BetriebKontaktFormScreenState
    extends ConsumerState<BetriebKontaktFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  BetriebKontaktLocal? _existing;

  late final _vornameController = TextEditingController();
  late final _nachnameController = TextEditingController();
  late final _telefonController = TextEditingController();
  late final _notizenController = TextEditingController();

  String? _selectedFunktion;
  String? _phoneContactId;
  bool _istHauptkontakt = false;
  bool _istDuAnrede = false;

  bool get _isEdit => widget.kontaktId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadKontakt();
  }

  Future<void> _loadKontakt() async {
    final kontakt = await BetriebKontaktRepository.getById(widget.kontaktId!);
    if (kontakt == null || !mounted) return;

    setState(() {
      _existing = kontakt;
      _vornameController.text = kontakt.vorname;
      _nachnameController.text = kontakt.nachname ?? '';
      _selectedFunktion = kontakt.funktion;
      _phoneContactId = kontakt.phoneContactId;
      _telefonController.text = kontakt.telefon ?? '';
      _notizenController.text = kontakt.notizen ?? '';
      _istHauptkontakt = kontakt.istHauptkontakt;
      _istDuAnrede = kontakt.istDuAnrede;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final kontakt = _existing ?? BetriebKontaktLocal();
      kontakt.betriebId = widget.betriebId;
      kontakt.vorname = _vornameController.text.trim();
      kontakt.nachname = _emptyToNull(_nachnameController.text);
      kontakt.funktion = _selectedFunktion;
      kontakt.telefon = _emptyToNull(_telefonController.text);
      kontakt.notizen = _emptyToNull(_notizenController.text);
      kontakt.istHauptkontakt = _istHauptkontakt;
      kontakt.istDuAnrede = _istDuAnrede;
      kontakt.phoneContactId = _phoneContactId;

      // Auf Handy speichern (nur Android/iOS)
      if (!kIsWeb) {
        try {
          final betrieb = await BetriebRepository.getById(widget.betriebId);
          final betriebName = betrieb?.name ?? '';
          final newPhoneId = await PhoneContactService.saveToPhone(
            vorname: kontakt.vorname,
            nachname: kontakt.nachname,
            telefon: kontakt.telefon,
            betriebName: betriebName,
            existingPhoneContactId: _phoneContactId,
          );
          if (newPhoneId != null) {
            kontakt.phoneContactId = newPhoneId;
            _phoneContactId = newPhoneId;
          }
        } catch (_) {
          // Handy-Sync fehlgeschlagen, App-Kontakt trotzdem speichern
        }
      }

      await BetriebKontaktRepository.save(kontakt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isEdit ? 'Kontakt aktualisiert' : 'Kontakt erstellt'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromPhone() async {
    final data = await PhoneContactService.pickContact();
    if (data == null || !mounted) return;

    setState(() {
      if (data['vorname'] != null) _vornameController.text = data['vorname']!;
      if (data['nachname'] != null) _nachnameController.text = data['nachname']!;
      if (data['telefon'] != null) _telefonController.text = data['telefon']!;
      if (data['phoneContactId'] != null) _phoneContactId = data['phoneContactId'];
    });
  }

  String? _emptyToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _vornameController.dispose();
    _nachnameController.dispose();
    _telefonController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Kontakt bearbeiten' : 'Neuer Kontakt'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Import von Handykontakten (nur Android/iOS) ===
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.contacts),
                  label: const Text('Aus Kontakten importieren'),
                  onPressed: _importFromPhone,
                ),
              ),

            // === Name ===
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vornameController,
                    decoration: const InputDecoration(
                      labelText: 'Vorname *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Vorname ist erforderlich'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nachnameController,
                    decoration: const InputDecoration(
                      labelText: 'Nachname',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Funktion ===
            DropdownButtonFormField<String>(
              value: _selectedFunktion,
              decoration: const InputDecoration(
                labelText: 'Funktion',
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: const [
                DropdownMenuItem(value: 'Geschäftsführer', child: Text('Geschäftsführer')),
                DropdownMenuItem(value: 'F&B Manager', child: Text('F&B Manager')),
                DropdownMenuItem(value: 'Mitarbeiter', child: Text('Mitarbeiter')),
                DropdownMenuItem(value: 'Hauswart', child: Text('Hauswart')),
                DropdownMenuItem(value: 'Sonstige', child: Text('Sonstige')),
              ],
              onChanged: (v) => setState(() => _selectedFunktion = v),
            ),
            const SizedBox(height: 12),

            // === Telefon ===
            TextFormField(
              controller: _telefonController,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: '+41 81 378 40 20',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [_PhoneFormatter()],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                if (!v.startsWith('+') || digits.length < 10) {
                  return 'Format: +41 81 378 40 20';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // === Optionen ===
            SwitchListTile(
              title: const Text('Hauptkontakt'),
              subtitle: const Text('Primärer Ansprechpartner'),
              value: _istHauptkontakt,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istHauptkontakt = v),
            ),
            SwitchListTile(
              title: Text(_istDuAnrede ? 'Du' : 'Sie'),
              subtitle: Text(_istDuAnrede ? 'Informelle Anrede' : 'Formelle Anrede'),
              value: _istDuAnrede,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istDuAnrede = v),
            ),
            const SizedBox(height: 12),

            // === Notizen ===
            TextFormField(
              controller: _notizenController,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // === Speichern ===
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : 'Kontakt erstellen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final buffer = StringBuffer();
    if (digits.startsWith('+')) {
      buffer.write('+');
      digits = digits.substring(1);
    }

    // Format: XX XX XXX XX XX (Leerzeichen nach Position 2, 4, 7, 9)
    const gaps = {2, 4, 7, 9};
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (gaps.contains(i)) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
