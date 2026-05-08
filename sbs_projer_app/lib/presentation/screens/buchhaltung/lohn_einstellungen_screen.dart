import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/lohn_repository.dart';
import 'package:sbs_projer_app/presentation/providers/lohn_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class LohnEinstellungenScreen extends ConsumerStatefulWidget {
  const LohnEinstellungenScreen({super.key});

  @override
  ConsumerState<LohnEinstellungenScreen> createState() =>
      _LohnEinstellungenScreenState();
}

class _LohnEinstellungenScreenState
    extends ConsumerState<LohnEinstellungenScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _jahr;
  bool _saving = false;
  bool _loaded = false;

  final _geburtsjahr = TextEditingController();

  // Sätze
  final _ahvAnCtrl = TextEditingController(text: '5.30');
  final _ahvAgCtrl = TextEditingController(text: '5.30');
  final _alvAnCtrl = TextEditingController(text: '1.10');
  final _alvAgCtrl = TextEditingController(text: '1.10');
  final _nbuAnCtrl = TextEditingController(text: '1.40');
  final _buAgCtrl = TextEditingController(text: '0.70');
  final _bvgAnCtrl = TextEditingController(text: '0.00');
  final _bvgAgCtrl = TextEditingController(text: '0.00');
  final _fakAgCtrl = TextEditingController(text: '1.35');
  final _ktgAnCtrl = TextEditingController(text: '0.00');
  final _ktgAgCtrl = TextEditingController(text: '0.00');

  // Lohnausweis
  final _nameCtrl = TextEditingController();
  final _vornameCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _plzOrtCtrl = TextEditingController();
  final _ahvNrCtrl = TextEditingController();
  final _gebDatumCtrl = TextEditingController();
  final _agNameCtrl = TextEditingController(text: 'SBS Projer GmbH');
  final _agAdresseCtrl = TextEditingController();
  final _agPlzOrtCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _jahr = DateTime.now().year;
  }

  @override
  void dispose() {
    for (final c in [
      _geburtsjahr, _ahvAnCtrl, _ahvAgCtrl,
      _alvAnCtrl, _alvAgCtrl, _nbuAnCtrl, _buAgCtrl,
      _bvgAnCtrl, _bvgAgCtrl, _fakAgCtrl, _ktgAnCtrl, _ktgAgCtrl,
      _nameCtrl, _vornameCtrl, _adresseCtrl, _plzOrtCtrl,
      _ahvNrCtrl, _gebDatumCtrl, _agNameCtrl, _agAdresseCtrl, _agPlzOrtCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFromEinstellungen(LohnEinstellungen e) {
    _geburtsjahr.text = e.geburtsjahr.toString();
    _ahvAnCtrl.text = e.ahvIvEoAnSatz.toStringAsFixed(2);
    _ahvAgCtrl.text = e.ahvIvEoAgSatz.toStringAsFixed(2);
    _alvAnCtrl.text = e.alvAnSatz.toStringAsFixed(2);
    _alvAgCtrl.text = e.alvAgSatz.toStringAsFixed(2);
    _nbuAnCtrl.text = e.nbuAnSatz.toStringAsFixed(2);
    _buAgCtrl.text = e.buAgSatz.toStringAsFixed(2);
    _bvgAnCtrl.text = e.bvgAnBetrag.toStringAsFixed(2);
    _bvgAgCtrl.text = e.bvgAgBetrag.toStringAsFixed(2);
    _fakAgCtrl.text = e.fakAgSatz.toStringAsFixed(2);
    _ktgAnCtrl.text = e.ktgAnSatz.toStringAsFixed(2);
    _ktgAgCtrl.text = e.ktgAgSatz.toStringAsFixed(2);
    _nameCtrl.text = e.arbeitnehmerName ?? '';
    _vornameCtrl.text = e.arbeitnehmerVorname ?? '';
    _adresseCtrl.text = e.arbeitnehmerAdresse ?? '';
    _plzOrtCtrl.text = e.arbeitnehmerPlzOrt ?? '';
    _ahvNrCtrl.text = e.arbeitnehmerAhvNr ?? '';
    _gebDatumCtrl.text = e.arbeitnehmerGeburtsdatum != null
        ? '${e.arbeitnehmerGeburtsdatum!.day.toString().padLeft(2, '0')}.${e.arbeitnehmerGeburtsdatum!.month.toString().padLeft(2, '0')}.${e.arbeitnehmerGeburtsdatum!.year}'
        : '';
    _agNameCtrl.text = e.arbeitgeberName ?? 'SBS Projer GmbH';
    _agAdresseCtrl.text = e.arbeitgeberAdresse ?? '';
    _agPlzOrtCtrl.text = e.arbeitgeberPlzOrt ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final einst = ref.watch(lohnEinstellungenProvider(_jahr));

    einst.whenData((e) {
      if (!_loaded && e != null) {
        _fillFromEinstellungen(e);
        _loaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lohn-Einstellungen'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _jahr,
            onSelected: (j) {
              setState(() {
                _jahr = j;
                _loaded = false;
              });
              ref.invalidate(lohnEinstellungenProvider(_jahr));
            },
            itemBuilder: (ctx) {
              final now = DateTime.now().year;
              return [
                for (int y = now + 1; y >= now - 2; y--)
                  PopupMenuItem(value: y, child: Text('$y')),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_jahr',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: einst.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (_) => _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Grunddaten'),
          _numberField(_geburtsjahr, 'Geburtsjahr', decimal: false),

          const SizedBox(height: 24),
          _sectionHeader('Sozialversicherungen — Sätze (%)'),
          _rateRow('AHV/IV/EO', _ahvAnCtrl, _ahvAgCtrl),
          _rateRow('ALV', _alvAnCtrl, _alvAgCtrl),
          _rateRowSingle('NBU (AN)', _nbuAnCtrl),
          _rateRowSingle('BU/UVG (AG)', _buAgCtrl, isAg: true),
          _rateRowSingle('FAK (AG)', _fakAgCtrl, isAg: true),
          _rateRow('KTG', _ktgAnCtrl, _ktgAgCtrl),

          const SizedBox(height: 24),
          _sectionHeader('BVG / Pensionskasse — Fixbeträge (CHF/Mt)'),
          _rateRow('BVG', _bvgAnCtrl, _bvgAgCtrl, isBetrag: true),

          const SizedBox(height: 24),
          _sectionHeader('Lohnausweis — Arbeitnehmer'),
          _textField(_nameCtrl, 'Name'),
          _textField(_vornameCtrl, 'Vorname'),
          _textField(_adresseCtrl, 'Adresse'),
          _textField(_plzOrtCtrl, 'PLZ / Ort'),
          _textField(_ahvNrCtrl, 'AHV-Nr. (756.xxxx.xxxx.xx)'),
          _textField(_gebDatumCtrl, 'Geburtsdatum (TT.MM.JJJJ)'),

          const SizedBox(height: 24),
          _sectionHeader('Lohnausweis — Arbeitgeber'),
          _textField(_agNameCtrl, 'Firmenname'),
          _textField(_agAdresseCtrl, 'Adresse'),
          _textField(_agPlzOrtCtrl, 'PLZ / Ort'),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: const Text('Speichern'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  Widget _numberField(TextEditingController ctrl, String label,
      {bool required = false, bool decimal = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType:
            TextInputType.numberWithOptions(decimal: decimal),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Pflichtfeld' : null
            : null,
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _rateRow(String label, TextEditingController anCtrl,
      TextEditingController agCtrl,
      {bool isBetrag = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: TextFormField(
              controller: anCtrl,
              decoration: InputDecoration(
                labelText: isBetrag ? 'AN (CHF)' : 'AN (%)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: agCtrl,
              decoration: InputDecoration(
                labelText: isBetrag ? 'AG (CHF)' : 'AG (%)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateRowSingle(String label, TextEditingController ctrl,
      {bool isAg = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          if (!isAg) ...[
            Expanded(
              child: TextFormField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'AN (%)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ] else ...[
            const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'AG (%)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  DateTime? _parseDatum(String text) {
    if (text.isEmpty) return null;
    final parts = text.split('.');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final e = LohnEinstellungen(
        id: '',
        userId: SupabaseService.dataUserId,
        jahr: _jahr,
        geburtsjahr: int.tryParse(_geburtsjahr.text) ?? 1990,
        ahvIvEoAnSatz: double.tryParse(_ahvAnCtrl.text) ?? 5.30,
        ahvIvEoAgSatz: double.tryParse(_ahvAgCtrl.text) ?? 5.30,
        alvAnSatz: double.tryParse(_alvAnCtrl.text) ?? 1.10,
        alvAgSatz: double.tryParse(_alvAgCtrl.text) ?? 1.10,
        nbuAnSatz: double.tryParse(_nbuAnCtrl.text) ?? 1.40,
        buAgSatz: double.tryParse(_buAgCtrl.text) ?? 0.70,
        bvgAnBetrag: double.tryParse(_bvgAnCtrl.text) ?? 0,
        bvgAgBetrag: double.tryParse(_bvgAgCtrl.text) ?? 0,
        fakAgSatz: double.tryParse(_fakAgCtrl.text) ?? 1.35,
        ktgAnSatz: double.tryParse(_ktgAnCtrl.text) ?? 0,
        ktgAgSatz: double.tryParse(_ktgAgCtrl.text) ?? 0,
        arbeitnehmerName:
            _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
        arbeitnehmerVorname:
            _vornameCtrl.text.isEmpty ? null : _vornameCtrl.text,
        arbeitnehmerAdresse:
            _adresseCtrl.text.isEmpty ? null : _adresseCtrl.text,
        arbeitnehmerPlzOrt:
            _plzOrtCtrl.text.isEmpty ? null : _plzOrtCtrl.text,
        arbeitnehmerAhvNr:
            _ahvNrCtrl.text.isEmpty ? null : _ahvNrCtrl.text,
        arbeitnehmerGeburtsdatum: _parseDatum(_gebDatumCtrl.text),
        arbeitgeberName:
            _agNameCtrl.text.isEmpty ? null : _agNameCtrl.text,
        arbeitgeberAdresse:
            _agAdresseCtrl.text.isEmpty ? null : _agAdresseCtrl.text,
        arbeitgeberPlzOrt:
            _agPlzOrtCtrl.text.isEmpty ? null : _agPlzOrtCtrl.text,
      );

      await LohnRepository.saveEinstellungen(e);
      ref.invalidate(lohnEinstellungenProvider(_jahr));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lohn-Einstellungen gespeichert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
