import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:sbs_projer_app/core/util/scor_referenz.dart';

void main() {
  test('kanonischer ISO-11649-Vektor', () {
    expect(scorReferenz('539007547034'), 'RF18539007547034');
  });

  test('erzeugte Referenz ist mod-97-gültig (RF…00-Regel)', () {
    final ref = scorReferenz('202606250001');
    expect(ref.startsWith('RF'), isTrue);
    expect(istGueltigeScor(ref), isTrue);
  });

  test('scorRefNorm: Leerzeichen weg, Uppercase', () {
    expect(scorRefNorm('rf18 5390 0754 7034'), 'RF18539007547034');
    expect(scorRefNorm(' RF18539007547034 '), 'RF18539007547034');
  });

  test('qrReferenzAusNummer: nur Kundentypen, Ziffern aus Nummer', () {
    expect(qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001'),
        scorReferenz('202606250001'));
    expect(qrReferenzAusNummer('jahresrechnung', '2026-0042'),
        scorReferenz('20260042'));
    expect(qrReferenzAusNummer('heineken_monat', '2026-06-25-0001'), isNull);
    expect(qrReferenzAusNummer('kundenrechnung', null), isNull);
  });

  test('Suffix erzeugt eine andere, gültige Referenz (Kollisions-Auflösung)', () {
    final basis = qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001')!;
    final s1 = qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 1)!;
    final s2 = qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 2)!;
    expect(qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 0), basis);
    expect(s1, isNot(basis));
    expect(s2, isNot(s1));
    expect(istGueltigeScor(s1), isTrue);
    expect(istGueltigeScor(s2), isTrue);
  });

  group('istQrReferenzKonflikt (Review 23.09.2026, Punkt 5)', () {
    test('23505 auf qr_referenz erkannt (message)', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint "rechnungen_qr_referenz_key"',
        code: '23505',
      );
      expect(istQrReferenzKonflikt(e), isTrue);
    });

    test('23505 auf qr_referenz erkannt (details)', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
        details: 'Key (qr_referenz)=(RF18539007547034) already exists.',
      );
      expect(istQrReferenzKonflikt(e), isTrue);
    });

    test('23505 auf einer anderen Spalte (z.B. rechnungsnummer) ist KEIN Treffer', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint "rechnungen_rechnungsnummer_key"',
        code: '23505',
      );
      expect(istQrReferenzKonflikt(e), isFalse);
    });

    test('anderer Fehlercode ist kein Treffer, auch mit qr_referenz im Text', () {
      final e = PostgrestException(message: 'irgendwas mit qr_referenz', code: '42501');
      expect(istQrReferenzKonflikt(e), isFalse);
    });

    test('keine PostgrestException ist kein Treffer', () {
      expect(istQrReferenzKonflikt(Exception('qr_referenz kaputt')), isFalse);
    });
  });

  group('mitQrReferenzRetry (Review 23.09.2026, Punkt 5)', () {
    test('erster Versuch klappt: kein Retry nötig', () async {
      final versuche = <String?>[];
      final ergebnis = await mitQrReferenzRetry<String?>(
        rechnungstyp: 'kundenrechnung',
        rechnungsnummer: '2026-06-25-0001',
        aktion: (ref) async {
          versuche.add(ref);
          return ref;
        },
      );
      expect(versuche, [qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001')]);
      expect(ergebnis, versuche.single);
    });

    test('Kollision auf dem ersten Kandidaten: zweiter Versuch mit Suffix 1', () async {
      final versuche = <String?>[];
      final ergebnis = await mitQrReferenzRetry<String?>(
        rechnungstyp: 'kundenrechnung',
        rechnungsnummer: '2026-06-25-0001',
        aktion: (ref) async {
          versuche.add(ref);
          if (versuche.length == 1) {
            throw PostgrestException(
              message: 'duplicate key value violates unique constraint',
              code: '23505',
              details: 'Key (qr_referenz)=($ref) already exists.',
            );
          }
          return ref;
        },
      );
      expect(versuche, hasLength(2));
      expect(versuche[1], qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 1));
      expect(ergebnis, versuche[1]);
    });

    test('ohne Rechnungsnummer/Kundentyp (ref null): EIN Versuch, kein Retry', () async {
      final versuche = <String?>[];
      final ergebnis = await mitQrReferenzRetry<String?>(
        rechnungstyp: 'heineken_monat',
        rechnungsnummer: '2026-06',
        aktion: (ref) async {
          versuche.add(ref);
          return ref;
        },
      );
      expect(versuche, [null]);
      expect(ergebnis, isNull);
    });

    test('ein anderer Fehler (keine qr_referenz-Kollision) wird NICHT wiederholt', () async {
      var versuche = 0;
      await expectLater(
        mitQrReferenzRetry<String?>(
          rechnungstyp: 'kundenrechnung',
          rechnungsnummer: '2026-06-25-0001',
          aktion: (ref) async {
            versuche++;
            throw Exception('Netzwerkfehler');
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(versuche, 1);
    });
  });
}
