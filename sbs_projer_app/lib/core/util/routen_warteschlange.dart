/// Globale, serielle Warteschlange für Routing-Anfragen (27.09.2026).
///
/// Die Edge Function `fahrzeit-route` fragt den öffentlichen
/// OSRM-Demo-Server, der höchstens eine Anfrage pro Sekunde erlaubt. Ohne
/// Schlange liefen Nachroute-Läufe parallel (Monatswechsel, Neuberechnung
/// nach jedem Erfolg) — die Logs zeigten 3 Anfragen/s. Hier läuft immer nur
/// EINE Anfrage, und zwischen dem Ende der einen und dem Start der nächsten
/// liegen mindestens [kRoutenAbstand]. Neue Anfragen reihen sich hinten an;
/// wer mehrere Anfragen auf einmal einreiht (ein Lauf), wird nicht von einem
/// späteren Lauf unterbrochen.
///
/// Bewusst ohne Flutter-/Supabase-Abhängigkeit: Uhr und Warten sind
/// einspritzbar, damit der Test die Abstände prüft, ohne zu warten.
library;

/// Mindestpause zwischen zwei Anfragen (OSRM-Demo: 1/s, plus Reserve).
const kRoutenAbstand = Duration(milliseconds: 1100);

class RoutenWarteschlange {
  RoutenWarteschlange({
    this.abstand = kRoutenAbstand,
    Future<void> Function(Duration dauer)? warten,
    DateTime Function()? jetzt,
  }) : _warten = warten ?? _echtWarten,
       _jetzt = jetzt ?? DateTime.now;

  final Duration abstand;
  final Future<void> Function(Duration dauer) _warten;
  final DateTime Function() _jetzt;

  /// Ende der Schlange: fertig, sobald die zuletzt eingereihte Anfrage
  /// durch ist (auch bei Fehler).
  Future<void> _ende = Future<void>.value();

  /// Wann die letzte Anfrage fertig war (`null` = noch keine).
  DateTime? _letzteFertig;

  /// Reiht [anfrage] ein und liefert ihr Ergebnis (oder ihren Fehler). Die
  /// Anfrage startet erst, wenn alle vorher eingereihten durch sind und seit
  /// der letzten mindestens [abstand] vergangen ist.
  Future<T> einreihen<T>(Future<T> Function() anfrage) {
    final ergebnis = _ende.then<T>((_) async {
      final letzte = _letzteFertig;
      if (letzte != null) {
        final rest = abstand - _jetzt().difference(letzte);
        if (rest > Duration.zero) await _warten(rest);
      }
      try {
        return await anfrage();
      } finally {
        _letzteFertig = _jetzt();
      }
    });
    // Ein Fehler gehört dem Aufrufer — die Schlange läuft weiter.
    _ende = ergebnis.then<void>((_) {}, onError: (Object _) {});
    return ergebnis;
  }
}

Future<void> _echtWarten(Duration dauer) => Future<void>.delayed(dauer);
