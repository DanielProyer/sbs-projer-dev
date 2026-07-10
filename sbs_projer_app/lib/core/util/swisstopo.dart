/// swisstopo-WMTS-Kachel-URLs (kostenlos, ohne API-Key, © swisstopo).
/// Werden als `TileLayer.urlTemplate` in flutter_map verwendet.
const swisstopoLuftbild =
    'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissimage/default/current/3857/{z}/{x}/{y}.jpeg';

/// Klassische Schweizer Landeskarte (Strassen/Ortsnamen) — „Karten"-Ansicht.
const swisstopoKarte =
    'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/3857/{z}/{x}/{y}.jpeg';
