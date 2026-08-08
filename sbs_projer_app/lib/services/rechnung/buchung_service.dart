import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeftsfall_resolver.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BuchungService {
  /// Erstellt eine manuelle Buchung basierend auf einer Vorlage (Geschäftsfall).
  ///
  /// Soll/Haben werden über [GeschaeftsfallResolver] aus Geschäftsfall (was) +
  /// [zahlungsweg] (wie) aufgelöst; bei `art='fix'` direkt aus der Vorlage.
  /// Der MWST-Satz kommt datumsabhängig aus [MwstSatzService], wenn die Vorlage
  /// `mwstPflichtig` ist.
  static Future<Buchung> createFromVorlage(
    BuchungsVorlage vorlage, {
    required DateTime datum,
    required double betragNetto,
    String? zahlungsweg, // bei art ausgabe/einnahme erforderlich
    String? beschreibung,
    String? belegnummer,
    String? belegTyp,
    String? belegId,
  }) async {
    final aufgeloest = GeschaeftsfallResolver.aufloesen(vorlage, zahlungsweg);

    // MWST: Satz aus Datum, nur wenn Vorlage steuerpflichtig
    final double mwstSatz =
        vorlage.mwstPflichtig ? await MwstSatzService.satzFuerDatum(datum) : 0;
    final double mwstBetrag = betragNetto * mwstSatz / 100;
    final double betragBrutto = betragNetto + mwstBetrag;

    return BuchungRepository.create({
      'datum': datum.toIso8601String().split('T').first,
      'belegnummer': belegnummer,
      'vorlage_id': vorlage.id,
      'soll_konto': aufgeloest.sollKonto,
      'haben_konto': aufgeloest.habenKonto,
      'mwst_konto': vorlage.mwstPflichtig ? aufgeloest.mwstKonto : null,
      'betrag_netto': betragNetto,
      'mwst_satz': mwstSatz,
      'mwst_betrag': (mwstBetrag * 100).roundToDouble() / 100,
      'betrag_brutto': (betragBrutto * 100).roundToDouble() / 100,
      'beschreibung': beschreibung ?? vorlage.bezeichnung,
      'zahlungsweg': zahlungsweg ?? vorlage.zahlungsweg,
      'belegordner': vorlage.belegordner,
      'beleg_typ': belegTyp ?? 'sonstiges',
      'beleg_id': belegId,
      'geschaeftsjahr': datum.year,
    });
  }

  /// Berechnet Saldi für alle Konten auf einmal (effizienter als einzeln).
  static Future<Map<int, double>> getAllSaldi() async {
    // Seitenweise holen — PostgREST deckelt sonst bei 1000 Zeilen (Saldo wäre verfälscht).
    final rows = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final page = await SupabaseService.client
          .from('buchungen')
          .select('soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto, ist_storniert, storno_von_id')
          .eq('user_id', SupabaseService.dataUserId)
          .order('id') // stabile Pagination (sonst fallen Zeilen durch)
          .range(from, from + pageSize - 1);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < pageSize) break;
      from += pageSize;
    }

    final saldi = <int, double>{};
    for (final row in rows) {
      // Stornierte Originale UND Gegenbuchungen raus — sonst zeigt der Saldo
      // nach einem Storno −Original statt 0 (Ausschluss-Modell wie Bilanz/ER).
      if (!zaehltFuerSaldo(
          istStorniert: row['ist_storniert'] == true,
          stornoVonId: row['storno_von_id'] as String?)) {
        continue;
      }
      final brutto = double.tryParse(row['betrag_brutto'].toString()) ?? 0;
      final netto = row['betrag_netto'] != null
          ? (double.tryParse(row['betrag_netto'].toString()) ?? brutto)
          : brutto;
      final mwst = double.tryParse(row['mwst_betrag']?.toString() ?? '0') ?? 0;
      SaldoExpansion.apply(
        saldi,
        sollKonto: row['soll_konto'] as int,
        habenKonto: row['haben_konto'] as int,
        mwstKonto: row['mwst_konto'] as int?,
        betragNetto: netto,
        mwstBetrag: mwst,
        betragBrutto: brutto,
      );
    }

    // Passiv-/Ertragskonten: Saldo umkehren
    for (final konto in saldi.keys.toList()) {
      final klasse = konto ~/ 1000;
      if (klasse == 2 || klasse == 3 || klasse == 8 || klasse == 9) {
        saldi[konto] = -(saldi[konto] ?? 0);
      }
    }

    return saldi;
  }

  /// Saldo eines Kontos (inkl. MWST-Anteil, falls das Konto ein Steuerkonto ist).
  static Future<double> getKontoSaldo(int kontonummer) async {
    final saldi = await getAllSaldi();
    return saldi[kontonummer] ?? 0;
  }
}
