/// Was eine Rechnung für den Geldfluss bedeutet und wie sie heisst — an EINER
/// Stelle.
///
/// WARUM (Analyse 25.09.2026, R2): «offen» war dreifach definiert. Der
/// Bankabgleich und der Zuordnen-Dialog nahmen nur `offen`/`gesendet` einer
/// `kundenrechnung`; eine gemahnte Rechnung oder eine Jahresrechnung hätte
/// keine Bankzahlung mehr bekommen und wäre als «unbekannte Gutschrift»
/// liegen geblieben — ausgerechnet nach dem ersten Mahnlauf.
///
/// Seit Migration 211 (27.09.2026) trägt `zahlungsstatus` nur noch die
/// Zahlung (`offen`/`bezahlt`/`abgeschrieben`). Zustellung, Mahnstufe und
/// Heineken-Freigabe sind eigene Felder; die Anzeige ([anzeigeSchluessel])
/// liest nur noch Felder.
library;

import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Erledigt — hier fliesst kein Geld mehr. Negativliste für [istOffen]:
/// Jeder unbekannte Wert zählt als offen, statt still aus Listen zu fallen.
const kErledigteStatus = Zahlungsstatus.erledigt;

/// Status, in dem eine Kunden- oder Jahresrechnung eine Zahlung erwartet.
/// Bewusst Positivliste: ein unbekannter Wert soll keine Bankzahlung
/// anziehen. Seit 211 nur noch `offen` — gemahnt oder gesendet ist eine
/// offene Rechnung trotzdem.
const kZahlbareStatus = {Zahlungsstatus.offen};

/// Rechnungstypen, die über den Kunden-Bankabgleich bezahlt werden. Die
/// Heineken-Monatsrechnung läuft über ihren eigenen Matcher (Freigabe →
/// Ertragsbuchung, erst dann Zahlung).
const kZahlbareTypen = {'kundenrechnung', 'jahresrechnung'};

/// Gilt eine Rechnung als offen (Übersichten, Mahn- und Telefonliste)?
bool istOffen(Rechnung r) => !kErledigteStatus.contains(r.zahlungsstatus);

/// Darf eine Kundenzahlung (Bankabgleich, Zuordnen-Dialog) auf diese Rechnung
/// verbucht werden?
bool istZahlbar(Rechnung r) =>
    kZahlbareTypen.contains(r.rechnungstyp) &&
    kZahlbareStatus.contains(r.zahlungsstatus);

/// Mahnstufe 0–3 aus `mahnung_stufe` (Konvention seit v0.144.0):
/// 0 = ungemahnt, 1 = erinnert, 2 = 1. Mahnung, 3 = letzte Mahnung.
/// Ausserhalb 0–3 (DB-CHECK verhindert es) geklemmt.
int mahnstufeVon(Rechnung r) =>
    r.mahnungStufe < 0 ? 0 : (r.mahnungStufe > 3 ? 3 : r.mahnungStufe);

/// Offen und mindestens einmal gemahnt.
bool istGemahnt(Rechnung r) => istOffen(r) && mahnstufeVon(r) > 0;

/// Anzeige-Schlüssel einer Rechnung — KEINE DB-Werte (ausser bezahlt und
/// abgeschrieben). Für Text ([anzeigeTextFuer]), Farbe
/// (`rechnungStatusFarbe`), Symbol und Listenfilter (`?status=`).
abstract final class RechnungAnzeige {
  /// Offen, weder `versendet_am` noch `uebergeben_am` — hiess bis 211
  /// «Offen», was neben «Gesendet» nach «unbezahlt» klang.
  static const nichtZugestellt = 'nicht_zugestellt';
  static const gesendet = 'gesendet';
  static const uebergeben = 'uebergeben';

  /// Heineken-Monatsrechnung mit `freigegeben_am` (Ertrag gebucht).
  static const freigegeben = 'freigegeben';
  static const erinnert = 'erinnert';
  static const mahnung1 = 'mahnung_1';
  static const mahnung2 = 'mahnung_2';
  static const bezahlt = Zahlungsstatus.bezahlt;
  static const abgeschrieben = Zahlungsstatus.abgeschrieben;

  static const alle = {
    nichtZugestellt,
    gesendet,
    uebergeben,
    freigegeben,
    erinnert,
    mahnung1,
    mahnung2,
    bezahlt,
    abgeschrieben,
  };
}

const _anzeigeTexte = {
  RechnungAnzeige.nichtZugestellt: 'Nicht zugestellt',
  RechnungAnzeige.gesendet: 'Gesendet',
  RechnungAnzeige.uebergeben: 'Übergeben',
  RechnungAnzeige.freigegeben: 'Freigegeben',
  RechnungAnzeige.erinnert: 'Erinnert',
  RechnungAnzeige.mahnung1: '1. Mahnung',
  RechnungAnzeige.mahnung2: 'Letzte Mahnung',
  RechnungAnzeige.bezahlt: 'Bezahlt',
  RechnungAnzeige.abgeschrieben: 'Abgeschrieben',
};

const _stufenSchluessel = {
  1: RechnungAnzeige.erinnert,
  2: RechnungAnzeige.mahnung1,
  3: RechnungAnzeige.mahnung2,
};

