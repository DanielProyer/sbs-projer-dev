import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// R1 (Analyse 25.09.2026): Rechnung und Buchungen einer abgeschlossenen
/// Reinigung dürfen nie mehr ungeprüft gelöscht werden. Der Korrektur-
/// Service prüft die Sperre, storniert statt zu löschen und ruft
/// `deleteByBeleg` nicht mehr auf; die Screens gehen nur über ihn.
void main() {
  String lies(String p) => File(p).readAsStringSync();

  test('Korrektur-Service loescht keine Buchungen mehr hart', () {
    final s = lies('lib/services/rechnung/reinigung_korrektur_service.dart');
    expect(s.contains('deleteByBeleg'), isFalse);
    expect(s.contains('BuchungRepository.stornieren'), isTrue);
    expect(s.contains('korrekturSperre('), isTrue);
  });

  test('Formular und Detail pruefen die Sperre vor jeder Korrektur', () {
    final form = lies('lib/presentation/screens/reinigungen/reinigung_form_screen.dart');
    final detail = lies('lib/presentation/screens/reinigungen/reinigung_detail_screen.dart');
    expect(form.contains('ReinigungKorrekturService.sperrePruefen'), isTrue);
    expect(form.contains('preisrelevantGeaendert('), isTrue);
    expect(form.contains('cleanupBuchhaltung'), isFalse);
    expect(detail.contains('ReinigungKorrekturService.sperrePruefen'), isTrue);
  });

  test('Review af581d42: eigene Ausnahmen, Abschluss-Erkennung, Preise behalten', () {
    final s = lies('lib/services/rechnung/reinigung_korrektur_service.dart');
    expect(s.contains('throw KorrekturGesperrt('), isTrue);
    expect(s.contains('throw KorrekturFehler('), isTrue);
    expect(s.contains('StateError('), isFalse);
    final form = lies('lib/presentation/screens/reinigungen/reinigung_form_screen.dart');
    expect(form.contains('abschliessen && !_warAbgeschlossen'), isTrue);
    expect(form.contains('_existing?.status != '), isFalse);
    expect(form.contains('preiseBehalten'), isTrue);
    final detail = lies('lib/presentation/screens/reinigungen/reinigung_detail_screen.dart');
    expect(detail.contains('mitAusweg: false'), isTrue);
  });

  test('Duplikat-Check der Ertragsbuchung zaehlt stornierte Zeilen nicht', () {
    final s = lies('lib/services/buchhaltung/reinigung_buchung_service.dart');
    expect(s.contains('zaehltFuerSaldo('), isTrue);
  });
}
