import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/image/document_enhancer.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';

/// Vorbefüllung für eine neue Anlass-Montage (aus dem Event-Zeit-Tab, E4).
class MontageVorbefuellung {
  final String montageTyp;
  final String? betriebId;
  final DateTime datum;
  final List<({String text, double stunden})> slots;
  const MontageVorbefuellung({
    required this.montageTyp,
    required this.betriebId,
    required this.datum,
    required this.slots,
  });
}

class MontageFormScreen extends ConsumerStatefulWidget {
  final String? montageId; // null = neu
  final String? anlageId;
  final String? betriebId;
  final MontageVorbefuellung? vorbefuellung;

  const MontageFormScreen({
    super.key,
    this.montageId,
    this.anlageId,
    this.betriebId,
    this.vorbefuellung,
  });

  @override
  ConsumerState<MontageFormScreen> createState() => _MontageFormScreenState();
}

class _MontageFormScreenState extends ConsumerState<MontageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  MontageLocal? _existing;

  // Typ
  String _montageTyp = 'neumontage';

  // Betrieb
  String? _betriebId;

  // Datum & Stunden
  late DateTime _datum;
  late final _stundenController = TextEditingController();
  late final _betragController = TextEditingController();

  // Details
  late final _beschreibungController = TextEditingController();

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

  // Stundensatz (80 CHF/h default)
  double _stundensatz = 80.0;

  // HeiGenie-spezifisch
  int _anzahlHaehne = 0;
  bool _istBergkunde = false;
  Preis? _preisliste;
  Uint8List? _fotoBytes;
  bool _fotoProcessing = false;
  String _fotoProcessingStep = '';
  bool _fotoUploading = false;
  String? _existingFotoPfad;
  String? _heinekenMailRsl;

  bool get _isEdit => widget.montageId != null;

  /// Betrieb-Feld deaktiviert bei Spesen und Aufwandsentschädigung
  bool get _betriebDisabled =>
      _montageTyp == 'spesen' || _montageTyp == 'aufwandsentschaedigung';

  /// Bei Spesen: CHF-Betrag eingeben statt Stunden
  bool get _isSpesen => _montageTyp == 'spesen';

  /// HeiGenie: Hahn-basierte Preisberechnung
  bool get _isHeigenie => _montageTyp == 'heigenie_service';

  /// Anlass: Tages-Einträge in Material-Slots
  bool get _isAnlass => _montageTyp == 'anlass';

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _betriebId = widget.betriebId;
    final vb = widget.vorbefuellung;
    if (vb != null && !_isEdit) {
      _montageTyp = vb.montageTyp;
      _datum = vb.datum;
      if (vb.betriebId != null) _betriebId = vb.betriebId;
      for (var i = 0; i < 5 && i < vb.slots.length; i++) {
        final s = vb.slots[i];
        // Bei Anlass ist die "material_id" der Freitext.
        _materialIds[i] = s.text;
        _materialControllers[i].text = s.text;
        _materialMengen[i] = s.stunden;
        _materialMengenControllers[i].text = s.stunden.toStringAsFixed(2);
      }
    }
    _loadLager();
    _loadStundensatz();
    _loadHeigeniePreise();
    if (_isEdit) {
      _loadMontage();
    }
  }

  Future<void> _loadLager() async {
    try {
      final items = await LagerRepository.getAll();
      if (mounted) setState(() => _lagerItems = items);
    } catch (_) {}
  }

  Future<void> _loadStundensatz() async {
    try {
      final preisRows = await SupabaseService.client
          .from('preise')
          .select('montage_stundensatz')
          .lte('gueltig_ab', _datum.toIso8601String().substring(0, 10))
          .order('gueltig_ab', ascending: false)
          .limit(1);
      if (preisRows.isNotEmpty &&
          preisRows.first['montage_stundensatz'] != null) {
        final satz = double.tryParse(
          preisRows.first['montage_stundensatz'].toString(),
        );
        if (satz != null && mounted) setState(() => _stundensatz = satz);
      }
    } catch (_) {
      // Fallback: 80 CHF/h bleibt
    }
  }

  Future<void> _loadHeigeniePreise() async {
    try {
      final preis = await PreisRepository.getAktuell(datum: _datum);
      if (preis != null && mounted) {
        setState(() => _preisliste = preis);
      }
      // RSL-Kontakt für HeiGenie Mail laden
      final rslKontakt = await KontaktRepository.getHeinekenZuweisung(
        'heigenie_service',
      );
      if (rslKontakt != null && mounted) {
        setState(
          () => _heinekenMailRsl = MailConfig.empfaenger(
            rslKontakt.email,
            bereich: 'montage',
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadMontage() async {
    final m = await MontageRepository.getById(widget.montageId!);
    if (m == null || !mounted) return;

    setState(() {
      _existing = m;
      _montageTyp = m.montageTyp;
      _betriebId = m.betriebId;
      _datum = m.datum;
      _stundenController.text = m.dauerStunden != null
          ? m.dauerStunden.toString()
          : '';
      // Bei Spesen: Betrag aus kostenArbeit vorbelegen
      if (m.montageTyp == 'spesen' && m.kostenArbeit != null) {
        _betragController.text = m.kostenArbeit!.toStringAsFixed(2);
      }
      _beschreibungController.text = m.beschreibung;
      if (m.stundensatz != null) _stundensatz = m.stundensatz!;

      // HeiGenie-Felder
      _anzahlHaehne = m.anzahlHaehne ?? 0;
      _istBergkunde = m.istBergkunde;
      _existingFotoPfad = m.protokollFotoPfad;

      // Material / Anlass-Slots
      final ids = [
        m.material1Id,
        m.material2Id,
        m.material3Id,
        m.material4Id,
        m.material5Id,
      ];
      final mengen = [
        m.material1Menge,
        m.material2Menge,
        m.material3Menge,
        m.material4Menge,
        m.material5Menge,
      ];
      for (int i = 0; i < 5; i++) {
        _materialIds[i] = ids[i];
        _materialMengen[i] = mengen[i] ?? (m.montageTyp == 'anlass' ? 0 : 1);
        _materialMengenControllers[i].text = m.montageTyp == 'anlass'
            ? (mengen[i] != null ? mengen[i]!.toStringAsFixed(2) : '')
            : (mengen[i] ?? 1).toStringAsFixed(0);
        if (ids[i] != null) {
          if (m.montageTyp == 'anlass') {
            // Bei Anlass: material_id IST der Freitext
            _materialControllers[i].text = ids[i]!;
          } else {
            final match = _lagerItems.where((l) => l.id == ids[i]);
            if (match.isNotEmpty)
              _materialControllers[i].text = match.first.name;
          }
        }
      }
    });
  }

  // ── Foto-Methoden (Pattern aus reinigung_form_screen.dart) ────────

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    await _onPhotoTaken(bytes);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _fotoBytes = bytes;
      _existingFotoPfad = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scan importiert (${(bytes.length / 1024).round()} KB)',
          style: const TextStyle(fontSize: 13),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onPhotoTaken(Uint8List bytes) async {
    setState(() {
      _fotoProcessing = true;
      _fotoProcessingStep = 'Foto wird optimiert...';
    });

    await Future(() {});
    final frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frameCompleter.complete();
    });
    await frameCompleter.future;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    try {
      final enhanced = await DocumentEnhancer.enhance(
        bytes,
        onStep: (step) {
          if (mounted) setState(() => _fotoProcessingStep = step);
        },
      );
      if (!mounted) return;
      setState(() {
        _fotoBytes = enhanced;
        _existingFotoPfad = null;
        _fotoProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fotoBytes = bytes;
        _existingFotoPfad = null;
        _fotoProcessing = false;
      });
    }
  }

  // ── HeiGenie Preis berechnen (inkl. MwSt) ────────────────────────

  /// Preis inkl. MwSt: (Grundtarif + Zusatz-Hähne) × MwSt-Divisor + Bergkunde (fix)
  double? get _heigeniePreis {
    if (_preisliste == null || _anzahlHaehne <= 0) return null;
    final grundtarif = _preisliste!.grundtarifHeigenie;
    final zusatzHaehne = (_anzahlHaehne - 1).clamp(0, 999);
    final hahnZuschlag = _preisliste!.zusatzHahnEigen * zusatzHaehne;
    final haehneBrutto =
        (grundtarif + hahnZuschlag) * (1 + _preisliste!.mwstFaktor);
    final bergkunde = _istBergkunde ? _preisliste!.bergkundenZuschlag : 0.0;
    return _round5Rappen(haehneBrutto + bergkunde);
  }

  /// Brutto-Einzelpreise für Anzeige
  double _grundtarifBrutto() => _round5Rappen(
    _preisliste!.grundtarifHeigenie * (1 + _preisliste!.mwstFaktor),
  );

  double _zusatzHahnBrutto() => _round5Rappen(
    _preisliste!.zusatzHahnEigen * (1 + _preisliste!.mwstFaktor),
  );

  static double _round5Rappen(double v) => (v * 20).roundToDouble() / 20;

  // ── Save ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final m = _existing ?? MontageLocal();

      if (!_isEdit) {
        m.anlageId = widget.anlageId;
      }

      m.montageTyp = _montageTyp;
      m.betriebId = _betriebDisabled ? null : _betriebId;
      m.datum = _datum;
      m.beschreibung = _beschreibungController.text.trim();
      m.status = 'abgeschlossen';

      if (_isHeigenie) {
        // HeiGenie: Hahn-basierte Preisberechnung (Bergkunde inkl.)
        m.anzahlHaehne = _anzahlHaehne;
        m.istBergkunde = _istBergkunde;
        m.kostenArbeit = _heigeniePreis;
        m.preislisteId = _preisliste?.id;
        // Stunden-Umrechnung für Monatsrechnung
        m.stundensatz = _stundensatz;
        m.dauerStunden = (_heigeniePreis != null && _stundensatz > 0)
            ? ((_heigeniePreis! / _stundensatz * 100).roundToDouble() / 100)
            : null;

        // Foto uploaden
        if (_fotoBytes != null) {
          setState(() => _fotoUploading = true);
          final montageId = m.serverId ?? const Uuid().v4();
          m.serverId ??= montageId;
          final pfad = await ProtokollFotoStorage.uploadFoto(
            montageId,
            _fotoBytes!,
          );
          m.protokollFotoPfad = pfad;
          setState(() => _fotoUploading = false);
        }
      } else {
        // Standard-Logik
        m.anzahlHaehne = null;
        m.istBergkunde = false;
        m.protokollFotoPfad = _existingFotoPfad;
        m.stundensatz = _stundensatz;
        if (_isAnlass) {
          // Anlass: Stunden aus Slots summieren
          final totalStunden = _anlassTotalStunden;
          m.dauerStunden = totalStunden > 0 ? totalStunden : null;
          m.kostenArbeit = totalStunden > 0
              ? _stundensatz * totalStunden
              : null;
        } else if (_isSpesen) {
          final betrag = double.tryParse(_betragController.text.trim());
          m.kostenArbeit = betrag;
          m.dauerStunden = betrag != null && _stundensatz > 0
              ? (betrag / _stundensatz * 100).roundToDouble() / 100
              : null;
        } else {
          final stunden = double.tryParse(_stundenController.text.trim());
          m.dauerStunden = stunden;
          m.kostenArbeit = stunden != null ? _stundensatz * stunden : null;
        }
      }

      // Material-Felder (bei Anlass: Freitext-Beschreibung + Stunden)
      if (_isAnlass) {
        for (int i = 0; i < 5; i++) {
          final text = _materialControllers[i].text.trim();
          _materialIds[i] = text.isNotEmpty ? text : null;
          if (text.isEmpty) _materialMengen[i] = 0;
        }
      } else {
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
      }
      m.material1Id = _materialIds[0];
      m.material1Menge = _materialIds[0] != null ? _materialMengen[0] : null;
      m.material2Id = _materialIds[1];
      m.material2Menge = _materialIds[1] != null ? _materialMengen[1] : null;
      m.material3Id = _materialIds[2];
      m.material3Menge = _materialIds[2] != null ? _materialMengen[2] : null;
      m.material4Id = _materialIds[3];
      m.material4Menge = _materialIds[3] != null ? _materialMengen[3] : null;
      m.material5Id = _materialIds[4];
      m.material5Menge = _materialIds[4] != null ? _materialMengen[4] : null;

      await MontageRepository.save(m);
      // Wegpunkt nur beim NEU-Erfassen — Einsatz-Zeitstempel fuer Routen-
      // Daten und den Fahrzeit-Guard (Daniel 30.07.2026). Fire-and-forget.
      if (!_isEdit) {
        unawaited(
          WegpunktRepository.stempeln(
            quelle: 'montage',
            betriebId: m.betriebId,
            referenzId: m.serverId,
          ),
        );
      }
      if (_materialIds.any((id) => id != null)) {
        ref.invalidate(materialienStreamProvider);
      }

      // HeiGenie: RSL-Mail mit Protokoll
      if (_isHeigenie) {
        if (_heinekenMailRsl != null &&
            _heinekenMailRsl!.isNotEmpty &&
            m.protokollFotoPfad != null) {
          try {
            final betriebe = ref.read(betriebeProvider);
            final betrieb = _betriebId != null
                ? betriebe.where((b) => b.serverId == _betriebId).firstOrNull
                : null;
            final kundeName = betrieb?.name ?? 'Unbekannt';
            final datumStr =
                '${_datum.day.toString().padLeft(2, '0')}.${_datum.month.toString().padLeft(2, '0')}.${_datum.year}';

            await SupabaseService.client.functions.invoke(
              'send-rechnung-mail',
              body: {
                'to': _heinekenMailRsl,
                'subject':
                    'HeiGenie Service Protokoll - $kundeName - $datumStr',
                'bodyText':
                    'Beiliegend das Reinigungsprotokoll für den HeiGenie Service bei $kundeName vom $datumStr.\n\nAnzahl Hähne: $_anzahlHaehne\n\nMit freundlichen Grüssen\nSBS Projer GmbH',
                'protokollFotoPfad': m.protokollFotoPfad,
                'userId': SupabaseService.currentUser!.id,
              },
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Protokoll an RSL gesendet')),
              );
            }
          } catch (e) {
            debugPrint('RSL-Mail fehlgeschlagen: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Montage aktualisiert' : 'Montage erfasst'),
          ),
        );
        if (kIsWeb) ref.invalidate(montagenStreamProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fotoUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stundenController.dispose();
    _betragController.dispose();
    _beschreibungController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Montage bearbeiten' : 'Neue Montage'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // === Betrieb ===
                _sectionTitle(context, 'Betrieb'),
                const SizedBox(height: 8),
                _buildBetriebField(),
                const SizedBox(height: 24),

                // === Montage-Typ ===
                _sectionTitle(context, 'Montage-Typ'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _montageTyp,
                  decoration: const InputDecoration(
                    labelText: 'Typ *',
                    prefixIcon: Icon(Icons.build),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'neumontage',
                      child: Text('Neumontage'),
                    ),
                    DropdownMenuItem(
                      value: 'demontage',
                      child: Text('Demontage'),
                    ),
                    DropdownMenuItem(
                      value: 'abaenderung',
                      child: Text('Abänderung'),
                    ),
                    DropdownMenuItem(
                      value: 'heigenie_service',
                      child: Text('HeiGenie Service'),
                    ),
                    DropdownMenuItem(value: 'anlass', child: Text('Anlass')),
                    DropdownMenuItem(value: 'spesen', child: Text('Spesen')),
                    DropdownMenuItem(
                      value: 'aufwandsentschaedigung',
                      child: Text('Aufwandsentschädigung'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _montageTyp = v;
                        if (_betriebDisabled) _betriebId = null;
                        // Anlass: Stundenfelder auf 0 setzen
                        if (v == 'anlass') {
                          for (int i = 0; i < 5; i++) {
                            _materialMengen[i] = 0;
                            _materialMengenControllers[i].text = '0';
                          }
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // === HeiGenie: Hähne + Bergkunde ===
                if (_isHeigenie) ...[
                  _sectionTitle(context, 'HeiGenie Service'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _datum,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
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
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          initialValue: _anzahlHaehne > 0
                              ? _anzahlHaehne.toString()
                              : '',
                          decoration: const InputDecoration(
                            labelText: 'Anz. Hähne',
                            prefixIcon: Icon(Icons.countertops),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (!_isHeigenie) return null;
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Min. 1';
                            return null;
                          },
                          onChanged: (v) {
                            setState(() {
                              _anzahlHaehne = int.tryParse(v) ?? 0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_istBergkunde) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.landscape,
                            size: 18,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bergkunde (Zuschlag ${_preisliste?.bergkundenZuschlag.toStringAsFixed(2) ?? '–'} CHF inkl.)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildHeigenieKostenPreview(),
                  const SizedBox(height: 24),

                  // Protokoll-Scan
                  _sectionTitle(context, 'Reinigungsprotokoll'),
                  const SizedBox(height: 8),
                  if (_fotoBytes == null && _existingFotoPfad == null)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: _fotoUploading ? null : _takePhoto,
                              icon: const Icon(
                                Icons.document_scanner,
                                size: 24,
                              ),
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
                ],

                // === Datum & Stunden (nicht HeiGenie) ===
                if (!_isHeigenie) ...[
                  _sectionTitle(context, 'Datum & Aufwand'),
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
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() => _datum = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _isAnlass ? 'Startdatum' : 'Datum',
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            child: Text(_formatDate(_datum)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isSpesen
                            ? TextFormField(
                                controller: _betragController,
                                decoration: const InputDecoration(
                                  labelText: 'Betrag',
                                  prefixIcon: Icon(Icons.payments),
                                  suffixText: 'CHF',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                              )
                            : _isAnlass
                            ? InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Total Stunden',
                                  prefixIcon: Icon(Icons.timer),
                                  suffixText: 'h',
                                ),
                                child: Text(
                                  _anlassTotalStunden.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : TextFormField(
                                controller: _stundenController,
                                decoration: const InputDecoration(
                                  labelText: 'Stunden',
                                  prefixIcon: Icon(Icons.timer),
                                  suffixText: 'h',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                              ),
                      ),
                    ],
                  ),
                  if (!_isAnlass) ...[
                    const SizedBox(height: 12),
                    _buildKostenPreview(),
                  ],
                  const SizedBox(height: 24),
                ],

                // === Beschreibung ===
                _sectionTitle(context, 'Beschreibung'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _beschreibungController,
                  decoration: InputDecoration(
                    labelText: _betriebDisabled
                        ? 'Beschreibung *'
                        : 'Beschreibung',
                    prefixIcon: const Icon(Icons.description),
                    alignLabelWithHint: true,
                    hintText: _isSpesen
                        ? 'z.B. AdBlue, Arbeitsschuhe, Autobahnvignette'
                        : _montageTyp == 'aufwandsentschaedigung'
                        ? 'z.B. Schulung, Einführung neuer Mitarbeiter'
                        : _isHeigenie
                        ? 'z.B. HeiGenie Service Reinigung'
                        : _isAnlass
                        ? 'z.B. Festival Zürich 18.-20. April'
                        : null,
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  validator: _betriebDisabled
                      ? (v) => (v == null || v.trim().isEmpty)
                            ? 'Beschreibung erforderlich'
                            : null
                      : null,
                ),
                const SizedBox(height: 24),

                // === Anlass: Tages-/Spesen-Einträge ===
                if (_isAnlass) ...[
                  _sectionTitle(context, 'Tage & Spesen'),
                  const SizedBox(height: 4),
                  Text(
                    'Einzelne Tage und Spesen erfassen. Stunden werden automatisch summiert.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildAnlassSlots(),
                  const SizedBox(height: 8),
                  _buildAnlassSumme(),
                  const SizedBox(height: 24),
                ],

                // === Material (nur bei Standard-Montagen) ===
                if (!_isHeigenie &&
                    !_isAnlass &&
                    !_isSpesen &&
                    _montageTyp != 'aufwandsentschaedigung') ...[
                  _sectionTitle(context, 'Verwendetes Material'),
                  const SizedBox(height: 8),
                  ..._buildMaterialSlots(),
                  const SizedBox(height: 24),
                ],

                // === Speichern ===
                FilledButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Speichern' : 'Montage erfassen'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Foto-Processing Overlay
          if (_fotoProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_fotoProcessingStep),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── HeiGenie Kostenvorschau ───────────────────────────────────────

  Widget _buildHeigenieKostenPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: _preisliste == null
          ? const Text(
              'Preise werden geladen...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : _anzahlHaehne <= 0
          ? const Text(
              'Anzahl Hähne eingeben für Kostenvorschau',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : Column(
              children: [
                _preisRow(
                  'Grundtarif HeiGenie (inkl. 1 Hahn)',
                  '${_grundtarifBrutto().toStringAsFixed(2)} CHF',
                ),
                if (_anzahlHaehne > 1)
                  _preisRow(
                    '${_anzahlHaehne - 1} Zusatz-Hähne × ${_zusatzHahnBrutto().toStringAsFixed(2)}',
                    '${_round5Rappen(_zusatzHahnBrutto() * (_anzahlHaehne - 1)).toStringAsFixed(2)} CHF',
                  ),
                if (_istBergkunde)
                  _preisRow(
                    'Bergkunden-Pauschale (fix)',
                    '${_preisliste!.bergkundenZuschlag.toStringAsFixed(2)} CHF',
                  ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total inkl. MwSt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_heigeniePreis?.toStringAsFixed(2) ?? '–'} CHF',
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

  // ── Foto-Vorschau (neues Foto) ────────────────────────────────────

  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  // ── Anlass: Stunden-Summe aus Slots ──────────────────────────────

  double get _anlassTotalStunden {
    double sum = 0;
    for (int i = 0; i < 5; i++) {
      if (_materialControllers[i].text.trim().isNotEmpty) {
        sum += _materialMengen[i];
      }
    }
    return sum;
  }

  // ── Anlass: Tages-/Spesen-Slots ───────────────────────────────────

  List<Widget> _buildAnlassSlots() {
    return List.generate(
      5,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _materialControllers[i],
                decoration: InputDecoration(
                  labelText: 'Eintrag ${i + 1}',
                  isDense: true,
                  prefixIcon: const Icon(Icons.event_note, size: 20),
                  hintText: i < 3
                      ? 'z.B. Fr 18.4. Service'
                      : 'z.B. Spesen Essen',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.black26,
                  ),
                  suffixIcon: _materialControllers[i].text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            setState(() {
                              _materialControllers[i].clear();
                              _materialIds[i] = null;
                              _materialMengen[i] = 0;
                              _materialMengenControllers[i].text = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  // Freitext als "Material-ID" speichern
                  setState(() {
                    _materialIds[i] = v.trim().isNotEmpty ? v.trim() : null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 105,
              child: TextFormField(
                controller: _materialMengenControllers[i],
                decoration: const InputDecoration(
                  labelText: 'Stunden',
                  isDense: true,
                  suffixText: 'h',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) {
                  setState(() {
                    _materialMengen[i] = double.tryParse(v) ?? 0;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnlassSumme() {
    final total = _anlassTotalStunden;
    final kosten = total * _stundensatz;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: total <= 0
          ? const Text(
              'Tage/Spesen eintragen für Kostenvorschau',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : Column(
              children: [
                _preisRow(
                  'Stundensatz',
                  '${_stundensatz.toStringAsFixed(2)} CHF/h',
                ),
                _preisRow('Total Stunden', '${total.toStringAsFixed(2)} h'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Arbeitskosten',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${kosten.toStringAsFixed(2)} CHF',
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

  // ── Standard-Widgets (unverändert) ────────────────────────────────

  List<Widget> _buildMaterialSlots() {
    return List.generate(
      5,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _lagerItems.isNotEmpty
                  ? Autocomplete<Lager>(
                      initialValue: TextEditingValue(
                        text: _materialControllers[i].text,
                      ),
                      displayStringForOption: (l) => l.name,
                      optionsViewOpenDirection: OptionsViewOpenDirection.up,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty)
                          return _lagerItems.take(10);
                        final q = textEditingValue.text.toLowerCase();
                        return _lagerItems.where(
                          (l) => l.name.toLowerCase().contains(q),
                        );
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                            _autoCompleteControllers[i] = controller;
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Material ${i + 1}',
                                isDense: true,
                                prefixIcon: const Icon(
                                  Icons.inventory_2,
                                  size: 20,
                                ),
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
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                                maxWidth: 350,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final l = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(l.name),
                                    subtitle: l.dboNr != null
                                        ? Text(
                                            l.dboNr!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          )
                                        : null,
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
              width: 105,
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
      ),
    );
  }

  Widget _buildBetriebField() {
    final betriebe = ref
        .watch(betriebeProvider)
        .where((b) => b.serverId != null)
        .toList();

    final currentName = _betriebId != null
        ? betriebe
              .where((b) => b.serverId == _betriebId)
              .map((b) => b.name)
              .firstOrNull
        : null;

    if (_betriebDisabled) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Betrieb (nicht relevant)',
          prefixIcon: Icon(Icons.store),
        ),
        child: Text('—', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Autocomplete<BetriebLocal>(
      initialValue: currentName != null
          ? TextEditingValue(text: currentName)
          : TextEditingValue.empty,
      displayStringForOption: (b) => b.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return betriebe.take(20);
        final query = textEditingValue.text.toLowerCase();
        return betriebe.where(
          (b) =>
              b.name.toLowerCase().contains(query) ||
              (b.ort?.toLowerCase().contains(query) ?? false),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Betrieb suchen *',
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
          validator: (_) => _betriebId == null ? 'Betrieb auswählen' : null,
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
                    subtitle: b.ort != null
                        ? Text(b.ort!, style: const TextStyle(fontSize: 12))
                        : null,
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
          // Bergkunde automatisch aus Betrieb übernehmen
          _istBergkunde = b.istBergkunde;
        });
      },
    );
  }

  Widget _buildKostenPreview() {
    if (_isSpesen) {
      final betrag = double.tryParse(_betragController.text.trim());
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: betrag == null
            ? const Text(
                'Betrag eingeben für Kostenvorschau',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            : Column(
                children: [
                  _preisRow('Betrag', '${betrag.toStringAsFixed(2)} CHF'),
                  _preisRow(
                    'Stundensatz',
                    '${_stundensatz.toStringAsFixed(2)} CHF/h',
                  ),
                  _preisRow(
                    'Umrechnung',
                    '${(betrag / _stundensatz).toStringAsFixed(2)} h',
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Verrechnet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${betrag.toStringAsFixed(2)} CHF → ${(betrag / _stundensatz).toStringAsFixed(2)}h à ${_stundensatz.toStringAsFixed(2)} CHF/h',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      );
    }

    final stunden = double.tryParse(_stundenController.text.trim());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: stunden == null
          ? const Text(
              'Stunden eingeben für Kostenvorschau',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : Column(
              children: [
                _preisRow(
                  'Stundensatz',
                  '${_stundensatz.toStringAsFixed(2)} CHF/h',
                ),
                _preisRow('Stunden', '${stunden.toStringAsFixed(2)} h'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Arbeitskosten',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${(_stundensatz * stunden).toStringAsFixed(2)} CHF',
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

  Widget _preisRow(String label, String betrag) {
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
          Text(betrag, style: const TextStyle(fontSize: 13)),
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
