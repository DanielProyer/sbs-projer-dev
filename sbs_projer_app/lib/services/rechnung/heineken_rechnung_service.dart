import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/models/heineken_monats_daten.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/services/pdf/heineken_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class HeinekenRechnungService {
  // Defaults als Fallback, werden dynamisch aus Preisen geladen
  static double _anfahrtPauschale = 180.0;
  static double _mwstSatz = 0.081;
  static String _heinekenPoNummer = '6100259429';
  static String _mwstLabel = '8.1%';

  static Future<Preis?> _loadPreise({DateTime? datum}) async {
    final preis = await PreisRepository.getAktuell(datum: datum);
    if (preis != null) {
      _mwstSatz = preis.mwstFaktor;
      _anfahrtPauschale = preis.bergkundenZuschlag;
      _heinekenPoNummer = preis.heinekenPoNummer ?? '6100259429';
      _mwstLabel = preis.mwstLabel;
    }
    return preis;
  }

  static String get _userId => SupabaseService.dataUserId;

  /// Sammelt alle Heineken-relevanten Daten für den gegebenen Monat.
  static Future<HeinekenMonatsDaten> sammleMonatsDaten(DateTime monat) async {
    // Preise für den Monat laden
    await _loadPreise(datum: monat);
    final start = DateTime(monat.year, monat.month, 1);
    final end = DateTime(monat.year, monat.month + 1, 1);
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;

    // Alle Daten parallel laden
    final results = await Future.wait([
      _queryTable('stoerungen', 'datum', startStr, endStr),
      _queryTable('eigenauftraege', 'datum', startStr, endStr),
      _queryTable('eroeffnungsreinigungen', 'datum', startStr, endStr),
      _queryTable('montagen', 'datum', startStr, endStr),
      _queryTable('pikett_dienste', 'datum_start', startStr, endStr),
      _queryReinigungen(startStr, endStr),
      _queryTable('bergkundenpauschalen', 'datum', startStr, endStr),
    ]);

    final stoerungsRows = results[0] as List<Map<String, dynamic>>;
    final eigenauftragRows = results[1] as List<Map<String, dynamic>>;
    final eroeffnungRows = results[2] as List<Map<String, dynamic>>;
    final montageRows = results[3] as List<Map<String, dynamic>>;
    final pikettRows = results[4] as List<Map<String, dynamic>>;
    final reinigungData = results[5] as Map<String, List<Map<String, dynamic>>>;
    final bergkundenRows = results[6] as List<Map<String, dynamic>>;

    // Betrieb-Namen laden
    final betriebIds = <String>{};
    for (final row in [
      ...stoerungsRows,
      ...eigenauftragRows,
      ...eroeffnungRows,
      ...montageRows,
    ]) {
      final bid = row['betrieb_id'] as String?;
      if (bid != null) betriebIds.add(bid);
    }
    for (final row in [
      ...bergkundenRows,
      ...reinigungData['gratisreinigungen']!,
    ]) {
      final bid = row['betrieb_id'] as String?;
      if (bid != null) betriebIds.add(bid);
    }

    final betriebe = await _loadBetriebe(betriebIds);

    // Material-Namen laden für Rapport-PDFs
    final materialNames = await _loadMaterialNames([
      ...stoerungsRows,
      ...eigenauftragRows,
      ...eroeffnungRows,
      ...montageRows,
    ]);

    // Betrieb-Map für Rapport-PDFs erstellen
    final betriebMap = <String, Map<String, dynamic>>{};
    for (final entry in betriebe.entries) {
      betriebMap[entry.key] = {
        'name': entry.value.name,
        'strasse': entry.value.strasse,
        'nr': entry.value.nr,
        'ort': entry.value.ort,
        'plz': entry.value.plz,
        'betrieb_nr': entry.value.betriebNr,
        'rechnungsstellung': entry.value.rechnungsstellung,
        'ist_bergkunde': entry.value.istBergkunde,
      };
    }

    // Positionen aufbauen
    return HeinekenMonatsDaten(
      monat: start,
      stoerungen: _mapStoerungen(stoerungsRows, betriebe),
      eigenauftraege: _mapEigenauftraege(eigenauftragRows, betriebe),
      eroeffnungen: _mapEroeffnungen(eroeffnungRows, betriebe),
      montagen: _mapMontagen(montageRows, betriebe),
      pikettDienste: _mapPikett(pikettRows),
      berghaeuserAnfahrt:
          _mapBerghaeuserAnfahrt(bergkundenRows, betriebe),
      gratisreinigungen:
          _mapGratisreinigungen(reinigungData['gratisreinigungen']!, betriebe),
      // Raw data for rapport PDF generation
      stoerungRows: stoerungsRows,
      eigenauftragRows: eigenauftragRows,
      eroeffnungRows: eroeffnungRows,
      montageRows: montageRows,
      pikettRows: pikettRows,
      bergkundenRows: bergkundenRows,
      gratisreinigungRows: reinigungData['gratisreinigungen']!,
      betriebMap: betriebMap,
      materialNames: materialNames,
      mwstFaktor: _mwstSatz,
    );
  }

  /// Erstellt eine Heineken-Monatsrechnung in Supabase und generiert das PDF.
  static Future<Rechnung> erstelleMonatsrechnung(
      HeinekenMonatsDaten daten) async {
    final monatsName =
        DateFormat('MMMM yyyy', 'de_CH').format(daten.monat);

    // 1. Rechnung erstellen
    final rechnung = await RechnungRepository.create({
      'rechnungstyp': 'heineken_monat',
      'heineken_po_nummer': _heinekenPoNummer,
      'heineken_monat':
          daten.monat.toIso8601String().split('T').first,
      'rechnungsdatum': DateTime(daten.monat.year, daten.monat.month + 1, 0)
          .toIso8601String()
          .split('T')
          .first,
      'faelligkeitsdatum':
          DateTime(daten.monat.year, daten.monat.month + 1, 0)
              .add(const Duration(days: 30))
              .toIso8601String()
              .split('T')
              .first,
      'betrag_netto': daten.totalNetto,
      'mwst_betrag': daten.mwstBetrag,
      'betrag_brutto': daten.totalBrutto,
      'zahlungsstatus': 'offen',
    });

    // 2. Rechnungspositionen (eine pro Kategorie)
    final positionen = <Map<String, dynamic>>[];
    int pos = 0;
    for (final (name, _, total) in daten.kategorien) {
      pos++;
      final mwst = _round2(total * _mwstSatz);
      positionen.add({
        'rechnung_id': rechnung.id,
        'position': pos,
        'beschreibung': name,
        'betrag_netto': _round2(total),
        'mwst_satz': _mwstSatz * 100,
        'mwst_betrag': mwst,
        'betrag_brutto': _round2(total + mwst),
      });
    }
    await RechnungsPositionRepository.createAll(positionen);

    // 3. Combined PDF generieren (Hauptrechnung + Rapport-Beilagen)
    try {
      // Logo laden
      debugPrint('[HEI] Step 3a: Logo laden...');
      Uint8List? logoBytes;
      try {
        final data = await rootBundle.load('assets/images/heineken_logo.png');
        logoBytes = data.buffer.asUint8List();
        debugPrint('[HEI] Logo geladen: ${logoBytes.length} bytes');
      } catch (e) {
        debugPrint('[HEI] Logo laden fehlgeschlagen: $e');
      }

      debugPrint('[HEI] Step 3b: PDF Seiten erstellen...');
      final pdf = pw.Document();

      // Hauptrechnung: Übersicht + Detail
      pdf.addPage(HeinekenPdfService.buildUebersichtPage(
          daten, rechnung.rechnungsnummer,
          logoBytes: logoBytes,
          poNummer: _heinekenPoNummer,
          mwstLabel: _mwstLabel));
      debugPrint('[HEI] Übersicht-Seite hinzugefügt');

      final detailWidgets = HeinekenPdfService.buildDetailWidgets(daten);
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: HeinekenPdfService.buildDetailHeader(),
        ),
        build: (context) => detailWidgets,
      ));
      debugPrint('[HEI] Detail-Seite hinzugefügt');

      // Rapport-Beilagen anhängen
      debugPrint('[HEI] Step 3c: Rapport-Beilagen anhängen...');
      await _addRapportPages(pdf, daten, logoBytes);
      debugPrint('[HEI] Rapport-Seiten hinzugefügt');

      debugPrint('[HEI] Step 3d: PDF speichern...');
      final pdfBytes = await pdf.save();
      debugPrint('[HEI] PDF generiert: ${pdfBytes.length} bytes (${(pdfBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

      debugPrint('[HEI] Step 3e: Upload zu Storage (Rechnung ${rechnung.id})...');
      await RechnungPdfStorage.uploadPdf(rechnung.id, pdfBytes);
      debugPrint('[HEI] PDF hochgeladen');

      debugPrint('[HEI] Step 3f: Signed URL holen...');
      final signedUrl = await RechnungPdfStorage.getSignedUrl(rechnung.id);
      debugPrint('[HEI] Signed URL erhalten');

      await RechnungRepository.update(rechnung.id, {'pdf_url': signedUrl});
      debugPrint('[HEI] PDF URL in DB gesetzt');
    } catch (e, stack) {
      debugPrint('[HEI] FEHLER: $e');
      debugPrint('[HEI] Typ: ${e.runtimeType}');
      debugPrint('[HEI] Stack: $stack');
      rethrow;
    }

    // 4. Service-Einträge als abgerechnet markieren
    await _markiereAbgerechnet(daten);

    debugPrint('Heineken-Monatsrechnung $monatsName erstellt');
    return rechnung;
  }

  // ── Hilfsmethoden ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _queryTable(
    String table,
    String datumColumn,
    String startStr,
    String endStr,
  ) async {
    try {
      final rows = await SupabaseService.client
          .from(table)
          .select()
          .eq('user_id', _userId)
          .gte(datumColumn, startStr)
          .lt(datumColumn, endStr)
          .order(datumColumn);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Heineken: Fehler beim Laden von $table: $e');
      return [];
    }
  }

  /// Lädt Reinigungen für Gratisreinigungen (heineken, noch nicht abgerechnet).
  /// Bergkunden kommen jetzt aus der separaten bergkundenpauschalen-Tabelle.
  static Future<Map<String, List<Map<String, dynamic>>>> _queryReinigungen(
    String startStr,
    String endStr,
  ) async {
    List<Map<String, dynamic>> allRows;
    try {
      final rows = await SupabaseService.client
          .from('reinigungen')
          .select()
          .eq('user_id', _userId)
          .eq('abgerechnet', false)
          .gte('datum', startStr)
          .lt('datum', endStr)
          .order('datum');
      allRows = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Heineken: Fehler beim Laden von reinigungen: $e');
      return {'gratisreinigungen': []};
    }

    // Betrieb-IDs sammeln
    final betriebIds = <String>{};
    for (final row in allRows) {
      final bid = row['betrieb_id'] as String?;
      if (bid != null) betriebIds.add(bid);
    }

    // Betriebe laden für rechnungsstellung
    Map<String, Map<String, dynamic>> betriebe = {};
    if (betriebIds.isNotEmpty) {
      final bRows = await SupabaseService.client
          .from('betriebe')
          .select('id, rechnungsstellung')
          .inFilter('id', betriebIds.toList());
      for (final b in bRows) {
        betriebe[b['id'] as String] = b;
      }
    }

    final gratis = <Map<String, dynamic>>[];
    for (final row in allRows) {
      final bid = row['betrieb_id'] as String?;
      if (bid == null) continue;
      final betrieb = betriebe[bid];
      if (betrieb == null) continue;
      if (betrieb['rechnungsstellung'] == 'heineken') {
        gratis.add(row);
      }
    }

    return {'gratisreinigungen': gratis};
  }

  static Future<Map<String, _BetriebInfo>> _loadBetriebe(
      Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await SupabaseService.client
        .from('betriebe')
        .select('id, name, strasse, nr, ort, plz, ist_bergkunde, heineken_nr, rechnungsstellung')
        .inFilter('id', ids.toList());
    final map = <String, _BetriebInfo>{};
    for (final row in rows) {
      map[row['id'] as String] = _BetriebInfo(
        name: row['name'] as String? ?? '',
        strasse: row['strasse'] as String? ?? '',
        nr: row['nr'] as String? ?? '',
        ort: row['ort'] as String? ?? '',
        plz: row['plz'] as String? ?? '',
        betriebNr: row['heineken_nr'] as String? ?? '',
        rechnungsstellung: row['rechnungsstellung'] as String? ?? '',
        istBergkunde: row['ist_bergkunde'] == true,
      );
    }
    return map;
  }

  /// Lädt Material-Namen für alle Material-IDs in den Raw-Rows.
  static Future<Map<String, String>> _loadMaterialNames(
      List<Map<String, dynamic>> allRows) async {
    final ids = <String>{};
    for (final row in allRows) {
      for (int i = 1; i <= 5; i++) {
        final id = row['material${i}_id'] as String?;
        if (id != null) ids.add(id);
      }
    }
    if (ids.isEmpty) return {};
    try {
      final rows = await SupabaseService.client
          .from('lager')
          .select('id, name')
          .inFilter('id', ids.toList());
      final map = <String, String>{};
      for (final row in rows) {
        map[row['id'] as String] = row['name'] as String? ?? '';
      }
      return map;
    } catch (e) {
      debugPrint('Heineken: Fehler beim Laden von Material-Namen: $e');
      return {};
    }
  }

  static String _betriebLabel(
      String? betriebId, Map<String, _BetriebInfo> betriebe) {
    if (betriebId == null) return 'UNBEKANNT';
    final b = betriebe[betriebId];
    if (b == null) return 'UNBEKANNT';
    if (b.ort.isEmpty) return b.name;
    return '${b.name} - ${b.ort}';
  }

  // ── Mapper pro Kategorie ───────────────────────────────────────

  static List<HeinekenPosition> _mapStoerungen(
    List<Map<String, dynamic>> rows,
    Map<String, _BetriebInfo> betriebe,
  ) {
    return rows.map((r) {
      final isKm = r['ist_kilometerabrechnung'] == true;
      final bereiche = (r['stoerung_bereiche'] as List?)?.cast<int>();
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        stoerNr: isKm ? '0' : r['referenz_nr']?.toString(),
        bereich: isKm ? null : (bereiche != null && bereiche.isNotEmpty ? bereiche.join(', ') : null),
        kunde: isKm ? (r['problem_beschreibung']?.toString() ?? '') : _betriebLabel(r['betrieb_id'], betriebe),
        betrag: _toDouble(r['preis_netto']),
      );
    }).toList();
  }

  static List<HeinekenPosition> _mapEigenauftraege(
    List<Map<String, dynamic>> rows,
    Map<String, _BetriebInfo> betriebe,
  ) {
    return rows.map((r) {
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        stoerNr: r['referenz_nr']?.toString(),
        bereich: 'EA',
        kunde: _betriebLabel(r['betrieb_id'], betriebe),
        betrag: _toDouble(r['pauschale']),
      );
    }).toList();
  }

  static List<HeinekenPosition> _mapEroeffnungen(
    List<Map<String, dynamic>> rows,
    Map<String, _BetriebInfo> betriebe,
  ) {
    return rows.map((r) {
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        stoerNr: r['referenz_nr']?.toString(),
        bereich: 'Eröffnung',
        kunde: _betriebLabel(r['betrieb_id'], betriebe),
        betrag: _toDouble(r['preis']),
      );
    }).toList();
  }

  static List<HeinekenPosition> _mapMontagen(
    List<Map<String, dynamic>> rows,
    Map<String, _BetriebInfo> betriebe,
  ) {
    return rows.map((r) {
      final typ = r['montage_typ']?.toString() ?? 'neumontage';
      final betriebId = r['betrieb_id'] as String?;
      // Ohne Betrieb (Spesen/Aufwandsentschädigung): Beschreibung als Kunde
      final kunde = betriebId != null
          ? _betriebLabel(betriebId, betriebe)
          : (r['beschreibung']?.toString() ?? '');
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        stoerNr: '-',
        bereich: _montageTypLabel(typ),
        kunde: kunde,
        betrag: _toDouble(r['kosten_arbeit']),
      );
    }).toList();
  }

  /// Lesbare Labels für Montage-Typen (für Heineken-Rechnung).
  static String _montageTypLabel(String typ) {
    switch (typ) {
      case 'neumontage': return 'Neumontage';
      case 'demontage': return 'Demontage';
      case 'abaenderung': return 'Abänderung';
      case 'heigenie_service': return 'HeiGenie';
      case 'anlass': return 'Anlass';
      case 'spesen': return 'Spesen';
      case 'aufwandsentschaedigung': return 'Aufwandsentsch.';
      // Legacy (vor Migration 062)
      case 'neu_installation': case 'montage': return 'Neumontage';
      case 'umbau': case 'erweiterung': return 'Abänderung';
      case 'abbau': return 'Demontage';
      case 'anlass_mitarbeit': return 'Anlass';
      default: return typ;
    }
  }

  static List<HeinekenPosition> _mapPikett(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map((r) {
      final datumStart = DateTime.parse(r['datum_start']);
      final kw = _kalenderWoche(datumStart);
      final feiertage = r['anzahl_feiertage'] ?? 0;
      return HeinekenPosition(
        datum: datumStart,
        stoerNr: 'KW $kw',
        bereich: 'Pikett',
        kunde: 'Feiertage: $feiertage',
        betrag: _toDouble(r['pauschale_gesamt']),
      );
    }).toList();
  }

  static List<HeinekenPosition> _mapBerghaeuserAnfahrt(
    List<Map<String, dynamic>> rows,
    Map<String, _BetriebInfo> betriebe,
  ) {
    return rows.map((r) {
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        kunde: _betriebLabel(r['betrieb_id'], betriebe),
        betrag: _toDouble(r['betrag']) ?? _anfahrtPauschale,
      );
    }).toList();
  }

  static List<HeinekenPosition> _mapGratisreinigungen(
    List<Map<String, dynamic>> rows,
    Map<String, _BetriebInfo> betriebe,
  ) {
    return rows.map((r) {
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        kunde: _betriebLabel(r['betrieb_id'], betriebe),
        betrag: _toDouble(r['preis_netto']),
      );
    }).toList();
  }

  // ── Abgerechnet markieren ──────────────────────────────────────

  static Future<void> _markiereAbgerechnet(HeinekenMonatsDaten daten) async {
    final start = daten.monat;
    final end = DateTime(start.year, start.month + 1, 1);
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;
    final monatStr = startStr;

    final tables = [
      'stoerungen',
      'eigenauftraege',
      'eroeffnungsreinigungen',
      'montagen',
      'bergkundenpauschalen',
    ];

    for (final table in tables) {
      await SupabaseService.client
          .from(table)
          .update({
            'abgerechnet': true,
            'abrechnungs_monat': monatStr,
          })
          .eq('user_id', _userId)
          .gte('datum', startStr)
          .lt('datum', endStr);
    }

    // Pikett hat datum_start statt datum
    await SupabaseService.client
        .from('pikett_dienste')
        .update({
          'abgerechnet': true,
          'abrechnungs_monat': monatStr,
        })
        .eq('user_id', _userId)
        .gte('datum_start', startStr)
        .lt('datum_start', endStr);

    // Reinigungen: nur Heineken-Betriebe markieren
    try {
      final bRows = await SupabaseService.client
          .from('betriebe')
          .select('id')
          .eq('user_id', _userId)
          .eq('rechnungsstellung', 'heineken');
      final heinekenBetriebIds =
          bRows.map((b) => b['id'] as String).toList();
      if (heinekenBetriebIds.isNotEmpty) {
        await SupabaseService.client
            .from('reinigungen')
            .update({
              'abgerechnet': true,
              'abrechnungs_monat': monatStr,
            })
            .eq('user_id', _userId)
            .inFilter('betrieb_id', heinekenBetriebIds)
            .gte('datum', startStr)
            .lt('datum', endStr);
      }
    } catch (e) {
      debugPrint('Heineken: Reinigungen markieren fehlgeschlagen: $e');
    }
  }

  // ── Utils ──────────────────────────────────────────────────────

  static int _kalenderWoche(DateTime date) {
    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final wday = date.weekday;
    return ((dayOfYear - wday + 10) ~/ 7);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double? _toDoubleN(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  // ── Rapport-Beilagen ────────────────────────────────────────────

  /// Adresse aus betriebMap: "Strasse Nr"
  static String _adresse(Map<String, dynamic>? b) {
    if (b == null) return '';
    return '${b['strasse'] ?? ''} ${b['nr'] ?? ''}'.trim();
  }

  /// PLZ + Ort aus betriebMap
  static String _plzOrt(Map<String, dynamic>? b) {
    if (b == null) return '';
    return '${b['plz'] ?? ''} ${b['ort'] ?? ''}'.trim();
  }

  /// Sortiert Rows nach datum-Spalte (aufsteigend).
  static List<Map<String, dynamic>> _sortByDatum(
      List<Map<String, dynamic>> rows, [String datumCol = 'datum']) {
    final sorted = List<Map<String, dynamic>>.from(rows);
    sorted.sort((a, b) =>
        (a[datumCol]?.toString() ?? '').compareTo(b[datumCol]?.toString() ?? ''));
    return sorted;
  }

  /// Fügt alle Rapport-PDF-Seiten zum Dokument hinzu.
  /// Reihenfolge: Störungen → Eigenaufträge → Eröffnungen → Montagen →
  /// Pikett → Bergkunden → Gratisreinigungen (gleich wie Übersicht).
  /// Innerhalb jeder Kategorie: nach Datum sortiert.
  static Future<void> _addRapportPages(
      pw.Document pdf, HeinekenMonatsDaten daten, Uint8List? logoBytes) async {
    final names = daten.materialNames;
    final betriebe = daten.betriebMap;

    // 1. Störungsrapporte (nach Datum)
    for (final row in _sortByDatum(daten.stoerungRows)) {
      final isKm = row['ist_kilometerabrechnung'] == true;
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildStoerungPage(
        referenzNr: isKm ? '0' : (row['referenz_nr']?.toString() ?? ''),
        stoerungsnummer: isKm ? '0' : (row['referenz_nr']?.toString() ?? ''),
        datum: DateTime.parse(row['datum']),
        kunde: isKm ? (row['problem_beschreibung']?.toString() ?? '') : (b?['name'] ?? 'UNBEKANNT'),
        adresse: isKm ? '' : _adresse(b),
        ort: isKm ? (row['notizen']?.toString() ?? '') : _plzOrt(b),
        stoerungBereiche: isKm ? null : (row['stoerung_bereiche'] as List?)?.cast<int>(),
        serienNrKuehler: isKm ? null : row['serien_nr_kuehler']?.toString(),
        uhrzeitStart: isKm ? '00:00' : row['uhrzeit_start']?.toString(),
        istPikettEinsatz: isKm ? false : row['ist_pikett_einsatz'] == true,
        istBergkunde: isKm ? false : (b?['ist_bergkunde'] == true),
        anfahrtKm: _toInt(row['anfahrt_km']),
        preisBasis: isKm ? null : _toDoubleN(row['preis_basis']),
        preisAnfahrt: _toDoubleN(row['preis_anfahrt']),
        preisWochenende: isKm ? null : _toDoubleN(row['preis_wochenende']),
        komplexitaetZuschlag: _toDoubleN(row['komplexitaet_zuschlag']),
        preisNetto: _toDoubleN(row['preis_netto']),
        materialien: isKm ? const [] : _extractMaterialien(row, names, 5),
        logoBytes: logoBytes,
      ));
    }

    // 2. Eigenauftrag-Rapporte (nach Datum)
    for (final row in _sortByDatum(daten.eigenauftragRows)) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildEigenauftragPage(
        referenzNr: row['referenz_nr']?.toString() ?? '',
        stoerungsnummer: row['referenz_nr']?.toString() ?? '',
        datum: DateTime.parse(row['datum']),
        kunde: b?['name'] ?? 'UNBEKANNT',
        adresse: _adresse(b),
        ort: _plzOrt(b),
        problemBeschreibung: row['problem_beschreibung']?.toString() ?? '',
        loesungBeschreibung: row['loesung_beschreibung']?.toString(),
        pauschale: _toDoubleN(row['pauschale']),
        materialien: _extractMaterialien(row, names, 3),
        logoBytes: logoBytes,
      ));
    }

    // 3. Eröffnungs-/Endreinigung-Rapporte (nach Datum)
    for (final row in _sortByDatum(daten.eroeffnungRows)) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildEEReinigungPage(
        referenzNr: row['referenz_nr']?.toString() ?? '',
        stoerungsnummer: row['referenz_nr']?.toString() ?? '',
        datum: DateTime.parse(row['datum']),
        kunde: b?['name'] ?? 'UNBEKANNT',
        adresse: _adresse(b),
        ort: _plzOrt(b),
        istBergkunde: row['ist_bergkunde'] == true || b?['ist_bergkunde'] == true,
        preis: _toDouble(row['preis']),
        logoBytes: logoBytes,
      ));
    }

    // 4. Montage-Rapporte (nach Datum)
    for (final row in _sortByDatum(daten.montageRows)) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      final typ = row['montage_typ']?.toString() ?? 'sonstiges';
      final fotoPfad = row['protokoll_foto_pfad'] as String?;

      // HeiGenie mit Protokoll-Foto → gescanntes Papierprotokoll als Seite
      if (typ == 'heigenie_service' &&
          fotoPfad != null &&
          fotoPfad.isNotEmpty) {
        try {
          final jpgPfad = ProtokollFotoStorage.jpgPathFromPdf(fotoPfad);
          final bytes = await SupabaseService.client.storage
              .from('reinigung-fotos')
              .download(jpgPfad);

          final image = pw.MemoryImage(bytes);
          pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ));
        } catch (e) {
          debugPrint(
              '[HEI] HeiGenie Protokoll-Foto nicht ladbar ($fotoPfad): $e');
          // Fallback: Standard-Rapport
          _addStandardMontagePage(
              pdf, row, bid, b, names, logoBytes);
        }
      } else {
        // Standard-Rapport (alle anderen Montage-Typen)
        _addStandardMontagePage(
            pdf, row, bid, b, names, logoBytes);
      }
    }

    // 5. Pikett-Rapporte (nach Datum)
    for (final row in _sortByDatum(daten.pikettRows, 'datum_start')) {
      final datumStart = DateTime.parse(row['datum_start']);
      final datumEnde = row['datum_ende'] != null
          ? DateTime.parse(row['datum_ende'])
          : datumStart.add(const Duration(days: 6));
      final kw = _kalenderWoche(datumStart);
      pdf.addPage(HeinekenRapportService.buildPikettPage(
        referenzNr: row['referenz_nr']?.toString() ??
            '${datumStart.year}_$kw',
        datumStart: datumStart,
        datumEnde: datumEnde,
        kalenderwoche: kw,
        pauschale: _toDoubleN(row['pauschale']),
        anzahlFeiertage: _toInt(row['anzahl_feiertage']),
        feiertagZuschlag: _toDoubleN(row['feiertag_zuschlag']),
        pauschaleGesamt: _toDoubleN(row['pauschale_gesamt']),
        logoBytes: logoBytes,
      ));
    }

    // 6. Anfahrtspauschale-Rapporte (Bergkunden, nach Datum)
    for (final row in _sortByDatum(daten.bergkundenRows)) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      final datum = DateTime.parse(row['datum']);
      final dateStr = '${datum.day.toString().padLeft(2, '0')}_'
          '${datum.month.toString().padLeft(2, '0')}_${datum.year}';
      pdf.addPage(HeinekenRapportService.buildAnfahrtspauschPage(
        referenzNr: dateStr,
        datum: datum,
        kunde: b?['name'] ?? 'UNBEKANNT',
        adresse: _adresse(b),
        ort: _plzOrt(b),
        logoBytes: logoBytes,
      ));
    }

    // 7. Gratisreinigungen → gescannte Papierprotokolle (nach Datum)
    if (daten.gratisreinigungRows.isNotEmpty) {
      for (final row in _sortByDatum(daten.gratisreinigungRows)) {
        final fotoPfad = row['protokoll_foto_pfad'] as String?;
        if (fotoPfad == null || fotoPfad.isEmpty) continue;

        try {
          // JPEG-Version des Protokolls herunterladen
          final jpgPfad = ProtokollFotoStorage.jpgPathFromPdf(fotoPfad);
          final bytes = await SupabaseService.client.storage
              .from('reinigung-fotos')
              .download(jpgPfad);

          final image = pw.MemoryImage(bytes);
          pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ));
        } catch (e) {
          debugPrint('[HEI] Protokoll-Foto nicht ladbar ($fotoPfad): $e');
        }
      }
    }
  }

  /// Fügt eine Standard-Montage-Rapport-Seite hinzu.
  static void _addStandardMontagePage(
    pw.Document pdf,
    Map<String, dynamic> row,
    String? bid,
    Map<String, dynamic>? b,
    Map<String, String> names,
    Uint8List? logoBytes,
  ) {
    final kunde = bid != null
        ? (b?['name'] ?? 'UNBEKANNT')
        : (row['beschreibung']?.toString() ?? '');
    final typ = row['montage_typ']?.toString() ?? 'neumontage';

    // Bei Anlass: material_ids SIND die Freitext-Beschreibungen (keine Lager-IDs)
    final materialien = typ == 'anlass'
        ? _extractAnlassEintraege(row, 5)
        : _extractMaterialien(row, names, 5);

    pdf.addPage(HeinekenRapportService.buildMontagePage(
      referenzNr: row['referenz_nr']?.toString() ?? typ,
      datum: DateTime.parse(row['datum']),
      kunde: kunde,
      adresse: bid != null ? _adresse(b) : '',
      ort: bid != null ? _plzOrt(b) : '',
      montageTyp: typ,
      beschreibung: row['beschreibung']?.toString() ?? '',
      stundensatz: _toDoubleN(row['stundensatz']),
      dauerStunden: _toDoubleN(row['dauer_stunden']),
      kostenArbeit: _toDoubleN(row['kosten_arbeit']),
      materialien: materialien,
      logoBytes: logoBytes,
    ));
  }

  /// Extrahiert Anlass-Einträge (Freitext + Stunden) aus einer Raw-Row.
  static List<(String, double)> _extractAnlassEintraege(
      Map<String, dynamic> row, int max) {
    final result = <(String, double)>[];
    for (int i = 1; i <= max; i++) {
      final text = row['material${i}_id'] as String?;
      if (text != null && text.isNotEmpty) {
        final stunden = _toDouble(row['material${i}_menge']);
        result.add((text, stunden));
      }
    }
    return result;
  }

  /// Extrahiert Material-Positionen aus einer Raw-Row.
  static List<(String, double)> _extractMaterialien(
      Map<String, dynamic> row, Map<String, String> names, int max) {
    final result = <(String, double)>[];
    for (int i = 1; i <= max; i++) {
      final id = row['material${i}_id'] as String?;
      if (id != null) {
        final name = names[id] ?? id;
        final menge = _toDouble(row['material${i}_menge']);
        result.add((name, menge > 0 ? menge : 1));
      }
    }
    return result;
  }
}

class _BetriebInfo {
  final String name;
  final String strasse;
  final String nr;
  final String ort;
  final String plz;
  final String betriebNr;
  final String rechnungsstellung;
  final bool istBergkunde;
  _BetriebInfo({
    required this.name,
    this.strasse = '',
    this.nr = '',
    required this.ort,
    this.plz = '',
    this.betriebNr = '',
    this.rechnungsstellung = '',
    this.istBergkunde = false,
  });
}
