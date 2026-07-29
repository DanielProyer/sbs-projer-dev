import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_korrektur_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/data/repositories/bergkundenpauschale_repository.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_qr_dialog.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';
import 'package:uuid/uuid.dart';

class ReinigungFormScreen extends ConsumerStatefulWidget {
  final String? reinigungId; // null = neu
  final String? anlageId; // für neue Reinigung
  final String? betriebId; // für neue Reinigung

  const ReinigungFormScreen({
    super.key,
    this.reinigungId,
    this.anlageId,
    this.betriebId,
  });

  @override
  ConsumerState<ReinigungFormScreen> createState() =>
      _ReinigungFormScreenState();
}

String _monatName(int monat) {
  const namen = [
    '',
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return namen[monat];
}

class _ReinigungFormScreenState extends ConsumerState<ReinigungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  ReinigungLocal? _existing;

  // Zeiterfassung
  late DateTime _datum;
  late final _uhrzeitStartController = TextEditingController();
  late final _uhrzeitEndeController = TextEditingController();
  late final _notizenController = TextEditingController();

  // Protokoll-Foto
  Uint8List? _fotoBytes;
  bool _fotoUploading = false;
  String? _existingFotoPfad;

  // Lade-Status
  bool _anlagenLoaded = false;

  // Neue Felder
  bool _istKulanz = false;
  bool _istHeinekenMonteur = false;
  String _serviceArt = 'standardservice';
  bool _wasserKuehlerGewechselt = false;
  ReinigungLocal? _letzteReinigung;

  // Preis-Kalkulator
  String? _serviceTyp;
  bool _istBergkunde = false;
  int _anzahlHaehneEigen = 0;
  int _anzahlHaehneOrion = 0;
  int _anzahlHaehneFremd = 0;
  int _anzahlHaehneWein = 0;
  int _anzahlHaehneAndererStandort = 0;
  Map<String, dynamic>? _preisliste;

  String _status = 'offen';
  BetriebLocal? _betrieb;
  String? _rechnungsstellung;
  // true sobald der User im Abschluss-Dialog eine Zahlungsart BESTÄTIGT hat —
  // nur dann darf _rechnungsstellung den frischen Betriebs-Default übersteuern
  // (beim Erstöffnen stammt _rechnungsstellung aus dem evtl. veralteten Cache).
  bool _zahlungsartManuellGewaehlt = false;

  // Multi-Anlagen-Auswahl
  List<AnlageLocal> _anlagenDesBetrieb = [];
  Set<String> _selectedAnlageIds = {};

  bool get _isEdit => widget.reinigungId != null;

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _uhrzeitStartController.text = _formatTime(TimeOfDay.now());
    // Betrieb sofort aus Provider laden (synchron)
    if (widget.betriebId != null) {
      final betriebe = ref.read(betriebeProvider);
      final match = betriebe
          .where((b) => b.serverId == widget.betriebId)
          .firstOrNull;
      if (match != null) {
        _betrieb = match;
        _rechnungsstellung = match.rechnungsstellung;
        _istBergkunde = match.istBergkunde;
      }
    }
    if (_isEdit) {
      _loadReinigung();
    } else {
      _loadPreisData();
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 'HH:mm' -> Minuten seit Mitternacht, fuer die Fahrzeit-Nachfuehrung
  /// (Auswahl der zeitlich letzten vorherigen Reinigung). Lokale Kopie statt
  /// Abhaengigkeit — dieselbe Parsing-Regel wie in besuch_dauer.dart.
  int? _hmMinuten(String? s) {
    if (s == null) return null;
    final t = s.split(':');
    if (t.length < 2) return null;
    final h = int.tryParse(t[0]), m = int.tryParse(t[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Future<void> _loadReinigung() async {
    final r = await ReinigungRepository.getById(widget.reinigungId!);
    if (r == null || !mounted) return;

    setState(() {
      _existing = r;
      _datum = r.datum;
      _uhrzeitStartController.text = r.uhrzeitStart ?? '';
      _uhrzeitEndeController.text = r.uhrzeitEnde ?? '';
      _notizenController.text = r.notizen ?? '';
      _status = r.status;
      _existingFotoPfad = r.protokollFotoPfad;
      _istKulanz = r.istKulanz;
      _istHeinekenMonteur = r.istHeinekenMonteur;
      _serviceArt = r.serviceArt ?? _serviceArt;
      _wasserKuehlerGewechselt = r.wasserKuehlerGewechselt;
      // Preis-Felder
      _serviceTyp = r.serviceTyp;
      _istBergkunde = r.istBergkunde;
      _anzahlHaehneEigen = r.anzahlHaehneEigen;
      _anzahlHaehneOrion = r.anzahlHaehneOrion;
      _anzahlHaehneFremd = r.anzahlHaehneFremd;
      _anzahlHaehneWein = r.anzahlHaehneWein;
      _anzahlHaehneAndererStandort = r.anzahlHaehneAndererStandort;
      // Multi-Anlagen: aus anlageIdsJson laden
      if (r.anlageIdsJson != null) {
        _selectedAnlageIds = Set<String>.from(
          (jsonDecode(r.anlageIdsJson!) as List).map((e) => e.toString()),
        );
      } else if (r.anlageId.isNotEmpty) {
        _selectedAnlageIds = {r.anlageId};
      }
      // Betrieb sofort aus Provider laden (synchron, Fallback)
      if (r.betriebId.isNotEmpty) {
        final betriebe = ref.read(betriebeProvider);
        final match = betriebe
            .where((b) => b.serverId == r.betriebId)
            .firstOrNull;
        if (match != null) {
          _betrieb = match;
          _rechnungsstellung = match.rechnungsstellung;
        }
      }
    });
    _loadPreisData();
  }

  Future<void> _loadPreisData() async {
    final betriebId = widget.betriebId ?? _existing?.betriebId;

    // Preisliste laden (optional, darf nicht Betrieb/Anlagen blockieren)
    try {
      final preisRows = await SupabaseService.client
          .from('preise')
          .select()
          .lte('gueltig_ab', _datum.toIso8601String().substring(0, 10))
          .order('gueltig_ab', ascending: false)
          .limit(1);
      if (preisRows.isNotEmpty && mounted) {
        setState(() => _preisliste = preisRows.first);
      }
    } catch (_) {}

    // Betrieb → Bergkunde + Rechnungsstellung + Anlagen laden
    if (betriebId != null && betriebId.isNotEmpty) {
      try {
        final betrieb = await BetriebRepository.getByServerId(betriebId);
        if (betrieb != null && mounted) {
          setState(() {
            _betrieb = betrieb;
            _rechnungsstellung = betrieb.rechnungsstellung;
            if (!_isEdit) _istBergkunde = betrieb.istBergkunde;
          });
        }
      } catch (e) {
        debugPrint('[Reinigung] Betrieb laden fehlgeschlagen: $e');
      }

      try {
        // Alle Anlagen des Betriebs laden
        final anlagen = await AnlageRepository.getByBetrieb(betriebId);
        if (mounted) {
          setState(() {
            _anlagenDesBetrieb = anlagen;
            _anlagenLoaded = true;
            // Bei neuer Reinigung: alle Anlagen vorausgewählt
            if (!_isEdit && _selectedAnlageIds.isEmpty) {
              _selectedAnlageIds = anlagen
                  .map((a) => a.serverId ?? a.routeId)
                  .toSet();
            }
          });
        }
      } catch (e) {
        debugPrint('[Reinigung] Anlagen laden fehlgeschlagen: $e');
        if (mounted) setState(() => _anlagenLoaded = true);
      }

      // Letzte Reinigung laden (für Vorausfüllung bei neuer Reinigung)
      if (!_isEdit) {
        try {
          final letzte = await ReinigungRepository.getLastByBetrieb(betriebId);
          if (letzte != null && mounted) {
            _letzteReinigung = letzte;
            setState(() {
              _serviceTyp ??= letzte.serviceTyp;
              if (_anzahlHaehneEigen == 0)
                _anzahlHaehneEigen = letzte.anzahlHaehneEigen;
              if (_anzahlHaehneOrion == 0)
                _anzahlHaehneOrion = letzte.anzahlHaehneOrion;
              if (_anzahlHaehneFremd == 0)
                _anzahlHaehneFremd = letzte.anzahlHaehneFremd;
              if (_anzahlHaehneWein == 0)
                _anzahlHaehneWein = letzte.anzahlHaehneWein;
              if (_anzahlHaehneAndererStandort == 0) {
                _anzahlHaehneAndererStandort =
                    letzte.anzahlHaehneAndererStandort;
              }
            });
          }
        } catch (_) {}
      }
    }

    // ServiceTyp ableiten (aus erster ausgewählter Anlage)
    if (_serviceTyp == null && _selectedAnlageIds.isNotEmpty) {
      final firstAnlage = _anlagenDesBetrieb
          .where((a) => _selectedAnlageIds.contains(a.serverId ?? a.routeId))
          .firstOrNull;
      if (firstAnlage != null && mounted) {
        setState(() {
          _serviceTyp = switch (firstAnlage.typAnlage.toLowerCase()) {
            'orion' => 'reinigung_orion',
            'heigenie' => 'heigenie',
            _ => 'reinigung_bier',
          };
        });
      }
    }

    // Bierleitungen → Hähne zählen (aus allen ausgewählten Anlagen)
    try {
      if (!_isEdit &&
          _selectedAnlageIds.isNotEmpty &&
          _letzteReinigung == null) {
        await _recalculateHaehne();
      }
    } catch (_) {}
  }

  Future<void> _recalculateHaehne() async {
    int eigen = 0, orion = 0, fremd = 0, wein = 0;
    for (final anlageId in _selectedAnlageIds) {
      final leitungen = await BierleitungRepository.getByAnlage(anlageId);
      for (final l in leitungen) {
        if (!l.istAktiv) continue;
        final sorte = (l.biersorte ?? '').toLowerCase();
        if (sorte.contains('wein') || sorte.contains('wine')) {
          wein++;
        } else if (sorte.contains('orion')) {
          orion++;
        } else if (sorte.contains('heineken') ||
            sorte.contains('desperados') ||
            sorte.contains('calanda') ||
            sorte.contains('eichhof') ||
            sorte.contains('birra moretti') ||
            sorte.isEmpty) {
          eigen++;
        } else {
          fremd++;
        }
      }
    }
    if (mounted) {
      setState(() {
        _anzahlHaehneEigen = eigen;
        _anzahlHaehneOrion = orion;
        _anzahlHaehneFremd = fremd;
        _anzahlHaehneWein = wein;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    _onPhotoTaken(bytes);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    _onPhotoTaken(bytes);
  }

  void _onPhotoTaken(Uint8List bytes) {
    setState(() {
      _fotoBytes = bytes;
      _existingFotoPfad = null;
    });
  }

  Future<void> _save({bool abschliessen = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final r = _existing ?? ReinigungLocal();

      // Betrieb immer aktualisieren (auch bei Edit, falls gewechselt)
      r.betriebId = _betrieb?.serverId ?? widget.betriebId ?? r.betriebId;
      // Multi-Anlagen: anlageIds + anlageIdsJson + anlageId synchron setzen
      if (_selectedAnlageIds.isNotEmpty) {
        r.anlageIds = _selectedAnlageIds.toList();
        r.anlageIdsJson = jsonEncode(_selectedAnlageIds.toList());
        r.anlageId = _selectedAnlageIds.first;
      } else if (!_isEdit) {
        r.anlageId = widget.anlageId ?? '';
      }

      r.datum = _datum;
      r.uhrzeitStart = _emptyToNull(_uhrzeitStartController.text);
      r.uhrzeitEnde = _emptyToNull(_uhrzeitEndeController.text);
      r.notizen = _emptyToNull(_notizenController.text);

      // Kulanz / Heineken-Monteur
      r.istKulanz = _istKulanz;
      r.istHeinekenMonteur = _istHeinekenMonteur;
      r.serviceArt = _serviceArt;
      r.wasserKuehlerGewechselt = _wasserKuehlerGewechselt;

      if (_istHeinekenMonteur) {
        // Heineken-Monteur: nur Datum, keine Preise/Checkliste
        r.serviceTyp = null;
        r.istBergkunde = false;
        r.anzahlHaehneEigen = 0;
        r.anzahlHaehneOrion = 0;
        r.anzahlHaehneFremd = 0;
        r.anzahlHaehneWein = 0;
        r.anzahlHaehneAndererStandort = 0;
        r.preisGrundtarif = null;
        r.preisZusatzHaehne = null;
        r.bergkundenZuschlag = null;
        r.preisNetto = null;
        r.mwstSatz = null;
        r.preisMwst = null;
        r.preisBrutto = null;
      } else if (_istKulanz) {
        // Kulanz: Positionen normal, aber alle Preise 0
        r.serviceTyp = _serviceTyp;
        r.istBergkunde = _istBergkunde;
        r.anzahlHaehneEigen = _anzahlHaehneEigen;
        r.anzahlHaehneOrion = _anzahlHaehneOrion;
        r.anzahlHaehneFremd = _anzahlHaehneFremd;
        r.anzahlHaehneWein = _anzahlHaehneWein;
        r.anzahlHaehneAndererStandort = _anzahlHaehneAndererStandort;
        r.preisGrundtarif = 0;
        r.preisZusatzHaehne = 0;
        r.bergkundenZuschlag = 0;
        r.preisNetto = 0;
        r.mwstSatz = 8.1;
        r.preisMwst = 0;
        r.preisBrutto = 0;
      } else {
        // Normal: Preis-Kalkulation
        r.serviceTyp = _serviceTyp;
        r.istBergkunde = _istBergkunde;
        r.anzahlHaehneEigen = _anzahlHaehneEigen;
        r.anzahlHaehneOrion = _anzahlHaehneOrion;
        r.anzahlHaehneFremd = _anzahlHaehneFremd;
        r.anzahlHaehneWein = _anzahlHaehneWein;
        r.anzahlHaehneAndererStandort = _anzahlHaehneAndererStandort;

        final preis = _calculatePreis();
        if (preis.isNotEmpty) {
          r.preisGrundtarif = preis['grundtarif'];
          r.preisZusatzHaehne = preis['zusatz'];
          r.bergkundenZuschlag = preis['bergkundenZuschlag'];
          r.preisNetto = preis['netto'];
          r.mwstSatz = preis['mwstSatz'];
          r.preisMwst = preis['mwst'];
          r.preisBrutto = preis['brutto'];
        }
      }

      // Status ZUERST setzen (vor Foto-Upload, damit kein Doppel-Eintrag entsteht)
      if (abschliessen) {
        r.status = 'abgeschlossen';
        r.uhrzeitEnde ??= _formatTime(TimeOfDay.now());
        // Zahlungsart auf der Reinigung fixieren — ab hier ist NUR dieser Wert
        // massgebend (nie mehr die Betriebs-Einstellung zum Buchungszeitpunkt).
        r.zahlungsart = _rechnungsstellung ?? 'rechnung_tresen';
      } else {
        r.status = _status;
      }

      r.userId = SupabaseService.currentUser!.id;

      // Auf Web: UUID vorab generieren damit Foto-Upload und finaler Save dieselbe ID verwenden
      if (kIsWeb && !_isEdit && r.serverId == null) {
        r.serverId = const Uuid().v4();
      }

      // Foto hochladen (wenn neues Foto aufgenommen)
      if (_fotoBytes != null && !_istHeinekenMonteur) {
        setState(() => _fotoUploading = true);
        try {
          // Auf Native: zuerst speichern um eine Isar-ID zu haben
          if (!kIsWeb && !_isEdit) {
            await ReinigungRepository.save(r);
          }

          final reinigungId = r.serverId ?? r.routeId;
          final pfad = await ProtokollFotoStorage.uploadFoto(
            reinigungId,
            _fotoBytes!,
          );
          r.protokollFotoPfad = pfad;
        } catch (e) {
          debugPrint('Foto-Upload fehlgeschlagen: $e');
        } finally {
          if (mounted) setState(() => _fotoUploading = false);
        }
      } else if (_existingFotoPfad != null && !_istHeinekenMonteur) {
        r.protokollFotoPfad = _existingFotoPfad;
      }

      await ReinigungRepository.save(r);

      // Fahrzeit-Nachfuehrung (Spec 2026-07-29 §3.1, Task 4): NUR beim
      // Uebergang zu 'abgeschlossen' (nicht bei jedem Save), sonst wuerde
      // jede spaetere Notiz-Korrektur einer bereits abgeschlossenen Reinigung
      // denselben Uebergang erneut zaehlen — `anzahl` waechst kuenstlich und
      // verwaessert den gleitenden Mittelwert (Review-Befund 29.07.2026).
      // Erkennung: abschliessen==true UND der Status VOR diesem Save war noch
      // nicht 'abgeschlossen' (_existing = geladener Stand vor den Edits).
      final wurdeGeradeAbgeschlossen =
          abschliessen && _existing?.status != 'abgeschlossen';
      // Eigener try/catch: die synchrone Vorgaenger-Suche haengt sonst im
      // aeusseren try von _save — eine Exception hier wuerde dem Nutzer
      // faelschlich "Fehler" zeigen, obwohl das Speichern (Zeile oben) schon
      // durch war, und wuerde Snackbar/Invalidierung/pop ueberspringen.
      if (wurdeGeradeAbgeschlossen &&
          r.uhrzeitStart != null &&
          r.uhrzeitEnde != null) {
        try {
          final startMin = _hmMinuten(r.uhrzeitStart);
          if (startMin != null) {
            ReinigungLocal? vorherige;
            int? vorherigeEndeMin;
            for (final x in ref.read(reinigungenProvider)) {
              if (x.betriebId.isEmpty || x.betriebId == r.betriebId) continue;
              if (x.datum.year != r.datum.year ||
                  x.datum.month != r.datum.month ||
                  x.datum.day != r.datum.day) {
                continue;
              }
              final endeMin = _hmMinuten(x.uhrzeitEnde);
              if (endeMin == null || endeMin >= startMin) continue;
              if (vorherigeEndeMin == null || endeMin > vorherigeEndeMin) {
                vorherige = x;
                vorherigeEndeMin = endeMin;
              }
            }
            if (vorherige != null) {
              final luecke =
                  fahrtLueckeMinuten(vorherige.uhrzeitEnde, r.uhrzeitStart);
              if (luecke != null) {
                unawaited(FahrzeitRepository.beobachtungNachfuehren(
                  vonBetriebId: vorherige.betriebId,
                  nachBetriebId: r.betriebId,
                  minuten: luecke,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('[Fahrzeit] Nachfuehrung uebersprungen: $e');
        }
      }

      // Buchhaltung korrigieren bei Bearbeitung einer abgeschlossenen Reinigung
      bool buchungKorrigiert = false;
      String? korrekturTypLabel;
      if (_isEdit &&
          !abschliessen &&
          kIsWeb &&
          r.status == 'abgeschlossen' &&
          r.serverId != null &&
          !_istKulanz &&
          !_istHeinekenMonteur) {
        try {
          await ReinigungKorrekturService.cleanupBuchhaltung(r.serverId!);
          final result = await ReinigungKorrekturService.recreateBuchhaltung(
            r,
            _betrieb ??
                await BetriebRepository.getByServerId(r.betriebId) ??
                _betrieb!,
          );
          buchungKorrigiert = result.buchungVerbucht;
          korrekturTypLabel = result.buchungTypLabel;
          debugPrint('[Korrektur] Buchhaltung neu erstellt');
        } catch (e) {
          debugPrint('[Korrektur] Fehler: $e');
        }
      }

      // HeiGenie-Mail an Heineken senden
      if (abschliessen && kIsWeb && _serviceTyp == 'heigenie') {
        try {
          final betrieb =
              _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
          if (betrieb != null) {
            final kontakt = await KontaktRepository.getHeinekenZuweisung(
              'heigenie_service',
            );
            final empfaenger = MailConfig.empfaenger(
              kontakt?.email,
              bereich: 'heigenie',
            );
            debugPrint(
              '[HeiGenie-Mail] Kontakt: ${kontakt?.vorname} ${kontakt?.nachname}, Email: ${kontakt?.email}',
            );
            debugPrint(
              '[HeiGenie-Mail] testModus=${MailConfig.testModus}, heigenieScharf=${MailConfig.heigenieScharf}',
            );
            debugPrint('[HeiGenie-Mail] Empfänger: $empfaenger');
            final datumStr =
                '${r.datum.day.toString().padLeft(2, '0')}.${r.datum.month.toString().padLeft(2, '0')}.${r.datum.year}';
            final betriebLabel = betrieb.ort != null && betrieb.ort!.isNotEmpty
                ? '${betrieb.name} ${betrieb.ort}'
                : betrieb.name;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'HeiGenie-Mail → $empfaenger (Kontakt: ${kontakt?.email ?? "KEIN KONTAKT"})',
                  ),
                  duration: const Duration(seconds: 6),
                ),
              );
            }

            await SupabaseService.client.functions.invoke(
              'send-rechnung-mail',
              body: {
                'to': empfaenger,
                'subject': 'Higenie Service - $betriebLabel - $datumStr',
                'bodyText':
                    'Hallo Beat\n\n'
                    'Beiliegend das Reinigungsprotokoll für den Higenie Service im $betriebLabel vom $datumStr.\n\n'
                    'Gruass Dani',
                'userId': SupabaseService.dataUserId,
                if (r.protokollFotoPfad != null)
                  'protokollFotoPfad': r.protokollFotoPfad,
              },
            );
            debugPrint('[HeiGenie-Mail] Versendet an $empfaenger');
          }
        } catch (e) {
          debugPrint('[HeiGenie-Mail] Fehler: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(
                  'HeiGenie-Mail fehlgeschlagen: $e',
                  style: const TextStyle(color: Colors.white),
                ),
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
      }

      // Kundenrechnung + Buchung erstellen bei Abschluss (nicht bei Kulanz/Heineken)
      bool buchungVerbucht = false;
      String? buchungTypLabel;
      if (abschliessen && kIsWeb && !_istKulanz && !_istHeinekenMonteur) {
        final betrieb =
            _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
        if (betrieb != null) {
          final zahlungsart = resolveZahlungsart(
            r.zahlungsart,
            betrieb.rechnungsstellung,
          );
          // 1. Rechnung + Mail — eigener try/catch; ein Fehler hier darf die
          //    Buchung (Schritt 2) NICHT verhindern.
          try {
            final rechnung = await RechnungService.createFromReinigung(
              r,
              betrieb,
            );

            // Mail versenden wenn rechnung_mail
            if (rechnung != null && zahlungsart == 'rechnung_mail') {
              try {
                // Kunden-Email NUR aus betrieb_rechnungsadressen — betriebe.email
                // ist reine Info.
                String? kundenEmail;
                try {
                  final adrRows = await SupabaseService.client
                      .from('betrieb_rechnungsadressen')
                      .select('email')
                      .eq('betrieb_id', betrieb.serverId!)
                      .limit(1);
                  if (adrRows.isNotEmpty) {
                    final mail = (adrRows.first as Map)['email'];
                    if (mail is String && mail.isNotEmpty) kundenEmail = mail;
                  }
                } catch (e) {
                  debugPrint(
                    '[ServiceMail] Rechnungsadresse-Query fehlgeschlagen: $e',
                  );
                }
                final keineKundenadresse = kundenEmail == null;
                final empfaenger = MailConfig.empfaenger(
                  kundenEmail,
                  bereich: 'reinigung',
                );
                final datumStr =
                    '${r.datum.day}. ${_monatName(r.datum.month)} ${r.datum.year}';
                final betriebLabel =
                    betrieb.ort != null && betrieb.ort!.isNotEmpty
                    ? '${betrieb.name} ${betrieb.ort}'
                    : betrieb.name;
                final betragRounded =
                    (rechnung.betragBrutto * 20).roundToDouble() / 20;
                final betragStr = betragRounded.toStringAsFixed(2);
                final response = await SupabaseService.client.functions.invoke(
                  'send-rechnung-mail',
                  body: {
                    'to': empfaenger,
                    'subject':
                        'Rechnung Service Offenausschankanlage $betriebLabel vom $datumStr',
                    'bodyText':
                        'Guten Tag\n\n'
                        'Im Anhang sende ich Ihnen die Rechnung für die Bierleitungsreinigung im $betriebLabel vom $datumStr, '
                        'die Details entnehmen Sie bitte der Rechnung und dem Lieferschein im Anhang.\n\n'
                        'Ich bitte Sie den offenen Betrag von CHF $betragStr innerhalb von 30 Tagen '
                        'mit dem beiliegenden Einzahlungsschein zu begleichen.\n\n'
                        'Mit freundlichen Grüssen\n\n'
                        'Daniel Projer\n\n'
                        'SBS Projer GmbH\nVia Rezia 8\n7013 Domat/Ems\n076 / 566 58 06',
                    'rechnungId': rechnung.id,
                    'userId': SupabaseService.dataUserId,
                    if (r.protokollFotoPfad != null)
                      'protokollFotoPfad': r.protokollFotoPfad,
                  },
                );
                debugPrint(
                  '[ServiceMail] Response: ${response.status} ${response.data}',
                );
                // Status/versendet_am NUR bei scharfem Versand setzen — im
                // Testmodus ging die Mail an den Test-Empfänger, nicht an den Kunden.
                if (MailConfig.istScharf('reinigung')) {
                  await RechnungRepository.update(rechnung.id, {
                    'zahlungsstatus': 'gesendet',
                    'versendet_am': DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first,
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    keineKundenadresse
                        ? SnackBar(
                            backgroundColor: AppColors.warning,
                            content: Text(
                              'Keine Kundenadresse gepflegt — Rechnung ging an $empfaenger (intern). '
                              'Bitte Rechnungsadresse für ${betrieb.name} ergänzen.',
                              style: const TextStyle(color: Colors.white),
                            ),
                            duration: const Duration(seconds: 8),
                          )
                        : SnackBar(
                            content: Text(
                              'Rechnung per Mail versendet an $empfaenger',
                            ),
                          ),
                  );
                }
              } catch (e) {
                debugPrint('[ServiceMail] Fehler: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text(
                        'MAIL-VERSAND FEHLGESCHLAGEN: $e',
                        style: const TextStyle(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 8),
                    ),
                  );
                }
              }
            }
            // Bei "Per Post": Rechnung per Mail an Daniel selbst (zum Ausdrucken
            // und Versand per Post). Geht immer an dani.proyer@gmail.com.
            // Versanddatum = Abschlusstag (Annahme: Postversand erfolgt zeitnah).
            else if (rechnung != null && zahlungsart == 'rechnung_post') {
              try {
                final datumStr =
                    '${r.datum.day}. ${_monatName(r.datum.month)} ${r.datum.year}';
                final betriebLabel =
                    betrieb.ort != null && betrieb.ort!.isNotEmpty
                    ? '${betrieb.name} ${betrieb.ort}'
                    : betrieb.name;
                await SupabaseService.client.functions.invoke(
                  'send-rechnung-mail',
                  body: {
                    'to': MailConfig
                        .testEmpfaenger, // dani.proyer@gmail.com (intern)
                    'subject':
                        'Post-Rechnung zum Ausdrucken: $betriebLabel vom $datumStr',
                    'bodyText':
                        'Rechnung für die Bierleitungsreinigung im $betriebLabel vom $datumStr '
                        'zum Ausdrucken und Versand per Post (Anhang: Rechnung + Lieferschein).',
                    'rechnungId': rechnung.id,
                    'userId': SupabaseService.dataUserId,
                    if (r.protokollFotoPfad != null)
                      'protokollFotoPfad': r.protokollFotoPfad,
                  },
                );
                // Versand gilt mit dem Abschluss als erfolgt (Postversand zeitnah).
                await RechnungRepository.update(rechnung.id, {
                  'zahlungsstatus': 'gesendet',
                  'versendet_am': DateTime.now()
                      .toIso8601String()
                      .split('T')
                      .first,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rechnung zum Postversand an dich gemailt'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('[Post-Mail] Fehler: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text(
                        'POST-MAIL FEHLGESCHLAGEN: $e',
                        style: const TextStyle(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 8),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            debugPrint('Rechnungs-/Mailerstellung fehlgeschlagen: $e');
            // Fehler NICHT verschlucken: der Nutzer muss sehen, dass Rechnung/
            // Mail nicht erstellt wurden (sonst steht nur "abgeschlossen" da).
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.error,
                  content: Text(
                    'RECHNUNG/MAIL FEHLGESCHLAGEN: $e\n'
                    'Reinigung ist abgeschlossen. Rechnung/Mail über das '
                    'Rechnungs-Menü im Detail nachholen.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 12),
                ),
              );
            }
          }

          // 2. Automatische Buchung — UNABHÄNGIG vom Rechnungs-/Mailversand,
          //    damit eine gescheiterte Rechnung NIE die Buchhaltung verhindert.
          try {
            final buchung = await ReinigungBuchungService.createFromReinigung(
              r,
              betrieb,
            );
            if (buchung != null) {
              buchungVerbucht = true;
              buchungTypLabel = zahlungsart == 'barzahlung'
                  ? 'Barzahlung'
                  : 'Rechnung';
            }
          } catch (e) {
            debugPrint('[Buchung] Fehler: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.error,
                  content: Text(
                    'BUCHUNG FEHLGESCHLAGEN: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 10),
                ),
              );
            }
          }
        } else {
          // Ohne Betrieb entstehen WEDER Rechnung NOCH Buchung — bisher völlig
          // lautlos. Das ist der letzte Zweig hier, der ohne Ausnahme und ohne
          // Spur aussteigt, und damit der Hauptverdächtige für die 38 fehlenden
          // Rechnungen vom 26.06.–13.07.: kein Insert (Sequenz unberührt), kein
          // Fehler, keine Meldung. Ab jetzt sichtbar.
          debugPrint(
            '[Rechnung] BETRIEB NULL — betriebId="${r.betriebId}", '
            '_betrieb=${_betrieb?.serverId}, widget.betriebId=${widget.betriebId}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(
                  'BETRIEB NICHT GELADEN — KEINE RECHNUNG, KEINE BUCHUNG!\n'
                  'Reinigung ist gespeichert. Bitte Daniel melden.\n'
                  'betriebId="${r.betriebId}"',
                  style: const TextStyle(color: Colors.white),
                ),
                duration: const Duration(seconds: 30),
              ),
            );
          }
        }
      }

      // Bergkundenpauschale erstellen (wird Heineken verrechnet, nicht dem Kunden)
      if (abschliessen && kIsWeb && _istBergkunde && !_istHeinekenMonteur) {
        try {
          final reinigungId = r.serverId;
          if (reinigungId != null) {
            final betrag =
                (_preisliste?['bergkunden_zuschlag'] as num?)?.toDouble() ??
                180.0;
            await BergkundenpauschaleRepository.create({
              'betrieb_id': r.betriebId,
              'reinigung_id': reinigungId,
              'datum': r.datum.toIso8601String().split('T').first,
              'betrag': betrag,
            });
            ref.invalidate(bergkundenpauschaleStreamProvider);
            debugPrint(
              '[Bergkundenpauschale] Erstellt: $betrag CHF für ${r.betriebId}',
            );
          }
        } catch (e) {
          debugPrint('[Bergkundenpauschale] Fehler: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              abschliessen
                  ? (buchungVerbucht
                        ? 'Reinigung abgeschlossen – $buchungTypLabel verbucht'
                        : 'Reinigung abgeschlossen')
                  : buchungKorrigiert
                  ? 'Reinigung aktualisiert – Buchhaltung korrigiert ($korrekturTypLabel)'
                  : _isEdit
                  ? 'Reinigung aktualisiert'
                  : 'Reinigung gestartet',
            ),
          ),
        );
        if (kIsWeb) {
          ref.invalidate(reinigungenStreamProvider);
          ref.invalidate(reinigungenByJahrProvider);
          ref.invalidate(reinigungJahreProvider);
          ref.invalidate(anlagenStreamProvider);
          if (abschliessen || buchungKorrigiert) {
            ref.invalidate(rechnungenStreamProvider);
            ref.invalidate(buchungenStreamProvider);
          }
        }
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAbschlussDialog() async {
    // Heineken-Monteur/Kulanz: direkt abschliessen ohne Rechnungsdialog
    if (_istHeinekenMonteur || _istKulanz) {
      _save(abschliessen: true);
      return;
    }

    // Doppeltap-Guard: vor showDialog laufen zwei awaits — währenddessen wäre
    // der Button sonst weiter tappbar → zwei parallele Dialoge → zwei _save →
    // Doppelrechnung + Doppelbuchung. _isLoading bleibt bis nach dem
    // (awaiteten) _save gesetzt; _saves eigenes setState(true) ist dabei
    // idempotent (bereits true), sein finally + unser finally setzen beide
    // zurück — kein Deadlock, da _save keinen eigenen _isLoading-Guard hat.
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _abschlussDialogFlow();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abschlussDialogFlow() async {
    // Betrieb FRISCH laden — der Formular-Cache kann veraltet sein (4 der 38
    // fehlenden Rechnungen entstanden genau so).
    BetriebLocal? betrieb = _betrieb;
    final betriebId = widget.betriebId ?? _existing?.betriebId;
    if (betriebId != null && betriebId.isNotEmpty) {
      try {
        final frisch = await BetriebRepository.getByServerId(betriebId);
        if (frisch != null) betrieb = frisch;
      } catch (e) {
        debugPrint('[Abschluss] Betrieb-Refresh fehlgeschlagen: $e');
      }
    }
    if (!mounted) return;

    // Vorbelegung, Priorität:
    // (1) bereits auf der Reinigung fixierte Zahlungsart (Edit/Retry einer
    //     bestehenden Reinigung — _save hat r.zahlungsart schon gesetzt),
    // (2) letzte im Dialog BESTÄTIGTE User-Wahl (Retry bei neuer Reinigung,
    //     wo _existing noch null ist),
    // (3) frischer Betriebs-Default.
    // _rechnungsstellung allein taugt NICHT als Override: beim Erstöffnen
    // stammt er aus dem evtl. veralteten Formular-Cache — nur nach expliziter
    // Bestätigung (_zahlungsartManuellGewaehlt) darf er den frischen
    // Betriebs-Default übersteuern.
    var selected = resolveZahlungsart(
      _existing?.zahlungsart ??
          (_zahlungsartManuellGewaehlt ? _rechnungsstellung : null),
      betrieb?.rechnungsstellung,
    );
    var alsStandard = false;
    // Standard-Checkbox nur zeigen, wenn die Wahl vom Betriebs-Default
    // abweicht (Regel Daniel 22.07. — übersichtlicher). Beim Zurückwechseln
    // auf den Default wird sie versteckt UND zurückgesetzt, damit kein
    // unsichtbares Häkchen mitläuft.
    final betriebsDefault = resolveZahlungsart(null, betrieb?.rechnungsstellung);

    // Rechnungsadresse-E-Mail (Versand läuft NUR darüber; betriebe.email = Info).
    String? raEmail;
    try {
      final ra = betriebId == null
          ? null
          : await BetriebRechnungsadresseRepository.getByBetrieb(betriebId);
      raEmail = (ra?.email != null && ra!.email!.isNotEmpty) ? ra.email : null;
    } catch (e) {
      debugPrint('[Abschluss] Rechnungsadresse-Load fehlgeschlagen: $e');
    }
    if (!mounted) return;
    final emailCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reinigung abschliessen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zahlungsart für DIESE Reinigung:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Zahlungsart',
                    prefixIcon: Icon(Icons.receipt),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'rechnung_mail',
                      child: Text('Per E-Mail'),
                    ),
                    DropdownMenuItem(
                      value: 'rechnung_post',
                      child: Text('Per Post'),
                    ),
                    DropdownMenuItem(
                      value: 'rechnung_tresen',
                      child: Text('Rechnung Tresen (EZS)'),
                    ),
                    DropdownMenuItem(
                      value: 'barzahlung',
                      child: Text('Barzahlung'),
                    ),
                    DropdownMenuItem(
                      value: 'jahresrechnung',
                      child: Text('Jahresrechnung'),
                    ),
                    DropdownMenuItem(
                      value: 'heineken',
                      child: Text('Via Heineken (monatlich)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        selected = v;
                        if (v == betriebsDefault) alsStandard = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Klartext: WAS löst der Abschluss aus? (Die 38 fehlenden
                // Rechnungen blieben unsichtbar, weil das nirgends stand.)
                Text(
                  zahlungsartKlartext(selected, kundenEmail: raEmail),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected == 'rechnung_mail' && raEmail == null
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
                // Mail ohne Rechnungsadresse-E-Mail: sofort erfassen können.
                if (selected == 'rechnung_mail' && raEmail == null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Rechnungs-E-Mail jetzt erfassen',
                      prefixIcon: Icon(Icons.alternate_email, size: 18),
                      isDense: true,
                    ),
                  ),
                ],
                if (selected != betriebsDefault) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: alsStandard,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Auch als Standard für diesen Betrieb übernehmen',
                      style: TextStyle(fontSize: 13),
                    ),
                    onChanged: (v) =>
                        setDialogState(() => alsStandard = v ?? false),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Abschliessen'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Neu erfasste Rechnungs-E-Mail speichern: Rechnungsadresse anlegen
    // (vorbefüllt aus Betriebsdaten, damit der PDF-Adressblock stimmt) bzw.
    // nur die E-Mail ergänzen.
    final neueEmail = emailCtrl.text.trim();
    if (selected == 'rechnung_mail' &&
        raEmail == null &&
        neueEmail.isNotEmpty &&
        betriebId != null) {
      try {
        var ra = await BetriebRechnungsadresseRepository.getByBetrieb(
          betriebId,
        );
        ra ??= BetriebRechnungsadresseLocal()
          ..betriebId = betriebId
          ..nachname = betrieb?.name ?? ''
          ..strasse = betrieb?.strasse ?? ''
          ..plz = betrieb?.plz ?? ''
          ..ort = betrieb?.ort ?? '';
        ra.email = neueEmail;
        await BetriebRechnungsadresseRepository.save(ra);
      } catch (e) {
        debugPrint('[Abschluss] Rechnungsadresse speichern fehlgeschlagen: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                'Rechnungs-E-Mail konnte nicht gespeichert werden: $e\n'
                'Bitte in der Rechnungsadresse nachtragen.',
                style: const TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    }

    // Betriebs-Default NUR auf expliziten Wunsch aktualisieren (Checkbox) —
    // der frühere STILLE Rückschreib-Effekt hat zu den 38 beigetragen.
    if (alsStandard &&
        betrieb != null &&
        selected != betrieb.rechnungsstellung) {
      betrieb.rechnungsstellung = selected;
      await BetriebRepository.save(betrieb);
      if (kIsWeb && mounted) ref.invalidate(betriebeStreamProvider);
    }

    setState(() {
      _rechnungsstellung = selected;
      _zahlungsartManuellGewaehlt = true; // ab jetzt gilt die User-Wahl (Retry)
    });
    await _save(abschliessen: true);
  }

  String? _emptyToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _uhrzeitStartController.dispose();
    _uhrzeitEndeController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  double _roundTo5Rappen(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  Map<String, double> _calculatePreis() {
    if (_preisliste == null || _serviceTyp == null) return {};
    final p = _preisliste!;

    final grundtarif = switch (_serviceTyp) {
      'reinigung_bier' =>
        (p['grundtarif_reinigung_bier'] as num?)?.toDouble() ?? 0,
      'reinigung_orion' =>
        (p['grundtarif_reinigung_orion'] as num?)?.toDouble() ?? 0,
      'heigenie' => (p['grundtarif_heigenie'] as num?)?.toDouble() ?? 0,
      'reinigung_fremd' =>
        (p['grundtarif_reinigung_fremd'] as num?)?.toDouble() ?? 0,
      'wein' => (p['grundtarif_wein'] as num?)?.toDouble() ?? 0,
      _ => 0.0,
    };

    final hEigen = (p['zusatz_hahn_eigen'] as num?)?.toDouble() ?? 18.0;
    final hOrion = (p['zusatz_hahn_orion'] as num?)?.toDouble() ?? 18.0;
    final hFremd = (p['zusatz_hahn_fremd'] as num?)?.toDouble() ?? 23.0;
    final hWein = (p['zusatz_hahn_wein'] as num?)?.toDouble() ?? 23.0;
    final hStandort =
        (p['zusatz_hahn_anderer_standort'] as num?)?.toDouble() ?? 30.0;

    double zusatz = 0;
    zusatz += _anzahlHaehneEigen * hEigen;
    zusatz += _anzahlHaehneOrion * hOrion;
    zusatz += _anzahlHaehneFremd * hFremd;
    zusatz += _anzahlHaehneWein * hWein;
    zusatz += _anzahlHaehneAndererStandort * hStandort;

    final bergkundenZuschlag = _istBergkunde
        ? ((p['bergkunden_zuschlag'] as num?)?.toDouble() ?? 100.0)
        : 0.0;
    // Bergkunden-Zuschlag NICHT in Netto/Brutto — wird Heineken separat verrechnet
    final netto = grundtarif + zusatz;
    final mwstSatz = (p['mwst_satz'] as num?)?.toDouble() ?? 8.1;
    final brutto = _roundTo5Rappen(netto * (1 + mwstSatz / 100));
    final mwst = brutto - netto;

    return {
      'grundtarif': grundtarif,
      'zusatz': zusatz,
      'bergkundenZuschlag': bergkundenZuschlag,
      'netto': netto,
      'mwstSatz': mwstSatz,
      'mwst': mwst,
      'brutto': brutto,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Reinigung bearbeiten' : 'Neue Reinigung'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Betrieb-Info ===
            if (_betrieb != null) ...[
              _buildBetriebCard(),
              const SizedBox(height: 8),
            ],

            // === Heineken-Monteur Switch ===
            _buildHeinekenMonteurSwitch(),
            const SizedBox(height: 8),

            // === Anlagen-Auswahl ===
            if (!_istHeinekenMonteur) ...[
              if (_anlagenDesBetrieb.isNotEmpty) ...[
                _buildAnlagenAuswahl(),
                const SizedBox(height: 16),
              ] else if (!_anlagenLoaded && _betrieb != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ],

            // === Zeiterfassung ===
            _sectionTitle(context, 'Zeiterfassung'),
            const SizedBox(height: 8),
            // Datum, Start und Ende in einer Zeile
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
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
                // Bei Heineken-Monteur: nur Datum, Start/Ende ausblenden
                if (!_istHeinekenMonteur) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _uhrzeitStartController,
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _uhrzeitEndeController,
                      decoration: const InputDecoration(
                        labelText: 'Ende',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ],
            ),

            // Bei Heineken-Monteur: Rest ausblenden
            if (!_istHeinekenMonteur) ...[
              const SizedBox(height: 24),

              // === Service-Art & Wasserwechsel ===
              _sectionTitle(context, 'Service-Art'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _serviceArt,
                decoration: const InputDecoration(
                  labelText: 'Service-Art',
                  prefixIcon: Icon(Icons.build),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'standardservice',
                    child: Text('Standardservice'),
                  ),
                  DropdownMenuItem(
                    value: 'endreinigung',
                    child: Text('Endreinigung'),
                  ),
                  DropdownMenuItem(
                    value: 'eroeffnungsservice',
                    child: Text('Eröffnungsservice'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _serviceArt = v);
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _wasserKuehlerGewechselt,
                onChanged: (v) =>
                    setState(() => _wasserKuehlerGewechselt = v ?? false),
                title: const Text('Wasser im Kühler gewechselt'),
                secondary: const Icon(Icons.water_drop),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),

              // === Protokoll ===
              _sectionTitle(context, 'Protokoll'),
              const SizedBox(height: 8),
              if (_fotoBytes == null && _existingFotoPfad == null)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _fotoUploading ? null : _takePhoto,
                          icon: const Icon(Icons.document_scanner, size: 24),
                          label: const Text(
                            'Digitalisieren',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _fotoUploading ? null : _pickPhoto,
                          icon: const Icon(Icons.upload_file, size: 24),
                          label: const Text(
                            'Hochladen',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_fotoBytes != null || _existingFotoPfad != null)
                _buildFotoSection(),
              const SizedBox(height: 24),

              // === Beanstandungen / Notizen ===
              _sectionTitle(context, 'Beanstandungen / Notizen'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notizenController,
                decoration: const InputDecoration(
                  labelText: 'Beanstandungen / Notizen',
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                  hintText: 'Auffälligkeiten, Mängel, Kundenhinweise...',
                ),
                maxLines: 4,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // === Kulanz Switch ===
              _buildKulanzSwitch(),
              const SizedBox(height: 16),

              // === Positionen ===
              _sectionTitle(context, 'Positionen'),
              const SizedBox(height: 8),
              _buildPositionen(),
              const SizedBox(height: 16),

              // === Preisliste-Referenz ===
              if (_preisliste != null) _buildPreislisteReferenz(),
              const SizedBox(height: 24),
            ],

            // === Aktionen ===
            if (_isEdit) ...[
              FilledButton(
                onPressed: _isLoading ? null : () => _save(),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Speichern'),
              ),
              if (_status == 'offen') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showAbschlussDialog,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Reinigung abschliessen'),
                ),
              ],
            ] else
              FilledButton.icon(
                onPressed: _isLoading ? null : _showAbschlussDialog,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _istHeinekenMonteur
                      ? 'Heineken-Monteur erfassen'
                      : 'Reinigung abschliessen',
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBetriebCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _betrieb!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (_betrieb!.ort != null)
                  Text(
                    _betrieb!.ort!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
            tooltip: 'Betrieb anzeigen',
            onPressed: () {
              context.push(
                '/betriebe/${_betrieb!.serverId ?? _betrieb!.routeId}',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnlagenAuswahl() {
    final selectedCount = _selectedAnlageIds.length;
    final totalCount = _anlagenDesBetrieb.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.precision_manufacturing,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Anlagen',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '$selectedCount/$totalCount ausgewählt',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...(_anlagenDesBetrieb.map((anlage) {
            final anlageId = anlage.serverId ?? anlage.routeId;
            final isSelected = _selectedAnlageIds.contains(anlageId);
            return Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedAnlageIds.add(anlageId);
                        } else {
                          _selectedAnlageIds.remove(anlageId);
                        }
                      });
                      if (!_isEdit) _recalculateHaehne();
                    },
                    title: Text(
                      anlage.bezeichnung ?? anlage.typAnlage,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: anlage.bezeichnung != null
                        ? Text(
                            anlage.typAnlage,
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Anlage anzeigen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    context.push('/anlagen/$anlageId');
                  },
                ),
              ],
            );
          })),
        ],
      ),
    );
  }

  Widget _buildHeinekenMonteurSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _istHeinekenMonteur
            ? AppColors.info.withAlpha(25)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _istHeinekenMonteur
              ? AppColors.info.withAlpha(100)
              : AppColors.divider,
        ),
      ),
      child: SwitchListTile(
        title: const Text(
          'Heineken-Monteur',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Nur Datum erfassen (kein Preis/Protokoll)',
          style: TextStyle(fontSize: 12),
        ),
        secondary: const Icon(Icons.engineering, color: AppColors.info),
        value: _istHeinekenMonteur,
        contentPadding: EdgeInsets.zero,
        onChanged: (v) => setState(() {
          _istHeinekenMonteur = v;
          if (v) _istKulanz = false;
        }),
      ),
    );
  }

  Widget _buildKulanzSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _istKulanz ? AppColors.warning.withAlpha(25) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _istKulanz
              ? AppColors.warning.withAlpha(100)
              : AppColors.divider,
        ),
      ),
      child: SwitchListTile(
        title: const Text(
          'Kulanz (kostenlos)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Gesamtpreis CHF 0.–',
          style: TextStyle(fontSize: 12),
        ),
        secondary: const Icon(
          Icons.volunteer_activism,
          color: AppColors.warning,
        ),
        value: _istKulanz,
        contentPadding: EdgeInsets.zero,
        onChanged: (v) => setState(() {
          _istKulanz = v;
          if (v) _istHeinekenMonteur = false;
        }),
      ),
    );
  }

  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Foto-Vorschau
        if (_fotoBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _fotoBytes!,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
        ] else if (_existingFotoPfad != null) ...[
          if (ProtokollFotoStorage.isPdf(_existingFotoPfad!))
            // PDF: Platzhalter mit Öffnen-Button
            FutureBuilder<String>(
              future: ProtokollFotoStorage.getSignedUrl(_existingFotoPfad!),
              builder: (context, snapshot) {
                return Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          size: 40,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 8),
                        if (snapshot.hasData)
                          FilledButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(snapshot.data!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('PDF öffnen'),
                          )
                        else
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            // JPG (legacy): Bild direkt anzeigen
            FutureBuilder<String>(
              future: ProtokollFotoStorage.getSignedUrl(_existingFotoPfad!),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      snapshot.data!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Foto konnte nicht geladen werden',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          const SizedBox(height: 8),
        ],

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _fotoUploading ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _fotoBytes != null || _existingFotoPfad != null
                      ? 'Neues Foto'
                      : 'Protokoll fotografieren',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _fotoUploading ? null : _pickPhoto,
              icon: const Icon(Icons.photo_library),
              label: const Text('Galerie'),
            ),
          ],
        ),
        if (_fotoUploading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Foto wird hochgeladen...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _updatePositionAndPreis(VoidCallback update) {
    setState(() {
      update();
    });
  }

  Widget _buildPositionen() {
    final preis = _calculatePreis();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service-Typ
          DropdownButtonFormField<String>(
            initialValue: _serviceTyp,
            decoration: const InputDecoration(
              labelText: 'Service-Typ',
              prefixIcon: Icon(Icons.cleaning_services),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'reinigung_bier',
                child: Text('Reinigung Bier'),
              ),
              DropdownMenuItem(
                value: 'reinigung_orion',
                child: Text('Reinigung Orion'),
              ),
              DropdownMenuItem(value: 'heigenie', child: Text('Heigenie')),
              DropdownMenuItem(
                value: 'reinigung_fremd',
                child: Text('Reinigung Fremd'),
              ),
              DropdownMenuItem(value: 'wein', child: Text('Wein')),
            ],
            onChanged: (v) => _updatePositionAndPreis(() => _serviceTyp = v),
          ),
          const SizedBox(height: 12),

          // Grundtarif (readonly, aus Preisliste)
          if (_preisliste != null && _serviceTyp != null) ...[
            _preisRow(
              'Grundtarif ${_serviceTypLabel(_serviceTyp)} (exkl. MwSt)',
              _istKulanz ? 0 : _getGrundtarif(),
            ),
            const Divider(height: 16),
          ],

          // Hähne-Aufstellung
          _haehneRow(
            'Hähne Eigen',
            _anzahlHaehneEigen,
            _hahnPreis('zusatz_hahn_eigen'),
            (v) => _updatePositionAndPreis(() => _anzahlHaehneEigen = v),
          ),
          _haehneRow(
            'Hähne Orion',
            _anzahlHaehneOrion,
            _hahnPreis('zusatz_hahn_orion'),
            (v) => _updatePositionAndPreis(() => _anzahlHaehneOrion = v),
          ),
          _haehneRow(
            'Hähne Fremd',
            _anzahlHaehneFremd,
            _hahnPreis('zusatz_hahn_fremd'),
            (v) => _updatePositionAndPreis(() => _anzahlHaehneFremd = v),
          ),
          _haehneRow(
            'Hähne Wein',
            _anzahlHaehneWein,
            _hahnPreis('zusatz_hahn_wein'),
            (v) => _updatePositionAndPreis(() => _anzahlHaehneWein = v),
          ),
          _haehneRow(
            'Anderer Standort',
            _anzahlHaehneAndererStandort,
            _hahnPreis('zusatz_hahn_anderer_standort'),
            (v) =>
                _updatePositionAndPreis(() => _anzahlHaehneAndererStandort = v),
          ),

          // Kalkulation
          const Divider(height: 16),
          if (_istKulanz)
            ..._buildKulanzKalkulationRows()
          else
            ..._buildKalkulationRows(preis),

          // QR-Zahlung (Firmenkonto-QR, Betrag vorbefüllt aus Brutto)
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _zeigeQrZahlung,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('QR-Zahlung'),
          ),
        ],
      ),
    );
  }

  Future<void> _zeigeQrZahlung() async {
    final betriebName =
        _betrieb?.name ??
        (widget.betriebId != null
            ? (await BetriebRepository.getByServerId(
                    widget.betriebId!,
                  ))?.name ??
                  ''
            : '');
    final firma = await GeschaeftRepository.get();
    final brutto = _calculatePreis()['brutto'];
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => ReinigungQrDialog(
        firma: firma,
        betriebName: betriebName,
        datum: _datum,
        initialBetrag: brutto,
        referenz: qrReferenzFuerReinigung(
          zahlungsart:
              _existing?.zahlungsart ??
              _rechnungsstellung ??
              _betrieb?.rechnungsstellung,
          datum: _datum,
          betriebNr: _betrieb?.betriebNr,
        ),
      ),
    );
  }

  double _hahnPreis(String key) {
    return (_preisliste?[key] as num?)?.toDouble() ?? 18.0;
  }

  double _getGrundtarif() {
    if (_preisliste == null || _serviceTyp == null) return 0;
    final p = _preisliste!;
    return switch (_serviceTyp) {
      'reinigung_bier' =>
        (p['grundtarif_reinigung_bier'] as num?)?.toDouble() ?? 0,
      'reinigung_orion' =>
        (p['grundtarif_reinigung_orion'] as num?)?.toDouble() ?? 0,
      'heigenie' => (p['grundtarif_heigenie'] as num?)?.toDouble() ?? 0,
      'reinigung_fremd' =>
        (p['grundtarif_reinigung_fremd'] as num?)?.toDouble() ?? 0,
      'wein' => (p['grundtarif_wein'] as num?)?.toDouble() ?? 0,
      _ => 0.0,
    };
  }

  String _serviceTypLabel(String? typ) {
    return switch (typ) {
      'reinigung_bier' => 'Bier',
      'reinigung_orion' => 'Orion',
      'heigenie' => 'Heigenie',
      'reinigung_fremd' => 'Fremd',
      'wein' => 'Wein',
      _ => '',
    };
  }

  List<Widget> _buildKulanzKalkulationRows() {
    return [
      _preisRow('Netto (exkl. MwSt)', 0),
      _preisRow('MwSt (8.1%)', 0),
      const Divider(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total (inkl. 8.1% MwSt)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Text(
            '0.00 CHF',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Kulanz — keine Verrechnung',
          style: TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildKalkulationRows(Map<String, double> preis) {
    if (preis.isEmpty) return [];
    return [
      _preisRow('Netto (exkl. MwSt)', preis['netto']!),
      _preisRow(
        'MwSt (${preis['mwstSatz']!.toStringAsFixed(1)}%)',
        preis['mwst']!,
      ),
      const Divider(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total (inkl. 8.1% MwSt)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(
            '${preis['brutto']!.toStringAsFixed(2)} CHF',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    ];
  }

  Widget _buildPreislisteReferenz() {
    final p = _preisliste!;
    return ExpansionTile(
      title: const Text(
        'Preisliste (exkl. MwSt)',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        _preislisteRow(
          'Grundtarif Eigen',
          (p['grundtarif_reinigung_bier'] as num?)?.toDouble() ?? 0,
        ),
        _preislisteRow(
          'Grundtarif Orion',
          (p['grundtarif_reinigung_orion'] as num?)?.toDouble() ?? 0,
        ),
        _preislisteRow(
          'Service Heigenie (Leihvertrag)',
          (p['grundtarif_heigenie'] as num?)?.toDouble() ?? 0,
        ),
        _preislisteRow(
          'Grundtarif Fremd',
          (p['grundtarif_reinigung_fremd'] as num?)?.toDouble() ?? 0,
        ),
        const Divider(height: 8),
        _preislisteRow(
          'Zusätzl. Hahn Eigen/Orion',
          (p['zusatz_hahn_eigen'] as num?)?.toDouble() ?? 18,
        ),
        _preislisteRow(
          'Zusätzl. Hahn Fremd',
          (p['zusatz_hahn_fremd'] as num?)?.toDouble() ?? 23,
        ),
        _preislisteRow(
          'Zusätzl. Hahn anderer Standort',
          (p['zusatz_hahn_anderer_standort'] as num?)?.toDouble() ?? 30,
        ),
        const Divider(height: 8),
        _preislisteRow(
          'Bergkunden-Zuschlag (→ Heineken)',
          (p['bergkunden_zuschlag'] as num?)?.toDouble() ?? 100,
        ),
      ],
    );
  }

  Widget _preislisteRow(String label, double betrag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            'CHF ${betrag.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _haehneRow(
    String label,
    int anzahl,
    double preisProHahn,
    ValueChanged<int> onChanged,
  ) {
    final total = _istKulanz ? 0.0 : anzahl * preisProHahn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Minus-Button
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: anzahl > 0 ? () => onChanged(anzahl - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$anzahl',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          // Plus-Button
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: () => onChanged(anzahl + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              total > 0 ? '${total.toStringAsFixed(0)} CHF' : '–',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                color: total > 0 ? null : AppColors.textSecondary,
              ),
            ),
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
