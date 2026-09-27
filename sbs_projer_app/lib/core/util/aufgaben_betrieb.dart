/// Aufgaben eines Betriebs (Migration 212, Entscheid Daniel 27.09.2026).
///
/// Quelle sind die rohen Zeilen der Tabelle `aufgaben`
/// (`aufgabenZeilenProvider`) — dieselbe eine Abfrage, die Glocke, Liste und
/// Tourenplan lesen. Kein eigener Request pro Betrieb: Die Tabelle ist
/// klein, und nach jeder Aktion wird ohnehin `aufgabenZeilenProvider`
/// invalidiert — so zieht auch die Betriebsseite ohne eigenes Zutun nach.
library;

import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';

/// So lange bleibt eine erledigte Aufgabe auf der Betriebsseite stehen —
/// «was war da noch?» beim nächsten Besuch, ohne dass die Sektion über die
/// Jahre wächst.
const kErledigteAufgabenTage = 30;

/// Die eigenen Aufgaben des Betriebs [betriebId]: offene zuerst (nach
/// Fälligkeit, ohne Datum zuletzt, dann Titel), danach die in den letzten
/// [kErledigteAufgabenTage] Tagen erledigten (zuletzt erledigte zuerst).
/// Marker-/Snooze-Zeilen und Zeilen ohne Id fallen weg.
List<EigeneAufgabe> aufgabenFuerBetrieb(
  List<Map<String, dynamic>> zeilen,
  String betriebId,
  DateTime jetzt,
) {
  final grenze = jetzt.subtract(const Duration(days: kErledigteAufgabenTage));
  final offen = <EigeneAufgabe>[];
  final erledigt = <EigeneAufgabe>[];
  for (final z in zeilen) {
    if (z['typ'] != 'eigene' || z['betrieb_id'] != betriebId) continue;
    if (z['id'] is! String) continue;
    final a = EigeneAufgabe.fromJson(z);
    if (a.id.isEmpty) continue;
    if (!a.erledigt) {
      offen.add(a);
    } else if (!a.erledigtAm!.isBefore(grenze)) {
      erledigt.add(a);
    }
  }
  offen.sort((a, b) {
    final fa = a.faelligAm, fb = b.faelligAm;
    if (fa != null && fb != null) {
      final c = fa.compareTo(fb);
      if (c != 0) return c;
    } else if (fa != null) {
      return -1;
    } else if (fb != null) {
      return 1;
    }
    return a.titel.toLowerCase().compareTo(b.titel.toLowerCase());
  });
  erledigt.sort((a, b) => b.erledigtAm!.compareTo(a.erledigtAm!));
  return [...offen, ...erledigt];
}
