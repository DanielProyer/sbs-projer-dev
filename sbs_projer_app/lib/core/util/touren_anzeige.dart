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
