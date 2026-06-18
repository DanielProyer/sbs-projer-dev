import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/lohn_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/lohn_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';
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

  @override
  void initState() {
    super.initState();
    _jahr = DateTime.now().year;
  }

  @override
  void dispose() {
    for (final c in [
      _ahvAnCtrl, _ahvAgCtrl,
      _alvAnCtrl, _alvAgCtrl, _nbuAnCtrl, _buAgCtrl,
      _bvgAnCtrl, _bvgAgCtrl, _fakAgCtrl, _ktgAnCtrl, _ktgAgCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFromEinstellungen(LohnEinstellungen e) {
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
  }

  @override
  Widget build(BuildContext context) {
    final einst = ref.watch(lohnEinstellungenProvider(_jahr));

    if (!_loaded && !einst.isLoading) {
      final e = einst.valueOrNull;
      if (e != null) _fillFromEinstellungen(e);
      _loaded = true;
    }

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
                for (int y = now + 1; y >= 2019; y--)
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final geschaeft = ref.read(geschaeftProvider).valueOrNull ?? const GeschaeftEinstellungen();
      final an = GeschaeftMapping.arbeitnehmer(geschaeft);
      final ag = GeschaeftMapping.arbeitgeber(geschaeft);
      final e = LohnEinstellungen(
        id: '',
        userId: SupabaseService.dataUserId,
        jahr: _jahr,
        geburtsjahr: an.geburtsjahr,
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
        arbeitnehmerName: an.name,
        arbeitnehmerVorname: an.vorname,
        arbeitnehmerAdresse: an.adresse,
        arbeitnehmerPlzOrt: an.plzOrt,
        arbeitnehmerAhvNr: an.ahvNr,
        arbeitnehmerGeburtsdatum: an.geburtsdatum,
        arbeitgeberName: ag.name,
        arbeitgeberAdresse: ag.adresse,
        arbeitgeberPlzOrt: ag.plzOrt,
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
