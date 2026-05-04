import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/presentation/providers/preis_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:uuid/uuid.dart';

class PreisVersionFormScreen extends ConsumerStatefulWidget {
  final String? preisId;

  const PreisVersionFormScreen({super.key, this.preisId});

  @override
  ConsumerState<PreisVersionFormScreen> createState() =>
      _PreisVersionFormScreenState();
}

class _PreisVersionFormScreenState
    extends ConsumerState<PreisVersionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isReadOnly = false;

  DateTime _gueltigAb = DateTime.now();

  // MwSt
  final _mwstSatzCtrl = TextEditingController();
  final _mwstSatzRedCtrl = TextEditingController();

  // Heineken
  final _poNummerCtrl = TextEditingController();

  // Reinigung Grundtarife
  final _reinBierCtrl = TextEditingController();
  final _reinOrionCtrl = TextEditingController();
  final _reinHeigenieCtrl = TextEditingController();
  final _reinFremdCtrl = TextEditingController();
  final _reinWeinCtrl = TextEditingController();

  // Zusatz pro Hahn
  final _hahnEigenCtrl = TextEditingController();
  final _hahnOrionCtrl = TextEditingController();
  final _hahnFremdCtrl = TextEditingController();
  final _hahnWeinCtrl = TextEditingController();
  final _hahnAndererCtrl = TextEditingController();

  // Störungspreise Normal
  final _st1NCtrl = TextEditingController();
  final _st2NCtrl = TextEditingController();
  final _st3NCtrl = TextEditingController();
  final _st4NCtrl = TextEditingController();
  final _st5NCtrl = TextEditingController();
  // Störungspreise Bergkunde
  final _st1BCtrl = TextEditingController();
  final _st2BCtrl = TextEditingController();
  final _st3BCtrl = TextEditingController();
  final _st4BCtrl = TextEditingController();
  final _st5BCtrl = TextEditingController();

  // Anfahrt
  final _anfahrtPauschCtrl = TextEditingController();
  final _anfahrtKmGrCtrl = TextEditingController();
  final _anfahrtKmSatzCtrl = TextEditingController();
  final _weZuschlagCtrl = TextEditingController();

  // Weitere
  final _eigenauftragCtrl = TextEditingController();
  final _montageStdCtrl = TextEditingController();
  final _pikettPauschCtrl = TextEditingController();
  final _pikettFeiertagCtrl = TextEditingController();
  final _eroeffnungNCtrl = TextEditingController();
  final _eroeffnungBCtrl = TextEditingController();
  final _bergkundenZCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    Preis? vorlage;
    if (widget.preisId != null && widget.preisId != 'neu') {
      final alle = await PreisRepository.getAll();
      vorlage = alle.where((p) => p.id == widget.preisId).firstOrNull;
      _isReadOnly = true;
    } else {
      vorlage = await PreisRepository.getAktuell();
    }

    if (vorlage != null) {
      _fillFromPreis(vorlage);
    } else {
      _mwstSatzCtrl.text = '8.10';
      _mwstSatzRedCtrl.text = '2.60';
      _poNummerCtrl.text = '6100259429';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _fillFromPreis(Preis p) {
    _gueltigAb = _isReadOnly ? p.gueltigAb : DateTime.now();
    _mwstSatzCtrl.text = p.mwstSatz.toStringAsFixed(2);
    _mwstSatzRedCtrl.text = p.mwstSatzReduziert.toStringAsFixed(2);
    _poNummerCtrl.text = p.heinekenPoNummer ?? '';

    _reinBierCtrl.text = p.grundtarifReinigungBier.toStringAsFixed(2);
    _reinOrionCtrl.text = p.grundtarifReinigungOrion.toStringAsFixed(2);
    _reinHeigenieCtrl.text = p.grundtarifHeigenie.toStringAsFixed(2);
    _reinFremdCtrl.text = p.grundtarifReinigungFremd.toStringAsFixed(2);
    _reinWeinCtrl.text = p.grundtarifWein.toStringAsFixed(2);

    _hahnEigenCtrl.text = p.zusatzHahnEigen.toStringAsFixed(2);
    _hahnOrionCtrl.text = p.zusatzHahnOrion.toStringAsFixed(2);
    _hahnFremdCtrl.text = p.zusatzHahnFremd.toStringAsFixed(2);
    _hahnWeinCtrl.text = p.zusatzHahnWein.toStringAsFixed(2);
    _hahnAndererCtrl.text = p.zusatzHahnAndererStandort.toStringAsFixed(2);

    _st1NCtrl.text = p.stoerung1Normal.toStringAsFixed(2);
    _st2NCtrl.text = p.stoerung2Normal.toStringAsFixed(2);
    _st3NCtrl.text = p.stoerung3Normal.toStringAsFixed(2);
    _st4NCtrl.text = p.stoerung4Normal.toStringAsFixed(2);
    _st5NCtrl.text = p.stoerung5Normal.toStringAsFixed(2);
    _st1BCtrl.text = p.stoerung1Bergkunde.toStringAsFixed(2);
    _st2BCtrl.text = p.stoerung2Bergkunde.toStringAsFixed(2);
    _st3BCtrl.text = p.stoerung3Bergkunde.toStringAsFixed(2);
    _st4BCtrl.text = p.stoerung4Bergkunde.toStringAsFixed(2);
    _st5BCtrl.text = p.stoerung5Bergkunde.toStringAsFixed(2);

    _anfahrtPauschCtrl.text = p.stoerungAnfahrtPauschale.toStringAsFixed(2);
    _anfahrtKmGrCtrl.text = p.stoerungAnfahrtKmGrenze.toString();
    _anfahrtKmSatzCtrl.text = p.stoerungAnfahrtKmSatz.toStringAsFixed(3);
    _weZuschlagCtrl.text = p.stoerungWochenendeZuschlag.toStringAsFixed(2);

    _eigenauftragCtrl.text = p.eigenauftragPauschale.toStringAsFixed(2);
    _montageStdCtrl.text = p.montageStundensatz.toStringAsFixed(2);
    _pikettPauschCtrl.text = p.pikettPauschale.toStringAsFixed(2);
    _pikettFeiertagCtrl.text = p.pikettFeiertagZuschlag.toStringAsFixed(2);
    _eroeffnungNCtrl.text = p.eroeffnungPreisNormal.toStringAsFixed(2);
    _eroeffnungBCtrl.text = p.eroeffnungPreisBergkunde.toStringAsFixed(2);
    _bergkundenZCtrl.text = p.bergkundenZuschlag.toStringAsFixed(2);
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text) ?? 0;

  int _i(TextEditingController c) =>
      int.tryParse(c.text) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'id': const Uuid().v4(),
        'user_id': SupabaseService.dataUserId,
        'gueltig_ab': _gueltigAb.toIso8601String().split('T').first,
        'mwst_satz': _d(_mwstSatzCtrl),
        'mwst_satz_reduziert': _d(_mwstSatzRedCtrl),
        'heineken_po_nummer': _poNummerCtrl.text.trim().isEmpty
            ? null
            : _poNummerCtrl.text.trim(),
        'bergkunden_zuschlag': _d(_bergkundenZCtrl),
        'grundtarif_reinigung_bier': _d(_reinBierCtrl),
        'grundtarif_reinigung_orion': _d(_reinOrionCtrl),
        'grundtarif_heigenie': _d(_reinHeigenieCtrl),
        'grundtarif_reinigung_fremd': _d(_reinFremdCtrl),
        'grundtarif_wein': _d(_reinWeinCtrl),
        'zusatz_hahn_eigen': _d(_hahnEigenCtrl),
        'zusatz_hahn_orion': _d(_hahnOrionCtrl),
        'zusatz_hahn_fremd': _d(_hahnFremdCtrl),
        'zusatz_hahn_wein': _d(_hahnWeinCtrl),
        'zusatz_hahn_anderer_standort': _d(_hahnAndererCtrl),
        'eigenauftrag_pauschale': _d(_eigenauftragCtrl),
        'montage_stundensatz': _d(_montageStdCtrl),
        'pikett_pauschale': _d(_pikettPauschCtrl),
        'pikett_feiertag_zuschlag': _d(_pikettFeiertagCtrl),
        'eroeffnung_preis_normal': _d(_eroeffnungNCtrl),
        'eroeffnung_preis_bergkunde': _d(_eroeffnungBCtrl),
        'stoerung_1_normal': _d(_st1NCtrl),
        'stoerung_1_bergkunde': _d(_st1BCtrl),
        'stoerung_2_normal': _d(_st2NCtrl),
        'stoerung_2_bergkunde': _d(_st2BCtrl),
        'stoerung_3_normal': _d(_st3NCtrl),
        'stoerung_3_bergkunde': _d(_st3BCtrl),
        'stoerung_4_normal': _d(_st4NCtrl),
        'stoerung_4_bergkunde': _d(_st4BCtrl),
        'stoerung_5_normal': _d(_st5NCtrl),
        'stoerung_5_bergkunde': _d(_st5BCtrl),
        'stoerung_anfahrt_pauschale': _d(_anfahrtPauschCtrl),
        'stoerung_anfahrt_km_grenze': _i(_anfahrtKmGrCtrl),
        'stoerung_anfahrt_km_satz': _d(_anfahrtKmSatzCtrl),
        'stoerung_wochenende_zuschlag': _d(_weZuschlagCtrl),
      };

      await PreisRepository.save(data);
      ref.invalidate(aktuellePreiseProvider);
      ref.invalidate(allePreiseProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preisversion gespeichert')),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _gueltigAb,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _gueltigAb = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preisversion')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReadOnly
            ? 'Preisversion ${DateFormat('dd.MM.yyyy').format(_gueltigAb)}'
            : 'Neue Werte erfassen'),
        actions: [
          if (_isReadOnly)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Als neue Version kopieren',
              onPressed: () {
                setState(() {
                  _isReadOnly = false;
                  _gueltigAb = DateTime.now();
                });
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Gültig ab
            _FieldRow(
              label: 'Gültig ab',
              child: InkWell(
                onTap: _isReadOnly ? null : _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                    color: _isReadOnly ? Colors.grey.shade100 : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd.MM.yyyy').format(_gueltigAb),
                        style: const TextStyle(fontSize: 15),
                      ),
                      if (!_isReadOnly) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.edit_calendar,
                            size: 18, color: Colors.grey.shade600),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // MwSt
            _sectionHeader('MwSt-Sätze'),
            _numRow('Normal', _mwstSatzCtrl, suffix: '%'),
            _numRow('Reduziert', _mwstSatzRedCtrl, suffix: '%'),
            const SizedBox(height: 16),

            // Heineken
            _sectionHeader('Heineken'),
            _textRow('PO-Nummer', _poNummerCtrl),
            if (!_isReadOnly)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Kontakte werden unter Einstellungen → Heineken Kontakte verwaltet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 16),

            // Reinigung Grundtarife
            _sectionHeader('Reinigung Grundtarife'),
            _numRow('Bier', _reinBierCtrl),
            _numRow('Orion', _reinOrionCtrl),
            _numRow('Heigenie', _reinHeigenieCtrl),
            _numRow('Fremd', _reinFremdCtrl),
            _numRow('Wein', _reinWeinCtrl),
            const SizedBox(height: 16),

            // Zusatz pro Hahn
            _sectionHeader('Zusatz pro Hahn'),
            _numRow('Eigen', _hahnEigenCtrl),
            _numRow('Orion', _hahnOrionCtrl),
            _numRow('Fremd', _hahnFremdCtrl),
            _numRow('Wein', _hahnWeinCtrl),
            _numRow('Anderer Standort', _hahnAndererCtrl),
            const SizedBox(height: 16),

            // Störungspreise
            _sectionHeader('Störungspreise Normal'),
            for (int i = 0; i < 5; i++)
              _numRow(
                'Bereich ${i + 1}',
                [_st1NCtrl, _st2NCtrl, _st3NCtrl, _st4NCtrl, _st5NCtrl][i],
              ),
            const SizedBox(height: 12),
            _sectionHeader('Störungspreise Bergkunde'),
            for (int i = 0; i < 5; i++)
              _numRow(
                'Bereich ${i + 1}',
                [_st1BCtrl, _st2BCtrl, _st3BCtrl, _st4BCtrl, _st5BCtrl][i],
              ),
            const SizedBox(height: 16),

            // Anfahrt
            _sectionHeader('Störung Anfahrt'),
            _numRow('Pauschale', _anfahrtPauschCtrl),
            _numRow('km-Grenze', _anfahrtKmGrCtrl, isInt: true),
            _numRow('km-Satz', _anfahrtKmSatzCtrl),
            _numRow('WE-Zuschlag', _weZuschlagCtrl),
            const SizedBox(height: 16),

            // Weitere
            _sectionHeader('Weitere Preise'),
            _numRow('Eigenauftrag', _eigenauftragCtrl),
            _numRow('Montage/Std.', _montageStdCtrl),
            _numRow('Pikett', _pikettPauschCtrl),
            _numRow('Pikett Feiertag', _pikettFeiertagCtrl),
            _numRow('Eröffnung Normal', _eroeffnungNCtrl),
            _numRow('Eröffnung Bergk.', _eroeffnungBCtrl),
            _numRow('Bergkunden-Zuschlag', _bergkundenZCtrl),
            const SizedBox(height: 24),

            if (!_isReadOnly)
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('Speichern'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _numRow(String label, TextEditingController ctrl,
      {String? suffix, bool isInt = false}) {
    return _FieldRow(
      label: label,
      child: SizedBox(
        width: 120,
        child: TextFormField(
          controller: ctrl,
          readOnly: _isReadOnly,
          textAlign: TextAlign.right,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            filled: _isReadOnly,
            fillColor: _isReadOnly ? Colors.grey.shade100 : null,
            suffixText: suffix ?? 'CHF',
            suffixStyle:
                TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Pflicht';
            if (isInt) {
              if (int.tryParse(v) == null) return 'Ganzzahl';
            } else {
              if (double.tryParse(v) == null) return 'Zahl';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _textRow(String label, TextEditingController ctrl) {
    return _FieldRow(
      label: label,
      child: Expanded(
        child: TextFormField(
          controller: ctrl,
          readOnly: _isReadOnly,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            filled: _isReadOnly,
            fillColor: _isReadOnly ? Colors.grey.shade100 : null,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mwstSatzCtrl.dispose();
    _mwstSatzRedCtrl.dispose();
    _poNummerCtrl.dispose();
    _reinBierCtrl.dispose();
    _reinOrionCtrl.dispose();
    _reinHeigenieCtrl.dispose();
    _reinFremdCtrl.dispose();
    _reinWeinCtrl.dispose();
    _hahnEigenCtrl.dispose();
    _hahnOrionCtrl.dispose();
    _hahnFremdCtrl.dispose();
    _hahnWeinCtrl.dispose();
    _hahnAndererCtrl.dispose();
    _st1NCtrl.dispose();
    _st2NCtrl.dispose();
    _st3NCtrl.dispose();
    _st4NCtrl.dispose();
    _st5NCtrl.dispose();
    _st1BCtrl.dispose();
    _st2BCtrl.dispose();
    _st3BCtrl.dispose();
    _st4BCtrl.dispose();
    _st5BCtrl.dispose();
    _anfahrtPauschCtrl.dispose();
    _anfahrtKmGrCtrl.dispose();
    _anfahrtKmSatzCtrl.dispose();
    _weZuschlagCtrl.dispose();
    _eigenauftragCtrl.dispose();
    _montageStdCtrl.dispose();
    _pikettPauschCtrl.dispose();
    _pikettFeiertagCtrl.dispose();
    _eroeffnungNCtrl.dispose();
    _eroeffnungBCtrl.dispose();
    _bergkundenZCtrl.dispose();
    super.dispose();
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
