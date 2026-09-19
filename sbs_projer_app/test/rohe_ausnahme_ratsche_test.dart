import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rohe Ausnahmen gehören nicht in eine Snackbar.
///
/// WARUM: Am 16.09.2026 füllte eine PostgREST-URL mit siebzig UUIDs den
/// Bildschirm, am 17.09.2026 stand «MAIL-VERSAND FEHLGESCHLAGEN:
/// ClientException: Failed to fetch, uri=…» darauf — während die Mail längst
/// beim Kunden lag. Eine geworfene Ausnahme beschreibt, was der Code sah,
/// nicht was Daniel am Tresen tun soll. Und im Mailpfad ist sie gefährlich:
/// Sie fordert zum Nachholen auf und schickt dem Kunden die Rechnung zweimal.
///
/// Der Test startete am 17.09.2026 als **Ratsche** bei 163 Fundstellen — die
/// Zahl durfte nur sinken. Am 19.09.2026 wurden alle 163 auf
/// `kurzeFehlermeldung()` umgestellt; seither steht hier eine harte Null.
///
/// Nicht erfasst und bewusst so: Listen gesammelter Fehlertexte wie
/// `${fehler.join('; ')}` (camt-Import, Abgleich-Vorschau). Das sind keine
/// gefangenen Ausnahmen, sondern eigene Meldungen — sie brauchen, wenn
/// überhaupt, eine andere Kur.
void main() {
  final funde = _funde();

  test('kein Rechnungs-/Mailpfad zeigt eine rohe Ausnahme', () {
    const hartNull = [
      'lib/presentation/screens/reinigungen/reinigung_form_screen.dart',
      'lib/presentation/screens/reinigungen/reinigung_detail_screen.dart',
      'lib/services/rechnung/reinigung_rechnung_versand.dart',
    ];
    final treffer = funde
        .where((f) => hartNull.any((p) => f.startsWith('$p:')))
        .toList();
    expect(
      treffer,
      isEmpty,
      reason:
          'Im Mailpfad gehoert `versandMeldung`/`kurzeFehlermeldung` hin '
          '(versand_meldung.dart):\n${treffer.join('\n')}',
    );
  });

  test('nirgends in lib steht eine rohe Ausnahme in einer Snackbar', () {
    expect(
      funde,
      isEmpty,
      reason:
          'Rohe Ausnahme in einer Snackbar. Bitte `kurzeFehlermeldung(e)` '
          'nutzen (core/util/anfrage_bloecke.dart) — die Rohfassung gehoert '
          'ins debugPrint, nicht auf den Bildschirm:\n${funde.join('\n')}',
    );
  });
}

/// Alle `content: Text(...)`-Aufrufe in `lib`, die eine gefangene Ausnahme
/// direkt einsetzen — als `pfad:zeile`.
List<String> _funde() {
  // `$e`, aber nicht `$erg`; dazu die uebrigen ueblichen catch-Namen.
  final muster = RegExp(r'\$\{?(e|err|ex|error)(?![A-Za-z0-9_])');
  final treffer = <String>[];
  for (final f in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final pfad = f.path.replaceAll(r'\', '/');
    final quelle = _ohneKommentare(f.readAsStringSync());
    for (final m in RegExp(r'content:\s*Text\(').allMatches(quelle)) {
      if (muster.hasMatch(_aufrufInhalt(quelle, m.end))) {
        treffer.add(
          '$pfad:${'\n'.allMatches(quelle.substring(0, m.start)).length + 1}',
        );
      }
    }
  }
  return treffer;
}

/// Ersetzt `//`-Kommentare durch Leerzeichen, ohne die Zeichenpositionen zu
/// verschieben. Zeichenketten bleiben unangetastet — sonst schnitte ein
/// `'https://…'` die halbe Zeile weg.
String _ohneKommentare(String quelle) {
  final aus = quelle.split('');
  String? anfuehrung;
  for (var i = 0; i < quelle.length; i++) {
    final c = quelle[i];
    if (anfuehrung != null) {
      if (c == r'\') {
        i++;
      } else if (c == anfuehrung) {
        anfuehrung = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      anfuehrung = c;
      continue;
    }
    if (c == '/' && i + 1 < quelle.length && quelle[i + 1] == '/') {
      while (i < quelle.length && quelle[i] != '\n') {
        aus[i] = ' ';
        i++;
      }
    }
  }
  return aus.join();
}

/// Der Inhalt eines Aufrufs ab der oeffnenden Klammer bis zur passenden
/// schliessenden. Klammern in Zeichenketten zaehlen nicht mit — sonst risse
/// ein Text wie «Reinigung (Kulanz)» die Zaehlung auseinander.
String _aufrufInhalt(String quelle, int ab) {
  var tiefe = 1;
  var i = ab;
  String? anfuehrung;
  while (i < quelle.length && tiefe > 0) {
    final c = quelle[i];
    if (anfuehrung != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == anfuehrung) anfuehrung = null;
    } else if (c == "'" || c == '"') {
      anfuehrung = c;
    } else if (c == '(') {
      tiefe++;
    } else if (c == ')') {
      tiefe--;
    }
    i++;
  }
  return quelle.substring(ab, i);
}
