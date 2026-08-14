/// Version des GELADENEN Bundles — einkompiliert, nicht nachgeladen.
///
/// Bewusst eine Konstante und nicht `version.json`: Letzteres sagt nur, was auf
/// dem Server liegt. Diese hier sagt, was im Browser tatsächlich ausgeführt
/// wird. Genau diese Differenz war am 15.07.2026 stundenlang nicht feststellbar
/// und hat drei Fehldiagnosen verursacht — die eigentliche Ursache lag dann in
/// einem DB-Trigger (Migration 143), nicht im Bundle-Stand.
///
/// MUSS bei jedem Bump von `pubspec.yaml` Zeile 4 mitgezogen werden.
/// `test/app_version_test.dart` erzwingt das — die Konstante stand am
/// 06.08.2026 drei Auslieferungen zurueck, ohne dass es jemand merkte.
const String kAppVersion = '0.90.0';
