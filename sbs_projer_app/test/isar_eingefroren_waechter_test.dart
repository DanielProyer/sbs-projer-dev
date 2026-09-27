import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Isar eingefroren seit 27.09.2026 (Entscheid Daniel) — Ratsche.
//
// WARUM: Die Offline-Android-App kommt aus der v2 (Heineken-Projekt); diese
// App läuft nur im Browser, ihr nativer Zweig wird nie ausgeführt. Der
// bestehende Isar-Code bleibt und muss kompilieren, wird aber nicht mehr
// ausgebaut (CLAUDE.md «Isar eingefroren»). Neue Entities und Repositories
// entstehen nur Web/Supabase — das verbietet dieser Test ausdrücklich NICHT:
// Er prüft nur, dass der native Zweig nicht wächst.
//
// Es gab vorher keinen Wächter, der die drei Dateien je Entity
// (`*_local.dart`, `*_local_export.dart`, `web/*_local_web.dart`) oder
// `IsarService`-Methoden erzwang — die Pflicht stand nur in der
// CLAUDE.md-Checkliste und ist dort entfallen.
//
// Schlägt der Test an, weil ein Isar-Model oder eine `IsarService`-Methode
// dazukam: die neue Entity nur Web bauen (DTO + Repository + Provider).
// Fällt ein Eintrag weg, die Liste bzw. Zahl hier mit nachziehen.

/// Stand beim Einfrieren (27.09.2026): 28 Isar-Collections.
const Set<String> kEingefroreneIsarModels = {
  'anlage_local.dart',
  'bergkundenpauschale_local.dart',
  'betrieb_ferien_local.dart',
  'betrieb_kontakt_local.dart',
  'betrieb_local.dart',
  'betrieb_rechnungsadresse_local.dart',
  'bierleitung_local.dart',
  'eigenauftrag_local.dart',
  'eroeffnungsreinigung_local.dart',
  'event_aufwand_local.dart',
  'event_dokument_local.dart',
  'event_einsatz_local.dart',
  'event_geraet_local.dart',
  'event_kontakt_local.dart',
  'event_kuehler_messung_local.dart',
  'event_leitung_local.dart',
  'event_local.dart',
  'event_stand_anlage_local.dart',
  'event_stand_local.dart',
  'kontakt_local.dart',
  'lager_local.dart',
  'montage_local.dart',
  'pikett_dienst_local.dart',
  'preis_local.dart',
  'region_local.dart',
  'reinigung_local.dart',
  'stoerung_local.dart',
  'sync_meta_local.dart',
};

/// `static`-Deklarationen in `isar_service.dart` — Stand 27.09.2026.
/// Ratsche: darf nur sinken.
const kMaxIsarServiceStatics = 172;

void main() {
  test('kein neues Isar-Model in data/local/ (Isar eingefroren)', () {
    final dateien = Directory('lib/data/local')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where(
          (n) =>
              n.endsWith('_local.dart') &&
              !n.endsWith('.g.dart') &&
              !n.endsWith('_export.dart'),
        )
        .toSet();

    final neu = dateien.difference(kEingefroreneIsarModels);
    expect(
      neu,
      isEmpty,
      reason:
          'Isar ist seit 27.09.2026 eingefroren — neue Entities nur Web/'
          'Supabase (DTO + Repository + Provider), kein Isar-Model: $neu',
    );
  });

  test('IsarService wächst nicht (Isar eingefroren)', () {
    final text = File(
      'lib/services/storage/isar_service.dart',
    ).readAsStringSync();
    final anzahl = RegExp(
      r'^\s*static\s',
      multiLine: true,
    ).allMatches(text).length;

    expect(
      anzahl,
      lessThanOrEqualTo(kMaxIsarServiceStatics),
      reason:
          'Isar ist seit 27.09.2026 eingefroren — keine neuen '
          'IsarService-Methoden; der Web-Zweig des Repositories genügt. '
          'Gezählt: $anzahl, erlaubt: $kMaxIsarServiceStatics.',
    );
  });
}
