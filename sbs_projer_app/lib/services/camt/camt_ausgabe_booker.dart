import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

/// Bucht eine Ausgabe/Bargeld-Transaktion aus camt anhand einer Buchungsvorlage.
/// Erzeugt EINE Buchung (Brutto/Netto/MwSt in einer Zeile) und stempelt den
/// camt_tx_key direkt für robusten Dedup.
class CamtAusgabeBooker {
  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static Future<Buchung> book(CamtTransaction tx, BuchungsVorlage vorlage) async {
    final brutto = _round2(tx.amount);
    final satz = vorlage.mwstSatz ?? 0;
    final netto = satz > 0 ? _round2(brutto / (1 + satz / 100)) : brutto;
    final mwst = _round2(brutto - netto);
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;
    final beschreibung = tx.partyName != null
        ? '${tx.isCredit ? "Zahlung" : "Belastung"} ${tx.partyName}'
        : (tx.additionalInfo ?? vorlage.bezeichnung);
    final notizen = <String>[
      if (tx.strukturierteReferenz != null) 'Ref: ${tx.strukturierteReferenz}',
      if (tx.partyIban != null) 'IBAN: ${tx.partyIban}',
    ].join('\n');

    return BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': tx.accountServiceRef,
      'vorlage_id': vorlage.id,
      'soll_konto': vorlage.sollKonto,
      'haben_konto': vorlage.habenKonto,
      'mwst_konto': vorlage.mwstKonto,
      'betrag_netto': netto,
      'mwst_satz': satz,
      'mwst_betrag': mwst,
      'betrag_brutto': brutto,
      'beschreibung': beschreibung,
      'zahlungsweg': vorlage.zahlungsweg ?? 'bank',
      'belegordner': vorlage.belegordner ?? 'bank',
      'beleg_typ': 'camt053',
      'geschaeftsjahr': tx.bookingDate.year,
      'camt_tx_key': tx.txKey,
      'notizen': notizen,
    });
  }
}
