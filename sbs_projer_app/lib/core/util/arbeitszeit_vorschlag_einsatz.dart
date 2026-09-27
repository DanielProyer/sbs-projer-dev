/// Arbeitszeit-Vorschlag für eine Störung/Montage, die ohne Arbeitszeit
/// abgeschlossen wird (Entscheid Daniel 27.09.2026).
///
/// **Warum:** 34 von 36 Störungen seit August haben kein `arbeit_von/bis`.
/// Die Zeitachse schätzt dann «Wegpunkt-Stempel minus geplante Dauer», und
/// «Fahrten aus der Kette» führt den Einsatz als «ohne Zeit» — der Stempel
/// entsteht beim Abschliessen, oft abends zuhause. Beim Abschliessen wird
/// deshalb einmal nachgefragt; dieser Vorschlag belegt die Frage vor, damit
/// meist ein Tipp genügt.
///
/// Rein und ohne Flutter: Die Halte des Tages kommen aus [halteAusKette]
/// (im Formular über `TagesFahrten.halte`).
library;

import 'dart:math' as math;

import 'package:sbs_projer_app/core/util/besuch_dauer.dart'
    show kDauerDefaultMinuten;
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart'
    show hhmmAusMinuten;

/// Raster der geschätzten Zeiten — wie der Tagesplan.
const int kArbeitszeitRasterMin = 5;

/// Schlägt `arbeit_von`/`arbeit_bis` ('HH:mm') für einen Einsatz am
/// [betriebId] vor, der an [datum] ohne Arbeitszeit abgeschlossen wird.
///
/// Reihenfolge der Regeln:
/// 1. **Der Betrieb liegt als Halt in der Kette** ([halteDesTages], Typ
///    Betrieb, gleiche Id) — etwa weil dort eine Reinigung erfasst ist: genau
///    diese Zeiten, ungerundet (es sind erfasste Werte). Ist der Halt nur ein
///    Punkt (ein Stempel am Betrieb), markiert er das ENDE — Vorschlag
///    Stempel minus Dauer bis Stempel, nicht vor dem Arbeitsbeginn (dieselbe
///    Annahme wie die Zeitachse). Ein Zeitfenster geht einem Punkt vor.
/// 2. **Sonst die grösste Lücke der Kette** — Abfahrt eines Halts bis zur
///    Ankunft des nächsten; heute ohne Feierabend zählt auch das offene Ende
///    von der letzten Abfahrt bis [jetzt]. In einer geschlossenen Lücke die
///    Mitte ± Dauer/2, im offenen Ende «jetzt − Dauer» bis «jetzt» (wer
///    gleich nach der Arbeit abschliesst, war eben fertig). Auf 5 Minuten
///    gerundet und nie über die Lücke hinaus: So bleibt der Vorschlag im
///    Arbeitstag und überlappt keinen erfassten Einsatz — sonst entstünde in
///    «Fahrten aus der Kette» eine Ankunft vor der Abfahrt. Bei gleich
///    grossen Lücken gilt die spätere.
/// 3. **Keine Halte, keine Lücke:** heute «jetzt − Dauer» bis «jetzt», an
///    einem anderen Tag `null` (lieber leere Felder als eine erfundene Zeit).
///
/// Welche Lücke der Einsatz wirklich füllte, weiss die Kette nicht (er fehlt
/// ja darin) — die grösste ist die Stelle mit der meisten unerklärten Zeit.
///
/// [geplanteDauerMin] ≤ 0 → Standarddauer [kDauerDefaultMinuten].
({String von, String bis})? arbeitszeitVorschlag({
  required DateTime datum,
  required String? betriebId,
  required List<Halt> halteDesTages,
  required int geplanteDauerMin,
  DateTime? jetzt,
}) {
  final uhr = jetzt ?? DateTime.now();
  final istHeute =
      uhr.year == datum.year &&
      uhr.month == datum.month &&
      uhr.day == datum.day;
  final jetztMin = uhr.hour * 60 + uhr.minute;
  final dauer = geplanteDauerMin > 0 ? geplanteDauerMin : kDauerDefaultMinuten;
  final halte = halteDesTages;

  // 1. Der Betrieb selbst in der Kette.
  final amBetrieb = _betriebsHalt(halte, betriebId);
  if (amBetrieb != null) {
    final an = amBetrieb.ankunftMin!, ab = amBetrieb.abfahrtMin!;
    if (ab > an) return _text(an, ab);
    final von = math.max(an - dauer, _arbeitsbeginn(halte) ?? 0);
    if (an > von) return _text(von, an);
    // Stempel genau beim Arbeitsbeginn: kein brauchbares Fenster — weiter
    // mit den Lücken.
  }

  // 2. Die grösste Lücke.
  final luecke = _groessteLuecke(halte, offenBis: istHeute ? jetztMin : null);
  if (luecke != null) {
    final z = _platzieren(luecke, dauer);
    return _text(z.von, z.bis);
  }

  // 3. Rückfall «jetzt», nur für heute.
  if (!istHeute) return null;
  final bis = _ab(jetztMin);
  final von = math.max(0, _gerundet(bis - dauer));
  return bis > von ? _text(von, bis) : null;
}

