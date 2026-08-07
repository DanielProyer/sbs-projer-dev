import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

import 'package:sbs_projer_app/services/buchhaltung/geschaeftsfall_resolver.dart';

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Löst die Konten einer Vorlage für den camt-Kontext auf. Phase-0a-Vorlagen
/// (art 'ausgabe'/'einnahme') tragen das Konto in `hauptkonto` und haben
/// soll/haben = NULL — der direkte Zugriff crashte dort (Fall «Bussen»/
/// «Fahrbewilligung»). camt läuft immer über die Bank → Zahlungsweg 'bank'.
AufgeloesteBuchung kontenFuerCamt(BuchungsVorlage vorlage) =>
    GeschaeftsfallResolver.aufloesen(vorlage, 'bank');

/// Konten und Beträge einer camt-Ausgabe-Buchung — richtungsbewusst (B8-Fix,
/// Buchhaltungsprüfung 06.08.2026):
/// - **Belastung** (Normalfall): Konten wie in der Vorlage, MwSt-Split über
///   `mwst_konto` (SaldoExpansion).
/// - **Gutschrift** (z. B. Prämien-Rückerstattung auf einer Ausgabe-Regel):
///   Konten getauscht, damit die Bank im Soll steht. Der Vorsteuer-Split
///   lässt sich in einer Zeile nicht invertieren (die SaldoExpansion wählt
///   den Zweig nach Konto-Klasse) → brutto ohne Split buchen; die MwSt ist
///   im Einzelfall manuell zu prüfen (Hinweis in den Notizen).
Map<String, dynamic> ausgabeBuchungsFelder({
  required double betrag,
  required bool isCredit,
  required double mwstSatz,
  required int vorlageSoll,
  required int vorlageHaben,
  int? vorlageMwstKonto,
}) {
  final brutto = _round2(betrag);
  if (isCredit) {
    return {
      'soll_konto': vorlageHaben,
      'haben_konto': vorlageSoll,
      'mwst_konto': null,
      'betrag_netto': brutto,
      'mwst_satz': 0,
      'mwst_betrag': 0.0,
      'betrag_brutto': brutto,
    };
  }
  final netto = mwstSatz > 0 ? _round2(brutto / (1 + mwstSatz / 100)) : brutto;
  return {
    'soll_konto': vorlageSoll,
    'haben_konto': vorlageHaben,
    'mwst_konto': vorlageMwstKonto,
    'betrag_netto': netto,
    'mwst_satz': mwstSatz,
    'mwst_betrag': _round2(brutto - netto),
    'betrag_brutto': brutto,
  };
}

/// Bucht eine Ausgabe/Bargeld-Transaktion aus camt anhand einer Buchungsvorlage.
/// Erzeugt EINE Buchung (Brutto/Netto/MwSt in einer Zeile) und stempelt den
/// camt_tx_key direkt für robusten Dedup.
class CamtAusgabeBooker {
  static Future<Buchung> book(CamtTransaction tx, BuchungsVorlage vorlage) async {
    final konten = kontenFuerCamt(vorlage);
    final felder = ausgabeBuchungsFelder(
      betrag: tx.amount,
      isCredit: tx.isCredit,
      mwstSatz: vorlage.mwstSatz ?? 0,
      vorlageSoll: konten.sollKonto,
      vorlageHaben: konten.habenKonto,
      vorlageMwstKonto: konten.mwstKonto,
    );
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;
    final beschreibung = tx.partyName != null
        ? '${tx.isCredit ? "Zahlung" : "Belastung"} ${tx.partyName}'
        : (tx.additionalInfo ?? vorlage.bezeichnung);
    final notizen = <String>[
      if (tx.isCredit)
        'GUTSCHRIFT auf Ausgabe-Regel (Konten getauscht) — MwSt manuell prüfen',
      if (tx.strukturierteReferenz != null) 'Ref: ${tx.strukturierteReferenz}',
      if (tx.partyIban != null) 'IBAN: ${tx.partyIban}',
    ].join('\n');

    return BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': tx.accountServiceRef,
      'vorlage_id': vorlage.id,
      ...felder,
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
