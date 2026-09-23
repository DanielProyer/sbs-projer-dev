import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Das Mahnwesen bleibt im Testmodus, bis Daniel es bewusst scharf stellt.
///
/// WARUM ein Wächter: Scharfstellen heisst, dass echte Kunden Mahnungen
/// bekommen. Das ist ein bewusster Schritt Daniels nach ausgiebigem Test
/// (Entscheid 23.09.2026) — nicht etwas, das nebenbei in einem Commit
/// passieren darf. Wer `mahnwesenScharf` ändert, muss diesen Test bewusst
/// mit anpassen. Und solange der Testmodus gilt, muss der Mahnlauf den
/// Empfänger über `MailConfig.empfaenger(…, bereich: 'mahnwesen')`
/// bestimmen und den Betreff als TEST kennzeichnen — sonst ginge eine
/// Testmahnung an den echten Kunden.
void main() {
  test('mahnwesenScharf steht auf false', () {
    final config = File('lib/core/config/mail_config.dart').readAsStringSync();
    expect(
      RegExp(r'static const mahnwesenScharf\s*=\s*false;').hasMatch(config),
      isTrue,
      reason: 'Mahnwesen scharf gestellt? Nur nach Daniels ausdrücklicher '
          'Freigabe — dann diesen Wächter bewusst anpassen.',
    );
  });

  test('Mahnlauf: Empfänger über MailConfig (bereich mahnwesen), TEST im Betreff', () {
    final service =
        File('lib/services/rechnung/mahnlauf_service.dart').readAsStringSync();
    expect(
      RegExp(r"MailConfig\.empfaenger\([^)]*bereich:\s*'mahnwesen'")
          .hasMatch(service),
      isTrue,
      reason: 'Der Mail-Empfänger des Mahnlaufs muss über '
          "MailConfig.empfaenger(…, bereich: 'mahnwesen') laufen.",
    );
    expect(
      service.contains("'TEST an: "),
      isTrue,
      reason: 'Im Testmodus muss der Betreff mit «TEST an: <echte Adresse>» '
          'beginnen.',
    );
  });
}
