import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';

/// Stufe 2 des Kreditorenmodells: bucht die Bank-Belastung einer Lieferanten-
/// zahlung (Kreditorkonto → Bank 1020) und setzt die Eingangsrechnung auf
/// 'bezahlt'. Idempotent: existiert bereits eine Zahlungs-Buchung zum Beleg,
/// passiert nichts. `camt_tx_key` wird auf Buchung UND Eingangsrechnung
/// gestempelt (Reversibilität, TP-6).
class CamtKreditorBooker {
  static const int bankKonto = 1020;
  static const int kreditorKontoDefault = 2000;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static Future<void> book(CamtTransaction tx, Eingangsrechnung e) async {
    // Idempotenz: bereits eine Zahlungs-Buchung (Stufe 2) zu diesem Beleg?
    // Sichtbar machen statt still schlucken (sonst würde eine zweite reale
    // Belastung lautlos verschwinden) — kein Doppelbuchen.
    // Aktive Zahlungs-Buchung = beleg_typ 'zahlung', nicht storniert UND keine
    // Storno-Gegenbuchung (stornoVonId==null) — sonst würde nach einem Storno
    // die Gegenbuchung ein erneutes Matching fälschlich blockieren.
    final existing = await BuchungRepository.getByBeleg(e.id);
    if (existing.any((b) =>
        b.belegTyp == 'zahlung' &&
        !b.istStorniert &&
        b.stornoVonId == null)) {
      throw StateError(
          'Kreditor "${e.ausstellerName ?? e.id}" ist bereits als bezahlt gebucht.');
    }

    // Kreditorkonto aus der Stufe-1-Buchung lesen (robust ggü. künftigen
    // Sonderkonten; heute stets 2000): die erste Stufe-1-Zeile bucht
    // Aufwand (soll) AN Kreditorkonto (haben).
    int kreditorKonto = kreditorKontoDefault;
    if (e.buchungStufe1Id != null) {
      final stufe1 = await BuchungRepository.getById(e.buchungStufe1Id!);
      if (stufe1 != null) kreditorKonto = stufe1.habenKonto;
    }

    final brutto = _round2(e.betragBrutto);
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;

    final buchung = await BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': e.rechnungsnummer,
      'soll_konto': kreditorKonto,
      'haben_konto': bankKonto,
      'betrag_netto': brutto,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': brutto,
      'beschreibung': 'Zahlung Kreditor ${e.ausstellerName ?? ''}'.trim(),
      'zahlungsweg': 'bank',
      'beleg_typ': 'zahlung',
      'beleg_id': e.id,
      'geschaeftsjahr': tx.bookingDate.year,
      'camt_tx_key': tx.txKey,
    });

    await EingangsrechnungRepository.update(e.id, {
      'status': 'bezahlt',
      'bezahlt_am': datumStr,
      'buchung_stufe2_id': buchung.id,
      'camt_tx_key': tx.txKey,
    });
  }
}
