// Reine Validierungs-Helfer für Swiss-QR-Zahlungen (QR-IBAN + QRR-Referenz).
// Keine Abhängigkeiten, voll testbar — gespiegelt nach dem Muster von
// `scor_referenz.dart`.

/// Prüft, ob [iban] eine QR-IBAN ist. QR-IBANs tragen eine spezielle
/// Instituts-ID (IID) im Bereich 30000–31999 (Stellen 5–9 der IBAN, 0-basiert
/// Substring 4..9). Nur QR-IBANs dürfen mit einer QRR-Referenz kombiniert
/// werden.
bool istQrIban(String iban) {
  final norm = iban.replaceAll(' ', '');
  if (norm.length < 9) return false;
  final iid = int.tryParse(norm.substring(4, 9));
  if (iid == null) return false;
  return iid >= 30000 && iid <= 31999;
}

/// Prüft die Prüfziffer einer 27-stelligen QR-Referenz (QRR) nach dem
/// rekursiven Modulo-10-Verfahren (ESR/Swiss QR).
///
/// Die Referenz muss exakt 27 Ziffern enthalten (Leerzeichen werden entfernt).
/// Über die ersten 26 Ziffern wird der Übertrag berechnet, die Prüfziffer ist
/// `(10 - carry) % 10` und muss der 27. Ziffer entsprechen.
bool qrrPruefzifferOk(String ref) {
  final r = ref.replaceAll(' ', '');
  if (r.length != 27 || !RegExp(r'^\d{27}$').hasMatch(r)) return false;

  const tabelle = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5];
  var carry = 0;
  for (var i = 0; i < 26; i++) {
    final ziffer = int.parse(r[i]);
    carry = tabelle[(carry + ziffer) % 10];
  }
  final pruefziffer = (10 - carry) % 10;
  return pruefziffer == int.parse(r[26]);
}
