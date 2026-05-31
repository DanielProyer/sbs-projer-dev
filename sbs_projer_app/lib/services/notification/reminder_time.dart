/// Berechnet den absoluten Zeitpunkt einer Termin-Erinnerung.
///
/// Bei vorhandener [uhrzeitVon] (Format "HH:mm") wird Datum+Uhrzeit als Bezug
/// genommen, sonst 08:00 am Termintag. Davon wird [vorlaufMinuten] abgezogen.
/// Ungueltige Uhrzeit -> 08:00.
DateTime berechneErinnerungszeitpunkt({
  required DateTime datum,
  required String? uhrzeitVon,
  required int vorlaufMinuten,
}) {
  int stunde = 8, minute = 0;
  if (uhrzeitVon != null && uhrzeitVon.contains(':')) {
    final teile = uhrzeitVon.split(':');
    final h = int.tryParse(teile[0]);
    final m = teile.length > 1 ? int.tryParse(teile[1]) : 0;
    if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
      stunde = h;
      minute = m;
    }
  }
  final bezug = DateTime(datum.year, datum.month, datum.day, stunde, minute);
  return bezug.subtract(Duration(minutes: vorlaufMinuten));
}

/// Vordefinierte Vorlauf-Optionen (Minuten -> Label) fuer das UI.
const Map<int, String> erinnerungVorlaufOptionen = {
  0: 'Pünktlich',
  15: '15 Minuten vorher',
  30: '30 Minuten vorher',
  60: '1 Stunde vorher',
  120: '2 Stunden vorher',
  1440: '1 Tag vorher',
  2880: '2 Tage vorher',
  4320: '3 Tage vorher',
  10080: '1 Woche vorher',
};
