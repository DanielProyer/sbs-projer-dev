/// Baut aus einer rohen Telefonnummer die wa.me-Nummer (E.164 ohne '+').
/// CH-Default: führende 0 wird zu 41. Zu kurze/leere Nummern -> null.
String? whatsappNummer(String? telefon) {
  if (telefon == null) return null;
  var d = telefon.replaceAll(RegExp(r'[^\d+]'), '');
  if (d.startsWith('+')) {
    d = d.substring(1);
  } else if (d.startsWith('00')) {
    d = d.substring(2);
  } else if (d.startsWith('0')) {
    d = '41${d.substring(1)}';
  }
  if (d.length < 8) return null;
  return d;
}

/// wa.me-Link für [telefon]; wirft, wenn die Nummer unbrauchbar ist —
/// vorher mit [whatsappNummer] prüfen.
Uri whatsappUri(String telefon) => Uri.parse('https://wa.me/${whatsappNummer(telefon)!}');
