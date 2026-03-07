import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/anlage_local.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';

class AnlageFormScreen extends ConsumerStatefulWidget {
  final int? anlageId; // null = neu erstellen
  final String? betriebId; // für neue Anlage: Zuordnung zum Betrieb

  const AnlageFormScreen({super.key, this.anlageId, this.betriebId});

  @override
  ConsumerState<AnlageFormScreen> createState() => _AnlageFormScreenState();
}

class _AnlageFormScreenState extends ConsumerState<AnlageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  AnlageLocal? _existing;

  // Controller
  late final _bezeichnungController = TextEditingController();
  late final _seriennummerController = TextEditingController();
  late final _typSaeuleController = TextEditingController();
  late final _durchlaufkuehlerController = TextEditingController();
  late final _gasTyp1Controller = TextEditingController();
  late final _gasTyp2Controller = TextEditingController();
  late final _hauptdruckController = TextEditingController();
  late final _serviceMorgenAbController = TextEditingController();
  late final _serviceMorgenBisController = TextEditingController();
  late final _serviceNachmittagAbController = TextEditingController();
  late final _serviceNachmittagBisController = TextEditingController();
  late final _notizenController = TextEditingController();

  // State
  String _typAnlage = 'Warmanstich';
  int _anzahlHaehne = 1;
  bool _backpython = false;
  bool _booster = false;
  String _vorkuehler = 'keiner';
  bool _hatNiederdruck = false;
  String _reinigungRhythmus = '4-Wochen';
  String _status = 'aktiv';

  bool get _isEdit => widget.anlageId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadAnlage();
  }

  Future<void> _loadAnlage() async {
    final anlage = await AnlageRepository.getById(widget.anlageId!);
    if (anlage == null || !mounted) return;

    setState(() {
      _existing = anlage;
      _bezeichnungController.text = anlage.bezeichnung ?? '';
      _seriennummerController.text = anlage.seriennummer ?? '';
      _typSaeuleController.text = anlage.typSaeule ?? '';
      _durchlaufkuehlerController.text = anlage.durchlaufkuehler ?? '';
      _gasTyp1Controller.text = anlage.gasTyp1 ?? '';
      _gasTyp2Controller.text = anlage.gasTyp2 ?? '';
      _hauptdruckController.text =
          anlage.hauptdruckBar?.toString() ?? '';
      _serviceMorgenAbController.text = anlage.servicezeitMorgenAb ?? '';
      _serviceMorgenBisController.text = anlage.servicezeitMorgenBis ?? '';
      _serviceNachmittagAbController.text =
          anlage.servicezeitNachmittagAb ?? '';
      _serviceNachmittagBisController.text =
          anlage.servicezeitNachmittagBis ?? '';
      _notizenController.text = anlage.notizen ?? '';
      _typAnlage = anlage.typAnlage;
      _anzahlHaehne = anlage.anzahlHaehne;
      _backpython = anlage.backpython;
      _booster = anlage.booster;
      _vorkuehler = anlage.vorkuehler;
      _hatNiederdruck = anlage.hatNiederdruck;
      _reinigungRhythmus = anlage.reinigungRhythmus;
      _status = anlage.status;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final anlage = _existing ?? AnlageLocal();

      // BetriebId setzen (bei Neu über Parameter, bei Edit bleibt erhalten)
      if (!_isEdit) {
        anlage.betriebId = widget.betriebId!;
      }

      anlage.bezeichnung = _emptyToNull(_bezeichnungController.text);
      anlage.seriennummer = _emptyToNull(_seriennummerController.text);
      anlage.typAnlage = _typAnlage;
      anlage.typSaeule = _emptyToNull(_typSaeuleController.text);
      anlage.anzahlHaehne = _anzahlHaehne;
      anlage.backpython = _backpython;
      anlage.booster = _booster;
      anlage.vorkuehler = _vorkuehler;
      anlage.durchlaufkuehler =
          _emptyToNull(_durchlaufkuehlerController.text);
      anlage.gasTyp1 = _emptyToNull(_gasTyp1Controller.text);
      anlage.gasTyp2 = _emptyToNull(_gasTyp2Controller.text);
      anlage.hauptdruckBar =
          double.tryParse(_hauptdruckController.text.trim());
      anlage.hatNiederdruck = _hatNiederdruck;
      anlage.servicezeitMorgenAb =
          _emptyToNull(_serviceMorgenAbController.text);
      anlage.servicezeitMorgenBis =
          _emptyToNull(_serviceMorgenBisController.text);
      anlage.servicezeitNachmittagAb =
          _emptyToNull(_serviceNachmittagAbController.text);
      anlage.servicezeitNachmittagBis =
          _emptyToNull(_serviceNachmittagBisController.text);
      anlage.reinigungRhythmus = _reinigungRhythmus;
      anlage.status = _status;
      anlage.notizen = _emptyToNull(_notizenController.text);

      await AnlageRepository.save(anlage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isEdit ? 'Anlage aktualisiert' : 'Anlage erstellt'),
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
    _bezeichnungController.dispose();
    _seriennummerController.dispose();
    _typSaeuleController.dispose();
    _durchlaufkuehlerController.dispose();
    _gasTyp1Controller.dispose();
    _gasTyp2Controller.dispose();
    _hauptdruckController.dispose();
    _serviceMorgenAbController.dispose();
    _serviceMorgenBisController.dispose();
    _serviceNachmittagAbController.dispose();
    _serviceNachmittagBisController.dispose();
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
        title: Text(_isEdit ? 'Anlage bearbeiten' : 'Neue Anlage'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Grunddaten ===
            _sectionTitle(context, 'Grunddaten'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _typAnlage,
              decoration: const InputDecoration(
                labelText: 'Anlage-Typ *',
                prefixIcon: Icon(Icons.precision_manufacturing),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Warmanstich', child: Text('Warmanstich')),
                DropdownMenuItem(
                    value: 'Kaltanstich', child: Text('Kaltanstich')),
                DropdownMenuItem(
                    value: 'Buffetanstich', child: Text('Buffetanstich')),
                DropdownMenuItem(value: 'Orion', child: Text('Orion')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _typAnlage = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bezeichnungController,
              decoration: const InputDecoration(
                labelText: 'Bezeichnung',
                prefixIcon: Icon(Icons.label),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _seriennummerController,
              decoration: const InputDecoration(
                labelText: 'Seriennummer',
                prefixIcon: Icon(Icons.tag),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _typSaeuleController,
              decoration: const InputDecoration(
                labelText: 'Säulen-Typ',
                prefixIcon: Icon(Icons.view_column),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Anzahl Hähne: '),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _anzahlHaehne > 1
                      ? () => setState(() => _anzahlHaehne--)
                      : null,
                ),
                Text(
                  '$_anzahlHaehne',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _anzahlHaehne++),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Kühlung & Gas ===
            _sectionTitle(context, 'Kühlung & Gas'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _vorkuehler,
              decoration: const InputDecoration(
                labelText: 'Vorkühler',
                prefixIcon: Icon(Icons.ac_unit),
              ),
              items: const [
                DropdownMenuItem(value: 'keiner', child: Text('Keiner')),
                DropdownMenuItem(value: 'nass', child: Text('Nasskühler')),
                DropdownMenuItem(
                    value: 'trocken', child: Text('Trockenkühler')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _vorkuehler = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durchlaufkuehlerController,
              decoration: const InputDecoration(
                labelText: 'Durchlaufkühler',
                prefixIcon: Icon(Icons.kitchen),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Backpython'),
              value: _backpython,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _backpython = v),
            ),
            SwitchListTile(
              title: const Text('Booster'),
              value: _booster,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _booster = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gasTyp1Controller,
                    decoration:
                        const InputDecoration(labelText: 'Gas Typ 1'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gasTyp2Controller,
                    decoration:
                        const InputDecoration(labelText: 'Gas Typ 2'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hauptdruckController,
              decoration: const InputDecoration(
                labelText: 'Hauptdruck (bar)',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
            ),
            SwitchListTile(
              title: const Text('Niederdruck vorhanden'),
              value: _hatNiederdruck,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _hatNiederdruck = v),
            ),
            const SizedBox(height: 16),

            // === Servicezeiten ===
            _sectionTitle(context, 'Servicezeiten'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _serviceMorgenAbController,
                    decoration:
                        const InputDecoration(labelText: 'Morgen ab'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _serviceMorgenBisController,
                    decoration:
                        const InputDecoration(labelText: 'Morgen bis'),
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
                    controller: _serviceNachmittagAbController,
                    decoration:
                        const InputDecoration(labelText: 'Nachmittag ab'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _serviceNachmittagBisController,
                    decoration:
                        const InputDecoration(labelText: 'Nachmittag bis'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Reinigung ===
            _sectionTitle(context, 'Reinigung'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _reinigungRhythmus,
              decoration: const InputDecoration(
                labelText: 'Reinigung-Rhythmus',
                prefixIcon: Icon(Icons.cleaning_services),
              ),
              items: const [
                DropdownMenuItem(
                    value: '2-Wochen', child: Text('2-Wochen')),
                DropdownMenuItem(
                    value: '4-Wochen', child: Text('4-Wochen')),
                DropdownMenuItem(
                    value: '6-Wochen', child: Text('6-Wochen')),
                DropdownMenuItem(
                    value: '8-Wochen', child: Text('8-Wochen')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _reinigungRhythmus = v);
              },
            ),
            const SizedBox(height: 16),

            // === Einstellungen ===
            _sectionTitle(context, 'Einstellungen'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.circle),
              ),
              items: const [
                DropdownMenuItem(value: 'aktiv', child: Text('Aktiv')),
                DropdownMenuItem(
                    value: 'inaktiv', child: Text('Inaktiv')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),

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
                  : Text(_isEdit ? 'Speichern' : 'Anlage erstellen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
