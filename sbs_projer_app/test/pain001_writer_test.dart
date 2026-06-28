import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/pain001_writer.dart';

void main() {
  const debtor = Pain001Debtor(
    name: 'SBS Projer GmbH',
    iban: 'CH6600774010376550601',
    strtNm: 'Via Rezia',
    bldgNb: '8',
    pstCd: '7013',
    twnNm: 'Domat/Ems',
    ctry: 'CH',
    bic: 'GRKBCH2270A',
  );

  test('QRR-Zahlung erzeugt korrektes pain.001.001.09 XML', () {
    const payment = Pain001Payment(
      endToEndId: '96761766',
      cdtrName: 'Heineken Switzerland AG',
      cdtrIban: 'CH8830154001085747001',
      referenzTyp: 'QRR',
      referenz: '000000000041502501007887897',
      betrag: 3772.70,
      waehrung: 'CHF',
      cdtrTwnNm: 'Zürich',
      cdtrCtry: 'CH',
    );

    final xml = Pain001Writer.build(
      msgId: 'MSG-1',
      creationDateTime: DateTime(2026, 6, 28, 10, 0, 0),
      requestedExecutionDate: DateTime(2026, 6, 30),
      debtor: debtor,
      payments: [payment],
    );

    expect(
      xml.contains('urn:iso:std:iso:20022:tech:xsd:pain.001.001.09'),
      isTrue,
    );
    expect(xml.contains('<NbOfTxs>1</NbOfTxs>'), isTrue);
    expect(xml.contains('CH6600774010376550601'), isTrue);
    expect(xml.contains('CH8830154001085747001'), isTrue);
    expect(xml.contains('3772.70'), isTrue);
    expect(xml.contains('QRR'), isTrue);
    expect(xml.contains('000000000041502501007887897'), isTrue);
    expect(xml.contains('GRKBCH2270A'), isTrue);
  });

  test('SCOR-Zahlung erzeugt Strd>CdtrRefInf mit Cd SCOR, kein QRR', () {
    const payment = Pain001Payment(
      endToEndId: '12345678',
      cdtrName: 'Lieferant AG',
      cdtrIban: 'CH9300762011623852957',
      referenzTyp: 'SCOR',
      referenz: 'RF18539007547034',
      betrag: 100.00,
      waehrung: 'CHF',
      cdtrTwnNm: 'Bern',
      cdtrCtry: 'CH',
    );

    final xml = Pain001Writer.build(
      msgId: 'MSG-2',
      creationDateTime: DateTime(2026, 6, 28, 10, 0, 0),
      requestedExecutionDate: DateTime(2026, 6, 30),
      debtor: debtor,
      payments: [payment],
    );

    expect(xml.contains('SCOR'), isTrue);
    expect(xml.contains('RF18539007547034'), isTrue);
    expect(xml.contains('QRR'), isFalse);
  });

  test('NON-Zahlung erzeugt Ustrd-Mitteilung, kein Strd', () {
    const payment = Pain001Payment(
      endToEndId: '87654321',
      cdtrName: 'Vermieter GmbH',
      cdtrIban: 'CH9300762011623852957',
      referenzTyp: 'NON',
      mitteilung: 'Miete Buero Juni',
      betrag: 1500.00,
      waehrung: 'CHF',
      cdtrTwnNm: 'Chur',
      cdtrCtry: 'CH',
    );

    final xml = Pain001Writer.build(
      msgId: 'MSG-3',
      creationDateTime: DateTime(2026, 6, 28, 10, 0, 0),
      requestedExecutionDate: DateTime(2026, 6, 30),
      debtor: debtor,
      payments: [payment],
    );

    expect(xml.contains('<Ustrd>Miete Buero Juni</Ustrd>'), isTrue);
    expect(xml.contains('<Strd>'), isFalse);
  });
}
