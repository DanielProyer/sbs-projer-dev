import 'package:flutter/material.dart';
import 'package:sbs_projer_app/data/models/fehlersuche.dart';

final konventionellSystem = TsSystem(
  id: 'konventionell',
  name: 'Konventionell',
  beschreibung:
      'Warmanstich, Kaltanstich oder Buffetanstich. Durchlaufkühler mit Python '
      'und Begleitkühlung. Verschiedene Säulen und Hahntypen möglich.',
  komponenten: const [
    TsKomponente(
      id: 'gasflasche',
      name: 'Gasflasche',
      info: 'Aligal 2 (Warmanstich) oder Aligal 13 (Kaltanstich)',
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
      info: 'Verschiedene Modelle',
    ),
    TsKomponente(
      id: 'python',
      name: 'Python',
      info: 'Bündel von Bierleitungen, isoliert, mit Begleitkühlung',
    ),
    TsKomponente(
      id: 'backpython',
      name: 'Backpython',
      info: 'Kühlung Tank → Kühler (bei einigen Anlagen)',
    ),
    TsKomponente(
      id: 'saeule',
      name: 'Säule',
      info: 'Verschiedene Typen, auch elektronisch',
    ),
    TsKomponente(
      id: 'zapfhahn',
      name: 'Zapfhahn',
      info: 'Mit Kompensator',
    ),
    TsKomponente(
      id: 'fasskuehler',
      name: 'Fasskühler / Kühlzelle',
      info: 'Nur bei Kaltanstich',
    ),
  ],
  symptome: const [
    TsSymptom(
      id: 'platzhalter',
      name: 'Daten folgen',
      beschreibung:
          'Die Symptome und Ursachen für das konventionelle System werden noch erfasst.',
      icon: Icons.hourglass_empty,
      ursachen: [],
    ),
  ],
);
