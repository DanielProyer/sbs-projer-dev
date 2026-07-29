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
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Standard-Umwegfaktor Strasse/Luftlinie.
///
/// Kalibriert am 29.07.2026 gegen 180 beobachtete Übergänge aus den
/// historischen Reinigungen: Median von beobachtet/Luftlinien-Fahrzeit = 2.15.
/// Der Wert liegt bewusst über einem reinen Strassen-Umwegfaktor (~1.6),
/// weil die beobachtete Lücke auch Parkieren und Ein-/Ausladen enthält —
/// und genau diese effektive Übergangszeit soll der Tagesplan abbilden.
const double kFahrzeitFaktor = 2.2;
/// Angenommene Durchschnittsgeschwindigkeit (Berggebiet, Ortsdurchfahrten).
const double kSchnittKmh = 45.0;

int heuristikMinuten({required double luftlinieKm, double faktor = kFahrzeitFaktor}) {
  final min = (luftlinieKm * faktor) / kSchnittKmh * 60;
  return max(3, min.round());
}

(int, FahrzeitQuelle) waehleFahrzeit({int? beobachtet, int? route, required int heuristik}) {
  if (beobachtet != null) return (beobachtet, FahrzeitQuelle.beobachtet);
  if (route != null) return (route, FahrzeitQuelle.route);
  return (heuristik, FahrzeitQuelle.heuristik);
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
