import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter für `Datenbank/migrations/`: verhindert stille Nummern-Kollisionen
/// und übersehene Lücken in der Migrations-Reihenfolge.
///
/// Dateinamen tragen eine führende Nummer + optionalen Buchstaben-Suffix
/// (z. B. `209c_view_entgeltsminderung_netto.sql` → Nummer 209, Suffix 'c').
/// `setup_user_seed.sql` hat keine Nummer und wird ignoriert.
void main() {
  // Auf dem Server so geführt (Migrationen bereits angewendet) — nicht
  // umbenennen, auch wenn die Nummer doppelt ohne Suffix vergeben wurde.
  const bekannteDoppelteNummern = {83, 91, 92};

  // Bekannte Lücken in der Nummerierung — bewusst übersprungen.
  const bekannteLuecken = {8, 9};

  final migrationsOrdner = Directory('../Datenbank/migrations');

  test('Migrationsnummern: keine unbekannten Doppel, keine unbekannten Lücken', () {
    expect(
      migrationsOrdner.existsSync(),
      isTrue,
      reason: '${migrationsOrdner.path} fehlt — Pfad im Waechter anpassen',
    );

    final dateien = migrationsOrdner
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList();

    final musterMitNummer = RegExp(r'^0*(\d+)([a-z]?)_.*\.sql$');

    // nummer -> Liste von (suffix, dateiname)
    final vorkommen = <int, List<MapEntry<String, String>>>{};

    for (final f in dateien) {
      final name = f.uri.pathSegments.last;
      if (name == 'setup_user_seed.sql') continue;

      final match = musterMitNummer.firstMatch(name);
      expect(
        match,
        isNotNull,
        reason:
            '$name folgt nicht dem Muster <nummer>[buchstabe]_<name>.sql — '
            'Waechter anpassen oder Datei umbenennen.',
      );
      final nummer = int.parse(match!.group(1)!);
      final suffix = match.group(2)!;
      vorkommen.putIfAbsent(nummer, () => []).add(MapEntry(suffix, name));
    }

    // (a) keine Nummer ohne Suffix kommt doppelt vor — ausser den bekannten.
    final unerwarteteDoppel = <String>[];
    for (final eintrag in vorkommen.entries) {
      final ohneSuffix = eintrag.value.where((e) => e.key.isEmpty).toList();
      if (ohneSuffix.length > 1 &&
          !bekannteDoppelteNummern.contains(eintrag.key)) {
        unerwarteteDoppel.add(
          '${eintrag.key}: ${ohneSuffix.map((e) => e.value).join(', ')}',
        );
      }
    }
    expect(
      unerwarteteDoppel,
      isEmpty,
      reason:
          'Migrationsnummer(n) ohne Buchstaben-Suffix doppelt vergeben: '
          '${unerwarteteDoppel.join(' | ')}. Falls das serverseitig schon so '
          'angewendet wurde, in bekannteDoppelteNummern eintragen — sonst '
          'umbenennen (Buchstaben-Suffix vergeben).',
    );

    // (b) zwischen 1 und der hoechsten Nummer fehlt keine Nummer, ausser den
    // bekannten Luecken.
    final hoechsteNummer = vorkommen.keys.reduce((a, b) => a > b ? a : b);
    final fehlend = <int>[];
    for (var n = 1; n <= hoechsteNummer; n++) {
      if (!vorkommen.containsKey(n) && !bekannteLuecken.contains(n)) {
        fehlend.add(n);
      }
    }
    expect(
      fehlend,
      isEmpty,
      reason:
          'Migrationsnummer(n) fehlen zwischen 1 und $hoechsteNummer: '
          '$fehlend. Falls das eine bewusste, bekannte Luecke ist, in '
          'bekannteLuecken eintragen — sonst fehlt eine Datei.',
    );
  });
}
