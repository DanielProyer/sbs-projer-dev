/// Öffnungszeiten als eine Zeile — gleiche Tage zusammengefasst.
///
/// Die bestehende Formatierung in `vorschlag_anzeige.dart` listet jeden Tag
/// einzeln; auf einer Karte wären das sieben Einträge. Für die
/// Servicezeiten-Durchsicht (08.09.2026) braucht es die kurze Form, damit
/// beim Festlegen der Servicezeit daneben steht, wann der Betrieb überhaupt
/// offen hat.
library;

const _tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _geschlossen = 'geschlossen';

/// «Mo–Fr 08:30–18:00 · Sa/So geschlossen». Gibt null zurück, wenn nichts
/// hinterlegt ist oder der Betrieb an keinem Tag offen hat — dann ist die
/// Angabe schlicht unbekannt und eine Zeile «alles geschlossen» wäre
/// irreführend.
String? oeffnungszeitenKompakt(Map<String, dynamic>? zeiten) {
  if (zeiten == null || zeiten.isEmpty) return null;

  String fuerTag(String tag) {
    final slots = zeiten[tag];
    if (slots is! List || slots.isEmpty) return _geschlossen;
    final teile = slots
        .whereType<Map>()
        .map((s) => '${s['von'] ?? '?'}–${s['bis'] ?? '?'}')
        .toList();
    return teile.isEmpty ? _geschlossen : teile.join(', ');
  }

  // Nur Tage, zu denen überhaupt etwas hinterlegt ist. Ein fehlender Tag
  // heisst «unbekannt», nicht «geschlossen» — den zu erfinden wäre schlimmer
  // als ihn wegzulassen.
  final vorhanden = [
    for (var i = 0; i < _tage.length; i++)
      if (zeiten.containsKey(_tage[i])) (index: i, wert: fuerTag(_tage[i])),
  ];
  if (vorhanden.isEmpty) return null;
  if (vorhanden.every((e) => e.wert == _geschlossen)) return null;

  // Benachbarte Tage mit gleicher Zeit zusammenziehen. Fehlt ein Tag
  // dazwischen, beginnt eine neue Gruppe.
  final gruppen = <({int von, int bis, String wert})>[];
  for (final e in vorhanden) {
    final l = gruppen.isEmpty ? null : gruppen.last;
    if (l != null && l.wert == e.wert && e.index == l.bis + 1) {
      gruppen.removeLast();
      gruppen.add((von: l.von, bis: e.index, wert: l.wert));
    } else {
      gruppen.add((von: e.index, bis: e.index, wert: e.wert));
    }
  }

  String tagText(int von, int bis) {
    if (von == bis) return _tage[von];
    if (bis - von == 1) return '${_tage[von]}/${_tage[bis]}';
    return '${_tage[von]}–${_tage[bis]}';
  }

  return gruppen
      .map((g) => '${tagText(g.von, g.bis)} ${g.wert}')
      .join(' · ');
}
