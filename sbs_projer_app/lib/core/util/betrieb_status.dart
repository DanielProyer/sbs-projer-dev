/// Betrieb-Status-Semantik (app-weit einheitlich).
///
/// Ein Betrieb ist **operativ**, wenn er betreut wird: `aktiv` oder
/// `saisonpause` (aktiv, aber Pause). Inaktive/geschlossene Betriebe sollen
/// standardmässig nirgends erscheinen — nur, wenn ein Filter das explizit setzt.
bool istBetriebOperativ(String status) =>
    status == 'aktiv' || status == 'saisonpause';
