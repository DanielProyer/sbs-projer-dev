import 'dart:io';

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

  group('einsatzWirdJetztErledigt — Abschluss-Moment dieses Speicherns', () {
    bool moment({
      required bool isEdit,
      required bool warGeplant,
      required bool geplant,
    }) => einsatzWirdJetztErledigt(
      isEdit: isEdit,
      warGeplant: warGeplant,
      geplant: geplant,
    );

    test('neu und gleich erledigt → ja', () {
      expect(moment(isEdit: false, warGeplant: false, geplant: false), isTrue);
    });

    test('neu, aber erst geplant → nein', () {
      expect(moment(isEdit: false, warGeplant: false, geplant: true), isFalse);
    });

    test('geplant/laufend → jetzt erledigt → ja', () {
      expect(moment(isEdit: true, warGeplant: true, geplant: false), isTrue);
    });

    test('geplant bleibt geplant → nein', () {
      expect(moment(isEdit: true, warGeplant: true, geplant: true), isFalse);
    });

    test('längst erledigten Einsatz bearbeiten → nein (keine Nachfrage)', () {
      expect(moment(isEdit: true, warGeplant: false, geplant: false), isFalse);
    });
  });

  test('Wächter: beide Formulare fragen die Arbeitszeit nur im '
      'Abschluss-Moment', () {
    for (final pfad in [
      'lib/presentation/screens/stoerungen/stoerung_form_screen.dart',
      'lib/presentation/screens/montagen/montage_form_screen.dart',
    ]) {
      final text = File(pfad).readAsStringSync();
      expect(
        text,
        contains('wirdErledigt: istWegpunktMoment'),
        reason: '$pfad: die Nachfrage hängt am Abschluss-Moment',
      );
      expect(
        text,
        isNot(contains('wirdErledigt: !_geplant')),
        reason: '$pfad: «nicht geplant» gilt auch beim Bearbeiten eines '
            'längst erledigten Einsatzes',
      );
      expect(text, contains('einsatzWirdJetztErledigt('), reason: pfad);
    }
  });
}
