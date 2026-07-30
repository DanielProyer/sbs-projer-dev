// ─── Was ist «noch zu erledigen»? ───
//
// Störungen und Montagen sind planbar, solange sie nicht abgeschlossen sind.
// Die Regel stand bis v0.60.0 an sechs Stellen einzeln im Code (Tourenplan,
// Aufgaben-Screen, Startbildschirm-Zähler) und lief auseinander — hier ist
// sie einmal definiert.

/// Störung ist noch zu erledigen (Status 'offen' oder 'in_bearbeitung').
bool stoerungOffen(String status) =>
    status == 'offen' || status == 'in_bearbeitung';

/// Montage ist noch zu erledigen (Status 'geplant' oder 'in_bearbeitung').
bool montageOffen(String status) =>
    status == 'geplant' || status == 'in_bearbeitung';

/// Wie dringend eine Anlage zur Reinigung ansteht.
///
/// Die Reihenfolge ist die Sortierreihenfolge im Tourenplan — dringend zuerst,
/// [nichtFaellig] zuletzt. `tour_providers.dart` exportiert dieses Enum weiter,
/// damit es dort weiterhin importiert werden kann.
enum FaelligkeitsStatus {
  ueberfaellig,
  faellig,
  baldFaellig,
  endreinigungFaellig,
  eroeffnungFaellig,
  nichtFaellig,
}

/// Filter-Auswahl über der Fällig-Liste im Tourenplan.
///
/// Fünf Knöpfe auf einer Zeile (Wunsch Daniel 28.07.2026). Eröffnung und
/// Endreinigung liegen zusammen unter [saison] — beide sind saisonale
/// Planungsfenster und wurden ohnehin immer gemeinsam an- oder abgewählt.
enum TourFilter { ueberfaellig, faellig, bald, saison, alle }

/// Kurzes Label für den Chip. Bewusst knapp, damit alle fünf nebeneinander
/// auf ein Handy-Display passen, ohne dass die Leiste umbricht.
String tourFilterLabel(TourFilter f) => switch (f) {
  TourFilter.ueberfaellig => 'Überfällig',
  TourFilter.faellig => 'Fällig',
  TourFilter.bald => 'Bald',
  TourFilter.saison => 'Saison',
  TourFilter.alle => 'Alle',
};

/// Die Fälligkeits-Status, die dieser Filter durchlässt.
Set<FaelligkeitsStatus> statusFuer(TourFilter f) => switch (f) {
  TourFilter.ueberfaellig => {FaelligkeitsStatus.ueberfaellig},
  TourFilter.faellig => {FaelligkeitsStatus.faellig},
  TourFilter.bald => {FaelligkeitsStatus.baldFaellig},
  TourFilter.saison => {
    FaelligkeitsStatus.endreinigungFaellig,
    FaelligkeitsStatus.eroeffnungFaellig,
  },
  // «Alle» zeigt auch Anlagen, die noch gar nicht fällig sind — etwa um
  // eine Anlage mitzunehmen, weil man ohnehin in der Region ist.
  TourFilter.alle => FaelligkeitsStatus.values.toSet(),
};

/// Ist der Standard-Satz aktiv? Alles ausser «Alle» — so war die Leiste schon
/// vorher eingestellt (überfällig/fällig/bald/saisonal sichtbar).
Set<TourFilter> get standardTourFilter => {
  TourFilter.ueberfaellig,
  TourFilter.faellig,
  TourFilter.bald,
  TourFilter.saison,
};

/// Kommt ein Eintrag mit diesem Fälligkeits-Status durch die Auswahl?
///
/// Leere Auswahl lässt alles durch (wie bisher: kein Filter = keine
/// Einschränkung). Einträge ohne Fälligkeit — Störungen, Montagen — werden
/// vom Fälligkeitsfilter grundsätzlich nicht angefasst; das entscheidet der
/// Aufrufer.
bool sichtbarImTourfilter(FaelligkeitsStatus status, Set<TourFilter> gewaehlt) {
  if (gewaehlt.isEmpty) return true;
  for (final f in gewaehlt) {
    if (statusFuer(f).contains(status)) return true;
  }
  return false;
}

/// Braucht die Liste auch Anlagen, die nicht fällig sind?
bool zeigtNichtFaellige(Set<TourFilter> gewaehlt) =>
    gewaehlt.isEmpty || gewaehlt.contains(TourFilter.alle);

/// Auswahl nach einem Tipp auf [getippt].
///
/// «Alle» ist exklusiv: Es schaltet die übrigen ab, und ein Tipp auf einen
/// anderen Knopf schaltet «Alle» wieder aus. Das Abwählen des letzten Knopfes
/// ist erlaubt — dann greift die Regel «leer = alles zeigen».
Set<TourFilter> nachTipp(Set<TourFilter> aktuell, TourFilter getippt) {
  if (getippt == TourFilter.alle) {
    return aktuell.contains(TourFilter.alle)
        ? <TourFilter>{}
        : {TourFilter.alle};
  }
  final neu = {...aktuell}..remove(TourFilter.alle);
  if (neu.contains(getippt)) {
    neu.remove(getippt);
  } else {
    neu.add(getippt);
  }
  return neu;
}
