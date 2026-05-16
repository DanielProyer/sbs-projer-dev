import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class StoerungFormScreen extends ConsumerStatefulWidget {
  final String? stoerungId; // null = neu
  final String? anlageId; // für neue Störung
  final String? betriebId; // für neue Störung

  const StoerungFormScreen({
    super.key,
    this.stoerungId,
    this.anlageId,
    this.betriebId,
  });

  @override
  ConsumerState<StoerungFormScreen> createState() =>
      _StoerungFormScreenState();
}

class _StoerungFormScreenState extends ConsumerState<StoerungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  StoerungLocal? _existing;

  // Zeiterfassung
  late DateTime _datum;
  late final _heinekennrController = TextEditingController();
  late final _stoerungseingangController = TextEditingController();

  // Störungsdetails
  late final _beschreibungController = TextEditingController();
  List<int> _stoerungBereiche = [];
  bool _istPikettWochenende = false;
  bool _istBergkunde = false;

  // Notizen
  late final _notizenController = TextEditingController();

  // Material
  List<Lager> _lagerItems = [];
  final List<String?> _materialIds = List.filled(5, null);
  final List<double> _materialMengen = List.filled(5, 1);
  final List<TextEditingController> _materialControllers =
      List.generate(5, (_) => TextEditingController());
  final List<TextEditingController> _materialMengenControllers =
      List.generate(5, (_) => TextEditingController(text: '1'));
  final List<TextEditingController?> _autoCompleteControllers =
      List.filled(5, null);

  // Kilometerabrechnung
  bool _istKilometerabrechnung = false;

  // Betrieb
  String? _betriebId;
  String? _anlageTyp;

  // Preis-Kalkulator
  late final _anfahrtKmController = TextEditingController(text: '0');
  late final _komplexitaetController = TextEditingController(text: '0');
  Map<String, dynamic>? _preisliste;

  bool get _isEdit => widget.stoerungId != null;

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _stoerungseingangController.text = _formatTime(TimeOfDay.now());
    _betriebId = widget.betriebId;
    _loadLager();
    if (_isEdit) {
      _loadStoerung();
    } else {
      _loadPreisData();
      _istPikettWochenende = _shouldAutoPikett();
    }
  }

  Future<void> _loadLager() async {
    try {
      final items = await LagerRepository.getAll();
      if (mounted) {
        setState(() {
          _lagerItems = items;
          // Material-Controller mit Namen befüllen (wenn IDs gesetzt)
          for (int i = 0; i < 5; i++) {
            if (_materialIds[i] != null && _materialControllers[i].text.isEmpty) {
              final lager = items.where((l) => l.id == _materialIds[i]).firstOrNull;
              if (lager != null) _materialControllers[i].text = lager.name;
            }
          }
        });
      }
    } catch (_) {}
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadStoerung() async {
    final s = await StoerungRepository.getById(widget.stoerungId!);
    if (s == null || !mounted) return;

    setState(() {
      _existing = s;
      _datum = s.datum;
      _heinekennrController.text = s.referenzNr ?? '';
      final zeit = s.uhrzeitStart ?? '';
      _stoerungseingangController.text = zeit.length >= 5 ? zeit.substring(0, 5) : zeit;
      _beschreibungController.text = s.problemBeschreibung;
      _stoerungBereiche = s.stoerungBereiche ?? [];
      _betriebId = s.betriebId;
      _anlageTyp = s.anlageTyp;
      _istPikettWochenende = s.istPikettEinsatz;
      _istBergkunde = s.istBergkunde;
      _istKilometerabrechnung = s.istKilometerabrechnung;
      _notizenController.text = s.notizen ?? '';
      _anfahrtKmController.text = s.anfahrtKm.toString();
      _komplexitaetController.text = (s.komplexitaetZuschlag ?? 0).toStringAsFixed(0);

      // Material IDs + Mengen
      _materialIds[0] = s.material1Id;
      _materialIds[1] = s.material2Id;
      _materialIds[2] = s.material3Id;
      _materialIds[3] = s.material4Id;
      _materialIds[4] = s.material5Id;
      _materialMengen[0] = s.material1Menge ?? 1;
      _materialMengen[1] = s.material2Menge ?? 1;
      _materialMengen[2] = s.material3Menge ?? 1;
      _materialMengen[3] = s.material4Menge ?? 1;
      _materialMengen[4] = s.material5Menge ?? 1;
      for (int i = 0; i < 5; i++) {
        _materialMengenControllers[i].text = _materialMengen[i].toStringAsFixed(0);
      }
    });
    _loadPreisData();
  }

  Future<void> _loadPreisData() async {
    try {
      // Preisliste laden
      final preisRows = await SupabaseService.client
          .from('preise')
          .select()
          .lte('gueltig_ab', _datum.toIso8601String().substring(0, 10))
          .order('gueltig_ab', ascending: false)
          .limit(1);
      if (preisRows.isNotEmpty && mounted) {
        setState(() => _preisliste = preisRows.first);
      }

      // Betrieb → Bergkunde
      if (_betriebId != null) {
        final betrieb = await BetriebRepository.getByServerId(_betriebId!);
        if (betrieb != null && mounted) {
          setState(() => _istBergkunde = betrieb.istBergkunde);
        }
      }
    } catch (_) {}
  }

  Map<String, double> _calculatePreis() {
    if (_preisliste == null || (_stoerungBereiche.isEmpty && !_istKilometerabrechnung)) return {};
    final p = _preisliste!;

    // Basis: Summe über alle gewählten Bereiche (0 bei Kilometerabrechnung)
    final keySuffix = _istBergkunde ? 'bergkunde' : 'normal';
    double basis = 0;
    for (final b in _stoerungBereiche) {
      final key = 'stoerung_${b}_$keySuffix';
      basis += (p[key] as num?)?.toDouble() ?? 0;
    }

    // Anfahrt
    final km = int.tryParse(_anfahrtKmController.text) ?? 0;
    final kmGrenze = (p['stoerung_anfahrt_km_grenze'] as num?)?.toDouble() ?? 80;
    final pauschale = (p['stoerung_anfahrt_pauschale'] as num?)?.toDouble() ?? 60;
    final kmSatz = (p['stoerung_anfahrt_km_satz'] as num?)?.toDouble() ?? 0.72;
    final anfahrt = km >= kmGrenze ? km * kmSatz : pauschale;

    final wochenende = (_istPikettWochenende && !_istKilometerabrechnung)
        ? ((p['stoerung_wochenende_zuschlag'] as num?)?.toDouble() ?? 0)
        : 0.0;
    final komplex = double.tryParse(_komplexitaetController.text) ?? 0;

    final total = basis + anfahrt + wochenende + komplex;

    return {
      'basis': basis,
      'anfahrt': anfahrt,
      'wochenende': wochenende,
      'komplex': komplex,
      'total': total,
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final s = _existing ?? StoerungLocal();

      s.istKilometerabrechnung = _istKilometerabrechnung;

      if (_istKilometerabrechnung) {
        s.betriebId = null;
        s.anlageTyp = null;
        s.stoerungBereiche = null;
        s.referenzNr = null;
        s.anlageId = null;
        // Material leer
        s.material1Id = null; s.material1Menge = null;
        s.material2Id = null; s.material2Menge = null;
        s.material3Id = null; s.material3Menge = null;
        s.material4Id = null; s.material4Menge = null;
        s.material5Id = null; s.material5Menge = null;
      } else {
        if (!_isEdit) {
          s.anlageId = widget.anlageId;
        }
        s.betriebId = _betriebId;
        s.anlageTyp = _anlageTyp;
        s.referenzNr = _emptyToNull(_heinekennrController.text);
        s.stoerungBereiche = _stoerungBereiche.isEmpty ? null : _stoerungBereiche;
        // Fallback: Text-Matching wenn User getippt aber nicht aus Dropdown gewählt hat
        for (int i = 0; i < 5; i++) {
          if (_materialIds[i] == null) {
            final text = (_autoCompleteControllers[i] ?? _materialControllers[i]).text.trim();
            if (text.isNotEmpty && _lagerItems.isNotEmpty) {
              final match = _lagerItems.where(
                (l) => l.name.toLowerCase() == text.toLowerCase(),
              ).firstOrNull;
              if (match != null) {
                _materialIds[i] = match.id;
              }
            }
          }
        }
        // Material-Felder
        s.material1Id = _materialIds[0];
        s.material1Menge = _materialIds[0] != null ? _materialMengen[0] : null;
        s.material2Id = _materialIds[1];
        s.material2Menge = _materialIds[1] != null ? _materialMengen[1] : null;
        s.material3Id = _materialIds[2];
        s.material3Menge = _materialIds[2] != null ? _materialMengen[2] : null;
        s.material4Id = _materialIds[3];
        s.material4Menge = _materialIds[3] != null ? _materialMengen[3] : null;
        s.material5Id = _materialIds[4];
        s.material5Menge = _materialIds[4] != null ? _materialMengen[4] : null;
      }

      s.datum = _datum;
      s.uhrzeitStart = _emptyToNull(_stoerungseingangController.text);
      s.problemBeschreibung = _beschreibungController.text.trim();
      s.istPikettEinsatz = _istPikettWochenende;
      s.istBergkunde = _istBergkunde;
      s.istWochenende = _istPikettWochenende;
      s.notizen = _emptyToNull(_notizenController.text);

      // Preis-Felder
      s.anfahrtKm = int.tryParse(_anfahrtKmController.text) ?? 0;
      s.komplexitaetZuschlag = double.tryParse(_komplexitaetController.text);
      final preis = _calculatePreis();
      if (preis.isNotEmpty) {
        s.preisBasis = preis['basis'];
        s.preisAnfahrt = preis['anfahrt'];
        s.preisWochenende = preis['wochenende'];
        s.preisNetto = preis['total'];
        s.preisBrutto = preis['total'];
      }

      s.status = 'behoben';

      await StoerungRepository.save(s);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? (_istKilometerabrechnung ? 'Kilometerabrechnung aktualisiert' : 'Störung aktualisiert')
                : (_istKilometerabrechnung ? 'Kilometerabrechnung erfasst' : 'Störung erfasst')),
          ),
        );
        if (kIsWeb) ref.invalidate(stoerungenStreamProvider);
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

  // === Auto-Pikett: Wochenende / Feiertag / Abend ===

  bool _shouldAutoPikett() {
    final isWeekend = _datum.weekday == DateTime.saturday ||
        _datum.weekday == DateTime.sunday;
    final isHoliday = _isSwissHoliday(_datum);
    bool isPikettTime = false;
    final timeText = _stoerungseingangController.text.trim();
    if (timeText.contains(':')) {
      final parts = timeText.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      if (hour < 7 || hour >= 18) isPikettTime = true;
      // Freitag ab 17:00 = Pikett
      if (_datum.weekday == DateTime.friday && hour >= 17) isPikettTime = true;
    }
    return isWeekend || isHoliday || isPikettTime;
  }

  void _updatePikettAuto() {
    setState(() => _istPikettWochenende = _shouldAutoPikett());
  }

  bool _isSwissHoliday(DateTime date) {
    final year = date.year;
    final d = DateTime(year, date.month, date.day);
    // Feste Feiertage (Graubünden)
    final fixed = [
      DateTime(year, 1, 1), // Neujahr
      DateTime(year, 1, 2), // Berchtoldstag
      DateTime(year, 8, 1), // Bundesfeiertag
      DateTime(year, 12, 25), // Weihnachten
      DateTime(year, 12, 26), // Stephanstag
    ];
    // Bewegliche Feiertage (Ostern-basiert)
    final easter = _computeEaster(year);
    final moving = [
      easter.subtract(const Duration(days: 2)), // Karfreitag
      easter.add(const Duration(days: 1)), // Ostermontag
      easter.add(const Duration(days: 39)), // Auffahrt
      easter.add(const Duration(days: 50)), // Pfingstmontag
    ];
    return fixed.any((h) => h == d) ||
        moving.any((h) =>
            h.year == d.year && h.month == d.month && h.day == d.day);
  }

  DateTime _computeEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  @override
  void dispose() {
    _heinekennrController.dispose();
    _stoerungseingangController.dispose();
    _beschreibungController.dispose();
    _notizenController.dispose();
    _anfahrtKmController.dispose();
    _komplexitaetController.dispose();
    for (final c in _materialControllers) { c.dispose(); }
    for (final c in _materialMengenControllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_istKilometerabrechnung
            ? (_isEdit ? 'Kilometerabrechnung bearbeiten' : 'Neue Kilometerabrechnung')
            : (_isEdit ? 'Störung bearbeiten' : 'Neue Störung')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Kilometerabrechnung Switch ===
            SwitchListTile(
              title: const Text('Kilometerabrechnung'),
              subtitle: const Text('Nur Anfahrt abrechnen (ohne Störung)'),
              secondary: const Icon(Icons.directions_car),
              value: _istKilometerabrechnung,
              activeTrackColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setState(() => _istKilometerabrechnung = v);
                // Bei neuem Eintrag: Beschreibung aus letzter Km-Abrechnung vorausfüllen
                if (v && !_isEdit) {
                  final stoerungen = ref.read(stoerungenProvider);
                  final letzte = stoerungen
                      .where((s) => s.istKilometerabrechnung)
                      .toList()
                    ..sort((a, b) => b.datum.compareTo(a.datum));
                  if (letzte.isNotEmpty) {
                    if (_beschreibungController.text.isEmpty) {
                      _beschreibungController.text = letzte.first.problemBeschreibung;
                    }
                    if (_anfahrtKmController.text == '0') {
                      _anfahrtKmController.text = letzte.first.anfahrtKm.toString();
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 16),

            // === Betrieb (nur bei normaler Störung) ===
            if (!_istKilometerabrechnung) ...[
              _sectionTitle(context, 'Betrieb'),
              const SizedBox(height: 8),
              _buildBetriebField(),
              const SizedBox(height: 16),

              // === Anlagentyp ===
              _sectionTitle(context, 'Anlagentyp'),
              const SizedBox(height: 8),
              _buildAnlageTypChips(),
              const SizedBox(height: 24),
            ],

            // === Zeiterfassung ===
            _sectionTitle(context, 'Zeiterfassung'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _datum,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _datum = picked);
                        _updatePikettAuto();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Datum',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(_datum)),
                    ),
                  ),
                ),
                if (!_istKilometerabrechnung) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heinekennrController,
                      decoration: const InputDecoration(
                        labelText: 'Störungsnummer',
                        prefixIcon: Icon(Icons.tag),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ],
            ),
            if (!_istKilometerabrechnung) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _stoerungseingangController,
                decoration: const InputDecoration(
                  labelText: 'Störungseingang (Uhrzeit)',
                  prefixIcon: Icon(Icons.phone_callback),
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _updatePikettAuto(),
              ),
            ],
            const SizedBox(height: 24),

            // === Störungsbereiche (nur bei normaler Störung) ===
            if (!_istKilometerabrechnung) ...[
              _sectionTitle(context, 'Störungsbereiche'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _bereichChip(1, 'Zapfhahn/Säule'),
                  _bereichChip(2, 'Leitung/Python'),
                  _bereichChip(3, 'Kühler/Vorkühler'),
                  _bereichChip(4, 'Zapfkopf/Tank'),
                  _bereichChip(5, 'Gas/Manometer'),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // === Beschreibung ===
            _sectionTitle(context, _istKilometerabrechnung ? 'Beschreibung' : 'Störungsbeschreibung'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _beschreibungController,
              decoration: InputDecoration(
                labelText: _istKilometerabrechnung
                    ? 'Beschreibung (z.B. Fahrt Innerschweiz)'
                    : 'Beschreibung',
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
              validator: _istKilometerabrechnung
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Beschreibung erforderlich' : null
                  : null,
            ),
            const SizedBox(height: 24),

            // === Optionen (nur bei normaler Störung) ===
            if (!_istKilometerabrechnung) ...[
              _sectionTitle(context, 'Optionen'),
              const SizedBox(height: 8),
              _checkTile('Pikett / Wochenende / Feiertag', _istPikettWochenende,
                  (v) => setState(() => _istPikettWochenende = v)),
              _checkTile('Bergkunde', _istBergkunde,
                  (v) => setState(() => _istBergkunde = v)),
              const SizedBox(height: 24),
            ],

            // === Preiskalkulation ===
            _sectionTitle(context, 'Preiskalkulation'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anfahrtKmController,
                    decoration: const InputDecoration(
                      labelText: 'Anfahrt (km)',
                      prefixIcon: Icon(Icons.directions_car),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _komplexitaetController,
                    decoration: const InputDecoration(
                      labelText: 'Zusatzkosten (CHF)',
                      prefixIcon: Icon(Icons.add_circle_outline),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPreisPreview(),
            const SizedBox(height: 24),

            // === Material (nur bei normaler Störung) ===
            if (!_istKilometerabrechnung) ...[
              _sectionTitle(context, 'Verwendetes Material'),
              const SizedBox(height: 8),
              ..._buildMaterialSlots(),
              const SizedBox(height: 24),
            ],

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
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // === Aktionen ===
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : (_istKilometerabrechnung ? 'Kilometerabrechnung erfassen' : 'Störung erfassen')),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMaterialSlots() {
    return List.generate(5, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _lagerItems.isNotEmpty
                ? Autocomplete<Lager>(
                    initialValue: TextEditingValue(text: _materialControllers[i].text),
                    displayStringForOption: (l) => l.name,
                    optionsViewOpenDirection: OptionsViewOpenDirection.up,
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return _lagerItems.take(10);
                      final q = textEditingValue.text.toLowerCase();
                      return _lagerItems.where((l) => l.name.toLowerCase().contains(q));
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      _autoCompleteControllers[i] = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Material ${i + 1}',
                          isDense: true,
                          prefixIcon: const Icon(Icons.inventory_2, size: 20),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    controller.clear();
                                    setState(() {
                                      _materialIds[i] = null;
                                      _materialControllers[i].clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.bottomLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final l = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(l.name),
                                  subtitle: l.dboNr != null ? Text(l.dboNr!, style: const TextStyle(fontSize: 11)) : null,
                                  onTap: () => onSelected(l),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (l) {
                      setState(() {
                        _materialIds[i] = l.id;
                        _materialControllers[i].text = l.name;
                      });
                    },
                  )
                : TextFormField(
                    controller: _materialControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Material ${i + 1}',
                      isDense: true,
                      prefixIcon: const Icon(Icons.inventory_2, size: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: _materialMengenControllers[i],
              decoration: const InputDecoration(
                labelText: 'Anz.',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                _materialMengen[i] = double.tryParse(v) ?? 1;
              },
            ),
          ),
        ],
      ),
    ));
  }

  String? _autoSelectAnlageTyp(List<String> zapfsysteme) {
    const mapping = {
      'David': 'david',
      'Higenie': 'heigenie',
      'Konventionell': 'konventionell',
      'Orion': 'orion',
    };
    final gueltig = zapfsysteme
        .map((z) => mapping[z])
        .whereType<String>()
        .toList();
    return gueltig.length == 1 ? gueltig.first : null;
  }

  Widget _buildAnlageTypChips() {
    Widget chip(String value, String label) {
      final selected = _anlageTyp == value;
      return FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary.withAlpha(40),
        checkmarkColor: AppColors.primary,
        onSelected: (v) => setState(() => _anlageTyp = v ? value : null),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip('david', 'David'),
        chip('heigenie', 'Heigenie'),
        chip('konventionell', 'Konventionell'),
        chip('orion', 'Orion'),
      ],
    );
  }

  Widget _buildBetriebField() {
    final betriebe = ref.watch(betriebeProvider)
        .where((b) => b.serverId != null)
        .toList();

    // Betrieb-Name für aktuellen Wert
    final currentName = _betriebId != null
        ? betriebe.where((b) => b.serverId == _betriebId).map((b) => b.name).firstOrNull
        : null;

    return Autocomplete<BetriebLocal>(
      initialValue: currentName != null
          ? TextEditingValue(text: currentName)
          : TextEditingValue.empty,
      displayStringForOption: (b) => b.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return betriebe.take(20);
        }
        final query = textEditingValue.text.toLowerCase();
        return betriebe.where((b) =>
            b.name.toLowerCase().contains(query) ||
            (b.ort?.toLowerCase().contains(query) ?? false) ||
            (b.betriebNr?.toLowerCase().contains(query) ?? false));
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Betrieb suchen',
            prefixIcon: const Icon(Icons.store),
            suffixIcon: _betriebId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        _betriebId = null;
                        _istBergkunde = false;
                      });
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final b = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(b.name),
                    subtitle: b.ort != null ? Text(b.ort!, style: const TextStyle(fontSize: 12)) : null,
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
          _istBergkunde = b.istBergkunde;
          // Anlagentyp vorauswählen aus Zapfsystemen
          _anlageTyp = _autoSelectAnlageTyp(b.zapfsysteme);
        });
        _loadPreisData();
      },
    );
  }

  Widget _bereichChip(int value, String label) {
    final selected = _stoerungBereiche.contains(value);
    return FilterChip(
      label: Text('$value - $label'),
      selected: selected,
      selectedColor: AppColors.primary.withAlpha(40),
      checkmarkColor: AppColors.primary,
      onSelected: (v) {
        setState(() {
          if (v) {
            _stoerungBereiche = [..._stoerungBereiche, value]..sort();
          } else {
            _stoerungBereiche = _stoerungBereiche.where((b) => b != value).toList();
          }
        });
      },
    );
  }

  Widget _checkTile(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.success,
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

  Widget _buildPreisPreview() {
    final preis = _calculatePreis();
    if (preis.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          _istKilometerabrechnung
              ? 'Preisliste wird geladen...'
              : (_stoerungBereiche.isEmpty
                  ? 'Bitte Störungsbereich wählen'
                  : 'Preisliste wird geladen...'),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          if (!_istKilometerabrechnung || preis['basis']! > 0)
            _preisRow(
              _istKilometerabrechnung ? 'Basis' : 'Basis (Bereich ${_stoerungBereiche.join(', ')})',
              preis['basis']!,
            ),
          if (preis['anfahrt']! > 0)
            _preisRow('Anfahrt', preis['anfahrt']!),
          if (preis['wochenende']! > 0)
            _preisRow('Pikett/WE-Zuschlag', preis['wochenende']!),
          if (preis['komplex']! > 0)
            _preisRow('Zusatzkosten', preis['komplex']!),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${preis['total']!.toStringAsFixed(2)} CHF',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preisRow(String label, double betrag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text('${betrag.toStringAsFixed(2)} CHF', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
