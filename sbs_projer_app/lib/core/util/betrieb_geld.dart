/// Der Geldstand eines Betriebs für die Betriebsseite (Akte, T10).
///
/// WARUM: Die Betriebsseite zeigte Einsätze, aber nicht, ob der Kunde noch
/// Geld schuldet — dafür musste man in die Rechnungsliste. «Offen» heisst
/// hier dasselbe wie im Bankabgleich ([istZahlbar]): Kunden- und
/// Jahresrechnungen, die noch eine Zahlung erwarten, gemahnte eingeschlossen.
library;

import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

class BetriebGeldStand {
  /// Summe dessen, was der Kunde noch zahlen muss ([Rechnung.zuZahlen]).
  final double offenCHF;
  final int anzahlOffen;
  final int anzahlUeberfaellig;

  /// Höchste Mahnstufe unter den offenen Rechnungen: 0 = ungemahnt,
  /// 1 = Erinnerung, 2 = 1. Mahnung, 3 = 2. Mahnung ([mahnstufeLabel]).
  ///
  /// Aus dem `zahlungsstatus` abgeleitet, nicht aus `mahnung_stufe` — auch
  /// wenn der Mahnlauf dort seit dem Fix (26.09.2026, `MahnStufeX.wert`)
  /// korrekt 1–3 schreibt: `zahlungsstatus` ist der Wert, mit dem der Rest
  /// der App (Mahnregeln, Korrektur-Sperre) ohnehin schon rechnet, eine
  /// zweite Quelle für dieselbe Information bräuchte es hier nicht.
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
    final stufe = switch (r.zahlungsstatus) {
      Zahlungsstatus.erinnert => 1,
      Zahlungsstatus.mahnung1 => 2,
      Zahlungsstatus.mahnung2 => 3,
      _ => 0,
    };
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
