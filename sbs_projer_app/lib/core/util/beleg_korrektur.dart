// Reine Rechen- und Prüflogik rund um den Spesenbeleg-Scan.

/// Schweizer 5-Rappen-Rundung.
double runde5Rappen(double betrag) => (betrag * 20).roundToDouble() / 20;

double _zwei(double v) => double.parse(v.toStringAsFixed(2));

/// Verteilt die 5-Rappen-Rundung einer Barzahlung auf die Positionen.
///
/// Gerundet wird ausschliesslich das **Beleg-Total** — die Differenz erhält
/// die grösste Position. Würde jede Position einzeln gerundet, liefe die
/// Summe vom tatsächlich bezahlten Betrag weg und erzeugte Kassendifferenzen
/// (Coop Pronto: 89.70 + 6.75 + 10.10 = 106.55 statt 106.53).
List<double> verteileBarRundung(List<double> betraege) {
  if (betraege.isEmpty) return [];

  final positionen = betraege.map(_zwei).toList();
  final summe = positionen.reduce((a, b) => a + b);
  final differenz = _zwei(runde5Rappen(summe) - summe);
  if (differenz == 0) return positionen;

  var groesster = 0;
  for (var i = 1; i < positionen.length; i++) {
    if (positionen[i] > positionen[groesster]) groesster = i;
  }
  positionen[groesster] = _zwei(positionen[groesster] + differenz);
  return positionen;
}

/// Abweichung zwischen Positionssumme und erfasstem Beleg-Total.
/// Positiv = Positionen ergeben weniger als das Total. Unter einem halben
/// Rappen (reines Rundungsrauschen) gilt der Beleg als stimmig -> null.
double? differenzZumTotal(List<double> betraege, double total) {
  final summe = betraege.fold<double>(0, (s, b) => s + b);
  final differenz = total - summe;
  return differenz.abs() < 0.005 ? null : differenz;
}

/// Ist die Erfassung belastbar?
///
/// Die Selbsteinschätzung des Modells ist das schwächere Signal — es meldet
/// auch bei einwandfrei gelesenen Belegen gerne 0.80–0.85 (gemeldet Daniel
/// 28.07.2026). Deckt sich die Summe der Positionen dagegen mit dem
/// gedruckten Total, ist der Beleg rechnerisch schlüssig: jeder Lesefehler in
/// einem Betrag würde die Summe verschieben. Diese Probe schlägt darum die
/// Konfidenz — ausser das Bild war so schlecht, dass auch das Total geraten
/// sein könnte (< 0.5).
bool belegStimmig(double konfidenz, List<double> betraege, double total) {
  if (betraege.isEmpty) return false;
  if (konfidenz >= 0.85) return true;
  if (konfidenz < 0.5) return false;

  // 5 Rappen Toleranz: bei Barzahlung ist das gedruckte Total gerundet.
  final summe = betraege.fold<double>(0, (s, b) => s + b);
  return (summe - total).abs() <= 0.05;
}

/// Eine bereits gebuchte Spesen-Position desselben Belegdatums.
class DublettenKandidat {
  final String beschreibung;
  final double brutto;

  const DublettenKandidat({required this.beschreibung, required this.brutto});
}

/// Erkennt, ob ein Beleg an diesem Datum schon einmal gebucht wurde:
/// gleiches Geschäft (Beschreibung beginnt mit dem Namen) und gleiche Summe.
///
/// Bewusst keine harte Sperre — zweimal am selben Tag bei derselben
/// Tankstelle zu tanken ist ein echter Fall. Toleranz 5 Rappen wegen der
/// Barzahlungs-Rundung.
bool dublettenTreffer(
  List<DublettenKandidat> kandidaten,
  String geschaeft,
  double total,
) {
  final name = geschaeft.trim().toLowerCase();
  if (name.isEmpty) return false;

  final summe = kandidaten
      .where((k) => k.beschreibung.toLowerCase().startsWith(name))
      .fold<double>(0, (s, k) => s + k.brutto);

  return summe > 0 && (summe - total).abs() <= 0.05;
}
