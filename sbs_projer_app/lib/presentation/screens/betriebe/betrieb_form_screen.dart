import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';
import 'package:sbs_projer_app/services/betrieb/betrieb_google_service.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/google_calendar_providers.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';
import 'package:sbs_projer_app/core/util/betrieb_kunde.dart';
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/widgets/saison_reinigung_dialog.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';

class BetriebFormScreen extends ConsumerStatefulWidget {
  final String? betriebId; // null = neu erstellen

  const BetriebFormScreen({super.key, this.betriebId});

  @override
  ConsumerState<BetriebFormScreen> createState() => _BetriebFormScreenState();
}

class _BetriebFormScreenState extends ConsumerState<BetriebFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  BetriebLocal? _existing;

  // Formular-Controller
  late final _nameController = TextEditingController();
  late final _strasseController = TextEditingController();
  late final _nrController = TextEditingController();
  late final _plzController = TextEditingController();
  late final _ortController = TextEditingController();
  late final _telefonController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _websiteController = TextEditingController();
  late final _betriebNrController = TextEditingController();
  late final _weNummerController = TextEditingController();
  late final _agNummerController = TextEditingController();
  late final _zugangController = TextEditingController();
  late final _notizenController = TextEditingController();

  String _status = 'aktiv';
  bool _istMeinKunde = true;
  String? _schliessungsgrund;
  DateTime? _schliessungsdatum;
  bool _istBergkunde = false;
  bool _istSaisonbetrieb = false;
  String _rechnungsstellung = 'rechnung_mail';
  String? _regionId;

  // Saison-Felder
  bool _winterSaisonAktiv = false;
  DateTime? _winterStartDatum;
  DateTime? _winterEndeDatum;
  bool _sommerSaisonAktiv = false;
  DateTime? _sommerStartDatum;
  DateTime? _sommerEndeDatum;
  final List<DateTime?> _ferienStarts = List.filled(5, null);
  final List<DateTime?> _ferienEnden = List.filled(5, null);
  int _ferienZeilen = 1;
  bool _keineBetriebsferien = false;
  List<String> _ruhetage = [];
  double? _latitude;
  double? _longitude;
  bool _googleLoading = false;
  bool _websiteLoading = false;
  List<String> _zapfsysteme = [];
  List<String> _zahlerAliase = [];
  final _aliasController = TextEditingController();

  // Servicezeiten
  final _servicezeitMorgenAbCtrl = TextEditingController();
  final _servicezeitMorgenBisCtrl = TextEditingController();
  final _servicezeitNachmittagAbCtrl = TextEditingController();
  final _servicezeitNachmittagBisCtrl = TextEditingController();

  // Öffnungszeiten pro Wochentag: {"Mo": [{"von":"HH:mm","bis":"HH:mm"}, ...], ...}
  final Map<String, List<Map<String, String>>> _oeffnungszeiten = {
    for (final t in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) t: [],
  };

  List<RegionLocal> _regionen = [];

  bool get _isEdit => widget.betriebId != null;

  @override
  void initState() {
    super.initState();
    _loadRegionen();
    if (_isEdit) _loadBetrieb();
  }

  Future<void> _loadRegionen() async {
    final regionen = await RegionRepository.getAll();
    if (mounted) setState(() => _regionen = regionen);
  }

  Future<void> _loadBetrieb() async {
    final betrieb = await BetriebRepository.getById(widget.betriebId!);
    if (betrieb == null || !mounted) return;

    setState(() {
      _existing = betrieb;
      _nameController.text = betrieb.name;
      _strasseController.text = betrieb.strasse ?? '';
      _nrController.text = betrieb.nr ?? '';
      _plzController.text = betrieb.plz ?? '';
      _ortController.text = betrieb.ort ?? '';
      _telefonController.text = betrieb.telefon ?? '';
      _emailController.text = betrieb.email ?? '';
      _websiteController.text = betrieb.website ?? '';
      _betriebNrController.text = betrieb.betriebNr ?? '';
      _weNummerController.text = betrieb.weNummer ?? '';
      _agNummerController.text = betrieb.agNummer ?? '';
      _zugangController.text = betrieb.zugangNotizen ?? '';
      _notizenController.text = betrieb.notizen ?? '';
      _servicezeitMorgenAbCtrl.text = betrieb.servicezeitMorgenAb ?? '';
      _servicezeitMorgenBisCtrl.text = betrieb.servicezeitMorgenBis ?? '';
      _servicezeitNachmittagAbCtrl.text = betrieb.servicezeitNachmittagAb ?? '';
      _servicezeitNachmittagBisCtrl.text = betrieb.servicezeitNachmittagBis ?? '';
      _status = betrieb.status;
      _schliessungsgrund = betrieb.schliessungsgrund;
      _schliessungsdatum = betrieb.schliessungsdatum;
      _istMeinKunde = betrieb.istMeinKunde;
      _istBergkunde = betrieb.istBergkunde;
      _istSaisonbetrieb = betrieb.istSaisonbetrieb;
      _rechnungsstellung = betrieb.rechnungsstellung;
      _regionId = betrieb.regionId;
      _winterSaisonAktiv = betrieb.winterSaisonAktiv;
      _winterStartDatum = betrieb.winterStartDatum;
      _winterEndeDatum = betrieb.winterEndeDatum;
      _sommerSaisonAktiv = betrieb.sommerSaisonAktiv;
      _sommerStartDatum = betrieb.sommerStartDatum;
      _sommerEndeDatum = betrieb.sommerEndeDatum;
      final geladeneStarts = [
        betrieb.ferienStart, betrieb.ferien2Start, betrieb.ferien3Start,
        betrieb.ferien4Start, betrieb.ferien5Start,
      ];
      final geladeneEnden = [
        betrieb.ferienEnde, betrieb.ferien2Ende, betrieb.ferien3Ende,
        betrieb.ferien4Ende, betrieb.ferien5Ende,
      ];
      for (var i = 0; i < 5; i++) {
        _ferienStarts[i] = geladeneStarts[i];
        _ferienEnden[i] = geladeneEnden[i];
      }
      _ferienZeilen = 1;
      for (var i = 4; i >= 0; i--) {
        if (_ferienStarts[i] != null || _ferienEnden[i] != null) {
          _ferienZeilen = i + 1;
          break;
        }
      }
      _keineBetriebsferien = betrieb.keineBetriebsferien;
      _ruhetage = List<String>.from(betrieb.ruhetage);
      _latitude = betrieb.latitude;
      _longitude = betrieb.longitude;
      _zapfsysteme = List<String>.from(betrieb.zapfsysteme);
      _zahlerAliase = List<String>.from(betrieb.zahlerAliase);
      if (betrieb.oeffnungszeitenJson != null && betrieb.oeffnungszeitenJson!.isNotEmpty) {
        try {
          final map = jsonDecode(betrieb.oeffnungszeitenJson!) as Map<String, dynamic>;
          for (final tag in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
            final slots = map[tag];
            if (slots is List) {
              _oeffnungszeiten[tag] = slots
                  .map((s) => {'von': s['von']?.toString() ?? '', 'bis': s['bis']?.toString() ?? ''})
                  .toList();
            }
          }
        } catch (_) {}
      }
    });
  }

  void _aliasHinzufuegen() {
    final norm = zahlernameNorm(_aliasController.text);
    if (norm.isEmpty) return;
    setState(() {
      if (!_zahlerAliase.contains(norm)) _zahlerAliase.add(norm);
      _aliasController.clear();
    });
  }

  Future<void> _ausGoogleUebernehmen() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('Bitte zuerst den Betriebsnamen eingeben.');
      return;
    }
    final ortTeil = [_plzController.text.trim(), _ortController.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final query = ortTeil.isEmpty ? name : '$name $ortTeil';

    setState(() => _googleLoading = true);
    try {
      final daten = await BetriebGoogleService.lookup(query);
      if (!mounted) return;
      await _zeigeUebernahmeDialog(daten);
    } on BetriebGoogleException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('Google-Abgleich fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _oeffnungszeitenVonWebsite() async {
    final website = _websiteController.text.trim();
    if (website.isEmpty) {
      _snack('Bitte zuerst eine Website eintragen (oder aus Google übernehmen).');
      return;
    }
    setState(() => _websiteLoading = true);
    try {
      final daten = await BetriebGoogleService.oeffnungszeitenVonWebsite(
        website,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      if (!daten.oeffnungszeiten.values.any((l) => l.isNotEmpty)) {
        _snack('Auf der Website keine Öffnungszeiten gefunden.');
        return;
      }
      await _zeigeUebernahmeDialog(daten, titel: 'Öffnungszeiten von Website');
    } on BetriebGoogleException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('Website-Auslesen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _websiteLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _zeigeUebernahmeDialog(GoogleBetriebDaten d,
      {String titel = 'Google-Daten übernehmen'}) async {
    final hatOeffnungszeiten =
        d.oeffnungszeiten.values.any((l) => l.isNotEmpty);
    final kandidaten = <_GoogleFeld>[
      if (d.strasse != null || d.nr != null)
        _GoogleFeld(
          'Adresse',
          '${d.strasse ?? ''} ${d.nr ?? ''}'.trim(),
          '${_strasseController.text} ${_nrController.text}'.trim(),
          () {
            if (d.strasse != null) _strasseController.text = d.strasse!;
            if (d.nr != null) _nrController.text = d.nr!;
          },
        ),
      if (d.plz != null)
        _GoogleFeld('PLZ', d.plz!, _plzController.text,
            () => _plzController.text = d.plz!),
      if (d.ort != null)
        _GoogleFeld('Ort', d.ort!, _ortController.text,
            () => _ortController.text = d.ort!),
      if (d.telefon != null)
        _GoogleFeld('Telefon', d.telefon!, _telefonController.text,
            () => _telefonController.text = d.telefon!),
      if (d.website != null)
        _GoogleFeld('Website', d.website!, _websiteController.text,
            () => _websiteController.text = d.website!),
      if (d.latitude != null && d.longitude != null)
        _GoogleFeld(
          'Koordinaten',
          '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}',
          (_latitude != null && _longitude != null)
              ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
              : '',
          () {
            _latitude = d.latitude;
            _longitude = d.longitude;
          },
        ),
      if (hatOeffnungszeiten)
        _GoogleFeld(
          'Öffnungszeiten',
          _oeffnungszeitenKurz(d.oeffnungszeiten),
          '',
          () {
            setState(() {
              for (final t in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
                _oeffnungszeiten[t] =
                    List<Map<String, String>>.from(d.oeffnungszeiten[t] ?? []);
              }
              if (d.ruhetage.isNotEmpty) {
                _ruhetage = List<String>.from(d.ruhetage);
              }
            });
          },
          detail: _oeffnungszeitenDetail(d.oeffnungszeiten, d.ruhetage),
        ),
    ];

    if (kandidaten.isEmpty) {
      _snack('Google lieferte keine übernehmbaren Felder.');
      return;
    }

    final auswahl = {for (final k in kandidaten) k: true};

    final uebernehmen = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(titel),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (d.name != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Gefunden: ${d.name}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                for (final k in kandidaten)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: auswahl[k],
                    onChanged: (v) =>
                        setDialogState(() => auswahl[k] = v ?? false),
                    title: Text(k.detail != null
                        ? k.label
                        : '${k.label}: ${k.wert}'),
                    subtitle: k.detail != null
                        ? Text(k.detail!, style: const TextStyle(fontSize: 12))
                        : (k.aktuell.isNotEmpty
                            ? Text('ersetzt: ${k.aktuell}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey))
                            : null),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Übernehmen')),
          ],
        ),
      ),
    );

    if (uebernehmen == true) {
      setState(() {
        for (final k in kandidaten) {
          if (auswahl[k] == true) k.uebernehmen();
        }
      });
      _snack('Google-Daten übernommen. Zum Sichern speichern.');
    }
  }

  String _oeffnungszeitenKurz(Map<String, List<Map<String, String>>> oz) {
    final tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
        .where((t) => (oz[t] ?? []).isNotEmpty)
        .toList();
    return '${tage.length} Tag(e) mit Zeiten';
  }

  /// Öffnungszeiten pro Tag (Mo–So) inkl. Ruhetag, mehrzeilig — zur Kontrolle.
  String _oeffnungszeitenDetail(
      Map<String, List<Map<String, String>>> oz, List<String> ruhetage) {
    const tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return [
      for (final t in tage)
        () {
          final slots = oz[t] ?? [];
          if (slots.isNotEmpty) {
            return '$t: ${slots.map((s) => '${s['von']}–${s['bis']}').join(', ')}';
          }
          return '$t: ${ruhetage.contains(t) ? 'Ruhetag' : '—'}';
        }(),
    ].join('\n');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final betrieb = _existing ?? BetriebLocal();
      betrieb.name = _nameController.text.trim();
      betrieb.strasse = _emptyToNull(_strasseController.text);
      betrieb.nr = _emptyToNull(_nrController.text);
      betrieb.plz = _emptyToNull(_plzController.text);
      betrieb.ort = _emptyToNull(_ortController.text);
      betrieb.telefon = _emptyToNull(_telefonController.text);
      betrieb.email = _emptyToNull(_emailController.text);
      betrieb.website = _emptyToNull(_websiteController.text);
      betrieb.betriebNr = _emptyToNull(_betriebNrController.text);
      betrieb.weNummer = _emptyToNull(_weNummerController.text);
      betrieb.agNummer = _emptyToNull(_agNummerController.text);
      betrieb.zugangNotizen = _emptyToNull(_zugangController.text);
      betrieb.notizen = _emptyToNull(_notizenController.text);
      betrieb.status = _status;
      betrieb.schliessungsgrund =
          _status == 'geschlossen' ? _schliessungsgrund : null;
      betrieb.schliessungsdatum =
          _status == 'geschlossen' ? _schliessungsdatum : null;
      betrieb.istMeinKunde = _istMeinKunde;
      betrieb.istBergkunde = _istBergkunde;
      betrieb.istSaisonbetrieb = _istSaisonbetrieb;
      betrieb.rechnungsstellung = _rechnungsstellung;
      betrieb.regionId = _regionId;
      betrieb.winterSaisonAktiv = _istSaisonbetrieb ? _winterSaisonAktiv : false;
      betrieb.winterStartDatum = _istSaisonbetrieb ? _winterStartDatum : null;
      betrieb.winterEndeDatum = _istSaisonbetrieb ? _winterEndeDatum : null;
      betrieb.sommerSaisonAktiv = _istSaisonbetrieb ? _sommerSaisonAktiv : false;
      betrieb.sommerStartDatum = _istSaisonbetrieb ? _sommerStartDatum : null;
      betrieb.sommerEndeDatum = _istSaisonbetrieb ? _sommerEndeDatum : null;
      betrieb.ferienStart = _keineBetriebsferien ? null : _ferienStarts[0];
      betrieb.ferienEnde = _keineBetriebsferien ? null : _ferienEnden[0];
      betrieb.ferien2Start = _keineBetriebsferien ? null : _ferienStarts[1];
      betrieb.ferien2Ende = _keineBetriebsferien ? null : _ferienEnden[1];
      betrieb.ferien3Start = _keineBetriebsferien ? null : _ferienStarts[2];
      betrieb.ferien3Ende = _keineBetriebsferien ? null : _ferienEnden[2];
      betrieb.ferien4Start = _keineBetriebsferien ? null : _ferienStarts[3];
      betrieb.ferien4Ende = _keineBetriebsferien ? null : _ferienEnden[3];
      betrieb.ferien5Start = _keineBetriebsferien ? null : _ferienStarts[4];
      betrieb.ferien5Ende = _keineBetriebsferien ? null : _ferienEnden[4];
      betrieb.keineBetriebsferien = _keineBetriebsferien;
      betrieb.ruhetage = _ruhetage;
      betrieb.zapfsysteme = _zapfsysteme;
      betrieb.zahlerAliase = _zahlerAliase;
      betrieb.oeffnungszeitenJson = jsonEncode(_oeffnungszeiten);
      betrieb.latitude = _latitude;
      betrieb.longitude = _longitude;
      betrieb.servicezeitMorgenAb = _emptyToNull(_servicezeitMorgenAbCtrl.text);
      betrieb.servicezeitMorgenBis = _emptyToNull(_servicezeitMorgenBisCtrl.text);
      betrieb.servicezeitNachmittagAb = _emptyToNull(_servicezeitNachmittagAbCtrl.text);
      betrieb.servicezeitNachmittagBis = _emptyToNull(_servicezeitNachmittagBisCtrl.text);

      await BetriebRepository.save(betrieb);

      // Saison-/Ferien-Reinigungen optional in den Google Kalender eintragen
      // (mit Bestätigungs-Dialog, nur wenn Google verbunden).
      final betriebSid = betrieb.serverId;
      final reinigungen = betriebReinigungen(betrieb);
      if (mounted &&
          reinigungen.isNotEmpty &&
          betriebSid != null &&
          betriebSid.isNotEmpty) {
        final status = await ref.read(googleCalendarStatusProvider.future);
        if (status.connected && mounted) {
          final items = await showDialog<List<Map<String, dynamic>>>(
            context: context,
            builder: (_) => SaisonReinigungDialog(reinigungen: reinigungen),
          );
          if (items != null) {
            try {
              await GoogleCalendarSyncService.syncBetriebReinigungen(
                  betriebSid, reinigungen.first.label, items);
            } catch (e) {
              debugPrint('[GCal-Reinigung] fehlgeschlagen: $e');
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Betrieb aktualisiert' : 'Betrieb erstellt'),
          ),
        );
        if (kIsWeb) {
          ref.invalidate(betriebeStreamProvider);
        }
        context.pop();
      }
    } catch (e, stack) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Fehler beim Speichern'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: SelectableText('$e\n\n$stack'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _lookupPlz(String plz) async {
    if (plz.length != 4) return;
    if (_ortController.text.isNotEmpty) return; // Nicht überschreiben
    try {
      final response = await Dio().get('https://api.zippopotam.us/ch/$plz');
      if (response.statusCode == 200 && mounted) {
        final places = response.data['places'] as List?;
        if (places != null && places.isNotEmpty) {
          final ort = places[0]['place name'] as String?;
          if (ort != null && _ortController.text.isEmpty) {
            setState(() => _ortController.text = ort);
          }
        }
      }
    } catch (_) {}
  }

  String? _emptyToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strasseController.dispose();
    _nrController.dispose();
    _plzController.dispose();
    _ortController.dispose();
    _telefonController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _betriebNrController.dispose();
    _weNummerController.dispose();
    _agNummerController.dispose();
    _zugangController.dispose();
    _notizenController.dispose();
    _servicezeitMorgenAbCtrl.dispose();
    _servicezeitMorgenBisCtrl.dispose();
    _servicezeitNachmittagAbCtrl.dispose();
    _servicezeitNachmittagBisCtrl.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Betrieb bearbeiten' : 'Neuer Betrieb'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Name ===
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.store),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name ist erforderlich' : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _googleLoading ? null : _ausGoogleUebernehmen,
              icon: _googleLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.travel_explore),
              label: const Text('Aus Google übernehmen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _websiteLoading ? null : _oeffnungszeitenVonWebsite,
              icon: _websiteLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.schedule),
              label: const Text('Öffnungszeiten von Website'),
            ),
            const SizedBox(height: 8),

            // === Zapfsysteme (direkt unter Name) ===
            Wrap(
              spacing: 8,
              children: ['David', 'Konventionell', 'Higenie', 'Orion', 'Veranstaltungen'].map((system) {
                final selected = _zapfsysteme.contains(system);
                return FilterChip(
                  label: Text(system),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _zapfsysteme.add(system);
                      } else {
                        _zapfsysteme.remove(system);
                      }
                      // Vorschlag: Mein Kunde je nach Status + Zapfsystemen neu setzen
                      _istMeinKunde = istMeinKundeVorschlag(
                          _status, _zapfsysteme.toList());
                    });
                  },
                );
              }).toList(),
            ),
            SwitchListTile(
              title: const Text('Mein Kunde'),
              value: _istMeinKunde,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istMeinKunde = v),
            ),
            SwitchListTile(
              title: const Text('Bergkunde'),
              subtitle: const Text('+100 CHF Zuschlag'),
              value: _istBergkunde,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istBergkunde = v),
            ),
            if (_istMeinKunde)
              DropdownButtonFormField<String>(
                initialValue: _rechnungsstellung,
                decoration: const InputDecoration(
                  labelText: 'Rechnungsstellung',
                  prefixIcon: Icon(Icons.receipt),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'rechnung_mail', child: Text('Per E-Mail')),
                  DropdownMenuItem(
                      value: 'rechnung_post', child: Text('Per Post')),
                  DropdownMenuItem(
                      value: 'rechnung_tresen', child: Text('Rechnung Tresen')),
                  DropdownMenuItem(
                      value: 'barzahlung', child: Text('Barzahlung')),
                  DropdownMenuItem(
                      value: 'jahresrechnung', child: Text('Jahresrechnung')),
                  DropdownMenuItem(
                      value: 'heineken', child: Text('Via Heineken')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _rechnungsstellung = v);
                },
              ),
            const SizedBox(height: 16),

            if (_istMeinKunde) ...[
              // === Zahlernamen-Aliase (Bank zu Betrieb-Lernen) ===
              Text('Zahlernamen (Bank)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const Text(
                'Namen, unter denen dieser Betrieb Zahlungen überweist. '
                'Wird beim Bankauszug-Import automatisch gelernt.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (_zahlerAliase.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in _zahlerAliase)
                      InputChip(
                        label: Text(a),
                        onDeleted: () => setState(() => _zahlerAliase.remove(a)),
                      ),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aliasController,
                      decoration: const InputDecoration(
                        labelText: 'Zahlername hinzufügen',
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _aliasHinzufuegen(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Hinzufügen',
                    onPressed: _aliasHinzufuegen,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // === Adresse ===
            Text('Adresse',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _strasseController,
                    decoration: const InputDecoration(labelText: 'Strasse'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nrController,
                    decoration: const InputDecoration(labelText: 'Nr.'),
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
                    controller: _plzController,
                    decoration: const InputDecoration(labelText: 'PLZ'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: _lookupPlz,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ortController,
                    decoration: const InputDecoration(labelText: 'Ort'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonController,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: '+41 81 377 14 94',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [_PhoneFormatter()],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                if (!v.startsWith('+') || digits.length < 10) {
                  return 'Format: +41 81 377 14 94';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // === Kontakt ===
            Text('Kontakt',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website',
                prefixIcon: Icon(Icons.language),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),

            // === Nummern (nur für "meine Kunden") ===
            if (_istMeinKunde) ...[
              const SizedBox(height: 16),
              Text('Nummern',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),
              TextFormField(
                controller: _betriebNrController,
                decoration: const InputDecoration(
                  labelText: 'Betrieb Nr.',
                  prefixIcon: Icon(Icons.tag),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weNummerController,
                decoration: const InputDecoration(
                  labelText: 'WE-Nummer',
                  prefixIcon: Icon(Icons.tag),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _agNummerController,
                decoration: const InputDecoration(
                  labelText: 'AG-Nummer',
                  prefixIcon: Icon(Icons.tag),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 16),

            // === Einstellungen ===
            Text('Einstellungen',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.circle),
              ),
              items: const [
                DropdownMenuItem(value: 'aktiv', child: Text('Aktiv')),
                DropdownMenuItem(value: 'inaktiv', child: Text('Inaktiv')),
                DropdownMenuItem(
                    value: 'saisonpause', child: Text('Saisonpause')),
                DropdownMenuItem(
                    value: 'geschlossen',
                    child: Text('Geschlossen (dauerhaft)')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _status = v;
                    _istMeinKunde = istMeinKundeVorschlag(
                        _status, _zapfsysteme.toList());
                    if (_status != 'geschlossen') {
                      _schliessungsgrund = null;
                      _schliessungsdatum = null;
                    }
                  });
                }
              },
            ),
            if (_status == 'geschlossen') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _schliessungsgrund,
                decoration: const InputDecoration(
                  labelText: 'Schliessungsgrund',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'umnutzung', child: Text('Umnutzung')),
                  DropdownMenuItem(value: 'abbruch', child: Text('Abbruch')),
                  DropdownMenuItem(value: 'konkurs', child: Text('Konkurs')),
                  DropdownMenuItem(value: 'sonstiges', child: Text('Sonstiges')),
                ],
                onChanged: (v) => setState(() => _schliessungsgrund = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _schliessungsdatum ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _schliessungsdatum = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Schliessungsdatum',
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(_schliessungsdatum == null
                      ? 'Datum wählen'
                      : '${_schliessungsdatum!.day.toString().padLeft(2, '0')}.'
                          '${_schliessungsdatum!.month.toString().padLeft(2, '0')}.'
                          '${_schliessungsdatum!.year}'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // === Region ===
            DropdownButtonFormField<String>(
              initialValue: _regionId,
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.map),
              ),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('Keine Region')),
                ..._regionen.map((r) => DropdownMenuItem<String>(
                      value: r.serverId ?? r.id.toString(),
                      child: Text(r.name),
                    )),
              ],
              onChanged: (v) => setState(() => _regionId = v),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Saisonbetrieb'),
              value: _istSaisonbetrieb,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _istSaisonbetrieb = v),
            ),

            // === Saison-Details (bedingt) ===
            if (_istSaisonbetrieb) ...[
              const SizedBox(height: 16),
              Text('Saison-Details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),
              // Winter
              SwitchListTile(
                title: const Text('Wintersaison'),
                value: _winterSaisonAktiv,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _winterSaisonAktiv = v),
              ),
              if (_winterSaisonAktiv)
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Saison von',
                        value: _winterStartDatum,
                        onChanged: (v) => setState(() => _winterStartDatum = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Saison bis',
                        value: _winterEndeDatum,
                        onChanged: (v) => setState(() => _winterEndeDatum = v),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // Sommer
              SwitchListTile(
                title: const Text('Sommersaison'),
                value: _sommerSaisonAktiv,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _sommerSaisonAktiv = v),
              ),
              if (_sommerSaisonAktiv)
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Saison von',
                        value: _sommerStartDatum,
                        onChanged: (v) => setState(() => _sommerStartDatum = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Saison bis',
                        value: _sommerEndeDatum,
                        onChanged: (v) => setState(() => _sommerEndeDatum = v),
                      ),
                    ),
                  ],
                ),
            ],

            // === Ruhetage (für alle Betriebe) ===
            const SizedBox(height: 16),
            Text('Ruhetage',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Keine'),
                  selected: _ruhetage.contains('keine'),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _ruhetage = ['keine'];
                      } else {
                        _ruhetage.remove('keine');
                      }
                    });
                  },
                ),
                ...['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'].map((tag) {
                  final selected = _ruhetage.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        _ruhetage.remove('keine');
                        if (v) {
                          _ruhetage.add(tag);
                        } else {
                          _ruhetage.remove(tag);
                        }
                      });
                    },
                  );
                }),
              ],
            ),

            // === Betriebsferien (bis 5 Perioden, kompakt) ===
            const SizedBox(height: 16),
            Text('Betriebsferien',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Keine Betriebsferien'),
              value: _keineBetriebsferien,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() {
                _keineBetriebsferien = v;
                if (v) {
                  for (var i = 0; i < 5; i++) {
                    _ferienStarts[i] = null;
                    _ferienEnden[i] = null;
                  }
                  _ferienZeilen = 1;
                }
              }),
            ),
            if (!_keineBetriebsferien) ...[
              for (var i = 0; i < _ferienZeilen; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Ferien ${i + 1} von',
                        value: _ferienStarts[i],
                        onChanged: (v) =>
                            setState(() => _ferienStarts[i] = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Ferien ${i + 1} bis',
                        value: _ferienEnden[i],
                        onChanged: (v) =>
                            setState(() => _ferienEnden[i] = v),
                      ),
                    ),
                  ],
                ),
              ],
              if (_ferienZeilen < 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _ferienZeilen++),
                    icon: const Icon(Icons.add),
                    label: const Text('Weitere Ferien'),
                  ),
                ),
            ],

            // === Öffnungszeiten ===
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Öffnungszeiten',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                ),
                TextButton.icon(
                  onPressed: _oeffnungszeitenAlleUebernehmen,
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Mo → alle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildOeffnungszeitenForm(),

            // === Servicezeiten (nur für "meine Kunden") ===
            if (_istMeinKunde) ...[
              const SizedBox(height: 16),
              Text('Servicezeiten',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerField(
                      label: 'Morgen von',
                      value: _parseTime(_servicezeitMorgenAbCtrl.text),
                      onChanged: (t) => setState(() =>
                          _servicezeitMorgenAbCtrl.text = _formatTime(t) ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerField(
                      label: 'Morgen bis',
                      value: _parseTime(_servicezeitMorgenBisCtrl.text),
                      onChanged: (t) => setState(() =>
                          _servicezeitMorgenBisCtrl.text = _formatTime(t) ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerField(
                      label: 'Nachmittag von',
                      value: _parseTime(_servicezeitNachmittagAbCtrl.text),
                      onChanged: (t) => setState(() =>
                          _servicezeitNachmittagAbCtrl.text = _formatTime(t) ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerField(
                      label: 'Nachmittag bis',
                      value: _parseTime(_servicezeitNachmittagBisCtrl.text),
                      onChanged: (t) => setState(() =>
                          _servicezeitNachmittagBisCtrl.text = _formatTime(t) ?? ''),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // === Notizen ===
            TextFormField(
              controller: _zugangController,
              decoration: const InputDecoration(
                labelText: 'Zugang / Schlüssel',
                prefixIcon: Icon(Icons.vpn_key),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
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
                  : Text(_isEdit ? 'Speichern' : 'Betrieb erstellen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // === Öffnungszeiten Helpers ===
  static const _tageLabel = {
    'Mo': 'Montag', 'Di': 'Dienstag', 'Mi': 'Mittwoch',
    'Do': 'Donnerstag', 'Fr': 'Freitag', 'Sa': 'Samstag', 'So': 'Sonntag',
  };

  List<Widget> _buildOeffnungszeitenForm() {
    const tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return tage.map((tag) {
      final istRuhetag = _ruhetage.contains(tag);
      final slots = _oeffnungszeiten[tag] ?? [];
      final slotsText = istRuhetag
          ? 'Ruhetag'
          : slots.isNotEmpty
              ? slots.map((s) => '${s['von']} – ${s['bis']}').join(', ')
              : '–';
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          onTap: istRuhetag ? null : () => _editTagOeffnungszeiten(tag),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(tag, style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                      color: istRuhetag ? Colors.grey : null)),
                ),
                Expanded(
                  child: Text(slotsText, style: TextStyle(
                    fontSize: 13,
                    color: istRuhetag || slots.isEmpty ? Colors.grey : null,
                  )),
                ),
                if (!istRuhetag)
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _oeffnungszeitenAlleUebernehmen() {
    final moSlots = _oeffnungszeiten['Mo'] ?? [];
    setState(() {
      for (final tag in ['Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
        if (_ruhetage.contains(tag)) continue;
        _oeffnungszeiten[tag] = moSlots
            .map((s) => Map<String, String>.from(s))
            .toList();
      }
    });
  }

  Future<void> _editTagOeffnungszeiten(String tag) async {
    final slots = (_oeffnungszeiten[tag] ?? [])
        .map((s) => Map<String, String>.from(s))
        .toList();

    // Mindestens 1 Slot anzeigen
    if (slots.isEmpty) slots.add({'von': '', 'bis': ''});

    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (ctx) => _OeffnungszeitenDialog(
        tag: _tageLabel[tag] ?? tag,
        initialSlots: slots,
      ),
    );

    if (result != null) {
      setState(() {
        _oeffnungszeiten[tag] = result
            .where((s) => s['von']!.isNotEmpty && s['bis']!.isNotEmpty)
            .toList();
      });
    }
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

}

class _GoogleFeld {
  final String label;
  final String wert;
  final String aktuell;
  final void Function() uebernehmen;

  /// Optionale mehrzeilige Detailansicht (z.B. Öffnungszeiten pro Tag).
  final String? detail;
  _GoogleFeld(this.label, this.wert, this.aktuell, this.uebernehmen,
      {this.detail});
}

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
      lastDate: DateTime(2050),
    );
    if (picked != null) onChanged(picked);
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
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
              icon: const Icon(Icons.access_time, size: 18),
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
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) onChanged(picked);
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final buffer = StringBuffer();
    if (digits.startsWith('+')) {
      buffer.write('+');
      digits = digits.substring(1);
    }

    // Format: XX XX XXX XX XX (Leerzeichen nach Position 2, 4, 7, 9)
    const gaps = {2, 4, 7, 9};
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (gaps.contains(i)) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _OeffnungszeitenDialog extends StatefulWidget {
  final String tag;
  final List<Map<String, String>> initialSlots;

  const _OeffnungszeitenDialog({
    required this.tag,
    required this.initialSlots,
  });

  @override
  State<_OeffnungszeitenDialog> createState() => _OeffnungszeitenDialogState();
}

class _OeffnungszeitenDialogState extends State<_OeffnungszeitenDialog> {
  late List<Map<String, String>> _slots;

  @override
  void initState() {
    super.initState();
    _slots = widget.initialSlots
        .map((s) => Map<String, String>.from(s))
        .toList();
  }

  TimeOfDay? _parse(String? v) {
    if (v == null || v.isEmpty) return null;
    final parts = v.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int index, String field) async {
    final current = _parse(_slots[index][field]);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _slots[index][field] = _fmt(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tag),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._slots.asMap().entries.map((e) {
              final i = e.key;
              final slot = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(i, 'von'),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Von',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          child: Text(slot['von']!.isEmpty ? '–' : slot['von']!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(i, 'bis'),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Bis',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          child: Text(slot['bis']!.isEmpty ? '–' : slot['bis']!),
                        ),
                      ),
                    ),
                    if (_slots.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => setState(() => _slots.removeAt(i)),
                      ),
                  ],
                ),
              );
            }),
            if (_slots.length < 3)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _slots.add({'von': '', 'bis': ''})),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Zeitfenster hinzufügen'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context, <Map<String, String>>[]);
              },
              child: const Text('Ruhetag (keine Zeiten)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _slots),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
