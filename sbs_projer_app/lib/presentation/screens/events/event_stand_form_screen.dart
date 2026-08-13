import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/util/koordinaten_parser.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

/// Formular zum Anlegen/Bearbeiten eines Event-Stands mit dynamischen
/// Schankanlagen-Zeilen (Typ + Anzahl).
class EventStandFormScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String? standId; // null = neu

  const EventStandFormScreen({
    super.key,
    required this.eventId,
    this.standId,
  });

  @override
  ConsumerState<EventStandFormScreen> createState() =>
      _EventStandFormScreenState();
}

class _EventStandFormScreenState extends ConsumerState<EventStandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialLoading = false;
  EventStandLocal? _existing;

  final _nameController = TextEditingController();
  final _standnummerController = TextEditingController();
  final _notizenController = TextEditingController();

  /// Koordinaten als Text — direkt aus Google Maps einfügbar
  /// («46.849994916702336, 9.532274794958706») oder von Hand getippt.
  final _koordinatenController = TextEditingController();
  String? _genauigkeit;

  // Dynamische Anlagen-Zeilen (Parallel-Arrays). [_zeilenKeys] hält den
  // Widget-State (z. B. Anzahl-Feld) beim Entfernen einer Zeile stabil.
  final List<String> _typen = [];
  final List<int> _anzahl = [];
  final List<String?> _anlagenServerIds = [];
  final List<UniqueKey> _zeilenKeys = [];

  bool get _isEdit => widget.standId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _initialLoading = true;
      _loadStand();
    }
  }

  Future<void> _loadStand() async {
    try {
      final staende = await EventStandRepository.getByEvent(widget.eventId);
      final stand = staende
          .where((s) => s.routeId == widget.standId)
          .cast<EventStandLocal?>()
          .firstWhere((s) => s != null, orElse: () => null);
      if (stand == null || !mounted) {
        if (mounted) setState(() => _initialLoading = false);
        return;
      }
      final anlagen =
          await EventStandAnlageRepository.getByStand(stand.serverId!);
      if (!mounted) return;
      setState(() {
        _existing = stand;
        _nameController.text = stand.name;
        _standnummerController.text = stand.standnummer ?? '';
        _notizenController.text = stand.notizen ?? '';
        if (stand.latitude != null && stand.longitude != null) {
          _koordinatenController.text =
              koordinatenText(stand.latitude!, stand.longitude!);
        }
        _genauigkeit = stand.positionGenauigkeit;
        for (final a in anlagen) {
          _typen.add(a.typ);
          _anzahl.add(a.anzahl);
          _anlagenServerIds.add(a.serverId);
          _zeilenKeys.add(UniqueKey());
        }
        _initialLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  void _anlageHinzufuegen() {
    setState(() {
      _typen.add(EventStandAnlage.typen.first);
      _anzahl.add(1);
      _anlagenServerIds.add(null);
      _zeilenKeys.add(UniqueKey());
    });
  }

  void _anlageEntfernen(int i) {
    setState(() {
      _typen.removeAt(i);
      _anzahl.removeAt(i);
      _anlagenServerIds.removeAt(i);
      _zeilenKeys.removeAt(i);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final stand = _existing ?? EventStandLocal();
      if (!_isEdit) {
        stand.eventId = widget.eventId;
      }
      stand.name = _nameController.text.trim();
      final standnummer = _standnummerController.text.trim();
      stand.standnummer = standnummer.isEmpty ? null : standnummer;
      final notizen = _notizenController.text.trim();
      stand.notizen = notizen.isEmpty ? null : notizen;

      // Koordinaten aus dem Textfeld (Google-Maps-Format oder getippt).
      // Leeres Feld löscht die Position; die Gültigkeit prüft der Validator,
      // hier kann also nur noch «leer» oder «gültig» ankommen.
      final roh = _koordinatenController.text.trim();
      if (roh.isEmpty) {
        stand
          ..latitude = null
          ..longitude = null
          ..positionQuelle = null
          ..positionErfasstAm = null
          ..positionGenauigkeit = null;
      } else {
        final k = koordinatenAus(roh);
        if (k != null) {
          final geaendert =
              stand.latitude != k.lat || stand.longitude != k.lng;
          stand
            ..latitude = k.lat
            ..longitude = k.lng
            ..positionGenauigkeit = _genauigkeit;
          if (geaendert) {
            // Von Hand gesetzt zählt wie auf der Karte gesetzt: geplant,
            // nicht gemessen — vor Ort kommt dann die Rückfrage.
            stand
              ..positionQuelle = quelleKarte
              ..positionErfasstAm = DateTime.now();
          }
        }
      }
      await EventStandRepository.save(stand);

      // Anlagen id-basiert abgleichen (Reihenfolge = Zeilen-Reihenfolge,
      // inBetrieb/inBetriebAm bestehender Anlagen bleiben erhalten).
      final zeilen = <({String? serverId, String typ, int anzahl})>[
        for (var i = 0; i < _typen.length; i++)
          (serverId: _anlagenServerIds[i], typ: _typen[i], anzahl: _anzahl[i]),
      ];
      await EventStandAnlageRepository.applyForStand(stand.serverId!, zeilen);

      ref.invalidate(eventStaendeProvider(widget.eventId));
      ref.invalidate(eventStandAnlagenProvider(stand.serverId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEdit ? 'Stand aktualisiert' : 'Stand angelegt')),
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
    _nameController.dispose();
    _standnummerController.dispose();
    _notizenController.dispose();
    _koordinatenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Stand bearbeiten' : 'Neuer Stand'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Stand ===
            _sectionTitle(context, 'Stand'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.storefront),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name erforderlich' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _standnummerController,
              decoration: const InputDecoration(
                labelText: 'Standnummer',
                prefixIcon: Icon(Icons.tag),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // === Position ===
            // Direkte Koordinaten-Eingabe (Daniel 11.08.2026): In Google Maps
            // Rechtsklick auf den Punkt → die Koordinaten stehen zuoberst im
            // Menü und lassen sich mit einem Klick kopieren. Eine ganze
            // Standliste ist so schneller erfasst als über die Karte.
            _sectionTitle(context, 'Position'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _koordinatenController,
              decoration: const InputDecoration(
                labelText: 'Koordinaten',
                hintText: '46.849994916702336, 9.532274794958706',
                helperText: 'Aus Google Maps einfügen · leer = keine Position',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.my_location),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final k = koordinatenAus(t);
                if (k == null) {
                  return 'Nicht lesbar — erwartet: 46.8500, 9.5323';
                }
                if (!istInDerSchweiz(k.lat, k.lng)) {
                  // Warnung, keine Sperre: Anlässe ausserhalb der Schweiz sind
                  // denkbar, vertauschte Werte aber viel wahrscheinlicher.
                  return 'Ausserhalb der Schweiz — Breite und Länge vertauscht?';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _GenauigkeitAuswahl(
              wert: _genauigkeit,
              aktiv: _koordinatenController.text.trim().isNotEmpty,
              onChanged: (v) => setState(() => _genauigkeit = v),
            ),
            const SizedBox(height: 24),

            // === Schankanlagen ===
            _sectionTitle(context, 'Schankanlagen'),
            const SizedBox(height: 8),
            if (_typen.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Noch keine Anlagen erfasst.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ..._buildAnlagenZeilen(),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _anlageHinzufuegen,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Anlage'),
              ),
            ),
            const SizedBox(height: 24),

            // === Notizen ===
            _sectionTitle(context, 'Notizen'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notizenController,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
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
                  : Text(_isEdit ? 'Speichern' : 'Stand anlegen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnlagenZeilen() {
    return List.generate(_typen.length, (i) {
      return Card(
        key: _zeilenKeys[i],
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _typen[i],
                  decoration: const InputDecoration(
                    labelText: 'Typ',
                    isDense: true,
                  ),
                  items: EventStandAnlage.typen
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(EventStandAnlage.typLabel(t)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _typen[i] = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextFormField(
                  initialValue: _anzahl[i].toString(),
                  decoration: const InputDecoration(
                    labelText: 'Anz.',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    _anzahl[i] = (n == null || n < 1) ? 1 : n;
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: 'Anlage entfernen',
                onPressed: () => _anlageEntfernen(i),
              ),
            ],
          ),
        ),
      );
    });
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

/// Auswahl der Positions-Genauigkeit (genau / mittel / ungefähr).
///
/// Wozu (Daniel 11.08.2026): Am Schreibtisch gesetzte Koordinaten sind nicht
/// gleich verlässlich — mal ist der Standplatz metergenau bekannt, mal nur
/// die Ecke des Platzes. Die Stufe sagt dem Monteur im Feld, worauf er sich
/// verlassen kann. Bei einer GPS-Messung setzt die App sie selbst aus der
/// gemeldeten Messgenauigkeit.
class _GenauigkeitAuswahl extends StatelessWidget {
  final String? wert;
  final bool aktiv;
  final ValueChanged<String?> onChanged;

  const _GenauigkeitAuswahl({
    required this.wert,
    required this.aktiv,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: aktiv ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !aktiv,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genauigkeit',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final g in alleGenauigkeiten)
                  ChoiceChip(
                    label: Text(genauigkeitText(g)),
                    selected: wert == g,
                    onSelected: (s) => onChanged(s ? g : null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
