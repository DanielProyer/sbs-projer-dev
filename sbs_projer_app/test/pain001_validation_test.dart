import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/pain001_writer.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/pain001_validation.dart';

Pain001Payment _p({
  String iban = 'CH8830154001085747001', // QR-IBAN (IID 30154)
  String typ = 'QRR',
  String? ref = '000000000041502501007887897', // echte Heineken-QRR
  String? ort = 'Zürich',
  double betrag = 100.0,
}) =>
    Pain001Payment(
      endToEndId: 'E',
      cdtrName: 'X',
      cdtrIban: iban,
      referenzTyp: typ,
      cdtrTwnNm: ort,
      cdtrCtry: 'CH',
      referenz: ref,
      betrag: betrag,
      waehrung: 'CHF',
    );

void main() {
  test('gültige QRR-Zahlung -> keine Fehler', () {
    expect(pruefeZahlung(_p()), isEmpty);
  });

  test('QRR ohne QR-IBAN -> Fehler', () {
    final f = pruefeZahlung(_p(iban: 'CH9300762011623852957')); // normale IBAN
    expect(f.any((e) => e.contains('QR-IBAN')), isTrue);
  });

  test('SCOR mit QR-IBAN -> Fehler', () {
    final f = pruefeZahlung(_p(typ: 'SCOR', ref: 'RF18539007547034'));
    expect(f.any((e) => e.contains('nicht mit QR-IBAN')), isTrue);
  });

  test('fehlender Ort -> Fehler', () {
    expect(pruefeZahlung(_p(ort: '')).any((e) => e.contains('Ort')), isTrue);
  });

  test('fehlende IBAN -> Fehler', () {
    expect(
        pruefeZahlung(_p(iban: '')).any((e) => e.contains('IBAN fehlt')), isTrue);
  });
}
