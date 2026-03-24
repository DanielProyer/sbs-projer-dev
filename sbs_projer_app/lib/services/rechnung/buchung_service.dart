import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BuchungService {
  /// Erstellt eine manuelle Buchung basierend auf einer Vorlage.
  static Future<Buchung> createFromVorlage(
    BuchungsVorlage vorlage, {
    required DateTime datum,
    required double betragNetto,
    String? beschreibung,
    String? belegnummer,
    String? belegTyp,
    String? belegId,
  }) async {
    final mwstSatz = vorlage.mwstSatz ?? 0;
    final mwstBetrag = betragNetto * mwstSatz / 100;
    final betragBrutto = betragNetto + mwstBetrag;

    return BuchungRepository.create({
      'datum': datum.toIso8601String().split('T').first,
      'belegnummer': belegnummer,
      'vorlage_id': vorlage.id,
      'soll_konto': vorlage.sollKonto,
      'haben_konto': vorlage.habenKonto,
      'mwst_konto': vorlage.mwstKonto,
      'betrag_netto': betragNetto,
      'mwst_satz': mwstSatz,
      'mwst_betrag': (mwstBetrag * 100).roundToDouble() / 100,
      'betrag_brutto': (betragBrutto * 100).roundToDouble() / 100,
      'beschreibung': beschreibung ?? vorlage.bezeichnung,
      'zahlungsweg': vorlage.zahlungsweg,
      'belegordner': vorlage.belegordner,
      'beleg_typ': belegTyp ?? 'sonstiges',
      'beleg_id': belegId,
      'geschaeftsjahr': datum.year,
    });
  }

  /// Berechnet den Saldo eines Kontos (Soll - Haben für Aktiv/Aufwand, Haben - Soll für Passiv/Ertrag).
  static Future<double> getKontoSaldo(int kontonummer) async {
    final buchungen = await BuchungRepository.getByKonto(kontonummer);
    double saldo = 0;
    for (final b in buchungen) {
      if (b.istStorniert) continue;
      if (b.sollKonto == kontonummer) saldo += b.betragBrutto;
      if (b.habenKonto == kontonummer) saldo -= b.betragBrutto;
    }
    // Passiv-/Ertragskonten: Saldo umkehren (Klasse 2, 3, 8, 9)
    final klasse = kontonummer ~/ 1000;
    if (klasse == 2 || klasse == 3 || klasse == 8 || klasse == 9) {
      saldo = -saldo;
    }
    return saldo;
  }

  /// Berechnet Saldi für alle Konten auf einmal (effizienter als einzeln).
  static Future<Map<int, double>> getAllSaldi() async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('soll_konto, haben_konto, betrag_brutto, ist_storniert')
        .eq('user_id', SupabaseService.dataUserId);

    final saldi = <int, double>{};
    for (final row in rows) {
      if (row['ist_storniert'] == true) continue;
      final betrag = double.tryParse(row['betrag_brutto'].toString()) ?? 0;
      final soll = row['soll_konto'] as int;
      final haben = row['haben_konto'] as int;
      saldi[soll] = (saldi[soll] ?? 0) + betrag;
      saldi[haben] = (saldi[haben] ?? 0) - betrag;
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
}
