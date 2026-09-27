import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Ein Ferien-Slot (Start/Ende koennen einzeln null sein).
typedef FerienSlot = ({DateTime? start, DateTime? ende});

/// Ferien-Perioden aus der Tabelle `betrieb_ferien`, gruppiert nach
/// `betrieb_id` (== [BetriebLocal.serverId]).
typedef FerienPeriodenMap = Map<String, List<({DateTime von, DateTime bis})>>;

/// Wie oft [ferienSlots] einen Betrieb OHNE geladene Perioden gesehen hat.
///
/// Nur zur Beobachtung waehrend der Woche vor dem DROP der Altspalten: Steht
/// der Zaehler nach einer Tour-Planung nicht auf 0, gibt es noch einen Pfad,
/// der Betriebe ohne [mitFerienPerioden] bzw.
/// `BetriebFerienRepository.periodenAnhaengen` auswertet.
int ferienRueckfallZaehler = 0;

/// Betriebe, fuer die der Rueckfall schon gemeldet wurde — damit der
/// Tourenplan (tausende Aufrufe je Aufbau) die Konsole nicht flutet.
final Set<String> _rueckfallGemeldet = {};

/// Steht, solange [betriebeMitFerien] die Ferien-Tabelle nicht laden konnte.
/// Die Betriebe tragen dann ABSICHTLICH `ferienPerioden = null`
/// («unbekannt»), und [ferienSlots] darf das nicht als Programmierfehler
/// werten.
///
/// WARUM (Review 27.09.2026, M1): Ohne diese Marke warf das `assert` in
/// [ferienSlots] im Debug-Modus in jedem `build`, der Ferien auswertet
/// (Betriebsliste, Aufgabenliste) — und riss ausgerechnet die Aufgabe
/// «Ferien nicht geladen» mit. Gesetzt im `catch` des Ladens,
/// zurueckgesetzt erst, wenn eine Liste MIT Ferien ausgeliefert wird: Bis
/// dahin kann ein Neuaufbau noch die alte Liste (Perioden `null`) lesen.
/// Laut bleibt es trotzdem: `debugPrint`, [ferienRueckfallZaehler] und die
/// Aufgabe `ferien_ladefehler`.
bool ferienLadefehlerAktiv = false;

/// Haengt die Ferien aus [map] an [b] und gibt [b] zurueck.
///
/// Die EINE Stelle, an der eine geladene Ferien-Tabelle an Betriebe kommt
/// (Betriebsliste, Heineken-Raster). Setzt IMMER eine Liste, nie `null`:
/// - Betrieb mit Eintraegen → seine Perioden,
/// - Betrieb ohne Eintraege → leere Liste (geladen, keine Ferien),
/// - Betrieb ohne `serverId` (nativ noch nicht synchronisiert) → leere
///   Liste: `betrieb_ferien.betrieb_id` verweist auf `betriebe.id`, ein
///   solcher Betrieb kann also noch keine Perioden haben.
BetriebLocal mitFerienPerioden(BetriebLocal b, FerienPeriodenMap map) {
  final id = b.serverId;
  b.ferienPerioden = id == null ? const [] : (map[id] ?? const []);
  return b;
}

/// Verbindet einen Betriebe-Strom mit der Ferien-Tabelle: Jede Liste kommt
/// erst, wenn [ferien] fertig ist, und jeder Betrieb traegt dann seine
/// Perioden ([mitFerienPerioden]). Grundlage von `betriebeStreamProvider`.
/// Nativ sendet der Isar-Strom bei jeder Aenderung neu; jede Sendung bekommt
/// die Ferien angehaengt.
///
/// Schlaegt [ferien] fehl, kommen die Betriebe TROTZDEM — mit
/// `ferienPerioden = null` («unbekannt»). Betriebe sind der Kern der App
/// (Stoerung erfassen, Rechnung, Suche); ein Ferien-Ladefehler darf sie
/// nicht ausblenden (Entscheid 27.09.2026). Still bleibt es trotzdem nicht:
/// Jede Ferien-Auswertung meldet den Rueckfall ([ferienSlots]), und die
/// Aufgabe «Ferien nicht geladen» steht auf der Heute-Karte und in der
/// Glocke (`ferienLadefehlerProvider`).
Stream<List<BetriebLocal>> betriebeMitFerien(
  Stream<List<BetriebLocal>> betriebe,
  Future<FerienPeriodenMap> ferien,
) {
  // Ein Ladefehler kann eintreffen, bevor jemand den Strom abonniert — er
  // soll dann nicht als «unbehandelt» in der Zone landen (das `await` unten
  // bekommt ihn trotzdem).
  ferien.ignore();
  return _betriebeMitFerien(betriebe, ferien);
}

