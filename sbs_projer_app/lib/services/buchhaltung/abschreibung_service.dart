import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';

class AbschreibungSplit {
  final double netto;
  final double mwst;
  const AbschreibungSplit(this.netto, this.mwst);
}

class AbschreibungService {
  /// Netto/MWST aus Brutto + Satz (mwst = Residuum, keine Drift).
  static AbschreibungSplit split(double brutto, double satz) {
    if (satz <= 0) return AbschreibungSplit(brutto, 0);
    final netto = (brutto / (1 + satz / 100) * 100).roundToDouble() / 100;
    final mwst = ((brutto - netto) * 100).roundToDouble() / 100;
    return AbschreibungSplit(netto, mwst);
  }

  /// Schreibt einen Debitor-Brutto-Betrag ab: Soll 3805/Haben 1100 (netto)
  /// + Soll 2200/Haben 1100 (MWST-Rückholung), rückdatiert auf [datum].
  ///
  /// [mwst] ist die auf der Rechnung ausgewiesene Steuer
  /// (`rechnungen.mwst_betrag`) — die Rückholung darf nur holen, was damals
  /// abgeliefert wurde. Ohne [mwst] (Pauschalbeträge ohne Rechnung) wird der
  /// Satz per [datum] genommen; für Altjahrgänge wäre das falsch (7.7 %
  /// bis 2023, 8.1 % danach — docs/buchhaltung/abschreibungen-jahrgaenge.md).
  static Future<void> abschreiben({
    required double brutto,
    required DateTime datum,
    required String beschreibung,
    String? belegnummer,
    String? belegId,
    double? mwst,
  }) async {
    final AbschreibungSplit s;
    if (mwst != null) {
      s = AbschreibungSplit(
        ((brutto - mwst) * 100).roundToDouble() / 100,
        (mwst * 100).roundToDouble() / 100,
      );
    } else {
      final satz = await MwstSatzService.satzFuerDatum(datum);
      s = split(brutto, satz);
    }
    final d = datum.toIso8601String().split('T').first;

    await BuchungRepository.create({
      'datum': d,
      'belegnummer': belegnummer,
      'soll_konto': 3805,
      'haben_konto': 1100,
      'betrag_netto': s.netto,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': s.netto,
      'beschreibung': beschreibung,
      'zahlungsweg': 'intern',
      'beleg_typ': 'abschreibung',
      'beleg_id': belegId,
      'geschaeftsjahr': datum.year,
      'notizen': 'Phase2c Abschreibung (netto)',
    });

    if (s.mwst > 0) {
      await BuchungRepository.create({
        'datum': d,
        'belegnummer': belegnummer,
        'soll_konto': 2200,
        'haben_konto': 1100,
        'betrag_netto': s.mwst,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': s.mwst,
        'beschreibung': '$beschreibung — MWST-Rückholung',
        'zahlungsweg': 'intern',
        'beleg_typ': 'abschreibung',
        'beleg_id': belegId,
        'geschaeftsjahr': datum.year,
        'notizen': 'Phase2c Abschreibung (MWST-Rückholung)',
      });
    }
  }

  /// Setzt das Delkredere (Konto 1109, Aktiv-Minus) auf [zielWertberichtigung]
  /// (positiv = gewünschte Wertberichtigung) durch Buchung der Differenz.
  static Future<void> delkredereSetzen({
    required double zielWertberichtigung,
    required DateTime datum,
  }) async {
    final saldi = await BuchungService.getAllSaldi();
    // 1109 ist Klasse 1 → Anzeige-Saldo = Roh (Soll−Haben). Wertberichtigung
    // (Haben-Überhang) erscheint als negativer Anzeige-Saldo.
    final aktuelleWb = -(saldi[1109] ?? 0);
    final diff = zielWertberichtigung - aktuelleWb;
    final betrag = (diff.abs() * 100).roundToDouble() / 100;
    if (betrag < 0.01) return;
    final d = datum.toIso8601String().split('T').first;
    await BuchungRepository.create({
      'datum': d,
      'soll_konto': diff > 0 ? 3805 : 1109,
      'haben_konto': diff > 0 ? 1109 : 3805,
      'betrag_netto': betrag,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': betrag,
      'beschreibung':
          'Delkredere-Anpassung (Ziel ${zielWertberichtigung.toStringAsFixed(2)})',
      'zahlungsweg': 'intern',
      'beleg_typ': 'abschreibung',
      'geschaeftsjahr': datum.year,
      'notizen': 'Phase2c Delkredere',
    });
  }
}