/// Schlüssel des angezeigten Status ([RechnungAnzeige]), bei einem
/// unbekannten Status dieser selbst. Für Text, Farbe, Symbol und Filter —
/// damit alles aus derselben Ableitung kommt.
///
/// WARUM (Analyse 25.09.2026, Abschnitt 2; Migration 211): Der Status mischte
/// Zahlung, Zustellung und Mahnstufe; sieben Stellen übersetzten den rohen
/// Wert je selbst. Seit 211 liest die Ableitung nur noch Felder:
/// 1. erledigt (`bezahlt`/`abgeschrieben`) geht allem vor;
/// 2. ein unbekannter Wert kommt roh durch — sichtbar statt als «offen»;
/// 3. die Mahnstufe aus `mahnung_stufe`;
/// 4. `freigegeben_am` (Heineken-Monatsrechnung);
/// 5. zugestellt: `versendet_am` («Gesendet»), sonst `uebergeben_am`;
/// 6. sonst «Nicht zugestellt».
String anzeigeSchluessel(Rechnung r) {
  final s = r.zahlungsstatus;
  if (kErledigteStatus.contains(s)) return s;
  if (!Zahlungsstatus.alle.contains(s)) return s;
  final stufe = _stufenSchluessel[mahnstufeVon(r)];
  if (stufe != null) return stufe;
  if (r.freigegebenAm != null) return RechnungAnzeige.freigegeben;
  if (r.versendetAm != null) return RechnungAnzeige.gesendet;
  if (r.uebergebenAm != null) return RechnungAnzeige.uebergeben;
  return RechnungAnzeige.nichtZugestellt;
}

/// Der Status einer Rechnung als deutscher Text — die EINE Übersetzung für
/// alle Listen und Details (siehe [anzeigeSchluessel]).
String anzeigeStatus(Rechnung r) => anzeigeTextFuer(anzeigeSchluessel(r));

/// Der deutsche Text zu einem Anzeige-Schlüssel ([anzeigeSchluessel]) — auch
/// für Filter, die dieselben Wörter zeigen müssen wie die Liste
/// («1. Mahnung», nicht «Mahnung 1»). Unbekanntes kommt roh durch.
String anzeigeTextFuer(String schluessel) =>
    _anzeigeTexte[schluessel] ?? schluessel;

/// Die Anzeige-Schlüssel, nach denen die Rechnungsliste filtern kann — in
/// der Reihenfolge des Ablaufs. Gefiltert wird auf [anzeigeSchluessel], nicht
/// auf den rohen Status: Sonst stünde unter einem Filter eine Zeile mit
/// anderem Chip (Review 27.09.2026, K1). `freigegeben` fehlt bewusst — das
/// ist die Heineken-Monatsrechnung mit eigener Liste.
const kAnzeigeFilterSchluessel = [
  RechnungAnzeige.nichtZugestellt,
  RechnungAnzeige.gesendet,
  RechnungAnzeige.uebergeben,
  RechnungAnzeige.erinnert,
  RechnungAnzeige.mahnung1,
  RechnungAnzeige.mahnung2,
  RechnungAnzeige.bezahlt,
  RechnungAnzeige.abgeschrieben,
];

/// Nächster Mahnschritt für das Kurzsymbol der Rechnungsliste — als
/// Anzeige-Schlüssel ([RechnungAnzeige.erinnert] … [RechnungAnzeige.mahnung2]
/// führen in den Mahnlauf, [RechnungAnzeige.abgeschrieben] ins Abschreiben),
/// `null` = kein Symbol.
///
/// WARUM (Entscheid 3a, 27.09.2026): Bis 211 hing das Symbol am rohen Status.
/// `gesendet` hatte keinen Folgeschritt — ausgerechnet die zugestellten
/// Mail-Rechnungen boten kein Mahnen an, die nie zugestellten dagegen
/// schon. Jetzt: jede offene, ZUGESTELLTE Kunden-/Jahresrechnung. Heineken
/// hat kein Mahnwesen; eine nicht zugestellte Rechnung mahnt man nicht.
String? naechsteMahnAktion(Rechnung r) {
  if (!kZahlbareTypen.contains(r.rechnungstyp)) return null;
  return switch (anzeigeSchluessel(r)) {
    RechnungAnzeige.gesendet ||
    RechnungAnzeige.uebergeben => RechnungAnzeige.erinnert,
    RechnungAnzeige.erinnert => RechnungAnzeige.mahnung1,
    RechnungAnzeige.mahnung1 => RechnungAnzeige.mahnung2,
    RechnungAnzeige.mahnung2 => RechnungAnzeige.abgeschrieben,
    _ => null,
  };
}

/// Stufe der Heineken-Monatsrechnung für die Monatsprüfung:
/// `offen → gesendet → freigegeben → bezahlt` — seit 211 aus den Feldern.
/// Die Stufen sind geordnet: Eine bezahlte Rechnung war zwingend
/// freigegeben, eine freigegebene zwingend gesendet.
String heinekenStufe({
  required String zahlungsstatus,
  DateTime? versendetAm,
  DateTime? freigegebenAm,
}) {
  if (kErledigteStatus.contains(zahlungsstatus)) return zahlungsstatus;
  if (freigegebenAm != null) return RechnungAnzeige.freigegeben;
  if (versendetAm != null) return RechnungAnzeige.gesendet;
  return Zahlungsstatus.offen;
}

/// `versendet_am` nach einem (Neu-)Versand: Das Datum des ERSTEN Versands
/// bleibt, nur ein erster Versand setzt [jetzt].
///
/// WARUM (Analyse 25.09.2026, Abschnitt 2): Jeder Neuversand überschrieb
/// `versendet_am` — das Erstversanddatum ging verloren. Es ist aber die
/// Zustellung, an der Mahnfristen und die Frage «wann gestellt?» hängen
/// (`mahnregeln.dart`, Jahrgangs-Abschreibung, Kontoauszug). Ein Neuversand,
/// der dem Kunden bewusst mehr Zeit gibt, setzt dafür `faelligkeitsdatum`
/// neu (Rechnungsdetail «neu versenden»: heute + 30).
DateTime versendetAmNachVersand(DateTime? bisher, DateTime jetzt) =>
    bisher ?? jetzt;
