import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';

class BetriebRechnungsadresseFormScreen extends ConsumerStatefulWidget {
  final String betriebId;
  final String? adresseId;

  const BetriebRechnungsadresseFormScreen({
    super.key,
    required this.betriebId,
    this.adresseId,
  });

  @override
  ConsumerState<BetriebRechnungsadresseFormScreen> createState() =>
      _BetriebRechnungsadresseFormScreenState();
}

class _BetriebRechnungsadresseFormScreenState
    extends ConsumerState<BetriebRechnungsadresseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  BetriebRechnungsadresseLocal? _existing;

  late final _firmaController = TextEditingController();
  late final _vornameController = TextEditingController();
  late final _nachnameController = TextEditingController();
  late final _strasseController = TextEditingController();
  late final _nrController = TextEditingController();
  late final _plzController = TextEditingController();
  late final _ortController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _notizenController = TextEditingController();

  bool get _isEdit => widget.adresseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadAdresse();
    } else {
      _loadExisting();
    }
  }

  /// Prüfe ob bereits eine Rechnungsadresse existiert (für neuen Eintrag)
  Future<void> _loadExisting() async {
    final existing =
        await BetriebRechnungsadresseRepository.getByBetrieb(widget.betriebId);
    if (existing != null && mounted) {
      setState(() {
        _existing = existing;
        _firmaController.text = existing.firma ?? '';
        _vornameController.text = existing.vorname ?? '';
        _nachnameController.text = existing.nachname;
        _strasseController.text = existing.strasse;
        _nrController.text = existing.nr ?? '';
        _plzController.text = existing.plz;
        _ortController.text = existing.ort;
        _emailController.text = existing.email ?? '';
        _notizenController.text = existing.notizen ?? '';
      });
    }
  }

  Future<void> _loadAdresse() async {
    final adresse =
        await BetriebRechnungsadresseRepository.getById(widget.adresseId!);
    if (adresse == null || !mounted) return;

    setState(() {
      _existing = adresse;
      _firmaController.text = adresse.firma ?? '';
      _vornameController.text = adresse.vorname ?? '';
      _nachnameController.text = adresse.nachname;
      _strasseController.text = adresse.strasse;
      _nrController.text = adresse.nr ?? '';
      _plzController.text = adresse.plz;
      _ortController.text = adresse.ort;
      _emailController.text = adresse.email ?? '';
      _notizenController.text = adresse.notizen ?? '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final adresse = _existing ?? BetriebRechnungsadresseLocal();
      adresse.betriebId = widget.betriebId;
      adresse.firma = _emptyToNull(_firmaController.text);
      adresse.vorname = _emptyToNull(_vornameController.text);
      adresse.nachname = _nachnameController.text.trim();
      adresse.strasse = _strasseController.text.trim();
      adresse.nr = _emptyToNull(_nrController.text);
      adresse.plz = _plzController.text.trim();
      adresse.ort = _ortController.text.trim();
      adresse.email = _emptyToNull(_emailController.text);
      adresse.notizen = _emptyToNull(_notizenController.text);

      await BetriebRechnungsadresseRepository.save(adresse);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rechnungsadresse gespeichert')),
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
    _firmaController.dispose();
    _vornameController.dispose();
    _nachnameController.dispose();
    _strasseController.dispose();
    _nrController.dispose();
    _plzController.dispose();
    _ortController.dispose();
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
        title: const Text('Rechnungsadresse'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Firma ===
            TextFormField(
              controller: _firmaController,
              decoration: const InputDecoration(
                labelText: 'Firma',
                prefixIcon: Icon(Icons.business),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // === Name ===
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vornameController,
                    decoration: const InputDecoration(
                      labelText: 'Vorname',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nachnameController,
                    decoration: const InputDecoration(
                      labelText: 'Nachname *',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nachname ist erforderlich'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Adresse ===
            Text('Adresse',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _strasseController,
                    decoration: const InputDecoration(labelText: 'Strasse *'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Strasse ist erforderlich'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nrController,
                    decoration: const InputDecoration(labelText: 'Nr.'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _plzController,
                    decoration: const InputDecoration(labelText: 'PLZ *'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'PLZ ist erforderlich'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ortController,
                    decoration: const InputDecoration(labelText: 'Ort *'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ort ist erforderlich'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Kontakt ===
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-Mail (für Rechnungsversand)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
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
                  : const Text('Speichern'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
