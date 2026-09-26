import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter (Review 26.09.2026, D1): Lade-Fenster im Tourenplan.
///
/// Beim Tipp auf einen anderen Tag zeigt der Kopf sofort den neuen Tag, der
/// `TagesplanNotifier` hält aber bis zum Eintreffen des Plans noch den des
/// vorigen Tages. In diesem Fenster legte «Übernehmen» Einträge im Plan des
/// vorigen Tages ab, und das Verschieben liess Stopps doppelt stehen. Und
/// ein Ladefehler kam als «kein Plan» an — die nächste Änderung überschrieb
/// den echten Plan in der DB.
///
/// Die Regel selbst testet `test/providers/tour_tagesplan_test.dart`; hier
/// wird festgehalten, dass jede Plan-Aktion des Screens sie auch fragt.

/// Rumpf der Methode, deren Kopf [kopf] enthält (Klammern gezählt).
String _rumpf(String quelle, String kopf) {
  final start = quelle.indexOf(kopf);
  expect(start, greaterThanOrEqualTo(0), reason: 'nicht gefunden: $kopf');
  final auf = quelle.indexOf('{', quelle.indexOf(')', start));
  var tiefe = 0;
  for (var i = auf; i < quelle.length; i++) {
    if (quelle[i] == '{') tiefe++;
    if (quelle[i] == '}') {
      tiefe--;
      if (tiefe == 0) return quelle.substring(auf, i + 1);
    }
  }
  fail('Rumpf von $kopf nicht geschlossen');
}

