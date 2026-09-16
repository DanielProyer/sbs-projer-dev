import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

/// Id-Listen in `inFilter` gehen als GET-Parameter über die Leitung — jede
/// UUID rund 45 Zeichen. 200 Ids (9 KB) scheiterten im Funkloch am Berghaus
/// (16.09.2026). Die Blockgrösse steht einmal in `anfrage_bloecke.dart`;
/// wer eine Id-Liste in Blöcken abfragt, nimmt sie von dort.
void main() {
  test('Blockgroesse bleibt klein', () {
    expect(kInFilterBlock, lessThanOrEqualTo(50));
  });

  test('kein Dienst schneidet Id-Bloecke mit eigener Zahl', () {
    final treffer = <String>[];
    final muster = RegExp(r'sublist\(i, \(i \+ \d+\)');
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final k = zeilen[i].indexOf('//');
        final code = k == -1 ? zeilen[i] : zeilen[i].substring(0, k);
        if (muster.hasMatch(code)) treffer.add('${f.path}:${i + 1}');
      }
    }
    expect(
      treffer,
      isEmpty,
      reason:
          'Id-Bloecke mit fester Zahl statt kInFilterBlock:\n${treffer.join('\n')}',
    );
  });

  group('kurzeFehlermeldung', () {
    test('Netzfehler werden zu «keine Verbindung», ohne URL', () {
      final m = kurzeFehlermeldung(
        'ClientException: Failed to fetch, uri=https://x.supabase.co/rest/v1/buchungen?beleg_id=in.(a,b,c)',
      );
      expect(m, 'keine Verbindung');
    });
    test('Timeout', () {
      expect(
        kurzeFehlermeldung(Exception('TimeoutException after 0:00:20')),
        'Zeitüberschreitung',
      );
    });
    test('anderes wird auf 80 Zeichen gekuerzt', () {
      final lang = 'x' * 200;
      expect(kurzeFehlermeldung(lang).length, 81);
      expect(kurzeFehlermeldung('kurz'), 'kurz');
    });
  });
}
