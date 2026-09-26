import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_abschluss_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/saison_luecke.dart';
import 'package:sbs_projer_app/core/util/reinigung_korrektur_regel.dart';
import 'package:sbs_projer_app/presentation/widgets/saison_abmachung_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
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
import 'package:sbs_projer_app/core/util/service_schalter.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_korrektur_service.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_qr_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/pause_pruefen_helfer.dart';
import 'package:sbs_projer_app/presentation/widgets/ungespeichert_schutz.dart';
import 'package:sbs_projer_app/presentation/widgets/mahn_hinweis_band.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';

class ReinigungFormScreen extends ConsumerStatefulWidget {
  final String? reinigungId; // null = neu
  final String? anlageId; // für neue Reinigung (erste Anlage)
  final List<String> anlageIds; // für neue Reinigung (gebündelter Besuch)
  final String? betriebId; // für neue Reinigung

  const ReinigungFormScreen({
    super.key,
    this.reinigungId,
    this.anlageId,
    this.anlageIds = const [],
    this.betriebId,
  });

  @override
  ConsumerState<ReinigungFormScreen> createState() =>
      _ReinigungFormScreenState();
}

class _ReinigungFormScreenState extends ConsumerState<ReinigungFormScreen>
    with UngespeichertMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  ReinigungLocal? _existing;

  /// Preisrelevanter Stand beim Laden (R1). Eigene Kopie, weil `_save` das
  /// geladene Objekt direkt bearbeitet (`r = _existing`) — ein Vergleich mit
  /// `_existing` wäre immer «unverändert».
  ReinigungLocal? _ausgangsstand;

  /// Beim Laden bereits abgeschlossen? Festgehalten, weil `_save` den Status
  /// am selben Objekt überschreibt.
  bool _warAbgeschlossen = false;

  /// Sperre der Buchhaltung beim Bearbeiten einer abgeschlossenen Reinigung
  /// (R1). null = noch nicht geprüft oder keine Rechnung.
  KorrekturStand? _korrekturStand;

  // Zeiterfassung
  late DateTime _datum;
  late final _uhrzeitStartController = TextEditingController();
  late final _uhrzeitEndeController = TextEditingController();
  late final _notizenController = TextEditingController();

  // Protokoll-Foto
  Uint8List? _fotoBytes;
  bool _fotoUploading = false;
  String? _existingFotoPfad;

  /// Auf Web vorab erzeugt, damit das Foto sofort nach der Aufnahme in den
  /// richtigen Ordner kann (T1). Beim Bearbeiten = serverId der Reinigung.
  String? _fotoReinigungId;
  String? _hochgeladenerPfad;
  String? _fotoFehler;

  /// Der gerade laufende Sofort-Upload — `_save` wartet darauf, statt einen
  /// zweiten parallel zu starten.
  Future<void>? _laufenderUpload;

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
    if (kIsWeb && !_isEdit) _fotoReinigungId = const Uuid().v4();
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

  /// Anlagen der aktuellen Auswahl — eine Reinigung kann mehrere umfassen.
  List<AnlageLocal> get _gewaehlteAnlagen => _anlagenDesBetrieb
      .where((a) => _selectedAnlageIds.contains(a.serverId ?? a.routeId))
      .toList();

  /// Booster/Eissäule der gewählten Anlagen — müssen vor dem Service aus.
  List<String> get _schalterKomponenten =>
      ServiceSchalter.komponentenAusAnlagen(_gewaehlteAnlagen);

  /// Auffällige Hinweisbox. Bewusst aus Container/Row statt einem Material-
  /// Komfort-Widget gebaut (CanvasKit-Regel in CLAUDE.md).
  /// Band über dem Formular, wenn dem Betrieb die Saisondaten für die
  /// kommende Saison fehlen.
  ///
  /// **Warum genau hier (Daniel, 20.09.2026):** Während der Reinigung steht
  /// der Wirt daneben. Das ist der Moment, um zu fragen «wann macht ihr zu,
  /// wann wieder auf?» und gleich abzumachen, wann Daniel zur Saisonreinigung
  /// kommen darf. Eine Stunde später im Auto ist niemand mehr da, den man
  /// fragen könnte.
  Widget _saisonBand() {
    final b = _betrieb;
    if (b == null || !saisondatenUnvollstaendig(b, DateTime.now())) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _saisonAbmachen,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            border: Border.all(color: AppColors.warning.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_note, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Saisondaten fehlen — jetzt beim Wirt fragen und gleich die '
                  'Saisonreinigung abmachen.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.warning,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saisonAbmachen() async {
    final b = _betrieb;
    if (b == null) return;
    final ok = await zeigeSaisonAbmachungSheet(context, betrieb: b);
    if (ok && mounted) setState(() {});
  }

  /// Einmalige Nachfrage beim Abschliessen, wenn die Saisondaten fehlen.
  ///
  /// Bewusst ohne Zwang: «Später» schliesst die Reinigung trotzdem ab. Ein
  /// Dialog, der sich nicht wegklicken lässt, würde beim nächsten Mal
  /// reflexhaft weggetippt.
  Future<void> _saisonNachfragen() async {
    final b = _betrieb;
    if (b == null || !saisondatenUnvollstaendig(b, DateTime.now())) return;
    final jetzt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisondaten fehlen'),
        content: Text(
          'Bei ${b.name} weiss die App nicht, wann die Saison endet und '
          'wieder beginnt. Solange der Wirt da ist: kurz fragen und gleich '
          'die Saisonreinigung abmachen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Später'),
          ),
          TapKnopf(
            text: 'Jetzt erfassen',
            icon: Icons.event_note,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (jetzt == true && mounted) {
      await zeigeSaisonAbmachungSheet(context, betrieb: b);
    }
  }

  Widget _hinweisBox(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
      _ausgangsstand = preisSchnappschuss(r);
      _warAbgeschlossen = r.status == 'abgeschlossen';
      _datum = r.datum;
      _uhrzeitStartController.text = r.uhrzeitStart ?? '';
      _uhrzeitEndeController.text = r.uhrzeitEnde ?? '';
      _notizenController.text = r.notizen ?? '';
      _status = r.status;
      _existingFotoPfad = r.protokollFotoPfad;
      _fotoReinigungId = r.serverId;
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
    if (kIsWeb && _warAbgeschlossen && r.serverId != null) {
      try {
        final stand = await ReinigungKorrekturService.sperrePruefen(r.serverId!);
        if (mounted) setState(() => _korrekturStand = stand);
      } catch (e) {
        debugPrint('[Korrektur] Sperre nicht pruefbar: $e');
      }
    }
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
            // Kulanz-Vorwahl: Steht der Merker am Betrieb, ist der Schalter
            // von Anfang an gesetzt — man muss aktiv widersprechen statt
            // aktiv daran zu denken. Ein blosser Hinweis reichte nicht: Beim
            // Chleina Pub stand er ab 07.08.2026 am Betrieb und wurde beim
            // Abschluss auch angezeigt, am 27.08. wurde trotzdem regulaer
            // verrechnet. Nur bei NEUEN Reinigungen — eine bestehende traegt
            // ihre eigene Entscheidung.
            if (!_isEdit && betrieb.naechsteReinigungKulanz) {
              _istKulanz = true;
              _istHeinekenMonteur = false;
            }
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
            // Bei neuer Reinigung mit gebündeltem Besuch (Tourenplan/
            // Betriebsseite, anlageIds aus der Route): nur die IDs
            // übernehmen, die tatsächlich zu diesem Betrieb gehören — eine
            // nicht (mehr) passende ID aus der URL soll ignoriert werden,
            // statt eine Geister-Auswahl zu erzeugen.
            if (!_isEdit &&
                _selectedAnlageIds.isEmpty &&
                widget.anlageIds.isNotEmpty) {
              // Beide Kennungen zulassen: Der Tourenplan schreibt `routeId`
              // in seine Besuchs-Blöcke, gespeichert und ausgewählt wird
              // aber `serverId ?? routeId`. Im Web sind beide identisch
              // (`routeId => serverId!`), nativ ist `routeId` die Isar-Id —
              // dort liefe ein Abgleich nur gegen `serverId` ins Leere, und
              // der Besuch käme ohne Vorauswahl an.
              final gueltigeIds = {
                for (final a in anlagen) ...[
                  if (a.serverId != null) a.serverId!,
                  a.routeId,
                ],
              };
              _selectedAnlageIds = widget.anlageIds
                  .where(gueltigeIds.contains)
                  .map((id) {
                    final a = anlagen.firstWhere(
                      (x) => x.serverId == id || x.routeId == id,
                    );
                    return a.serverId ?? a.routeId;
                  })
                  .toSet();
            }
            // Bei neuer Reinigung ohne (gültige) Vorauswahl: alle Anlagen
            // vorausgewählt
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
    markiereGeaendert();
    setState(() {
      _fotoBytes = bytes;
      _existingFotoPfad = null;
      _hochgeladenerPfad = null;
      _fotoFehler = null;
    });
    if (kIsWeb) _laufenderUpload = _fotoHochladen();
  }

  /// Lädt das Foto sofort hoch (Web). Ein Fehler ist sichtbar (rotes Band
  /// mit «Erneut versuchen») und wird beim Speichern noch einmal probiert.
  Future<void> _fotoHochladen() async {
    final bytes = _fotoBytes;
    final id = _fotoReinigungId;
    if (bytes == null || id == null || _istHeinekenMonteur) return;
    setState(() {
      _fotoUploading = true;
      _fotoFehler = null;
    });
    try {
      final pfad = await ProtokollFotoStorage.uploadFoto(id, bytes);
      // Nur übernehmen, wenn inzwischen kein neues Foto aufgenommen wurde —
      // sonst zeigte der Pfad auf das alte Bild.
      if (mounted && identical(bytes, _fotoBytes)) {
        setState(() => _hochgeladenerPfad = pfad);
      }
    } catch (e) {
      debugPrint('[Foto] Upload fehlgeschlagen: $e');
      if (mounted && identical(bytes, _fotoBytes)) {
        setState(() => _fotoFehler = kurzeFehlermeldung(e));
      }
    } finally {
      if (mounted && identical(bytes, _fotoBytes)) {
        setState(() => _fotoUploading = false);
      }
    }
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
        // Bleibt leer, wenn der Betrieb gar keine Anlage hat — der Mapper
        // schreibt dann null statt "" (sonst uuid-Fehler, 11.08.2026).
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

      // 1) Mengen und Typ übernehmen (Heineken-Monteur: keine Positionen).
      if (_istHeinekenMonteur) {
        r.serviceTyp = null;
        r.istBergkunde = false;
        r.anzahlHaehneEigen = 0;
        r.anzahlHaehneOrion = 0;
        r.anzahlHaehneFremd = 0;
        r.anzahlHaehneWein = 0;
        r.anzahlHaehneAndererStandort = 0;
      } else {
        r.serviceTyp = _serviceTyp;
        r.istBergkunde = _istBergkunde;
        r.anzahlHaehneEigen = _anzahlHaehneEigen;
        r.anzahlHaehneOrion = _anzahlHaehneOrion;
        r.anzahlHaehneFremd = _anzahlHaehneFremd;
        r.anzahlHaehneWein = _anzahlHaehneWein;
        r.anzahlHaehneAndererStandort = _anzahlHaehneAndererStandort;
      }

      // 2) R1: Hat sich an einer abgeschlossenen Reinigung etwas
      // Preisrelevantes geändert? Verglichen wird mit dem Schnappschuss beim
      // Laden, NICHT mit `_existing` (dasselbe Objekt wie `r`) — und zwar
      // BEVOR die Preise neu gerechnet werden: Die preis*-Felder in `r` sind
      // hier noch die gespeicherten, verglichen werden effektiv Mengen, Typ,
      // Bergkunde, Kulanz, Datum, Zahlungsart und Anlagen. Sonst würde bei
      // Altdaten oder nach einer Preislisten-Änderung jede Notiz-Korrektur
      // «preisrelevant» und löste eine Rechnungskorrektur aus.
      final mengenGeaendert = _warAbgeschlossen &&
          _ausgangsstand != null &&
          preisrelevantGeaendert(_ausgangsstand!, r);
      // Nichts Preisrelevantes geändert → gespeicherte Preise behalten.
      final preiseBehalten =
          _isEdit && _warAbgeschlossen && !abschliessen && !mengenGeaendert;

      // 3) Preise
      if (preiseBehalten) {
        // gespeicherte Preise bleiben unverändert
      } else if (_istHeinekenMonteur) {
        // Heineken-Monteur: nur Datum, keine Preise/Checkliste
        r.preisGrundtarif = null;
        r.preisZusatzHaehne = null;
        r.bergkundenZuschlag = null;
        r.preisNetto = null;
        r.mwstSatz = null;
        r.preisMwst = null;
        r.preisBrutto = null;
      } else if (_istKulanz) {
        // Kulanz: Positionen normal, aber alle Preise 0
        r.preisGrundtarif = 0;
        r.preisZusatzHaehne = 0;
        r.bergkundenZuschlag = 0;
        r.preisNetto = 0;
        r.mwstSatz = 8.1;
        r.preisMwst = 0;
        r.preisBrutto = 0;
      } else {
        // Normal: Preis-Kalkulation
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

      // R1: Buchhaltung nur anfassen, wenn sich etwas Preisrelevantes
      // geändert hat, und nur ohne Sperre.
      final korrekturNoetig = _isEdit &&
          !abschliessen &&
          kIsWeb &&
          r.serverId != null &&
          mengenGeaendert;
      if (korrekturNoetig) {
        final stand = await ReinigungKorrekturService.sperrePruefen(r.serverId!);
        if (stand.sperre != KorrekturSperre.keine) {
          // `r` trägt schon neu gerechnete Preise, ist aber nicht gespeichert.
          // Frisch nachladen: Setzt der Nutzer die Mengen zurück, gilt beim
          // nächsten Speichern «Preise behalten» — und das müssen die
          // GESPEICHERTEN sein, nicht die eben gerechneten.
          final frisch = await ReinigungRepository.getById(widget.reinigungId!);
          if (frisch != null) _existing = frisch;
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Änderung nicht möglich'),
                content: Text(stand.text),
                actions: [
                  TapKnopf(text: 'Verstanden', onTap: () => Navigator.pop(ctx)),
                ],
              ),
            );
          }
          return; // nichts gespeichert — finally setzt _isLoading zurück
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

      // Web: dieselbe ID wie der Foto-Ordner, in den das Foto schon sofort
      // nach der Aufnahme hochgeladen wurde (T1).
      if (kIsWeb && !_isEdit && r.serverId == null) {
        r.serverId = _fotoReinigungId ??= const Uuid().v4();
      }

      // Protokollfoto — scheitert der Upload, wird NICHT blockiert (Daniel
      // steht beim Kunden), aber laut gemeldet; die Aufgabe «Reinigung ohne
      // Protokollfoto» erinnert danach daran.
      if (_fotoBytes != null && !_istHeinekenMonteur) {
        String? neuerPfad;
        if (kIsWeb) {
          await _laufenderUpload;
          if (_hochgeladenerPfad == null) await _fotoHochladen(); // 2. Versuch
          neuerPfad = _hochgeladenerPfad;
        } else {
          setState(() => _fotoUploading = true);
          try {
            // Nativ: zuerst speichern, um eine Isar-ID zu haben
            if (!_isEdit) await ReinigungRepository.save(r);
            neuerPfad = await ProtokollFotoStorage.uploadFoto(
              r.serverId ?? r.routeId,
              _fotoBytes!,
            );
          } catch (e) {
            debugPrint('[Foto] Upload fehlgeschlagen (nativ): $e');
            _fotoFehler = kurzeFehlermeldung(e);
          } finally {
            if (mounted) setState(() => _fotoUploading = false);
          }
        }
        // Gescheitert: ein bisheriges Protokoll (Bearbeiten) bleibt stehen.
        if (neuerPfad != null) r.protokollFotoPfad = neuerPfad;
        if (neuerPfad == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                'PROTOKOLLFOTO NICHT HOCHGELADEN '
                '(${_fotoFehler ?? 'unbekannt'}).\n'
                '${r.protokollFotoPfad != null ? 'Das bisherige Protokoll bleibt' : 'Reinigung wird ohne Protokoll gespeichert'}'
                ' — über «Bearbeiten» nachreichen.',
                style: const TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 12),
            ),
          );
        }
      } else if (_existingFotoPfad != null && !_istHeinekenMonteur) {
        r.protokollFotoPfad = _existingFotoPfad;
      }

      await ReinigungRepository.save(r);

      // Buchhaltung korrigieren bei Bearbeitung einer abgeschlossenen Reinigung
      // (R1: nur bei preisrelevanter Änderung, Sperre oben schon geprüft).
      // Kein Kulanz-/Monteur-Guard mehr: ein Wechsel auf Kulanz ist
      // preisrelevant — `korrigieren` storniert die alte Buchung, und
      // `createFromReinigung` legt bei Kulanz bewusst nichts Neues an.
      bool buchungKorrigiert = false;
      String? korrekturTypLabel;
      if (korrekturNoetig) {
        try {
          final betrieb =
              _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
          if (betrieb == null) throw StateError('Betrieb nicht geladen');
          final erg = await ReinigungKorrekturService.korrigieren(r, betrieb);
          buchungKorrigiert = erg.buchungVerbucht;
          korrekturTypLabel = erg.buchungTypLabel;
        } catch (e) {
          debugPrint('[Korrektur] Fehler: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(
                  'Reinigung gespeichert, aber Rechnung/Buchung NICHT korrigiert: '
                  '${korrekturMeldung(e)}'
                  '\nBitte im Rechnungsbereich prüfen.',
                  style: const TextStyle(color: Colors.white),
                ),
                duration: const Duration(seconds: 12),
              ),
            );
          }
        }
      }

      // Die Abschlusskette (Rechnung → Versand → Buchung → Nachholen →
      // Bergkundenpauschale → Kulanz-Merker) lebt EINMAL im
      // ReinigungAbschlussService — das Formular zeigt nur die Meldungen.
      // Bis v0.139.0 stand sie hier ein zweites Mal (Analyse 25.09.2026 §3).
      AbschlussErgebnis? abschluss;
      if (abschliessen && kIsWeb) {
        final betrieb =
            _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
        if (betrieb == null) {
          // Ohne Betrieb entstehen WEDER Rechnung NOCH Buchung — bis Juli
          // völlig lautlos und damit Hauptverdächtiger für die 38 fehlenden
          // Rechnungen vom 26.06.–13.07. Ab jetzt sichtbar.
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
        } else {
          abschluss = await ReinigungAbschlussService.abschliessen(r, betrieb);
          if (abschluss.nachgeholt > 0) {
            ref.invalidate(reinigungenOhneRechnungProvider);
          }
          if (r.istBergkunde) ref.invalidate(bergkundenpauschaleStreamProvider);
          if (mounted) _zeigeMeldungen(abschluss.meldungen);
        }
      }

      // T5 (Analyse 25.09.2026): Fahrzeit, Wegpunkt und vor allem die
      // Pausen-Prüfung laufen NACH der Abschlusskette. Vorher stand das
      // Pausen-Sheet davor und hielt Rechnung und Buchung an, bis es
      // beantwortet war — wer das Handy dann wegsteckte, verlor die Kette.
      //
      // Fahrzeit-Nachfuehrung (Spec 2026-07-29 §3.1, Task 4): NUR beim
      // Uebergang zu 'abgeschlossen' (nicht bei jedem Save), sonst wuerde
      // jede spaetere Notiz-Korrektur einer bereits abgeschlossenen Reinigung
      // denselben Uebergang erneut zaehlen — `anzahl` waechst kuenstlich und
      // verwaessert den gleitenden Mittelwert (Review-Befund 29.07.2026).
      // Erkennung: abschliessen==true UND der Status VOR diesem Save war noch
      // nicht 'abgeschlossen'. NICHT über _existing: das ist dasselbe Objekt
      // wie r, dessen Status oben schon gesetzt wurde — der Vergleich war
      // beim Bearbeiten deshalb immer false (Review af581d42).
      // _warAbgeschlossen hält den Stand beim Laden fest (neu: false).
      final wurdeGeradeAbgeschlossen = abschliessen && !_warAbgeschlossen;
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
              final luecke = fahrtLueckeMinuten(
                vorherige.uhrzeitEnde,
                r.uhrzeitStart,
              );
              if (luecke != null) {
                // Guard (Daniel 30.07.2026): Lag zwischen den beiden
                // Reinigungen eine Stoerung/Montage, ist die Luecke keine
                // reine Fahrzeit — dann nicht lernen. Die Wegpunkte liefern
                // die Ereigniszeiten dafuer.
                final endeVorher = vorherige.uhrzeitEnde;
                final von = DateTime(
                  r.datum.year,
                  r.datum.month,
                  r.datum.day,
                  _hmMinuten(endeVorher)! ~/ 60,
                  _hmMinuten(endeVorher)! % 60,
                );
                final bis = DateTime(
                  r.datum.year,
                  r.datum.month,
                  r.datum.day,
                  startMin ~/ 60,
                  startMin % 60,
                );
                final vonId = vorherige.betriebId;
                unawaited(() async {
                  final belegt =
                      await WegpunktRepository.stoerungOderMontageZwischen(
                        von,
                        bis,
                      );
                  if (belegt) {
                    debugPrint(
                      '[Fahrzeit] Uebergang nicht gelernt — '
                      'Stoerung/Montage dazwischen',
                    );
                    return;
                  }
                  await FahrzeitRepository.beobachtungNachfuehren(
                    vonBetriebId: vonId,
                    nachBetriebId: r.betriebId,
                    minuten: luecke,
                  );
                }());
              }
            }
          }
        } catch (e) {
          debugPrint('[Fahrzeit] Nachfuehrung uebersprungen: $e');
        }
        // Wegpunkt stempeln (Zeit + GPS + Betrieb) — Datenstrom fuer die
        // spaetere Routen-Optimierung (Daniel 30.07.2026). Fire-and-forget.
        unawaited(
          WegpunktRepository.stempeln(
            quelle: 'reinigung',
            betriebId: r.betriebId.isEmpty ? null : r.betriebId,
            referenzId: r.serverId,
          ),
        );
        // Vergessene Pause abfangen (Daniel 31.07.2026): laeuft noch eine
        // Pause, jetzt anhand der aktuellen Position pruefen — NIE
        // blockierend, eigener try/catch (der Abschluss ist das Wichtige).
        if (mounted) {
          try {
            await pausePruefenNachEreignis(context, ref);
          } catch (e) {
            debugPrint('[Pause-Pruefung] uebersprungen, Fehler: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              abschliessen
                  ? abschlussSnackbarText(
                      abschluss ??
                          const AbschlussErgebnis(
                            rechnungErstellt: false,
                            buchungVerbucht: false,
                            buchungTypLabel: null,
                            nachgeholt: 0,
                            meldungen: [],
                          ),
                    )
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
          // korrekturNoetig: auch ohne neue Buchung (Wechsel auf Kulanz) wurde
          // storniert und die Rechnung entfernt.
          if (abschliessen || buchungKorrigiert || korrekturNoetig) {
            ref.invalidate(rechnungenStreamProvider);
            ref.invalidate(buchungenStreamProvider);
          }
        }
        // Gespeichert — der Schutz darf beim Verlassen nicht mehr fragen.
        geaendertZuruecksetzen();

        // Letzte Gelegenheit: Fehlen die Saisondaten, EINMAL nachfragen,
        // solange der Wirt noch greifbar ist (Daniel, 20.09.2026). Nur beim
        // Abschluss — beim blossen Start der Arbeit waere es zu früh.
        if (abschliessen) await _saisonNachfragen();
        if (!mounted) return;
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

  /// Meldungen der Abschlusskette als Snackbars (Stufe → Farbe/Dauer).
  void _zeigeMeldungen(List<AbschlussMeldung> meldungen) {
    for (final m in meldungen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: switch (m.stufe) {
            AbschlussStufe.info => null,
            AbschlussStufe.warnung => AppColors.warning,
            AbschlussStufe.fehler => AppColors.error,
          },
          content: Text(
            m.text,
            style: m.stufe == AbschlussStufe.info
                ? null
                : const TextStyle(color: Colors.white),
          ),
          duration: m.dauer,
        ),
      );
    }
  }

  Future<void> _showAbschlussDialog() async {
    // Heineken-Monteur/Kulanz: direkt abschliessen ohne Rechnungsdialog.
    // Guard gegen Doppeltap: ohne ihn liefen zwei _save parallel.
    if (_istHeinekenMonteur || _istKulanz) {
      if (_isLoading) return;
      await _save(abschliessen: true);
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
    final betriebsDefault = resolveZahlungsart(
      null,
      betrieb?.rechnungsstellung,
    );

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
                // Service-Hinweis des Betriebs (z.B. «Nächste Reinigung GRATIS
                // — Kulanz») — prominent, damit er beim Abschluss nicht
                // untergeht (Wunsch Daniel 07.08.2026, Fall Chleina Pub).
                if ((betrieb?.serviceHinweis ?? '').trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withAlpha(120),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.campaign,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            betrieb!.serviceHinweis!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Gegenstück zum Hinweis beim Beginn: Was vor dem Service
                // ausgeschaltet wurde, muss jetzt wieder an.
                if (ServiceSchalter.hinweisEnde(_schalterKomponenten)
                    case final hinweis?) ...[
                  _hinweisBox(hinweis, Icons.power_settings_new),
                  const SizedBox(height: 12),
                ],
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
          ..objekt = betrieb?.name ?? ''
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
                'Rechnungs-E-Mail konnte nicht gespeichert werden '
                '(${kurzeFehlermeldung(e)}).\n'
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

    // Die Ferienfrage an dieser Stelle wurde am 05.08.2026 wieder entfernt
    // (Daniel: «stört im Moment mehr, als es nützt — ein Klick mehr bei der
    // Reinigung»). Betriebsferien laufen über das Betriebs-Formular und den
    // täglichen Google/Website-Abgleich mit Prüfliste.

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

    return UngespeichertSchutz(
      geaendert: geaendert,
      was: 'Die Reinigung',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Reinigung bearbeiten' : 'Neue Reinigung'),
        ),
        body: Form(
          key: _formKey,
          // Deckt alle FormFields ab; Schalter und Auswahl melden sich selbst.
          onChanged: markiereGeaendert,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === Betrieb-Info ===
              if (_betrieb != null) ...[
                _buildBetriebCard(),
                const SizedBox(height: 8),
              ],

              // Saisondaten fehlen — jetzt ist der Wirt greifbar.
              _saisonBand(),

              // Gemahnte Rechnungen — vor Ort bar einkassieren (Mahnwesen Teil 3).
              MahnHinweisBand(betriebId: _betrieb?.serverId),

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

              // Booster/Eissäule vor dem Service ausschalten — sonst friert
              // Wasser oder Lauge in der Leitung ein (Daniel, 01.09.2026).
              // Steht bewusst direkt über der Zeiterfassung: Wer hier die
              // Startzeit einträgt, fängt gleich an.
              if (ServiceSchalter.hinweisBeginn(_schalterKomponenten)
                  case final hinweis?) ...[
                _hinweisBox(hinweis, Icons.power_settings_new),
                const SizedBox(height: 16),
              ],

              // R1: Rechnung bezahlt/gemahnt/versendet/altes Jahr — Preis und
              // Positionen gesperrt; Notiz, Foto, Zeiten gehen weiter.
              if (_korrekturStand != null &&
                  _korrekturStand!.sperre != KorrekturSperre.keine) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_korrekturStand!.text)),
                    ],
                  ),
                ),
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
                          markiereGeaendert();
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
                  onChanged: (v) {
                    markiereGeaendert();
                    setState(() => _wasserKuehlerGewechselt = v ?? false);
                  },
                  title: const Text('Wasser im Kühler gewechselt'),
                  secondary: const Icon(Icons.water_drop),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),

                // === Protokoll ===
                _sectionTitle(context, 'Protokoll'),
                const SizedBox(height: 8),
                if (_fotoFehler != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.error),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Foto nicht hochgeladen: $_fotoFehler',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TapKnopf(
                          text: 'Erneut versuchen',
                          laeuft: _fotoUploading,
                          onTap: _fotoUploading
                              ? null
                              : () => _laufenderUpload = _fotoHochladen(),
                        ),
                      ],
                    ),
                  ),
                if (_fotoUploading && _fotoFehler == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(),
                  ),
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
                      markiereGeaendert();
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
        onChanged: (v) {
          markiereGeaendert();
          setState(() {
            _istHeinekenMonteur = v;
            if (v) _istKulanz = false;
          });
        },
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
        onChanged: (v) {
          markiereGeaendert();
          setState(() {
            _istKulanz = v;
            if (v) _istHeinekenMonteur = false;
          });
        },
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
          if (_hochgeladenerPfad != null) ...[
            const Row(
              children: [
                Icon(Icons.cloud_done, size: 18, color: AppColors.success),
                SizedBox(width: 6),
                Text(
                  'Hochgeladen ✓',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
    // Deckt die +/- Knöpfe der Hähne mit ab — die sind kein FormField.
    markiereGeaendert();
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
            items: [
              const DropdownMenuItem(
                value: 'reinigung_bier',
                child: Text('Reinigung Bier'),
              ),
              const DropdownMenuItem(
                value: 'reinigung_orion',
                child: Text('Reinigung Orion'),
              ),
              // Heigenie ist nicht mehr wählbar (0 Nutzungen; HeiGenie-
              // Betriebe sind ist_mein_kunde = false, die HeiGenie-Mail ist
              // mit der eigenen Abschlusskette entfallen). Der Eintrag bleibt
              // NUR für Altdaten/erkannte Heigenie-Anlagen stehen — ein
              // Dropdown-Wert ohne passenden Eintrag bricht das Formular ab.
              if (_serviceTyp == 'heigenie')
                const DropdownMenuItem(
                  value: 'heigenie',
                  child: Text('Heigenie (alt)'),
                ),
              const DropdownMenuItem(
                value: 'reinigung_fremd',
                child: Text('Reinigung Fremd'),
              ),
              const DropdownMenuItem(value: 'wein', child: Text('Wein')),
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
