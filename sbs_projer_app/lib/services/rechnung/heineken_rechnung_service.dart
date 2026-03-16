import 'package:flutter/foundation.dart';
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
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class HeinekenRechnungService {
  static const _anfahrtPauschale = 180.0;
  static const _mwstSatz = 0.081;
  static const _heinekenPoNummer = '6100259429';

  static String get _userId => SupabaseService.dataUserId;

  /// Sammelt alle Heineken-relevanten Daten für den gegebenen Monat.
  static Future<HeinekenMonatsDaten> sammleMonatsDaten(DateTime monat) async {
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
    ]);

    final stoerungsRows = results[0] as List<Map<String, dynamic>>;
    final eigenauftragRows = results[1] as List<Map<String, dynamic>>;
    final eroeffnungRows = results[2] as List<Map<String, dynamic>>;
    final montageRows = results[3] as List<Map<String, dynamic>>;
    final pikettRows = results[4] as List<Map<String, dynamic>>;
    final reinigungData = results[5] as Map<String, List<Map<String, dynamic>>>;

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
      ...reinigungData['bergkunden']!,
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
        'ort': entry.value.ort,
        'plz': entry.value.plz,
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
          _mapBerghaeuserAnfahrt(reinigungData['bergkunden']!, betriebe),
      gratisreinigungen:
          _mapGratisreinigungen(reinigungData['gratisreinigungen']!, betriebe),
      // Raw data for rapport PDF generation
      stoerungRows: stoerungsRows,
      eigenauftragRows: eigenauftragRows,
      eroeffnungRows: eroeffnungRows,
      montageRows: montageRows,
      pikettRows: pikettRows,
      bergkundenRows: reinigungData['bergkunden']!,
      betriebMap: betriebMap,
      materialNames: materialNames,
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
        'mwst_satz': 8.10,
        'mwst_betrag': mwst,
        'betrag_brutto': _round2(total + mwst),
      });
    }
    await RechnungsPositionRepository.createAll(positionen);

    // 3. Combined PDF generieren (Hauptrechnung + Rapport-Beilagen)
    try {
      final pdf = pw.Document();

      // Hauptrechnung: Übersicht + Detail
      pdf.addPage(HeinekenPdfService.buildUebersichtPage(
          daten, rechnung.rechnungsnummer));
      final detailWidgets = HeinekenPdfService.buildDetailWidgets(daten);
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
        build: (context) => detailWidgets,
      ));

      // Rapport-Beilagen anhängen
      _addRapportPages(pdf, daten);

      final pdfBytes = await pdf.save();
      await RechnungPdfStorage.uploadPdf(rechnung.id, pdfBytes);
      final signedUrl = await RechnungPdfStorage.getSignedUrl(rechnung.id);
      await RechnungRepository.update(rechnung.id, {'pdf_url': signedUrl});
    } catch (e) {
      debugPrint('Heineken PDF Generierung fehlgeschlagen: $e');
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

  /// Lädt Reinigungen und splittet in Bergkunden / Gratisreinigungen.
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
          .gte('datum', startStr)
          .lt('datum', endStr)
          .order('datum');
      allRows = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Heineken: Fehler beim Laden von reinigungen: $e');
      return {'bergkunden': [], 'gratisreinigungen': []};
    }

    // Betrieb-IDs sammeln
    final betriebIds = <String>{};
    for (final row in allRows) {
      final bid = row['betrieb_id'] as String?;
      if (bid != null) betriebIds.add(bid);
    }

    // Betriebe laden für istBergkunde und rechnungsstellung
    Map<String, Map<String, dynamic>> betriebe = {};
    if (betriebIds.isNotEmpty) {
      final bRows = await SupabaseService.client
          .from('betriebe')
          .select('id, ist_bergkunde, rechnungsstellung')
          .inFilter('id', betriebIds.toList());
      for (final b in bRows) {
        betriebe[b['id'] as String] = b;
      }
    }

    final bergkunden = <Map<String, dynamic>>[];
    final gratis = <Map<String, dynamic>>[];

    for (final row in allRows) {
      final bid = row['betrieb_id'] as String?;
      if (bid == null) continue;
      final betrieb = betriebe[bid];
      if (betrieb == null) continue;

      if (betrieb['ist_bergkunde'] == true) {
        bergkunden.add(row);
      }
      if (betrieb['rechnungsstellung'] == 'rechnung_heineken') {
        gratis.add(row);
      }
    }

    return {'bergkunden': bergkunden, 'gratisreinigungen': gratis};
  }

  static Future<Map<String, _BetriebInfo>> _loadBetriebe(
      Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await SupabaseService.client
        .from('betriebe')
        .select('id, name, ort, plz, ist_bergkunde')
        .inFilter('id', ids.toList());
    final map = <String, _BetriebInfo>{};
    for (final row in rows) {
      map[row['id'] as String] = _BetriebInfo(
        name: row['name'] as String? ?? '',
        ort: row['ort'] as String? ?? '',
        plz: row['plz'] as String? ?? '',
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
      final bereich = r['stoerung_bereich'];
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        stoerNr: r['stoerungsnummer']?.toString(),
        bereich: bereich?.toString(),
        kunde: _betriebLabel(r['betrieb_id'], betriebe),
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
        stoerNr: r['stoerungsnummer']?.toString(),
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
        stoerNr: r['stoerungsnummer']?.toString(),
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
      return HeinekenPosition(
        datum: DateTime.parse(r['datum']),
        stoerNr: '-',
        bereich: r['montage_typ']?.toString() ?? 'Abänderung',
        kunde: _betriebLabel(r['betrieb_id'], betriebe),
        betrag: _toDouble(r['kosten_arbeit']),
      );
    }).toList();
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
        betrag: _anfahrtPauschale,
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

  /// Fügt alle Rapport-PDF-Seiten zum Dokument hinzu.
  static void _addRapportPages(pw.Document pdf, HeinekenMonatsDaten daten) {
    final names = daten.materialNames;
    final betriebe = daten.betriebMap;

    // 1. Störungsrapporte
    for (final row in daten.stoerungRows) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildStoerungPage(
        referenzNr: row['referenz_nr']?.toString() ??
            row['stoerungsnummer']?.toString() ?? '',
        stoerungsnummer: row['stoerungsnummer']?.toString() ?? '',
        datum: DateTime.parse(row['datum']),
        kunde: b?['name'] ?? 'UNBEKANNT',
        ort: '${b?['plz'] ?? ''} ${b?['ort'] ?? ''}'.trim(),
        stoerungBereich: row['stoerung_bereich'] as int?,
        serienNrKuehler: row['serien_nr_kuehler']?.toString(),
        uhrzeitStart: row['uhrzeit_start']?.toString(),
        istPikettEinsatz: row['ist_pikett_einsatz'] == true,
        istBergkunde: b?['ist_bergkunde'] == true,
        anfahrtKm: _toInt(row['anfahrt_km']),
        preisBasis: _toDoubleN(row['preis_basis']),
        preisAnfahrt: _toDoubleN(row['preis_anfahrt']),
        preisWochenende: _toDoubleN(row['preis_wochenende']),
        komplexitaetZuschlag: _toDoubleN(row['komplexitaet_zuschlag']),
        preisNetto: _toDoubleN(row['preis_netto']),
        materialien: _extractMaterialien(row, names, 5),
      ));
    }

    // 2. Eigenauftrag-Rapporte
    for (final row in daten.eigenauftragRows) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildEigenauftragPage(
        referenzNr: row['referenz_nr']?.toString() ??
            row['stoerungsnummer']?.toString() ?? '',
        stoerungsnummer: row['stoerungsnummer']?.toString() ?? '',
        datum: DateTime.parse(row['datum']),
        kunde: b?['name'] ?? 'UNBEKANNT',
        ort: '${b?['plz'] ?? ''} ${b?['ort'] ?? ''}'.trim(),
        problemBeschreibung: row['problem_beschreibung']?.toString() ?? '',
        loesungBeschreibung: row['loesung_beschreibung']?.toString(),
        pauschale: _toDoubleN(row['pauschale']),
        materialien: _extractMaterialien(row, names, 3),
      ));
    }

    // 3. Eröffnungs-/Endreinigung-Rapporte
    for (final row in daten.eroeffnungRows) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildEEReinigungPage(
        referenzNr: row['stoerungsnummer']?.toString() ?? '',
        stoerungsnummer: row['stoerungsnummer']?.toString() ?? '',
        datum: DateTime.parse(row['datum']),
        kunde: b?['name'] ?? 'UNBEKANNT',
        ort: '${b?['plz'] ?? ''} ${b?['ort'] ?? ''}'.trim(),
        istBergkunde: row['ist_bergkunde'] == true || b?['ist_bergkunde'] == true,
        preis: _toDouble(row['preis']),
      ));
    }

    // 4. Montage-Rapporte
    for (final row in daten.montageRows) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      pdf.addPage(HeinekenRapportService.buildMontagePage(
        referenzNr: row['referenz_nr']?.toString() ??
            row['montage_typ']?.toString() ?? '',
        datum: DateTime.parse(row['datum']),
        kunde: b?['name'] ?? 'UNBEKANNT',
        ort: '${b?['plz'] ?? ''} ${b?['ort'] ?? ''}'.trim(),
        montageTyp: row['montage_typ']?.toString() ?? 'sonstiges',
        beschreibung: row['beschreibung']?.toString() ?? '',
        stundensatz: _toDoubleN(row['stundensatz']),
        dauerStunden: _toDoubleN(row['dauer_stunden']),
        kostenArbeit: _toDoubleN(row['kosten_arbeit']),
        materialien: _extractMaterialien(row, names, 5),
      ));
    }

    // 5. Pikett-Rapporte
    for (final row in daten.pikettRows) {
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
      ));
    }

    // 6. Anfahrtspauschale-Rapporte (Bergkunden)
    for (final row in daten.bergkundenRows) {
      final bid = row['betrieb_id'] as String?;
      final b = bid != null ? betriebe[bid] : null;
      final datum = DateTime.parse(row['datum']);
      final dateStr = '${datum.day.toString().padLeft(2, '0')}_'
          '${datum.month.toString().padLeft(2, '0')}_${datum.year}';
      pdf.addPage(HeinekenRapportService.buildAnfahrtspauschPage(
        referenzNr: dateStr,
        datum: datum,
        kunde: b?['name'] ?? 'UNBEKANNT',
        ort: '${b?['plz'] ?? ''} ${b?['ort'] ?? ''}'.trim(),
      ));
    }
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
  final String ort;
  final String plz;
  final bool istBergkunde;
  _BetriebInfo({
    required this.name,
    required this.ort,
    this.plz = '',
    this.istBergkunde = false,
  });
}
