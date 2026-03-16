import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/eigenauftrag_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';

class EigenauftragFormScreen extends ConsumerStatefulWidget {
  final String? eigenauftragId;
  final String? betriebId;

  const EigenauftragFormScreen({
    super.key,
    this.eigenauftragId,
    this.betriebId,
  });

  @override
  ConsumerState<EigenauftragFormScreen> createState() =>
      _EigenauftragFormScreenState();
}

class _EigenauftragFormScreenState
    extends ConsumerState<EigenauftragFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  EigenauftragLocal? _existing;

  // Felder
  String? _betriebId;
  String _betriebSearchText = '';
  late DateTime _datum;
  late final _stoerungsnummerController = TextEditingController();
  late final _beschreibungController = TextEditingController();
  late final _anzahlController = TextEditingController(text: '1');
  String _status = 'behoben';

  // Material
  List<Lager> _lagerItems = [];
  final _materialControllers = List.generate(3, (_) => TextEditingController());
  final _materialMengenControllers =
      List.generate(3, (_) => TextEditingController(text: '1'));
  final _materialIds = List<String?>.filled(3, null);

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _betriebId = widget.betriebId;
    _loadLager();
    if (widget.eigenauftragId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadLager() async {
    try {
      final items = await LagerRepository.getAll();
      if (mounted) setState(() => _lagerItems = items);
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    final ea = await EigenauftragRepository.getById(widget.eigenauftragId!);
    if (ea == null || !mounted) return;
    setState(() {
      _existing = ea;
      _betriebId = ea.betriebId;
      _datum = ea.datum;
      _stoerungsnummerController.text = ea.stoerungsnummer;
      _beschreibungController.text = ea.problemBeschreibung;
      _status = ea.status;

      // Anzahl aus Pauschale berechnen (pauschale / 30)
      if (ea.pauschale != null && ea.pauschale! > 0) {
        _anzahlController.text =
            (ea.pauschale! / 30.0).round().toString();
      }

      // Material laden
      final ids = [ea.material1Id, ea.material2Id, ea.material3Id];
      final mengen = [ea.material1Menge, ea.material2Menge, ea.material3Menge];
      for (int i = 0; i < 3; i++) {
        _materialIds[i] = ids[i];
        if (mengen[i] != null) {
          _materialMengenControllers[i].text =
              mengen[i]!.toStringAsFixed(0);
        }
      }
    });

    // Material-Namen laden
    for (int i = 0; i < 3; i++) {
      if (_materialIds[i] != null) {
        try {
          final lager = await LagerRepository.getById(_materialIds[i]!);
          if (lager != null && mounted) {
            _materialControllers[i].text = lager.name;
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _stoerungsnummerController.dispose();
    _beschreibungController.dispose();
    _anzahlController.dispose();
    for (final c in _materialControllers) {
      c.dispose();
    }
    for (final c in _materialMengenControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eigenauftragId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Eigenauftrag bearbeiten' : 'Neuer Eigenauftrag'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Betrieb
            _buildBetriebField(),
            const SizedBox(height: 16),

            // Störungsnummer
            TextFormField(
              controller: _stoerungsnummerController,
              decoration: const InputDecoration(
                labelText: 'Störungsnummer (Heineken) *',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 16),

            // Datum
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Datum'),
              subtitle: Text(_formatDate(_datum)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Beschreibung
            TextFormField(
              controller: _beschreibungController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung *',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 16),

            // Anzahl + Preis
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anzahlController,
                    decoration: const InputDecoration(
                      labelText: 'Anzahl *',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Pflichtfeld';
                      final n = int.tryParse(v);
                      if (n == null || n < 1) return 'Min. 1';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPreisPreview(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status (nur bei Bearbeiten)
            if (isEdit) ...[
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'behoben', child: Text('Behoben')),
                  DropdownMenuItem(
                      value: 'nicht_behebbar',
                      child: Text('Nicht behebbar')),
                  DropdownMenuItem(
                      value: 'nachbearbeitung_noetig',
                      child: Text('Nachbearbeitung nötig')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 16),
            ],

            // Material
            const Text('Material',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ..._buildMaterialSlots(),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // Speichern
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(isEdit ? 'Speichern' : 'Eigenauftrag erfassen'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildBetriebField() {
    final betriebe = ref
        .watch(betriebeProvider)
        .where((b) => b.serverId != null)
        .toList();

    // Aktuellen Betrieb-Namen finden
    if (_betriebId != null && _betriebSearchText.isEmpty) {
      final match = betriebe.where((b) => b.serverId == _betriebId).toList();
      if (match.isNotEmpty) {
        _betriebSearchText = match.first.name;
      }
    }

    return Autocomplete<BetriebLocal>(
      initialValue: TextEditingValue(text: _betriebSearchText),
      displayStringForOption: (b) => b.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return betriebe;
        final query = textEditingValue.text.toLowerCase();
        return betriebe.where((b) => b.name.toLowerCase().contains(query));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Betrieb *',
            prefixIcon: Icon(Icons.store),
          ),
          validator: (_) =>
              _betriebId == null ? 'Bitte Betrieb auswählen' : null,
          onChanged: (v) {
            if (v.isEmpty) {
              setState(() {
                _betriebId = null;
                _betriebSearchText = '';
              });
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final b = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(b.name),
                    subtitle: b.ort != null ? Text(b.ort!) : null,
                    onTap: () => onSelected(b),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (b) {
        setState(() {
          _betriebId = b.serverId;
          _betriebSearchText = b.name;
        });
      },
    );
  }

  Widget _buildPreisPreview() {
    final anzahl = int.tryParse(_anzahlController.text) ?? 0;
    final total = anzahl * 30.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text('$anzahl × 30 CHF',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('${total.toStringAsFixed(2)} CHF',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  List<Widget> _buildMaterialSlots() {
    return List.generate(3, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _lagerItems.isNotEmpty
                  ? Autocomplete<Lager>(
                      initialValue:
                          TextEditingValue(text: _materialControllers[i].text),
                      displayStringForOption: (l) => l.name,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return [];
                        final query = textEditingValue.text.toLowerCase();
                        return _lagerItems
                            .where((l) =>
                                l.name.toLowerCase().contains(query) ||
                                (l.dboNr?.toLowerCase().contains(query) ??
                                    false))
                            .take(10);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                        _materialControllers[i] = controller;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Material ${i + 1}',
                            isDense: true,
                          ),
                        );
                      },
                      onSelected: (l) {
                        setState(() => _materialIds[i] = l.id);
                      },
                    )
                  : TextFormField(
                      controller: _materialControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Material ${i + 1}',
                        isDense: true,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextFormField(
                controller: _materialMengenControllers[i],
                decoration:
                    const InputDecoration(labelText: 'Anz.', isDense: true),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _datum = picked);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final ea = _existing ?? EigenauftragLocal();
      ea.betriebId = _betriebId;
      ea.stoerungsnummer = _stoerungsnummerController.text.trim();
      ea.datum = _datum;
      ea.problemBeschreibung = _beschreibungController.text.trim();
      ea.status = _status;

      // Preis
      final anzahl = int.tryParse(_anzahlController.text) ?? 1;
      ea.pauschale = anzahl * 30.0;

      // Material
      final matIds = [null, null, null] as List<String?>;
      final matMengen = [null, null, null] as List<double?>;
      for (int i = 0; i < 3; i++) {
        if (_materialIds[i] != null) {
          matIds[i] = _materialIds[i];
          matMengen[i] =
              double.tryParse(_materialMengenControllers[i].text) ?? 1;
        } else if (_materialControllers[i].text.isNotEmpty) {
          // Freitext — kein Lager-Link
          matMengen[i] =
              double.tryParse(_materialMengenControllers[i].text) ?? 1;
        }
      }
      ea.material1Id = matIds[0];
      ea.material1Menge = matMengen[0];
      ea.material2Id = matIds[1];
      ea.material2Menge = matMengen[1];
      ea.material3Id = matIds[2];
      ea.material3Menge = matMengen[2];

      await EigenauftragRepository.save(ea);
      ref.invalidate(eigenauftraegeStreamProvider);

      if (mounted) context.pop();
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
}
