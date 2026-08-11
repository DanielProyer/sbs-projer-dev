import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';

void main() {
  String montage({
    required bool geplant,
    String? von,
    String? bis,
  }) =>
      einsatzStatusNachSpeichern(
        geplant: geplant,
        arbeitVon: von,
        arbeitBis: bis,
        offenWert: 'geplant',
        erledigtWert: 'abgeschlossen',
      );

  String stoerung({
    required bool geplant,
    String? von,
    String? bis,
  }) =>
      einsatzStatusNachSpeichern(
        geplant: geplant,
        arbeitVon: von,
        arbeitBis: bis,
        offenWert: 'offen',
        erledigtWert: 'behoben',
      );

  group('Montage', () {
    test('Schalter «Erst geplant» aus → erledigt', () {
      expect(montage(geplant: false), 'abgeschlossen');
      expect(montage(geplant: false, von: '11:30', bis: '12:00'),
          'abgeschlossen');
    });

    test('geplant, noch nicht begonnen → geplant', () {
      expect(montage(geplant: true), 'geplant');
    });

    test('geplant, Arbeit läuft (nur Beginn) → in Bearbeitung', () {
      expect(montage(geplant: true, von: '11:30'), 'in_bearbeitung');
    });

    test(
        'FALL SARTONS: Beginn UND Ende erfasst → erledigt, auch wenn der '
        'Schalter «Erst geplant» noch an ist', () {
      expect(montage(geplant: true, von: '11:30', bis: '12:00'),
          'abgeschlossen');
    });

    test('Ende ohne Beginn (Beginn-Knopf vergessen) → erledigt', () {
      expect(montage(geplant: true, bis: '12:00'), 'abgeschlossen');
    });

    test('leere Zeitangaben zählen nicht als erfasst', () {
      expect(montage(geplant: true, von: '  ', bis: ''), 'geplant');
    });
  });

  group('Störung — gleiche Regel, andere Statuswerte', () {
    test('offen, nicht begonnen', () {
      expect(stoerung(geplant: true), 'offen');
    });

    test('Arbeit läuft', () {
      expect(stoerung(geplant: true, von: '09:00'), 'in_bearbeitung');
    });

    test('Beginn und Ende erfasst → behoben', () {
      expect(stoerung(geplant: true, von: '09:00', bis: '10:15'), 'behoben');
    });
  });
}
