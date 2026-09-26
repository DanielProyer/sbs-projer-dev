import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter (Review 26.09.2026, M1/M4): Ladefehler des gespeicherten
/// Tagesplans.
///
/// M1 — `gespeicherterTagesplanProvider` ist nicht autoDispose: ein
/// einmaliger Ladefehler lag als AsyncError im Cache und kam bei JEDEM
/// `ref.read(...future)` wieder. Die Einplanen-Helfer lesen deshalb frisch,
/// und jeder Aufrufer fängt den Fehler ab — auch wenn nicht abgewartet
/// wird. Im Diktat darf ein Fehler NACH dem Speichern nicht als «Speichern
/// fehlgeschlagen» ankommen (ein zweiter Tipp legte den Einsatz doppelt an).
///
/// M4 — Die Arbeitstag-Schreiber schreiben Beginn/Ende/km IMMER. Bei einem
/// Ladefehler war der erfasste Beginn `null` — ein Tipp auf «Pause» löschte
/// ihn. Jeder Schreiber fragt deshalb zuerst `arbeitstagStandBereit`.
///
/// Das Verhalten der Regel testet `test/providers/tour_tagesplan_test.dart`
/// (`arbeitstagSchreibbereit`); hier wird festgehalten, dass alle Stellen sie
/// auch nutzen.

String _lies(String pfad) => File(pfad).readAsStringSync();

/// Quelltext ohne Zeilenkommentare — dort steht erklärt, WARUM etwas nicht
/// mehr so gemacht wird, und das darf den Wächter nicht auslösen.
String _ohneKommentare(String quelle) =>
    quelle.replaceAll(RegExp(r'//.*'), '');

