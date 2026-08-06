import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/app_version.dart';

// `kAppVersion` ist die Version, die die App im Bildschirm ANZEIGT; sie ist
// einkompiliert und sagt damit, welches Bundle wirklich laeuft. `pubspec.yaml`
// steuert dagegen `version.json` auf dem Server.
//
// Laufen die beiden auseinander, zeigt die App eine falsche Nummer — und
// genau daran haengt die Frage «ist mein Fix ueberhaupt angekommen?».
// Am 06.08.2026 stand die Konstante drei Auslieferungen zurueck (0.71.0 statt
// 0.72.2), weil sie beim Bump vergessen wurde. Dieser Test macht das unmoeglich:
// die Suite laeuft vor jedem Deploy.

void main() {
  test('kAppVersion stimmt mit der Version in pubspec.yaml ueberein', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final treffer = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(treffer, isNotNull, reason: 'Keine version-Zeile in pubspec.yaml');
    expect(
      kAppVersion,
      treffer!.group(1),
      reason:
          'kAppVersion in lib/core/app_version.dart muss beim Bump von '
          'pubspec.yaml mitgezogen werden — sonst zeigt die App eine falsche '
          'Version an und man weiss nicht, welcher Stand laeuft.',
    );
  });
}
