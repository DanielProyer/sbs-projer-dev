import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Plan-Beginn und Ist-Beginn dürfen nicht wieder zusammenfallen.
///
/// WARUM: Bis Migration 191 trug `tagesplaene.arbeitsbeginn` zwei Bedeutungen
/// — den hypothetischen Beginn für die Zeitachse (gesetzt im Tourenplan) und
/// den tatsächlichen (gesetzt von «Jetzt starten»). Die Arbeitstag-Karte
/// konnte sie nicht auseinanderhalten:
///
///     final beginnErfasst = gespeichert?.arbeitsbeginn != null;
///
/// Ein Planwert liess den Tag dadurch als bereits begonnen erscheinen: Statt
/// «Jetzt starten» stand dort «Neu starten» und «ab 06:47», und die
/// Tages-Kilometer blieben falsch, wenn niemand den Knopf drückte. Daniel hat
/// den Unterschied am 14.09.2026 benannt: «ich brauche einen hypothetischen
/// Arbeitsbeginn für die Planung, dies ist aber nicht der tatsächliche».
///
/// Die Regel lautet seither:
/// - Die Arbeitstag-Karte liest und schreibt NUR `arbeitsbeginn`.
/// - Die Zeitachse liest `arbeitsbeginn ?? planBeginn` — der gemessene Wert
///   ist genauer als der geplante.
void main() {
  String ohneKommentare(String quelle) => quelle
      .split('\n')
      .map((z) {
        final k = z.indexOf('//');
        return k == -1 ? z : z.substring(0, k);
      })
      .join('\n');

  test('die Arbeitstag-Karte fasst den Plan-Beginn nicht an', () {
    final datei = File('lib/presentation/widgets/arbeitstag_karte.dart');
    expect(datei.existsSync(), isTrue,
        reason: 'arbeitstag_karte.dart fehlt — Pfad im Waechter anpassen');

    expect(
      ohneKommentare(datei.readAsStringSync()).contains('planBeginn'),
      isFalse,
      reason:
          'Die Arbeitstag-Karte zeigt den TATSAECHLICHEN Arbeitstag. Liest '
          'sie den Plan-Beginn mit, sieht ein blosser Planwert wieder wie ein '
          'begonnener Tag aus — genau der Fehler, den Migration 191 behoben '
          'hat (Vorfall 14.09.2026, Montagsplan 06:47 ohne km-Start).',
    );
  });

  test('die Zeitachse zieht den Ist-Beginn dem geplanten vor', () {
    final datei = File('lib/presentation/screens/touren/tourenplanung_screen.dart');
    final text = ohneKommentare(datei.readAsStringSync());

    expect(
      text.contains('?.arbeitsbeginn ?? gespeicherterTag?.planBeginn'),
      isTrue,
      reason:
          'Die Zeitachse muss zuerst den gemessenen Beginn nehmen und erst '
          'dann den geplanten. Steht dort nur einer von beiden, rechnet sie '
          'entweder mit einer Planung, obwohl der Tag laengst laeuft, oder '
          'sie verliert den geplanten Start ganz.',
    );
  });
}
