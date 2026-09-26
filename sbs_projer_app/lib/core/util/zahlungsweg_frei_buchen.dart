/// Zahlungswege im Modus «Frei buchen» des Buchungsformulars.
///
/// Vorlagen kennen zusätzlich `kreditor` und `debitor`. Wer von so einer
/// Vorlage auf «Frei buchen» wechselte, behielt den Wert: Das freie Dropdown
/// hat ihn nicht in seinen Einträgen (Debug: Assertion, sonst leeres Feld),
/// und gespeichert wurde trotzdem `kreditor` (Code-Review 26.09.2026).
library;

/// Die einzigen Zahlungswege, die «Frei buchen» anbietet und speichert.
const kZahlungswegeFreiBuchen = ['kasse', 'bank', 'privat'];

/// Zahlungsweg beim Umschalten auf bzw. Speichern in «Frei buchen»: ein
/// erlaubter Wert bleibt, alles andere wird `null` — der Nutzer muss dann
/// selbst wählen (Validator «Zahlungsweg wählen»).
String? zahlungswegFuerFreiBuchen(String? bisher) =>
    kZahlungswegeFreiBuchen.contains(bisher) ? bisher : null;
