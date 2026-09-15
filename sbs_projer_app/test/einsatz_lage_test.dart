import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';

void main() {
  const keines = EinsatzKennzeichen.keines;

  group('reinigungLage', () {
    test('abgeschlossen ohne Buchung und ohne Heineken-Flag = erledigt', () {
      final l = reinigungLage(
        status: 'abgeschlossen',
        abgerechnet: false,
        hatBuchung: false,
      );
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, keines);
    });

    test(
      'Tresenrechnung mit Ertragsbuchung = verrechnet, obwohl abgerechnet false',
      () {
        final l = reinigungLage(
          status: 'abgeschlossen',
          abgerechnet: false,
          hatBuchung: true,
        );
        expect(l.status, EinsatzStatus.verrechnet);
      },
    );

    test('Heineken-Reinigung: abgerechnet reicht, keine Buchung noetig', () {
      final l = reinigungLage(
        status: 'abgeschlossen',
        abgerechnet: true,
        hatBuchung: false,
      );
      expect(l.status, EinsatzStatus.verrechnet);
    });

    test('offen (angelegt, nicht abgeschlossen) = in Arbeit', () {
      expect(
        reinigungLage(
          status: 'offen',
          abgerechnet: false,
          hatBuchung: false,
        ).status,
        EinsatzStatus.inArbeit,
      );
    });

    test(
      'storniert = erledigt mit Kennzeichen abgebrochen, nie verrechnet',
      () {
        final l = reinigungLage(
          status: 'storniert',
          abgerechnet: true,
          hatBuchung: true,
        );
        expect(l.status, EinsatzStatus.erledigt);
        expect(l.kennzeichen, EinsatzKennzeichen.abgebrochen);
      },
    );

    test('unbekannter Wert wirft nicht, sondern ergibt offen', () {
      expect(
        reinigungLage(
          status: 'irgendwas',
          abgerechnet: false,
          hatBuchung: false,
        ).status,
        EinsatzStatus.offen,
      );
    });
  });

  group('stoerungLage', () {
    test('offen ohne Termin = offen', () {
      expect(
        stoerungLage(status: 'offen', abgerechnet: false).status,
        EinsatzStatus.offen,
      );
    });

    test('offen mit geplant_am = geplant', () {
      expect(
        stoerungLage(
          status: 'offen',
          geplantAm: DateTime(2026, 9, 17),
          abgerechnet: false,
        ).status,
        EinsatzStatus.geplant,
      );
    });

    test('Arbeit begonnen ohne Ende = in Arbeit, auch bei Status offen', () {
      expect(
        stoerungLage(
          status: 'offen',
          arbeitVon: '09:10',
          abgerechnet: false,
        ).status,
        EinsatzStatus.inArbeit,
      );
    });

    test('in_bearbeitung = in Arbeit', () {
      expect(
        stoerungLage(status: 'in_bearbeitung', abgerechnet: false).status,
        EinsatzStatus.inArbeit,
      );
    });

    test('behoben = erledigt', () {
      expect(
        stoerungLage(status: 'behoben', abgerechnet: false).status,
        EinsatzStatus.erledigt,
      );
    });

    test('nicht_behebbar = erledigt mit Kennzeichen', () {
      final l = stoerungLage(status: 'nicht_behebbar', abgerechnet: false);
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.nichtBehebbar);
    });

    test('abgerechnet gewinnt ueber alles — hoechste Stufe', () {
      expect(
        stoerungLage(status: 'in_bearbeitung', abgerechnet: true).status,
        EinsatzStatus.verrechnet,
      );
    });
  });

  group('montageLage', () {
    test('geplant = geplant', () {
      expect(
        montageLage(status: 'geplant', abgerechnet: false).status,
        EinsatzStatus.geplant,
      );
    });
    test('geplant mit begonnener Arbeit = in Arbeit', () {
      expect(
        montageLage(
          status: 'geplant',
          arbeitVon: '08:00',
          abgerechnet: false,
        ).status,
        EinsatzStatus.inArbeit,
      );
    });
    test('begonnen und beendet zaehlt nicht mehr als in Arbeit', () {
      expect(
        montageLage(
          status: 'geplant',
          arbeitVon: '08:00',
          arbeitBis: '10:00',
          abgerechnet: false,
        ).status,
        EinsatzStatus.geplant,
      );
    });
    test('abgeschlossen = erledigt', () {
      expect(
        montageLage(status: 'abgeschlossen', abgerechnet: false).status,
        EinsatzStatus.erledigt,
      );
    });
    test('abgebrochen = erledigt mit Kennzeichen, nie verrechnet', () {
      final l = montageLage(status: 'abgebrochen', abgerechnet: true);
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.abgebrochen);
    });
  });

  group('eigenauftragLage', () {
    test('behoben = erledigt', () {
      expect(
        eigenauftragLage(status: 'behoben', abgerechnet: false).status,
        EinsatzStatus.erledigt,
      );
    });
    test('nachbearbeitung_noetig = in Arbeit', () {
      expect(
        eigenauftragLage(
          status: 'nachbearbeitung_noetig',
          abgerechnet: false,
        ).status,
        EinsatzStatus.inArbeit,
      );
    });
    test('nicht_behebbar = erledigt mit Kennzeichen', () {
      expect(
        eigenauftragLage(
          status: 'nicht_behebbar',
          abgerechnet: false,
        ).kennzeichen,
        EinsatzKennzeichen.nichtBehebbar,
      );
    });
    test('abgerechnet = verrechnet', () {
      expect(
        eigenauftragLage(status: 'behoben', abgerechnet: true).status,
        EinsatzStatus.verrechnet,
      );
    });
  });

  group('saisonreinigungLage (Beleg)', () {
    test('ein Beleg ist immer erledigt', () {
      expect(
        saisonreinigungLage(abgerechnet: false).status,
        EinsatzStatus.erledigt,
      );
    });
    test('abgerechnet = verrechnet', () {
      expect(
        saisonreinigungLage(abgerechnet: true).status,
        EinsatzStatus.verrechnet,
      );
    });
  });

  group('terminLage', () {
    test('vorgeschlagen = offen', () {
      expect(terminLage(status: 'vorgeschlagen').status, EinsatzStatus.offen);
    });
    test('geplant = geplant', () {
      expect(terminLage(status: 'geplant').status, EinsatzStatus.geplant);
    });
    test('erledigt = erledigt', () {
      expect(terminLage(status: 'erledigt').status, EinsatzStatus.erledigt);
    });
    test('abgesagt = erledigt mit Kennzeichen abgebrochen', () {
      final l = terminLage(status: 'abgesagt');
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.abgebrochen);
    });
  });

  group('pikettLage', () {
    test('aktiv = in Arbeit', () {
      expect(
        pikettLage(istAktiv: true, abgerechnet: false).status,
        EinsatzStatus.inArbeit,
      );
    });
    test('inaktiv = erledigt', () {
      expect(
        pikettLage(istAktiv: false, abgerechnet: false).status,
        EinsatzStatus.erledigt,
      );
    });
    test('abgerechnet = verrechnet', () {
      expect(
        pikettLage(istAktiv: false, abgerechnet: true).status,
        EinsatzStatus.verrechnet,
      );
    });
  });

  test('Reihenfolge der Stufen ist die Reihenfolge des Enums', () {
    expect(EinsatzStatus.values, [
      EinsatzStatus.offen,
      EinsatzStatus.geplant,
      EinsatzStatus.inArbeit,
      EinsatzStatus.erledigt,
      EinsatzStatus.verrechnet,
    ]);
  });
}
