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
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
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
            (jsonDecode(r.anlageIdsJson!) as List).map((e) => e.toString()));
      } else if (r.anlageId != null) {
        _selectedAnlageIds = {r.anlageId!};
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
        print('[Reinigung] Betrieb laden fehlgeschlagen: $e');
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
        print('[Reinigung] Anlagen laden fehlgeschlagen: $e');
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
              if (_anzahlHaehneEigen == 0) _anzahlHaehneEigen = letzte.anzahlHaehneEigen;
              if (_anzahlHaehneOrion == 0) _anzahlHaehneOrion = letzte.anzahlHaehneOrion;
              if (_anzahlHaehneFremd == 0) _anzahlHaehneFremd = letzte.anzahlHaehneFremd;
              if (_anzahlHaehneWein == 0) _anzahlHaehneWein = letzte.anzahlHaehneWein;
              if (_anzahlHaehneAndererStandort == 0) {
                _anzahlHaehneAndererStandort = letzte.anzahlHaehneAndererStandort;
              }
            });
          }
        } catch (_) {}
      }
    }

    // ServiceTyp ableiten (aus erster ausgewählter Anlage)
    if (_serviceTyp == null && _selectedAnlageIds.isNotEmpty) {
      final firstAnlage = _anlagenDesBetrieb.where(
          (a) => _selectedAnlageIds.contains(a.serverId ?? a.routeId)).firstOrNull;
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
      if (!_isEdit && _selectedAnlageIds.isNotEmpty && _letzteReinigung == null) {
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
      // Multi-Anlagen: anlageIds setzen, anlageId = erste (Backward-Compat)
      if (_selectedAnlageIds.isNotEmpty) {
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
          final pfad =
              await ProtokollFotoStorage.uploadFoto(reinigungId, _fotoBytes!);
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

      // HeiGenie-Mail an Heineken senden
      if (abschliessen && kIsWeb && _serviceArt == 'heigenie') {
        try {
          final betrieb = _betrieb ??
              await BetriebRepository.getByServerId(r.betriebId);
          if (betrieb != null) {
            final empfaenger = MailConfig.empfaenger(null, bereich: 'heigenie');
            final datumStr =
                '${r.datum.day.toString().padLeft(2, '0')}.${r.datum.month.toString().padLeft(2, '0')}.${r.datum.year}';
            final betriebLabel = betrieb.ort != null && betrieb.ort!.isNotEmpty
                ? '${betrieb.name} ${betrieb.ort}'
                : betrieb.name;

            await SupabaseService.client.functions.invoke(
              'send-rechnung-mail',
              body: {
                'to': empfaenger,
                'subject': 'Higenie Service - $betriebLabel - $datumStr',
                'bodyText': 'Hallo Beat\n\n'
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
                content: Text('HeiGenie-Mail fehlgeschlagen: $e',
                    style: const TextStyle(color: Colors.white)),
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
        try {
          final betrieb = _betrieb ??
              await BetriebRepository.getByServerId(r.betriebId);
          if (betrieb != null) {
            final rechnung = await RechnungService.createFromReinigung(r, betrieb);

            // Mail versenden wenn rechnung_mail
            if (rechnung != null && betrieb.rechnungsstellung == 'rechnung_mail') {
              try {
                final empfaenger = MailConfig.empfaenger(null, bereich: 'reinigung');
                final response = await SupabaseService.client.functions.invoke(
                  'send-rechnung-mail',
                  body: {
                    'to': empfaenger,
                    'subject': 'Rechnung ${rechnung.rechnungsnummer} – SBS Projer GmbH',
                    'bodyText': 'Guten Tag\n\n'
                        'Im Anhang finden Sie die Rechnung für den Service '
                        'vom ${r.datum.day.toString().padLeft(2, '0')}.${r.datum.month.toString().padLeft(2, '0')}.${r.datum.year}.\n\n'
                        'Freundliche Grüsse\nDaniel Proyer\nSBS Projer GmbH',
                    'rechnungId': rechnung.id,
                    'userId': SupabaseService.dataUserId,
                    if (r.protokollFotoPfad != null)
                      'protokollFotoPfad': r.protokollFotoPfad,
                  },
                );
                debugPrint('[ServiceMail] Response: ${response.status} ${response.data}');
                await RechnungRepository.update(rechnung.id, {
                  'zahlungsstatus': 'versendet',
                  'versendet_am': DateTime.now().toIso8601String().split('T').first,
                });
              } catch (e) {
                debugPrint('[ServiceMail] Fehler: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('MAIL-VERSAND FEHLGESCHLAGEN: $e',
                          style: const TextStyle(color: Colors.white)),
                      duration: const Duration(seconds: 8),
                    ),
                  );
                }
              }
            }

            // Automatische Buchung (Barzahlung oder Rechnung)
            final buchung = await ReinigungBuchungService.createFromReinigung(r, betrieb);
            if (buchung != null) {
              buchungVerbucht = true;
              buchungTypLabel = betrieb.rechnungsstellung == 'barzahlung'
                  ? 'Barzahlung'
                  : 'Rechnung';
            }
          }
        } catch (e) {
          debugPrint('Rechnungs-/Buchungserstellung fehlgeschlagen: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(abschliessen
                ? (buchungVerbucht
                    ? 'Reinigung abgeschlossen – $buchungTypLabel verbucht'
                    : 'Reinigung abgeschlossen')
                : _isEdit
                    ? 'Reinigung aktualisiert'
                    : 'Reinigung gestartet'),
          ),
        );
        if (kIsWeb) {
          ref.invalidate(reinigungenStreamProvider);
          if (abschliessen) {
            ref.invalidate(rechnungenStreamProvider);
            ref.invalidate(buchungenStreamProvider);
          }
        }
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

  Future<void> _showAbschlussDialog() async {
    // Heineken-Monteur: direkt abschliessen ohne Rechnungsdialog
    if (_istHeinekenMonteur || _istKulanz) {
      _save(abschliessen: true);
      return;
    }

    var selectedRechnungsstellung = _rechnungsstellung ?? 'rechnung_tresen';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reinigung abschliessen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rechnungsart für diesen Service:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRechnungsstellung,
                decoration: const InputDecoration(
                  labelText: 'Rechnungsstellung',
                  prefixIcon: Icon(Icons.receipt),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'rechnung_mail', child: Text('Per E-Mail')),
                  DropdownMenuItem(
                      value: 'rechnung_post', child: Text('Per Post')),
                  DropdownMenuItem(
                      value: 'rechnung_tresen',
                      child: Text('Rechnung Tresen')),
                  DropdownMenuItem(
                      value: 'barzahlung', child: Text('Barzahlung')),
                  DropdownMenuItem(
                      value: 'jahresrechnung',
                      child: Text('Jahresrechnung')),
                  DropdownMenuItem(
                      value: 'heineken', child: Text('Via Heineken')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedRechnungsstellung = v);
                  }
                },
              ),
            ],
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

    if (confirmed == true) {
      // Rechnungsstellung am Betrieb aktualisieren wenn geändert
      if (_betrieb != null &&
          selectedRechnungsstellung != _betrieb!.rechnungsstellung) {
        _betrieb!.rechnungsstellung = selectedRechnungsstellung;
        await BetriebRepository.save(_betrieb!);
        if (kIsWeb && mounted) ref.invalidate(betriebeStreamProvider);
      }
      setState(() => _rechnungsstellung = selectedRechnungsstellung);
      _save(abschliessen: true);
    }
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
    final hStandort = (p['zusatz_hahn_anderer_standort'] as num?)?.toDouble() ?? 30.0;

    double zusatz = 0;
    zusatz += _anzahlHaehneEigen * hEigen;
    zusatz += _anzahlHaehneOrion * hOrion;
    zusatz += _anzahlHaehneFremd * hFremd;
    zusatz += _anzahlHaehneWein * hWein;
    zusatz += _anzahlHaehneAndererStandort * hStandort;

    final bergkundenZuschlag = _istBergkunde
        ? ((p['bergkunden_zuschlag'] as num?)?.toDouble() ?? 100.0)
        : 0.0;
    final netto = grundtarif + zusatz + bergkundenZuschlag;
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
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
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
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ],
            ],

            // === Zeiterfassung ===
            _sectionTitle(context, 'Zeiterfassung'),
            const SizedBox(height: 8),
            InkWell(
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

            // Bei Heineken-Monteur: nur Datum, Rest ausblenden
            if (!_istHeinekenMonteur) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _uhrzeitStartController,
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        prefixIcon: Icon(Icons.play_arrow),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _uhrzeitEndeController,
                      decoration: const InputDecoration(
                        labelText: 'Ende',
                        prefixIcon: Icon(Icons.stop),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === Service-Art & Wasserwechsel ===
              _sectionTitle(context, 'Service-Art'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _serviceArt,
                decoration: const InputDecoration(
                  labelText: 'Service-Art',
                  prefixIcon: Icon(Icons.build),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'standardservice', child: Text('Standardservice')),
                  DropdownMenuItem(
                      value: 'endreinigung', child: Text('Endreinigung')),
                  DropdownMenuItem(
                      value: 'eroeffnungsservice',
                      child: Text('Eröffnungsservice')),
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
                          label: const Text('Digitalisieren',
                              style: TextStyle(fontSize: 15)),
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
                          label: const Text('Hochladen',
                              style: TextStyle(fontSize: 15)),
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
                label: Text(_istHeinekenMonteur
                    ? 'Heineken-Monteur erfassen'
                    : 'Reinigung abschliessen'),
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
                Text(_betrieb!.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (_betrieb!.ort != null)
                  Text(_betrieb!.ort!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
            tooltip: 'Betrieb anzeigen',
            onPressed: () {
              context.push('/betriebe/${_betrieb!.serverId ?? _betrieb!.routeId}');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showBetriebWechselDialog() async {
    final betriebe = ref
        .read(betriebeProvider)
        .where((b) => b.serverId != null && b.status != 'inaktiv')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    String search = '';

    final selected = await showModalBottomSheet<BetriebLocal>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = search.isEmpty
                ? betriebe
                : betriebe.where((b) {
                    final q = search.toLowerCase();
                    return b.name.toLowerCase().contains(q) ||
                        (b.ort?.toLowerCase().contains(q) ?? false);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: SearchBar(
                        hintText: 'Betrieb suchen...',
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.search, size: 20),
                        ),
                        onChanged: (v) => setSheetState(() => search = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final b = filtered[i];
                          final isCurrent =
                              b.serverId == _betrieb?.serverId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCurrent
                                  ? AppColors.primary.withAlpha(40)
                                  : AppColors.primary.withAlpha(15),
                              child: Icon(Icons.store,
                                  color: AppColors.primary, size: 18),
                            ),
                            title: Text(b.name,
                                style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500)),
                            subtitle: b.ort != null ? Text(b.ort!) : null,
                            trailing: isCurrent
                                ? const Icon(Icons.check,
                                    color: AppColors.primary, size: 20)
                                : null,
                            onTap: () => Navigator.pop(ctx, b),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (selected != null && selected.serverId != _betrieb?.serverId && mounted) {
      setState(() {
        _betrieb = selected;
        _rechnungsstellung = selected.rechnungsstellung;
        _istBergkunde = selected.istBergkunde;
        _anlagenDesBetrieb = [];
        _selectedAnlageIds = {};
      });
      // Anlagen des neuen Betriebs laden
      final anlagen =
          await AnlageRepository.getByBetrieb(selected.serverId!);
      if (mounted) {
        setState(() {
          _anlagenDesBetrieb = anlagen;
          _selectedAnlageIds =
              anlagen.map((a) => a.serverId ?? a.routeId).toSet();
        });
        if (!_isEdit) await _recalculateHaehne();
      }
    }
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
              const Icon(Icons.precision_manufacturing, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Anlagen',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text('$selectedCount/$totalCount ausgewählt',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                    title: Text(anlage.bezeichnung ?? anlage.typAnlage,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: anlage.bezeichnung != null
                        ? Text(anlage.typAnlage, style: const TextStyle(fontSize: 12))
                        : null,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                  tooltip: 'Anlage anzeigen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
        title: const Text('Heineken-Monteur',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Nur Datum erfassen (kein Preis/Protokoll)',
            style: TextStyle(fontSize: 12)),
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
        color: _istKulanz
            ? AppColors.warning.withAlpha(25)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _istKulanz
              ? AppColors.warning.withAlpha(100)
              : AppColors.divider,
        ),
      ),
      child: SwitchListTile(
        title: const Text('Kulanz (kostenlos)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Gesamtpreis CHF 0.–',
            style: TextStyle(fontSize: 12)),
        secondary: const Icon(Icons.volunteer_activism, color: AppColors.warning),
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
                        const Icon(Icons.picture_as_pdf,
                            size: 40, color: AppColors.error),
                        const SizedBox(height: 8),
                        if (snapshot.hasData)
                          FilledButton.icon(
                            onPressed: () => launchUrl(
                                Uri.parse(snapshot.data!),
                                mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('PDF öffnen'),
                          )
                        else
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
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
              future:
                  ProtokollFotoStorage.getSignedUrl(_existingFotoPfad!),
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
                              Icon(Icons.broken_image,
                                  color: AppColors.textSecondary),
                              SizedBox(height: 4),
                              Text('Foto konnte nicht geladen werden',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
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
                  child:
                      const Center(child: CircularProgressIndicator()),
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
                label: Text(_fotoBytes != null || _existingFotoPfad != null
                    ? 'Neues Foto'
                    : 'Protokoll fotografieren'),
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
                      color: AppColors.textSecondary, fontSize: 13),
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
            value: _serviceTyp,
            decoration: const InputDecoration(
              labelText: 'Service-Typ',
              prefixIcon: Icon(Icons.cleaning_services),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                  value: 'reinigung_bier', child: Text('Reinigung Bier')),
              DropdownMenuItem(
                  value: 'reinigung_orion',
                  child: Text('Reinigung Orion')),
              DropdownMenuItem(
                  value: 'heigenie', child: Text('Heigenie')),
              DropdownMenuItem(
                  value: 'reinigung_fremd',
                  child: Text('Reinigung Fremd')),
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
          _haehneRow('Hähne Eigen', _anzahlHaehneEigen, _hahnPreis('zusatz_hahn_eigen'),
              (v) => _updatePositionAndPreis(() => _anzahlHaehneEigen = v)),
          _haehneRow('Hähne Orion', _anzahlHaehneOrion, _hahnPreis('zusatz_hahn_orion'),
              (v) => _updatePositionAndPreis(() => _anzahlHaehneOrion = v)),
          _haehneRow('Hähne Fremd', _anzahlHaehneFremd, _hahnPreis('zusatz_hahn_fremd'),
              (v) => _updatePositionAndPreis(() => _anzahlHaehneFremd = v)),
          _haehneRow('Hähne Wein', _anzahlHaehneWein, _hahnPreis('zusatz_hahn_wein'),
              (v) => _updatePositionAndPreis(() => _anzahlHaehneWein = v)),
          _haehneRow('Anderer Standort', _anzahlHaehneAndererStandort, _hahnPreis('zusatz_hahn_anderer_standort'),
              (v) => _updatePositionAndPreis(() => _anzahlHaehneAndererStandort = v)),

          // Bergkunden-Zuschlag
          if (_istBergkunde) ...[
            const SizedBox(height: 4),
            _preisRow('Bergkunden-Zuschlag (exkl. MwSt)',
                _istKulanz ? 0 : ((_preisliste?['bergkunden_zuschlag'] as num?)?.toDouble() ?? 100.0)),
          ],

          // Kalkulation
          const Divider(height: 16),
          if (_istKulanz)
            ..._buildKulanzKalkulationRows()
          else
            ..._buildKalkulationRows(preis),
        ],
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
          const Text('Total (inkl. 8.1% MwSt)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Text('0.00 CHF',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
          'MwSt (${preis['mwstSatz']!.toStringAsFixed(1)}%)', preis['mwst']!),
      const Divider(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total (inkl. 8.1% MwSt)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${preis['brutto']!.toStringAsFixed(2)} CHF',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    ];
  }

  Widget _buildPreislisteReferenz() {
    final p = _preisliste!;
    return ExpansionTile(
      title: const Text('Preisliste (exkl. MwSt)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        _preislisteRow('Grundtarif Eigen',
            (p['grundtarif_reinigung_bier'] as num?)?.toDouble() ?? 0),
        _preislisteRow('Grundtarif Orion',
            (p['grundtarif_reinigung_orion'] as num?)?.toDouble() ?? 0),
        _preislisteRow('Service Heigenie (Leihvertrag)',
            (p['grundtarif_heigenie'] as num?)?.toDouble() ?? 0),
        _preislisteRow('Grundtarif Fremd',
            (p['grundtarif_reinigung_fremd'] as num?)?.toDouble() ?? 0),
        const Divider(height: 8),
        _preislisteRow('Zusätzl. Hahn Eigen/Orion',
            (p['zusatz_hahn_eigen'] as num?)?.toDouble() ?? 18),
        _preislisteRow('Zusätzl. Hahn Fremd',
            (p['zusatz_hahn_fremd'] as num?)?.toDouble() ?? 23),
        _preislisteRow('Zusätzl. Hahn anderer Standort',
            (p['zusatz_hahn_anderer_standort'] as num?)?.toDouble() ?? 30),
        const Divider(height: 8),
        _preislisteRow('Bergkunden-Zuschlag',
            (p['bergkunden_zuschlag'] as num?)?.toDouble() ?? 100),
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
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Text('CHF ${betrag.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _haehneRow(
      String label, int anzahl, double preisProHahn, ValueChanged<int> onChanged) {
    final total = _istKulanz ? 0.0 : anzahl * preisProHahn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text('${betrag.toStringAsFixed(2)} CHF',
              style: const TextStyle(fontSize: 13)),
        ],
      ),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
