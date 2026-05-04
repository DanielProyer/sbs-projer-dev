import 'package:flutter/material.dart';
import 'package:sbs_projer_app/data/models/fehlersuche.dart';

final orionSystem = TsSystem(
  id: 'orion',
  name: 'Orion',
  beschreibung:
      'Grosstanksystem mit 500l oder 1000l Tanks. Druckgas durch Kompressor. '
      'Immer mit Durchlaufkühler und Python. Füllstandsmessung an Heineken.',
  komponenten: const [
    TsKomponente(
      id: 'grosstank',
      name: 'Grosstank',
      info: '500l oder 1000l, direkt vom Lastwagen befüllt',
    ),
    TsKomponente(
      id: 'kompressor',
      name: 'Kompressor',
      info: 'Erzeugt den Druck (kein Gasflaschen-System)',
    ),
    TsKomponente(
      id: 'fuellstandsmessung',
      name: 'Füllstandsmessung',
      info: 'Elektronisch, übermittelt an Heineken. Häufiges Resetten nötig.',
    ),
    TsKomponente(
      id: 'durchlaufkuehler',
      name: 'Durchlaufkühler',
    ),
    TsKomponente(
      id: 'python',
      name: 'Python',
      info: 'Mit Begleitkühlung',
    ),
    TsKomponente(
      id: 'kuehlung',
      name: 'Kühlung',
      info: 'Kühlzelle oder passive Kühlung',
    ),
    TsKomponente(
      id: 'saeule',
      name: 'Säule',
      info: 'Verschiedene Typen möglich',
    ),
    TsKomponente(
      id: 'zapfhahn',
      name: 'Zapfhahn',
    ),
  ],
  symptome: const [
    TsSymptom(
      id: 'platzhalter',
      name: 'Daten folgen',
      beschreibung:
          'Die Symptome und Ursachen für das Orion-System werden noch erfasst.',
      icon: Icons.hourglass_empty,
      ursachen: [],
    ),
  ],
);
