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
      expect(r.telefon, '+41 79 123 45 67');
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

  group('telefonAusPicker (Nummernformat, Regel Daniel 22.07.)', () {
    test('nationale Nummer 079… -> +41-Format', () {
      expect(telefonAusPicker('079 123 45 67'), '+41 79 123 45 67');
      expect(telefonAusPicker('0791234567'), '+41 79 123 45 67');
    });
    test('Festnetz 081… -> +41-Format', () {
      expect(telefonAusPicker('081 378 40 20'), '+41 81 378 40 20');
    });
    test('00-Präfix -> +', () {
      expect(telefonAusPicker('0041 79 123 45 67'), '+41 79 123 45 67');
    });
    test('bereits +41 wird nur formatiert', () {
      expect(telefonAusPicker('+41791234567'), '+41 79 123 45 67');
      expect(telefonAusPicker('+41 79 123 45 67'), '+41 79 123 45 67');
    });
    test('41-Präfix ohne + wird ergänzt', () {
      expect(telefonAusPicker('41791234567'), '+41 79 123 45 67');
    });
    test('ausländische Nummer bleibt vollständig (kein CH-Raster)', () {
      expect(telefonAusPicker('+49 170 1234567'), '+491701234567');
    });
    test('unbekanntes Format bleibt unverändert', () {
      expect(telefonAusPicker('123'), '123');
    });
    test('leer/null -> null', () {
      expect(telefonAusPicker(null), isNull);
      expect(telefonAusPicker('  '), isNull);
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
