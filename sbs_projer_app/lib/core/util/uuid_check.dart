/// Ist [wert] eine valide UUID?
///
/// Seit Migration 175 tragen `montagen.material_N_id` bei Anlass-Montagen
/// FREITEXT-Tageszeilen (die Spalten sind text). Überall dort, wo diese
/// Werte gegen uuid-Spalten gefiltert werden (z. B. der lager-Lookup der
/// Monatsrechnung), müssen Nicht-UUIDs vorher raus — sonst wirft PostgREST
/// 22P02 und der ganze Lookup fällt aus.
final _uuidMuster = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool istUuid(String wert) => _uuidMuster.hasMatch(wert);
