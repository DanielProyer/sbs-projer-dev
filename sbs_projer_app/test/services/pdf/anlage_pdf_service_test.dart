import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/services/pdf/anlage_pdf_service.dart';

// Gültiges kleines Test-Bild (via image-Paket erzeugt).
final Uint8List _pngBytes = img.encodePng(img.Image(width: 4, height: 4));

void main() {
  // PDF-Services laden die Unicode-Schrift aus den Assets (rootBundle).
  TestWidgetsFlutterBinding.ensureInitialized();
  final a = AnlageLocal()
    ..bezeichnung = 'Warm 1'
    ..typAnlage = 'Warmanstich'
    ..anzahlHaehne = 4;
  final b = BetriebLocal()
    ..name = 'Restaurant Sonne'
    ..ort = 'Chur';

  test('steckbrief baut ein PDF ohne Fotos', () async {
    final bytes = await AnlagePdfService.steckbrief(anlage: a, betrieb: b);
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

  test('steckbrief baut ein PDF mit 5 Bierleitungen + 4 Fotos (eine Seite)',
      () async {
    final leitungen = [
      for (var i = 1; i <= 5; i++)
        BierleitungLocal()
          ..leitungsNummer = i
          ..biersorte = 'Lager $i'
          ..hahnTyp = 'Standard',
    ];
    final fotos = <Uint8List>[_pngBytes, _pngBytes, _pngBytes, _pngBytes];
    final bytes = await AnlagePdfService.steckbrief(
      anlage: a,
      betrieb: b,
      fotos: fotos,
      bierleitungen: leitungen,
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}
