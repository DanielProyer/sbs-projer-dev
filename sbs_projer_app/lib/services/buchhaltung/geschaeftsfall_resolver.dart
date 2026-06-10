import '../../data/models/buchungs_vorlage.dart';

/// Aufgelöste Konten einer Buchung.
class AufgeloesteBuchung {
  final int sollKonto;
  final int habenKonto;
  final int? mwstKonto;
  const AufgeloesteBuchung(this.sollKonto, this.habenKonto, this.mwstKonto);
}

/// Löst Geschäftsfall (was) + Zahlungsweg (wie) zu Soll/Haben/MWST auf.
class GeschaeftsfallResolver {
  /// Zahlungsweg → Gegenkonto.
  static int gegenkonto(String zahlungsweg) {
    switch (zahlungsweg) {
      case 'kasse':
        return 1000;
      case 'bank':
        return 1020;
      case 'privat':
        return 2260;
      case 'kreditor':
        return 2000;
      case 'debitor':
        return 1100;
      default:
        throw ArgumentError('Unbekannter Zahlungsweg: $zahlungsweg');
    }
  }

  static AufgeloesteBuchung aufloesen(BuchungsVorlage v, String? zahlungsweg) {
    switch (v.art) {
      case 'fix':
        return AufgeloesteBuchung(v.sollKonto!, v.habenKonto!, v.mwstKonto);
      case 'ausgabe':
        final g = gegenkonto(zahlungsweg!);
        return AufgeloesteBuchung(v.hauptkonto!, g, v.mwstKonto);
      case 'einnahme':
        final g = gegenkonto(zahlungsweg!);
        return AufgeloesteBuchung(g, v.hauptkonto!, v.mwstKonto);
      default:
        throw ArgumentError('Unbekannte Geschäftsfall-Art: ${v.art}');
    }
  }
}
