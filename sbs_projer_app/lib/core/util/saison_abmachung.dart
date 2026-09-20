/// Abmachung mit dem Wirt über die nächste Eröffnungs- oder Endreinigung.
///
/// **Warum (Daniel, 20.09.2026):** Beim Reinigen vor Ort ist der Moment, um
/// zu fragen «wann macht ihr zu, wann wieder auf?» — und gleich abzumachen,
/// wann er zur Saisonreinigung kommen darf. Das ist oft kein fixer Termin:
/// Mal «Dienstag um acht», mal «die ganze Woche geht», mal «die ganze
/// Zwischensaison ist jemand da».
library;

/// Wie fest die Abmachung ist. Entspricht `termine.spielraum`
/// (Migration 199).
enum Spielraum {
  /// Genau an diesem Tag, gegebenenfalls zu dieser Uhrzeit.
  fix,

  /// Irgendwann in dieser Woche — sieben Tage ab dem gewählten Tag.
  woche,

  /// Jederzeit während der Zwischensaison; es ist jemand da.
  zwischensaison,
}

extension SpielraumText on Spielraum {
  String get dbWert => switch (this) {
    Spielraum.fix => 'fix',
    Spielraum.woche => 'woche',
    Spielraum.zwischensaison => 'zwischensaison',
  };

  String get label => switch (this) {
    Spielraum.fix => 'Genau dann',
    Spielraum.woche => 'Ganze Woche',
    Spielraum.zwischensaison => 'Ganze Zwischensaison',
  };

  String get erklaerung => switch (this) {
    Spielraum.fix => 'Ein fester Tag, auf Wunsch mit Uhrzeit.',
    Spielraum.woche => 'Sieben Tage ab dem gewählten Tag — such dir einen aus.',
    Spielraum.zwischensaison =>
      'Die ganze Zwischensaison ist jemand da. Zeitraum kommt aus den '
          'Saisondaten.',
  };
}

/// Ein Zeitraum von–bis (beide Tage eingeschlossen).
typedef Zeitraum = ({DateTime von, DateTime bis});

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Die nächste Zwischensaison aus den erfassten Saisondaten.
///
/// Eine Zwischensaison ist die Lücke zwischen dem Ende der einen und dem
/// Start der anderen Saison — im Frühling zwischen Winterende und
/// Sommerstart, im Herbst zwischen Sommerende und Winterstart. Gesucht ist
/// die **nächste**, die nach [heute] beginnt oder gerade läuft.
///
/// `null`, wenn sich keine berechnen lässt: weil eine der beiden Saisons
/// fehlt, weil ein Datum fehlt, oder weil zwischen Ende und Start kein Tag
/// liegt (nahtloser Übergang — dann gibt es keine Zwischensaison, siehe
/// «Keine Herbstpause»).
///
/// **Grenze der Datenlage, bewusst so:** Der Betrieb hält je Saison nur EIN
/// Fenster. Endet der Winter am 01.04.2027 und steht beim Sommer noch das
/// Fenster von 2026, lässt sich die Frühlingspause 2027 nicht berechnen —
/// der Sommerstart 2027 ist schlicht noch nicht bekannt. Dann kommt `null`
/// zurück, und der Spielraum «ganze Zwischensaison» steht nicht zur
/// Verfügung, bis die neuen Daten erfasst sind. Lieber keine Angabe als eine
/// erfundene.
Zeitraum? naechsteZwischensaison({
  required bool winterAktiv,
  required DateTime? winterStart,
  required DateTime? winterEnde,
  required bool sommerAktiv,
  required DateTime? sommerStart,
  required DateTime? sommerEnde,
  required DateTime heute,
}) {
  final h = _tag(heute);
  final kandidaten = <Zeitraum>[];

  void pruefe(DateTime? ende, DateTime? start) {
    if (ende == null || start == null) return;
    final von = _tag(ende).add(const Duration(days: 1));
    final bis = _tag(start).subtract(const Duration(days: 1));
    if (bis.isBefore(von)) return; // nahtlos oder verdreht
    if (bis.isBefore(h)) return; // schon vorbei
    kandidaten.add((von: von, bis: bis));
  }

  if (winterAktiv && sommerAktiv) {
    pruefe(winterEnde, sommerStart); // Frühlingspause
    pruefe(sommerEnde, winterStart); // Herbstpause
  }
  if (kandidaten.isEmpty) return null;
  kandidaten.sort((a, b) => a.von.compareTo(b.von));
  return kandidaten.first;
}

/// Der Zeitraum, der als Termin gespeichert wird.
///
/// `bis` ist `null` bei [Spielraum.fix] — dort ist der Termin eintägig und
/// `termine.datum_bis` bleibt leer.
Zeitraum? terminZeitraum({
  required Spielraum spielraum,
  required DateTime? datum,
  required Zeitraum? zwischensaison,
}) {
  switch (spielraum) {
    case Spielraum.fix:
      return datum == null ? null : (von: _tag(datum), bis: _tag(datum));
    case Spielraum.woche:
      if (datum == null) return null;
      final von = _tag(datum);
      return (von: von, bis: von.add(const Duration(days: 6)));
    case Spielraum.zwischensaison:
      return zwischensaison;
  }
}

/// Titel des Termins — steht so im Google Kalender hinter «SBS · ».
String abmachungTitel({required bool endreinigung, required Spielraum s}) {
  final art = endreinigung ? 'Endreinigung' : 'Eröffnungsreinigung';
  return switch (s) {
    Spielraum.fix => art,
    Spielraum.woche => '$art (ganze Woche)',
    Spielraum.zwischensaison => '$art (ganze Zwischensaison)',
  };
}
