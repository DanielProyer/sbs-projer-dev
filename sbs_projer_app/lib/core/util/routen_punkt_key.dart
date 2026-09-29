/// Schlüssel der Routen-Enden im Cache `routen_punkte` (Migration 213,
/// 29.09.2026).
///
/// Die Edge Function `fahrzeit-route` routet seit 213 auch zwischen
/// beliebigen Punkten (GPS-Position, Startort) und legt das Ergebnis unter
/// `von_key`/`nach_key` ab: ein Betrieb als `'b:<uuid>'`, ein Punkt als
/// `'p:<lat>,<lng>'` mit vier Nachkommastellen (≈ 11 m). Die App rechnet
/// dieselben Schlüssel, um die Strecke ohne neue Anfrage zu finden — diese
/// Datei und `supabase/functions/fahrzeit-route/keys.ts` müssen Zeichen für
/// Zeichen gleich rechnen (gleiche Testbeispiele auf beiden Seiten).
///
/// Rundung über `toStringAsFixed(4)` — im Web ist das dasselbe JS-`toFixed`
/// wie in der Function, die Dart-VM rechnet gleich. Kleine negative Werte
/// ergeben auf beiden Seiten `-0.0000` (geprüft 29.09.2026), eine eigene
/// Vorzeichen-Normalisierung braucht es darum nicht.
///
/// Den Schlüssel eines `Halt` liefert `haltKey` in `fahrten_aus_kette.dart`
/// (dort, wo `Halt` steht — sonst importierten sich die beiden Dateien
/// gegenseitig).
library;

/// Ein Ende einer Routen-Anfrage an `fahrzeit-route`: ENTWEDER ein Betrieb
/// ([betriebId], die Function liest die Koordinaten aus den Stammdaten)
/// ODER ein Punkt ([lat]/[lng]: Startort, GPS-Position). Hier statt im
/// Repository, damit die reinen Regeln (`fahrten_aus_kette.dart`) Aufträge
/// bauen können, ohne Supabase zu kennen.
typedef RoutenEnde = ({String? betriebId, double? lat, double? lng});

/// Schlüssel eines Punkts: `p:<lat>,<lng>`, je vier Nachkommastellen.
String punktKey(double lat, double lng) =>
    'p:${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

/// Schlüssel eines Betriebs: `b:<betrieb uuid>`.
String betriebKey(String id) => 'b:$id';

/// Nachschlage-Schlüssel eines gerichteten Paars in der Map aus
/// `FahrzeitRepository.ladePunktRouten` (`'<vonKey>><nachKey>'`).
String punktRoutenSchluessel(String vonKey, String nachKey) =>
    '$vonKey>$nachKey';
