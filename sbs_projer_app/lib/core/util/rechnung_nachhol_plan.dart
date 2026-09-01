/// Was beim erneuten Auslösen von «Rechnung erstellen/senden» zu tun ist.
///
/// Vorfall 01.09.2026: Bei der Reinigung Central brach der Upload des
/// Rechnungs-PDF ab (Verbindungsabbruch, 54 ms). Die Rechnung selbst war
/// angelegt — und genau deshalb übersprang der Nachholweg die Erstellung und
/// damit auch das PDF. Gemeldet wurde trotzdem «Rechnung erstellt». Ein
/// zweiter Versuch hätte den Zustand nie repariert.
///
/// Lehre: «Rechnung vorhanden» ist nicht dasselbe wie «Rechnung vollständig».
class RechnungNachholPlan {
  final bool rechnungErstellen;
  final bool pdfNachziehen;

  const RechnungNachholPlan._({
    required this.rechnungErstellen,
    required this.pdfNachziehen,
  });

  factory RechnungNachholPlan.fuer({
    required bool rechnungVorhanden,
    required bool pdfVorhanden,
  }) {
    if (!rechnungVorhanden) {
      // Beim Erstellen entsteht das PDF mit — kein separates Nachziehen.
      return const RechnungNachholPlan._(
        rechnungErstellen: true,
        pdfNachziehen: false,
      );
    }
    return RechnungNachholPlan._(
      rechnungErstellen: false,
      pdfNachziehen: !pdfVorhanden,
    );
  }

  bool get nichtsZuTun => !rechnungErstellen && !pdfNachziehen;

  /// Hängt den Hinweis auf ein fehlendes PDF an eine Erfolgsmeldung an.
  /// Bewusst am Ende der Meldung und mit «ACHTUNG»: Ein fehlendes PDF darf
  /// nicht hinter einer grünen Meldung verschwinden.
  static String pdfFehltMeldung(String basis) =>
      '$basis ACHTUNG: Das Rechnungs-PDF konnte nicht abgelegt werden — '
      'im Rechnungs-Detail erneut versuchen.';
}
