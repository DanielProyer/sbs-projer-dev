import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/arbeitszeit_block.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/betrieb_feld.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'dart:async';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/pause_pruefen_helfer.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/ungespeichert_schutz.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/material_slots.dart';
import 'package:sbs_projer_app/presentation/widgets/mahn_hinweis_band.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

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
  ConsumerState<StoerungFormScreen> createState() => _StoerungFormScreenState();
}

class _StoerungFormScreenState extends ConsumerState<StoerungFormScreen>
    with UngespeichertMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  StoerungLocal? _existing;

  /// Erst geplant (Status 'offen') statt erledigt ('behoben') — nur so
  /// erscheint die Störung im Tourenplan.
  bool _geplant = false;

  // Zeiterfassung
  late DateTime _datum;
  late final _heinekennrController = TextEditingController();
  late final _stoerungseingangController = TextEditingController();

  // Arbeitszeit-Erfassung (Migration 163 / Daniel 31.07.2026): "Beginn"-Knopf
  // mit GPS-Stempel + Status "in_bearbeitung"; beide Zeiten bleiben zusaetzlich
  // von Hand aenderbar, falls der Knopf vergessen wurde.
  late final _arbeitVonController = TextEditingController();
  late final _arbeitBisController = TextEditingController();
  bool _arbeitBeginnLaeuft = false;

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
  final List<TextEditingController> _materialControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _materialMengenControllers = List.generate(
    5,
    (_) => TextEditingController(text: '1'),
  );
  final List<TextEditingController?> _autoCompleteControllers = List.filled(
    5,
    null,
  );

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
        var befuellt = false;
        final warGeaendert = geaendert;
        setState(() {
          _lagerItems = items;
          // Material-Controller mit Namen befüllen (wenn IDs gesetzt)
          for (int i = 0; i < 5; i++) {
            if (_materialIds[i] != null &&
                _materialControllers[i].text.isEmpty) {
              final lager = items
                  .where((l) => l.id == _materialIds[i])
                  .firstOrNull;
              if (lager != null) {
                _materialControllers[i].text = lager.name;
                befuellt = true;
              }
            }
          }
        });
        // Das Lager kommt asynchron und kann NACH dem Aufbau des Formulars
        // eintreffen (Reihenfolge zu _loadStoerung ist nicht garantiert).
        // Das Befüllen der Material-Controller meldet TextFormField dann als
        // Änderung — der Nutzer hat aber nichts angefasst.
        if (befuellt && !warGeaendert) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => geaendertZuruecksetzen(),
          );
        }
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
      _geplant = s.status == 'offen' || s.status == 'in_bearbeitung';
      _datum = s.datum;
      _heinekennrController.text = s.referenzNr ?? '';
      final zeit = s.uhrzeitStart ?? '';
      _stoerungseingangController.text = zeit.length >= 5
          ? zeit.substring(0, 5)
          : zeit;
      _beschreibungController.text = s.problemBeschreibung;
      _stoerungBereiche = s.stoerungBereiche ?? [];
      _betriebId = s.betriebId;
      _anlageTyp = s.anlageTyp;
      _istPikettWochenende = s.istPikettEinsatz;
      _istBergkunde = s.istBergkunde;
      _istKilometerabrechnung = s.istKilometerabrechnung;
      _notizenController.text = s.notizen ?? '';
      _arbeitVonController.text = s.arbeitVon ?? '';
      _arbeitBisController.text = s.arbeitBis ?? '';
      _anfahrtKmController.text = s.anfahrtKm.toString();
      _komplexitaetController.text = (s.komplexitaetZuschlag ?? 0)
          .toStringAsFixed(0);

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
        _materialMengenControllers[i].text = _materialMengen[i].toStringAsFixed(
          0,
        );
      }
    });
    _loadPreisData();
  }

  bool get _warGeplant =>
      _isEdit &&
      _existing != null &&
      (_existing!.status == 'offen' || _existing!.status == 'in_bearbeitung');

  /// "Beginn"-Knopf: setzt Arbeit-von auf jetzt, stempelt einen Wegpunkt mit
  /// GPS und setzt den Status auf "in_bearbeitung" — gezielt und sofort
  /// persistiert, unabhaengig vom Haupt-Speichern (das Formular kann noch
  /// unvollstaendig sein). Fehler duerfen die App nicht blockieren.
  /// «Arbeit beenden»-Knopf: setzt Arbeit-bis auf jetzt und behebt die
  /// Störung — sofort persistiert, unabhängig vom Haupt-Speichern.
  ///
  /// Ohne diesen Knopf war ein einmal gestarteter Einsatz über den normalen
  /// Weg nicht abschliessbar (Fall Sartons, 11.08.2026). `dauerStunden` und
  /// Preisfelder bleiben unangetastet — die gehören in den Rapport.
  Future<void> _arbeitBeenden() async {
    final zeitStr = _formatTime(TimeOfDay.now());
    setState(() {
      _arbeitBisController.text = zeitStr;
      _geplant = false;
      _existing?.status = 'behoben';
      _arbeitBeginnLaeuft = true;
    });

    final id = widget.stoerungId;
    try {
      if (id != null) {
        await StoerungRepository.arbeitszeitSetzen(
          id: id,
          von: _emptyToNull(_arbeitVonController.text),
          bis: zeitStr,
        );
        await StoerungRepository.statusSetzen(id: id, status: 'behoben');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Arbeit beendet ($zeitStr) — Rapport ergänzen '
              'und speichern nicht vergessen.',
            ),
          ),
        );
      }
    } catch (e) {
      // Die Zeit steht jetzt nur noch lokal im Controller — der haengt an
      // keinem FormField, also merkt Form.onChanged nichts davon.
      markiereGeaendert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ende nicht gespeichert: ${kurzeFehlermeldung(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _arbeitBeginnLaeuft = false);
    }
  }

  Future<void> _arbeitBeginnen() async {
    final zeitStr = _formatTime(TimeOfDay.now());
    setState(() {
      _arbeitVonController.text = zeitStr;
      _existing?.status = 'in_bearbeitung';
      _arbeitBeginnLaeuft = true;
    });

    final id = widget.stoerungId;
    try {
      if (id != null) {
        await StoerungRepository.arbeitszeitSetzen(
          id: id,
          von: zeitStr,
          bis: _emptyToNull(_arbeitBisController.text),
        );
        await StoerungRepository.statusSetzen(id: id, status: 'in_bearbeitung');
      }
    } catch (e) {
      debugPrint('[Arbeitszeit] Beginn konnte nicht gespeichert werden: $e');
      // Die Zeit steht jetzt nur noch lokal im Controller — der haengt an
      // keinem FormField, also merkt Form.onChanged nichts davon.
      markiereGeaendert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beginn nicht gespeichert: ${kurzeFehlermeldung(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _arbeitBeginnLaeuft = false);
    }

    // Wegpunkt mit GPS stempeln — Ist-Ort bei Arbeitsbeginn (fire-and-forget,
    // stoert das Formular nicht bei Fehlern).
    unawaited(
      WegpunktRepository.stempeln(
        quelle: 'stoerung',
        betriebId: _betriebId,
        referenzId: _existing?.serverId,
        notiz: 'Arbeitsbeginn',
      ),
    );
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
    if (_preisliste == null ||
        (_stoerungBereiche.isEmpty && !_istKilometerabrechnung)) {
      return {};
    }
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
    final kmGrenze =
        (p['stoerung_anfahrt_km_grenze'] as num?)?.toDouble() ?? 80;
    final pauschale =
        (p['stoerung_anfahrt_pauschale'] as num?)?.toDouble() ?? 60;
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

    // Muss VOR jeder Statusmutation unten erfasst werden: "war der Einsatz
    // bislang geplant/laufend?" entscheidet, ob dies ein echter Abschluss-
    // Moment ist (Datum auf heute korrigieren, Wegpunkt/Pause pruefen) oder
    // nur eine Bearbeitung eines bereits erledigten Eintrags (Daniel
    // 31.07.2026).
    final warGeplant = _warGeplant;
    final schliesstJetztAb = warGeplant && !_geplant;
    final istWegpunktMoment = (!_isEdit && !_geplant) || schliesstJetztAb;

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
        s.material1Id = null;
        s.material1Menge = null;
        s.material2Id = null;
        s.material2Menge = null;
        s.material3Id = null;
        s.material3Menge = null;
        s.material4Id = null;
        s.material4Menge = null;
        s.material5Id = null;
        s.material5Menge = null;
      } else {
        if (!_isEdit) {
          s.anlageId = widget.anlageId;
        }
        s.betriebId = _betriebId;
        s.anlageTyp = _anlageTyp;
        s.referenzNr = _emptyToNull(_heinekennrController.text);
        s.stoerungBereiche = _stoerungBereiche.isEmpty
            ? null
            : _stoerungBereiche;
        // Fallback: Text-Matching wenn User getippt aber nicht aus Dropdown gewählt hat
        for (int i = 0; i < 5; i++) {
          if (_materialIds[i] == null) {
            final text =
                (_autoCompleteControllers[i] ?? _materialControllers[i]).text
                    .trim();
            if (text.isNotEmpty && _lagerItems.isNotEmpty) {
              final match = _lagerItems
                  .where((l) => l.name.toLowerCase() == text.toLowerCase())
                  .firstOrNull;
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

      // datum steuert die Abrechnung (abrechnungs_monat). Normal aus dem
      // Formular — AUSSER beim echten Abschluss eines vorher geplanten
      // Einsatzes: dann zaehlt der tatsaechliche Arbeitstag (heute), sonst
      // wuerde eine im Juli gemeldete, im August erledigte Stoerung im
      // falschen Monat abgerechnet (Daniel 31.07.2026). gemeldet_am bleibt
      // davon unberuehrt.
      if (schliesstJetztAb) {
        final heute = DateTime.now();
        s.datum = DateTime(heute.year, heute.month, heute.day);
      } else {
        s.datum = _datum;
      }
      s.uhrzeitStart = _emptyToNull(_stoerungseingangController.text);
      s.problemBeschreibung = _beschreibungController.text.trim();
      s.istPikettEinsatz = _istPikettWochenende;
      s.istBergkunde = _istBergkunde;
      s.istWochenende = _istPikettWochenende;
      s.notizen = _emptyToNull(_notizenController.text);

      // Arbeitszeit: von Hand aenderbar (Beginn-Knopf ggf. vergessen). Beim
      // Abschliessen wird das Ende automatisch nachgetragen, wenn noch leer.
      if (schliesstJetztAb && _emptyToNull(_arbeitBisController.text) == null) {
        _arbeitBisController.text = _formatTime(TimeOfDay.now());
      }
      s.arbeitVon = _emptyToNull(_arbeitVonController.text);
      s.arbeitBis = _emptyToNull(_arbeitBisController.text);

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

      // Ist die Arbeit zu Ende erfasst, gilt der Einsatz als erledigt — auch
      // wenn der «Erst geplant»-Schalter noch an steht (Fall Sartons,
      // 11.08.2026). Regel + Begründung: core/util/einsatz_status.dart.
      s.status = einsatzStatusNachSpeichern(
        geplant: _geplant,
        arbeitVon: s.arbeitVon,
        arbeitBis: s.arbeitBis,
        offenWert: 'offen',
        erledigtWert: 'behoben',
      );

      await StoerungRepository.save(s);
      // Ein erledigter Einsatz gehört in die Ist-Ansicht, nicht mehr in den
      // Plan — sonst steht die (jetzt behobene) Störung als „Geisterblock"
      // weiter in der Zeitachse des Tages, für den sie geplant war (Daniel
      // 02.08.2026). `s.geplantAm` ist hier noch das VOR dem Speichern
      // geladene Plandatum (`save` fasst `geplantAm` nicht an).
      if (schliesstJetztAb && s.geplantAm != null) {
        final geplanterTag = DateTime(
          s.geplantAm!.year,
          s.geplantAm!.month,
          s.geplantAm!.day,
        );
        unawaited(
          einsatzAusTagesplanEntfernen(ref, geplanterTag, 's_${s.routeId}'),
        );
      }
      // Wegpunkt beim NEU-Erfassen eines sofort erledigten Einsatzes UND
      // beim Abschliessen eines vorher geplanten Einsatzes: der Stempel
      // markiert den tatsächlichen Einsatz-Zeitpunkt für Routen-Daten und
      // den Fahrzeit-Guard. Eine bloss geplante/laufende Störung, die so
      // bleibt, war noch nirgends — ihr Stempel würde die Fahrzeit-
      // Lernkurve verfälschen (Daniel 30./31.07.2026).
      if (istWegpunktMoment) {
        unawaited(
          WegpunktRepository.stempeln(
            quelle: 'stoerung',
            betriebId: s.betriebId,
            referenzId: s.serverId,
          ),
        );
        // Vergessene Pause abfangen (Daniel 31.07.2026): laeuft noch eine
        // Pause, jetzt anhand der aktuellen Position pruefen — NIE
        // blockierend, eigener try/catch.
        if (mounted) {
          try {
            await pausePruefenNachEreignis(context, ref);
          } catch (e) {
            debugPrint('[Pause-Pruefung] uebersprungen, Fehler: $e');
          }
        }
      }
      if (_materialIds.any((id) => id != null)) {
        ref.invalidate(materialienStreamProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? (_istKilometerabrechnung
                        ? 'Kilometerabrechnung aktualisiert'
                        : 'Störung aktualisiert')
                  : (_istKilometerabrechnung
                        ? 'Kilometerabrechnung erfasst'
                        : 'Störung erfasst'),
            ),
          ),
        );
        if (kIsWeb) ref.invalidate(stoerungenStreamProvider);
        // Gespeichert — der Schutz darf beim Verlassen nicht mehr fragen.
        geaendertZuruecksetzen();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: ${kurzeFehlermeldung(e)}')),
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
    final isWeekend =
        _datum.weekday == DateTime.saturday ||
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
        moving.any(
          (h) => h.year == d.year && h.month == d.month && h.day == d.day,
        );
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
    _arbeitVonController.dispose();
    _arbeitBisController.dispose();
    _beschreibungController.dispose();
    _notizenController.dispose();
    _anfahrtKmController.dispose();
    _komplexitaetController.dispose();
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
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return UngespeichertSchutz(
      geaendert: geaendert,
      was: 'Die Störung',
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _istKilometerabrechnung
                ? (_isEdit
                      ? 'Kilometerabrechnung bearbeiten'
                      : 'Neue Kilometerabrechnung')
                : (_isEdit ? 'Störung bearbeiten' : 'Neue Störung'),
          ),
        ),
        body: Form(
          key: _formKey,
          // Deckt alle FormFields ab; Schalter, Chips, Datum/Zeit und die
          // Material-Auswahl melden sich selbst.
          onChanged: markiereGeaendert,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === Geplant / erledigt ===
              // Bis v0.59.0 schrieb das Formular immer 'behoben' — eine Störung
              // liess sich also gar nicht vorausplanen und tauchte nie im
              // Tourenplan auf (Fund Daniel 31.07.2026).
              SwitchListTile(
                title: const Text('Erst geplant'),
                subtitle: Text(
                  _geplant
                      ? 'Erscheint im Tourenplan; Rapport folgt beim Erledigen'
                      : 'Erledigt — Rapport wird jetzt erfasst',
                ),
                secondary: Icon(
                  _geplant ? Icons.event_outlined : Icons.check_circle_outline,
                  color: _geplant ? AppColors.info : AppColors.success,
                ),
                value: _geplant,
                activeTrackColor: AppColors.info,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  markiereGeaendert();
                  setState(() => _geplant = v);
                },
              ),
              const Divider(height: 24),

              // === Kilometerabrechnung Switch ===
              SwitchListTile(
                title: const Text('Kilometerabrechnung'),
                subtitle: const Text('Nur Anfahrt abrechnen (ohne Störung)'),
                secondary: const Icon(Icons.directions_car),
                value: _istKilometerabrechnung,
                activeTrackColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  markiereGeaendert();
                  setState(() => _istKilometerabrechnung = v);
                  // Bei neuem Eintrag: Beschreibung aus letzter Km-Abrechnung vorausfüllen
                  if (v && !_isEdit) {
                    final stoerungen = ref.read(stoerungenProvider);
                    final letzte =
                        stoerungen
                            .where((s) => s.istKilometerabrechnung)
                            .toList()
                          ..sort((a, b) => b.datum.compareTo(a.datum));
                    if (letzte.isNotEmpty) {
                      if (_beschreibungController.text.isEmpty) {
                        _beschreibungController.text =
                            letzte.first.problemBeschreibung;
                      }
                      if (_anfahrtKmController.text == '0') {
                        _anfahrtKmController.text = letzte.first.anfahrtKm
                            .toString();
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
                // Gemahnte Rechnungen — vor Ort bar einkassieren (Mahnwesen Teil 3).
                MahnHinweisBand(
                  betriebId: _betriebId,
                  padding: const EdgeInsets.only(top: 8),
                ),
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
              ArbeitszeitBlock(
                vonController: _arbeitVonController,
                bisController: _arbeitBisController,
                beginnMoeglich: _warGeplant,
                laeuft: _arbeitBeginnLaeuft,
                onBeginnen: _arbeitBeginnen,
                onBeenden: _arbeitBeenden,
                onGeaendert: markiereGeaendert,
                zwischen: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final picked = await zeigeDatumsauswahl(
                              context,
                              initial: _datum,
                              erstes: DateTime(2024),
                              letztes: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked != null) {
                              markiereGeaendert();
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
                  const SizedBox(height: 12),
                ],
              ),
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
              _sectionTitle(
                context,
                _istKilometerabrechnung
                    ? 'Beschreibung'
                    : 'Störungsbeschreibung',
              ),
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
                    ? (v) => (v == null || v.trim().isEmpty)
                          ? 'Beschreibung erforderlich'
                          : null
                    : null,
              ),
              const SizedBox(height: 24),

              // === Optionen (nur bei normaler Störung) ===
              if (!_istKilometerabrechnung) ...[
                _sectionTitle(context, 'Optionen'),
                const SizedBox(height: 8),
                _checkTile(
                  'Pikett / Wochenende / Feiertag',
                  _istPikettWochenende,
                  (v) {
                    markiereGeaendert();
                    setState(() => _istPikettWochenende = v);
                  },
                ),
                _checkTile('Bergkunde', _istBergkunde, (v) {
                  markiereGeaendert();
                  setState(() => _istBergkunde = v);
                }),
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
                MaterialSlots(
                  lager: _lagerItems,
                  ids: _materialIds,
                  namen: _materialControllers,
                  mengenController: _materialMengenControllers,
                  mengen: _materialMengen,
                  feldController: _autoCompleteControllers,
                  onGeaendert: markiereGeaendert,
                ),
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
              TapKnopf(
                text: _isEdit
                    ? 'Speichern'
                    : (_istKilometerabrechnung
                          ? 'Kilometerabrechnung erfassen'
                          : 'Störung erfassen'),
                laeuft: _isLoading,
                onTap: _save,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
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
        onSelected: (v) {
          markiereGeaendert();
          setState(() => _anlageTyp = v ? value : null);
        },
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
    return BetriebFeld(
      betriebe: ref.watch(betriebeProvider),
      betriebId: _betriebId,
      onGeaendert: markiereGeaendert,
      onGeleert: () => setState(() {
        _betriebId = null;
        _istBergkunde = false;
      }),
      onGewaehlt: (b) {
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
        markiereGeaendert();
        setState(() {
          if (v) {
            _stoerungBereiche = [..._stoerungBereiche, value]..sort();
          } else {
            _stoerungBereiche = _stoerungBereiche
                .where((b) => b != value)
                .toList();
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
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
              _istKilometerabrechnung
                  ? 'Basis'
                  : 'Basis (Bereich ${_stoerungBereiche.join(', ')})',
              preis['basis']!,
            ),
          if (preis['anfahrt']! > 0) _preisRow('Anfahrt', preis['anfahrt']!),
          if (preis['wochenende']! > 0)
            _preisRow('Pikett/WE-Zuschlag', preis['wochenende']!),
          if (preis['komplex']! > 0)
            _preisRow('Zusatzkosten', preis['komplex']!),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                '${preis['total']!.toStringAsFixed(2)} CHF',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${betrag.toStringAsFixed(2)} CHF',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
