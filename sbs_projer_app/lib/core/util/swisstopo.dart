/// Kartenhintergründe für die flutter_map-Ansichten.
///
/// swisstopo-WMTS ist kostenlos und ohne API-Key nutzbar (© swisstopo).
/// OpenStreetMap kam am 30.07.2026 als dritter Hintergrund dazu und ist neu
/// der Standard: In Ortschaften zeigt es mehr von dem, was bei der Anfahrt
/// zählt (Restaurants, Parkplätze, Einbahnen) als die Landeskarte.
///
/// Google Maps ist bewusst NICHT dabei: Deren Nutzungsbedingungen erlauben
/// die Anzeige der Kacheln nur mit Googles eigenem Renderer, nicht in
/// flutter_map. Für die Navigation gibt es stattdessen den
/// «In Google Maps öffnen»-Knopf (google_maps_route.dart).
library;

/// Die drei wählbaren Hintergründe. [osm] ist der Standard.
enum Basemap { osm, karte, luftbild }

const swisstopoLuftbild =
    'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissimage/default/current/3857/{z}/{x}/{y}.jpeg';

/// Klassische Schweizer Landeskarte (Strassen/Ortsnamen) — „Karten"-Ansicht.
const swisstopoKarte =
    'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/3857/{z}/{x}/{y}.jpeg';

/// OpenStreetMap-Standardstil (© OpenStreetMap-Mitwirkende, ODbL).
const openStreetMap = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Kachel-URL des gewählten Hintergrunds.
String basemapUrl(Basemap b) => switch (b) {
  Basemap.osm => openStreetMap,
  Basemap.karte => swisstopoKarte,
  Basemap.luftbild => swisstopoLuftbild,
};

/// Pflicht-Quellenangabe des gewählten Hintergrunds — beide Dienste verlangen
/// sie in ihren Nutzungsbedingungen.
String basemapQuelle(Basemap b) => switch (b) {
  Basemap.osm => '© OpenStreetMap',
  Basemap.karte || Basemap.luftbild => '© swisstopo',
};
