import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_kontakte.dart';

void main() {
  group('hatKontakteScope', () {
    test('null/leer/nur Kalender -> false', () {
      expect(hatKontakteScope(null), isFalse);
      expect(hatKontakteScope(''), isFalse);
      expect(
          hatKontakteScope(
              'https://www.googleapis.com/auth/calendar.events openid'),
          isFalse);
    });
    test('mit contacts-Scope -> true', () {
      expect(
          hatKontakteScope('https://www.googleapis.com/auth/calendar.events '
              'https://www.googleapis.com/auth/contacts email'),
          isTrue);
    });
    test('contacts.readonly zählt NICHT als Schreib-Scope', () {
      expect(
          hatKontakteScope('https://www.googleapis.com/auth/contacts.readonly'),
          isFalse);
    });
  });

  group('kontaktAusPicker (Name-Split)', () {
    test('zwei Wörter: erstes = Vorname, letztes = Nachname', () {
      final r = kontaktAusPicker('Hans Muster', '+41791234567', 'h@m.ch');
      expect(r.vorname, 'Hans');
      expect(r.nachname, 'Muster');
      expect(r.telefon, '+41791234567');
      expect(r.email, 'h@m.ch');
    });
    test('drei Wörter: letztes Wort = Nachname, Rest = Vorname', () {
      final r = kontaktAusPicker('Hans Peter Muster', null, null);
      expect(r.vorname, 'Hans Peter');
      expect(r.nachname, 'Muster');
    });
    test('ein Wort: alles Nachname', () {
      final r = kontaktAusPicker('Muster', null, null);
      expect(r.vorname, isNull);
      expect(r.nachname, 'Muster');
    });
    test('leer/null: alles null', () {
      final r = kontaktAusPicker('  ', null, '');
      expect(r.vorname, isNull);
      expect(r.nachname, isNull);
      expect(r.telefon, isNull);
      expect(r.email, isNull);
    });
  });

  group('kontakteSyncStatusText', () {
    test('nie gesynct', () {
      expect(kontakteSyncStatusText(null, null), 'Noch nie synchronisiert');
    });
    test('mit Zeit und Info', () {
      expect(
          kontakteSyncStatusText(
              DateTime(2026, 7, 21, 18, 32), '104 Kontakte, 240 Betriebe'),
          'Letzter Sync 21.07.2026 18:32 · 104 Kontakte, 240 Betriebe');
    });
    test('Fehler-Info wird durchgereicht', () {
      expect(kontakteSyncStatusText(DateTime(2026, 7, 21, 6, 5), 'Fehler: 401'),
          'Letzter Sync 21.07.2026 06:05 · Fehler: 401');
    });
    test('Zeit ohne Info', () {
      expect(kontakteSyncStatusText(DateTime(2026, 7, 21, 6, 5), ''),
          'Letzter Sync 21.07.2026 06:05');
    });
  });
}
