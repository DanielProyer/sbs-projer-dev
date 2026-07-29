// Reine Anzeige-Helfer für die Tourenplanung (ohne Flutter-Abhängigkeiten).
//
// Ruhetage stehen am Betrieb als Kürzel ('Mo' … 'So') — so schreibt sie das
// Betriebs-Formular, und so stehen sie in der Datenbank. Frühere Fassungen
// erwarteten hier die vollen Namen ('Montag'), wodurch kein einziger Ruhetag
// erkannt wurde. Die Helfer verstehen deshalb beide Schreibweisen.

const List<String> _kuerzel = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

const Map<String, String> _vollZuKurz = {
  'Montag': 'Mo',
  'Dienstag': 'Di',
  'Mittwoch': 'Mi',
  'Donnerstag': 'Do',
  'Freitag': 'Fr',
  'Samstag': 'Sa',
  'Sonntag': 'So',
};

/// Wochentag-Eintrag auf das Kürzel bringen; null bei 'keine' und Unbekanntem.
String? _alsKuerzel(String eintrag) {
  final s = eintrag.trim();
  if (_kuerzel.contains(s)) return s;
  return _vollZuKurz[s];
}

/// Ist [tag] ein Ruhetag laut [ruhetage]?
bool istRuhetag(List<String> ruhetage, DateTime tag) {
  if (ruhetage.isEmpty) return false;
  final heute = _kuerzel[tag.weekday - 1];
  for (final r in ruhetage) {
    if (_alsKuerzel(r) == heute) return true;
  }
  return false;
}

/// Kompakte Ruhetags-Anzeige, z.B. `Mo, Di`. Leer bei keinen/`'keine'`.
/// Sortiert nach Wochentag, unabhängig von der Reihenfolge im Betrieb.
String ruhetageText(List<String> ruhetage) {
  final gefunden = <String>{};
  for (final r in ruhetage) {
    final k = _alsKuerzel(r);
    if (k != null) gefunden.add(k);
  }
  return _kuerzel.where(gefunden.contains).join(', ');
}

bool _hat(String? s) => s != null && s.isNotEmpty;

/// Ist überhaupt eine Servicezeit erfasst?
///
/// Ohne jeden Block ist die Angabe schlicht offen. Sobald **ein** Block
/// gefüllt ist, gilt der andere als bewusst leer — «dann kein Service»
/// (Regel Daniel 29.07.2026). So ist unterscheidbar, ob eine Zeit fehlt oder
/// ob zu der Tageszeit kein Service möglich ist.
bool servicezeitErfasst(
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) =>
    (_hat(morgenAb) && _hat(morgenBis)) ||
    (_hat(nachmittagAb) && _hat(nachmittagBis));

/// Servicezeit-Anzeige, z.B. `08:00–12:00 · 13:30–17:00`.
///
/// Ist nur ein Block erfasst, wird der andere ausdrücklich als «kein Service»
/// benannt statt stillschweigend wegzufallen. Ein Block zählt nur, wenn Ab
/// **und** Bis gesetzt sind. Leerer Text = gar nichts erfasst.
String servicezeitText(
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  final morgen = _hat(morgenAb) && _hat(morgenBis);
  final nachmittag = _hat(nachmittagAb) && _hat(nachmittagBis);
  if (!morgen && !nachmittag) return '';
  if (morgen && nachmittag) {
    return '$morgenAb–$morgenBis · $nachmittagAb–$nachmittagBis';
  }
  if (morgen) return '$morgenAb–$morgenBis · nachmittags kein Service';
  return '$nachmittagAb–$nachmittagBis · morgens kein Service';
}

// ─── Zeitachse (Tourenplan-Zeitachse, Spec 2026-07-29 §4/§5) ───

/// 'HH:mm' → Minuten seit Mitternacht; null bei ungültiger Eingabe.
///
/// Bewusst tolerant (tryParse statt parse): ein einzelner beschädigter Wert
/// aus Altdaten darf die Zeitachse des ganzen Tages nicht zum Absturz bringen.
int? minutenAusHhmm(String? hhmm) {
  if (hhmm == null) return null;
  final teile = hhmm.split(':');
  if (teile.length < 2) return null;
  final h = int.tryParse(teile[0]);
  final m = int.tryParse(teile[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// Minuten seit Mitternacht → 'HH:mm' (auch über 24 h hinaus lesbar, falls
/// ein Plan über Mitternacht läuft: 25:10 statt 01:10 — sonst wäre nicht
/// erkennbar, dass der Tag zu lang geplant ist).
String hhmmAusMinuten(int minuten) {
  final m = minuten < 0 ? 0 : minuten;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// Alle vollständig erfassten Servicefenster eines Betriebs als
/// (ab, bis)-Minutenpaare. Halbe Fenster (nur Ab **oder** nur Bis) werden
/// ignoriert — dieselbe Regel wie in [servicezeitText].
List<({int ab, int bis})> _fenster(
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  final result = <({int ab, int bis})>[];
  for (final paar in [(morgenAb, morgenBis), (nachmittagAb, nachmittagBis)]) {
    final ab = minutenAusHhmm(paar.$1);
    final bis = minutenAusHhmm(paar.$2);
    if (ab != null && bis != null && bis > ab) result.add((ab: ab, bis: bis));
  }
  result.sort((a, b) => a.ab.compareTo(b.ab));
  return result;
}

/// Liegt die Ankunft ([minute] seit Mitternacht) in einem Servicefenster?
///
/// Ist gar kein vollständiges Fenster erfasst, gilt `true`: unbekannt ist
/// keine Einschränkung — der Tourenplan warnt nur, wenn er es wirklich besser
/// weiss (sonst hinge an jedem Betrieb ohne gepflegte Servicezeit eine
/// Warnung).
bool liegtInServicefenster(
  int minute,
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  final fenster = _fenster(morgenAb, morgenBis, nachmittagAb, nachmittagBis);
  if (fenster.isEmpty) return true;
  return fenster.any((f) => minute >= f.ab && minute <= f.bis);
}

/// Liegt ein Besuch von [startMin] bis [endMin] ausserhalb der Servicezeit?
///
/// Spec 2026-07-29 §4: geprüft wird «Ankunft–Ende», nicht nur die Ankunft.
/// Ein Besuch, der um 11:45 im Fenster startet und bis 12:30 dauert, ragt aus
/// dem Fenster heraus — genau der Fall, den Daniel gewarnt haben will (er
/// steht sonst vor verschlossener Tür bzw. mitten im Mittagsgeschäft).
bool besuchAusserhalbServicezeit(
  int startMin,
  int endMin,
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  bool drin(int m) => liegtInServicefenster(
    m,
    morgenAb,
    morgenBis,
    nachmittagAb,
    nachmittagBis,
  );
  return !drin(startMin) || !drin(endMin);
}

/// Beginn des nächsten Servicefensters **nach** [minute] (Minuten seit
/// Mitternacht) — Grundlage für den Vorschlag «Anker HH:mm?» am Block.
/// null, wenn kein Fenster mehr folgt (oder keines erfasst ist).
int? naechsterFensterStart(
  int minute,
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  for (final f in _fenster(morgenAb, morgenBis, nachmittagAb, nachmittagBis)) {
    if (f.ab > minute) return f.ab;
  }
  return null;
}
