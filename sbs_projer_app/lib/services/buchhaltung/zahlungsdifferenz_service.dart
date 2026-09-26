import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

/// Einzelne Verrechnungsbuchung über Kundenguthaben (Mahnwesen,
/// Abschreibung).
///
/// Zahlungseingänge (Bank, Kasse, Guthaben voll) laufen seit Runde 3
/// ausschliesslich über `ZahlungKern.erfassen` (services/rechnung/
/// zahlung_kern.dart) — die früheren `verbuchen`/`verbuchenSammel` schrieben
/// Buchung für Buchung ohne Transaktion und sind entfernt.
class ZahlungsdifferenzService {
  static String _alsText(DateTime d) => d.toIso8601String().split('T').first;

  /// Verrechnungsbuchung Soll 2030 / Haben 1100 über das Guthaben der Rechnung
  /// (auch vom Abschreiben).
  static Future<Buchung> verrechnungBuchen(
      Rechnung rechnung, double betrag, DateTime datum) {
    final rgNr = rechnung.rechnungsnummer ?? '';
    return BuchungRepository.create({
      'datum': _alsText(datum),
      'belegnummer': rgNr,
      'soll_konto': kKontoKundenguthaben,
      'haben_konto': 1100,
      'betrag_netto': betrag,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': betrag,
      'beschreibung': 'Verrechnung Kundenguthaben $rgNr',
      'zahlungsweg': 'intern',
      'beleg_typ': 'sonstiges',
      'beleg_id': rechnung.id,
      'geschaeftsjahr': datum.year,
    });
  }
}
