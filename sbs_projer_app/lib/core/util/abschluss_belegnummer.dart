/// Belegnummern der Jahresabschluss-Buchungen: `JA<jahr>_<Schritt>`, jede
/// Nachführung mit laufender Nummer (`JA2025_E`, `JA2025_E2`, `JA2025_E3` …)
/// — so wie die SQL-Buchungen des Abschlusses 2025
/// (docs/buchhaltung/jahresabschluss-2025.md).
library;

/// Basis der Belegnummer, z. B. `JA2025_E`.
String abschlussBelegBasis(int jahr, String schritt) => 'JA${jahr}_$schritt';

/// Nächste freie Belegnummer zu [basis]: [basis] selbst, solange sie im
/// Journal fehlt, sonst `<basis><n>` mit n = höchste vergebene Nummer + 1.
///
/// Nur exakte Treffer zählen (`JA2025_D`, `JA2025_D2`) — `JA2025_D_U1` ist
/// eine Umbuchung der Steuerzahlung, keine Nachführung. WARUM «höchste + 1»
/// statt «erste Lücke»: Eine gelöschte `_E2` darf nicht wieder vergeben
/// werden, sonst stünden in der Chronik zwei verschiedene `_E2`.
String naechsteAbschlussBelegnummer(
  String basis,
  Iterable<String?> vorhandene,
) {
  final muster = RegExp('^${RegExp.escape(basis)}(\\d*)\$');
  var hoechste = 0;
  for (final nr in vorhandene) {
    if (nr == null) continue;
    final m = muster.firstMatch(nr.trim());
    if (m == null) continue;
    final n = m.group(1)!.isEmpty ? 1 : int.parse(m.group(1)!);
    if (n > hoechste) hoechste = n;
  }
  return hoechste == 0 ? basis : '$basis${hoechste + 1}';
}
