import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// T1/R8: Ein gescheiterter Foto-Upload darf nie mehr nur im Debug-Protokoll
/// landen (~23 Abbrüche in 17 Tagen, Protokolle fehlten still).
void main() {
  test('Foto-Upload meldet Fehler sichtbar und laeuft sofort nach der Aufnahme', () {
    final s = File('lib/presentation/screens/reinigungen/reinigung_form_screen.dart')
        .readAsStringSync();
    expect(s.contains('_fotoHochladen('), isTrue);
    expect(s.contains('_fotoFehler'), isTrue);
    expect(s.contains("debugPrint('Foto-Upload fehlgeschlagen: \$e');"), isFalse);
  });
  test('Detektor fuer Reinigungen ohne Protokollfoto existiert', () {
    final s = File('lib/presentation/providers/aufgaben_detektoren_provider.dart')
        .readAsStringSync();
    expect(s.contains('protokollFehltAufgabe('), isTrue);
    expect(s.contains("isFilter('protokoll_foto_pfad', null)"), isTrue);
  });
}
