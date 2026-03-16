import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_kontakt_repository.dart';

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
  late final _funktionController = TextEditingController();
  late final _telefonController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _notizenController = TextEditingController();

  String _kontaktMethode = 'telefon';
  bool _istHauptkontakt = false;

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
      _funktionController.text = kontakt.funktion ?? '';
      _telefonController.text = kontakt.telefon ?? '';
      _emailController.text = kontakt.email ?? '';
      _notizenController.text = kontakt.notizen ?? '';
      _kontaktMethode = kontakt.kontaktMethode;
      _istHauptkontakt = kontakt.istHauptkontakt;
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
      kontakt.funktion = _emptyToNull(_funktionController.text);
      kontakt.telefon = _emptyToNull(_telefonController.text);
      kontakt.email = _emptyToNull(_emailController.text);
      kontakt.notizen = _emptyToNull(_notizenController.text);
      kontakt.kontaktMethode = _kontaktMethode;
      kontakt.istHauptkontakt = _istHauptkontakt;

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

  String? _emptyToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _vornameController.dispose();
    _nachnameController.dispose();
    _funktionController.dispose();
    _telefonController.dispose();
    _emailController.dispose();
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
            TextFormField(
              controller: _funktionController,
              decoration: const InputDecoration(
                labelText: 'Funktion',
                prefixIcon: Icon(Icons.work_outline),
                hintText: 'z.B. Geschäftsführer, Barkeeper',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // === Kontaktdaten ===
            Text('Kontaktdaten',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            TextFormField(
              controller: _telefonController,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kontaktMethode,
              decoration: const InputDecoration(
                labelText: 'Bevorzugte Kontaktmethode',
                prefixIcon: Icon(Icons.contact_mail),
              ),
              items: const [
                DropdownMenuItem(value: 'telefon', child: Text('Telefon')),
                DropdownMenuItem(value: 'email', child: Text('E-Mail')),
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kontaktMethode = v);
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
