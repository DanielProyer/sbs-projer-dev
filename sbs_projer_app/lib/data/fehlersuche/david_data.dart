import 'package:flutter/material.dart';
import 'package:sbs_projer_app/data/models/fehlersuche.dart';

final davidSystem = TsSystem(
  id: 'david',
  name: 'David',
  beschreibung:
      'Kompaktes Kühlsystem mit Schlauchführung. Nur Aligal 2, Idealdruck 0.45–0.50 Bar. '
      'Platz für 2 × 20l Tanks, ca. 8h Kühlzeit. Kein Kompensator.',
  komponenten: const [
    TsKomponente(
      id: 'gasflasche',
      name: 'Gasflasche',
      info: 'Nur Aligal 2 erlaubt',
    ),
    TsKomponente(
      id: 'manometer',
      name: 'Manometer',
      info: 'Idealdruck 0.45–0.50 Bar',
    ),
    TsKomponente(
      id: 'tank',
      name: 'Tank (20l)',
      info: '2 Tanks, ca. 8h Kühlzeit',
    ),
    TsKomponente(
      id: 'schlauchfuehrung',
      name: 'Schlauchführung',
      info: 'Schlauch wird mit Kappe eingeführt',
    ),
    TsKomponente(
      id: 'plastikleitung',
      name: 'Plastikleitung',
    ),
    TsKomponente(
      id: 'kuehlung',
      name: 'Kühlung (David)',
      info: 'Ideale Temperatur 1.5–3.0 °C',
    ),
    TsKomponente(
      id: 'saeule',
      name: 'Säule',
    ),
    TsKomponente(
      id: 'zapfhahn',
      name: 'Zapfhahn',
      info: 'Kein Kompensator',
    ),
  ],
  symptome: [
    // 1. Kein Bier
    TsSymptom(
      id: 'kein_bier',
      name: 'Kein Bier',
      beschreibung: 'Es kommt kein Bier aus dem Hahn',
      icon: Icons.block,
      ursachen: [
        const TsUrsache(
          id: 'gasflasche_leer',
          name: 'Gasflasche leer',
          checkAnleitung:
              'Manometer prüfen – zeigt es 0 Bar? Gasflasche aufdrehen und prüfen ob Gas kommt.',
          loesung: 'Neue Gasflasche anschliessen. Nur Aligal 2 verwenden!',
          komponentenIds: ['gasflasche', 'manometer'],
          kundeKannSelbst: true,
        ),
        const TsUrsache(
          id: 'tank_eingefroren',
          name: 'Tank eingefroren',
          checkAnleitung:
              'Tank anfassen – ist er steinhart/eisig? Kühlung prüfen: Temperatur unter 0 °C?',
          loesung:
              'Tank aus dem System nehmen und bei Raumtemperatur auftauen lassen. '
              'Kühltemperatur kontrollieren (Soll: 1.5–3.0 °C).',
          komponentenIds: ['tank', 'kuehlung'],
          kundeKannSelbst: false,
        ),
      ],
    ),

    // 2. Bier läuft langsam
    TsSymptom(
      id: 'bier_langsam',
      name: 'Bier läuft langsam',
      beschreibung: 'Das Bier fliesst nur tropfenweise oder sehr langsam',
      icon: Icons.speed,
      ursachen: [
        const TsUrsache(
          id: 'druck_niedrig',
          name: 'Druck zu niedrig',
          checkAnleitung:
              'Manometer ablesen – liegt der Druck unter 0.45 Bar? '
              'Gasflasche prüfen: ist sie offen und hat noch Inhalt?',
          loesung:
              'Druck auf 0.45–0.50 Bar einstellen. Achtung: System reagiert sehr sensibel auf Druckveränderungen!',
          komponentenIds: ['manometer', 'gasflasche'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'manometer_defekt_langsam',
          name: 'Manometer defekt',
          checkAnleitung:
              'Zeigt das Manometer einen unrealistischen Wert? Nadel klemmt oder springt? '
              'Der korrekte Druck kann nur von Heineken Technikern mit Messgerät geprüft werden.',
          loesung: 'Manometer austauschen lassen (Heineken Techniker).',
          komponentenIds: ['manometer'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'lippenventil_verklemmt',
          name: 'Lippenventil Manometer verklemmt',
          checkAnleitung:
              'Lippenventil am Manometer prüfen – klemmt es in geschlossener Position? '
              'Ventil vorsichtig bewegen.',
          loesung:
              'Lippenventil lösen oder Manometer austauschen lassen.',
          komponentenIds: ['manometer'],
          kundeKannSelbst: false,
        ),
      ],
    ),

    // 3. Bier läuft zu schnell
    TsSymptom(
      id: 'bier_schnell',
      name: 'Bier läuft zu schnell',
      beschreibung: 'Das Bier schiesst unkontrolliert aus dem Hahn',
      icon: Icons.fast_forward,
      ursachen: [
        const TsUrsache(
          id: 'druck_hoch',
          name: 'Druck zu hoch',
          checkAnleitung:
              'Manometer ablesen – liegt der Druck über 0.50 Bar? '
              'Kein Kompensator vorhanden → Druck muss stimmen!',
          loesung:
              'Druck auf 0.45–0.50 Bar reduzieren. Achtung: System reagiert sehr sensibel!',
          komponentenIds: ['manometer', 'gasflasche'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'manometer_defekt_schnell',
          name: 'Manometer defekt',
          checkAnleitung:
              'Zeigt das Manometer den korrekten Druck, aber Bier fliesst trotzdem zu schnell? '
              'Manometer-Anzeige könnte falsch sein.',
          loesung: 'Manometer austauschen lassen (Heineken Techniker).',
          komponentenIds: ['manometer'],
          kundeKannSelbst: false,
        ),
      ],
    ),

    // 4. Bier schäumt
    TsSymptom(
      id: 'bier_schaeumt',
      name: 'Bier schäumt',
      beschreibung: 'Übermässige Schaumbildung beim Zapfen',
      icon: Icons.bubble_chart,
      ursachen: [
        const TsUrsache(
          id: 'kuehlung_defekt',
          name: 'Kühlung defekt',
          checkAnleitung:
              'Biertemperatur messen – ist sie über 3.0 °C? '
              'David-Kühlung prüfen: läuft der Kompressor? Kondensator sauber?',
          loesung:
              'Kühlung reparieren/reinigen. Soll-Temperatur: 1.5–3.0 °C. '
              'Tank evtl. in Kühlzelle vorkühlen.',
          komponentenIds: ['kuehlung'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'falsches_gas',
          name: 'Falsches Gas',
          checkAnleitung:
              'Gasflasche kontrollieren – ist es wirklich Aligal 2? '
              'Beim David darf NUR Aligal 2 verwendet werden!',
          loesung: 'Gasflasche durch Aligal 2 ersetzen.',
          komponentenIds: ['gasflasche'],
          kundeKannSelbst: true,
        ),
        const TsUrsache(
          id: 'hahn_loose',
          name: 'Hahn loose',
          checkAnleitung:
              'Zapfhahn bewegen – wackelt er? Ist die Verschraubung fest?',
          loesung: 'Zapfhahn festziehen oder Dichtung ersetzen.',
          komponentenIds: ['zapfhahn'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'plastikleitung_defekt',
          name: 'Plastikleitung defekt',
          checkAnleitung:
              'Plastikleitung visuell prüfen – Risse, Knicke oder poröse Stellen? '
              'Verbindungsstellen kontrollieren.',
          loesung: 'Plastikleitung ersetzen.',
          komponentenIds: ['plastikleitung'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'tank_defekt',
          name: 'Tank defekt',
          checkAnleitung:
              'Tank auf Beschädigungen prüfen – Dellen, Undichtigkeiten? '
              'Ventil in Ordnung?',
          loesung: 'Tank austauschen und defekten Tank melden.',
          komponentenIds: ['tank'],
          kundeKannSelbst: true,
        ),
        const TsUrsache(
          id: 'zapfkopf_defekt',
          name: 'Zapfkopf defekt',
          checkAnleitung:
              'Zapfkopf prüfen – schliesst er korrekt? Dichtung intakt? '
              'Zischt es beim Anstechen?',
          loesung: 'Zapfkopf-Dichtung ersetzen oder Zapfkopf austauschen.',
          komponentenIds: ['tank'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'falscher_druck',
          name: 'Falscher Druck',
          checkAnleitung:
              'Manometer ablesen – liegt der Druck ausserhalb 0.45–0.50 Bar? '
              'Zu hoher Druck = häufigste Schaum-Ursache beim David!',
          loesung:
              'Druck auf 0.45–0.50 Bar korrigieren. '
              'Bei wiederkehrendem Problem: Manometer prüfen lassen.',
          komponentenIds: ['manometer', 'gasflasche'],
          kundeKannSelbst: false,
        ),
      ],
    ),

    // 5. Schlauch lässt sich nicht einführen
    TsSymptom(
      id: 'schlauch_problem',
      name: 'Schlauch lässt sich nicht einführen',
      beschreibung: 'Der Bierschlauch kann nicht in die Schlauchführung eingeführt werden',
      icon: Icons.link_off,
      ursachen: [
        const TsUrsache(
          id: 'versatz_saeule',
          name: 'Versatz in Säule',
          checkAnleitung:
              'Säule visuell prüfen – ist sie gerade montiert? '
              'Innere Führung auf Versatz kontrollieren.',
          loesung: 'Säule neu ausrichten oder Führung korrigieren.',
          komponentenIds: ['saeule', 'schlauchfuehrung'],
          kundeKannSelbst: false,
        ),
        const TsUrsache(
          id: 'schlauch_ohne_kappe',
          name: 'Schlauch ohne Kappe eingeführt',
          checkAnleitung:
              'Hat der Schlauch die Schutzkappe? Ohne Kappe kann der Schlauch '
              'in der Führung hängenbleiben.',
          loesung:
              'Schlauch mit Kappe einführen. Falls Kappe fehlt: neue Kappe aufsetzen.',
          komponentenIds: ['schlauchfuehrung'],
          kundeKannSelbst: true,
        ),
        const TsUrsache(
          id: 'schlauchfuehrung_deformiert',
          name: 'Schlauchführung deformiert',
          checkAnleitung:
              'Schlauchführung inspizieren – verbogen, eingedellt oder blockiert?',
          loesung: 'Schlauchführung richten oder ersetzen.',
          komponentenIds: ['schlauchfuehrung'],
          kundeKannSelbst: false,
        ),
      ],
    ),

    // 6. Bier ist trüb oder schmeckt komisch
    TsSymptom(
      id: 'bier_trueb',
      name: 'Bier ist trüb oder schmeckt komisch',
      beschreibung: 'Optische oder geschmackliche Veränderung des Biers',
      icon: Icons.visibility_off,
      ursachen: [
        const TsUrsache(
          id: 'tank_schlechte_qualitaet',
          name: 'Tank mit schlechter Qualität',
          checkAnleitung:
              'MHD auf dem Tank prüfen – ist es abgelaufen? '
              'Wurde der Tank korrekt gelagert (Temperatur, Licht)?',
          loesung:
              'Tank austauschen und bei Heineken/Lieferant reklamieren.',
          komponentenIds: ['tank'],
          kundeKannSelbst: true,
        ),
        const TsUrsache(
          id: 'tank_war_eingefroren',
          name: 'Tank war eingefroren',
          checkAnleitung:
              'Wurde der Tank zwischenzeitlich eingefroren? '
              'Eis-Kristalle im Bier? Kühltemperatur-Verlauf prüfen.',
          loesung:
              'Tank entsorgen – eingefrorenes Bier ist nicht mehr verwendbar. '
              'Kühltemperatur auf 1.5–3.0 °C einstellen.',
          komponentenIds: ['tank', 'kuehlung'],
          kundeKannSelbst: true,
        ),
        const TsUrsache(
          id: 'falsches_bier',
          name: 'Falsches Bier',
          checkAnleitung:
              'Biersorte auf dem Tank prüfen – stimmt sie mit der Bestellung überein? '
              'Verwechslung bei der Lieferung?',
          loesung: 'Korrekten Tank einsetzen.',
          komponentenIds: ['tank'],
          kundeKannSelbst: true,
        ),
      ],
    ),
  ],
);
