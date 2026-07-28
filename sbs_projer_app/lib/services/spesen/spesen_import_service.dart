import 'dart:typed_data';
import 'package:sbs_projer_app/data/models/beleg_scan_result.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_beleg_repository.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';

enum Zahlungsweg { bar, bank, privat }

/// Erstellt Buchungen + Beleg-Uploads aus einem BelegScanResult.
class SpesenImportService {
  /// Schweizer 5-Rappen-Rundung für Barzahlung.
  static double _runden5Rappen(double betrag) =>
      (betrag * 20).roundToDouble() / 20;

  /// Konten-Mapping nach Kategorie (Kontenwahl Daniel 26.07.2026).
  /// 'essen' ist der Auffangwert für alles Übrige → Spesen.
  static int _sollKonto(String kategorie) {
    switch (kategorie) {
      case 'benzin':
        return 6200; // Betriebsaufwand Fahrzeuge
      case 'material':
        return 4004; // Hilfs- und Verbrauchsmaterialaufwand
      case 'berufskleider':
        return 5850; // Berufskleider/Schutzausrüstung
      case 'parkgebuehren':
        return 6270; // Parkgebühren
      case 'entsorgung':
        return 6460; // Entsorgungsaufwand
      default:
        return 5820; // Reise- und Spesenvergütungen
    }
  }

  static String _belegordner(String kategorie) {
    switch (kategorie) {
      case 'benzin':
      case 'parkgebuehren':
        return '040_Fahrzeug';
      case 'material':
      case 'berufskleider':
      case 'entsorgung':
        return '050_Material';
      default:
        return '030_Spesen';
    }
  }

  static int _habenKonto(Zahlungsweg weg) {
    switch (weg) {
      case Zahlungsweg.bar:
        return 1000; // Kasse
      case Zahlungsweg.bank:
        return 1020; // Bankguthaben
      case Zahlungsweg.privat:
        return 2260; // Privatkonto
    }
  }

  static String _zahlungswegLabel(Zahlungsweg weg) {
    switch (weg) {
      case Zahlungsweg.bar:
        return 'kasse';
      case Zahlungsweg.bank:
        return 'bank';
      case Zahlungsweg.privat:
        return 'privat';
    }
  }

  /// Importiert Spesen: Erstellt 1-N Buchungen (pro Position) + Beleg-Upload.
  /// Kategorie (benzin/material/berufskleider/parkgebuehren/entsorgung/essen)
  /// wird pro Position automatisch aus dem OCR-Ergebnis bestimmt.
  static Future<List<Buchung>> importSpesen({
    required BelegScanResult scanResult,
    required Zahlungsweg zahlungsweg,
    required Uint8List belegBytes,
    required String dateiname,
    required String dateityp,
  }) async {
    final buchungen = <Buchung>[];
    final now = DateTime.now();

    for (int i = 0; i < scanResult.positionen.length; i++) {
      final pos = scanResult.positionen[i];
      final kat = pos.kategorie;
      final datumStr = scanResult.datum.toIso8601String().split('T').first;
      final beschreibung = scanResult.positionen.length > 1
          ? '${scanResult.geschaeft} - ${pos.beschreibung}'
          : scanResult.geschaeft;

      // Barzahlung: auf 5 Rappen runden (Schweizer Rundungsregel)
      final brutto = zahlungsweg == Zahlungsweg.bar
          ? _runden5Rappen(pos.betragBrutto)
          : pos.betragBrutto;
      final netto = pos.mwstSatz > 0
          ? brutto / (1 + pos.mwstSatz / 100)
          : brutto;
      final betragNetto = double.parse(netto.toStringAsFixed(2));
      final mwstBetrag = double.parse((brutto - betragNetto).toStringAsFixed(2));
      final habenKonto = _habenKonto(zahlungsweg);

      // 1. Aufwand-Buchung: Soll Aufwandkonto / Haben Zahlungskonto → Netto
      final buchung = await BuchungRepository.create({
        'datum': datumStr,
        'soll_konto': _sollKonto(kat),
        'haben_konto': habenKonto,
        'mwst_konto': 1171,
        'betrag_netto': betragNetto,
        'mwst_satz': pos.mwstSatz,
        'mwst_betrag': mwstBetrag,
        'betrag_brutto': brutto,
        'beschreibung': beschreibung,
        'zahlungsweg': _zahlungswegLabel(zahlungsweg),
        'belegordner': _belegordner(kat),
        'beleg_typ': 'sonstiges',
        'geschaeftsjahr': scanResult.datum.year,
        'notizen': 'Spesen-Scanner Import ${now.toIso8601String().split('T').first}',
      });

      // 2. Vorsteuer-Buchung: Soll 1171 (Vorsteuer) / Haben Aufwandkonto → MwSt-Betrag
      //    Reduziert den Aufwand um die Vorsteuer (MwSt ist bereits im Brutto der Aufwand-Buchung)
      if (mwstBetrag > 0) {
        final mwstBuchung = await BuchungRepository.create({
          'datum': datumStr,
          'soll_konto': 1171, // Vorsteuer Betrieb
          'haben_konto': _sollKonto(kat), // Aufwandkonto (5820/6200), NICHT Zahlungskonto
          'betrag_netto': mwstBetrag,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': mwstBetrag,
          'beschreibung': 'Vorsteuer ${pos.mwstSatz}% - $beschreibung',
          'zahlungsweg': _zahlungswegLabel(zahlungsweg),
          'belegordner': _belegordner(kat),
          'beleg_typ': 'sonstiges',
          'geschaeftsjahr': scanResult.datum.year,
          'notizen': 'Spesen-Scanner Import ${now.toIso8601String().split('T').first}',
        });

        // Beleg auch zur Vorsteuer-Buchung
        await BuchungsBelegRepository.upload(
          buchungId: mwstBuchung.id,
          dateiname: dateiname,
          dateityp: dateityp,
          bytes: belegBytes,
          belegQuelle: 'spesen_scan',
          beschreibung: 'Vorsteuer - ${scanResult.geschaeft}',
        );

        buchungen.add(mwstBuchung);
      }

      // Beleg zur Aufwand-Buchung
      await BuchungsBelegRepository.upload(
        buchungId: buchung.id,
        dateiname: dateiname,
        dateityp: dateityp,
        bytes: belegBytes,
        belegQuelle: 'spesen_scan',
        beschreibung: '${scanResult.geschaeft} - ${pos.beschreibung}',
      );

      buchungen.add(buchung);
    }

    return buchungen;
  }
}
