import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/mahnschreiben.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/widgets/mahnverlauf.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

/// Reine Teile des Mahnverlaufs im Rechnungsdetail.
void main() {
  Mahnschreiben schreiben(int stufe) => Mahnschreiben(
        id: 'm$stufe',
        userId: 'u',
        betriebId: 'b',
        stufe: stufe,
        rechnungIds: const ['r1'],
        kanal: 'mail',
        test: true,
        fristBis: DateTime.utc(2026, 10, 3),
        vorher: const {},
        erstelltAm: DateTime.utc(2026, 9, 23),
      );

  group('sichtbareAltEintraege (M-4)', () {
    final alt = [
      (stufe: 0, datum: DateTime.utc(2026, 7, 1)),
      (stufe: 1, datum: DateTime.utc(2026, 8, 1)),
    ];

    test('ohne Protokoll: alle alten Einträge', () {
      expect(sichtbareAltEintraege(alt, const []), hasLength(2));
    });

    test('nur die Stufe, die schon im Protokoll steht, wird ausgeblendet', () {
      final s = sichtbareAltEintraege(alt, [schreiben(1)]);
      expect(s.map((a) => a.stufe), [0],
          reason: 'die alte Erinnerung bleibt sichtbar, obwohl die 1. Mahnung protokolliert ist');
    });
  });

  group('zuruecknehmenMeldung (M-7)', () {
    test('nennt die Rechnungsnummer je übersprungener Rechnung', () {
      final t = zuruecknehmenMeldung(MahnlaufZuruecknehmenErgebnis(
        zurueckgesetzt: const ['r1'],
        uebersprungen: const [
          (rechnungId: 'r2', rechnungsnummer: 'RE-2026-0042', grund: 'inzwischen bezahlt'),
        ],
      ));
      expect(t, contains('1 Rechnung(en) zurückgesetzt'));
      expect(t, contains('RE-2026-0042: inzwischen bezahlt'));
    });

    test('nichts zurückgesetzt: Schreiben gilt weiter; ohne Nummer die Id', () {
      final t = zuruecknehmenMeldung(MahnlaufZuruecknehmenErgebnis(
        zurueckgesetzt: const [],
        uebersprungen: const [
          (rechnungId: 'r9', rechnungsnummer: null, grund: 'Rechnung nicht gefunden'),
        ],
      ));
      expect(t, startsWith('Nichts zurückgesetzt'));
      expect(t, contains('r9: Rechnung nicht gefunden'));
      expect(t, contains('gilt weiter'));
    });

    test('alles zurückgesetzt', () {
      final t = zuruecknehmenMeldung(MahnlaufZuruecknehmenErgebnis(
        zurueckgesetzt: const ['r1', 'r2'],
        uebersprungen: const [],
      ));
      expect(t, '2 Rechnung(en) zurückgesetzt.');
    });
  });
}
