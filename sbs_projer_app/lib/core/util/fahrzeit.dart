/// Fahrzeit-Heuristik + Kaskaden-Wahl (Spec 2026-07-29).
/// Die gelernten/gerouteten Werte kommen aus der Tabelle `fahrzeiten`
/// (FahrzeitRepository); hier liegt nur die reine, testbare Logik.
library;

import 'dart:math';

enum FahrzeitQuelle { beobachtet, route, heuristik }

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Pauschaler Zuschlag für Parkieren, Ein-/Ausladen und Rüsten zwischen zwei
/// Besuchen — das, was eine beobachtete Lücke über der reinen Fahrzeit hat.
/// Median über 2'807 beobachtete Übergänge: 7.5 min; 5 min minimiert den
/// Fehler (Median 7 min gegenüber 12 min beim alten Modell).
const int kRuestzuschlagMin = 5;

/// Reine Fahrzeit aus der Luftlinie — kalibriert an 804 echten Routen
/// (31.07.2026, `anfahrtszeiten`: beide Startorte zu allen 402 Betrieben).
///
/// **Warum keine Konstanten mehr:** Das frühere Modell (Luftlinie × 2.5 bei
/// 45 km/h) war an kurzen Bündner Bergstrecken kalibriert und skalierte
/// katastrophal — für Domat/Ems → Eich (Luftlinie 104 km) ergab es 346 statt
/// 117 Minuten (Median-Fehler über 100 km: 249 min). Über eine lange Strecke
/// sinkt der Umwegfaktor (Autobahn statt Talstrasse) UND der Schnitt steigt.
/// Beides läuft hier exponentiell gegen den Fernverkehrs-Wert:
/// Umweg 2.20 → 1.45, Schnitt 32 → 78 km/h, Halbwertsstrecke ~18 km.
/// Median-Fehler über alle 804 Routen: 7 min (vorher 35 min).
double reineFahrzeitMinuten(double luftlinieKm) {
  final naehe = exp(-luftlinieKm / 18);
  final umwegFaktor = 1.45 + 0.75 * naehe;
  final schnittKmh = 78 - 46 * naehe;
  return luftlinieKm * umwegFaktor / schnittKmh * 60;
}

/// Geschätzte Übergangszeit zwischen zwei Orten.
///
/// [mitRuestzeit] `true` (Standard) für Fahrten zwischen zwei Besuchen —
/// dort gehören Parkieren und Umladen zur Lücke. `false` für reine
/// Streckenschätzungen (z.B. Anfahrt ab Startort, wenn kein gerouteter Wert
/// vorliegt).
int heuristikMinuten({required double luftlinieKm, bool mitRuestzeit = true}) {
  final min =
      reineFahrzeitMinuten(luftlinieKm) +
      (mitRuestzeit ? kRuestzuschlagMin : 0);
  return max(3, min.round());
}

(int, FahrzeitQuelle) waehleFahrzeit({
  int? beobachtet,
  int? route,
  required int heuristik,
}) {
  if (beobachtet != null) return (beobachtet, FahrzeitQuelle.beobachtet);
  if (route != null) return (route, FahrzeitQuelle.route);
  return (heuristik, FahrzeitQuelle.heuristik);
}

/// Darf eine gemessene Luecke als Fahrzeit gelernt werden?
///
/// Ohne diese Pruefung landet jede Stoerung, Pause oder Terminwartezeit
/// zwischen zwei Reinigungen als «Fahrzeit» in der Lernkurve. Ein Blick in die
/// Daten am 30.07.2026: 652 von 2882 beobachteten Werten (23 %) lagen mehr als
/// doppelt so hoch wie die tatsaechliche Route — im Schnitt 43 min zu viel.
///
/// Regel: Ohne [referenzMinuten] (noch keine Route bekannt) bleibt es bei der
/// groben Bereichspruefung des Aufrufers. Mit Referenz muss die Luecke im
/// Fenster 0.5x–2x liegen; zusaetzlich sind [toleranzMin] Minuten Zuschlag
/// immer erlaubt, damit kurze Strecken (Route 4 min, real 9 min inkl.
/// Parkieren) nicht faelschlich verworfen werden.
///
/// Bewusst NICHT gelernt wird lieber einmal zu oft: Ein fehlender Lernschritt
/// kostet nichts (die Route bleibt als Wert stehen), ein falscher verdirbt die
/// Planung fuer Monate.
bool lueckePlausibel({
  required int lueckeMinuten,
  required int? referenzMinuten,
  int toleranzMin = 10,
}) {
  if (referenzMinuten == null || referenzMinuten <= 0) return true;
  if (lueckeMinuten < referenzMinuten * 0.5) return false;
  return lueckeMinuten <= referenzMinuten * 2 + toleranzMin;
}

/// Fahrt-Luecke zwischen dem Ende eines Besuchs und dem Start des naechsten
/// (beide 'HH:mm'), fuer die Beobachtungs-Nachfuehrung (FahrzeitRepository.
/// beobachtungNachfuehren). Gleiche Gueltigkeitsregel wie der Backfill in
/// Migration 152: 3-120 min gilt als plausible Fahrzeit, alles ausserhalb
/// (negativ/ueberlappend oder zu lang, z.B. Mittagspause) wird verworfen.
int? fahrtLueckeMinuten(String? endeVorher, String? startNeu) {
  int? toMin(String? s) {
    if (s == null) return null;
    final t = s.split(':');
    if (t.length < 2) return null;
    final h = int.tryParse(t[0]), m = int.tryParse(t[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final a = toMin(endeVorher), b = toMin(startNeu);
  if (a == null || b == null) return null;
  final luecke = b - a;
  if (luecke < 3 || luecke > 120) return null;
  return luecke;
}
