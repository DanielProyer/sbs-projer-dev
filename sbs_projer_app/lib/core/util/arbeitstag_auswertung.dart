/// Auswertung der erfassten Arbeitstage (Arbeitszeit, Kilometer, Besuche).
///
/// Bewusst ohne Flutter-/Supabase-Abhängigkeiten: die Rechenregeln sind der
/// heikle Teil (unvollständige Tage!) und müssen ohne Widget-Test prüfbar sein.
library;

import 'package:sbs_projer_app/core/util/touren_anzeige.dart'
    show minutenAusHhmm;

/// Ein erfasster Tag, so wie ihn die Auswertung braucht.
///
/// `kmStart` = Zählerstand beim Arbeitsbeginn, `kmEnde` = Stand am Feierabend
/// (in der DB `km_stand`). Beide Namen bewusst symmetrisch, damit beim Rechnen
/// nicht wieder die historische Asymmetrie der Spaltennamen durchschlägt.
typedef Arbeitstagsdaten = ({
  DateTime datum,
  String? beginn,
  String? ende,
  int? kmStart,
  int? kmEnde,
  int besuche,
});

/// Ergebnis der Monatsauswertung. `null` heisst überall «nicht berechenbar»
/// (keine Grundlage vorhanden) — nicht «0», sonst zeigte der Screen einen
/// erfundenen Nullwert an, wo schlicht nichts erfasst wurde.
typedef ArbeitstagKennzahlen = ({
  int anzahlTage,
  int tageMitKm,
  int totalKm,
  double? schnittKm,
  int tageMitZeit,
  int totalMinuten,
  double? schnittMinuten,
  int anzahlBesuche,
  double? schnittBesuche,
  double? kmJeBesuch,
  double? minutenJeBesuch,
});

/// Gefahrene Kilometer eines Tages.
///
/// `null`, sobald einer der beiden Zählerstände fehlt oder der Abendstand
/// kleiner ist als der Morgenstand (Tippfehler — lieber keine Zahl als eine
/// negative, die die Monatssumme still verfälscht). Gleicher Stand = 0 km ist
/// ein gültiger Tag (nicht gefahren).
int? tagesKm({int? kmStart, int? kmEnde}) {
  if (kmStart == null || kmEnde == null) return null;
  if (kmEnde < kmStart) return null;
  return kmEnde - kmStart;
}

/// Gearbeitete Minuten eines Tages aus 'HH:mm'-Werten.
///
/// Über Mitternacht wird bewusst NICHT gerechnet: aus «22:00 bis 02:00» liesse
/// sich nicht unterscheiden, ob wirklich vier Stunden in die Nacht gearbeitet
/// wurde oder ob Beginn/Ende vertauscht erfasst wurden. Da der Aussendienst
/// tagsüber läuft, ist die Verwechslung der häufigere Fall — also `null`, und
/// der Tag fällt aus der Zeitstatistik statt sie zu verfälschen.
int? arbeitsMinuten({String? beginn, String? ende}) {
  final a = minutenAusHhmm(beginn);
  final b = minutenAusHhmm(ende);
  if (a == null || b == null) return null;
  if (b < a) return null;
  return b - a;
}

/// Hat der Tag überhaupt etwas Auswertbares? Steuert, welche Tage im Screen
/// erscheinen und was als «Arbeitstag» zählt.
bool hatErfassung(Arbeitstagsdaten t) =>
    t.besuche > 0 ||
    tagesKm(kmStart: t.kmStart, kmEnde: t.kmEnde) != null ||
    arbeitsMinuten(beginn: t.beginn, ende: t.ende) != null ||
    t.beginn != null ||
    t.ende != null ||
    t.kmStart != null ||
    t.kmEnde != null;

