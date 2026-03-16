import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/reinigung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/reinigung_pdf_storage.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

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

  // Unterschriften
  late final SignatureController _sigTechnikerController;
  late final SignatureController _sigKundeController;
  late final _kundeNameController = TextEditingController();
  String? _existingTechnikerSig;
  String? _existingKundeSig;
  bool _techDrawNew = false;
  bool _kundeDrawNew = false;

  // Checkliste - Anlagen-Checks
  bool _hatDurchlaufkuehler = false;
  bool _hatBuffetanstich = false;
  bool _hatKuehlkeller = false;
  bool _hatFasskuehler = false;

  // Checkliste - Service-Checks
  bool _begleitkuehlungKontrolliert = false;
  bool _installationAllgemeinKontrolliert = false;
  bool _aligalAnschluesseKontrolliert = false;
  bool _durchlaufkuehlerAusgeblasen = false;
  bool _wasserstandKontrolliert = false;
  bool _wasserGewechselt = false;
  bool _leitungWasserVorgespuelt = false;
  bool _leitungsreinigungReinigungsmittel = false;
  bool _foerderdruckKontrolliert = false;
  bool _zapfhahnZerlegtGereinigt = false;
  bool _zapfkopfZerlegtGereinigt = false;
  bool _servicekarteAusgefuellt = false;

  String _status = 'offen';

  // Checkliste-Notizen
  Map<String, String> _checklisteNotizen = {};

  // Preis-Kalkulator
  String? _serviceTyp;
  bool _istBergkunde = false;
  int _anzahlHaehneEigen = 0;
  int _anzahlHaehneOrion = 0;
  int _anzahlHaehneFremd = 0;
  int _anzahlHaehneWein = 0;
  int _anzahlHaehneAndererStandort = 0;
  Map<String, dynamic>? _preisliste;

  bool get _isEdit => widget.reinigungId != null;

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _uhrzeitStartController.text = _formatTime(TimeOfDay.now());
    _sigTechnikerController = SignatureController(
      penStrokeWidth: 2.0,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _sigKundeController = SignatureController(
      penStrokeWidth: 2.0,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
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
      _hatDurchlaufkuehler = r.hatDurchlaufkuehler;
      _hatBuffetanstich = r.hatBuffetanstich;
      _hatKuehlkeller = r.hatKuehlkeller;
      _hatFasskuehler = r.hatFasskuehler;
      _begleitkuehlungKontrolliert = r.begleitkuehlungKontrolliert;
      _installationAllgemeinKontrolliert =
          r.installationAllgemeinKontrolliert;
      _aligalAnschluesseKontrolliert = r.aligalAnschluesseKontrolliert;
      _durchlaufkuehlerAusgeblasen = r.durchlaufkuehlerAusgeblasen;
      _wasserstandKontrolliert = r.wasserstandKontrolliert;
      _wasserGewechselt = r.wasserGewechselt;
      _leitungWasserVorgespuelt = r.leitungWasserVorgespuelt;
      _leitungsreinigungReinigungsmittel =
          r.leitungsreinigungReinigungsmittel;
      _foerderdruckKontrolliert = r.foerderdruckKontrolliert;
      _zapfhahnZerlegtGereinigt = r.zapfhahnZerlegtGereinigt;
      _zapfkopfZerlegtGereinigt = r.zapfkopfZerlegtGereinigt;
      _servicekarteAusgefuellt = r.servicekarteAusgefuellt;
      _checklisteNotizen = r.checklisteNotizenJson != null
          ? Map<String, String>.from(jsonDecode(r.checklisteNotizenJson!))
          : {};
      _status = r.status;
      _existingTechnikerSig = r.unterschriftTechniker;
      _existingKundeSig = r.unterschriftKunde;
      _kundeNameController.text = r.unterschriftKundeName ?? '';
      // Preis-Felder
      _serviceTyp = r.serviceTyp;
      _istBergkunde = r.istBergkunde;
      _anzahlHaehneEigen = r.anzahlHaehneEigen;
      _anzahlHaehneOrion = r.anzahlHaehneOrion;
      _anzahlHaehneFremd = r.anzahlHaehneFremd;
      _anzahlHaehneWein = r.anzahlHaehneWein;
      _anzahlHaehneAndererStandort = r.anzahlHaehneAndererStandort;
    });
    _loadPreisData();
  }

  Future<void> _loadPreisData() async {
    try {
      final anlageId = widget.anlageId ?? _existing?.anlageId;
      final betriebId = widget.betriebId ?? _existing?.betriebId;

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

      // Betrieb → Bergkunde (nur wenn noch nicht manuell gesetzt)
      if (betriebId != null && !_isEdit) {
        final betrieb = await BetriebRepository.getByServerId(betriebId);
        if (betrieb != null && mounted) {
          setState(() => _istBergkunde = betrieb.istBergkunde);
        }
      }

      // Anlage → ServiceTyp + Checklist-Defaults ableiten
      if (anlageId != null && _serviceTyp == null) {
        final anlage = await AnlageRepository.getByServerId(anlageId);
        if (anlage != null && mounted) {
          final hatDLK = anlage.durchlaufkuehler != null &&
              anlage.durchlaufkuehler != 'keiner';
          final isOrion = anlage.typAnlage.toLowerCase() == 'orion';

          setState(() {
            _serviceTyp = switch (anlage.typAnlage.toLowerCase()) {
              'orion' => 'reinigung_orion',
              'heigenie' => 'heigenie',
              _ => 'reinigung_bier',
            };

            if (!_isEdit) {
              // Anlagen-Checks — aus Anlage-Daten
              _hatDurchlaufkuehler = hatDLK;
              _hatFasskuehler = anlage.vorkuehler == 'Fasskühler';
              _hatKuehlkeller = anlage.vorkuehler == 'Kühlzelle';
              _hatBuffetanstich = anlage.vorkuehler == 'Buffet';

              // Service-Checks
              _begleitkuehlungKontrolliert = hatDLK;
              _installationAllgemeinKontrolliert = true;
              _aligalAnschluesseKontrolliert = !isOrion;
              _durchlaufkuehlerAusgeblasen = hatDLK;
              _wasserstandKontrolliert = hatDLK;
              _wasserGewechselt = false; // wird selten gemacht
              _leitungWasserVorgespuelt = true;
              _leitungsreinigungReinigungsmittel = true;
              _foerderdruckKontrolliert = true;
              _zapfhahnZerlegtGereinigt = true;
              _zapfkopfZerlegtGereinigt = !isOrion;
              _servicekarteAusgefuellt = true;
            }
          });
        }
      }

      // Bierleitungen → Hähne zählen
      if (anlageId != null && !_isEdit) {
        final leitungen = await BierleitungRepository.getByAnlage(anlageId);
        if (mounted) {
          int eigen = 0, orion = 0, fremd = 0, wein = 0;
          for (final l in leitungen) {
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
          setState(() {
            _anzahlHaehneEigen = eigen;
            _anzahlHaehneOrion = orion;
            _anzahlHaehneFremd = fremd;
            _anzahlHaehneWein = wein;
          });
        }
      }
    } catch (_) {
      // Preisberechnung ist optional, Fehler nicht kritisch
    }
  }

  Future<void> _save({bool abschliessen = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final r = _existing ?? ReinigungLocal();

      if (!_isEdit) {
        r.anlageId = widget.anlageId!;
        r.betriebId = widget.betriebId!;
      }

      r.datum = _datum;
      r.uhrzeitStart = _emptyToNull(_uhrzeitStartController.text);
      r.uhrzeitEnde = _emptyToNull(_uhrzeitEndeController.text);
      r.notizen = _emptyToNull(_notizenController.text);

      r.hatDurchlaufkuehler = _hatDurchlaufkuehler;
      r.hatBuffetanstich = _hatBuffetanstich;
      r.hatKuehlkeller = _hatKuehlkeller;
      r.hatFasskuehler = _hatFasskuehler;
      r.begleitkuehlungKontrolliert = _begleitkuehlungKontrolliert;
      r.installationAllgemeinKontrolliert =
          _installationAllgemeinKontrolliert;
      r.aligalAnschluesseKontrolliert = _aligalAnschluesseKontrolliert;
      r.durchlaufkuehlerAusgeblasen = _durchlaufkuehlerAusgeblasen;
      r.wasserstandKontrolliert = _wasserstandKontrolliert;
      r.wasserGewechselt = _wasserGewechselt;
      r.leitungWasserVorgespuelt = _leitungWasserVorgespuelt;
      r.leitungsreinigungReinigungsmittel =
          _leitungsreinigungReinigungsmittel;
      r.foerderdruckKontrolliert = _foerderdruckKontrolliert;
      r.zapfhahnZerlegtGereinigt = _zapfhahnZerlegtGereinigt;
      r.zapfkopfZerlegtGereinigt = _zapfkopfZerlegtGereinigt;
      r.servicekarteAusgefuellt = _servicekarteAusgefuellt;

      // Checkliste-Notizen (leere Einträge entfernen)
      final cleanedNotizen = Map<String, String>.from(_checklisteNotizen)
        ..removeWhere((_, v) => v.trim().isEmpty);
      r.checklisteNotizenJson =
          cleanedNotizen.isNotEmpty ? jsonEncode(cleanedNotizen) : null;

      // Preis-Felder
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

      // Unterschriften
      if (_sigTechnikerController.isNotEmpty) {
        final bytes = await _sigTechnikerController.toPngBytes();
        if (bytes != null) r.unterschriftTechniker = base64Encode(bytes);
      } else if (_existingTechnikerSig != null && !_techDrawNew) {
        r.unterschriftTechniker = _existingTechnikerSig;
      }
      if (_sigKundeController.isNotEmpty) {
        final bytes = await _sigKundeController.toPngBytes();
        if (bytes != null) r.unterschriftKunde = base64Encode(bytes);
      } else if (_existingKundeSig != null && !_kundeDrawNew) {
        r.unterschriftKunde = _existingKundeSig;
      }
      r.unterschriftKundeName = _emptyToNull(_kundeNameController.text);

      if (abschliessen) {
        r.status = 'abgeschlossen';
        r.uhrzeitEnde ??= _formatTime(TimeOfDay.now());
      } else {
        r.status = _status;
      }

      await ReinigungRepository.save(r);

      // PDF generieren und hochladen bei Abschluss
      if (abschliessen) {
        try {
          final pdfBytes = await ReinigungPdfService.generate(r);
          await ReinigungPdfStorage.uploadPdf(r.routeId, pdfBytes);
        } catch (e) {
          // PDF-Fehler blockiert Reinigung nicht
          debugPrint('PDF-Generierung fehlgeschlagen: $e');
        }

        // Kundenrechnung erstellen (falls zutreffend)
        if (kIsWeb) {
          try {
            final betrieb =
                await BetriebRepository.getByServerId(r.betriebId);
            if (betrieb != null) {
              await RechnungService.createFromReinigung(r, betrieb);
            }
          } catch (e) {
            debugPrint('Rechnungserstellung fehlgeschlagen: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(abschliessen
                ? 'Reinigung abgeschlossen'
                : _isEdit
                    ? 'Reinigung aktualisiert'
                    : 'Reinigung gestartet'),
          ),
        );
        if (kIsWeb) {
          ref.invalidate(reinigungenStreamProvider);
          if (abschliessen) ref.invalidate(rechnungenStreamProvider);
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

  String? _emptyToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _uhrzeitStartController.dispose();
    _uhrzeitEndeController.dispose();
    _notizenController.dispose();
    _sigTechnikerController.dispose();
    _sigKundeController.dispose();
    _kundeNameController.dispose();
    super.dispose();
  }

  /// Kaufmännisch auf 0.05 CHF runden (5 Rappen)
  double _roundTo5Rappen(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  Map<String, double> _calculatePreis() {
    if (_preisliste == null || _serviceTyp == null) return {};
    final p = _preisliste!;

    final grundtarif = switch (_serviceTyp) {
      'reinigung_bier' => (p['grundtarif_reinigung_bier'] as num?)?.toDouble() ?? 0,
      'reinigung_orion' => (p['grundtarif_reinigung_orion'] as num?)?.toDouble() ?? 0,
      'heigenie' => (p['grundtarif_heigenie'] as num?)?.toDouble() ?? 0,
      'reinigung_fremd' => (p['grundtarif_reinigung_fremd'] as num?)?.toDouble() ?? 0,
      'wein' => (p['grundtarif_wein'] as num?)?.toDouble() ?? 0,
      _ => 0.0,
    };

    // Zusätzliche Hähne — Grundtarif beinhaltet 1 Hahn, fixe Preise
    double zusatz = 0;
    zusatz += _anzahlHaehneEigen * 18.0;
    zusatz += _anzahlHaehneOrion * 18.0;
    zusatz += _anzahlHaehneFremd * 23.0;
    zusatz += _anzahlHaehneWein * 23.0;
    zusatz += _anzahlHaehneAndererStandort * 30.0;

    final bergkundenZuschlag = _istBergkunde ? 100.0 : 0.0;
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

  int get _checkedCount {
    var count = 0;
    if (_begleitkuehlungKontrolliert) count++;
    if (_installationAllgemeinKontrolliert) count++;
    if (_aligalAnschluesseKontrolliert) count++;
    if (_durchlaufkuehlerAusgeblasen) count++;
    if (_wasserstandKontrolliert) count++;
    if (_wasserGewechselt) count++;
    if (_leitungWasserVorgespuelt) count++;
    if (_leitungsreinigungReinigungsmittel) count++;
    if (_foerderdruckKontrolliert) count++;
    if (_zapfhahnZerlegtGereinigt) count++;
    if (_zapfkopfZerlegtGereinigt) count++;
    if (_servicekarteAusgefuellt) count++;
    if (_hatDurchlaufkuehler) count++;
    if (_hatBuffetanstich) count++;
    if (_hatKuehlkeller) count++;
    if (_hatFasskuehler) count++;
    return count;
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
        actions: [
          if (_isEdit || !_isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$_checkedCount/16',
                style: TextStyle(
                  color: _checkedCount == 16
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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

            // === Anlagen-Checks ===
            _sectionTitle(context, 'Anlagen-Checks'),
            const SizedBox(height: 8),
            _checkTile('Durchlaufkühler vorhanden',
                _hatDurchlaufkuehler,
                (v) => setState(() => _hatDurchlaufkuehler = v),
                noteKey: 'hat_durchlaufkuehler'),
            _checkTile('Buffetanstich vorhanden', _hatBuffetanstich,
                (v) => setState(() => _hatBuffetanstich = v),
                noteKey: 'hat_buffetanstich'),
            _checkTile('Kühlkeller vorhanden', _hatKuehlkeller,
                (v) => setState(() => _hatKuehlkeller = v),
                noteKey: 'hat_kuehlkeller'),
            _checkTile('Fasskühler vorhanden', _hatFasskuehler,
                (v) => setState(() => _hatFasskuehler = v),
                noteKey: 'hat_fasskuehler'),
            const SizedBox(height: 16),

            // === Service-Checkliste ===
            _sectionTitle(context, 'Service-Checkliste (12 Punkte)'),
            const SizedBox(height: 8),
            _checkTile('Begleitkühlung kontrolliert',
                _begleitkuehlungKontrolliert,
                (v) => setState(() => _begleitkuehlungKontrolliert = v),
                noteKey: 'begleitkuehlung_kontrolliert'),
            _checkTile('Installation allgemein kontrolliert',
                _installationAllgemeinKontrolliert,
                (v) => setState(
                    () => _installationAllgemeinKontrolliert = v),
                noteKey: 'installation_allgemein_kontrolliert'),
            _checkTile('Aligal-Anschlüsse kontrolliert',
                _aligalAnschluesseKontrolliert,
                (v) => setState(
                    () => _aligalAnschluesseKontrolliert = v),
                noteKey: 'aligal_anschluesse_kontrolliert'),
            _checkTile('Durchlaufkühler ausgeblasen',
                _durchlaufkuehlerAusgeblasen,
                (v) =>
                    setState(() => _durchlaufkuehlerAusgeblasen = v),
                noteKey: 'durchlaufkuehler_ausgeblasen'),
            _checkTile('Wasserstand kontrolliert',
                _wasserstandKontrolliert,
                (v) => setState(() => _wasserstandKontrolliert = v),
                noteKey: 'wasserstand_kontrolliert'),
            _checkTile('Wasser gewechselt', _wasserGewechselt,
                (v) => setState(() => _wasserGewechselt = v),
                noteKey: 'wasser_gewechselt'),
            _checkTile('Leitung mit Wasser vorgespült',
                _leitungWasserVorgespuelt,
                (v) => setState(() => _leitungWasserVorgespuelt = v),
                noteKey: 'leitung_wasser_vorgespuelt'),
            _checkTile('Leitungsreinigung mit Reinigungsmittel',
                _leitungsreinigungReinigungsmittel,
                (v) => setState(
                    () => _leitungsreinigungReinigungsmittel = v),
                noteKey: 'leitungsreinigung_reinigungsmittel'),
            _checkTile('Förderdruck kontrolliert',
                _foerderdruckKontrolliert,
                (v) => setState(() => _foerderdruckKontrolliert = v),
                noteKey: 'foerderdruck_kontrolliert'),
            _checkTile('Zapfhahn zerlegt & gereinigt',
                _zapfhahnZerlegtGereinigt,
                (v) => setState(() => _zapfhahnZerlegtGereinigt = v),
                noteKey: 'zapfhahn_zerlegt_gereinigt'),
            _checkTile('Zapfkopf zerlegt & gereinigt',
                _zapfkopfZerlegtGereinigt,
                (v) => setState(() => _zapfkopfZerlegtGereinigt = v),
                noteKey: 'zapfkopf_zerlegt_gereinigt'),
            _checkTile('Servicekarte ausgefüllt',
                _servicekarteAusgefuellt,
                (v) => setState(() => _servicekarteAusgefuellt = v),
                noteKey: 'servicekarte_ausgefuellt'),
            const SizedBox(height: 16),

            // === Notizen ===
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

            // === Preiskalkulation ===
            _sectionTitle(context, 'Preiskalkulation'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _serviceTyp,
              decoration: const InputDecoration(
                labelText: 'Grundtarif',
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'reinigung_bier', child: Text('Heineken/Bier')),
                DropdownMenuItem(value: 'reinigung_orion', child: Text('Orion')),
                DropdownMenuItem(value: 'heigenie', child: Text('Heigenie')),
                DropdownMenuItem(value: 'reinigung_fremd', child: Text('Fremdbier')),
                DropdownMenuItem(value: 'wein', child: Text('Wein')),
              ],
              onChanged: (v) => setState(() => _serviceTyp = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _haehneField('Zusätzliche Eigen', _anzahlHaehneEigen,
                      (v) => setState(() => _anzahlHaehneEigen = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _haehneField('Zusätzliche Orion', _anzahlHaehneOrion,
                      (v) => setState(() => _anzahlHaehneOrion = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _haehneField('Zusätzliche Fremd', _anzahlHaehneFremd,
                      (v) => setState(() => _anzahlHaehneFremd = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _haehneField('Zusätzliche Wein', _anzahlHaehneWein,
                      (v) => setState(() => _anzahlHaehneWein = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _haehneField('Zusätzliche Anderer Standort', _anzahlHaehneAndererStandort,
                (v) => setState(() => _anzahlHaehneAndererStandort = v)),
            const SizedBox(height: 12),
            _buildPreisPreview(),
            const SizedBox(height: 24),

            // === Unterschriften ===
            _sectionTitle(context, 'Unterschriften'),
            const SizedBox(height: 12),

            // Techniker
            Text('Techniker',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _buildSignaturePad(
              controller: _sigTechnikerController,
              existingSig: _existingTechnikerSig,
              drawNew: _techDrawNew,
              onClear: () => setState(() {
                _sigTechnikerController.clear();
                _existingTechnikerSig = null;
                _techDrawNew = true;
              }),
              onRedraw: () => setState(() => _techDrawNew = true),
            ),
            const SizedBox(height: 16),

            // Kunde
            Text('Kunde',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _kundeNameController,
              decoration: const InputDecoration(
                labelText: 'Name des Kunden',
                prefixIcon: Icon(Icons.person),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            _buildSignaturePad(
              controller: _sigKundeController,
              existingSig: _existingKundeSig,
              drawNew: _kundeDrawNew,
              onClear: () => setState(() {
                _sigKundeController.clear();
                _existingKundeSig = null;
                _kundeDrawNew = true;
              }),
              onRedraw: () => setState(() => _kundeDrawNew = true),
            ),
            const SizedBox(height: 24),

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
                  onPressed: _isLoading
                      ? null
                      : () => _save(abschliessen: true),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Reinigung abschliessen'),
                ),
              ],
            ] else
              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _save(abschliessen: true),
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Reinigung abschliessen'),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _haehneField(String label, int value, ValueChanged<int> onChanged) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(
        labelText: '$label Hähne',
        isDense: true,
        suffixText: label.startsWith('Zusätzliche') ? _haehnePreis(label) : null,
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }

  String? _haehnePreis(String label) {
    if (label.contains('Eigen') || label.contains('Orion')) return '@ 18.-';
    if (label.contains('Fremd') || label.contains('Wein')) return '@ 23.-';
    if (label.contains('Anderer')) return '@ 30.-';
    return null;
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
        child: const Text(
          'Preisliste wird geladen...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
          _preisRow('Grundtarif', preis['grundtarif']!),
          if (preis['zusatz']! > 0)
            _preisRow('Zusätzliche Hähne', preis['zusatz']!),
          if (preis['bergkundenZuschlag']! > 0)
            _preisRow('Bergkunden-Zuschlag', preis['bergkundenZuschlag']!),
          const Divider(height: 16),
          _preisRow('Netto', preis['netto']!),
          _preisRow('MwSt (${preis['mwstSatz']!.toStringAsFixed(1)}%)', preis['mwst']!),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${preis['brutto']!.toStringAsFixed(2)} CHF',
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

  Widget _buildSignaturePad({
    required SignatureController controller,
    required String? existingSig,
    required bool drawNew,
    required VoidCallback onClear,
    required VoidCallback onRedraw,
  }) {
    // Bestehende Signatur anzeigen (wenn vorhanden und nicht "neu zeichnen")
    if (existingSig != null && !drawNew) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.memory(
                base64Decode(existingSig),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onRedraw,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Neu zeichnen'),
              ),
            ],
          ),
        ],
      );
    }

    // Zeichenfläche
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Signature(
              controller: controller,
              height: 150,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Löschen'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _checkTile(String label, bool value, ValueChanged<bool> onChanged,
      {String? noteKey}) {
    final hasNote = noteKey != null &&
        _checklisteNotizen[noteKey] != null &&
        _checklisteNotizen[noteKey]!.isNotEmpty;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: Text(label, style: const TextStyle(fontSize: 14)),
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.success,
              ),
            ),
            if (noteKey != null)
              IconButton(
                icon: Icon(
                  hasNote ? Icons.note : Icons.note_add_outlined,
                  size: 18,
                  color: hasNote ? AppColors.primary : AppColors.textSecondary,
                ),
                tooltip: 'Notiz',
                onPressed: () => _showNoteDialog(noteKey, label),
              ),
          ],
        ),
        if (hasNote)
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _checklisteNotizen[noteKey]!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showNoteDialog(String key, String label) async {
    final controller = TextEditingController(
      text: _checklisteNotizen[key] ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Notiz',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Löschen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      setState(() {
        if (result.trim().isEmpty) {
          _checklisteNotizen.remove(key);
        } else {
          _checklisteNotizen[key] = result.trim();
        }
      });
    }
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
