import 'package:flutter/material.dart';
import 'package:sbs_projer_app/data/models/fehlersuche.dart';

final heigenieSystem = TsSystem(
  id: 'heigenie',
  name: 'Heigenie',
  beschreibung:
      'Neustes System der Heineken. Warmanstich mit Durchlaufkühler. '
      'Leitung-in-Leitung-Prinzip für optimale Kühlung. Service alle 6 Monate. '
      'Nur Heigenie-Hahn, kein Kompensator.',
  komponenten: const [
    TsKomponente(
      id: 'gasflasche',
      name: 'Gasflasche',
      info: 'Aligal 2 oder Aligal 13',
    ),
    TsKomponente(
      id: 'manometer',
      name: 'Manometer',
    ),
    TsKomponente(
      id: 'tank',
      name: 'Biertank',
    ),
    TsKomponente(
      id: 'zapfkopf',
      name: 'Zapfkopf',
    ),
    TsKomponente(
      id: 'durchlaufkuehler',
      name: 'Durchlaufkühler',
      info: 'Mit Pumpe für Leitung-in-Leitung-Kühlung',
    ),
    TsKomponente(
      id: 'leitung_in_leitung',
      name: 'Leitung-in-Leitung',
      info: 'Bierleitung innerhalb einer Kühlleitung',
    ),
    TsKomponente(
      id: 'zapfhahn',
      name: 'Heigenie-Hahn',
      info: 'Nur ein Hahntyp, kein Kompensator',
    ),
  ],
  symptome: const [
    TsSymptom(
      id: 'platzhalter',
      name: 'Daten folgen',
      beschreibung:
          'Die Symptome und Ursachen für das Heigenie-System werden noch erfasst.',
      icon: Icons.hourglass_empty,
      ursachen: [],
    ),
  ],
);
