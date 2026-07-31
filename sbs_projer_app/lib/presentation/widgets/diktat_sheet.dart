import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/einsatz_betrieb_match.dart'
    show BetriebEintrag;
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/einsatz_diktat_ergebnis.dart';
import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einplanen_sheet.dart';
import 'package:sbs_projer_app/services/betrieb/betrieb_google_service.dart';
import 'package:sbs_projer_app/services/einsatz/einsatz_diktat_entwurf_speicher.dart';
import 'package:sbs_projer_app/services/einsatz/einsatz_diktat_service.dart';

/// Zeigt das Diktier-Sheet: freier Text (übers Mikrofon der Tastatur
/// eingesprochen) -> KI-Auswertung (`parse-einsatz`) -> Bestätigung. Nichts
/// wird je still gespeichert — Daniel sieht und bestätigt immer, was
/// gespeichert wird. Schlägt die Auswertung fehl (typischerweise: kein
/// Netz), geht der Rohtext NIE verloren, sondern landet als Entwurf in der
/// lokalen Warteschlange (siehe `einsatz_diktat_entwurf_speicher.dart`).
Future<void> zeigeDiktatSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DiktatSheet(),
  );
}

enum _View { diktieren, einsatz, neuerBetrieb }

const _artOptionen = [
  'stoerung',
  'montage',
  'eroeffnungsreinigung',
  'endreinigung',
  'aufgabe',
];

String _artLabel(String art) => switch (art) {
  'stoerung' => 'Störung',
  'montage' => 'Montage',
  'eroeffnungsreinigung' => 'Eröffnungsreinigung',
  'endreinigung' => 'Endreinigung',
  'aufgabe' => 'Aufgabe',
  _ => art,
};

IconData _artIcon(String art) => switch (art) {
  'stoerung' => Icons.warning_amber,
  'montage' => Icons.build,
  'eroeffnungsreinigung' => Icons.cleaning_services_outlined,
  'endreinigung' => Icons.cleaning_services,
  'aufgabe' => Icons.task_alt,
  _ => Icons.help_outline,
};

/// Zapfsysteme-Wert (siehe `betrieb_form_screen.dart`) für einen
/// `anlagen_typ` aus `parse-einsatz`. `null` = nichts Passendes erkannt.
String? _zapfsystemFuer(String anlagenTyp) => switch (anlagenTyp) {
  'heigenie' => 'Higenie',
  'david' => 'David',
  'konventionell' => 'Konventionell',
  'orion' => 'Orion',
  _ => null,
};

class DiktatSheet extends ConsumerStatefulWidget {
  const DiktatSheet({super.key});

  @override
  ConsumerState<DiktatSheet> createState() => _DiktatSheetState();
}

class _DiktatSheetState extends ConsumerState<DiktatSheet> {
  final _textCtrl = TextEditingController();
  final _beschreibungCtrl = TextEditingController();
  final _betriebNeuNameCtrl = TextEditingController();
  final _betriebNeuOrtCtrl = TextEditingController();

  _View _view = _View.diktieren;
  bool _loading = false;
  List<EinsatzDiktatEntwurf> _entwuerfe = const [];
  bool _entwuerfeOffen = false;
  String? _letzterText;

  // Einsatz-Bestätigung
  String _art = 'stoerung';
  String? _betriebId;
  String? _betriebName;
  List<EinsatzBetriebKandidat> _kandidaten = const [];
  String? _rueckfrage;
  double _konfidenz = 1;
  DateTime? _geplantTag;
  String? _geplantZeit;
  int? _geplantDauerMin;

  // Neuer Betrieb
  String? _anlagenTyp;
  bool _istMeinKunde = true;
  bool _googleLoading = false;
  GoogleBetriebDaten? _googleDaten;
  String? _googleFehler;

  @override
  void initState() {
    super.initState();
    _entwuerfeLaden();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _beschreibungCtrl.dispose();
    _betriebNeuNameCtrl.dispose();
    _betriebNeuOrtCtrl.dispose();
    super.dispose();
  }

  Future<void> _entwuerfeLaden() async {
    final liste = await EinsatzDiktatEntwurfSpeicher.laden();
    if (!mounted) return;
    setState(() => _entwuerfe = liste);
  }

  List<BetriebEintrag> get _betriebEintraege => ref
      .read(betriebeProvider)
      .where((b) => b.serverId != null)
      .map((b) => (id: b.serverId!, name: b.name, ort: b.ort ?? ''))
      .toList();

