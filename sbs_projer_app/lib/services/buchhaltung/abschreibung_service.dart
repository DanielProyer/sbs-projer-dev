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
}
