import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die neue Reinigung muss ihren Entwurf sichern, anbieten und aufräumen (V2).
///
/// WARUM: Eine neue Reinigung lebte nur im Browser-Tab. Die Kamera-App
/// schiebt Chrome in den Hintergrund, Android verwirft den Tab — 111
/// Formular-Öffnungen bei 73 Reinigungen in 17 Tagen (Analyse 25.09.2026,
/// Bericht 4 «Tagesbetrieb», F2). Fällt einer der drei Aufrufe beim Umbau
/// weg, merkt es niemand, bis wieder eine Reinigung verloren ist.
void main() {
  final datei = File(
    'lib/presentation/screens/reinigungen/reinigung_form_screen.dart',
  );

  test('Formular sichert, lädt und löscht den Entwurf', () {
    final text = datei.readAsStringSync();
    for (final aufruf in const [
      'ReinigungEntwurfSpeicher.speichern(',
      'ReinigungEntwurfSpeicher.laden(',
      'ReinigungEntwurfSpeicher.loeschen(',
    ]) {
      expect(text, contains(aufruf), reason: '$aufruf fehlt im Formular');
    }
  });

  test('das Entwurf-Band baut seine Knöpfe aus TapKnopf', () {
    final text = datei.readAsStringSync();
    final start = text.indexOf('Widget _entwurfBand(');
    expect(start, isNot(-1), reason: '_entwurfBand() fehlt im Formular');
    final ende = text.indexOf('\n  }\n', start);
    final band = text.substring(start, ende);
    expect(band, contains('TapKnopf('));
    expect(band, contains('Fortsetzen'));
    expect(band, contains('Verwerfen'));
    expect(
      band,
      isNot(matches(RegExp(r'\b(Filled|Outlined|Elevated|Text)Button\b'))),
      reason: 'CanvasKit-Regel: Knöpfe im Band nur als TapKnopf (CLAUDE.md)',
    );
  });

  test('Verwerfen fragt über gefahrRueckfrage nach', () {
    final text = datei.readAsStringSync();
    expect(text, contains("titel: 'Entwurf verwerfen?'"));
  });
}
