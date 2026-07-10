import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/event_einsatz_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/event_einsatz_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

/// Formular zum Anlegen/Bearbeiten eines Pikett-Einsatzes: Beschreibung,
/// Material, optionaler Stand und Zeitpunkt (Datum + Zeit).
class EventEinsatzFormScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String? einsatzId; // null = neu

  const EventEinsatzFormScreen({
    super.key,
    required this.eventId,
    this.einsatzId,
  });

  @override
  ConsumerState<EventEinsatzFormScreen> createState() =>
      _EventEinsatzFormScreenState();
}

class _EventEinsatzFormScreenState
    extends ConsumerState<EventEinsatzFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialLoading = false;
  EventEinsatzLocal? _existing;

  final _beschreibungController = TextEditingController();
  final _materialController = TextEditingController();
  String? _standId;
  DateTime _zeitpunkt = DateTime.now();

  List<Lager> _lagerItems = [];
  Lager? _selectedLager;
  String? _existingMaterialId; // aus geladenem Einsatz, bis Lager geladen
  final _mengeController = TextEditingController();

  bool get _isEdit => widget.einsatzId != null;

  @override
  void initState() {
    super.initState();
    _loadLager();
    if (_isEdit) {
      _initialLoading = true;
      _loadEinsatz();
    }
  }

  Future<void> _loadLager() async {
    try {
      final items = await LagerRepository.getAll();
      if (!mounted) return;
      setState(() {
        _lagerItems = items;
        _resolveLager();
      });
    } catch (_) {}
  }

  void _resolveLager() {
    if (_existingMaterialId == null) return;
    final match = _lagerItems.where((l) => l.id == _existingMaterialId);
    if (match.isNotEmpty) _selectedLager = match.first;
  }

  Future<void> _loadEinsatz() async {
    try {
      final einsaetze =
          await EventEinsatzRepository.getByEvent(widget.eventId);
      final einsatz = einsaetze
          .where((e) => e.routeId == widget.einsatzId)
          .cast<EventEinsatzLocal?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (einsatz == null || !mounted) {
        if (mounted) setState(() => _initialLoading = false);
        return;
      }
      setState(() {
        _existing = einsatz;
        _beschreibungController.text = einsatz.beschreibung;
        _materialController.text = einsatz.material ?? '';
        _standId = einsatz.standId;
        _zeitpunkt = einsatz.zeitpunkt.toLocal();
        _existingMaterialId = einsatz.materialId;
        _mengeController.text = einsatz.materialMenge?.toString() ?? '';
        _resolveLager();
        _initialLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _zeitpunktWaehlen() async {
    final datum = await showDatePicker(
      context: context,
      initialDate: _zeitpunkt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (datum == null || !mounted) return;
    final zeit = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_zeitpunkt),
    );
    if (zeit == null || !mounted) return;
    setState(() {
      _zeitpunkt = DateTime(
        datum.year,
        datum.month,
        datum.day,
        zeit.hour,
        zeit.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final einsatz = _existing ?? EventEinsatzLocal();
      if (!_isEdit) {
        einsatz.eventId = widget.eventId;
      }
      einsatz.standId = _standId;
      einsatz.zeitpunkt = _zeitpunkt.toUtc();
      einsatz.beschreibung = _beschreibungController.text.trim();
      final material = _materialController.text.trim();
      einsatz.material = material.isEmpty ? null : material;
      einsatz.materialId = _selectedLager?.id;
      einsatz.materialMenge = _selectedLager != null
          ? (double.tryParse(_mengeController.text.replaceAll(',', '.')) ?? 0)
          : null;
      await EventEinsatzRepository.save(einsatz);

      // Bestand nur beim ANLEGEN abbuchen (keine Storno-Automatik bei Bearbeiten).
      if (!_isEdit &&
          _selectedLager != null &&
          (einsatz.materialMenge ?? 0) > 0) {
        final neu = _selectedLager!.bestandAktuell - einsatz.materialMenge!;
        await LagerRepository.update(
            _selectedLager!.id, {'bestand_aktuell': neu});
      }

      ref.invalidate(eventEinsaetzeProvider(widget.eventId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isEdit ? 'Einsatz aktualisiert' : 'Einsatz erfasst')),
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
  void dispose() {
    _beschreibungController.dispose();
    _materialController.dispose();
    _mengeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final staendeAsync = ref.watch(eventStaendeProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Einsatz bearbeiten' : 'Neuer Einsatz'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _beschreibungController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung *',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Beschreibung erforderlich'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _materialController,
              decoration: const InputDecoration(
                labelText: 'Material',
                prefixIcon: Icon(Icons.build),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            if (_lagerItems.isNotEmpty)
              Autocomplete<Lager>(
                initialValue:
                    TextEditingValue(text: _selectedLager?.name ?? ''),
                displayStringForOption: (l) => l.name,
                optionsBuilder: (v) {
                  if (v.text.isEmpty) return _lagerItems.take(15);
                  final q = v.text.toLowerCase();
                  return _lagerItems
                      .where((l) => l.name.toLowerCase().contains(q));
                },
                onSelected: (l) => setState(() => _selectedLager = l),
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Lager-Artikel (optional)',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      suffixIcon: _selectedLager != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                controller.clear();
                                setState(() => _selectedLager = null);
                              },
                            )
                          : null,
                    ),
                    onChanged: (t) {
                      if (t.isEmpty && _selectedLager != null) {
                        setState(() => _selectedLager = null);
                      }
                    },
                  );
                },
              ),
            if (_selectedLager != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _mengeController,
                decoration: InputDecoration(
                  labelText: 'Menge',
                  prefixIcon: const Icon(Icons.numbers),
                  suffixText: _selectedLager!.einheit,
                  helperText:
                      'Bestand aktuell: ${_selectedLager!.bestandAktuell.toStringAsFixed(0)} ${_selectedLager!.einheit}',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 16),
            staendeAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Fehler beim Laden der Stände: $e'),
              data: (staende) {
                // Gewählter Stand könnte gelöscht sein → auf null zurückfallen.
                final gueltig = _standId != null &&
                    staende.any((s) => s.serverId == _standId);
                return DropdownButtonFormField<String?>(
                  initialValue: gueltig ? _standId : null,
                  decoration: const InputDecoration(
                    labelText: 'Stand',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— (kein Stand)'),
                    ),
                    for (final s in staende)
                      DropdownMenuItem<String?>(
                        value: s.serverId,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _standId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _zeitpunktWaehlen,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Zeitpunkt',
                  prefixIcon: Icon(Icons.schedule),
                ),
                child: Text(_ddMMyyyyHHmm(_zeitpunkt)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : 'Einsatz erfassen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

String _zwei(int v) => v.toString().padLeft(2, '0');

String _ddMMyyyyHHmm(DateTime d) =>
    '${_zwei(d.day)}.${_zwei(d.month)}.${d.year} ${_zwei(d.hour)}:${_zwei(d.minute)}';
