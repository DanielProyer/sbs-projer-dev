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

  group('anzeigeStatus — eine Wahrheit für den Status-Text', () {
    Rechnung mit({
      String status = 'offen',
      String typ = 'kundenrechnung',
      int stufe = 0,
      DateTime? versendet,
      DateTime? uebergeben,
    }) =>
        Rechnung(
          id: 'r1',
          userId: 'u1',
          rechnungsnummer: 'R-1',
          rechnungstyp: typ,
          rechnungsdatum: DateTime(2026, 9, 1),
          faelligkeitsdatum: DateTime(2026, 10, 1),
          betragBrutto: 100,
          zahlungsstatus: status,
          mahnungStufe: stufe,
          versendetAm: versendet,
          uebergebenAm: uebergeben,
        );
    final tag = DateTime(2026, 9, 2);

    test('bezahlt und abgeschrieben gehen allem vor', () {
      // Auch mit Mahnstufe und Versanddatum: erledigt ist erledigt.
      final b = mit(status: 'bezahlt', stufe: 3, versendet: tag);
      expect(anzeigeStatus(b), 'Bezahlt');
      expect(anzeigeSchluessel(b), 'bezahlt');
      final a = mit(status: 'abgeschrieben', stufe: 3, versendet: tag);
      expect(anzeigeStatus(a), 'Abgeschrieben');
      expect(anzeigeSchluessel(a), 'abgeschrieben');
    });

    test('Mahnstufe aus dem Status', () {
      expect(anzeigeStatus(mit(status: 'erinnert', stufe: 1)), 'Erinnert');
      expect(anzeigeStatus(mit(status: 'mahnung_1', stufe: 2)), '1. Mahnung');
      expect(
        anzeigeStatus(mit(status: 'mahnung_2', stufe: 3)),
        'Letzte Mahnung',
      );
    });

    test('Mahnstufe aus mahnung_stufe, wenn der Status zurückfiel', () {
      // Rücknahme einer Bankzahlung stellte früher nur den Status zurück —
      // die Mahnung liegt aber beim Kunden.
      final r = mit(status: 'gesendet', stufe: 2, versendet: tag);
      expect(anzeigeStatus(r), '1. Mahnung');
      expect(anzeigeSchluessel(r), 'mahnung_1');
      expect(anzeigeStatus(mit(status: 'offen', stufe: 1)), 'Erinnert');
      expect(anzeigeStatus(mit(status: 'offen', stufe: 3)), 'Letzte Mahnung');
    });

    test('die höhere der beiden Stufen gilt', () {
      // Status sagt «erinnert», Stufe sagt «Mahnung 2» — und umgekehrt.
      expect(
        anzeigeStatus(mit(status: 'erinnert', stufe: 3)),
        'Letzte Mahnung',
      );
      expect(
        anzeigeStatus(mit(status: 'mahnung_2', stufe: 0)),
        'Letzte Mahnung',
      );
    });

    test('Heineken: freigegeben', () {
      final r =
          mit(status: 'freigegeben', typ: 'heineken_monat', versendet: tag);
      expect(anzeigeStatus(r), 'Freigegeben');
      expect(anzeigeSchluessel(r), 'freigegeben');
    });

    test('Heineken: gesendet und offen wie alle anderen', () {
      expect(
        anzeigeStatus(
          mit(status: 'gesendet', typ: 'heineken_monat', versendet: tag),
        ),
        'Gesendet',
      );
      expect(
        anzeigeStatus(mit(status: 'offen', typ: 'heineken_monat')),
        'Offen',
      );
    });

    test('gesendet aus versendet_am, auch wenn der Status noch offen ist', () {
      final r = mit(status: 'offen', versendet: tag);
      expect(anzeigeStatus(r), 'Gesendet');
      expect(anzeigeSchluessel(r), 'gesendet');
    });

    test('gesendet aus dem Status, auch ohne Datum (Altbestand)', () {
      expect(anzeigeStatus(mit(status: 'gesendet')), 'Gesendet');
    });

    test('übergeben aus uebergeben_am (Tresen setzt keinen Status)', () {
      final r = mit(status: 'offen', uebergeben: tag);
      expect(anzeigeStatus(r), 'Übergeben');
      expect(anzeigeSchluessel(r), kAnzeigeUebergeben);
    });

    test('versendet geht übergeben vor', () {
      expect(
        anzeigeStatus(mit(status: 'offen', versendet: tag, uebergeben: tag)),
        'Gesendet',
      );
    });

    test('sonst offen', () {
      final r = mit();
      expect(anzeigeStatus(r), 'Offen');
      expect(anzeigeSchluessel(r), 'offen');
    });

    test('unbekannter Status kommt roh durch — sichtbar statt «Offen»', () {
      expect(
        anzeigeStatus(mit(status: 'storniert', versendet: tag)),
        'storniert',
      );
      expect(anzeigeSchluessel(mit(status: 'storniert')), 'storniert');
    });

    test('jeder Wert des DB-CHECK hat einen deutschen Text', () {
      for (final s in checkWerte) {
        final text = anzeigeStatus(mit(status: s));
        expect(text, isNot(s), reason: 'roher Wert «$s» statt Text');
        expect(text, isNotEmpty);
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