void main() {
  final screen = File(
    'lib/presentation/screens/touren/tourenplanung_screen.dart',
  ).readAsStringSync();

  for (final kopf in [
    'void _faelligEintragUebernehmen(',
    'void _faelligeAlleUebernehmen(',
    'void _reihenfolgeOptimieren(',
    'Future<void> _planVonDatumUebernehmen(',
    'Future<void> _tagesplanLeeren(',
    'Future<void> _stoppVerschieben(',
    'Future<void> _ganzenTagVerschieben(',
  ]) {
    test('$kopf fragt zuerst, ob der Plan dem Tag gehört', () {
      expect(_rumpf(screen, kopf), contains('if (!_planBereit()) return;'));
    });
  }

  // Nach Dialogen bzw. Wartezeiten kann der Tag gewechselt haben.
  for (final kopf in [
    'Future<void> _planVonDatumUebernehmen(',
    'Future<void> _tagesplanLeeren(',
    'Future<void> _stoppVerschieben(',
    'Future<void> _ganzenTagVerschieben(',
  ]) {
    test('$kopf prüft nach den Dialogen erneut', () {
      // Das Verschieben selbst ist das letzte `await` — es läuft unter der
      // Sperre und zählt hier nicht als Dialog.
      final rumpf = _rumpf(
        screen,
        kopf,
      ).replaceAll('await _aufTagVerschieben(', '_aufTagVerschieben(');
      expect(rumpf, contains('_planNochAufTag(plantag)'));
      expect(
        rumpf.lastIndexOf('_planNochAufTag(plantag)'),
        greaterThan(rumpf.lastIndexOf('await ')),
        reason: 'die Prüfung gehört hinter den letzten Dialog',
      );
    });
  }

  test('Saison-Termine übernehmen nur mit geladenem Plan', () {
    final start = screen.indexOf('SaisonTermineSektion(');
    expect(start, greaterThanOrEqualTo(0));
    final abschnitt = screen.substring(start, screen.indexOf('onTap:', start));
    expect(
      RegExp(r'_planBereit\(\)').allMatches(abschnitt).length,
      2,
      reason: 'onUebernehmen und onAlleUebernehmen',
    );
  });

  test('Ladefehler wird nicht als «kein Plan» angewendet', () {
    final start = screen.indexOf('gespeichertAsync.when(');
    expect(start, greaterThanOrEqualTo(0));
    // Bis zur schliessenden Klammer des when-Aufrufs.
    final auf = screen.indexOf('(', start);
    var tiefe = 0;
    var zu = -1;
    for (var i = auf; i < screen.length; i++) {
      if (screen[i] == '(') tiefe++;
      if (screen[i] == ')') {
        tiefe--;
        if (tiefe == 0) {
          zu = i;
          break;
        }
      }
    }
    final block = screen.substring(auf, zu);
    expect(block, contains('error:'));
    final fehlerZweig = block.substring(block.indexOf('error:'));
    expect(fehlerZweig, isNot(contains('anwenden')));
    expect(fehlerZweig, isNot(contains('resetLeer')));
  });

  // K1 (Review 26.09.2026): Eine Aufgabe mit `/touren?datum=B` öffnet per
  // `router.push` eine zweite Tourenplanung; sie lädt B in den EINEN
  // globalen `tagesplanProvider`. Nach dem Zurück hielt die erste Instanz
  // `_loadedForDate == A`, lud nicht neu, und «Plan wird geladen…» blieb
  // stehen. Die Rücksetzung muss VOR der Lade-Prüfung stehen und darf nur
  // als oberste Route greifen (sonst Hin-und-Her zweier Instanzen).
  test('zweite Instanz: Plan wird neu übernommen, wenn er nicht zum Tag '
      'gehört', () {
    final zustand = screen.substring(
      screen.indexOf('class _TourenplanungScreenState'),
    );
    final build = _rumpf(zustand, 'Widget build(BuildContext context)');
    final ruecksetzung = build.indexOf('isCurrent');
    final pruefung = build.indexOf('if (_loadedForDate != _selectedDate)');
    expect(ruecksetzung, greaterThanOrEqualTo(0),
        reason: 'Rücksetzung mit ModalRoute…isCurrent fehlt');
    expect(pruefung, greaterThan(ruecksetzung),
        reason: 'die Rücksetzung gehört VOR die Lade-Prüfung');

    final zeile = build.substring(
      build.lastIndexOf('\n', ruecksetzung),
      build.indexOf('\n', ruecksetzung),
    );
    expect(zeile, contains('!aufTag'));
    expect(zeile, contains('ModalRoute.of(context)'));
    expect(
      build.substring(ruecksetzung, pruefung),
      contains('_loadedForDate = null'),
    );
    expect(
      build.substring(0, ruecksetzung),
      contains('.gehoertZu(_selectedDate)'),
    );
  });

  // M3 (Review 26.09.2026): `Duration(days: 7)` sind über die Zeitumstellung
  // 167/169 Stunden — «Nächste Woche» ab Mo 19.10.2026 landete auf
  // So 25.10. 23:00. Die Regel selbst testet `kalenderwoche_test.dart`.
  test('Wochenrechnung in Kalendertagen, gewählter Tag ohne Uhrzeit', () {
    final zustand = screen.substring(
      screen.indexOf('class _TourenplanungScreenState'),
    );
    expect(_rumpf(zustand, 'void _changeWeek('), contains('wochePlus('));
    expect(
      _rumpf(zustand, 'void _selectDay('),
      contains('DateTime(day.year, day.month, day.day)'),
    );
    expect(zustand, contains('_weekStart => wochenStart(_selectedDate)'));

    // Kommentare zählen nicht — dort steht, WARUM nicht so gerechnet wird.
    String ohneKommentare(String quelle) =>
        quelle.replaceAll(RegExp(r'//.*'), '');
    final code = ohneKommentare(screen);
    expect(code, isNot(contains('Duration(days: 7')));
    expect(
      RegExp(r'Duration\(days: \w+\.weekday').hasMatch(code),
      isFalse,
      reason: 'Wochenstart über wochenStart(), nicht über Stunden',
    );

    final leiste = File(
      'lib/presentation/screens/touren/widgets/wochen_leiste.dart',
    ).readAsStringSync();
    expect(ohneKommentare(leiste), isNot(contains('Duration(days')));
  });

  test('gespeicherterTagesplanProvider reicht Ladefehler weiter', () {
    final quelle = File(
      'lib/presentation/providers/tour_providers.dart',
    ).readAsStringSync();
    final start = quelle.indexOf('final gespeicherterTagesplanProvider =');
    expect(start, greaterThanOrEqualTo(0));
    final ende = quelle.indexOf('});', start);
    final rumpf = quelle.substring(start, ende);
    final fang = rumpf.substring(rumpf.indexOf('} catch (e) {'));
    expect(fang, contains('rethrow;'));
    expect(fang, isNot(contains('return null')));
  });
}