// ── intern ──────────────────────────────────────────────────────────────

typedef _Luecke = ({int von, int bis, bool offen});

/// Halt des Betriebs mit beiden Zeiten; ein Zeitfenster vor einem Punkt,
/// sonst der erste.
Halt? _betriebsHalt(List<Halt> halte, String? betriebId) {
  if (betriebId == null) return null;
  Halt? punkt;
  for (final h in halte) {
    if (h.typ != HaltTyp.betrieb || h.id != betriebId) continue;
    final an = h.ankunftMin, ab = h.abfahrtMin;
    if (an == null || ab == null) continue;
    if (ab > an) return h;
    punkt ??= h;
  }
  return punkt;
}

/// Abfahrt des Arbeitsbeginn-Halts (falls erfasst).
int? _arbeitsbeginn(List<Halt> halte) {
  for (final h in halte) {
    if (h.quelle == 'arbeitsbeginn') return h.abfahrtMin;
  }
  return null;
}

/// Grösste Lücke zwischen zwei aufeinanderfolgenden Halten; mit [offenBis]
/// zusätzlich das offene Ende nach dem letzten Halt (der Feierabend-Halt hat
/// keine Abfahrt — mit Feierabend gibt es also kein offenes Ende).
_Luecke? _groessteLuecke(List<Halt> halte, {int? offenBis}) {
  _Luecke? beste;
  void pruefe(int von, int bis, {required bool offen}) {
    if (bis <= von) return; // Überlappung = Erfassungsfehler, keine Lücke
    final b = beste;
    if (b == null || bis - von >= b.bis - b.von) {
      beste = (von: von, bis: bis, offen: offen);
    }
  }

  for (var i = 1; i < halte.length; i++) {
    final a = halte[i - 1].abfahrtMin, b = halte[i].ankunftMin;
    if (a != null && b != null) pruefe(a, b, offen: false);
  }
  final letzteAbfahrt = halte.isEmpty ? null : halte.last.abfahrtMin;
  if (offenBis != null && letzteAbfahrt != null) {
    pruefe(letzteAbfahrt, offenBis, offen: true);
  }
  return beste;
}

/// Legt [dauer] in die Lücke: Mitte (geschlossen) bzw. ans Ende (offen), auf
/// das Raster gerundet und in die Lücke geschoben — notfalls gekürzt. Passt
/// kein Rasterschritt hinein, ist die Lücke selbst der Vorschlag.
({int von, int bis}) _platzieren(_Luecke l, int dauer) {
  final lo = _auf(l.von), hi = _ab(l.bis);
  if (hi - lo < kArbeitszeitRasterMin) return (von: l.von, bis: l.bis);

  int von, bis;
  if (l.offen) {
    bis = hi;
    von = _gerundet(bis - dauer);
  } else {
    von = _gerundet((l.von + l.bis) / 2 - dauer / 2);
    bis = _gerundet(von + dauer);
  }
  if (von < lo) {
    bis += lo - von;
    von = lo;
  }
  if (bis > hi) {
    von -= bis - hi;
    bis = hi;
  }
  if (von < lo) von = lo;
  return (von: von, bis: bis);
}

/// Aufs nächste Raster gerundet.
int _gerundet(num minuten) =>
    (minuten / kArbeitszeitRasterMin).round() * kArbeitszeitRasterMin;

/// Aufs Raster aufgerundet (Untergrenze nach innen).
int _auf(int minuten) =>
    (minuten / kArbeitszeitRasterMin).ceil() * kArbeitszeitRasterMin;

/// Aufs Raster abgerundet (Obergrenze nach innen).
int _ab(int minuten) =>
    (minuten / kArbeitszeitRasterMin).floor() * kArbeitszeitRasterMin;

({String von, String bis}) _text(int von, int bis) =>
    (von: hhmmAusMinuten(von), bis: hhmmAusMinuten(bis));
