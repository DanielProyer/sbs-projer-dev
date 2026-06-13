/// Verteilt eine Buchung MWST-korrekt auf die beteiligten Konten und trägt die
/// Beiträge als Roh-Saldo (Σ Soll − Σ Haben) in [saldi] ein.
///
/// Klassifikation: mwstKonto Klasse 1 (1000–1999) = Vorsteuer (Soll-seitig);
/// sonst (≥2000) = Umsatzsteuer (Haben-seitig).
class SaldoExpansion {
  static void apply(
    Map<int, double> saldi, {
    required int sollKonto,
    required int habenKonto,
    int? mwstKonto,
    required double betragNetto,
    required double mwstBetrag,
    required double betragBrutto,
  }) {
    void add(int k, double v) => saldi[k] = (saldi[k] ?? 0) + v;

    // Invariante: brutto = netto + mwst (sonst werden die Salden unausgeglichen).
    assert((betragBrutto - betragNetto - mwstBetrag).abs() < 0.005,
        'betragBrutto ($betragBrutto) != netto+mwst (${betragNetto + mwstBetrag})');

    if (mwstBetrag == 0 || mwstKonto == null) {
      add(sollKonto, betragBrutto);
      add(habenKonto, -betragBrutto);
      return;
    }

    final istVorsteuer = mwstKonto ~/ 1000 == 1;
    if (istVorsteuer) {
      add(sollKonto, betragNetto);
      add(mwstKonto, mwstBetrag);
      add(habenKonto, -betragBrutto);
    } else {
      add(sollKonto, betragBrutto);
      add(mwstKonto, -mwstBetrag);
      add(habenKonto, -betragNetto);
    }
  }
}
