import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/erinnerung_util.dart';
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';

/// Betriebs-Anzeige inkl. Ort zur Unterscheidung gleichnamiger Betriebe
/// (z.B. "Calanda, Chur" vs. "Calanda, Felsberg").
String _betriebLabel(BetriebLocal b) {
  final ort = b.ort?.trim() ?? '';
  return ort.isEmpty ? b.name : '${b.name}, $ort';
}

class TerminFormScreen extends ConsumerStatefulWidget {
  final String? terminId;
  final String? betriebId;
  final String? datum;

  const TerminFormScreen({
    super.key,
    this.terminId,
    this.betriebId,
    this.datum,
  });

  @override
  ConsumerState<TerminFormScreen> createState() => _TerminFormScreenState();
}

class _TerminFormScreenState extends ConsumerState<TerminFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  TerminLocal? _existing;

  // Felder
  String? _betriebId;
  late DateTime _datum;
  TimeOfDay? _uhrzeitVon;
  TimeOfDay? _uhrzeitBis;
  String _typ = 'sonstiges';
  String _anlass = 'manuell';
  late final _titelController = TextEditingController();
  late final _notizenController = TextEditingController();
  String _status = 'geplant';
  int _erinnerungTage = 3;
  int _erinnerungVorlauf = 1440;
  List<TerminErinnerung> _erinnerungen = [];

  bool get _isEditing => widget.terminId != null;

  @override
  void initState() {
    super.initState();
    _datum = widget.datum != null
        ? DateTime.tryParse(widget.datum!) ?? DateTime.now()
        : DateTime.now();
    _betriebId = widget.betriebId;
    if (_isEditing) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _titelController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final termin = await TerminRepository.getById(widget.terminId!);
    if (termin == null || !mounted) return;
    setState(() {
      _existing = termin;
      _betriebId = termin.betriebId;
      _datum = termin.datum;
      _uhrzeitVon = _parseTime(termin.uhrzeitVon);
      _uhrzeitBis = _parseTime(termin.uhrzeitBis);
      _typ = termin.typ;
      _anlass = termin.anlass;
      _titelController.text = termin.titel;
      _notizenController.text = termin.notizen ?? '';
      _status = termin.status;
      _erinnerungTage = termin.erinnerungTage;
      _erinnerungVorlauf = termin.erinnerungVorlaufMinuten;
      _erinnerungen = parseErinnerungen(termin.erinnerungenJson);
    });
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0);
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _updateAutoTitel() {
    if (_isEditing && _existing != null) return;
    final betriebe = ref.read(betriebeProvider);
    final betrieb = betriebe.where((b) {
      final bId = b.serverId ?? b.id.toString();
      return bId == _betriebId;
    }).firstOrNull;
    if (betrieb == null) return;

    String typLabel;
    switch (_typ) {
      case 'eroeffnungsreinigung':
        typLabel = 'Eröffnungsreinigung';
        break;
      case 'endreinigung':
        typLabel = 'Endreinigung';
        break;
      default:
        typLabel = 'Termin';
    }
    _titelController.text = '$typLabel — ${betrieb.name}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_betriebId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Betrieb auswählen')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final termin = _existing ?? TerminLocal();
      termin.betriebId = _betriebId!;
      termin.datum = _datum;
      termin.uhrzeitVon = _formatTime(_uhrzeitVon);
      termin.uhrzeitBis = _formatTime(_uhrzeitBis);
      termin.typ = _typ;
      termin.anlass = _anlass;
      termin.titel = _titelController.text.trim();
      termin.notizen =
          _notizenController.text.trim().isEmpty ? null : _notizenController.text.trim();
      termin.status = _status;
      termin.erinnerungTage = _erinnerungTage;
      termin.erinnerungenJson = erinnerungenToJson(_erinnerungen);
      // Legacy-Felder als Fallback konsistent halten (bis G4)
      termin.erinnerungAktiv = _erinnerungen.isNotEmpty;
      termin.erinnerungVorlaufMinuten =
          _erinnerungen.isNotEmpty ? _erinnerungen.first.minuten : _erinnerungVorlauf;

      await TerminRepository.save(termin);
      ref.invalidate(termineStreamProvider);

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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termin löschen?'),
        content: const Text('Dieser Termin wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await TerminRepository.delete(widget.terminId!);
      ref.invalidate(termineStreamProvider);
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

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Termin bearbeiten' : 'Neuer Termin'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: _isLoading ? null : _delete,
            ),
        ],
      ),
      body: _isLoading && _isEditing && _existing == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Betrieb-Auswahl
                  _buildSectionHeader('Betrieb *'),
                  Autocomplete<BetriebLocal>(
                    initialValue: TextEditingValue(
                      text: _betriebId != null
                          ? (betriebe
                                  .where((b) =>
                                      (b.serverId ?? b.id.toString()) ==
                                      _betriebId)
                                  .map(_betriebLabel)
                                  .firstOrNull ??
                              '')
                          : '',
                    ),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return betriebe.take(20);
                      }
                      final q = textEditingValue.text.toLowerCase();
                      return betriebe.where((b) =>
                          b.name.toLowerCase().contains(q) ||
                          (b.ort ?? '').toLowerCase().contains(q));
                    },
                    displayStringForOption: _betriebLabel,
                    onSelected: (betrieb) {
                      setState(() {
                        _betriebId =
                            betrieb.serverId ?? betrieb.id.toString();
                      });
                      _updateAutoTitel();
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Betrieb suchen',
                          prefixIcon: Icon(Icons.store),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Datum
                  _buildSectionHeader('Datum *'),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _datum,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        locale: const Locale('de', 'DE'),
                      );
                      if (picked != null) {
                        setState(() => _datum = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('EEEE, d. MMMM yyyy', 'de_DE')
                            .format(_datum),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Uhrzeit von/bis
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Von'),
                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      _uhrzeitVon ?? const TimeOfDay(hour: 8, minute: 0),
                                );
                                if (picked != null) {
                                  setState(() => _uhrzeitVon = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.access_time),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_uhrzeitVon != null
                                    ? _uhrzeitVon!.format(context)
                                    : '—'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Bis'),
                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      _uhrzeitBis ?? const TimeOfDay(hour: 9, minute: 0),
                                );
                                if (picked != null) {
                                  setState(() => _uhrzeitBis = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.access_time),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_uhrzeitBis != null
                                    ? _uhrzeitBis!.format(context)
                                    : '—'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Typ
                  _buildSectionHeader('Typ'),
                  DropdownButtonFormField<String>(
                    initialValue: _typ,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'eroeffnungsreinigung',
                          child: Text('Eröffnungsreinigung')),
                      DropdownMenuItem(
                          value: 'endreinigung',
                          child: Text('Endreinigung')),
                      DropdownMenuItem(
                          value: 'sonstiges',
                          child: Text('Sonstiges')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _typ = v);
                        _updateAutoTitel();
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Anlass
                  _buildSectionHeader('Anlass'),
                  DropdownButtonFormField<String>(
                    initialValue: _anlass,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'saisonstart',
                          child: Text('Saisonstart')),
                      DropdownMenuItem(
                          value: 'saisonende',
                          child: Text('Saisonende')),
                      DropdownMenuItem(
                          value: 'ferien', child: Text('Ferien')),
                      DropdownMenuItem(
                          value: 'zwischensaison',
                          child: Text('Zwischensaison')),
                      DropdownMenuItem(
                          value: 'manuell', child: Text('Manuell')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _anlass = v);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Titel
                  _buildSectionHeader('Titel *'),
                  TextFormField(
                    controller: _titelController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                      hintText: 'Wird automatisch generiert',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Titel erforderlich' : null,
                  ),

                  const SizedBox(height: 16),

                  // Notizen
                  _buildSectionHeader('Notizen'),
                  TextFormField(
                    controller: _notizenController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // Status
                  _buildSectionHeader('Status'),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.flag),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'vorgeschlagen',
                          child: Text('Vorgeschlagen')),
                      DropdownMenuItem(
                          value: 'geplant', child: Text('Geplant')),
                      DropdownMenuItem(
                          value: 'erledigt', child: Text('Erledigt')),
                      DropdownMenuItem(
                          value: 'abgesagt', child: Text('Abgesagt')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Erinnerungen
                  _buildSectionHeader('Erinnerungen'),
                  _buildErinnerungenEditor(),

                  const SizedBox(height: 32),

                  // Speichern
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isEditing ? 'Speichern' : 'Erstellen'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  static const _minutenPresets = <int>[0, 10, 30, 60, 120, 1440, 2880, 10080];

  Widget _buildErinnerungenEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _erinnerungen.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _erinnerungen[i].methode,
                    isDense: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'popup', child: Text('Popup')),
                      DropdownMenuItem(value: 'email', child: Text('E-Mail')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _erinnerungen[i] = TerminErinnerung(
                          methode: v, minuten: _erinnerungen[i].minuten));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        _minutenPresets.contains(_erinnerungen[i].minuten)
                            ? _erinnerungen[i].minuten
                            : 60,
                    isDense: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: _minutenPresets
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(minutenLabel(m))))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _erinnerungen[i] = TerminErinnerung(
                          methode: _erinnerungen[i].methode, minuten: v));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.error,
                  tooltip: 'Entfernen',
                  onPressed: () => setState(() => _erinnerungen.removeAt(i)),
                ),
              ],
            ),
          ),
        if (_erinnerungen.length < 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Erinnerung hinzufügen'),
              onPressed: () => setState(() => _erinnerungen.add(
                  const TerminErinnerung(methode: 'popup', minuten: 60))),
            ),
          ),
        if (_erinnerungen.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Keine Erinnerung',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
