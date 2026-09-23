/// «Name, Ort» für jede Stelle, an der ein Betrieb neben etwas anderem steht.
///
/// WARUM: Es gibt mehrere Betriebe mit gleichem Namen (Rössli, Central,
/// Posthotel …). Bei Personen stand bis 23.09.2026 nur der Name — welcher
/// Rössli gemeint war, sah man nicht (Daniel 23.09.2026).
library;

String betriebMitOrt(String name, String? ort) {
  final o = ort?.trim() ?? '';
  return o.isEmpty ? name : '$name, $o';
}
