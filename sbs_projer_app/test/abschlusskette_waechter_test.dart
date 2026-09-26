import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// §3 Zeile 1 der Analyse 25.09.2026: Die Abschlusskette (Rechnung → Versand
/// → Buchung → Nachholen → Pauschale) existiert genau EINMAL —
/// im ReinigungAbschlussService. Screens rufen nur ihn.
void main() {
  String lies(String p) => File(p).readAsStringSync();
  const form = 'lib/presentation/screens/reinigungen/reinigung_form_screen.dart';
  const detail = 'lib/presentation/screens/reinigungen/reinigung_detail_screen.dart';

  test('Formular baut die Kette nicht mehr selbst', () {
    final s = lies(form);
    for (final verboten in [
      'RechnungService.createFromReinigung',
      "'send-rechnung-mail'",
      'ReinigungBuchungService.createFromReinigung',
      'BuchungNachholService.nachholen',
      'BergkundenpauschaleRepository.create',
      'ReinigungRechnungVersand.vermerkeVersand',
    ]) {
      expect(s.contains(verboten), isFalse, reason: '$verboten gehört in den Service');
    }
    expect(s.contains('ReinigungAbschlussService.abschliessen'), isTrue);
  });

  test('Detail-Screen nutzt dieselbe Kette', () {
    final s = lies(detail);
    expect(s.contains('ReinigungAbschlussService.abschliessen'), isTrue);
    expect(s.contains('ReinigungRechnungVersand.erstelleUndSende'), isFalse);
    expect(s.contains('ReinigungBuchungService.createFromReinigung'), isFalse);
  });

  test('T5: Pausen-Pruefung laeuft NACH der Kette', () {
    final s = lies(form);
    final kette = s.indexOf('ReinigungAbschlussService.abschliessen');
    final pause = s.indexOf('pausePruefenNachEreignis(');
    expect(kette, greaterThan(-1));
    expect(pause, greaterThan(kette));
  });

  test('Service enthaelt alle Glieder', () {
    final s = lies('lib/services/rechnung/reinigung_abschluss_service.dart');
    for (final glied in [
      'ReinigungRechnungVersand.erstelleUndSende',
      'ReinigungBuchungService.createFromReinigung',
      'BuchungNachholService.nachholen',
      'BergkundenpauschaleRepository.create',
    ]) {
      expect(s.contains(glied), isTrue, reason: glied);
    }
  });
}
