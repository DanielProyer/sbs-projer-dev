import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/pdf/event_abschluss_pdf_service.dart';

void main() {
  test('build liefert nicht-leere PDF-Bytes (mit Daten)', () async {
    final daten = EventAbschlussDaten(
      eventName: 'Openair Val Lumnezia',
      zeitraum: '23.–26.07.2026',
      staende: [
        (name: 'Signina Bar', anlagenText: '7× OT · 1× Hollandbuffet', inbetriebLabel: '✓ komplett'),
      ],
      anlagenTotal: 8,
      anlagenInBetrieb: 8,
      aufwaende: [
        (datum: DateTime(2026, 7, 24), kategorie: 'pikett', notiz: '10:00–02:00', stunden: 16),
        (datum: DateTime(2026, 7, 23), kategorie: 'anfahrt', notiz: null, stunden: 2),
      ],
      einsaetze: [
        (zeitpunkt: DateTime(2026, 7, 24, 23, 15), beschreibung: 'CO2 gewechselt', material: '1x CO2 6kg', standName: 'Signina Bar'),
      ],
    );
    final bytes = await EventAbschlussPdfService.build(daten);
    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('build liefert Bytes auch bei leeren Listen', () async {
    final daten = EventAbschlussDaten(
      eventName: 'Test', zeitraum: '2026',
      staende: const [], anlagenTotal: 0, anlagenInBetrieb: 0,
      aufwaende: const [], einsaetze: const [],
    );
    final bytes = await EventAbschlussPdfService.build(daten);
    expect(bytes.isNotEmpty, isTrue);
  });
}
