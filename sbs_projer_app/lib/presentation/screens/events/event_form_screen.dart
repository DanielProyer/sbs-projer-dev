import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

/// Formular zum Anlegen/Bearbeiten eines Event-Jahres (E1).
/// Bei Neu-Anlage optional Kontakte aus dem Vorjahres-Event übernehmen.
class EventFormScreen extends ConsumerStatefulWidget {
  final String? eventId;

  const EventFormScreen({super.key, this.eventId});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  EventLocal? _existing;

  late final _jahrCtrl = TextEditingController(text: '${DateTime.now().year}');
  late final _notizenCtrl = TextEditingController();

  String? _betriebId;
  DateTime? _terminVon;
  DateTime? _terminBis;

  /// Jüngstes Event des Betriebs mit kleinerem Jahr (nur bei Neu-Anlage).
  EventLocal? _vorjahrEvent;
  bool _uebernehmeVorjahr = true;
  int _vorjahrCheckToken = 0;

  bool get _isEdit => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadEvent();
  }

  Future<void> _loadEvent() async {
    final event = await EventRepository.getById(widget.eventId!);
    if (event == null || !mounted) return;

    setState(() {
      _existing = event;
      _betriebId = event.betriebId;
      _jahrCtrl.text = '${event.jahr}';
      _terminVon = event.terminVon;
      _terminBis = event.terminBis;
      _notizenCtrl.text = event.notizen ?? '';
    });
  }

  /// Prüft (nur bei Neu-Anlage), ob zum gewählten Betrieb ein Event mit
  /// kleinerem Jahr existiert — bei Betrieb-/Jahr-Änderung neu aufrufen.
  Future<void> _pruefeVorjahr() async {
    if (_isEdit) return;
    final betriebId = _betriebId;
    final jahr = int.tryParse(_jahrCtrl.text.trim());
    final token = ++_vorjahrCheckToken;
    if (betriebId == null || jahr == null) {
      if (mounted) setState(() => _vorjahrEvent = null);
      return;
    }

    final vorjahr = await EventRepository.getVorjahr(betriebId, jahr);
    if (!mounted || token != _vorjahrCheckToken) return;

    setState(() {
      // Bei neuer Quelle Checkbox wieder auf Default (angehakt) setzen
      if (vorjahr?.serverId != _vorjahrEvent?.serverId) {
        _uebernehmeVorjahr = true;
      }
      _vorjahrEvent = vorjahr;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_betriebId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bitte Veranstaltungs-Betrieb wählen')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final jahr = int.parse(_jahrCtrl.text.trim());

      // Duplikat-Schutz: pro Betrieb und Jahr genau ein Event
      // (UNIQUE-Constraint nicht in die DB crashen lassen)
      final alle = await EventRepository.getAll();
      final duplikat = alle.any((e) =>
          e.betriebId == _betriebId &&
          e.jahr == jahr &&
          (_existing == null || e.serverId != _existing!.serverId));
      if (duplikat) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Für diesen Betrieb existiert $jahr bereits ein Event')),
          );
        }
        return;
      }

      final e = _existing ?? EventLocal();
      e.betriebId = _betriebId!;
      e.jahr = jahr;
      e.terminVon = _terminVon;
      e.terminBis = _terminBis;
      e.notizen = _notizenCtrl.text.trim().isEmpty
          ? null
          : _notizenCtrl.text.trim();
      await EventRepository.save(e);

      var uebernommen = -1;
      if (!_isEdit && _uebernehmeVorjahr && _vorjahrEvent != null) {
        uebernommen = await EventKontaktRepository.uebernehmeVon(
            _vorjahrEvent!.serverId!, e.serverId!);
      }

      ref.invalidate(eventsProvider);

      if (mounted) {
        if (uebernommen >= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$uebernommen Kontakte übernommen')),
          );
        }
        if (_isEdit) {
          context.pop();
        } else {
          context.pushReplacement('/events/${e.routeId}');
        }
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
    _jahrCtrl.dispose();
    _notizenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final betriebe = ref.watch(betriebeProvider);
    // Nur Veranstaltungs-Betriebe (zapfsysteme enthält exakt 'Veranstaltungen')
    final veranstaltungsBetriebe = betriebe
        .where((b) =>
            b.serverId != null && b.zapfsysteme.contains('Veranstaltungen'))
        .toList();
    final betriebNamen = ref.watch(betriebNameMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Event bearbeiten' : 'Neues Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Betrieb: bei Bearbeiten read-only, bei Neu-Anlage Dropdown
            if (_isEdit)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Veranstaltungs-Betrieb',
                  prefixIcon: Icon(Icons.festival),
                ),
                child: Text(
                  betriebNamen[_betriebId] ?? 'Unbekannter Betrieb',
                ),
              )
            else if (veranstaltungsBetriebe.isEmpty)
              Card(
                color: AppColors.warning.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Kein Veranstaltungs-Betrieb vorhanden — zuerst '
                          'Betrieb mit Zapfsystem ‹Veranstaltungen› anlegen',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _betriebId,
                decoration: const InputDecoration(
                  labelText: 'Veranstaltungs-Betrieb *',
                  prefixIcon: Icon(Icons.festival),
                ),
                items: veranstaltungsBetriebe
                    .map((b) => DropdownMenuItem(
                          value: b.serverId,
                          child: Text(
                            b.ort != null && b.ort!.isNotEmpty
                                ? '${b.name} (${b.ort})'
                                : b.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                validator: (v) =>
                    v == null ? 'Betrieb ist erforderlich' : null,
                onChanged: (v) {
                  setState(() => _betriebId = v);
                  _pruefeVorjahr();
                },
              ),
            const SizedBox(height: 12),

            // Jahr
            TextFormField(
              controller: _jahrCtrl,
              decoration: const InputDecoration(
                labelText: 'Jahr *',
                prefixIcon: Icon(Icons.calendar_month),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final jahr = int.tryParse(v?.trim() ?? '');
                if (jahr == null || jahr < 2020 || jahr > 2100) {
                  return 'Jahr zwischen 2020 und 2100';
                }
                return null;
              },
              onChanged: (_) => _pruefeVorjahr(),
            ),
            const SizedBox(height: 12),

            // Termin von/bis
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'Termin von',
                    value: _terminVon,
                    onChanged: (v) => setState(() => _terminVon = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: 'Termin bis',
                    value: _terminBis,
                    onChanged: (v) => setState(() => _terminBis = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

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

            // Vorjahres-Übernahme (nur Neu-Anlage, wenn Vorjahres-Event da)
            if (!_isEdit && _vorjahrEvent != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Kontakte aus '
                  '‹${betriebNamen[_vorjahrEvent!.betriebId] ?? 'Betrieb'} '
                  '${_vorjahrEvent!.jahr}› übernehmen',
                ),
                value: _uebernehmeVorjahr,
                onChanged: (v) =>
                    setState(() => _uebernehmeVorjahr = v ?? false),
              ),
            ],
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
                  : Text(_isEdit ? 'Speichern' : 'Event erstellen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Datums-Feld mit DatePicker (Muster aus betrieb_form_screen.dart).
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
        : '';
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
              ),
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 18),
              onPressed: () => _pick(context),
            ),
          ],
        ),
      ),
      controller: TextEditingController(text: text),
      onTap: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) onChanged(picked);
  }
}
