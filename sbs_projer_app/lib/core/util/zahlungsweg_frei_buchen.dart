/// Zahlungswege im Modus «Frei buchen» des Buchungsformulars.
///
/// Vorlagen kennen zusätzlich `kreditor` und `debitor`. Wer von so einer
/// Vorlage auf «Frei buchen» wechselte, behielt den Wert: Das freie Dropdown
/// hat ihn nicht in seinen Einträgen (Debug: Assertion, sonst leeres Feld),
/// und gespeichert wurde trotzdem `kreditor` (Code-Review 26.09.2026).
///
/// Der Zahlungsweg ist in «Frei buchen» FREIWILLIG: Soll und Haben stehen
/// dort von Hand, die Spalte erlaubt `NULL` (Migration 089). Eine Umbuchung
/// ohne Geldfluss bekommt `intern` — so schreiben es auch die App-eigenen
/// Umbuchungen (Abschreibung, Zahlungsdifferenz, Zahlungskern). Die
/// Pflichtwahl vom 26.09.2026 machte beides unmöglich (Review 26.09.2026).
library;

/// Die einzigen Zahlungswege, die «Frei buchen» anbietet und speichert.
const kZahlungswegeFreiBuchen = ['kasse', 'bank', 'privat', 'intern'];

/// Zahlungsweg beim Umschalten auf bzw. Speichern in «Frei buchen»: ein
/// erlaubter Wert bleibt, alles andere wird `null` (kein Zahlungsweg).
String? zahlungswegFuerFreiBuchen(String? bisher) =>
    kZahlungswegeFreiBuchen.contains(bisher) ? bisher : null;

/// Darf [wert] in «Frei buchen» gespeichert werden? `null` ja (freiwillig),
/// sonst nur einer aus [kZahlungswegeFreiBuchen] — nie ein `kreditor`/
/// `debitor`, der von einer vorher gewählten Vorlage übrig blieb.
bool zahlungswegFreiErlaubt(String? wert) =>
    wert == null || kZahlungswegeFreiBuchen.contains(wert);
