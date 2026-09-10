import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';

void main() {
  _buchungsTests();
  _versandvermerkTests();

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

  group('mwstAufgaben', () {
    test('Q2 vorbei -> Aufgabe ab 01.07., Frist 31.08.', () {
      final a = mwstAufgaben(heute: DateTime(2026, 7, 22), markerKeys: const {}).first;
      expect(a.key, 'mwst:2026-Q2');
      expect(a.titel, contains('Q2'));
      expect(a.dringend, isFalse); // 31.08. ist > 14 Tage entfernt
    });
    test('14 Tage vor Frist -> dringend', () {
      expect(mwstAufgaben(heute: DateTime(2026, 8, 18), markerKeys: const {}).first.dringend, isTrue);
    });
    test('nach Frist -> weiterhin sichtbar und dringend', () {
      expect(mwstAufgaben(heute: DateTime(2026, 9, 15), markerKeys: const {}).first.dringend, isTrue);
    });
    test('Marker unterdrückt einzelnes Quartal', () {
      final keys = mwstAufgaben(heute: DateTime(2026, 7, 22), markerKeys: const {'mwst:2026-Q2'})
          .map((a) => a.key)
          .toList();
      expect(keys, isNot(contains('mwst:2026-Q2')));
    });
    test('Q4: Frist 28.02. im Folgejahr, key mit altem Jahr', () {
      final a = mwstAufgaben(heute: DateTime(2027, 1, 10), markerKeys: const {}).first;
      expect(a.key, 'mwst:2026-Q4');
    });
    test('Liste: mehrere unmarkierte Quartale gehen nicht verloren (Beispiel)', () {
      final keys = mwstAufgaben(heute: DateTime(2026, 7, 22), markerKeys: const {})
          .map((a) => a.key)
          .toList();
      expect(keys, ['mwst:2026-Q2', 'mwst:2026-Q1', 'mwst:2025-Q4', 'mwst:2025-Q3']);
    });
    test('Liste: mit Marker für Q1 und ältere -> nur Q2', () {
      final keys = mwstAufgaben(
        heute: DateTime(2026, 7, 22),
        markerKeys: const {'mwst:2026-Q1', 'mwst:2025-Q4', 'mwst:2025-Q3'},
      ).map((a) => a.key).toList();
      expect(keys, ['mwst:2026-Q2']);
    });
    test('Ablösung: Q1 unmarkiert bleibt auch nach Q2-Ende in der Liste', () {
      final keys = mwstAufgaben(heute: DateTime(2026, 10, 5), markerKeys: const {})
          .map((a) => a.key)
          .toList();
      expect(keys, contains('mwst:2026-Q1'));
      expect(keys, contains('mwst:2026-Q3'));
    });
    test('alle markiert -> leere Liste', () {
      final aufgaben = mwstAufgaben(
        heute: DateTime(2026, 7, 22),
        markerKeys: const {
          'mwst:2026-Q2',
          'mwst:2026-Q1',
          'mwst:2025-Q4',
          'mwst:2025-Q3',
        },
      );
      expect(aufgaben, isEmpty);
    });
    test('April -> erstes Element ist Q1', () {
      final a = mwstAufgaben(heute: DateTime(2026, 4, 15), markerKeys: const {}).first;
      expect(a.key, 'mwst:2026-Q1');
    });
    test('Oktober -> erstes Element ist Q3', () {
      final a = mwstAufgaben(heute: DateTime(2026, 10, 15), markerKeys: const {}).first;
      expect(a.key, 'mwst:2026-Q3');
    });
    test('Schaltjahr Q4: heute 10.01.2028 -> Q4/2027, Frist 28.02.2028', () {
      final a = mwstAufgaben(heute: DateTime(2028, 1, 10), markerKeys: const {}).first;
      expect(a.key, 'mwst:2027-Q4');
      expect(a.titel, contains('28.02.2028'));
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
    test('eigeneSichtbar: Zeitanteil von faelligAm wird ignoriert', () {
      expect(eigeneSichtbar(DateTime(2026, 7, 29, 23, 30), DateTime(2026, 7, 22)), isTrue);
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

/// Versandvermerk-Wächter — nachgerüstet am 10.09.2026.
///
/// Am 07.09. ging die Rechnung an Signina per Mail raus, der Vermerk in der
/// App kam nicht mehr durch: Sie stand danach auf «offen», obwohl sie beim
/// Kunden lag. Aufgefallen ist das nur, weil Daniel den Postausgang mit der
/// App verglichen hat — und die Gefahr war, sie ein zweites Mal zu senden.
///
/// Die App kann nicht wissen, ob eine Mail rausging. Sie kann aber sagen:
/// Hier stimmt etwas nicht, sieh im Postausgang nach.
void _buchungsTests() {
  group('Waechter fuer fehlende Ertragsbuchungen', () {
    test('stumm, solange nichts fehlt', () {
      expect(fehlendeBuchungenAufgabe(0), isNull);
    });

    test('meldet Einzahl und Mehrzahl', () {
      expect(fehlendeBuchungenAufgabe(1)!.titel,
          '1 Reinigung ohne Ertragsbuchung');
      expect(fehlendeBuchungenAufgabe(2)!.titel,
          '2 Reinigungen ohne Ertragsbuchung');
    });

    test('dringend und mit Weg zu den Forderungen', () {
      // Ohne Ertragsbuchung fehlt der Umsatz in der Erfolgsrechnung — das
      // faellt sonst erst beim Abschluss auf.
      final a = fehlendeBuchungenAufgabe(2)!;
      expect(a.dringend, isTrue);
      expect(a.route, '/rechnungen');
      expect(a.key, 'fehlende_buchungen');
    });
  });
}

void _versandvermerkTests() {
  group('Versandvermerk-Wächter', () {
    test('ohne Verdachtsfälle stumm', () {
      expect(versandvermerkAufgabe(0), isNull);
    });

    test('meldet Einzahl und Mehrzahl richtig', () {
      expect(versandvermerkAufgabe(1)!.titel,
          '1 Mail-Rechnung ohne Versandvermerk — Postausgang prüfen');
      expect(versandvermerkAufgabe(3)!.titel,
          '3 Mail-Rechnungen ohne Versandvermerk — Postausgang prüfen');
    });

    test('führt zu den Forderungen und ist dringend', () {
      // Dringend, weil beide möglichen Ursachen Geld kosten: entweder ist die
      // Rechnung nie beim Kunden angekommen, oder sie geht doppelt raus.
      final a = versandvermerkAufgabe(2)!;
      expect(a.route, '/rechnungen');
      expect(a.dringend, isTrue);
      expect(a.key, 'versandvermerk');
    });
  });
}
