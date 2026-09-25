import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/offene_pro_betrieb.dart' as opb;
import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Welche Rechnung darf eine Bankzahlung bekommen, und was macht ein
/// (Neu-)Versand mit ihrem Status?
///
/// WARUM (Analyse 25.09.2026, R2/R4): Der Bankabgleich nahm nur `offen` und
/// `gesendet` einer `kundenrechnung`. Gemahnte Rechnungen und
/// Jahresrechnungen wären nie per Bank bezahlbar gewesen — die Zahlung wäre
/// als «unbekannte Gutschrift» liegen geblieben. Umgekehrt setzte jeder
/// Versand pauschal `gesendet` und hätte eine bezahlte oder gemahnte Rechnung
/// zurückgedreht.
void main() {
  Rechnung rg({String status = 'offen', String typ = 'kundenrechnung'}) =>
      Rechnung(
        id: 'r1',
        userId: 'u1',
        rechnungsnummer: 'R-1',
        rechnungstyp: typ,
        rechnungsdatum: DateTime(2026, 9, 1),
        faelligkeitsdatum: DateTime(2026, 10, 1),
        betragBrutto: 100,
        zahlungsstatus: status,
      );

  /// Alle Werte des DB-CHECK (Migration 083).
  const checkWerte = {
    'offen',
    'gesendet',
    'freigegeben',
    'bezahlt',
    'erinnert',
    'mahnung_1',
    'mahnung_2',
    'abgeschrieben',
  };

  group('istZahlbar', () {
    for (final s in ['offen', 'gesendet', 'erinnert', 'mahnung_1', 'mahnung_2']) {
      test('Kundenrechnung «$s» ist zahlbar', () {
        expect(istZahlbar(rg(status: s)), isTrue);
      });
      test('Jahresrechnung «$s» ist zahlbar', () {
        expect(istZahlbar(rg(status: s, typ: 'jahresrechnung')), isTrue);
      });
    }

    for (final s in ['bezahlt', 'abgeschrieben', 'freigegeben']) {
      test('Kundenrechnung «$s» ist nicht zahlbar', () {
        expect(istZahlbar(rg(status: s)), isFalse);
      });
    }

    test('Heineken-Monatsrechnung nie — sie hat ihren eigenen Weg', () {
      for (final s in checkWerte) {
        expect(istZahlbar(rg(status: s, typ: 'heineken_monat')), isFalse,
            reason: s);
      }
    });

    test('unbekannter Status ist nicht zahlbar (Positivliste)', () {
      expect(istZahlbar(rg(status: 'storniert')), isFalse);
    });

    test('Status-Listen decken den DB-CHECK vollständig ab', () {
      expect(kZahlbareStatus.intersection(kErledigteStatus), isEmpty);
      expect(
        {...kZahlbareStatus, ...kErledigteStatus, 'freigegeben'},
        checkWerte,
      );
    });
  });

  group('istOffen nutzt dieselbe Quelle', () {
    test('offene_pro_betrieb liefert dieselbe Funktion', () {
      expect(identical(opb.istOffen, istOffen), isTrue);
      expect(identical(opb.kErledigteStatus, kErledigteStatus), isTrue);
      expect(opb.istOffen(rg(status: 'mahnung_2')), isTrue);
      expect(opb.istOffen(rg(status: 'abgeschrieben')), isFalse);
    });

    test('jede zahlbare Rechnung ist offen', () {
      for (final s in kZahlbareStatus) {
        expect(istOffen(rg(status: s)), isTrue, reason: s);
      }
    });
  });

  group('statusNachVersand', () {
    test('offen wird gesendet', () {
      expect(statusNachVersand('offen'), 'gesendet');
    });

    test('alles andere bleibt, wie es ist', () {
      for (final s in checkWerte.difference({'offen'})) {
        expect(statusNachVersand(s), s, reason: s);
      }
    });

    test('ganz mit Guthaben gedeckt: bleibt auch bei offen', () {
      expect(statusNachVersand('offen', vollMitGuthabenGedeckt: true), 'offen');
    });
  });
}
