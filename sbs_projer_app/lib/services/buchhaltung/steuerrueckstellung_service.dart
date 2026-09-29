import 'package:sbs_projer_app/core/util/abschluss_belegnummer.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/steuerrueckstellung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

/// Jahresabschluss Schritt D: Steuerrückstellung (8900 an 2208 per 31.12.).
///
/// Bis 29.09.2026 per SQL gebucht (JA2025_D, JA2025_D2 vorbereitet in
/// docs/buchhaltung/jahresabschluss-2025.md Abschnitt 9d). Die Rechnung
/// selbst steht in `core/util/steuerrueckstellung.dart`.
class SteuerrueckstellungService {
  /// Lage des Jahres [jahr] aus dem schon geladenen Journal.
  ///
  /// WARUM das Journal als Parameter statt `lage(int jahr)` mit eigenem
  /// Laden: Der Aufrufer hält es ohnehin (`buchungenStreamProvider`); ein
  /// zweiter Voll-Load wären ~17 Seiten à 1000 Zeilen für dieselben Daten
  /// (siehe `bilanzStichtagProvider`).
  static SteuerrueckstellungLage lage(List<Buchung> journal, int jahr) {
    final input = journal.map(BuchungSaldo.ausBuchung).toList();
    return rueckstellungLageAusSaldi(
      saldiBis: BilanzService.saldiPerStichtag(input, DateTime(jahr, 12, 31)),
      saldiVor: BilanzService.saldiPerStichtag(
        input,
        DateTime(jahr - 1, 12, 31),
      ),
      gebucht: rueckstellungGebucht(journal, jahr),
      bussen8900: bussenAuf8900(journal, jahr),
    );
  }

  /// Bucht die Differenz von [gebucht] auf [ziel] per 31.12.[jahr]:
  /// Aufbau 8900 an 2208, Abbau 2208 an 8900. Unter 0.01 nichts.
  static Future<void> buchen({
    required int jahr,
    required double ziel,
    required double gebucht,
    required String begruendung,
  }) async {
    if (rueckstellungBuchung(ziel: ziel, gebucht: gebucht).betrag < 0.01) {
      return;
    }
    final basis = abschlussBelegBasis(jahr, 'D');
    final vorhandene = await BuchungRepository.belegnummernMitPraefix(basis);
    final zeile = buchungszeile(
      jahr: jahr,
      ziel: ziel,
      gebucht: gebucht,
      begruendung: begruendung,
      belegnummer: naechsteAbschlussBelegnummer(basis, vorhandene),
    );
    if (zeile != null) await BuchungRepository.create(zeile);
  }

  /// Buchungszeile zu [buchen] — rein, damit Konten, Datum und Texte testbar
  /// sind. `null`, wenn nichts zu buchen ist.
  static Map<String, dynamic>? buchungszeile({
    required int jahr,
    required double ziel,
    required double gebucht,
    required String begruendung,
    required String belegnummer,
  }) {
    final b = rueckstellungBuchung(ziel: ziel, gebucht: gebucht);
    if (b.betrag < 0.01) return null;
    return {
      'datum': '$jahr-12-31',
      'belegnummer': belegnummer,
      'soll_konto': b.aufbau ? kKontoSteueraufwand : kKontoSteuerrueckstellung,
      'haben_konto': b.aufbau ? kKontoSteuerrueckstellung : kKontoSteueraufwand,
      'betrag_netto': b.betrag,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': b.betrag,
      'beschreibung':
          'Steuerrückstellung $jahr auf ${chf(ziel)} '
          '(bisher ${chf(gebucht)})',
      'zahlungsweg': 'intern',
      // 31.12. + Geschäftsjahr + 8900 ↔ 2208: daran erkennt
      // `istRueckstellungsbuchung` die Rückstellung des Jahres wieder.
      // «abschluss» wie JA2025_D: markiert das Jahr als abgeschlossen
      // (geschaeftsjahr_abgeschlossen, Migration 209/216).
      'beleg_typ': 'abschluss',
      'geschaeftsjahr': jahr,
      'notizen': 'Jahresabschluss $jahr Schritt D (App): $begruendung',
    };
  }
}
