/// Reine Helfer für den Google-Kontakte-Sync (testbar, kein I/O).
library;

/// Hat der gespeicherte OAuth-Scope den SCHREIB-Zugriff auf Kontakte?
/// `contacts.readonly` genügt nicht.
bool hatKontakteScope(String? scope) {
  if (scope == null) return false;
  return scope.split(' ').contains('https://www.googleapis.com/auth/contacts');
}

/// Ergebnis des Contact Pickers, aufbereitet fürs Kontakt-Formular.
class PickerKontakt {
  final String? vorname;
  final String? nachname;
  final String? telefon;
  final String? email;
  const PickerKontakt({this.vorname, this.nachname, this.telefon, this.email});
}

/// Rohe Picker-Nummer ins App-Format bringen (Regel Daniel 22.07.2026):
/// «079 123 45 67» / «0041 79…» / «41…» -> «+41 79 123 45 67».
/// Schweizer Nummern (+41, 11 Ziffern) werden im App-Raster formatiert,
/// ausländische bleiben vollständig als «+…» ohne Raster, unbekannte
/// Formate unverändert.
String? telefonAusPicker(String? roh) {
  final t = (roh ?? '').trim();
  if (t.isEmpty) return null;
  var nummer = t.replaceAll(RegExp(r'[^\d+]'), '');
  if (nummer.startsWith('00')) nummer = '+${nummer.substring(2)}';
  if (!nummer.startsWith('+')) {
    if (nummer.startsWith('0') && nummer.length > 1) {
      nummer = '+41${nummer.substring(1)}';
    } else if (nummer.startsWith('41') && nummer.length >= 11) {
      nummer = '+$nummer';
    } else {
      return t; // unbekanntes Format nicht verschlimmbessern
    }
  }
  final ziffern = nummer.substring(1).replaceAll('+', '');
  if (!ziffern.startsWith('41') || ziffern.length != 11) return '+$ziffern';
  // CH-Raster wie der _PhoneFormatter der App: +41 79 123 45 67
  final b = StringBuffer('+');
  const gaps = {2, 4, 7, 9};
  for (var i = 0; i < ziffern.length; i++) {
    if (gaps.contains(i)) b.write(' ');
    b.write(ziffern[i]);
  }
  return b.toString();
}

/// Name-Split: letztes Wort = Nachname, Rest = Vorname; ein Wort = Nachname.
PickerKontakt kontaktAusPicker(String? name, String? telefon, String? email) {
  String? clean(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  final teile = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  String? vorname;
  String? nachname;
  if (teile.length == 1) {
    nachname = teile.first;
  } else if (teile.length > 1) {
    nachname = teile.last;
    vorname = teile.sublist(0, teile.length - 1).join(' ');
  }
  return PickerKontakt(
    vorname: vorname,
    nachname: nachname,
    telefon: telefonAusPicker(telefon),
    email: clean(email),
  );
}

String _zwei(int n) => n.toString().padLeft(2, '0');

/// Statuszeile für die Einstellungen.
String kontakteSyncStatusText(DateTime? at, String? info) {
  if (at == null) return 'Noch nie synchronisiert';
  final zeit = '${_zwei(at.day)}.${_zwei(at.month)}.${at.year} '
      '${_zwei(at.hour)}:${_zwei(at.minute)}';
  return info == null || info.isEmpty
      ? 'Letzter Sync $zeit'
      : 'Letzter Sync $zeit · $info';
}
