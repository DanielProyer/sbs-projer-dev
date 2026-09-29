import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_betrag.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/dokument_scan_ergebnis.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/dokumente/dokument_scan_service.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Woher eine Datei kommt.
enum DokumentQuelle { pdf, galerie, kamera }

/// Eine gewählte Datei.
typedef DokumentDatei = ({Uint8List bytes, String name, String mime});

/// Dateiauswahl — austauschbar, damit Widget-Tests eine Datei einspeisen.
typedef DokumentDateiWaehler =
    Future<DokumentDatei?> Function(DokumentQuelle quelle);

/// Upload — austauschbar, damit Widget-Tests ohne Supabase prüfen können,
/// was hochgeladen würde. Signatur wie [DokumentRepository.upload].
typedef DokumentHochlader =
    Future<Dokument> Function({
      required String bereich,
      required String typ,
      String? kategorie,
      int? jahr,
      DateTime? dokumentDatum,
      double? betrag,
      String? referenz,
      required String titel,
      String? notizen,
      required String dateiname,
      required String dateityp,
      required Uint8List bytes,
      String? buchungId,
    });

/// Rückgabe: das angelegte Dokument oder null (abgebrochen).
///
/// Nach der Dateiauswahl ordnet [erkenner] das Dokument ein (Edge Function
/// `parse-dokument`, seit 29.09.2026) und füllt die Felder vor, die Daniel
/// noch nicht von Hand gesetzt hat. Schlägt die Erkennung fehl, bleibt alles
/// wie vorher: Felder von Hand, Upload wie gehabt.
Future<Dokument?> showDokumentUploadDialog(
  BuildContext context, {
  required String bereich,
  bool bereichFix = true,
  int? jahr,
  List<Buchung> buchungen = const [],
  DokumentErkenner erkenner = DokumentScanService.erkennen,
  @visibleForTesting DokumentDateiWaehler dateiWaehler = _dateiWaehlen,
  @visibleForTesting DokumentHochlader hochlader = DokumentRepository.upload,
}) => showDialog<Dokument>(
  context: context,
  builder: (_) => _UploadDialog(
    bereich: bereich,
    bereichFix: bereichFix,
    jahr: jahr,
    buchungen: buchungen,
    erkenner: erkenner,
    dateiWaehler: dateiWaehler,
    hochlader: hochlader,
  ),
);

