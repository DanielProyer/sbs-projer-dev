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
/// (z. B. −0.00004) ergeben auf beiden Seiten `-0.0000` (geprüft
/// 29.09.2026) — gleich, also unkritisch. Exakt −0.0 dagegen NICHT: JS
/// `(-0).toFixed(4)` ist `0.0000`, Dart (VM und Web) hängt ein Minus an.
/// Darum normalisieren beide Seiten −0.0 auf 0.0, bevor gerundet wird. In
/// Graubünden kommt das nie vor; es geht nur darum, dass die Schlüssel nie
/// auseinanderlaufen.
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
    'p:${_ohneMinusNull(lat).toStringAsFixed(4)},'
    '${_ohneMinusNull(lng).toStringAsFixed(4)}';

/// −0.0 → 0.0 (siehe Bibliotheks-Kommentar); `-0.0 == 0` ist wahr.
double _ohneMinusNull(double v) => v == 0 ? 0.0 : v;

/// Schlüssel eines Betriebs: `b:<betrieb uuid>`.
String betriebKey(String id) => 'b:$id';

/// Nachschlage-Schlüssel eines gerichteten Paars in der Map aus
/// `FahrzeitRepository.ladePunktRouten` (`'<vonKey>><nachKey>'`).
String punktRoutenSchluessel(String vonKey, String nachKey) =>
    '$vonKey>$nachKey';
