import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

BetriebRechnungsadresse _ra({
  String? firma,
  String objekt = 'Spiga',
  String? kostenstelle,
  String? zusatz,
  String? postfach,
  String strasse = '',
  String? nr,
  String plz = '8901',
  String ort = 'Urdorf',
}) =>
    BetriebRechnungsadresse(
      id: '',
      userId: '',
      betriebId: '',
      firma: firma,
      objekt: objekt,
      kostenstelle: kostenstelle,
      zusatz: zusatz,
      postfach: postfach,
      strasse: strasse,
      nr: nr,
      plz: plz,
      ort: ort,
    );

void main() {
  group('adressZeilen — Briefkopf', () {
    test('ohne Rechnungsadresse: Betriebsname + Betriebsadresse', () {
      final zeilen = adressZeilen(
        betriebName: 'Calanda',
        betriebStrasse: 'Grabenstrasse',
        betriebNr: '19',
        betriebPlz: '7000',
        betriebOrt: 'Chur',
        ra: null,
      );
      expect(zeilen, ['Calanda', 'Grabenstrasse 19', '7000 Chur']);
    });

    test('Sammelzahler: Firma zuerst, Betrieb direkt darunter sichtbar', () {
      final zeilen = adressZeilen(
        betriebName: 'Legna Bar',
        ra: _ra(
          firma: 'Weisse Arena Hospitality AG',
          objekt: 'Legna Bar',
          strasse: 'Via Murschetg',
          nr: '15',
          plz: '7032',
          ort: 'Laax',
        ),
      );
      expect(zeilen, [
        'Weisse Arena Hospitality AG',
        'Legna Bar',
        'Via Murschetg 15',
        '7032 Laax',
      ]);
    });

    test('SV-Fall: sechs Zeilen inkl. Kostenstelle, Zusatz und Postfach', () {
      final zeilen = adressZeilen(
        betriebName: 'Spiga',
        ra: _ra(
          firma: 'SV (Schweiz) AG',
          objekt: 'Spiga Steinbock Chur',
          kostenstelle: 'KST 28616406',
          zusatz: 'Scanning Center',
          postfach: 'Postfach 440',
        ),
      );
      expect(zeilen, [
        'SV (Schweiz) AG',
        'Spiga Steinbock Chur',
        'KST 28616406',
        'Scanning Center',
        'Postfach 440',
        '8901 Urdorf',
      ]);
    });

    test('Postfach verdraengt eine trotzdem erfasste Strasse', () {
      final zeilen = adressZeilen(
        betriebName: 'Spiga',
        ra: _ra(postfach: 'Postfach 440', strasse: 'Musterweg', nr: '7'),
      );
      expect(zeilen, contains('Postfach 440'));
      expect(zeilen, isNot(contains('Musterweg 7')));
    });

    test('leere Zusatzfelder erzeugen keine Leerzeilen', () {
      final zeilen = adressZeilen(
        betriebName: 'Spiga',
        ra: _ra(kostenstelle: '', zusatz: '   ', strasse: 'Dorfstr', nr: '1'),
      );
      expect(zeilen, ['Spiga', 'Dorfstr 1', '8901 Urdorf']);
    });
  });

  group('qrEmpfaenger — Zahlbar durch (QR-Bill)', () {
    test('nur Firma + Objekt im Namen, nie Kostenstelle oder Zusatz', () {
      final qr = qrEmpfaenger(
        betriebName: 'Spiga',
        ra: _ra(
          firma: 'SV (Schweiz) AG',
          objekt: 'Spiga Steinbock Chur',
          kostenstelle: 'KST 28616406',
          zusatz: 'Scanning Center',
          postfach: 'Postfach 440',
        ),
      );
      expect(qr.name, 'SV (Schweiz) AG Spiga Steinbock Chur');
      expect(qr.name, isNot(contains('KST')));
      expect(qr.name, isNot(contains('Scanning')));
    });

    test('Postfach wird zur Strassenzeile, Nr. bleibt leer', () {
      final qr = qrEmpfaenger(
        betriebName: 'Spiga',
        ra: _ra(postfach: 'Postfach 440'),
      );
      expect(qr.strasse, 'Postfach 440');
      expect(qr.nr, '');
      expect(qr.plz, '8901');
      expect(qr.ort, 'Urdorf');
    });

    test('Name wird auf 70 Zeichen begrenzt (QR-Bill-Norm)', () {
      final qr = qrEmpfaenger(
        betriebName: 'X',
        ra: _ra(firma: 'A' * 50, objekt: 'B' * 50),
      );
      expect(qr.name.length, 70);
    });

    test('ohne Rechnungsadresse: Betriebsname und Betriebsadresse', () {
      final qr = qrEmpfaenger(
        betriebName: 'Calanda',
        betriebStrasse: 'Grabenstrasse',
        betriebNr: '19',
        betriebPlz: '7000',
        betriebOrt: 'Chur',
        ra: null,
      );
      expect(qr.name, 'Calanda');
      expect(qr.strasse, 'Grabenstrasse');
      expect(qr.nr, '19');
    });
  });
}