/// Rumpf der Funktion, deren Kopf [kopf] enthält (Klammern gezählt).
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
  group('M1 — Einplanen-Pfade', () {
    final provider = _ohneKommentare(
      _lies('lib/presentation/providers/tour_providers.dart'),
    );

    for (final kopf in [
      'Future<void> einsatzInTagesplanAufnehmen(',
      'Future<void> einsatzAusTagesplanEntfernen(',
    ]) {
      test('$kopf liest frisch, nicht aus dem Fehler-Cache', () {
        final rumpf = _rumpf(provider, kopf);
        expect(rumpf, contains('_gespeicherteEintraegeLaden('));
        expect(
          rumpf,
          isNot(contains('gespeicherterTagesplanProvider(tagOhneZeit).future')),
          reason:
              'ref.read(...future) liefert einen gecachten Ladefehler bei '
              'jedem Aufruf wieder',
        );
      });
    }

    test('Aufgaben: jedes Umplanen läuft unter _sicherMit', () {
      final code = _ohneKommentare(
        _lies('lib/presentation/widgets/aufgaben_aktionen.dart'),
      );
      final alle = 'einsatzUmplanen('.allMatches(code).length;
      expect(alle, greaterThan(0));
      expect(
        '() => einsatzUmplanen('.allMatches(code).length,
        alle,
        reason: 'die Klasse verspricht «nie stiller Abbruch»',
      );
      expect(
        RegExp(r'_sicherMit\(\s*messenger,').allMatches(code).length,
        alle,
      );
    });

    final screen = _ohneKommentare(
      _lies('lib/presentation/screens/touren/tourenplanung_screen.dart'),
    );

    test('Tourenplan-Einplanen fängt den Fehler ab', () {
      final rumpf = _rumpf(screen, 'Future<void> _einplanen(');
      final versuch = rumpf.indexOf('try {');
      expect(versuch, greaterThanOrEqualTo(0));
      expect(rumpf.indexOf('einsatzUmplanen('), greaterThan(versuch));
      expect(rumpf, contains('} catch (e) {'));
      expect(rumpf, contains('messenger?.showSnackBar('));
    });

    test('Block-Sheet: Zurückschreiben ohne ungefangenes .then', () {
      final rumpf = _rumpf(screen, 'void _einsatzEinplanungZurueckschreiben(');
      expect(rumpf, isNot(contains('.then(')));
      expect(
        'catch (e)'.allMatches(rumpf).length,
        greaterThanOrEqualTo(2),
        reason: 'Einsatz schreiben UND alten Plan-Eintrag aufräumen',
      );
      expect(rumpf, contains('unawaited(zurueckschreiben())'));
    });

    for (final pfad in [
      'lib/presentation/screens/stoerungen/stoerung_form_screen.dart',
      'lib/presentation/screens/montagen/montage_form_screen.dart',
    ]) {
      test('${pfad.split('/').last}: Entfernen aus dem Plan abgefangen', () {
        final code = _ohneKommentare(_lies(pfad));
        final aufruf = code.indexOf('einsatzAusTagesplanEntfernen(');
        expect(aufruf, greaterThanOrEqualTo(0));
        final ende = code.indexOf(';', aufruf);
        expect(
          code.substring(aufruf, ende),
          contains('.catchError('),
          reason: 'unawaited ohne catchError: ein Ladefehler ginge unter',
        );
      });
    }

    group('Diktat', () {
      final diktat = _ohneKommentare(
        _lies('lib/presentation/widgets/diktat_sheet.dart'),
      );

      test('Tagesplan-Schritt nur im eigenen Fehlerfang', () {
        expect(
          'einsatzInTagesplanAufnehmen('.allMatches(diktat).length,
          1,
          reason: 'nur über _einplanenNachSpeichern',
        );
        final helfer = _rumpf(diktat, 'Future<String?> _einplanenNachSpeichern(');
        expect(helfer, contains('einsatzInTagesplanAufnehmen('));
        expect('catch (e)'.allMatches(helfer).length, 2);
        expect(helfer, isNot(contains('rethrow')));
      });

      test('Einplanen nach dem Speichern meldet nie «Speichern '
          'fehlgeschlagen»', () {
        final speichern = _rumpf(diktat, 'Future<void> _einsatzSpeichern(');
        // Jedes `…Repository.einplanen(` läuft als Closure durch den Helfer.
        final einplanen = RegExp(r'Repository\.einplanen\(')
            .allMatches(speichern)
            .length;
        expect(einplanen, 2, reason: 'Störung und Montage');
        expect(
          RegExp(r'einplanen: \(\) => \w+Repository\.einplanen\(')
              .allMatches(speichern)
              .length,
          einplanen,
        );
        expect(
          'hinweisNachSpeichern = await _einplanenNachSpeichern('
              .allMatches(speichern)
              .length,
          2,
        );
      });
    });
  });

  group('M4 — Arbeitstag-Schreiber prüfen zuerst den geladenen Stand', () {
    final karte = _ohneKommentare(
      _lies('lib/presentation/widgets/arbeitstag_karte.dart'),
    );

    for (final kopf in [
      'Future<void> _pause(',
      'Future<void> _startJetzt(',
      'Future<void> _feierabend(',
    ]) {
      test('Arbeitstag-Karte $kopf', () {
        final rumpf = _rumpf(karte, kopf);
        final pruefung = rumpf.indexOf('arbeitstagStandBereit(');
        expect(pruefung, greaterThanOrEqualTo(0));
        final erstesLesen = rumpf.indexOf('gespeicherterTagesplanProvider(');
        expect(erstesLesen, greaterThan(pruefung));
        final schreiben = rumpf.indexOf('_speichern(');
        expect(schreiben, greaterThan(pruefung));
      });
    }

    test('Pausen-Prüfung schreibt nur nach der Prüfung', () {
      final helfer = _ohneKommentare(
        _lies('lib/presentation/widgets/pause_pruefen_helfer.dart'),
      );
      final pruefung = helfer.indexOf('arbeitstagStandBereit(');
      expect(pruefung, greaterThanOrEqualTo(0));
      expect(helfer.indexOf('arbeitstagFelderSpeichern('), greaterThan(pruefung));
      expect(
        helfer.indexOf('.notifier).state = neu'),
        greaterThan(pruefung),
        reason: 'auch den lokalen Stand erst nach der Prüfung ändern',
      );
    });

    test('Tourenplan-Arbeitstagzeile schreibt nur nach der Prüfung', () {
      final screen = _ohneKommentare(
        _lies('lib/presentation/screens/touren/tourenplanung_screen.dart'),
      );
      final rumpf = _rumpf(screen, 'Future<void> speichern(Arbeitstag neu');
      final pruefung = rumpf.indexOf('arbeitstagStandBereit(');
      expect(pruefung, greaterThanOrEqualTo(0));
      expect(rumpf.indexOf('arbeitstagFelderSpeichern('), greaterThan(pruefung));
    });
  });
}
