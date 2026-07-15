/// Version des GELADENEN Bundles — einkompiliert, nicht nachgeladen.
///
/// Bewusst eine Konstante und nicht `version.json`: Letzteres sagt nur, was auf
/// dem Server liegt. Diese hier sagt, was im Browser tatsächlich ausgeführt
/// wird. Genau die Differenz war am 15.07.2026 stundenlang nicht feststellbar —
/// und vermutlich auch die Ursache der 38 fehlenden Rechnungen im Juni/Juli:
/// eine alte Fassung lief weiter, ohne dass es jemand sehen konnte.
///
/// MUSS bei jedem Bump von `pubspec.yaml` Zeile 4 mitgezogen werden.
const String kAppVersion = '0.48.4';
