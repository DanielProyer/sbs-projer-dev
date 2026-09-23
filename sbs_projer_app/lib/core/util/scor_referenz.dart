import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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
/// [suffix] > 0 hängt eine Ziffernfolge an den Body, um bei einer Kollision
/// (zwei Rechnungsnummern mit identischen Ziffern) eine eindeutige Referenz zu
/// erzeugen. suffix 0 = Basisreferenz.
/// Liefert null, wenn kein Kundentyp, keine Nummer oder keine Ziffern.
String? qrReferenzAusNummer(String? rechnungstyp, String? rechnungsnummer,
    {int suffix = 0}) {
  const kundentypen = {'kundenrechnung', 'jahresrechnung'};
  if (!kundentypen.contains(rechnungstyp)) return null;
  if (rechnungsnummer == null) return null;
  final digits = rechnungsnummer.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return scorReferenz(suffix > 0 ? '$digits$suffix' : digits);
}

/// True, wenn [e] eine Unique-Kollision auf `qr_referenz` ist (Spalte ist seit
/// Migration 104 UNIQUE) — zwei Rechnungsnummern mit identischen Ziffern
/// erzeugen sonst denselben SCOR-Body. Pure Prüfung auf dem Postgrest-Fehler,
/// ohne Netzzugriff — daher testbar mit einer lokal konstruierten Exception.
bool istQrReferenzKonflikt(Object e) {
  if (e is! PostgrestException) return false;
  return e.code == '23505' &&
      (e.message.contains('qr_referenz') ||
          (e.details?.toString().contains('qr_referenz') ?? false));
}

/// Versucht [aktion] mit steigendem SCOR-Suffix (siehe [qrReferenzAusNummer]),
/// bis sie ohne `qr_referenz`-Kollision durchläuft, oder gibt nach
/// [maxVersuche] den letzten Fehler weiter.
///
/// Gemeinsame Retry-Logik für ZWEI Stellen, die dieselbe Kollision behandeln
/// müssen (Review 23.09.2026 — "nicht kopieren, in eine gemeinsame Funktion
/// ziehen"): `RechnungRepository.create` (neue Rechnung mit frischer
/// Referenz) und `MahnlaufService` (nachträgliches Setzen an einer
/// bestehenden Rechnung ohne Referenz).
///
/// Liefert [ref] `null` sofort ohne Versuch an [aktion] weiterzugeben, wenn
/// schon der erste Kandidat (`suffix: 0`) null ist (kein Kundentyp oder keine
/// Rechnungsnummer) — ein Suffix ändert daran nichts, ein Retry wäre sinnlos.
Future<T> mitQrReferenzRetry<T>({
  required String? rechnungstyp,
  required String? rechnungsnummer,
  required Future<T> Function(String? referenz) aktion,
  int maxVersuche = 50,
}) async {
  for (var suffix = 0; suffix < maxVersuche; suffix++) {
    final ref = qrReferenzAusNummer(rechnungstyp, rechnungsnummer, suffix: suffix);
    try {
      return await aktion(ref);
    } catch (e) {
      final letzterVersuch = suffix == maxVersuche - 1;
      if (ref == null || !istQrReferenzKonflikt(e) || letzterVersuch) rethrow;
    }
  }
  // Unerreichbar: die Schleife kehrt in jedem Durchlauf entweder per return
  // oder per rethrow zurück.
  throw StateError('mitQrReferenzRetry: unerreichbar');
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
