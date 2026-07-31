/// Reine Helfer für den Baustein «War geschlossen» im Tagesplan
/// (Spec docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md,
/// Abschnitt 4, Baustein A).
///
/// Der Knopf dokumentiert eine Leerfahrt (Betrieb überraschend geschlossen)
/// direkt am Tagesplan-Block, statt dass sie spurlos bleibt.
library;

/// Wochentags-Kürzel wie in `BetriebLocal.ruhetage` verwendet, in
/// Wochenreihenfolge (Mo..So) — siehe `betrieb_form_screen.dart`.
const wochentagKuerzelListe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Sentinel-Wert in `ruhetage`, der ausdrücklich "kein Ruhetag" bedeutet.
const kKeinRuhetagWert = 'keine';

/// Der Knopf «War geschlossen» ergibt nur für heutige und vergangene Tage
/// Sinn — bei einem künftigen Plan-Eintrag steht noch nichts fest (Daniel
/// 31.07.2026, ausdrücklich keine Bearbeitung künftiger Tage).
bool istHeuteOderVergangenerTag(DateTime tag, {DateTime? jetzt}) {
  final j = jetzt ?? DateTime.now();
  final heute = DateTime(j.year, j.month, j.day);
  final t = DateTime(tag.year, tag.month, tag.day);
  return !t.isAfter(heute);
}

/// Heutiges Wochentags-Kürzel (Vorbelegung der Ruhetag-Auswahl).
String heutigesWochentagKuerzel({DateTime? jetzt}) {
  final j = jetzt ?? DateTime.now();
  return wochentagKuerzelListe[j.weekday - 1];
}

/// [aktuelle] Ruhetage-Liste, ergänzt um [tag]. Entfernt dabei den
/// Sentinel-Wert [kKeinRuhetagWert], falls vorhanden — ein vor Ort
/// bestätigter Ruhetag widerspricht der bisherigen Aussage "kein Ruhetag".
/// Idempotent: ist [tag] bereits enthalten, ändert sich nichts (Reihenfolge
/// bleibt erhalten).
List<String> ruhetageErgaenzt(List<String> aktuelle, String tag) {
  final ohneSentinel = aktuelle.where((t) => t != kKeinRuhetagWert).toList();
  if (ohneSentinel.contains(tag)) return ohneSentinel;
  return [...ohneSentinel, tag];
}

/// Standard-Ferienfenster für den Datumsbereich im Sheet: heute bis
/// heute + 14 Tage (anpassbar, siehe Spec §4 Baustein A).
({DateTime von, DateTime bis}) standardFerienfenster({DateTime? jetzt}) {
  final j = jetzt ?? DateTime.now();
  final heute = DateTime(j.year, j.month, j.day);
  return (von: heute, bis: heute.add(const Duration(days: 14)));
}