/// Summen und Durchschnitte über die übergebenen Tage.
///
/// **Regel für unvollständige Tage** (der Alltagsfall — Daniel erfasst mal nur
/// den km-Stand, mal nur den Feierabend): Ein Tag zählt für die km-Statistik
/// nur mit BEIDEN km-Ständen und für die Zeitstatistik nur mit BEIDEM,
/// Beginn und Ende. Deshalb hat jede Kennzahl ihren eigenen Nenner
/// ([tageMitKm], [tageMitZeit]) statt der Gesamtzahl der Tage — sonst würde
/// ein Tag mit nur halber Erfassung den Schnitt nach unten ziehen und die
/// Auswertung wäre bis zur lückenlosen Erfassung unbrauchbar.
///
/// Die Verhältniskennzahlen (km bzw. Minuten je Besuch) rechnen ebenfalls nur
/// über die jeweils vollständigen Tage — inklusive deren Besuchszahl. Ein Tag
/// mit km, aber ohne Besuch, würde «km je Besuch» sonst aufblähen.
ArbeitstagKennzahlen berechneKennzahlen(List<Arbeitstagsdaten> tage) {
  final relevant = tage.where(hatErfassung).toList();

  var tageMitKm = 0, totalKm = 0, besucheAnKmTagen = 0;
  var tageMitZeit = 0, totalMinuten = 0, besucheAnZeitTagen = 0;
  var anzahlBesuche = 0;

  for (final t in relevant) {
    anzahlBesuche += t.besuche;

    final km = tagesKm(kmStart: t.kmStart, kmEnde: t.kmEnde);
    if (km != null) {
      tageMitKm++;
      totalKm += km;
      besucheAnKmTagen += t.besuche;
    }

    final minuten = arbeitsMinuten(beginn: t.beginn, ende: t.ende);
    if (minuten != null) {
      tageMitZeit++;
      totalMinuten += minuten;
      besucheAnZeitTagen += t.besuche;
    }
  }

  return (
    anzahlTage: relevant.length,
    tageMitKm: tageMitKm,
    totalKm: totalKm,
    schnittKm: tageMitKm == 0 ? null : totalKm / tageMitKm,
    tageMitZeit: tageMitZeit,
    totalMinuten: totalMinuten,
    schnittMinuten: tageMitZeit == 0 ? null : totalMinuten / tageMitZeit,
    anzahlBesuche: anzahlBesuche,
    schnittBesuche: relevant.isEmpty ? null : anzahlBesuche / relevant.length,
    kmJeBesuch: besucheAnKmTagen == 0 ? null : totalKm / besucheAnKmTagen,
    minutenJeBesuch: besucheAnZeitTagen == 0
        ? null
        : totalMinuten / besucheAnZeitTagen,
  );
}

/// Besuche je Tag aus abgeschlossenen Reinigungen.
///
/// Ein Besuch = ein Betrieb an einem Tag, nicht eine Anlage: mehrere Anlagen
/// desselben Betriebs werden in einer Anfahrt erledigt (gleiche Zählweise wie
/// bei der Bergkundenpauschale). Sonst sähe ein Tag mit einem Grosskunden nach
/// vielen Besuchen aus und «km je Besuch» wäre unbrauchbar.
Map<DateTime, int> besucheJeTag(
  List<({DateTime datum, String betriebId})> abgeschlossene,
) {
  final proTag = <DateTime, Set<String>>{};
  for (final r in abgeschlossene) {
    final tag = nurDatum(r.datum);
    (proTag[tag] ??= <String>{}).add(r.betriebId);
  }
  return {for (final e in proTag.entries) e.key: e.value.length};
}

/// Datum ohne Uhrzeit — Schlüssel für alle Tages-Zuordnungen.
DateTime nurDatum(DateTime d) => DateTime(d.year, d.month, d.day);

/// Minuten als '7h 05'. Kompakter als '7 Std. 5 Min.' und damit auf dem Handy
/// in einer Kennzahlen-Karte lesbar.
String dauerText(int minuten) {
  final m = minuten < 0 ? 0 : minuten;
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}';
}

/// Zahl mit Schweizer Komma-Schreibweise; `null` → '–' (nichts erfasst).
String schnittText(double? wert, {int nachkomma = 1}) {
  if (wert == null) return '–';
  return wert.toStringAsFixed(nachkomma).replaceAll('.', ',');
}
