import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Migration 216: Jahressperre nur über eine Abschlussbuchung PER 31.12.
///
/// WARUM: `geschaeftsjahr_abgeschlossen` (209) prüfte «Abschlussbuchung mit
/// `datum <= 31.12.<jahr>`» ohne Untergrenze. Jede ältere Abschlussbuchung
/// erfüllt das — ab dem 01.01.2027 gälte 2026 durch `JA2025_D`
/// (31.12.2025), `JA2025_C2` (01.01.2026) und `JA2025_D_U1/U2` (April/Mai
/// 2026) als abgeschlossen, und `zahlung_erfassen` sperrte jede Zahlung mit
/// Geschäftsjahr 2026, bevor der Abschluss 2026 überhaupt gemacht ist.
/// App-seitig dieselbe Regel in `BuchungNachholService.nachbuchGrenze` —
/// dieser Test hält beide Hälften zusammen.
String _ohneKommentare(String sql) => sql
    .split('\n')
    .map((z) {
      final i = z.indexOf('--');
      return i < 0 ? z : z.substring(0, i);
    })
    .join('\n');

void main() {
  final sql = File(
    '../Datenbank/migrations/216_geschaeftsjahr_abgeschlossen_stichtag.sql',
  ).readAsStringSync();
  final code = _ohneKommentare(sql);

  test(
    '216 definiert geschaeftsjahr_abgeschlossen mit gleicher Signatur neu',
    () {
      expect(
        code,
        contains(
          'CREATE OR REPLACE FUNCTION geschaeftsjahr_abgeschlossen'
          '(p_user UUID, p_jahr INTEGER)',
        ),
      );
      expect(code, contains('RETURNS BOOLEAN'));
      expect(code, contains('STABLE'));
      expect(code, contains('SET search_path = public'));
    },
  );

  test('Abschlussbuchung genau per 31.12. des Jahres, keine offene '
      'Untergrenze', () {
    expect(code, contains('datum = make_date(p_jahr, 12, 31)'));
    expect(code, isNot(contains('<= make_date')));
    expect(code, contains("beleg_typ = 'abschluss'"));
  });

  test('Rest unverändert: laufendes Jahr offen, ältere als Vorjahr zu', () {
    expect(
      code,
      contains(
        'WHEN p_jahr >= EXTRACT(YEAR FROM current_date)::int THEN false',
      ),
    );
    expect(
      code,
      contains(
        'WHEN p_jahr < EXTRACT(YEAR FROM current_date)::int - 1 THEN true',
      ),
    );
  });

  test('App-Hälfte: nachbuchGrenze fragt dieselbe Regel (datum = 31.12.)', () {
    final dart = File(
      'lib/services/buchhaltung/buchung_nachhol_service.dart',
    ).readAsStringSync();
    expect(dart, contains(r".eq('datum', '$vorjahr-12-31')"));
    expect(dart, isNot(contains(r".lte('datum', '$vorjahr-12-31')")));
  });
}
