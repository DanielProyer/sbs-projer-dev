/// Ist die Klappe «Planung & Arbeitszeit» im Störungsformular offen?
/// (Runde 5, Entscheid Daniel 27.09.2026.)
///
/// **Warum eingeklappt:** Störungen werden praktisch nie vorausgeplant — 34
/// von 36 seit August hatten nicht einmal eine Arbeitszeit. Der Schalter
/// «Erst geplant» und der Arbeitszeit-Block («Arbeit beginnen», Von/Bis)
/// standen trotzdem bei jeder Störung ganz oben. Die Zeit kommt jetzt über
/// die Nachfrage beim Abschliessen (`arbeitszeit_nachfrage.dart`).
///
/// Offen, sobald dort etwas steht, das man sehen muss: der Schalter ist an
/// ([erstGeplant] — auch jede noch offene/laufende Störung), eine
/// Arbeitszeit ist erfasst ([arbeitVon]/[arbeitBis]), oder der Nutzer hat
/// die Klappe in dieser Sitzung selbst geöffnet ([manuellOffen]).
bool planungAufgeklappt({
  required bool erstGeplant,
  required String? arbeitVon,
  required String? arbeitBis,
  required bool manuellOffen,
}) =>
    manuellOffen ||
    erstGeplant ||
    (arbeitVon ?? '').trim().isNotEmpty ||
    (arbeitBis ?? '').trim().isNotEmpty;
