import 'package:flutter/material.dart';

/// EINE Datumsauswahl für die ganze App (Analyse-Runde 4). Grenzen
/// standardmässig 2019 … heute + 2 Jahre; initial wird in die Grenzen
/// geklemmt (sonst wirft showDatePicker). Wächter:
/// test/datumsauswahl_waechter_test.dart.
Future<DateTime?> zeigeDatumsauswahl(
  BuildContext context, {
  required DateTime initial,
  DateTime? erstes,
  DateTime? letztes,
  String? hilfetext,
}) {
  final first = erstes ?? DateTime(2019);
  final last = letztes ?? DateTime.now().add(const Duration(days: 730));
  var init = initial;
  if (init.isBefore(first)) init = first;
  if (init.isAfter(last)) init = last;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first,
    lastDate: last,
    helpText: hilfetext,
  );
}

// Kein gemeinsames DatumFeld: Die vier privaten Feld-Klassen
// (betrieb_form/event_form _DatePickerField, saison_nachtrag und
// war_geschlossen _DatumFeld) zeigen einen leeren Wert je anders an bzw.
// sind ganz anders gebaut — sie behalten ihre Form und rufen intern
// zeigeDatumsauswahl (Review Runde 4, 26.09.2026).
