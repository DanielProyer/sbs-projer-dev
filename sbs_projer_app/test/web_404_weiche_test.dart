import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Deep-Links auf GitHub Pages.
///
/// GitHub Pages kennt nur Dateien. `/sbs-projer-dev/dokumente` ist keine, also
/// kam bis v0.99.10 die GitHub-Fehlerseite — ein Lesezeichen auf einen
/// Unterbereich war damit unmöglich.
///
/// Zwei Teile gehören zusammen, und beide sind leicht zu verlieren:
/// 404.html schreibt den Pfad auf die Hash-Route um, und der Versions-Redirect
/// in index.html muss diesen Hash behalten. Fehlt eines von beidem, landet man
/// wieder auf dem Startbildschirm — ohne Fehlermeldung, weshalb es niemandem
/// auffällt.
void main() {
  test('404.html existiert und schreibt den Pfad auf die Hash-Route um', () {
    final datei = File('web/404.html');
    expect(datei.existsSync(), isTrue,
        reason: 'web/404.html fehlt — GitHub Pages zeigt dann seine eigene '
            'Fehlerseite statt der App');

    final inhalt = datei.readAsStringSync();
    expect(inhalt, contains('/sbs-projer-dev/'),
        reason: 'Die Weiche braucht den Basispfad des Deployments');
    expect(inhalt, contains('#/'),
        reason: 'Die App führt ihre Routen im Hash (kein usePathUrlStrategy)');
    expect(inhalt, contains('location.replace'),
        reason: 'replace statt href: der 404-Umweg gehört nicht in die History');
  });

  test('Versions-Redirect in index.html behaelt den Hash', () {
    final inhalt = File('web/index.html').readAsStringSync();
    final start = inhalt.indexOf('function redirectToVersion');
    expect(start, isNot(-1), reason: 'Der Cache-Buster-Redirect fehlt');

    // Die ganze Funktion prüfen, nicht eine Zeile: der replace-Aufruf ist
    // umbrochen, und ein Zeilentest wäre schon daran zerbrochen.
    final ende = inhalt.indexOf('\n    }', start);
    final rumpf = inhalt.substring(start, ende == -1 ? inhalt.length : ende);

    expect(rumpf, contains('location.replace'));
    expect(rumpf, contains('location.hash'),
        reason: 'Ohne den Hash verschluckt der Versions-Redirect die Route: '
            'jeder Deep-Link landet auf dem Startbildschirm');
  });
}
