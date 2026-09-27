/// Was ein `zahlungsstatus` für den Geldfluss bedeutet — an EINER Stelle.
///
/// WARUM (Analyse 25.09.2026, R2): «offen» war dreifach definiert. Der
/// Bankabgleich und der Zuordnen-Dialog nahmen nur `offen`/`gesendet` einer
/// `kundenrechnung`; eine gemahnte Rechnung oder eine Jahresrechnung hätte
/// keine Bankzahlung mehr bekommen und wäre als «unbekannte Gutschrift»
/// liegen geblieben — ausgerechnet nach dem ersten Mahnlauf.
library;

import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Erledigt — hier fliesst kein Geld mehr. Negativliste für [istOffen]:
/// Jeder neue Zwischenstatus zählt automatisch als offen, statt still aus
/// Listen zu fallen.
const kErledigteStatus = Zahlungsstatus.erledigt;

/// Status, in denen eine Kunden- oder Jahresrechnung eine Zahlung erwartet.
/// Bewusst Positivliste: `freigegeben` gehört zur Heineken-Monatsrechnung, und
/// ein unbekannter Wert soll keine Bankzahlung anziehen.
const kZahlbareStatus = {
  Zahlungsstatus.offen,
  Zahlungsstatus.gesendet,
  Zahlungsstatus.erinnert,
  Zahlungsstatus.mahnung1,
  Zahlungsstatus.mahnung2,
};

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

/// Anzeige-Schlüssel «übergeben» — kein DB-Wert: Die Tresen-Übergabe setzt
/// nur `uebergeben_am`, keinen Status.
const kAnzeigeUebergeben = 'uebergeben';

const _anzeigeTexte = {
  Zahlungsstatus.offen: 'Offen',
  Zahlungsstatus.gesendet: 'Gesendet',
  kAnzeigeUebergeben: 'Übergeben',
  Zahlungsstatus.freigegeben: 'Freigegeben',
  Zahlungsstatus.erinnert: 'Erinnert',
  Zahlungsstatus.mahnung1: '1. Mahnung',
  Zahlungsstatus.mahnung2: 'Letzte Mahnung',
  Zahlungsstatus.bezahlt: 'Bezahlt',
  Zahlungsstatus.abgeschrieben: 'Abgeschrieben',
};

/// Mahnstufe, die der Status selbst ausdrückt (1–3 wie `mahnung_stufe`).
const _stufeAusStatus = {
  Zahlungsstatus.erinnert: 1,
  Zahlungsstatus.mahnung1: 2,
  Zahlungsstatus.mahnung2: 3,
};

/// Schlüssel des angezeigten Status: ein Wert aus [Zahlungsstatus] oder
/// [kAnzeigeUebergeben], bei einem unbekannten Status dieser selbst. Für
/// Farbe und Symbol — damit Text und Farbe aus derselben Ableitung kommen.
///
/// WARUM (Analyse 25.09.2026, Abschnitt 2): `zahlungsstatus` mischt Zahlung,
/// Zustellung und Mahnstufe. Sieben Stellen übersetzten den rohen Wert je
/// selbst und zeigten deshalb Verschiedenes: `gesendet` und `freigegeben`
/// erschienen in Liste und Detail roh, dieselbe Mahnung hiess einmal
/// «Mahnung 2», einmal «Letzte Mahnung», und eine Rechnung, deren Status
/// nach einer Zahlungs-Rücknahme auf `gesendet` zurückfiel, erschien
/// ungemahnt, obwohl die Mahnung beim Kunden lag. Reihenfolge:
/// 1. erledigt (`bezahlt`/`abgeschrieben`) geht allem vor;
/// 2. ein unbekannter Wert kommt roh durch — sichtbar statt als «Offen»;
/// 3. die höhere Mahnstufe aus Status und `mahnung_stufe`;
/// 4. `freigegeben` (Heineken-Monatsrechnung);
/// 5. zugestellt: `versendet_am` bzw. Status `gesendet`, sonst `uebergeben_am`;
/// 6. sonst offen.
String anzeigeSchluessel(Rechnung r) {
  final s = r.zahlungsstatus;
  if (kErledigteStatus.contains(s)) return s;
  if (!Zahlungsstatus.alle.contains(s)) return s;
  final stufeStatus = _stufeAusStatus[s] ?? 0;
  final stufe = r.mahnungStufe > stufeStatus ? r.mahnungStufe : stufeStatus;
  if (stufe >= 3) return Zahlungsstatus.mahnung2;
  if (stufe == 2) return Zahlungsstatus.mahnung1;
  if (stufe == 1) return Zahlungsstatus.erinnert;
  if (s == Zahlungsstatus.freigegeben) return s;
  if (r.versendetAm != null || s == Zahlungsstatus.gesendet) {
    return Zahlungsstatus.gesendet;
  }
  if (r.uebergebenAm != null) return kAnzeigeUebergeben;
  return Zahlungsstatus.offen;
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
/// auf den rohen Status: Sonst stünde unter «Offen» eine Zeile mit dem Chip
/// «Gesendet», und eine per `mahnung_stufe` gemahnte Rechnung fehlte unter
/// ihrer Mahnstufe (Review 27.09.2026, K1). `freigegeben` fehlt bewusst — das
/// ist die Heineken-Monatsrechnung mit eigener Liste.
const kAnzeigeFilterSchluessel = [
  Zahlungsstatus.offen,
  Zahlungsstatus.gesendet,
  kAnzeigeUebergeben,
  Zahlungsstatus.erinnert,
  Zahlungsstatus.mahnung1,
  Zahlungsstatus.mahnung2,
  Zahlungsstatus.bezahlt,
  Zahlungsstatus.abgeschrieben,
];

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

/// Status nach einem (Neu-)Versand der Rechnung.
///
/// WARUM (Analyse 25.09.2026, R4): Der Versand setzte pauschal `gesendet`. Ein
/// Neuversand aus dem Reinigungsdetail hätte eine bezahlte oder gemahnte
/// Rechnung zurückgedreht. Nur `offen` rückt vor; alles andere bleibt —
/// genau wie der serverseitige Vermerk der Edge Function.
///
/// [vollMitGuthabenGedeckt]: Die Rechnung ist mit Kundenguthaben ganz
/// verrechnet und damit schon beglichen — dann bleibt der Status ebenfalls.
String statusNachVersand(
  String aktuell, {
  bool vollMitGuthabenGedeckt = false,
}) {
  if (vollMitGuthabenGedeckt) return aktuell;
  return aktuell == Zahlungsstatus.offen ? Zahlungsstatus.gesendet : aktuell;
}