Stream<List<BetriebLocal>> _betriebeMitFerien(
  Stream<List<BetriebLocal>> betriebe,
  Future<FerienPeriodenMap> ferien,
) async* {
  FerienPeriodenMap? map;
  try {
    map = await ferien;
  } catch (e) {
    ferienLadefehlerAktiv = true;
    debugPrint('[Ferien] Tabelle nicht geladen — Betriebe ohne Ferien: $e');
  }
  await for (final list in betriebe) {
    if (map == null) {
      // Ausdruecklich «unbekannt», nicht «keine Ferien» (leere Liste).
      for (final b in list) {
        b.ferienPerioden = null;
      }
      yield list;
    } else {
      final mitFerien = [for (final b in list) mitFerienPerioden(b, map)];
      // Erst jetzt: ab hier liest jeder Neuaufbau Betriebe MIT Ferien.
      ferienLadefehlerAktiv = false;
      yield mitFerien;
    }
  }
}

/// Alle Ferien-Slots eines Betriebs — ausschliesslich aus
/// [BetriebLocal.ferienPerioden] (Tabelle `betrieb_ferien`).
///
/// WARUM kein Rueckfall mehr auf die fuenf Altspalten `ferien*_start/ende`
/// (seit 27.09.2026): Die Tabelle ist seit 26.09.2026 vollstaendig — alle 47
/// vollstaendigen Alt-Slots stehen darin, die Altspalten sind eingefroren
/// (niemand schreibt sie mehr) und werden nach einer Woche Beobachtung
/// entfernt (DROP). Der Rueckfall war nur fuer die Umstellung da; er hielt
/// aber jeden Pfad am Leben, der die Perioden vergass, und haette nach dem
/// DROP still «keine Ferien» geliefert.
///
/// `null` in [BetriebLocal.ferienPerioden] heisst «nicht geladen» und ist
/// jetzt ein Programmierfehler: Jeder Pfad, der Ferien auswertet, laedt die
/// Perioden vorher ([mitFerienPerioden], `betriebeStreamProvider`,
/// `BetriebFerienRepository.periodenAnhaengen`). Tritt er trotzdem auf,
/// liefert die Funktion `[]` — aber LAUT: `debugPrint` je Betrieb,
/// [ferienRueckfallZaehler] zaehlt mit, und im Debug-Modus (Tests,
/// Entwicklung) bricht ein `assert` sofort ab. Vergessene Ferien sind der
/// schlimmste Fehlerfall — dann faehrt Daniel zu einem geschlossenen Betrieb.
///
/// Ausnahme vom `assert`: der vorgesehene Ladefehler
/// ([ferienLadefehlerAktiv]) — dort ist `null` Absicht, gemeldet wird er
/// ueber die Aufgabe «Ferien nicht geladen».
///
/// Eine LEERE Liste heisst dagegen «geladen, keine Ferien».
///
/// Prueft NICHT [BetriebLocal.keineBetriebsferien] — dafuer gibt es
/// [wirksameFerienSlots], ueber das alle auswertenden Leser gehen.
List<FerienSlot> ferienSlots(BetriebLocal b) {
  final perioden = b.ferienPerioden;
  if (perioden == null) {
    ferienRueckfallZaehler++;
    if (_rueckfallGemeldet.add(b.name)) {
      debugPrint('[Ferien] Rückfall ohne Perioden: ${b.name}');
    }
    assert(
      perioden != null || ferienLadefehlerAktiv,
      'Ferien ohne geladene Perioden ausgewertet (${b.name}) — '
      'mitFerienPerioden() bzw. BetriebFerienRepository.periodenAnhaengen() '
      'vergessen?',
    );
    return const [];
  }
  return [for (final p in perioden) (start: p.von, ende: p.bis)];
}

/// Die Ferien-Slots, die tatsaechlich gelten: leer, sobald der Schalter
/// [BetriebLocal.keineBetriebsferien] gesetzt ist.
///
/// WARUM: Seit v0.141.0 loescht der Schalter die Perioden nicht mehr, er
/// blendet sie nur aus (Analyse R7). Jeder Leser, der Ferien auswertet
/// (Tourenplan, Schliessungs-Gruende, Kalender, Raster), geht deshalb ueber
/// diese Funktion — sonst plante der Tourenplan um ausgeblendete Ferien herum.
/// [ferienSlots] bleibt fuer die seltenen Stellen, die den Rohbestand brauchen.
List<FerienSlot> wirksameFerienSlots(BetriebLocal b) =>
    b.keineBetriebsferien ? const [] : ferienSlots(b);

/// Alle belegten Ferien-Startdaten (leer bei keineBetriebsferien).
List<DateTime> ferienStarts(BetriebLocal b) => [
  for (final s in wirksameFerienSlots(b))
    if (s.start != null) s.start!,
];

/// Alle belegten Ferien-Enddaten (leer bei keineBetriebsferien).
List<DateTime> ferienEnden(BetriebLocal b) => [
  for (final s in wirksameFerienSlots(b))
    if (s.ende != null) s.ende!,
];

/// True wenn [datum] in einer vollstaendig erfassten Ferienperiode liegt
/// (Randtage inklusive). Immer false bei keineBetriebsferien.
bool istInFerien(BetriebLocal b, DateTime datum) {
  for (final s in wirksameFerienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    if (!datum.isBefore(s.start!) && !datum.isAfter(s.ende!)) return true;
  }
  return false;
}
