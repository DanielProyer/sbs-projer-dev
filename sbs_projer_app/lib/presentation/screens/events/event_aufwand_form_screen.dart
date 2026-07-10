import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/event_aufwand_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_aufwand_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

const kAufwandKategorien = <String, String>{
  'anfahrt': 'Anfahrt',
  'inbetriebnahme': 'Inbetriebnahme',
  'pikett': 'Pikettdienst',
  'spesen': 'Spesen',
};

/// Formular zum Anlegen/Bearbeiten einer Zeit-/Spesen-Zeile (E4).
class EventAufwandFormScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String? aufwandId; // null = neu

  const EventAufwandFormScreen({
    super.key,
    required this.eventId,
    this.aufwandId,
  });

  @override
  ConsumerState<EventAufwandFormScreen> createState() =>
      _EventAufwandFormScreenState();
}

class _EventAufwandFormScreenState
    extends ConsumerState<EventAufwandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialLoading = false;
  EventAufwandLocal? _existing;

  DateTime _datum = DateTime.now();
  String _kategorie = 'pikett';
  final _notizController = TextEditingController();
  final _stundenController = TextEditingController();

  bool get _isEdit => widget.aufwandId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _initialLoading = true;
      _loadAufwand();
    }
  }

  Future<void> _loadAufwand() async {
    try {
      final list = await EventAufwandRepository.getByEvent(widget.eventId);
      final a = list
          .where((e) => e.routeId == widget.aufwandId)
          .cast<EventAufwandLocal?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (a == null || !mounted) {
        if (mounted) setState(() => _initialLoading = false);
        return;
      }
      setState(() {
        _existing = a;
        _datum = a.datum;
        _kategorie = a.kategorie;
        _notizController.text = a.notiz ?? '';
        _stundenController.text = a.stunden.toStringAsFixed(2);
        _initialLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _datumWaehlen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _datum = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final a = _existing ?? EventAufwandLocal();
      if (!_isEdit) a.eventId = widget.eventId;
      a.datum = DateTime(_datum.year, _datum.month, _datum.day);
      a.kategorie = _kategorie;
      final notiz = _notizController.text.trim();
      a.notiz = notiz.isEmpty ? null : notiz;
      a.stunden = double.tryParse(_stundenController.text.replaceAll(',', '.')) ?? 0;
      await EventAufwandRepository.save(a);

      ref.invalidate(eventAufwaendeProvider(widget.eventId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Zeit aktualisiert' : 'Zeit erfasst')),
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
    _notizController.dispose();
    _stundenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Zeit bearbeiten' : 'Zeit erfassen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _datumWaehlen,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Datum',
                  prefixIcon: Icon(Icons.event),
                ),
                child: Text(_ddMMyyyy(_datum)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kategorie,
              decoration: const InputDecoration(
                labelText: 'Kategorie *',
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                for (final e in kAufwandKategorien.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kategorie = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notizController,
              decoration: const InputDecoration(
                labelText: 'Notiz',
                prefixIcon: Icon(Icons.note),
                hintText: 'z.B. 10:00–02:00 oder Essen CHF 120',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stundenController,
              decoration: const InputDecoration(
                labelText: 'Stunden *',
                prefixIcon: Icon(Icons.schedule),
                suffixText: 'h',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Stunden > 0 erforderlich';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Speichern' : 'Zeit erfassen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

String _zwei(int v) => v.toString().padLeft(2, '0');
String _ddMMyyyy(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';
