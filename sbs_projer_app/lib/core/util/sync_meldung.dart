/// Was dem Nutzer nach einem Sync angezeigt wird.
typedef SyncMeldung = ({String text, bool istFehler});

/// Baut aus dem Sync-Ergebnis eine Meldung für den Nutzer.
///
/// **Warum:** «Sync erzwingen» meldete früher nur «Synchronisierung
/// gestartet…» und danach nie wieder etwas — das Ergebnis wurde verworfen.
/// Zusammen mit den satzweise verschluckten Push-Fehlern (siehe
/// `push_einzeln.dart`) hiess das: Fehlende Daten sahen aus wie übertragene.
/// Behoben am 24.08.2026.
///
/// Der erste Fehler steht im Klartext dabei — die blosse Anzahl sagt nicht,
/// ob es ein vorübergehender Netzfehler oder ein kaputter Datensatz ist.
SyncMeldung syncMeldung({
  required int pushed,
  required int pulled,
  required List<String> fehler,
}) {
  final bilanz = 'gesendet $pushed, empfangen $pulled';

  if (fehler.isEmpty) {
    if (pushed == 0 && pulled == 0) {
      return (text: 'Alles aktuell — nichts zu übertragen', istFehler: false);
    }
    return (text: 'Synchronisiert: $bilanz', istFehler: false);
  }

  final kopf = fehler.length == 1
      ? 'Sync unvollständig (1 Problem)'
      : 'Sync unvollständig (${fehler.length} Probleme)';
  return (text: '$kopf: ${fehler.first} · $bilanz', istFehler: true);
}
