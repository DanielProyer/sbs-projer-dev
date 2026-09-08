/// Archiv der Saisonfenster eines Betriebs.
///
/// **Warum es das gibt (Daniel, 08.09.2026):** Die Saisondaten am Betrieb
/// (`winter_start_datum` … `sommer_ende_datum`) halten immer nur die aktuelle
/// Saison und werden jedes Jahr überschrieben — die Vorjahre gehen dabei
/// verloren. Genau die braucht es aber, um eine kommende Saison abzuschätzen,
/// solange der Betrieb sie noch nicht angesagt hat. Bei Acla Grischuna lag
/// das Winterende fünf Jahre in Folge zwischen dem 30. März und 4. April.
///
/// Bewusst **nicht** aus den erledigten Endreinigungen abgeleitet: Eine
/// Endreinigung kann auch mitten in der Zwischensaison stattfinden und wäre
/// dann kein Saisonende. Ins Archiv kommt nur, was am Betrieb stand.
library;

/// Eine abgeschlossene Saison, die ins Archiv gehört.
class SaisonArchivEintrag {
  final String saison; // 'winter' | 'sommer'
  final DateTime start;
  final DateTime? ende;
  const SaisonArchivEintrag({
    required this.saison,
    required this.start,
    this.ende,
  });
}

DateTime? _tag(DateTime? d) =>
    d == null ? null : DateTime(d.year, d.month, d.day);

/// Entscheidet, ob die bisherige Saison beim Speichern archiviert wird.
///
/// Auslöser ist allein das **Startdatum**: Ein neuer Start heisst «neue
/// Saison», das bisherige Fenster ist damit Geschichte. Ein geändertes Ende
/// ist dagegen eine Korrektur derselben Saison — würde man auch darauf
/// archivieren, entstünde beim getrennten Speichern von Ende und Start ein
/// zweiter Eintrag mit vermischten Daten.
///
/// Gibt null zurück, wenn nichts zu archivieren ist.
SaisonArchivEintrag? saisonArchivEintrag({
  required String saison,
  required DateTime? altStart,
  required DateTime? altEnde,
  required DateTime? neuStart,
}) {
  final alt = _tag(altStart);
  if (alt == null) return null; // es gab keine Saison
  if (alt == _tag(neuStart)) return null; // unverändert oder nur Ende geändert
  return SaisonArchivEintrag(saison: saison, start: alt, ende: _tag(altEnde));
}
