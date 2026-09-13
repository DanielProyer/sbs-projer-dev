import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

// ─── Zähler für die Startseiten-Kacheln (A2) ───
//
// Die zehn Kacheln der Startseite zeigten bisher Jahrestotale (Betriebe 443,
// Reinigungen 933, ...) — keine dieser Zahlen verlangt eine Handlung. Diese
// Datei liefert stattdessen Zähler für offene Arbeit. Das Umstellen der
// Kacheln selbst ist ein separater Schritt (Task 2) — hier stehen nur die
// Provider.

/// Der Sonntag, der die Woche von [tag] abschliesst. Fällt [tag] selbst auf
/// einen Sonntag, ist es dieser Tag — nicht der Sonntag darauf.
DateTime kommenderSonntag(DateTime tag) {
  final ohneZeit = DateTime(tag.year, tag.month, tag.day);
  final bisSonntag = DateTime.sunday - ohneZeit.weekday; // Mo=1 … So=7
  return ohneZeit.add(Duration(days: bisSonntag));
}

/// Anlagen, die bis zum Ende dieser Woche fällig werden.
///
/// Obermenge des Tourenplan-Zählers (`faelligeAnlagenCountProvider`, der auf
/// heute steht) — «heute fällig» ist in «diese Woche fällig» enthalten. Das
/// ist kein Widerspruch, sondern eine Eingrenzung: der Wochenzähler ist immer
/// grösser oder gleich dem Tageszähler.
final reinigungenDieseWocheProvider = Provider<int>((ref) {
  final sonntag = kommenderSonntag(DateTime.now());
  return ref.watch(faelligeAnlagenProvider(sonntag)).length;
});

/// Störungen, die noch zu erledigen sind (Status 'offen' oder
/// 'in_bearbeitung' — siehe `stoerungOffen` in `tour_filter.dart`, der
/// zentralen Definition, die auch der Tourenplan verwendet).
final offeneStoerungenCountProvider = Provider<int>((ref) {
  return ref
      .watch(stoerungenProvider)
      .where((s) => stoerungOffen(s.status))
      .length;
});

/// Montagen, die noch zu erledigen sind (Status 'geplant' oder
/// 'in_bearbeitung' — siehe `montageOffen` in `tour_filter.dart`).
final geplanteMontagenCountProvider = Provider<int>((ref) {
  return ref
      .watch(montagenProvider)
      .where((m) => montageOffen(m.status))
      .length;
});

/// Eigenaufträge, die noch nicht auf `behoben` stehen.
///
/// Geprüft am Code (13.09.2026): `EigenauftragLocal.status` kennt drei Werte
/// — 'behoben', 'nicht_behebbar', 'nachbearbeitung_noetig' (Dropdown in
/// `eigenauftrag_form_screen.dart`) — nicht nur den einen, wie die App-Analyse
/// vom 08.09.2026 (Befund 3) nahelegte. Für die Zählung ändert das nichts:
/// 'behoben' ist der einzige Abschluss-Status (auch das grüne Häkchen in
/// `eigenauftrag_list_screen.dart` hängt nur daran) — alles andere ist offen.
final offeneEigenauftraegeCountProvider = Provider<int>((ref) {
  return ref
      .watch(eigenauftraegeProvider)
      .where((e) => e.status != 'behoben')
      .length;
});

// ─── Eröffnungsreinigungen: bewusst ausgelassen ───
//
// Der Plan sah einen Zähler „anstehende Eröffnungen" vor, analog zu den
// beiden Providern oben (Status != 'abgeschlossen'). Geprüft am Code
// (13.09.2026): `EroeffnungsreinigungLocal` (lib/data/local/
// eroeffnungsreinigung_local.dart) hat gar kein Status-Feld — im Gegensatz zu
// Störung/Montage/Eigenauftrag ist das kein Auftrag mit Lebenszyklus, sondern
// ein nachträglich erfasster Beleg (Formular „Eröffnungsreinigung erfassen",
// Datum defaultet auf `DateTime.now()`, dazu nur `preis`/`abgerechnet` für die
// Abrechnung — kein „geplant"-Zustand). Ein „anstehend"-Zähler auf dieser
// Datenquelle wäre geraten, nicht gemessen.
//
// Das fachliche Gegenstück existiert bereits: `getFaelligkeit()` in
// tour_providers.dart liefert `FaelligkeitsStatus.eroeffnungFaellig` für
// Anlagen, deren saisonale Wiedereröffnung ansteht, und das fliesst über
// `faelligeAnlagenProvider` in `reinigungenDieseWocheProvider` oben bereits
// mit ein.
//
// Entschieden am 13.09.2026: Die Eröffnungen-Kachel bekommt KEINEN Zähler.
// Ein zweiter Zähler zählte dieselbe anstehende Arbeit ein zweites Mal — die
// Kachel behält Symbol und Namen, wie Betriebe, Kontakte und Spesen auch.
