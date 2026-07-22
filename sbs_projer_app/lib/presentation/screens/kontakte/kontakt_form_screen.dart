import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/kontakt.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class KontaktFormScreen extends ConsumerStatefulWidget {
  final String? kontaktId;
  final String? initialKategorie;
  final String? initialBetriebId;

  const KontaktFormScreen({
    super.key,
    this.kontaktId,
    this.initialKategorie,
    this.initialBetriebId,
  });

  @override
  ConsumerState<KontaktFormScreen> createState() => _KontaktFormScreenState();
}

class _KontaktFormScreenState extends ConsumerState<KontaktFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  KontaktLocal? _existing;

  late final _vornameCtrl = TextEditingController();
  late final _nachnameCtrl = TextEditingController();
  late final _telefonCtrl = TextEditingController();
  late final _emailCtrl = TextEditingController();
  late final _notizenCtrl = TextEditingController();

  String _kategorie = 'betrieb';
  String? _rolle;
  String? _betriebId;
  bool _istHauptkontakt = false;
  bool _istDuAnrede = false;
  String _kontaktMethode = 'telefon';

  bool get _isEdit => widget.kontaktId != null;

  @override
  void initState() {
    super.initState();
    _kategorie = widget.initialKategorie ?? 'betrieb';
    _betriebId = widget.initialBetriebId;
    if (_isEdit) _loadKontakt();
  }

  Future<void> _loadKontakt() async {
    final kontakt = await KontaktRepository.getById(widget.kontaktId!);
    if (kontakt == null || !mounted) return;

    setState(() {
      _existing = kontakt;
      _vornameCtrl.text = kontakt.vorname;
      _nachnameCtrl.text = kontakt.nachname ?? '';
      _telefonCtrl.text = kontakt.telefon ?? '';
      _emailCtrl.text = kontakt.email ?? '';
      _notizenCtrl.text = kontakt.notizen ?? '';
      _kategorie = kontakt.kategorie;
      _rolle = kontakt.rolle;
      _betriebId = kontakt.betriebId;
      _istHauptkontakt = kontakt.istHauptkontakt;
      _istDuAnrede = kontakt.istDuAnrede;
      _kontaktMethode = kontakt.kontaktMethode;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final kontakt = _existing ?? KontaktLocal();
      kontakt.vorname = _vornameCtrl.text.trim();
      kontakt.nachname = _emptyToNull(_nachnameCtrl.text);
      kontakt.telefon = _emptyToNull(_telefonCtrl.text);
      kontakt.email = _emptyToNull(_emailCtrl.text);
      kontakt.notizen = _emptyToNull(_notizenCtrl.text);
      kontakt.kategorie = _kategorie;
      kontakt.rolle = _rolle;
      kontakt.betriebId = _kategorie == 'betrieb' ? _betriebId : null;
      kontakt.istHauptkontakt = _istHauptkontakt;
      kontakt.istDuAnrede = _istDuAnrede;
      kontakt.kontaktMethode = _kontaktMethode;

      // Telefon normalisieren
      if (kontakt.telefon != null) {
        kontakt.telefonNormalized =
            kontakt.telefon!.replaceAll(RegExp(r'[^\d+]'), '');
      }

      await KontaktRepository.save(kontakt);
      ref.invalidate(kontakteProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isEdit ? 'Kontakt aktualisiert' : 'Kontakt erstellt')),
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
    _vornameCtrl.dispose();
    _nachnameCtrl.dispose();
    _telefonCtrl.dispose();
    _emailCtrl.dispose();
    _notizenCtrl.dispose();
    super.dispose();
  }

  Widget _buildBetriebAutocomplete(List<BetriebLocal> betriebe) {
    final filtered = betriebe.where((b) => b.serverId != null).toList();
    final currentName = _betriebId != null
        ? filtered
            .where((b) => b.serverId == _betriebId)
            .map((b) => b.name)
            .firstOrNull
        : null;

    return Autocomplete<BetriebLocal>(
      initialValue: currentName != null
          ? TextEditingValue(text: currentName)
          : TextEditingValue.empty,
      displayStringForOption: (b) => b.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return filtered.take(20);
        final query = textEditingValue.text.toLowerCase();
        return filtered.where((b) =>
            b.name.toLowerCase().contains(query) ||
            (b.ort?.toLowerCase().contains(query) ?? false));
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Betrieb suchen',
            prefixIcon: const Icon(Icons.store),
            suffixIcon: _betriebId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      setState(() => _betriebId = null);
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final b = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(b.name),
                    subtitle: b.ort != null
                        ? Text(b.ort!, style: const TextStyle(fontSize: 12))
                        : null,
                    onTap: () => onSelected(b),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (b) => setState(() => _betriebId = b.serverId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final betriebe = ref.watch(betriebeProvider);
    final rollen = Kontakt.rollenFuerKategorie(_kategorie);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Kontakt bearbeiten' : 'Neuer Kontakt'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kategorie
            DropdownButtonFormField<String>(
              initialValue: _kategorie,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'betrieb', child: Text('Betrieb')),
                DropdownMenuItem(value: 'heineken', child: Text('Heineken')),
                DropdownMenuItem(value: 'event', child: Text('Event')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _kategorie = v;
                  _rolle = null; // Rolle zurücksetzen bei Kategorie-Wechsel
                });
              },
            ),
            const SizedBox(height: 12),

            // Betrieb (nur bei Kategorie betrieb)
            if (_kategorie == 'betrieb') ...[
              _buildBetriebAutocomplete(betriebe),
              const SizedBox(height: 12),
            ],

            // Rolle
            if (rollen.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _rolle,
                decoration: const InputDecoration(
                  labelText: 'Rolle',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: rollen
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(Kontakt.rolleLabelStatic(r)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _rolle = v),
              ),
            if (rollen.isNotEmpty) const SizedBox(height: 12),

            // Name
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vornameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vorname *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Vorname ist erforderlich'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nachnameCtrl,
                    decoration: const InputDecoration(labelText: 'Nachname'),
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Telefon
            TextFormField(
              controller: _telefonCtrl,
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

            // E-Mail
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                  return 'Ungültige E-Mail-Adresse';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Du/Sie
            Row(
              children: [
                const Text('Anrede: '),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sie')),
                    ButtonSegment(value: true, label: Text('Du')),
                  ],
                  selected: {_istDuAnrede},
                  onSelectionChanged: (v) =>
                      setState(() => _istDuAnrede = v.first),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hauptkontakt (nur Betrieb)
            if (_kategorie == 'betrieb')
              SwitchListTile(
                title: const Text('Hauptkontakt'),
                subtitle: const Text('Primärer Ansprechpartner'),
                value: _istHauptkontakt,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _istHauptkontakt = v),
              ),

            // Kontaktmethode (nur Betrieb)
            if (_kategorie == 'betrieb') ...[
              DropdownButtonFormField<String>(
                initialValue: _kontaktMethode,
                decoration: const InputDecoration(
                  labelText: 'Bevorzugte Kontaktmethode',
                  prefixIcon: Icon(Icons.contact_phone),
                ),
                items: const [
                  DropdownMenuItem(value: 'telefon', child: Text('Telefon')),
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'email', child: Text('E-Mail')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _kontaktMethode = v);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Notizen
            TextFormField(
              controller: _notizenCtrl,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // Speichern
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
