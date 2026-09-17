/// Adresse und Mail eines Betriebs in die Felder der Rechnungsadresse
/// übernehmen. Reine Funktion, ohne IO — damit die Regel prüfbar bleibt.
///
/// WARUM es diesen Weg gibt: Von 229 aktiven eigenen Kunden hatten am
/// 17.09.2026 nur 74 eine Rechnungsadresse, und bei 37 davon — der Hälfte —
/// war sie eine reine Abschrift der Betriebsdaten. Das wurde jedes Mal von
/// Hand abgetippt.
///
/// WARUM `firma` NICHT dabei ist: `firma` ist die Rechnungsempfängerin (oft
/// eine Betreiber-GmbH), nicht der Betrieb. Von 75 erfassten Adressen trug
/// sie genau **einmal** den Betriebsnamen. `objekt` dagegen ist bei 73 von 75
/// der Betriebsname — das belegt das Formular ohnehin schon selbst vor.
/// Beide zu füllen wäre schädlich: `adressZeilen()` setzt firma und objekt
/// untereinander, der Name stünde doppelt auf der Rechnung und im QR-Namen.
library;

/// Die Felder, die aus einem Betrieb stammen können.
typedef BetriebsAdresse = ({
  String strasse,
  String nr,
  String plz,
  String ort,
  String email,
});

/// Was die Übernahme mit einem Feld tut.
typedef UebernahmeFeld = ({String name, String alt, String neu});

/// Das Ergebnis einer Übernahme: die neuen Werte und was sich dabei ändert.
typedef Uebernahme = ({
  BetriebsAdresse werte,
  List<UebernahmeFeld> geaendert,
  List<UebernahmeFeld> ueberschrieben,
});

/// Führt die Übernahme durch.
///
/// Zwei Regeln, beide aus Vorsicht:
/// 1. **Ein leeres Betriebsfeld überschreibt nie.** Sonst wäre ein Fehltipp
///    ein Datenverlust — der Betrieb kennt oft nur Ort und PLZ, die
///    Rechnungsadresse dagegen die volle Strasse.
/// 2. **Gleiche Werte gelten nicht als Änderung.** Sonst meldet der Knopf
///    Arbeit, die er gar nicht getan hat.
///
/// [ueberschrieben] listet die Felder, die einen anderen, nicht leeren Wert
/// hatten — die Meldung nennt sie, damit ein Tipp nichts still verändert.
Uebernahme uebernehmen({
  required BetriebsAdresse formular,
  required BetriebsAdresse betrieb,
}) {
  final geaendert = <UebernahmeFeld>[];
  final ueberschrieben = <UebernahmeFeld>[];

  String feld(String name, String alt, String neu) {
    final quelle = neu.trim();
    final bisher = alt.trim();
    if (quelle.isEmpty) return alt; // Regel 1
    if (quelle == bisher) return alt; // Regel 2
    final eintrag = (name: name, alt: bisher, neu: quelle);
    geaendert.add(eintrag);
    if (bisher.isNotEmpty) ueberschrieben.add(eintrag);
    return quelle;
  }

  final werte = (
    strasse: feld('Strasse', formular.strasse, betrieb.strasse),
    nr: feld('Nr.', formular.nr, betrieb.nr),
    plz: feld('PLZ', formular.plz, betrieb.plz),
    ort: feld('Ort', formular.ort, betrieb.ort),
    email: feld('E-Mail', formular.email, betrieb.email),
  );

  return (werte: werte, geaendert: geaendert, ueberschrieben: ueberschrieben);
}

/// Die Meldung nach einem Tipp auf den Knopf.
///
/// Sie sagt immer, WAS passiert ist — auch wenn nichts passiert ist. Ein
/// Knopf, der stumm bleibt, lässt offen, ob er kaputt ist oder nichts zu tun
/// hatte. (Siehe die Meldungs-Fehler vom 17.09.2026.)
String uebernahmeMeldung(Uebernahme u, {required bool betriebHatDaten}) {
  if (!betriebHatDaten) {
    return 'Beim Betrieb ist keine Adresse hinterlegt — nichts zu übernehmen.';
  }
  if (u.geaendert.isEmpty) {
    return 'Alles steht schon so wie beim Betrieb — nichts geändert.';
  }
  final namen = u.geaendert.map((f) => f.name).join(', ');
  if (u.ueberschrieben.isEmpty) {
    return 'Übernommen: $namen.';
  }
  final ersetzt = u.ueberschrieben.map((f) => f.name).join(', ');
  return 'Übernommen: $namen. Überschrieben wurde $ersetzt — '
      'noch nicht gespeichert, «Zurück» verwirft es.';
}