  // ─── Auswertung ───

  Future<void> _auswerten(String text, {String? entwurfId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ergebnis = await EinsatzDiktatService.parse(
        text: trimmed,
        betriebe: _betriebEintraege,
      );
      if (entwurfId != null) {
        await EinsatzDiktatEntwurfSpeicher.entfernen(entwurfId);
        await _entwuerfeLaden();
      }
      if (!mounted) return;
      _uebernehmen(trimmed, ergebnis);
    } catch (_) {
      if (entwurfId == null) {
        await EinsatzDiktatEntwurfSpeicher.hinzufuegen(trimmed);
        await _entwuerfeLaden();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _textCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kein Netz — Diktat gespeichert, wird später ausgewertet.',
          ),
        ),
      );
    }
  }

  String? _nameFuerBetrieb(String? id) {
    if (id == null) return null;
    for (final b in _betriebEintraege) {
      if (b.id == id) return b.name;
    }
    return null;
  }

  void _uebernehmen(String text, EinsatzDiktatErgebnis e) {
    setState(() {
      _loading = false;
      _textCtrl.clear();
      _letzterText = text;
      if (e.art == 'neuer_betrieb') {
        _view = _View.neuerBetrieb;
        _betriebNeuNameCtrl.text = e.betriebNeuName ?? '';
        _betriebNeuOrtCtrl.text = e.betriebNeuOrt ?? '';
        _anlagenTyp = e.anlagenTyp;
        _istMeinKunde = e.istMeinKunde ?? true;
        _googleDaten = null;
        _googleFehler = null;
      } else {
        _view = _View.einsatz;
        _art = _artOptionen.contains(e.art) ? e.art : 'aufgabe';
        _betriebId = e.betriebId;
        _betriebName = _nameFuerBetrieb(e.betriebId) ?? e.betriebNameErkannt;
        _kandidaten = e.betriebId == null ? e.betriebKandidaten : const [];
        _rueckfrage = e.rueckfrage;
        _konfidenz = e.konfidenz;
        _geplantTag = e.geplantAm;
        _geplantZeit = e.geplantZeit;
        _geplantDauerMin = e.geplantDauerMin;
        _beschreibungCtrl.text = e.beschreibung ?? '';
      }
    });
  }

  void _zurueckZumDiktieren() {
    setState(() {
      _view = _View.diktieren;
      if (_letzterText != null) _textCtrl.text = _letzterText!;
    });
  }

  // ─── Betrieb / Termin ───

  Future<void> _betriebWaehlen() async {
    final gewaehlt = await showModalBottomSheet<({String id, String name})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BetriebPickerSheet(betriebe: _betriebEintraege),
    );
    if (gewaehlt == null || !mounted) return;
    setState(() {
      _betriebId = gewaehlt.id;
      _betriebName = gewaehlt.name;
      _kandidaten = const [];
    });
  }

  void _kandidatWaehlen(EinsatzBetriebKandidat k) => setState(() {
    _betriebId = k.id;
    _betriebName = k.name;
    _kandidaten = const [];
  });

  Future<void> _terminBearbeiten() async {
    final ergebnis = await zeigeEinplanenSheet(
      context,
      titel: _artLabel(_art),
      untertitel: _betriebName,
      initialTag: _geplantTag,
      initialZeit: _geplantZeit,
      initialDauerMin: _geplantDauerMin,
    );
    if (ergebnis == null || !mounted) return;
    setState(() {
      _geplantTag = ergebnis.tag;
      _geplantZeit = ergebnis.zeit;
      _geplantDauerMin = ergebnis.dauerMin;
    });
  }

  void _terminLoeschen() => setState(() {
    _geplantTag = null;
    _geplantZeit = null;
    _geplantDauerMin = null;
  });

  // ─── Speichern: Einsatz ───

  bool get _zeigtBetrieb => _art != 'aufgabe';
  bool get _zeigtBeschreibung =>
      _art != 'eroeffnungsreinigung' && _art != 'endreinigung';

  Future<void> _einsatzSpeichern() async {
    setState(() => _loading = true);
    try {
      final beschreibung = _beschreibungCtrl.text.trim();
      switch (_art) {
        case 'stoerung':
          final s = StoerungLocal()
            ..serverId = const Uuid().v4()
            ..betriebId = _betriebId
            ..datum = _geplantTag ?? DateTime.now()
            ..problemBeschreibung = beschreibung
            ..status = 'offen';
          await StoerungRepository.save(s);
          if (_geplantTag != null) {
            await StoerungRepository.einplanen(
              id: s.routeId,
              tag: _geplantTag!,
              zeit: _geplantZeit,
              dauerMin: _geplantDauerMin,
            );
          }
          break;
        case 'montage':
          final m = MontageLocal()
            ..serverId = const Uuid().v4()
            ..betriebId = _betriebId
            ..montageTyp = 'neumontage'
            ..datum = _geplantTag ?? DateTime.now()
            ..beschreibung = beschreibung
            ..status = 'geplant';
          await MontageRepository.save(m);
          if (_geplantTag != null) {
            await MontageRepository.einplanen(
              id: m.routeId,
              tag: _geplantTag!,
              zeit: _geplantZeit,
              dauerMin: _geplantDauerMin,
            );
          }
          break;
        case 'eroeffnungsreinigung':
        case 'endreinigung':
          final er = EroeffnungsreinigungLocal()
            ..serverId = const Uuid().v4()
            ..betriebId = _betriebId
            ..art = _art == 'endreinigung' ? 'endreinigung' : 'eroeffnung'
            ..datum = _geplantTag ?? DateTime.now();
          await EroeffnungsreinigungRepository.save(er);
          break;
        case 'aufgabe':
        default:
          await AufgabenRepository.eigeneAnlegen(
            beschreibung.isEmpty ? 'Aufgabe (Diktat)' : beschreibung,
            _geplantTag,
          );
          break;
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${_artLabel(_art)} gespeichert.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    }
  }

  // ─── Speichern: Neuer Betrieb ───

  Future<void> _googleHolen() async {
    final name = _betriebNeuNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Namen eingeben.')),
      );
      return;
    }
    final ort = _betriebNeuOrtCtrl.text.trim();
    final query = ort.isEmpty ? name : '$name $ort';
    setState(() {
      _googleLoading = true;
      _googleFehler = null;
    });
    try {
      final daten = await BetriebGoogleService.lookup(query);
      if (!mounted) return;
      setState(() {
        _googleDaten = daten;
        _googleLoading = false;
      });
    } on BetriebGoogleException catch (e) {
      if (!mounted) return;
      setState(() {
        _googleFehler = e.message;
        _googleLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _googleFehler = 'Google-Abgleich fehlgeschlagen: $e';
        _googleLoading = false;
      });
    }
  }

  Future<void> _betriebSpeichern() async {
    final name = _betriebNeuNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Namen eingeben.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final b = BetriebLocal()
        ..name = name
        ..ort = _betriebNeuOrtCtrl.text.trim().isEmpty
            ? null
            : _betriebNeuOrtCtrl.text.trim()
        ..istMeinKunde = _istMeinKunde;
      final anlagenTyp = _anlagenTyp;
      if (anlagenTyp != null) {
        final zapf = _zapfsystemFuer(anlagenTyp);
        if (zapf != null) b.zapfsysteme = [zapf];
      }
      final g = _googleDaten;
      if (g != null) {
        if (g.strasse != null) b.strasse = g.strasse;
        if (g.nr != null) b.nr = g.nr;
        if (g.plz != null) b.plz = g.plz;
        if (g.ort != null) b.ort = g.ort;
        if (g.telefon != null) b.telefon = g.telefon;
        if (g.website != null) b.website = g.website;
        if (g.latitude != null) b.latitude = g.latitude;
        if (g.longitude != null) b.longitude = g.longitude;
      }
      await BetriebRepository.save(b);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Betrieb "$name" angelegt.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    }
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (_view) {
                _View.diktieren => _diktierenAnsicht(),
                _View.einsatz => _einsatzAnsicht(),
                _View.neuerBetrieb => _neuerBetriebAnsicht(),
              },
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String titel, {VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_back, size: 20),
              ),
            ),
          Expanded(
            child: Text(
              titel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ansicht: Diktieren ───

  Widget _diktierenAnsicht() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Diktieren'),
        if (_entwuerfe.isNotEmpty) _entwuerfeBanner(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Antippen und über das Mikrofon der Tastatur einsprechen, z.B.\n'
            '«Morgen 14 Uhr Störung beim Sunset, Zapfhahn tropft»\n'
            '«Neuer Betrieb Adler in Chur, Heigenie, mein Kunde»',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _textCtrl,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Diktat hier einsprechen …',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PrimaryButton(
            label: 'Auswerten',
            icon: Icons.auto_awesome,
            loading: _loading,
            enabled: _textCtrl.text.trim().isNotEmpty,
            onTap: () => _auswerten(_textCtrl.text),
          ),
        ),
      ],
    );
  }

  Widget _entwuerfeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _entwuerfeOffen = !_entwuerfeOffen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _entwuerfe.length == 1
                          ? '1 Diktat wartet'
                          : '${_entwuerfe.length} Diktate warten',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _entwuerfeOffen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_entwuerfeOffen) ...[
            for (final e in _entwuerfe) _entwurfZeile(e),
          ],
        ],
      ),
    );
  }

  Widget _entwurfZeile(EinsatzDiktatEntwurf e) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              e.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: _loading ? null : () => _auswerten(e.text, entwurfId: e.id),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.refresh, size: 18, color: AppColors.primary),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await EinsatzDiktatEntwurfSpeicher.entfernen(e.id);
              await _entwuerfeLaden();
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ansicht: Einsatz bestätigen ───

  Widget _einsatzAnsicht() {
    final df = DateFormat('EE, dd.MM.yyyy', 'de_CH');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Einsatz bestätigen', onBack: _zurueckZumDiktieren),
        if (_rueckfrage != null)
          _hinweisBox(_rueckfrage!, icon: Icons.help_outline),
        if (_konfidenz > 0 && _konfidenz < 0.7)
          _hinweisBox(
            'Unsichere Erkennung — bitte genau prüfen.',
            icon: Icons.warning_amber,
          ),

        const _SheetTitel('Art'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _artOptionen)
                _Wahlchip(
                  text: _artLabel(a),
                  icon: _artIcon(a),
                  ausgewaehlt: _art == a,
                  onTap: () => setState(() => _art = a),
                ),
            ],
          ),
        ),

        if (_zeigtBetrieb) ...[
          const _SheetTitel('Betrieb'),
          if (_kandidaten.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in _kandidaten)
                    _Wahlchip(
                      text: k.name,
                      ausgewaehlt: _betriebId == k.id,
                      onTap: () => _kandidatWaehlen(k),
                    ),
                ],
              ),
            ),
          _SheetAktion(
            icon: Icons.store,
            text: _betriebName ?? 'Betrieb wählen …',
            onTap: _betriebWaehlen,
          ),
        ],

        const _SheetTitel('Termin'),
        if (_geplantTag == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _Wahlchip(
              text: 'Termin festlegen',
              icon: Icons.event,
              ausgewaehlt: false,
              onTap: _terminBearbeiten,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _terminBearbeiten,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      [
                        df.format(_geplantTag!),
                        if (_geplantZeit != null) '${_geplantZeit!} Uhr',
                        if (_geplantDauerMin != null)
                          '${_geplantDauerMin!} min',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _terminLoeschen,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_geplantTag == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Kein Termin — wird als offener Eintrag angelegt.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),

        if (_zeigtBeschreibung) ...[
          const _SheetTitel('Beschreibung'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _beschreibungCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'z.B. Zapfhahn tropft',
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PrimaryButton(
            label: _geplantTag != null ? 'Einplanen' : 'Speichern',
            icon: Icons.check,
            loading: _loading,
            enabled: true,
            onTap: _einsatzSpeichern,
          ),
        ),
      ],
    );
  }

  Widget _hinweisBox(String text, {required IconData icon}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ─── Ansicht: Neuer Betrieb ───

  Widget _neuerBetriebAnsicht() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Neuer Betrieb bestätigen', onBack: _zurueckZumDiktieren),

        const _SheetTitel('Name'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _betriebNeuNameCtrl,
            decoration: const InputDecoration(hintText: 'Betriebsname'),
          ),
        ),

        const _SheetTitel('Ort'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _betriebNeuOrtCtrl,
            decoration: const InputDecoration(hintText: 'z.B. Chur'),
          ),
        ),

        const _SheetTitel('Anlagentyp'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const [
                'david',
                'konventionell',
                'heigenie',
                'orion',
              ])
                _Wahlchip(
                  text: _zapfsystemFuer(t) ?? t,
                  ausgewaehlt: _anlagenTyp == t,
                  onTap: () =>
                      setState(() => _anlagenTyp = _anlagenTyp == t ? null : t),
                ),
            ],
          ),
        ),

        const _SheetTitel('Kunde'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _Wahlchip(
                  text: 'Mein Kunde',
                  ausgewaehlt: _istMeinKunde,
                  onTap: () => setState(() => _istMeinKunde = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Wahlchip(
                  text: 'Heineken-Kunde',
                  ausgewaehlt: !_istMeinKunde,
                  onTap: () => setState(() => _istMeinKunde = false),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PrimaryButton(
            label: 'Daten von Google holen',
            icon: Icons.travel_explore,
            loading: _googleLoading,
            enabled: true,
            sekundaer: true,
            onTap: _googleHolen,
          ),
        ),
        if (_googleFehler != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _googleFehler!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        if (_googleDaten != null) _googleVorschau(_googleDaten!),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PrimaryButton(
            label: 'Betrieb anlegen',
            icon: Icons.check,
            loading: _loading,
            enabled: true,
            onTap: _betriebSpeichern,
          ),
        ),
      ],
    );
  }

  Widget _googleVorschau(GoogleBetriebDaten d) {
    final adresse = [
      [d.strasse, d.nr].where((s) => s != null && s.isNotEmpty).join(' '),
      [d.plz, d.ort].where((s) => s != null && s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');
    final zeilen = <String>[
      if (adresse.isNotEmpty) adresse,
      if (d.telefon != null) d.telefon!,
      if (d.website != null) d.website!,
      if (d.latitude != null && d.longitude != null)
        '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Von Google übernommen:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (zeilen.isEmpty)
            const Text(
              'Keine zusätzlichen Daten gefunden.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            ...zeilen.map((z) => Text(z, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

// ─── Betrieb-Auswahl (Suche + Liste) ───

class _BetriebPickerSheet extends StatefulWidget {
  final List<BetriebEintrag> betriebe;
  const _BetriebPickerSheet({required this.betriebe});

  @override
  State<_BetriebPickerSheet> createState() => _BetriebPickerSheetState();
}

class _BetriebPickerSheetState extends State<_BetriebPickerSheet> {
  String _suche = '';

  @override
  Widget build(BuildContext context) {
    final s = _suche.trim().toLowerCase();
    final gefiltert = s.isEmpty
        ? widget.betriebe
        : widget.betriebe
              .where(
                (b) =>
                    b.name.toLowerCase().contains(s) ||
                    b.ort.toLowerCase().contains(s),
              )
              .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Betrieb wählen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Suchen …',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _suche = v),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: gefiltert.isEmpty
                    ? const Center(
                        child: Text(
                          'Kein Treffer',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: gefiltert.length,
                        itemBuilder: (context, i) {
                          final b = gefiltert[i];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.pop(context, (
                              id: b.id,
                              name: b.name,
                            )),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (b.ort.isNotEmpty)
                                    Text(
                                      b.ort,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bausteine (gleicher Stil wie einplanen_sheet.dart / ferien_frage_sheet.dart
// — CanvasKit-Regel: kein ElevatedButton/TextButton in Bottom-Sheets) ───

class _SheetTitel extends StatelessWidget {
  final String text;
  const _SheetTitel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SheetAktion extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SheetAktion({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _Wahlchip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  const _Wahlchip({
    required this.text,
    this.icon,
    required this.ausgewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ausgewaehlt
              ? AppColors.primary
              : AppColors.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ausgewaehlt
                ? AppColors.primary
                : AppColors.primary.withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: ausgewaehlt ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ausgewaehlt ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grosser primärer CTA-Knopf im Sheet-Stil (kein ElevatedButton/FilledButton
/// — CanvasKit-Regel). [sekundaer] = heller Umriss-Stil statt vollflächig.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final bool sekundaer;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    this.sekundaer = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aktiv = enabled && !loading;
    return GestureDetector(
      onTap: aktiv ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sekundaer
              ? AppColors.primary.withAlpha(18)
              : (aktiv ? AppColors.primary : AppColors.divider),
          borderRadius: BorderRadius.circular(10),
          border: sekundaer
              ? Border.all(color: AppColors.primary.withAlpha(60))
              : null,
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: sekundaer
                        ? AppColors.primary
                        : (aktiv ? Colors.white : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: sekundaer
                          ? AppColors.primary
                          : (aktiv ? Colors.white : AppColors.textSecondary),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
