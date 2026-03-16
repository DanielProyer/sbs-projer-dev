import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BierleitungFormScreen extends ConsumerStatefulWidget {
  final String anlageId;
  final String? bierleitungId;

  const BierleitungFormScreen({
    super.key,
    required this.anlageId,
    this.bierleitungId,
  });

  @override
  ConsumerState<BierleitungFormScreen> createState() =>
      _BierleitungFormScreenState();
}

class _BierleitungFormScreenState
    extends ConsumerState<BierleitungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  BierleitungLocal? _existing;

  late final _biersorreController = TextEditingController();
  late final _hahnTypController = TextEditingController();
  late final _niederdruckBarController = TextEditingController();

  int _leitungsNummer = 1;
  bool _hatFobStop = false;
  String? _selectedHahnTyp;
  List<String> _biersortenVorschlaege = [];

  static const _hahnTypen = [
    'Adimat',
    'BuyToSell',
    'Celli FC2 (Standart)',
    'Celli FC4',
    'Celli Celtic (Guiness)',
    'Celli BT',
    'Celli Foreline (Guiness)',
    'Eurostar (silber)',
    'Eurostar (gold)',
    'Anderer',
  ];

  static const _defaultBiersorten = [
    'Heineken',
    'Eichhof',
    'Feldschlösschen',
    'Appenzeller',
    'Chopfab',
    'Erdinger',
    'Guinness',
    'Paulaner',
    'Strongbow',
  ];

  bool get _isEdit => widget.bierleitungId != null;

  @override
  void initState() {
    super.initState();
    _loadBiersorten();
    if (_isEdit) {
      _loadBierleitung();
    } else {
      _autoSelectNummer();
    }
  }

  Future<void> _loadBiersorten() async {
    try {
      final rows = await SupabaseService.client
          .from('bierleitungen')
          .select('biersorte')
          .eq('user_id', SupabaseService.dataUserId)
          .not('biersorte', 'is', null);
      final dbSorten = rows
          .map<String>((r) => r['biersorte'] as String)
          .where((s) => s.trim().isNotEmpty)
          .toSet();
      final alle = {..._defaultBiersorten, ...dbSorten}.toList()..sort();
      if (mounted) setState(() => _biersortenVorschlaege = alle);
    } catch (_) {
      if (mounted) setState(() => _biersortenVorschlaege = [..._defaultBiersorten]);
    }
  }

  Future<void> _autoSelectNummer() async {
    final existing = await BierleitungRepository.getByAnlage(widget.anlageId);
    if (!mounted) return;
    final usedNumbers = existing.map((l) => l.leitungsNummer).toSet();
    for (int i = 1; i <= 4; i++) {
      if (!usedNumbers.contains(i)) {
        setState(() => _leitungsNummer = i);
        return;
      }
    }
  }

  Future<void> _loadBierleitung() async {
    final leitung =
        await BierleitungRepository.getById(widget.bierleitungId!);
    if (leitung == null || !mounted) return;

    final hahnTyp = leitung.hahnTyp ?? '';
    String? selectedHahn;
    if (_hahnTypen.contains(hahnTyp)) {
      selectedHahn = hahnTyp;
    } else if (hahnTyp.isNotEmpty) {
      selectedHahn = 'Anderer';
    }

    setState(() {
      _existing = leitung;
      _leitungsNummer = leitung.leitungsNummer;
      _biersorreController.text = leitung.biersorte ?? '';
      _selectedHahnTyp = selectedHahn;
      _hahnTypController.text = selectedHahn == 'Anderer' ? hahnTyp : '';
      _niederdruckBarController.text =
          leitung.niederdruckBar?.toString() ?? '';
      _hatFobStop = leitung.hatFobStop;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final leitung = _existing ?? BierleitungLocal();
      leitung.anlageId = widget.anlageId;
      leitung.leitungsNummer = _leitungsNummer;
      leitung.biersorte = _emptyToNull(_biersorreController.text);
      leitung.hahnTyp = _selectedHahnTyp == 'Anderer'
          ? _emptyToNull(_hahnTypController.text)
          : _selectedHahnTyp;
      leitung.niederdruckBar =
          double.tryParse(_niederdruckBarController.text.trim());
      leitung.hatFobStop = _hatFobStop;

      await BierleitungRepository.save(leitung);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Bierleitung aktualisiert'
                : 'Bierleitung erstellt'),
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
    _biersorreController.dispose();
    _hahnTypController.dispose();
    _niederdruckBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEdit ? 'Bierleitung bearbeiten' : 'Neue Bierleitung'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Leitungs-Nummer ===
            DropdownButtonFormField<int>(
              initialValue: _leitungsNummer,
              decoration: const InputDecoration(
                labelText: 'Leitungs-Nummer *',
                prefixIcon: Icon(Icons.format_list_numbered),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Leitung 1')),
                DropdownMenuItem(value: 2, child: Text('Leitung 2')),
                DropdownMenuItem(value: 3, child: Text('Leitung 3')),
                DropdownMenuItem(value: 4, child: Text('Leitung 4')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _leitungsNummer = v);
              },
            ),
            const SizedBox(height: 12),

            // === Biersorte (Autocomplete) ===
            Autocomplete<String>(
              initialValue: _biersorreController.value,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _biersortenVorschlaege;
                }
                final query = textEditingValue.text.toLowerCase();
                return _biersortenVorschlaege
                    .where((s) => s.toLowerCase().contains(query));
              },
              onSelected: (value) => _biersorreController.text = value,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync mit unserem Controller
                controller.text = _biersorreController.text;
                controller.addListener(() {
                  if (_biersorreController.text != controller.text) {
                    _biersorreController.text = controller.text;
                  }
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Biersorte',
                    prefixIcon: Icon(Icons.local_drink),
                    hintText: 'z.B. Heineken, Eichhof',
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => onSubmitted(),
                );
              },
            ),
            const SizedBox(height: 12),

            // === Hahn-Typ ===
            DropdownButtonFormField<String>(
              value: _selectedHahnTyp,
              decoration: const InputDecoration(
                labelText: 'Hahn-Typ',
                prefixIcon: Icon(Icons.plumbing),
              ),
              items: _hahnTypen
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedHahnTyp = v;
                if (v != 'Anderer') _hahnTypController.text = '';
              }),
            ),
            if (_selectedHahnTyp == 'Anderer') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _hahnTypController,
                decoration: const InputDecoration(
                  labelText: 'Hahn-Typ (Freitext)',
                  prefixIcon: Icon(Icons.edit),
                ),
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 12),

            // === Niederdruck ===
            TextFormField(
              controller: _niederdruckBarController,
              decoration: const InputDecoration(
                labelText: 'Niederdruck (bar)',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),

            // === FOB-Stop ===
            SwitchListTile(
              title: const Text('FOB-Stop'),
              subtitle: const Text('Foam on Beer Stop vorhanden'),
              value: _hatFobStop,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _hatFobStop = v),
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
                  : Text(
                      _isEdit ? 'Speichern' : 'Bierleitung erstellen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
