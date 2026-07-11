/// Reine Anzeige-Helfer für die Tourenplanung (ohne Flutter-Abhängigkeiten).
///
/// Ruhetage werden am Betrieb als volle Wochentagsnamen gespeichert
/// (`'Montag'` … `'Sonntag'`), passend zu `isBetriebOffen` in tour_providers.

const List<String> _wochentageVoll = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

const Map<String, String> _kurzform = {
  'Montag': 'Mo',
  'Dienstag': 'Di',
  'Mittwoch': 'Mi',
  'Donnerstag': 'Do',
  'Freitag': 'Fr',
  'Samstag': 'Sa',
  'Sonntag': 'So',
};

/// Ist [tag] ein Ruhetag laut [ruhetage] (volle Wochentagsnamen)?
bool istRuhetag(List<String> ruhetage, DateTime tag) {
  if (ruhetage.isEmpty) return false;
  final name = _wochentageVoll[tag.weekday - 1];
  return ruhetage.contains(name);
}

/// Kompakte Ruhetags-Anzeige, z.B. `Mo, Di`. Leer bei keinen/`'keine'`.
String ruhetageText(List<String> ruhetage) {
  final teile = <String>[];
  for (final r in ruhetage) {
    final k = _kurzform[r];
    if (k != null) teile.add(k);
  }
  return teile.join(', ');
}

bool _hat(String? s) => s != null && s.isNotEmpty;

/// Servicezeit-Anzeige, z.B. `08:00–12:00 · 13:30–17:00`.
/// Ein Block zählt nur, wenn Ab **und** Bis gesetzt sind. Leer wenn nichts.
String servicezeitText(
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  final bloecke = <String>[];
  if (_hat(morgenAb) && _hat(morgenBis)) {
    bloecke.add('$morgenAb–$morgenBis');
  }
  if (_hat(nachmittagAb) && _hat(nachmittagBis)) {
    bloecke.add('$nachmittagAb–$nachmittagBis');
  }
  return bloecke.join(' · ');
}
