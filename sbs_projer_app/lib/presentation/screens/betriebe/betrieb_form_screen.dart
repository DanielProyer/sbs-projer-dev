import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

class BetriebFormScreen extends ConsumerStatefulWidget {
  final int? betriebId; // null = neu erstellen

  const BetriebFormScreen({super.key, this.betriebId});

  @override
  ConsumerState<BetriebFormScreen> createState() => _BetriebFormScreenState();
}

class _BetriebFormScreenState extends ConsumerState<BetriebFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  BetriebLocal? _existing;

  // Formular-Controller
  late final _nameController = TextEditingController();
  late final _strasseController = TextEditingController();
  late final _nrController = TextEditingController();
  late final _plzController = TextEditingController();
  late final _ortController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _websiteController = TextEditingController();
  late final _heinekenNrController = TextEditingController();
  late final _zugangController = TextEditingController();
  late final _notizenController = TextEditingController();

  String _status = 'aktiv';
  bool _istMeinKunde = true;
  bool _istBergkunde = false;
  bool _istSaisonbetrieb = false;
  String _rechnungsstellung = 'rechnung_mail';

  bool get _isEdit => widget.betriebId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadBetrieb();
  }

  Future<void> _loadBetrieb() async {
    final betrieb = await BetriebRepository.getById(widget.betriebId!);
    if (betrieb == null || !mounted) return;

    setState(() {
      _existing = betrieb;
      _nameController.text = betrieb.name;
      _strasseController.text = betrieb.strasse ?? '';
      _nrController.text = betrieb.nr ?? '';
      _plzController.text = betrieb.plz ?? '';
      _ortController.text = betrieb.ort ?? '';
      _emailController.text = betrieb.email ?? '';
      _websiteController.text = betrieb.website ?? '';
      _heinekenNrController.text = betrieb.heinekenNr ?? '';
      _zugangController.text = betrieb.zugangNotizen ?? '';
      _notizenController.text = betrieb.notizen ?? '';
      _status = betrieb.status;
      _istMeinKunde = betrieb.istMeinKunde;
      _istBergkunde = betrieb.istBergkunde;
      _istSaisonbetrieb = betrieb.istSaisonbetrieb;
      _rechnungsstellung = betrieb.rechnungsstellung;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final betrieb = _existing ?? BetriebLocal();
      betrieb.name = _nameController.text.trim();
      betrieb.strasse = _emptyToNull(_strasseController.text);
      betrieb.nr = _emptyToNull(_nrController.text);
      betrieb.plz = _emptyToNull(_plzController.text);
      betrieb.ort = _emptyToNull(_ortController.text);
      betrieb.email = _emptyToNull(_emailController.text);
      betrieb.website = _emptyToNull(_websiteController.text);
      betrieb.heinekenNr = _emptyToNull(_heinekenNrController.text);
      betrieb.zugangNotizen = _emptyToNull(_zugangController.text);
      betrieb.notizen = _emptyToNull(_notizenController.text);
      betrieb.status = _status;
      betrieb.istMeinKunde = _istMeinKunde;
      betrieb.istBergkunde = _istBergkunde;
      betrieb.istSaisonbetrieb = _istSaisonbetrieb;
      betrieb.rechnungsstellung = _rechnungsstellung;

      await BetriebRepository.save(betrieb);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Betrieb aktualisiert' : 'Betrieb erstellt'),
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
    _nameController.dispose();
    _strasseController.dispose();
    _nrController.dispose();
    _plzController.dispose();
    _ortController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _heinekenNrController.dispose();
    _zugangController.dispose();
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
        title: Text(_isEdit ? 'Betrieb bearbeiten' : 'Neuer Betrieb'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Name ===
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.store),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name ist erforderlich' : null,
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
                    decoration: const InputDecoration(labelText: 'Strasse'),
                    textInputAction: TextInputAction.next,
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
                    decoration: const InputDecoration(labelText: 'PLZ'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ortController,
                    decoration: const InputDecoration(labelText: 'Ort'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Kontakt ===
            Text('Kontakt',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
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
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website',
                prefixIcon: Icon(Icons.language),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _heinekenNrController,
              decoration: const InputDecoration(
                labelText: 'Heineken-Nr.',
                prefixIcon: Icon(Icons.tag),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // === Einstellungen ===
            Text('Einstellungen',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.circle),
              ),
              items: const [
                DropdownMenuItem(value: 'aktiv', child: Text('Aktiv')),
                DropdownMenuItem(value: 'inaktiv', child: Text('Inaktiv')),
                DropdownMenuItem(
                    value: 'saisonpause', child: Text('Saisonpause')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _rechnungsstellung,
              decoration: const InputDecoration(
                labelText: 'Rechnungsstellung',
                prefixIcon: Icon(Icons.receipt),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'rechnung_mail', child: Text('Per E-Mail')),
                DropdownMenuItem(
                    value: 'rechnung_post', child: Text('Per Post')),
                DropdownMenuItem(
                    value: 'heineken', child: Text('Via Heineken')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _rechnungsstellung = v);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Mein Kunde'),
              value: _istMeinKunde,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istMeinKunde = v),
            ),
            SwitchListTile(
              title: const Text('Bergkunde'),
              subtitle: const Text('+100 CHF Zuschlag'),
              value: _istBergkunde,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istBergkunde = v),
            ),
            SwitchListTile(
              title: const Text('Saisonbetrieb'),
              value: _istSaisonbetrieb,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istSaisonbetrieb = v),
            ),
            const SizedBox(height: 16),

            // === Notizen ===
            TextFormField(
              controller: _zugangController,
              decoration: const InputDecoration(
                labelText: 'Zugang / Schlüssel',
                prefixIcon: Icon(Icons.vpn_key),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
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
                  : Text(_isEdit ? 'Speichern' : 'Betrieb erstellen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
