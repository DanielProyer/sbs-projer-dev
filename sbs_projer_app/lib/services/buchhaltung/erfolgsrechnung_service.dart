import 'bilanz_service.dart' show BuchungSaldo;

/// Ergebnis der KMU-Stufengliederung.
class ErfolgsrechnungDaten {
  final double nettoerloes;
  final double materialaufwand;
  final double personalaufwand;
  final double uebrigerAufwand; // 6000–6799
  final double abschreibungen; // 6800–6899
  final double finanzerfolg; // 6900–6999, negativ wenn Aufwand überwiegt
  final double nebenerfolg; // Klasse 7 (Ertrag) − 8000–8899 (Aufwand)
  final double steuern; // 8900–8999
  const ErfolgsrechnungDaten({
    required this.nettoerloes,
    required this.materialaufwand,
    required this.personalaufwand,
    required this.uebrigerAufwand,
    required this.abschreibungen,
    required this.finanzerfolg,
    required this.nebenerfolg,
    required this.steuern,
  });

  double get bruttoergebnis1 => nettoerloes - materialaufwand;
  double get bruttoergebnis2 => bruttoergebnis1 - personalaufwand;
  double get ebitda => bruttoergebnis2 - uebrigerAufwand;
  double get ebit => ebitda - abschreibungen;
  double get ebt => ebit + finanzerfolg;
  double get jahresergebnis => ebt + nebenerfolg - steuern;
}

class ErfolgsrechnungService {
  /// Aufwand-Saldo (Soll−Haben) über einen Kontonummer-Bereich [von,bis].
  static double _aufwand(Map<int, double> sollMinusHaben, int von, int bis) {
    double s = 0;
    sollMinusHaben.forEach((nr, v) {
      if (nr >= von && nr <= bis) s += v;
    });
    return s;
  }

  static ErfolgsrechnungDaten berechne(
    List<BuchungSaldo> buchungen, {
    required DateTime von,
    required DateTime bis,
  }) {
    final shm = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert) continue;
      if (b.datum.isBefore(von) || b.datum.isAfter(bis)) continue;
      shm[b.sollKonto] = (shm[b.sollKonto] ?? 0) + b.betrag;
      shm[b.habenKonto] = (shm[b.habenKonto] ?? 0) - b.betrag;
    }

    final nettoerloes = -_aufwand(shm, 3000, 3999);
    final material = _aufwand(shm, 4000, 4999);
    final personal = _aufwand(shm, 5000, 5999);
    final uebrig = _aufwand(shm, 6000, 6799);
    final abschreib = _aufwand(shm, 6800, 6899);
    final finanzAufwand = _aufwand(shm, 6900, 6999);
    final nebenErtrag = -_aufwand(shm, 7000, 7999);
    final nebenAufwand = _aufwand(shm, 8000, 8899);
    final steuern = _aufwand(shm, 8900, 8999);

    return ErfolgsrechnungDaten(
      nettoerloes: nettoerloes,
      materialaufwand: material,
      personalaufwand: personal,
      uebrigerAufwand: uebrig,
      abschreibungen: abschreib,
      finanzerfolg: -finanzAufwand,
      nebenerfolg: nebenErtrag - nebenAufwand,
      steuern: steuern,
    );
  }
}
