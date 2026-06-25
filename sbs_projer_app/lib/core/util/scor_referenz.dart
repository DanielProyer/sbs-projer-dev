/// SCOR / ISO 11649 Creditor Reference (`RF` + 2 Prüfziffern + Body).
/// Body wird auf A–Z/0–9 reduziert und uppercased. Prüfziffer nach ISO 7064
/// MOD 97-10: 98 - (Body + "RF00", Buchstaben→Zahlen A=10..Z=35) mod 97.
String scorReferenz(String body) {
  final b = body.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  final pruef = 98 - _mod97('${b}RF00');
  return 'RF${pruef.toString().padLeft(2, '0')}$b';
}

/// Prüft, ob [referenz] eine gültige SCOR-Referenz ist (Mod-97 == 1, wenn die
/// ersten 4 Zeichen ans Ende verschoben werden).
bool istGueltigeScor(String referenz) {
  final r = scorRefNorm(referenz);
  if (r.length < 5 || !r.startsWith('RF')) return false;
  return _mod97('${r.substring(4)}${r.substring(0, 4)}') == 1;
}

/// Normalisiert eine Referenz für den Vergleich: nur A–Z/0–9, Uppercase.
String scorRefNorm(String s) =>
    s.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// Leitet die SCOR-Referenz aus der Rechnungsnummer ab — nur für Kundentypen
/// (heineken_monat ausgeschlossen). Body = Ziffern der Rechnungsnummer.
/// Liefert null, wenn kein Kundentyp, keine Nummer oder keine Ziffern.
String? qrReferenzAusNummer(String? rechnungstyp, String? rechnungsnummer) {
  const kundentypen = {'kundenrechnung', 'jahresrechnung'};
  if (!kundentypen.contains(rechnungstyp)) return null;
  if (rechnungsnummer == null) return null;
  final digits = rechnungsnummer.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return scorReferenz(digits);
}

/// MOD 97 über einen alphanumerischen String: jede Ziffer 0–9 bleibt, jeder
/// Buchstabe A–Z wird zu 10–35 (zweistellig), iterativ gerechnet (kein BigInt).
int _mod97(String s) {
  var rem = 0;
  for (final ch in s.split('')) {
    final code = int.parse(ch, radix: 36); // '0'..'9'→0..9, 'A'..'Z'→10..35
    for (final d in code.toString().split('')) {
      rem = (rem * 10 + int.parse(d)) % 97;
    }
  }
  return rem;
}
