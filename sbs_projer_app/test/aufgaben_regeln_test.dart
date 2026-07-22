import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';

void main() {
  group('heinekenAufgabe', () {
    // heute 05.08.2026 -> Vormonat Juli 2026
    final heute = DateTime(2026, 8, 5);
    test('keine Rechnung -> Stufe erstellen', () {
      final a = heinekenAufgabe(heute: heute, rechnungExistiert: false, rechnungOffen: false);
      expect(a, isNotNull);
      expect(a!.key, 'heineken:2026-07');
      expect(a.titel, contains('erstellen'));
      expect(a.titel, contains('Juli'));
    });
    test('Rechnung offen -> Stufe versenden', () {
      final a = heinekenAufgabe(heute: heute, rechnungExistiert: true, rechnungOffen: true);
      expect(a!.titel, contains('versenden'));
    });
    test('Rechnung gesendet -> erledigt (null)', () {
      expect(heinekenAufgabe(heute: heute, rechnungExistiert: true, rechnungOffen: false), isNull);
    });
    test('Färbung: bis 10. orange, danach rot', () {
      expect(heinekenAufgabe(heute: DateTime(2026, 8, 10), rechnungExistiert: false, rechnungOffen: false)!.dringend, isFalse);
      expect(heinekenAufgabe(heute: DateTime(2026, 8, 11), rechnungExistiert: false, rechnungOffen: false)!.dringend, isTrue);
    });
    test('Jahreswechsel: Januar erinnert an Dezember', () {
      final a = heinekenAufgabe(heute: DateTime(2027, 1, 2), rechnungExistiert: false, rechnungOffen: false);
      expect(a!.key, 'heineken:2026-12');
      expect(a.titel, contains('Dezember'));
    });
  });

  group('mwstAufgabe', () {
    test('Q2 vorbei -> Aufgabe ab 01.07., Frist 31.08.', () {
      final a = mwstAufgabe(heute: DateTime(2026, 7, 22), markerKeys: const {});
      expect(a!.key, 'mwst:2026-Q2');
      expect(a.titel, contains('Q2'));
      expect(a.dringend, isFalse); // 31.08. ist > 14 Tage entfernt
    });
    test('14 Tage vor Frist -> dringend', () {
      expect(mwstAufgabe(heute: DateTime(2026, 8, 18), markerKeys: const {})!.dringend, isTrue);
    });
    test('nach Frist -> weiterhin sichtbar und dringend', () {
      expect(mwstAufgabe(heute: DateTime(2026, 9, 15), markerKeys: const {})!.dringend, isTrue);
    });
    test('Marker unterdrückt', () {
      expect(mwstAufgabe(heute: DateTime(2026, 7, 22), markerKeys: const {'mwst:2026-Q2'}), isNull);
    });
    test('Q4: Frist 28.02. im Folgejahr, key mit altem Jahr', () {
      final a = mwstAufgabe(heute: DateTime(2027, 1, 10), markerKeys: const {});
      expect(a!.key, 'mwst:2026-Q4');
    });
  });

  group('mahnlauf/saisondaten', () {
    test('Zähler > 0 -> Aufgabe mit Anzahl, = 0 -> null', () {
      expect(mahnlaufAufgabe(3)!.titel, contains('3'));
      expect(mahnlaufAufgabe(0), isNull);
      expect(saisondatenAufgabe(15)!.titel, contains('15'));
      expect(saisondatenAufgabe(0), isNull);
    });
  });

  group('Snooze + eigene + Sortierung', () {
    final heute = DateTime(2026, 7, 22);
    test('snoozeAktiv: bis heute inkl., abgelaufen nicht', () {
      expect(snoozeAktiv(DateTime(2026, 7, 22), heute), isTrue);
      expect(snoozeAktiv(DateTime(2026, 7, 21), heute), isFalse);
      expect(snoozeAktiv(null, heute), isFalse);
    });
    test('eigeneSichtbar: ohne Datum sofort, mit Datum ab Fällig-7', () {
      expect(eigeneSichtbar(null, heute), isTrue);
      expect(eigeneSichtbar(DateTime(2026, 7, 29), heute), isTrue);  // genau 7 Tage
      expect(eigeneSichtbar(DateTime(2026, 7, 30), heute), isFalse); // 8 Tage
    });
    test('sortiereAufgaben: dringend zuerst, dann Rest stabil', () {
      final l = [
        const Aufgabe(key: 'a', titel: 'A', dringend: false),
        const Aufgabe(key: 'b', titel: 'B', dringend: true),
        const Aufgabe(key: 'c', titel: 'C', dringend: false),
      ];
      final s = sortiereAufgaben(l);
      expect(s.map((a) => a.key).toList(), ['b', 'a', 'c']);
    });
  });
}
