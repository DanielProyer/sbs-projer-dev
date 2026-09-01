import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnung_nachhol_plan.dart';

void main() {
  test('ohne Rechnung wird die Rechnung erstellt — das PDF entsteht dabei', () {
    final p = RechnungNachholPlan.fuer(
      rechnungVorhanden: false,
      pdfVorhanden: false,
    );
    expect(p.rechnungErstellen, isTrue);
    expect(p.pdfNachziehen, isFalse);
  });

  test('vorhandene Rechnung ohne PDF: das PDF wird nachgezogen', () {
    // Der Fehler vom 01.09.2026: Die Rechnung war da (Upload abgebrochen),
    // der Nachholweg übersprang die Erstellung — und damit auch das PDF.
    // Gemeldet wurde trotzdem Erfolg.
    final p = RechnungNachholPlan.fuer(
      rechnungVorhanden: true,
      pdfVorhanden: false,
    );
    expect(p.rechnungErstellen, isFalse);
    expect(p.pdfNachziehen, isTrue);
  });

  test('vorhandene Rechnung mit PDF: nichts zu tun', () {
    final p = RechnungNachholPlan.fuer(
      rechnungVorhanden: true,
      pdfVorhanden: true,
    );
    expect(p.rechnungErstellen, isFalse);
    expect(p.pdfNachziehen, isFalse);
    expect(p.nichtsZuTun, isTrue);
  });

  test('fehlendes PDF wird im Ergebnistext benannt, nicht verschwiegen', () {
    expect(
      RechnungNachholPlan.pdfFehltMeldung('Rechnung erstellt.'),
      'Rechnung erstellt. ACHTUNG: Das Rechnungs-PDF konnte nicht abgelegt '
          'werden — im Rechnungs-Detail erneut versuchen.',
    );
  });
}
