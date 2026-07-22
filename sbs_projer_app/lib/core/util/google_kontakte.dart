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
    telefon: clean(telefon),
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
