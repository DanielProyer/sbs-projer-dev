// Erzeugt ein Beispiel-pain.001.001.09 (alle 3 Zahlungstypen) zur XSD-Pruefung.
// Lauf: dart run tool/gen_pain001.dart  ->  build/sample_pain001.xml
import 'dart:io';
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

  final payments = <Pain001Payment>[
    const Pain001Payment(
      endToEndId: '96761766',
      cdtrName: 'Heineken Switzerland AG',
      cdtrIban: 'CH8830154001085747001',
      referenzTyp: 'QRR',
      referenz: '000000000041502501007887897',
      cdtrStrtNm: 'Industriestrasse',
      cdtrBldgNb: '23',
      cdtrPstCd: '8005',
      cdtrTwnNm: 'Zuerich',
      cdtrCtry: 'CH',
      betrag: 3772.70,
      waehrung: 'CHF',
    ),
    const Pain001Payment(
      endToEndId: 'R-2026-77',
      cdtrName: 'Beispiel SCOR AG',
      cdtrIban: 'CH9300762011623852957',
      referenzTyp: 'SCOR',
      referenz: 'RF18539007547034',
      cdtrStrtNm: 'Bahnhofstrasse',
      cdtrBldgNb: '1',
      cdtrPstCd: '7000',
      cdtrTwnNm: 'Chur',
      cdtrCtry: 'CH',
      betrag: 150.00,
      waehrung: 'CHF',
    ),
    const Pain001Payment(
      endToEndId: 'NOTPROVIDED',
      cdtrName: 'Vermieter Beispiel',
      cdtrIban: 'CH9300762011623852957',
      referenzTyp: 'NON',
      mitteilung: 'Miete Buero Juni 2026',
      cdtrStrtNm: 'Seestrasse',
      cdtrBldgNb: '10',
      cdtrPstCd: '8000',
      cdtrTwnNm: 'Zuerich',
      cdtrCtry: 'CH',
      betrag: 1200.00,
      waehrung: 'CHF',
    ),
  ];

  final xml = Pain001Writer.build(
    msgId: 'SBS-SAMPLE-1',
    creationDateTime: DateTime(2026, 6, 28, 10, 0, 0),
    requestedExecutionDate: DateTime(2026, 6, 30),
    debtor: debtor,
    payments: payments,
  );

  Directory('build').createSync(recursive: true);
  File('build/sample_pain001.xml').writeAsStringSync(xml);
  stdout.writeln('OK: build/sample_pain001.xml (${xml.length} Zeichen)');
}
