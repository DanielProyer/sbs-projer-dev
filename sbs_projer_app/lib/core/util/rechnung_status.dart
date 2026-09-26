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
