import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_artikel.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_artikel_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_kategorie_repository.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';

class MaterialFormScreen extends ConsumerStatefulWidget {
  final String? materialId;

  const MaterialFormScreen({super.key, this.materialId});

  @override
  ConsumerState<MaterialFormScreen> createState() =>
      _MaterialFormScreenState();
}

class _MaterialFormScreenState extends ConsumerState<MaterialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Lager? _existing;

  final _nameController = TextEditingController();
  final _beschreibungController = TextEditingController();
  final _bestandAktuellController = TextEditingController(text: '0');
  final _bestandMindestController = TextEditingController(text: '5');
  final _bestandOptimalController = TextEditingController(text: '10');
  final _notizenController = TextEditingController();

  String _einheit = 'Stück';
  String? _kategorieId;
  String? _materialId;
  String? _dboNr;
  String? _linkedArtikelName;

  List<MaterialKategorie> _kategorien = [];

  bool get _isEdit => widget.materialId != null;

  @override
  void initState() {
    super.initState();
    _loadKategorien();
    if (_isEdit) _loadMaterial();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _beschreibungController.dispose();
    _bestandAktuellController.dispose();
    _bestandMindestController.dispose();
    _bestandOptimalController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  Future<void> _loadKategorien() async {
    final kategorien = await MaterialKategorieRepository.getAll();
    if (mounted) setState(() => _kategorien = kategorien);
  }

  Future<void> _loadMaterial() async {
    final lager = await LagerRepository.getById(widget.materialId!);
    if (lager == null || !mounted) return;
    setState(() {
      _existing = lager;
      _nameController.text = lager.name;
      _beschreibungController.text = lager.beschreibung ?? '';
      _einheit = lager.einheit;
      _kategorieId = lager.kategorieId;
      _materialId = lager.materialId;
      _dboNr = lager.dboNr;
      _bestandAktuellController.text =
          lager.bestandAktuell.toStringAsFixed(0);
      _bestandMindestController.text =
          lager.bestandMindest.toStringAsFixed(0);
      _bestandOptimalController.text =
          lager.bestandOptimal.toStringAsFixed(0);
      _notizenController.text = lager.notizen ?? '';
    });
  }

  String? _emptyToNull(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final json = <String, dynamic>{
        'name': _nameController.text.trim(),
        'beschreibung': _emptyToNull(_beschreibungController.text),
        'einheit': _einheit,
        'kategorie_id': _kategorieId,
        'material_id': _materialId,
        'dbo_nr': _dboNr,
        'bestand_aktuell':
            double.tryParse(_bestandAktuellController.text) ?? 0,
        'bestand_mindest':
            double.tryParse(_bestandMindestController.text) ?? 5,
        'bestand_optimal':
            double.tryParse(_bestandOptimalController.text) ?? 10,
        'notizen': _emptyToNull(_notizenController.text),
      };

      if (_isEdit) {
        await LagerRepository.update(_existing!.id, json);
      } else {
        await LagerRepository.create(json);
      }

      if (mounted) {
        ref.invalidate(materialienStreamProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _isEdit ? 'Material aktualisiert' : 'Material erstellt')),
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

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Material bearbeiten' : 'Neues Material'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name eingeben' : null,
            ),
            const SizedBox(height: 12),

            // Beschreibung
            TextFormField(
              controller: _beschreibungController,
              decoration:
                  const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Kategorie
            DropdownButtonFormField<String>(
              value: _kategorieId,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Keine Kategorie')),
                ..._kategorien.map((k) => DropdownMenuItem(
                      value: k.id,
                      child: Text(k.name),
                    )),
              ],
              onChanged: (v) => setState(() => _kategorieId = v),
            ),
            const SizedBox(height: 12),

            // Einheit
            DropdownButtonFormField<String>(
              value: _einheit,
              decoration: const InputDecoration(labelText: 'Einheit'),
              items: const [
                DropdownMenuItem(value: 'Stück', child: Text('Stück')),
                DropdownMenuItem(value: 'Liter', child: Text('Liter')),
                DropdownMenuItem(value: 'Meter', child: Text('Meter')),
                DropdownMenuItem(
                    value: 'Kilogramm', child: Text('Kilogramm')),
                DropdownMenuItem(
                    value: 'Packung', child: Text('Packung')),
                DropdownMenuItem(value: 'Set', child: Text('Set')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _einheit = v);
              },
            ),
            const SizedBox(height: 16),

            // Bestand
            Text('Bestand',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bestandAktuellController,
                    decoration:
                        const InputDecoration(labelText: 'Aktuell'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bestandMindestController,
                    decoration:
                        const InputDecoration(labelText: 'Mindest'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bestandOptimalController,
                    decoration:
                        const InputDecoration(labelText: 'Optimal'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Heineken-Artikel
            Text('Heineken-Artikel',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_dboNr != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(_linkedArtikelName ?? _dboNr!),
                  subtitle: Text('DBO ${_dboNr}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _materialId = null;
                      _dboNr = null;
                      _linkedArtikelName = null;
                    }),
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _showArtikelPicker,
                icon: const Icon(Icons.search),
                label: const Text('Heineken-Artikel verknüpfen'),
              ),
            const SizedBox(height: 16),

            // Notizen
            TextFormField(
              controller: _notizenController,
              decoration: const InputDecoration(labelText: 'Notizen'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Save
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : 'Erstellen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showArtikelPicker() async {
    final result = await showDialog<MaterialArtikel>(
      context: context,
      builder: (ctx) => const _ArtikelPickerDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        _materialId = result.id;
        _dboNr = result.dboNr;
        _linkedArtikelName = result.name;
        if (_nameController.text.isEmpty) {
          _nameController.text = result.name;
        }
        if (_kategorieId == null && result.kategorieId != null) {
          _kategorieId = result.kategorieId;
        }
      });
    }
  }
}

class _ArtikelPickerDialog extends StatefulWidget {
  const _ArtikelPickerDialog();

  @override
  State<_ArtikelPickerDialog> createState() => _ArtikelPickerDialogState();
}

class _ArtikelPickerDialogState extends State<_ArtikelPickerDialog> {
  String _query = '';
  List<MaterialArtikel>? _results;
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await MaterialArtikelRepository.search(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Heineken-Artikel suchen'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'DBO-Nr. oder Name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                _query = v;
                _search(v);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results == null
                      ? const Center(
                          child: Text('Mindestens 2 Zeichen eingeben'))
                      : _results!.isEmpty
                          ? const Center(child: Text('Keine Ergebnisse'))
                          : ListView.builder(
                              itemCount: _results!.length,
                              itemBuilder: (context, index) {
                                final a = _results![index];
                                return ListTile(
                                  dense: true,
                                  title: Text(a.name,
                                      style:
                                          const TextStyle(fontSize: 13)),
                                  subtitle: Text('DBO ${a.dboNr}',
                                      style:
                                          const TextStyle(fontSize: 11)),
                                  onTap: () =>
                                      Navigator.of(context).pop(a),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}