Future<DokumentDatei?> _dateiWaehlen(DokumentQuelle quelle) async {
  if (quelle == DokumentQuelle.pdf) {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final f = r?.files.single;
    if (f?.bytes == null) return null;
    return (bytes: f!.bytes!, name: f.name, mime: 'application/pdf');
  }
  final x = await ImagePicker().pickImage(
    source: quelle == DokumentQuelle.kamera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 2000,
    imageQuality: 85,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  // mimeType liefert der Picker nicht auf allen Plattformen — dann
  // entscheidet die Endung.
  final mime =
      x.mimeType ??
      (x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  return (bytes: bytes, name: x.name, mime: mime);
}

/// Dropdown-Wert für einen frei eingetippten Dokumenttyp.
const _typAnderer = '__anderer__';

/// Felder, die Daniel von Hand setzen kann — die Erkennung lässt sie dann
/// in Ruhe.
enum _Feld {
  bereich,
  typ,
  kategorie,
  jahr,
  datum,
  betrag,
  referenz,
  titel,
  dateiname,
  notizen,
}

enum _Erkennung { aus, laeuft, erkannt, nichtErkannt, nichtMoeglich }

class _UploadDialog extends StatefulWidget {
  final String bereich;
  final bool bereichFix;
  final int? jahr;
  final List<Buchung> buchungen;
  final DokumentErkenner erkenner;
  final DokumentDateiWaehler dateiWaehler;
  final DokumentHochlader hochlader;

  const _UploadDialog({
    required this.bereich,
    required this.bereichFix,
    this.jahr,
    required this.buchungen,
    required this.erkenner,
    required this.dateiWaehler,
    required this.hochlader,
  });

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late String _bereich = widget.bereich;
  late String _typ = dokumentTypen(widget.bereich).first;
  String? _kategorie;
  late final _jahr = TextEditingController(text: widget.jahr?.toString() ?? '');
  final _typFrei = TextEditingController();
  final _kategorieFrei = TextEditingController();
  final _titel = TextEditingController();
  final _dateinameFeld = TextEditingController();
  final _betrag = TextEditingController();
  final _referenz = TextEditingController();
  final _notizen = TextEditingController();
  DateTime? _datum;
  String? _buchungId;
  Uint8List? _bytes;
  String? _dateiname;
  String? _dateityp;
  bool _laeuft = false;

  final _vonHand = <_Feld>{};
  var _erkennung = _Erkennung.aus;
  DokumentScanErgebnis? _erkannt;

  /// Zähler der Erkennungsläufe: eine Antwort, die nach einem neueren Lauf
  /// (andere Datei, «Erneut erkennen») oder nach «Speichern» eintrifft,
  /// wird verworfen.
  int _lauf = 0;

  static const _maxBytes = 20 * 1024 * 1024; // Bucket-Limit

  @override
  void dispose() {
    _jahr.dispose();
    _typFrei.dispose();
    _kategorieFrei.dispose();
    _titel.dispose();
    _dateinameFeld.dispose();
    _betrag.dispose();
    _referenz.dispose();
    _notizen.dispose();
    super.dispose();
  }

  void _meldung(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _vonHandGesetzt(_Feld f) => _vonHand.add(f);

  Future<void> _waehlen(DokumentQuelle quelle) async {
    final d = await widget.dateiWaehler(quelle);
    if (d == null || !mounted) return;
    _uebernehmen(d.bytes, d.name, d.mime);
  }

  void _uebernehmen(Uint8List bytes, String name, String mime) {
    if (bytes.isEmpty) {
      _meldung('Datei ist leer.');
      return;
    }
    if (bytes.length > _maxBytes) {
      _meldung('Datei grösser als 20 MB.');
      return;
    }
    setState(() {
      _bytes = bytes;
      _dateiname = name;
      _dateityp = mime;
      // Was die Erkennung der vorigen Datei eingetragen hat, gilt für diese
      // nicht mehr.
      _erkannt = null;
      _vorgabenSetzen();
    });
    _erkennen();
  }

  /// Alle Felder, die NICHT von Hand gesetzt sind, auf die Vorgabe ohne
  /// Erkennung: Bereich/Jahr des Aufrufers, Titel und Dateiname aus dem
  /// Dateinamen, der Rest leer.
  void _vorgabenSetzen() {
    final bereichFrei =
        !_vonHand.contains(_Feld.bereich) &&
        !_vonHand.contains(_Feld.typ) &&
        !_vonHand.contains(_Feld.kategorie);
    if (bereichFrei && _bereich != widget.bereich) {
      _bereich = widget.bereich;
      _buchungId = null;
    }
    if (!_vonHand.contains(_Feld.typ)) {
      _typ = dokumentTypen(_bereich).first;
      _typFrei.clear();
    }
    if (!_vonHand.contains(_Feld.kategorie)) {
      _kategorie = null;
      _kategorieFrei.clear();
    }
    if (!_vonHand.contains(_Feld.jahr)) {
      _jahr.text = widget.jahr?.toString() ?? '';
    }
    if (!_vonHand.contains(_Feld.datum)) _datum = null;
    if (!_vonHand.contains(_Feld.betrag)) _betrag.clear();
    if (!_vonHand.contains(_Feld.referenz)) _referenz.clear();
    if (!_vonHand.contains(_Feld.notizen)) _notizen.clear();
    final name = _dateiname ?? '';
    if (!_vonHand.contains(_Feld.titel)) {
      _titel.text = name.replaceAll(
        RegExp(r'\.(pdf|jpe?g|png)$', caseSensitive: false),
        '',
      );
    }
    if (!_vonHand.contains(_Feld.dateiname)) _dateinameFeld.text = name;
  }

  Future<void> _erkennen() async {
    final bytes = _bytes;
    final mime = _dateityp;
    if (bytes == null || mime == null || _laeuft) return;
    final lauf = ++_lauf;
    if (!DokumentScanService.erkennbar(mime, bytes.length)) {
      setState(() => _erkennung = _Erkennung.nichtMoeglich);
      return;
    }
    setState(() => _erkennung = _Erkennung.laeuft);
    DokumentScanErgebnis? e;
    try {
      e = await widget.erkenner(
        bytes: bytes,
        mediaType: mime,
        bereichVorgabe: _vonHand.contains(_Feld.bereich)
            ? _bereich
            : widget.bereich,
      );
    } catch (err) {
      // Der echte Erkenner wirft nie; ein Fehler hier darf den Upload
      // trotzdem nicht aufhalten.
      debugPrint('Dokument-Erkennung: $err');
    }
    if (!mounted || lauf != _lauf || _laeuft) return;
    setState(() {
      _erkannt = e;
      _erkennung = e == null ? _Erkennung.nichtErkannt : _Erkennung.erkannt;
      if (e != null) {
        _vorgabenSetzen();
        _anwenden(e);
      }
    });
  }

  /// Erkennung in die Felder übernehmen — nur in Felder, die Daniel nicht
  /// von Hand gesetzt hat, und nur Werte aus den Listen dieses Dialogs.
  void _anwenden(DokumentScanErgebnis e) {
    final bereich = e.bereich;
    if (bereich != null &&
        bereich != _bereich &&
        dokumentBereiche.containsKey(bereich) &&
        !widget.bereichFix &&
        !_vonHand.contains(_Feld.bereich) &&
        !_vonHand.contains(_Feld.typ) &&
        !_vonHand.contains(_Feld.kategorie)) {
      _bereich = bereich;
      _typ = dokumentTypen(bereich).first;
      _buchungId = null;
    }
    if (!_vonHand.contains(_Feld.typ) && e.typ != null) {
      final typen = dokumentTypen(_bereich);
      if (typen.contains(e.typ)) {
        _typ = e.typ!;
      } else if (typen.contains('sonstiges')) {
        // Erkannt, aber in diesem Bereich nicht vorgesehen: lieber
        // «Sonstiges» als der erste Listeneintrag (sähe nach Erkennung aus).
        _typ = 'sonstiges';
      }
    }
    if (!_vonHand.contains(_Feld.kategorie) &&
        (dokumentKategorien(_bereich)?.containsKey(e.kategorie) ?? false)) {
      _kategorie = e.kategorie;
    }
    if (!_vonHand.contains(_Feld.jahr) && e.jahr != null) {
      _jahr.text = '${e.jahr}';
    }
    if (!_vonHand.contains(_Feld.datum) && e.dokumentDatum != null) {
      _datum = e.dokumentDatum;
    }
    if (!_vonHand.contains(_Feld.betrag) && e.betrag != null) {
      _betrag.text = e.betrag!.toStringAsFixed(2);
    }
    if (!_vonHand.contains(_Feld.referenz) && e.referenz != null) {
      _referenz.text = e.referenz!;
    }
    if (!_vonHand.contains(_Feld.titel) && e.titel != null) {
      _titel.text = e.titel!;
    }
    if (!_vonHand.contains(_Feld.dateiname) && e.dateiname != null) {
      _dateinameFeld.text = dokumentDateiname(
        e.dateiname!,
        original: _dateiname ?? '',
        mime: _dateityp!,
      );
    }
    if (!_vonHand.contains(_Feld.notizen)) {
      if (e.zinsausweisNotiz() case final notiz?) _notizen.text = notiz;
    }
  }

  /// Erkannter Bereich weicht vom eingestellten ab (Bereich fest oder von
  /// Hand gewählt) — Daniel soll es sehen, bevor er speichert.
  String? get _bereichHinweis {
    final b = _erkannt?.bereich;
    if (b == null || b == _bereich || !dokumentBereiche.containsKey(b)) {
      return null;
    }
    return 'Erkannt als «${dokumentBereiche[b]}» — Bereich hier: '
        '«${dokumentBereiche[_bereich] ?? _bereich}»';
  }

  /// Die Erkennung hat das vom Aufrufer vorgegebene Jahr ersetzt — dann
  /// landet das Dokument nicht im Jahr, aus dem hochgeladen wurde.
  String? get _jahrHinweis {
    final j = _erkannt?.jahr;
    final vorgabe = widget.jahr;
    if (j == null || vorgabe == null || j == vorgabe) return null;
    if (_jahr.text != '$j') return null;
    return 'Jahr $j erkannt (Vorgabe war $vorgabe)';
  }

  bool get _bereit => _bytes != null && _titel.text.trim().isNotEmpty;

  Future<void> _speichern() async {
    if (_bytes == null) return;
    if (_titel.text.trim().isEmpty) {
      _meldung('Titel ist Pflicht');
      return;
    }
    // Freier Typ: kleingeschrieben, Leerzeichen zu _ (z. B. police_haftpflicht).
    var typ = _typ;
    if (typ == _typAnderer) {
      typ = _typFrei.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      if (typ.isEmpty) {
        _meldung('Typ fehlt');
        return;
      }
    }
    // Ein Tippfehler im Betrag darf nicht still als «kein Betrag» durchgehen.
    final betragRoh = _betrag.text.trim();
    final betrag = chfBetragParsen(betragRoh);
    if (betragRoh.isNotEmpty && betrag == null) {
      _meldung('Betrag ungültig');
      return;
    }
    // Eine noch laufende Erkennung darf die Felder jetzt nicht mehr ändern.
    _lauf++;
    setState(() => _laeuft = true);
    try {
      final d = await widget.hochlader(
        bereich: _bereich,
        typ: typ,
        kategorie: _kategorie,
        jahr: int.tryParse(_jahr.text),
        dokumentDatum: _datum,
        betrag: betrag,
        referenz: _referenz.text.trim().isEmpty ? null : _referenz.text.trim(),
        titel: _titel.text.trim(),
        notizen: _notizen.text.trim().isEmpty ? null : _notizen.text.trim(),
        dateiname: dokumentDateiname(
          _dateinameFeld.text,
          original: _dateiname!,
          mime: _dateityp!,
        ),
        dateityp: _dateityp!,
        bytes: _bytes!,
        buchungId: _buchungId,
      );
      if (mounted) Navigator.pop(context, d);
    } catch (e) {
      if (mounted) {
        setState(() {
          _laeuft = false;
          if (_erkennung == _Erkennung.laeuft) {
            _erkennung = _Erkennung.nichtErkannt;
          }
        });
        _meldung('Upload fehlgeschlagen: $e');
      }
    }
  }

  void _bereichWechseln(String neu) => setState(() {
    _vonHandGesetzt(_Feld.bereich);
    // Typ und Kategorie hängen am Bereich — was dort von Hand stand, gilt
    // im neuen Bereich nicht mehr.
    _vonHand.removeAll({_Feld.typ, _Feld.kategorie});
    _bereich = neu;
    _typ = dokumentTypen(neu).first;
    _typFrei.clear();
    _kategorie = null;
    _kategorieFrei.clear();
    // Passt der erkannte Typ auch in den neuen Bereich (Zinsausweis unter
    // Bank oder Steuern), bleibt er stehen.
    final e = _erkannt;
    if (e?.typ != null && dokumentTypen(neu).contains(e!.typ)) _typ = e.typ!;
    if (dokumentKategorien(neu)?.containsKey(e?.kategorie) ?? false) {
      _kategorie = e!.kategorie;
    }
    // Zahlungen werden nur im Steuer-Bereich verknüpft — sonst bliebe eine
    // Buchung hängen, die im neuen Bereich gar nicht mehr angeboten wird.
    _buchungId = null;
  });

  Widget _grau(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
    ),
  );

  List<Widget> _erkennungsZeilen() {
    final e = _erkannt;
    return [
      switch (_erkennung) {
        _Erkennung.aus => const SizedBox.shrink(),
        _Erkennung.laeuft => const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wird erkannt …',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        _Erkennung.erkannt => _grau(
          'Erkannt (Zuversicht ${((e?.zuversicht ?? 0) * 100).round()} %) '
          '— bitte prüfen',
        ),
        _Erkennung.nichtErkannt => _grau('Nicht erkannt — Felder von Hand'),
        _Erkennung.nichtMoeglich => _grau(
          'Keine Erkennung (nur PDF, JPG, PNG bis 15 MB) — Felder von Hand',
        ),
      },
      if (_erkennung == _Erkennung.erkannt && e?.hinweis != null)
        _grau(e!.hinweis!),
      if (_bereichHinweis case final h?) _grau(h),
      if (_jahrHinweis case final h?) _grau(h),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final zeigeBuchungen = _bereich == 'steuern' && widget.buchungen.isNotEmpty;
    return PopScope(
      canPop: !_laeuft,
      child: AlertDialog(
        title: const Text('Dokument hochladen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Datei zuerst: die Erkennung füllt danach die Felder darunter.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TapKnopf(
                    text: 'PDF',
                    icon: Icons.picture_as_pdf,
                    primaer: false,
                    onTap: _laeuft ? null : () => _waehlen(DokumentQuelle.pdf),
                  ),
                  TapKnopf(
                    text: 'Galerie',
                    icon: Icons.photo,
                    primaer: false,
                    onTap: _laeuft
                        ? null
                        : () => _waehlen(DokumentQuelle.galerie),
                  ),
                  TapKnopf(
                    text: 'Kamera',
                    icon: Icons.camera_alt,
                    primaer: false,
                    onTap: _laeuft
                        ? null
                        : () => _waehlen(DokumentQuelle.kamera),
                  ),
                ],
              ),
              if (_dateiname != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Datei: $_dateiname'),
                ),
              ..._erkennungsZeilen(),
              if (_bytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TapKnopf(
                    text: 'Erneut erkennen',
                    icon: Icons.refresh,
                    primaer: false,
                    laeuft: _erkennung == _Erkennung.laeuft,
                    onTap: _laeuft ? null : _erkennen,
                  ),
                ),
              if (!widget.bereichFix)
                DropdownButtonFormField<String>(
                  initialValue: _bereich,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bereich'),
                  items: [
                    for (final e in dokumentBereiche.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => _bereichWechseln(v!),
                ),
              DropdownButtonFormField<String>(
                initialValue: _typ,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Typ'),
                items: [
                  for (final t in dokumentTypen(_bereich))
                    DropdownMenuItem(
                      value: t,
                      child: Text(dokumentTypLabel(t)),
                    ),
                  const DropdownMenuItem(
                    value: _typAnderer,
                    child: Text('Anderer…'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _vonHandGesetzt(_Feld.typ);
                  _typ = v!;
                }),
              ),
              if (_typ == _typAnderer)
                TextField(
                  controller: _typFrei,
                  decoration: const InputDecoration(labelText: 'Typ (frei)'),
                ),
              // Bereiche mit fester Kategorienliste (Steuern, Versicherungen)
              // bekommen ein Dropdown, alle anderen ein Freitextfeld.
              if (dokumentKategorien(_bereich) case final kategorien?)
                DropdownButtonFormField<String?>(
                  initialValue: _kategorie,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _bereich == 'steuern' ? 'Steuerart' : 'Kategorie',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final e in kategorien.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() {
                    _vonHandGesetzt(_Feld.kategorie);
                    _kategorie = v;
                  }),
                )
              else
                TextField(
                  controller: _kategorieFrei,
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                  onChanged: (v) {
                    _vonHandGesetzt(_Feld.kategorie);
                    _kategorie = v.trim().isEmpty ? null : v.trim();
                  },
                ),
              TextField(
                controller: _jahr,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Jahr',
                  counterText: '',
                ),
                // Auch der Jahr-Hinweis hängt am Feldinhalt.
                onChanged: (_) => setState(() => _vonHandGesetzt(_Feld.jahr)),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Datum: ${_datum == null ? '—' : df.format(_datum!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final p = await zeigeDatumsauswahl(
                        context,
                        initial: _datum ?? DateTime.now(),
                        erstes: DateTime(2015),
                        letztes: DateTime(2035),
                      );
                      if (p != null && mounted) {
                        setState(() {
                          _vonHandGesetzt(_Feld.datum);
                          _datum = p;
                        });
                      }
                    },
                    child: const Text('wählen'),
                  ),
                ],
              ),
              TextField(
                controller: _betrag,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Betrag CHF (Guthaben negativ)',
                ),
                onChanged: (_) => _vonHandGesetzt(_Feld.betrag),
              ),
              TextField(
                controller: _referenz,
                decoration: const InputDecoration(
                  labelText: 'Referenz / Rechnungs-Nr.',
                ),
                onChanged: (_) => _vonHandGesetzt(_Feld.referenz),
              ),
              TextField(
                controller: _titel,
                decoration: const InputDecoration(labelText: 'Titel *'),
                // Gibt den Speichern-Knopf frei, sobald ein Titel dasteht.
                onChanged: (_) => setState(() => _vonHandGesetzt(_Feld.titel)),
              ),
              TextField(
                controller: _dateinameFeld,
                decoration: const InputDecoration(
                  labelText: 'Dateiname',
                  helperText: 'Endung wird beim Speichern ergänzt',
                ),
                onChanged: (_) => _vonHandGesetzt(_Feld.dateiname),
              ),
              TextField(
                controller: _notizen,
                decoration: const InputDecoration(labelText: 'Notizen'),
                maxLines: 2,
                onChanged: (_) => _vonHandGesetzt(_Feld.notizen),
              ),
              if (zeigeBuchungen)
                DropdownButtonFormField<String?>(
                  initialValue: _buchungId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Zahlung verknüpfen',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final b in widget.buchungen)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${df.format(b.datum)} '
                          '${b.betragBrutto.toStringAsFixed(2)} '
                          '${b.beschreibung}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _buchungId = v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _laeuft ? null : () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(
            text: 'Speichern',
            laeuft: _laeuft,
            onTap: _bereit ? _speichern : null,
          ),
        ],
      ),
    );
  }
}
