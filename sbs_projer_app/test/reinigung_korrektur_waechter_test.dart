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

  test('Duplikat-Check der Ertragsbuchung zaehlt stornierte Zeilen nicht', () {
    final s = lies('lib/services/buchhaltung/reinigung_buchung_service.dart');
    expect(s.contains('zaehltFuerSaldo('), isTrue);
  });
}
