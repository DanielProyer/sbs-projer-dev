/// Wächter vor der Freigabe einer Heineken-Monatsrechnung.
///
/// WARUM es das gibt (22.09.2026): Bei der August-Rechnung stand in
/// `rechnungs_positionen` unter «Störungen» 3'434.60, während das versendete
/// PDF 3'184.60 nannte — 250.00 zu viel. Mai bis Juli waren sauber. Ob das ein
/// Einzelfall war oder ein Fehler im Code, ist bis heute offen.
///
/// Der Freigabe-Schritt ist die Stelle, an der aus einem Anzeigefehler echtes
/// Geld wird: Dort entsteht die Debitoren- und Ertragsbuchung, und zwar aus dem
/// DATENSATZ, nicht aus dem PDF. Steht dort ein falscher Betrag, wandert er in
/// die Bücher, und beim Zahlungseingang bleibt ein unerklärlicher Rest offen.
///
/// Deshalb: vor der Freigabe die Positionen aus den Quelldaten neu rechnen und
/// gegen die gespeicherten halten.
library;

/// Eine Kategorie, deren gespeicherter Betrag nicht zur Neuberechnung passt.
class PositionsAbweichung {
  final String kategorie;

  /// Was in `rechnungs_positionen` steht — daraus entsteht die Buchung.
  final double aufRechnung;

  /// Was die Quelldaten heute ergeben.
  final double neuBerechnet;

  const PositionsAbweichung({
    required this.kategorie,
    required this.aufRechnung,
    required this.neuBerechnet,
  });

  /// Positiv = auf der Rechnung steht MEHR als die Quelldaten hergeben.
  double get differenz => aufRechnung - neuBerechnet;
}

/// Rappen-Toleranz. Beträge laufen durch mehrere Rundungen; ein halber Rappen
/// Abweichung ist Rechenrauschen, kein Befund.
const double kPruefToleranz = 0.005;

/// Vergleicht die gespeicherten Positionen mit der Neuberechnung.
///
/// Beide Seiten sind `Kategoriename → Nettobetrag`. Eine Kategorie, die nur auf
/// einer Seite vorkommt, zählt auf der anderen als 0 — so fällt auch eine ganz
/// fehlende oder eine zusätzliche Position auf, nicht nur ein falscher Betrag.
///
/// Sortiert nach dem Betrag der Abweichung, absteigend: Der grösste Fehler
/// steht oben, nicht der alphabetisch erste.
List<PositionsAbweichung> positionsAbweichungen({
  required Map<String, double> gespeichert,
  required Map<String, double> berechnet,
  double toleranz = kPruefToleranz,
}) {
  final namen = <String>{...gespeichert.keys, ...berechnet.keys};
  final treffer = <PositionsAbweichung>[];
  for (final name in namen) {
    final a = gespeichert[name] ?? 0;
    final b = berechnet[name] ?? 0;
    if ((a - b).abs() <= toleranz) continue;
    treffer.add(
      PositionsAbweichung(kategorie: name, aufRechnung: a, neuBerechnet: b),
    );
  }
  treffer.sort((x, y) => y.differenz.abs().compareTo(x.differenz.abs()));
  return treffer;
}

/// Stimmt die Kopfsumme der Rechnung mit der Summe ihrer Positionen überein?
///
/// Eigene Prüfung neben [positionsAbweichungen]: Der Kopf trägt den Betrag,
/// den Heineken schuldet. Läuft er von den Positionen weg, stimmt die Rechnung
/// schon in sich nicht — unabhängig davon, ob die Positionen zu den Quelldaten
/// passen.
double kopfAbweichung({
  required double kopfNetto,
  required Map<String, double> gespeichert,
}) {
  final summe = gespeichert.values.fold<double>(0, (s, v) => s + v);
  return kopfNetto - summe;
}

/// Kurztext für den Bestätigungsdialog. Leer, wenn alles stimmt.
String abweichungsText(
  List<PositionsAbweichung> abw,
  double kopfDiff, {
  double toleranz = kPruefToleranz,
}) {
  final zeilen = <String>[];
  for (final a in abw) {
    zeilen.add(
      '${a.kategorie}: auf der Rechnung ${a.aufRechnung.toStringAsFixed(2)}, '
      'neu berechnet ${a.neuBerechnet.toStringAsFixed(2)} '
      '(${a.differenz > 0 ? '+' : ''}${a.differenz.toStringAsFixed(2)})',
    );
  }
  if (kopfDiff.abs() > toleranz) {
    zeilen.add(
      'Kopfsumme weicht um ${kopfDiff.toStringAsFixed(2)} von der Summe der '
      'Positionen ab',
    );
  }
  return zeilen.join('\n');
}
