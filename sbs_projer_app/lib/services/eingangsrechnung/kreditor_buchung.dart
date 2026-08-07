/// Reine Berechnungslogik für die Kreditoren-Buchung (Stufe 1) einer
/// Eingangsrechnung nach der Bruttomethode.
///
/// Liefert EINE Buchungszeile: Aufwand (brutto) an Kreditor (2000), mit
/// `mwstKonto` = Vorsteuerkonto — die SaldoExpansion teilt daraus Netto/
/// Vorsteuer/Brutto auf. Die frühere zweite Zeile (Vorsteuer an Aufwand)
/// verdoppelte die Vorsteuer (Befund B1, Buchhaltungsprüfung 06.08.2026).
class KreditorBuchungZeile {
  final int sollKonto;
  final int habenKonto;
  final double betragNetto;
  final double mwstSatz;
  final double mwstBetrag;
  final double betragBrutto;
  final int? mwstKonto;
  final String beschreibung;

  const KreditorBuchungZeile({
    required this.sollKonto,
    required this.habenKonto,
    required this.betragNetto,
    required this.mwstSatz,
    required this.mwstBetrag,
    required this.betragBrutto,
    required this.mwstKonto,
    required this.beschreibung,
  });
}

/// Berechnet die Buchungszeilen für eine Kreditoren-Rechnung (Bruttomethode).
List<KreditorBuchungZeile> kreditorBuchungsZeilen({
  required double brutto,
  required double mwstSatz,
  required int aufwandskonto,
  required int? vorsteuerKonto,
  int kreditorKonto = 2000,
  required String beschreibung,
}) {
  final netto = double.parse(
    (mwstSatz > 0 ? brutto / (1 + mwstSatz / 100) : brutto).toStringAsFixed(2),
  );
  final mwstBetrag = double.parse((brutto - netto).toStringAsFixed(2));

  final zeile1 = KreditorBuchungZeile(
    sollKonto: aufwandskonto,
    habenKonto: kreditorKonto,
    betragNetto: netto,
    mwstSatz: mwstSatz,
    mwstBetrag: mwstBetrag,
    betragBrutto: brutto,
    mwstKonto: mwstBetrag > 0 ? vorsteuerKonto : null,
    beschreibung: beschreibung,
  );

  return [zeile1];
}
