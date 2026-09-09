/// Zählt, welche Route wie oft geöffnet wird — Punkt 5 der App-Analyse vom
/// 08.09.2026.
///
/// Ohne Zahlen ist «Anlagen braucht niemand» eine Meinung. Die Vorschläge A6
/// (Ballast aus dem Hauptmenü) und B2 (Einsätze zusammenführen) hängen an
/// dieser Messung.
///
/// Gezählt wird das Routen-MUSTER aus dem NavigatorObserver
/// (`/betriebe/:id`), nie die konkrete Adresse — es landen also keine
/// Datensatz-IDs in der Messung.
library;

import 'dart:convert';

/// Eine Zeile für `route_nutzung`: Route, Gerät und Tag bilden den Schlüssel.
class NutzungEintrag {
  final String route;
  final String geraet;
  final DateTime tag;
  final int anzahl;

  const NutzungEintrag({
    required this.route,
    required this.geraet,
    required this.tag,
    required this.anzahl,
  });
}

/// Handy oder Desktop — die Trennung aus Befund 4 der Analyse: Werkstatt und
/// Büro sind zwei verschiedene Nutzungen derselben App. 600 px ist die
/// Grenze, ab der das Layout zweispaltig wird.
String geraeteKlasse(double breite) => breite < 600 ? 'handy' : 'desktop';

/// Der Login sagt nichts über die Nutzung, und Übergänge ohne Namen (Dialoge,
/// Sheets) wären nur Rauschen.
bool routeZaehlbar(String? route) =>
    route != null && route.isNotEmpty && route != '/login';

/// Sammelt Aufrufe und schickt sie gebündelt weiter.
///
/// Gesendet wird erst ab [schwelle] Ereignissen (oder wenn jemand [senden]
/// ruft) — ein Netzaufruf pro Bildschirmwechsel wäre Verschwendung.
/// Schlägt das Senden fehl, bleibt alles im Puffer und geht beim nächsten Mal
/// mit: Daniel ist regelmässig im Keller ohne Empfang, und ausgerechnet die
/// Werkstatt-Nutzung wäre sonst untererfasst.
class RouteZaehler {
  static const int schwelle = 10;

  final Future<void> Function(List<NutzungEintrag>) _senden;
  final Future<String?> Function() _lesen;
  final Future<void> Function(String?) _schreiben;
  final DateTime Function() _heute;
  final double Function() _breite;

  /// Schlüssel `route|geraet|jjjj-mm-tt` → Anzahl.
  final Map<String, int> _puffer = {};
  int _seitLetztemSenden = 0;
  bool _sendetGerade = false;

  RouteZaehler({
    required Future<void> Function(List<NutzungEintrag>) senden,
    required Future<String?> Function() lesen,
    required Future<void> Function(String?) schreiben,
    required DateTime Function() heute,
    required double Function() breite,
  })  : _senden = senden,
        _lesen = lesen,
        _schreiben = schreiben,
        _heute = heute,
        _breite = breite;

  /// Holt zurück, was beim letzten Mal nicht durchkam.
  Future<void> laden() async {
    final roh = await _lesen();
    if (roh == null || roh.isEmpty) return;
    try {
      final map = (jsonDecode(roh) as Map).cast<String, dynamic>();
      map.forEach((k, v) {
        if (v is int && v > 0 && k.split('|').length == 3) {
          _puffer[k] = (_puffer[k] ?? 0) + v;
        }
      });
    } catch (_) {
      // Kaputter Puffer ist kein Grund, die App zu stören — verwerfen.
      await _schreiben(null);
    }
  }

  Future<void> zaehle(String route) async {
    if (!routeZaehlbar(route)) return;
    final t = _heute();
    final tag =
        '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final key = '$route|${geraeteKlasse(_breite())}|$tag';
    _puffer[key] = (_puffer[key] ?? 0) + 1;
    _seitLetztemSenden++;
    await _ablegen();
    if (_seitLetztemSenden >= schwelle) await senden();
  }

  /// Überträgt den Puffer. Erfolg leert ihn, Misserfolg lässt ihn stehen.
  Future<void> senden() async {
    if (_puffer.isEmpty || _sendetGerade) return;
    _sendetGerade = true;
    final schnappschuss = Map<String, int>.from(_puffer);
    try {
      await _senden(_zuEintraegen(schnappschuss));
      // Nur das Gesendete abziehen: Während der Übertragung kann weiter
      // gezählt worden sein.
      schnappschuss.forEach((k, v) {
        final rest = (_puffer[k] ?? 0) - v;
        if (rest > 0) {
          _puffer[k] = rest;
        } else {
          _puffer.remove(k);
        }
      });
      _seitLetztemSenden = 0;
      await _ablegen();
    } catch (_) {
      // Bleibt im Puffer, nächster Versuch später.
    } finally {
      _sendetGerade = false;
    }
  }

  List<NutzungEintrag> _zuEintraegen(Map<String, int> m) {
    return m.entries.map((e) {
      final teile = e.key.split('|');
      final d = teile[2].split('-');
      return NutzungEintrag(
        route: teile[0],
        geraet: teile[1],
        tag: DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2])),
        anzahl: e.value,
      );
    }).toList();
  }

  Future<void> _ablegen() async {
    await _schreiben(_puffer.isEmpty ? null : jsonEncode(_puffer));
  }
}
