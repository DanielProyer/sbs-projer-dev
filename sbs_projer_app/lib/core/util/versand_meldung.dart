import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

/// Was der Server über den Versand sagt, nachdem der Aufruf der Mail-Function
/// abgebrochen ist.
enum VersandStand {
  /// Der Versandvermerk steht — die Mail ist beim Empfänger.
  versendet,

  /// Kein Vermerk — die Mail ist nicht rausgegangen.
  nichtVersendet,

  /// Die Nachfrage kam selbst nicht durch. Nichts ist bewiesen.
  unklar,
}

/// Meldung nach einem abgebrochenen Mailversand: Text und ob sie ein Fehler
/// ist (rot) oder eine Warnung (gelb).
typedef VersandMeldung = ({String text, bool istFehler});

/// Übersetzt die Antwort der Nachfrage in einen Stand.
/// `null` heisst: die Nachfrage selbst scheiterte.
VersandStand versandStandAus(bool? vermerkt) => switch (vermerkt) {
  true => VersandStand.versendet,
  false => VersandStand.nichtVersendet,
  null => VersandStand.unklar,
};

/// Die Meldung, die nach einem abgebrochenen Mailversand auf dem Handy steht.
///
/// WARUM diese Umwege statt «MAIL-VERSAND FEHLGESCHLAGEN: $e»:
///
/// Die Edge Function setzt den Versandvermerk seit v15 selbst, direkt nach dem
/// Gmail-Aufruf, und hängt ihn seit v16 an `EdgeRuntime.waitUntil`. Der Vermerk
/// überlebt damit einen Verbindungsabbruch — die Antwort ans Handy nicht.
/// «Failed to fetch» ist der Weg zurück, nicht der Weg hin.
///
/// Am 17.09.2026, 11:32 (Löwen Maienfeld, Rechnung 2026-09-1452) meldete die
/// App deshalb einen fehlgeschlagenen Versand, während die Mail längst beim
/// Kunden lag. Die Meldung forderte zum Nachholen auf — der Kunde hätte
/// dieselbe Rechnung zweimal bekommen. Genau diesen Schaden verhindert der
/// serverseitige Vermerk; eine falsche Meldung macht ihn wieder auf.
///
/// Also: nicht behaupten, sondern nachfragen und sagen, was der Server weiss.
VersandMeldung versandMeldung(VersandStand stand, Object fehler) {
  final grund = kurzeFehlermeldung(fehler);
  return switch (stand) {
    VersandStand.versendet => (
      text:
          'Antwort nicht angekommen ($grund) — die Rechnung ist laut Server '
          'versendet. Nicht erneut senden.',
      istFehler: false,
    ),
    VersandStand.nichtVersendet => (
      text: 'Mail NICHT versendet ($grund) — im Rechnungs-Detail nachholen.',
      istFehler: true,
    ),
    VersandStand.unklar => (
      text:
          'Versand unklar ($grund) — erst im Rechnungs-Detail prüfen, dann '
          'erst erneut senden.',
      istFehler: false,
    ),
  };
}

/// Meldung, wenn die ganze Kette (Rechnung erstellen, PDF, Mail) abbricht.
///
/// Hier ist keine Rechnungs-Id zur Hand, mit der sich nachfragen liesse, und
/// unklar bleibt sogar, ob die Rechnung überhaupt entstanden ist. Deshalb
/// «prüfen», nicht «nachholen»: Eine Aufforderung zum Nachholen kann hier
/// eine zweite Rechnung erzeugen.
String kettenFehlerMeldung(Object fehler) =>
    'Rechnung/Mail abgebrochen (${kurzeFehlermeldung(fehler)}) — '
    'im Rechnungs-Detail prüfen, bevor du erneut sendest.';

/// Meldung, wenn die Ertragsbuchung nach dem Abschluss nicht durchkam.
///
/// WARUM der Weg genau benannt wird: v0.109.1 schickte Daniel «ins
/// Reinigungs-Detail nachbuchen» — dort gibt es das nicht. Am 17.09.2026,
/// 15:51 (Cafe Bar, Rechnung 2026-09-1456) stand die Rechnung, die Buchung
/// fehlte, und die Meldung zeigte ins Leere.
///
/// Der Knopf sitzt als Warnkarte oben in der Rechnungsliste («… CHF · tippen
/// zum Nachbuchen»). Der automatische Nachlauf ist KEIN Ersatz: Er hängt an
/// `if (buchungVerbucht)` und läuft erst beim nächsten Abschluss, dessen
/// eigene Buchung durchgeht — im Funkloch also gar nicht.
String buchungFehlerMeldung(Object fehler) =>
    'BUCHUNG FEHLGESCHLAGEN (${kurzeFehlermeldung(fehler)}) — '
    'in der Rechnungsliste oben «tippen zum Nachbuchen».';
