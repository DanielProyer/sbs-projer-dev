import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditor_buchung.dart';

/// Bucht eine Eingangsrechnung als Kreditor (Stufe 1, Bruttomethode).
///
/// Erstellt die Aufwand-an-Kreditor-Buchung (plus Vorsteuer-Korrektur, falls
/// MwSt-pflichtig) und stempelt die Eingangsrechnung auf Status `gebucht`.
class EingangsrechnungBuchungService {
  /// Stufe 1: Aufwand an Kreditoren (2000) verbuchen.
  ///
  /// Wirft, wenn kein Aufwandskonto gesetzt ist.
  static Future<void> bucheStufe1(Eingangsrechnung e) async {
    if (e.aufwandskonto == null) {
      throw Exception('Aufwandskonto fehlt');
    }

    // Idempotenz: nicht erneut Stufe-1 buchen, wenn bereits eine aktive
    // Aufwand-an-Kreditor-Buchung existiert (verhindert Doppel-Aufwand, z.B.
    // nach einem Zahlung-Rückgängig, wenn die Rechnung wieder 'gebucht' ist).
    final bestehend = await BuchungRepository.getByBeleg(e.id);
    if (bestehend.any((b) => b.belegTyp == 'eingang' && !b.istStorniert)) {
      throw Exception('Eingangsrechnung ist bereits gebucht (Stufe 1)');
    }

    final basisDatum = e.rechnungsdatum ?? DateTime.now();
    final datumStr = basisDatum.toIso8601String().split('T').first;
    final jahr = basisDatum.year;

    final zeilen = kreditorBuchungsZeilen(
      brutto: e.betragBrutto,
      mwstSatz: e.mwstSatz ?? 0,
      aufwandskonto: e.aufwandskonto!,
      vorsteuerKonto: e.vorsteuerKonto,
      beschreibung: e.ausstellerName ?? 'Eingangsrechnung',
    );

    String? erstesId;
    for (final z in zeilen) {
      final b = await BuchungRepository.create({
        'datum': datumStr,
        'soll_konto': z.sollKonto,
        'haben_konto': z.habenKonto,
        'betrag_netto': z.betragNetto,
        'mwst_satz': z.mwstSatz,
        'mwst_betrag': z.mwstBetrag,
        'betrag_brutto': z.betragBrutto,
        'mwst_konto': z.mwstKonto,
        'beschreibung': z.beschreibung,
        'zahlungsweg': 'kreditor',
        'beleg_typ': 'eingang',
        'beleg_id': e.id,
        'geschaeftsjahr': jahr,
      });
      erstesId ??= b.id;
    }

    await EingangsrechnungRepository.update(e.id, {
      'status': 'gebucht',
      'gebucht_am': DateTime.now().toIso8601String(),
      'zahlung_vorgemerkt': true,
      'buchung_stufe1_id': erstesId,
    });
  }
}
