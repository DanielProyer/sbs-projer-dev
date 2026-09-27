/// Der Geldstand eines Betriebs für die Betriebsseite (Akte, T10).
///
/// WARUM: Die Betriebsseite zeigte Einsätze, aber nicht, ob der Kunde noch
/// Geld schuldet — dafür musste man in die Rechnungsliste. «Offen» heisst
/// hier dasselbe wie im Bankabgleich ([istZahlbar]): Kunden- und
/// Jahresrechnungen, die noch eine Zahlung erwarten, gemahnte eingeschlossen.
library;

import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

class BetriebGeldStand {
  /// Summe dessen, was der Kunde noch zahlen muss ([Rechnung.zuZahlen]).
  final double offenCHF;
  final int anzahlOffen;
  final int anzahlUeberfaellig;

  /// Höchste Mahnstufe unter den offenen Rechnungen: 0 = ungemahnt,
  /// 1 = Erinnerung, 2 = 1. Mahnung, 3 = 2. Mahnung ([mahnstufeLabel]).
  ///
  /// Aus `mahnung_stufe` ([mahnstufeVon]) — seit Migration 211 die EINE
  /// Quelle der Mahnung; der Status bleibt beim Mahnen `offen`.
  final int hoechsteMahnstufe;

  /// Verfügbares Kundenguthaben (Konto 2030), nie negativ.
  final double guthabenCHF;

  const BetriebGeldStand({
    required this.offenCHF,
    required this.anzahlOffen,
    required this.anzahlUeberfaellig,
    required this.hoechsteMahnstufe,
    required this.guthabenCHF,
  });
}

BetriebGeldStand betriebGeldStand(
  List<Rechnung> rechnungen,
  double guthaben, {
  DateTime? heute,
}) {
  final jetzt = heute ?? DateTime.now();
  final stichtag = DateTime(jetzt.year, jetzt.month, jetzt.day);
  var offen = 0.0;
  var anzahl = 0;
  var ueberfaellig = 0;
  var mahnstufe = 0;
  for (final r in rechnungen) {
    if (!istZahlbar(r)) continue;
    offen += r.zuZahlen;
    anzahl++;
    final f = r.faelligkeitsdatum;
    if (DateTime(f.year, f.month, f.day).isBefore(stichtag)) ueberfaellig++;
    final stufe = mahnstufeVon(r);
    if (stufe > mahnstufe) mahnstufe = stufe;
  }
  return BetriebGeldStand(
    offenCHF: offen,
    anzahlOffen: anzahl,
    anzahlUeberfaellig: ueberfaellig,
    hoechsteMahnstufe: mahnstufe,
    guthabenCHF: guthaben > 0 ? guthaben : 0,
  );
}

String mahnstufeLabel(int stufe) => switch (stufe) {
  1 => 'Erinnerung',
  2 => '1. Mahnung',
  3 => '2. Mahnung',
  _ => 'keine',
};

/// Ziel des Geld-Blocks: Rechnungsliste, gesucht nach dem Betriebsnamen und
/// auf den Statusfilter «Unbezahlt» gestellt (Review Runde 5) — ausdrücklich,
/// denn mit Suchbegriff öffnet die Liste sonst auf «alle».
String betriebOffeneRechnungenRoute(String betriebName) =>
    '/rechnungen?suche=${Uri.encodeQueryComponent(betriebName)}&status=unbezahlt';
