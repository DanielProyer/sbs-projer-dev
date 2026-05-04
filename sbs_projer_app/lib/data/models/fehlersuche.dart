import 'package:flutter/material.dart';

/// Ein Zapfanlagen-System (David, Konventionell, Orion, Heigenie)
class TsSystem {
  final String id;
  final String name;
  final String beschreibung;
  final List<TsKomponente> komponenten;
  final List<TsSymptom> symptome;

  const TsSystem({
    required this.id,
    required this.name,
    required this.beschreibung,
    required this.komponenten,
    required this.symptome,
  });
}

/// Ein Bauteil des Systems (für Grafik-Hervorhebung)
class TsKomponente {
  final String id;
  final String name;
  final String? info;

  const TsKomponente({
    required this.id,
    required this.name,
    this.info,
  });
}

/// Ein Symptom = Einstiegspunkt (z.B. "Kein Bier")
class TsSymptom {
  final String id;
  final String name;
  final String? beschreibung;
  final IconData icon;
  final List<TsUrsache> ursachen;

  const TsSymptom({
    required this.id,
    required this.name,
    this.beschreibung,
    required this.icon,
    required this.ursachen,
  });
}

/// Eine mögliche Ursache mit Check-Anleitung
class TsUrsache {
  final String id;
  final String name;
  final String checkAnleitung;
  final String? loesung;
  final List<String> komponentenIds;
  final bool? kundeKannSelbst;

  const TsUrsache({
    required this.id,
    required this.name,
    required this.checkAnleitung,
    this.loesung,
    required this.komponentenIds,
    this.kundeKannSelbst,
  });
}
