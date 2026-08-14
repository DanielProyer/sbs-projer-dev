# Anstiche & Leitungen am Event — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Erfassungswerkzeug für die Bierversorgung am Openair Gampel (17.–23.08.2026): Anstiche (Orion-Tanks, Mehrfachanstiche) und Durchlaufkühler als Geräte, nummerierte Leitungen dazwischen — Spec: `docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md`.

**Architecture:** Zwei neue Tabellen (`event_geraete`, `event_leitungen`, Migration 172) als vollständige Sync-Vertikale nach dem Muster von `event_stand_anlagen` (DTO → Isar-Local → Web-Stub → Mapper → IsarService → Repository → Sync → Provider). Die fachliche Logik (Nummernbereich, natürliche Sortierung, Stand-Hinweise) liegt als reine Funktionen in `core/util/event_technik.dart`. Neuer sechster Tab «Technik» im Event-Detail als **eigene Datei** `event_technik_tab.dart` — der Detail-Screen hat 2715 Zeilen und wächst nicht weiter.

**Tech Stack:** Flutter (CanvasKit-Web produktiv!), Supabase (PostgREST), Riverpod, Isar (nur nativ). **CanvasKit-Regel:** keine `ExpansionTile`, kritische Aktionen aus `InkWell`/`GestureDetector` + `Container` — Vorbild `_StandCard` in `event_detail_screen.dart:1327`.

**Wichtig für jeden Task:** Flutter läuft über `export PATH="$PATH:/c/flutter/bin"`, Arbeitsverzeichnis `sbs_projer_app/`. Alle Imports von Local-Models über `*_export.dart`, nie direkt (Conditional-Export-Pattern, siehe CLAUDE.md).

---

### Task 1: Migration 172 — `event_geraete` + `event_leitungen`

**Files:**
- Create: `Datenbank/migrations/172_event_geraete_leitungen.sql`

- [ ] **Step 1: SQL-Datei schreiben**

```sql
-- ============================================================
-- Migration 172: Event-Technik — Anstiche & Leitungen
-- Projekt: SBS Projer App
-- Stand: 14.08.2026
-- Anlass: Openair Gampel 17.–23.08.2026. Spec:
--   docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
-- ============================================================

-- ── event_geraete: Anstiche UND Durchlaufkühler ──
-- Beide in EINER Tabelle: es sind Geräte, an denen Leitungen hängen,
-- beide haben Standort + Inbetriebnahme.
CREATE TABLE event_geraete (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  typ text NOT NULL CHECK (typ IN (
    'orion_1000', 'orion_500', 'mehrfachanstich', 'durchlaufkuehler'
  )),
  bezeichnung text NOT NULL,
  -- nur beim Mehrfachanstich: wie viele Tanks hängen an der Leitung (1–4)
  anzahl_tanks int CHECK (anzahl_tanks BETWEEN 1 AND 4),
  standort_notiz text,
  -- Position optional, gleiche Mechanik wie event_staende (Migration 168/169).
  -- Wird in dieser Ausbaustufe nur in der DB vorgehalten (Übernahme ins
  -- Projekt Heineken), die UI setzt sie noch nicht.
  latitude double precision,
  longitude double precision,
  position_quelle text,
  position_genauigkeit text
    CHECK (position_genauigkeit IN ('genau', 'mittel', 'ungefaehr')),
  in_betrieb boolean NOT NULL DEFAULT false,
  in_betrieb_am timestamptz,
  sortierung int NOT NULL DEFAULT 0,
  notizen text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_geraete ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_geraete_user_policy ON event_geraete
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_geraete_updated_at BEFORE UPDATE ON event_geraete
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_geraete_event ON event_geraete(user_id, event_id);

-- ── event_leitungen: eine Zeile je physisch angeschriebener Leitung ──
-- nummer ist TEXT: vor Ort kann «7a» oder «B3» angeschrieben sein, und ein
-- Zahlentyp erzwingt eine Sortierung, der die Beschriftung nicht folgen muss.
-- Nummern sind eindeutig JE ANSTICH (Auskunft Daniel 14.08.), nicht eventweit.
-- stand_id/stand_anlage_id nullable: beim Erzeugen steht das Ziel noch nicht
-- fest, es wird beim Anschliessen gesetzt.
CREATE TABLE event_leitungen (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  -- redundant zur Quelle, erspart beim Laden den Join über event_geraete
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  nummer text NOT NULL,
  quelle_id uuid NOT NULL REFERENCES event_geraete(id) ON DELETE CASCADE,
  kuehler_id uuid REFERENCES event_geraete(id) ON DELETE SET NULL,
  stand_id uuid REFERENCES event_staende(id) ON DELETE SET NULL,
  stand_anlage_id uuid REFERENCES event_stand_anlagen(id) ON DELETE SET NULL,
  in_betrieb boolean NOT NULL DEFAULT false,
  in_betrieb_am timestamptz,
  sortierung int NOT NULL DEFAULT 0,
  notiz text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_leitungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_leitungen_user_policy ON event_leitungen
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_leitungen_updated_at BEFORE UPDATE ON event_leitungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_leitungen_event ON event_leitungen(user_id, event_id);
CREATE INDEX idx_event_leitungen_stand ON event_leitungen(user_id, stand_id);
CREATE UNIQUE INDEX uq_event_leitungen_quelle_nummer
  ON event_leitungen(quelle_id, nummer);

COMMENT ON TABLE event_geraete IS
  'Event-Technik: Anstiche (Orion 500/1000, Mehrfachanstich) und Durchlaufkühler. Gampel-Erfassung; Zielmodell entsteht im Projekt Heineken.';
COMMENT ON TABLE event_leitungen IS
  'Bierleitungen am Event: physisch angeschriebene Nummer (eindeutig je Anstich), Quelle, optional Kühler und Ziel-Stand.';
COMMENT ON COLUMN event_leitungen.nummer IS
  'Angeschriebene Nummer (Text, z. B. «7» oder «7a») — steht am Anstich UND am Zapfhahn.';
```

- [ ] **Step 2: Migration anwenden**

Über den Supabase-MCP-Server: `mcp__supabase__apply_migration` mit `project_id: pltbaqqwpnmdajwgnhpd`, `name: event_geraete_leitungen`, Query = Inhalt der Datei (ohne den Kommentarkopf zu kürzen).

- [ ] **Step 3: Verifizieren**

`mcp__supabase__execute_sql`:
```sql
SELECT table_name, column_name FROM information_schema.columns
WHERE table_name IN ('event_geraete','event_leitungen') ORDER BY table_name, ordinal_position;
```
Erwartet: beide Tabellen mit allen Spalten aus Step 1.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/172_event_geraete_leitungen.sql
git commit -m "feat(db): Migration 172 - event_geraete + event_leitungen (Anstiche & Leitungen, Gampel)"
```

---

### Task 2: Reine Logik `event_technik.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/event_technik.dart`
- Test: `sbs_projer_app/test/core/util/event_technik_test.dart`

- [ ] **Step 1: Failing Tests schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';

void main() {
  group('vergleicheLeitungsNummern', () {
    test('numerisch: 2 vor 10 (lexikographisch wäre 10 zuerst)', () {
      final l = ['10', '2', '1', '12'];
      l.sort(vergleicheLeitungsNummern);
      expect(l, ['1', '2', '10', '12']);
    });
    test('gemischt: Zahl vor Text, Suffix lexikographisch', () {
      final l = ['7b', '7a', 'B3', '7'];
      l.sort(vergleicheLeitungsNummern);
      expect(l, ['7', '7a', '7b', 'B3']);
    });
  });

  group('leitungsNummernBereich', () {
    test('einfacher Bereich 1–4', () {
      expect(leitungsNummernBereich(1, 4), ['1', '2', '3', '4']);
    });
    test('umgekehrte Eingabe wird getauscht', () {
      expect(leitungsNummernBereich(4, 1), ['1', '2', '3', '4']);
    });
    test('bestehende Nummern werden übersprungen', () {
      expect(
        leitungsNummernBereich(1, 4, bestehend: {'2', '3'}),
        ['1', '4'],
      );
    });
    test('alle vorhanden → leer', () {
      expect(leitungsNummernBereich(1, 2, bestehend: {'1', '2'}), isEmpty);
    });
  });

  group('leitungsHinweiseFuerStand', () {
    // «Leitungen 7, 8, 9 ← Anstich A» — Gegenrichtung in der Stand-Karte.
    final leitungen = [
      (nummer: '9', quelleId: 'g1', standId: 's1'),
      (nummer: '7', quelleId: 'g1', standId: 's1'),
      (nummer: '3', quelleId: 'g2', standId: 's1'),
      (nummer: '8', quelleId: 'g1', standId: 's2'),
      (nummer: '1', quelleId: 'g1', standId: null),
    ];
    final namen = {'g1': 'Anstich A', 'g2': 'Kühlzelt Nord'};

    test('gruppiert je Quelle, Nummern sortiert', () {
      expect(
        leitungsHinweiseFuerStand(
          standId: 's1', leitungen: leitungen, quelleNamen: namen,
        ),
        ['7, 9 ← Anstich A', '3 ← Kühlzelt Nord'],
      );
    });
    test('Stand ohne Leitungen → leer', () {
      expect(
        leitungsHinweiseFuerStand(
          standId: 's9', leitungen: leitungen, quelleNamen: namen,
        ),
        isEmpty,
      );
    });
    test('unbekannte Quelle fällt nicht um → «?»', () {
      expect(
        leitungsHinweiseFuerStand(
          standId: 's1',
          leitungen: [(nummer: '5', quelleId: 'gX', standId: 's1')],
          quelleNamen: namen,
        ),
        ['5 ← ?'],
      );
    });
  });

  group('leitungNummerPasst', () {
    test('trim + case-insensitiv', () {
      expect(leitungNummerPasst(' 7 ', '7'), isTrue);
      expect(leitungNummerPasst('b3', 'B3'), isTrue);
      expect(leitungNummerPasst('7', '17'), isFalse);
      expect(leitungNummerPasst('', '7'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss ROT sein**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/core/util/event_technik_test.dart
```
Erwartet: Compile-Fehler «event_technik.dart not found» — richtige Fehlursache.

- [ ] **Step 3: Implementierung schreiben**

```dart
// Event-Technik: Anstiche & Leitungen (reine Funktionen, testbar).
// Spec: docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
//
// Die Leitungsnummer ist die physisch angeschriebene Beschriftung — sie steht
// am Anstich UND am Zapfhahn (Auskunft Daniel 14.08.2026). Nummern sind
// eindeutig je Anstich, nicht eventweit.

/// Natürlicher Vergleich von Leitungsnummern: führender Zahlenteil numerisch,
/// Rest lexikographisch. Lexikographisch stünde «10» vor «2» — auf dem
/// Kühlzelt-Zettel steht aber 1, 2, …, 10.
int vergleicheLeitungsNummern(String a, String b) {
  final za = _fuehrendeZahl(a);
  final zb = _fuehrendeZahl(b);
  if (za != null && zb != null) {
    final cmp = za.$1.compareTo(zb.$1);
    if (cmp != 0) return cmp;
    return za.$2.compareTo(zb.$2); // Suffix («a» in «7a»)
  }
  if (za != null) return -1; // Zahlen vor reinem Text
  if (zb != null) return 1;
  return a.compareTo(b);
}

/// Führende Zahl + Rest, z. B. «7a» → (7, 'a'); null wenn kein Zahl-Anfang.
(int, String)? _fuehrendeZahl(String s) {
  final m = RegExp(r'^(\d+)(.*)$').firstMatch(s.trim());
  if (m == null) return null;
  return (int.parse(m.group(1)!), m.group(2)!);
}

/// Nummernliste für die Massenanlage «Leitungen erzeugen»: [von]–[bis]
/// einschliesslich, vertauschte Grenzen werden getauscht, bereits
/// [bestehend]e Nummern übersprungen (macht die Aktion wiederholbar, ohne
/// den Unique-Index (quelle_id, nummer) zu verletzen).
List<String> leitungsNummernBereich(
  int von,
  int bis, {
  Set<String> bestehend = const {},
}) {
  final lo = von <= bis ? von : bis;
  final hi = von <= bis ? bis : von;
  return [
    for (var n = lo; n <= hi; n++)
      if (!bestehend.contains('$n')) '$n',
  ];
}

/// Gegenrichtung für die Stand-Karte: «7, 9 ← Anstich A», eine Zeile je
/// Quelle, Nummern natürlich sortiert. Quellen in der Reihenfolge ihres
/// ersten Auftretens; unbekannte Quelle wird «?» (fällt nicht um).
List<String> leitungsHinweiseFuerStand({
  required String standId,
  required List<({String nummer, String quelleId, String? standId})> leitungen,
  required Map<String, String> quelleNamen,
}) {
  final jeQuelle = <String, List<String>>{};
  for (final l in leitungen) {
    if (l.standId != standId) continue;
    jeQuelle.putIfAbsent(l.quelleId, () => []).add(l.nummer);
  }
  return [
    for (final e in jeQuelle.entries)
      '${(e.value..sort(vergleicheLeitungsNummern)).join(', ')}'
          ' ← ${quelleNamen[e.key] ?? '?'}',
  ];
}

/// Nummernsuche: trim + case-insensitiv, exakter Treffer (kein Substring —
/// «7» darf nicht «17» finden).
bool leitungNummerPasst(String eingabe, String nummer) {
  final e = eingabe.trim().toLowerCase();
  if (e.isEmpty) return false;
  return e == nummer.trim().toLowerCase();
}
```

- [ ] **Step 4: Tests laufen lassen — GRÜN**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/core/util/event_technik_test.dart
```
Erwartet: `All tests passed!` (11 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/event_technik.dart sbs_projer_app/test/core/util/event_technik_test.dart
git commit -m "feat: Event-Technik-Logik - Nummernbereich, natuerliche Sortierung, Stand-Hinweise (TDD)"
```

---

### Task 3: DTOs `EventGeraet` + `EventLeitung` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/data/models/event_geraet.dart`
- Create: `sbs_projer_app/lib/data/models/event_leitung.dart`
- Test: `sbs_projer_app/test/event_technik_dto_test.dart`

- [ ] **Step 1: Failing Test schreiben (fromJson/toJson-Roundtrip)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

void main() {
  test('EventGeraet: fromJson liest alle Felder, toJson spiegelt sie', () {
    final json = {
      'id': 'g1',
      'user_id': 'u1',
      'event_id': 'e1',
      'typ': 'mehrfachanstich',
      'bezeichnung': 'Kühlzelt Nord',
      'anzahl_tanks': 4,
      'standort_notiz': 'hinter Bühne',
      'latitude': 46.3,
      'longitude': 7.7,
      'position_quelle': 'karte',
      'position_genauigkeit': 'mittel',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-17T10:00:00Z',
      'sortierung': 2,
      'notizen': 'CO2 separat',
      'created_at': '2026-08-14T08:00:00Z',
      'updated_at': '2026-08-14T09:00:00Z',
    };
    final g = EventGeraet.fromJson(json);
    expect(g.typ, 'mehrfachanstich');
    expect(g.anzahlTanks, 4);
    expect(g.inBetrieb, isTrue);
    final back = g.toJson();
    expect(back['event_id'], 'e1');
    expect(back['anzahl_tanks'], 4);
    expect(back['in_betrieb_am'], isNotNull);
  });

  test('EventGeraet: Defaults bei fehlenden Feldern', () {
    final g = EventGeraet.fromJson({
      'id': 'g1', 'user_id': 'u1', 'event_id': 'e1',
      'typ': 'orion_500', 'bezeichnung': 'Tank A',
    });
    expect(g.anzahlTanks, isNull);
    expect(g.inBetrieb, isFalse);
    expect(g.sortierung, 0);
  });

  test('EventGeraet: typLabel und istAnstich', () {
    expect(EventGeraet.typLabel('orion_1000'), 'Orion 1000 l');
    expect(EventGeraet.typLabel('durchlaufkuehler'), 'Durchlaufkühler');
    expect(EventGeraet.istAnstich('orion_500'), isTrue);
    expect(EventGeraet.istAnstich('durchlaufkuehler'), isFalse);
  });

  test('EventLeitung: Roundtrip inkl. Null-Zielen', () {
    final l = EventLeitung.fromJson({
      'id': 'l1', 'user_id': 'u1', 'event_id': 'e1',
      'nummer': '7', 'quelle_id': 'g1',
    });
    expect(l.kuehlerId, isNull);
    expect(l.standId, isNull);
    expect(l.standAnlageId, isNull);
    expect(l.inBetrieb, isFalse);
    final back = l.toJson();
    expect(back['nummer'], '7');
    expect(back['quelle_id'], 'g1');
    expect(back.containsKey('kuehler_id'), isTrue); // explizit null mitschicken
  });
}
```

- [ ] **Step 2: Test laufen lassen — ROT** (`flutter test test/event_technik_dto_test.dart`, Compile-Fehler: Dateien fehlen)

- [ ] **Step 3: DTOs implementieren**

`lib/data/models/event_geraet.dart`:

```dart
/// Supabase-DTO für ein Technik-Gerät am Event: Anstich (Orion-Tank,
/// Mehrfachanstich) oder Durchlaufkühler. Beide in einer Tabelle — es sind
/// Geräte, an denen Leitungen hängen, mit Standort und Inbetriebnahme.
class EventGeraet {
  final String id;
  final String userId;
  final String eventId;
  final String typ;
  final String bezeichnung;
  final int? anzahlTanks; // nur mehrfachanstich (1–4)
  final String? standortNotiz;
  final double? latitude;
  final double? longitude;
  final String? positionQuelle;
  final String? positionGenauigkeit;
  final bool inBetrieb;
  final DateTime? inBetriebAm;
  final int sortierung;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventGeraet({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.typ,
    required this.bezeichnung,
    this.anzahlTanks,
    this.standortNotiz,
    this.latitude,
    this.longitude,
    this.positionQuelle,
    this.positionGenauigkeit,
    this.inBetrieb = false,
    this.inBetriebAm,
    this.sortierung = 0,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory EventGeraet.fromJson(Map<String, dynamic> json) {
    return EventGeraet(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      typ: json['typ'],
      bezeichnung: json['bezeichnung'],
      anzahlTanks: json['anzahl_tanks'],
      standortNotiz: json['standort_notiz'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      positionQuelle: json['position_quelle'],
      positionGenauigkeit: json['position_genauigkeit'],
      inBetrieb: json['in_betrieb'] ?? false,
      inBetriebAm: json['in_betrieb_am'] != null
          ? DateTime.parse(json['in_betrieb_am'])
          : null,
      sortierung: json['sortierung'] ?? 0,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'typ': typ,
      'bezeichnung': bezeichnung,
      'anzahl_tanks': anzahlTanks,
      'standort_notiz': standortNotiz,
      'latitude': latitude,
      'longitude': longitude,
      'position_quelle': positionQuelle,
      'position_genauigkeit': positionGenauigkeit,
      'in_betrieb': inBetrieb,
      'in_betrieb_am': inBetriebAm?.toIso8601String(),
      'sortierung': sortierung,
      'notizen': notizen,
    };
  }

  static const typen = [
    'orion_1000',
    'orion_500',
    'mehrfachanstich',
    'durchlaufkuehler',
  ];

  static String typLabel(String typ) => switch (typ) {
        'orion_1000' => 'Orion 1000 l',
        'orion_500' => 'Orion 500 l',
        'mehrfachanstich' => 'Mehrfachanstich',
        'durchlaufkuehler' => 'Durchlaufkühler',
        _ => typ,
      };

  /// Anstiche speisen Leitungen, Kühler kühlen sie nur.
  static bool istAnstich(String typ) => typ != 'durchlaufkuehler';
}
```

`lib/data/models/event_leitung.dart`:

```dart
/// Supabase-DTO für eine Bierleitung am Event. `nummer` ist die physisch
/// angeschriebene Beschriftung (am Anstich UND am Zapfhahn), eindeutig je
/// Anstich. Ziel (Stand/Gerätezeile) ist nullable — es wird beim
/// Anschliessen gesetzt, nicht beim Erzeugen.
class EventLeitung {
  final String id;
  final String userId;
  final String eventId;
  final String nummer;
  final String quelleId;
  final String? kuehlerId;
  final String? standId;
  final String? standAnlageId;
  final bool inBetrieb;
  final DateTime? inBetriebAm;
  final int sortierung;
  final String? notiz;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventLeitung({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.nummer,
    required this.quelleId,
    this.kuehlerId,
    this.standId,
    this.standAnlageId,
    this.inBetrieb = false,
    this.inBetriebAm,
    this.sortierung = 0,
    this.notiz,
    this.createdAt,
    this.updatedAt,
  });

  factory EventLeitung.fromJson(Map<String, dynamic> json) {
    return EventLeitung(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      nummer: json['nummer'],
      quelleId: json['quelle_id'],
      kuehlerId: json['kuehler_id'],
      standId: json['stand_id'],
      standAnlageId: json['stand_anlage_id'],
      inBetrieb: json['in_betrieb'] ?? false,
      inBetriebAm: json['in_betrieb_am'] != null
          ? DateTime.parse(json['in_betrieb_am'])
          : null,
      sortierung: json['sortierung'] ?? 0,
      notiz: json['notiz'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'nummer': nummer,
      'quelle_id': quelleId,
      'kuehler_id': kuehlerId,
      'stand_id': standId,
      'stand_anlage_id': standAnlageId,
      'in_betrieb': inBetrieb,
      'in_betrieb_am': inBetriebAm?.toIso8601String(),
      'sortierung': sortierung,
      'notiz': notiz,
    };
  }
}
```

- [ ] **Step 4: Tests GRÜN** (`flutter test test/event_technik_dto_test.dart`)

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/data/models/event_geraet.dart sbs_projer_app/lib/data/models/event_leitung.dart sbs_projer_app/test/event_technik_dto_test.dart
git commit -m "feat: DTOs EventGeraet + EventLeitung mit Roundtrip-Tests"
```

---

### Task 4: Isar-Local-Models, Web-Stubs, Exports, IsarService

**Files:**
- Create: `sbs_projer_app/lib/data/local/event_geraet_local.dart`
- Create: `sbs_projer_app/lib/data/local/event_geraet_local_export.dart`
- Create: `sbs_projer_app/lib/data/local/web/event_geraet_local_web.dart`
- Create: `sbs_projer_app/lib/data/local/event_leitung_local.dart`
- Create: `sbs_projer_app/lib/data/local/event_leitung_local_export.dart`
- Create: `sbs_projer_app/lib/data/local/web/event_leitung_local_web.dart`
- Modify: `sbs_projer_app/lib/services/storage/isar_service.dart` (Imports oben, Schema-Liste ~Zeile 45–68, Methoden bei den Event-Methoden ~Zeile 433)
- Modify: `sbs_projer_app/lib/services/storage/isar_service_web.dart` (dynamic-Stubs)

- [ ] **Step 1: Native Isar-Modelle schreiben**

`lib/data/local/event_geraet_local.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_geraet_local.g.dart';

@collection
class EventGeraetLocal {
  Id id = Isar.autoIncrement;

  @ignore
  String get routeId => kIsWeb ? serverId! : id.toString();

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  @Index()
  late String eventId;
  late String typ;
  late String bezeichnung;
  int? anzahlTanks;
  String? standortNotiz;
  double? latitude;
  double? longitude;
  String? positionQuelle;
  String? positionGenauigkeit;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

`lib/data/local/event_leitung_local.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_leitung_local.g.dart';

@collection
class EventLeitungLocal {
  Id id = Isar.autoIncrement;

  @ignore
  String get routeId => kIsWeb ? serverId! : id.toString();

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  @Index()
  late String eventId;
  late String nummer;
  @Index()
  late String quelleId;
  String? kuehlerId;
  String? standId;
  String? standAnlageId;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

- [ ] **Step 2: Web-Stubs schreiben**

`lib/data/local/web/event_geraet_local_web.dart`:

```dart
/// Web-Stub für EventGeraetLocal (kein Isar auf Web).
class EventGeraetLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String typ = '';
  String bezeichnung = '';
  int? anzahlTanks;
  String? standortNotiz;
  double? latitude;
  double? longitude;
  String? positionQuelle;
  String? positionGenauigkeit;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

`lib/data/local/web/event_leitung_local_web.dart`:

```dart
/// Web-Stub für EventLeitungLocal (kein Isar auf Web).
class EventLeitungLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String nummer = '';
  String quelleId = '';
  String? kuehlerId;
  String? standId;
  String? standAnlageId;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

- [ ] **Step 3: Conditional Exports schreiben**

`lib/data/local/event_geraet_local_export.dart`:
```dart
export 'event_geraet_local.dart' if (dart.library.html) 'web/event_geraet_local_web.dart';
```

`lib/data/local/event_leitung_local_export.dart`:
```dart
export 'event_leitung_local.dart' if (dart.library.html) 'web/event_leitung_local_web.dart';
```

- [ ] **Step 4: build_runner laufen lassen**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && dart run build_runner build --delete-conflicting-outputs
```
Erwartet: `event_geraet_local.g.dart` und `event_leitung_local.g.dart` entstehen ohne Fehler.

- [ ] **Step 5: IsarService (nativ) erweitern**

In `lib/services/storage/isar_service.dart`:

Bei den Imports (oben, zu den anderen `event_*_local.dart`-Imports — dort wird **direkt** importiert, nicht über Export, weil diese Datei nur nativ kompiliert wird):
```dart
import 'package:sbs_projer_app/data/local/event_geraet_local.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local.dart';
```

In der Schema-Liste (nach `EventStandAnlageLocalSchema,` Zeile 67):
```dart
      EventGeraetLocalSchema,
      EventLeitungLocalSchema,
```

Bei den Event-Methoden (nach `eventStandAnlageDelete`, ~Zeile 450):
```dart
  // ─── EventGeraet ───
  static Future<List<EventGeraetLocal>> eventGeraetFindByEvent(
    String eventId,
  ) => instance.eventGeraetLocals
      .filter()
      .eventIdEqualTo(eventId)
      .sortBySortierung()
      .findAll();
  static Future<EventGeraetLocal?> eventGeraetGet(int id) =>
      instance.eventGeraetLocals.get(id);
  static Future<EventGeraetLocal?> eventGeraetFindByServerId(
    String serverId,
  ) => instance.eventGeraetLocals
      .filter()
      .serverIdEqualTo(serverId)
      .findFirst();
  static Future<void> eventGeraetPut(EventGeraetLocal g) =>
      instance.writeTxn(() => instance.eventGeraetLocals.put(g));
  static Future<void> eventGeraetDelete(int id) =>
      instance.writeTxn(() => instance.eventGeraetLocals.delete(id));

  // ─── EventLeitung ───
  static Future<List<EventLeitungLocal>> eventLeitungFindByEvent(
    String eventId,
  ) => instance.eventLeitungLocals
      .filter()
      .eventIdEqualTo(eventId)
      .sortBySortierung()
      .findAll();
  static Future<List<EventLeitungLocal>> eventLeitungFindByQuelle(
    String quelleId,
  ) => instance.eventLeitungLocals
      .filter()
      .quelleIdEqualTo(quelleId)
      .sortBySortierung()
      .findAll();
  static Future<EventLeitungLocal?> eventLeitungGet(int id) =>
      instance.eventLeitungLocals.get(id);
  static Future<EventLeitungLocal?> eventLeitungFindByServerId(
    String serverId,
  ) => instance.eventLeitungLocals
      .filter()
      .serverIdEqualTo(serverId)
      .findFirst();
  static Future<void> eventLeitungPut(EventLeitungLocal l) =>
      instance.writeTxn(() => instance.eventLeitungLocals.put(l));
  static Future<void> eventLeitungDelete(int id) =>
      instance.writeTxn(() => instance.eventLeitungLocals.delete(id));
```

- [ ] **Step 6: IsarService-Web-Stub erweitern**

In `lib/services/storage/isar_service_web.dart` (am Ende der Klasse, Stil wie die bestehenden Blöcke):
```dart
  // ─── EventGeraet ───
  static dynamic eventGeraetFindByEvent(String eventId) => throw UnsupportedError('Isar not available on web');
  static dynamic eventGeraetGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic eventGeraetFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');
  static dynamic eventGeraetPut(dynamic g) => throw UnsupportedError('Isar not available on web');
  static dynamic eventGeraetDelete(int id) => throw UnsupportedError('Isar not available on web');

  // ─── EventLeitung ───
  static dynamic eventLeitungFindByEvent(String eventId) => throw UnsupportedError('Isar not available on web');
  static dynamic eventLeitungFindByQuelle(String quelleId) => throw UnsupportedError('Isar not available on web');
  static dynamic eventLeitungGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic eventLeitungFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');
  static dynamic eventLeitungPut(dynamic l) => throw UnsupportedError('Isar not available on web');
  static dynamic eventLeitungDelete(int id) => throw UnsupportedError('Isar not available on web');
```

- [ ] **Step 7: Analyse + bestehende Tests**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze && flutter test test/event_technik_dto_test.dart test/core/util/event_technik_test.dart
```
Erwartet: keine neuen analyze-Fehler (56 vorbestehende Infos sind normal), Tests grün.

- [ ] **Step 8: Commit**

```bash
git add sbs_projer_app/lib/data/local/ sbs_projer_app/lib/services/storage/
git commit -m "feat: Isar-Modelle + Web-Stubs + IsarService fuer EventGeraet/EventLeitung"
```

---

### Task 5: Mapper (TDD)

**Files:**
- Create: `sbs_projer_app/lib/data/mappers/event_geraet_mapper.dart`
- Create: `sbs_projer_app/lib/data/mappers/event_leitung_mapper.dart`
- Test: `sbs_projer_app/test/event_technik_mapper_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/mappers/event_geraet_mapper.dart';
import 'package:sbs_projer_app/data/mappers/event_leitung_mapper.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

void main() {
  test('EventGeraetMapper: DTO -> Local -> Json Roundtrip', () {
    final dto = EventGeraet.fromJson({
      'id': 'g1', 'user_id': 'u1', 'event_id': 'e1',
      'typ': 'orion_1000', 'bezeichnung': 'Tank A',
      'anzahl_tanks': null, 'standort_notiz': 'Kühlzelt',
      'in_betrieb': true, 'in_betrieb_am': '2026-08-17T10:00:00Z',
      'sortierung': 1,
      'updated_at': '2026-08-14T09:00:00Z',
    });
    final local = EventGeraetMapper.fromDto(dto);
    expect(local.serverId, 'g1');
    expect(local.bezeichnung, 'Tank A');
    expect(local.inBetrieb, isTrue);
    expect(local.isSynced, isTrue);
    final json = EventGeraetMapper.toJson(local);
    expect(json['id'], 'g1');
    expect(json['event_id'], 'e1');
    expect(json['typ'], 'orion_1000');
    expect(json['in_betrieb'], true);
  });

  test('EventLeitungMapper: DTO -> Local -> Json Roundtrip mit Nullen', () {
    final dto = EventLeitung.fromJson({
      'id': 'l1', 'user_id': 'u1', 'event_id': 'e1',
      'nummer': '7', 'quelle_id': 'g1',
    });
    final local = EventLeitungMapper.fromDto(dto);
    expect(local.nummer, '7');
    expect(local.standId, isNull);
    final json = EventLeitungMapper.toJson(local);
    expect(json['quelle_id'], 'g1');
    expect(json['stand_id'], isNull);
    expect(json['id'], 'l1');
  });

  test('toJson ohne serverId laesst id weg (Insert-Fall)', () {
    final dto = EventLeitung.fromJson({
      'id': 'l1', 'user_id': 'u1', 'event_id': 'e1',
      'nummer': '7', 'quelle_id': 'g1',
    });
    final local = EventLeitungMapper.fromDto(dto)..serverId = null;
    expect(EventLeitungMapper.toJson(local).containsKey('id'), isFalse);
  });
}
```

- [ ] **Step 2: ROT verifizieren** (`flutter test test/event_technik_mapper_test.dart` — Compile-Fehler, Mapper fehlen)

- [ ] **Step 3: Mapper implementieren**

`lib/data/mappers/event_geraet_mapper.dart`:

```dart
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';

class EventGeraetMapper {
  static EventGeraetLocal fromDto(EventGeraet dto, {EventGeraetLocal? existing}) {
    final local = existing ?? EventGeraetLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.typ = dto.typ;
    local.bezeichnung = dto.bezeichnung;
    local.anzahlTanks = dto.anzahlTanks;
    local.standortNotiz = dto.standortNotiz;
    local.latitude = dto.latitude;
    local.longitude = dto.longitude;
    local.positionQuelle = dto.positionQuelle;
    local.positionGenauigkeit = dto.positionGenauigkeit;
    local.inBetrieb = dto.inBetrieb;
    local.inBetriebAm = dto.inBetriebAm;
    local.sortierung = dto.sortierung;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventGeraetLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'typ': local.typ,
      'bezeichnung': local.bezeichnung,
      'anzahl_tanks': local.anzahlTanks,
      'standort_notiz': local.standortNotiz,
      'latitude': local.latitude,
      'longitude': local.longitude,
      'position_quelle': local.positionQuelle,
      'position_genauigkeit': local.positionGenauigkeit,
      'in_betrieb': local.inBetrieb,
      'in_betrieb_am': local.inBetriebAm?.toIso8601String(),
      'sortierung': local.sortierung,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
```

`lib/data/mappers/event_leitung_mapper.dart`:

```dart
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

class EventLeitungMapper {
  static EventLeitungLocal fromDto(EventLeitung dto, {EventLeitungLocal? existing}) {
    final local = existing ?? EventLeitungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.nummer = dto.nummer;
    local.quelleId = dto.quelleId;
    local.kuehlerId = dto.kuehlerId;
    local.standId = dto.standId;
    local.standAnlageId = dto.standAnlageId;
    local.inBetrieb = dto.inBetrieb;
    local.inBetriebAm = dto.inBetriebAm;
    local.sortierung = dto.sortierung;
    local.notiz = dto.notiz;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventLeitungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'nummer': local.nummer,
      'quelle_id': local.quelleId,
      'kuehler_id': local.kuehlerId,
      'stand_id': local.standId,
      'stand_anlage_id': local.standAnlageId,
      'in_betrieb': local.inBetrieb,
      'in_betrieb_am': local.inBetriebAm?.toIso8601String(),
      'sortierung': local.sortierung,
      'notiz': local.notiz,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
```

- [ ] **Step 4: GRÜN** (`flutter test test/event_technik_mapper_test.dart`)

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/data/mappers/event_geraet_mapper.dart sbs_projer_app/lib/data/mappers/event_leitung_mapper.dart sbs_projer_app/test/event_technik_mapper_test.dart
git commit -m "feat: Mapper EventGeraet/EventLeitung mit Roundtrip-Tests"
```

---

### Task 6: Repositories

> **Korrektur 14.08. (Quality-Review):** Der ursprüngliche `erzeugeLeitungen`-Code
> unten hat zwei Fehler, die in der Umsetzung behoben wurden — massgebend ist der
> committete Stand, nicht dieser Block: (1) Web legt die Leitungen als EIN
> Bulk-Upsert an (atomar), nicht als n sequenzielle `save()`-Requests;
> (2) `sortierung` startet bei max+1 der bestehenden Quelle-Leitungen, nicht bei
> deren Anzahl (Kollision nach Löschungen).

**Files:**
- Create: `sbs_projer_app/lib/data/repositories/event_geraet_repository.dart`
- Create: `sbs_projer_app/lib/data/repositories/event_leitung_repository.dart`

Kein sinnvoller Unit-Test ohne Supabase/Isar-Mock — die Klasse ist reine Verdrahtung nach dem Muster `event_stand_anlage_repository.dart`; die Logik (Nummernbereich) ist bereits in Task 2 getestet.

- [ ] **Step 1: `event_geraet_repository.dart` schreiben**

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/mappers/event_geraet_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventGeraetRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventGeraetLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_geraete').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('sortierung')
          .order('id');
      return rows
          .map((r) => EventGeraetMapper.fromDto(EventGeraet.fromJson(r)))
          .toList();
    }
    return IsarService.eventGeraetFindByEvent(eventId);
  }

  static Future<void> save(EventGeraetLocal geraet) async {
    geraet.userId = _userId;
    geraet.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventGeraetMapper.toJson(geraet);
      await SupabaseService.client.from('event_geraete').upsert(json);
      return;
    }
    geraet.isSynced = false;
    geraet.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventGeraetPut(geraet);
  }

  /// Löscht das Gerät. Leitungen mit diesem Gerät als QUELLE löscht die DB
  /// per ON DELETE CASCADE mit; als KÜHLER wird die Referenz genullt.
  /// Nativ werden die lokalen Leitungs-Kopien der Quelle mit entfernt.
  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_geraete').delete().eq('id', id);
      return;
    }
    final isarId = int.parse(id);
    final local = await IsarService.eventGeraetGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_geraete').delete().eq('id', local!.serverId!);
      final leitungen = await IsarService.eventLeitungFindByQuelle(
        local.serverId!,
      );
      for (final l in leitungen) {
        await IsarService.eventLeitungDelete(l.id);
      }
    }
    await IsarService.eventGeraetDelete(isarId);
  }
}
```

- [ ] **Step 2: `event_leitung_repository.dart` schreiben**

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';
import 'package:sbs_projer_app/data/mappers/event_leitung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventLeitungRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventLeitungLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_leitungen').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('sortierung')
          .order('id');
      return rows
          .map((r) => EventLeitungMapper.fromDto(EventLeitung.fromJson(r)))
          .toList();
    }
    return IsarService.eventLeitungFindByEvent(eventId);
  }

  static Future<void> save(EventLeitungLocal leitung) async {
    leitung.userId = _userId;
    leitung.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventLeitungMapper.toJson(leitung);
      await SupabaseService.client.from('event_leitungen').upsert(json);
      return;
    }
    leitung.isSynced = false;
    leitung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventLeitungPut(leitung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_leitungen').delete().eq('id', id);
      return;
    }
    final isarId = int.parse(id);
    final local = await IsarService.eventLeitungGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_leitungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventLeitungDelete(isarId);
  }

  /// Massenanlage «Leitungen erzeugen»: legt für die Quelle die Nummern
  /// [von]–[bis] an, überspringt bereits vorhandene (Unique-Index
  /// (quelle_id, nummer) bleibt sauber, die Aktion ist wiederholbar).
  /// Liefert die Anzahl neu angelegter Leitungen.
  static Future<int> erzeugeLeitungen({
    required String eventId,
    required String quelleId,
    required int von,
    required int bis,
  }) async {
    final alle = await getByEvent(eventId);
    final bestehend = {
      for (final l in alle)
        if (l.quelleId == quelleId) l.nummer,
    };
    final neue = leitungsNummernBereich(von, bis, bestehend: bestehend);
    var sortierung = alle.where((l) => l.quelleId == quelleId).length;
    for (final nummer in neue) {
      final l = EventLeitungLocal()
        ..eventId = eventId
        ..quelleId = quelleId
        ..nummer = nummer
        ..sortierung = sortierung++;
      await save(l);
    }
    return neue.length;
  }
}
```

- [ ] **Step 3: Analyse**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze
```
Erwartet: keine neuen Fehler.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/data/repositories/event_geraet_repository.dart sbs_projer_app/lib/data/repositories/event_leitung_repository.dart
git commit -m "feat: Repositories EventGeraet/EventLeitung inkl. Massenanlage erzeugeLeitungen"
```

---

### Task 7: SyncService

**Files:**
- Modify: `sbs_projer_app/lib/services/sync/sync_service.dart`

- [ ] **Step 1: Imports ergänzen**

Zu den bestehenden Blöcken (Local ~Zeile 31, Model ~Zeile 55, Mapper ~Zeile 79 — **direkte** Imports, diese Datei ist nur nativ):
```dart
import 'package:sbs_projer_app/data/local/event_geraet_local.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';
import 'package:sbs_projer_app/data/mappers/event_geraet_mapper.dart';
import 'package:sbs_projer_app/data/mappers/event_leitung_mapper.dart';
```

- [ ] **Step 2: Tier-Registrierung**

In der `tiers`-Liste (~Zeile 148–179): `_syncEventGeraete` in **Tier 3** (→ Event, neben `_syncEventStaende`), `_syncEventLeitungen` in **Tier 4** (→ Gerät/Stand/Stand-Anlage, neben `_syncEventStandAnlagen`):

```dart
        // Tier 3: → Anlage / Event
        [
          () => _syncBierleitungen(userId),
          () => _syncReinigungen(userId),
          () => _syncStoerungen(userId),
          () => _syncMontagen(userId),
          () => _syncEventKontakte(userId),
          () => _syncEventDokumente(userId),
          () => _syncEventStaende(userId),
          () => _syncEventAufwand(userId),
          () => _syncEventGeraete(userId),
        ],
        // Tier 4: → Betrieb/Anlage/Stand
        [
          () => _syncEigenauftraege(userId),
          () => _syncEroeffnungsreinigungen(userId),
          () => _syncEventStandAnlagen(userId),
          () => _syncEventEinsaetze(userId),
        ],
        // Tier 5: → Gerät + Stand + Stand-Anlage (event_leitungen referenziert
        // event_geraete UND event_stand_anlagen — Letztere sind erst nach
        // Tier 4 vollständig)
        [
          () => _syncEventLeitungen(userId),
        ],
```

- [ ] **Step 3: Sync-Methoden schreiben** (nach `_syncEventStandAnlagen`, ~Zeile 888; exakt das dortige Muster)

```dart
  static Future<({int pushed, int pulled})> _syncEventGeraete(
    String uid,
  ) async {
    final unsynced = await _isar.eventGeraetLocals
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
    final pushed = await _pushToSupabase<EventGeraetLocal>(
      'event_geraete',
      unsynced,
      EventGeraetMapper.toJson,
      (l, id) {
        l.serverId ??= id;
        l.isSynced = true;
      },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eventGeraetLocals.putAll(pushed));
    }

    final rows = await _pullRows('event_geraete', 'event_geraete', uid);
    final toSave = <EventGeraetLocal>[];
    for (final row in rows) {
      final dto = EventGeraet.fromJson(row);
      final ex = await _isar.eventGeraetLocals
          .filter()
          .serverIdEqualTo(dto.id)
          .findFirst();
      if (ex != null &&
          !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ??
              false)) {
        continue;
      }
      toSave.add(EventGeraetMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eventGeraetLocals.putAll(toSave));
    }
    await _updateMeta('event_geraete');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncEventLeitungen(
    String uid,
  ) async {
    final unsynced = await _isar.eventLeitungLocals
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
    final pushed = await _pushToSupabase<EventLeitungLocal>(
      'event_leitungen',
      unsynced,
      EventLeitungMapper.toJson,
      (l, id) {
        l.serverId ??= id;
        l.isSynced = true;
      },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eventLeitungLocals.putAll(pushed));
    }

    final rows = await _pullRows('event_leitungen', 'event_leitungen', uid);
    final toSave = <EventLeitungLocal>[];
    for (final row in rows) {
      final dto = EventLeitung.fromJson(row);
      final ex = await _isar.eventLeitungLocals
          .filter()
          .serverIdEqualTo(dto.id)
          .findFirst();
      if (ex != null &&
          !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ??
              false)) {
        continue;
      }
      toSave.add(EventLeitungMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eventLeitungLocals.putAll(toSave));
    }
    await _updateMeta('event_leitungen');
    return (pushed: pushed.length, pulled: toSave.length);
  }
```

- [ ] **Step 4: Analyse + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze
```
```bash
git add sbs_projer_app/lib/services/sync/sync_service.dart
git commit -m "feat: Sync fuer event_geraete (Tier 3) + event_leitungen (eigenes Tier nach Stand-Anlagen)"
```

---

### Task 8: Provider

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/event_providers.dart`

- [ ] **Step 1: Provider ergänzen** (ans Dateiende; Imports oben zu den bestehenden)

Imports:
```dart
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_geraet_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_leitung_repository.dart';
```

Provider:
```dart
/// Technik-Geräte eines Event-Jahres (Anstiche + Durchlaufkühler).
final eventGeraeteProvider =
    FutureProvider.family<List<EventGeraetLocal>, String>((ref, eventId) async {
  return EventGeraetRepository.getByEvent(eventId);
});

/// Leitungen eines Event-Jahres.
final eventLeitungenProvider =
    FutureProvider.family<List<EventLeitungLocal>, String>((ref, eventId) async {
  return EventLeitungRepository.getByEvent(eventId);
});
```

- [ ] **Step 2: Analyse + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze
```
```bash
git add sbs_projer_app/lib/presentation/providers/event_providers.dart
git commit -m "feat: Provider eventGeraeteProvider + eventLeitungenProvider"
```

---

### Task 9: Technik-Tab — Gerüst + Geräte-CRUD

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/events/event_technik_tab.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/events/event_detail_screen.dart` (Zeile 67 `length: 5` → `6`; Tab-Liste Zeile 490–494; TabBarView Zeile 501–505; Import oben)

**CanvasKit-Pflicht:** kein `ExpansionTile`, Karten-Köpfe aus `InkWell` + `Row`/`Column` mit eigenem Auf/Zu-Zustand — exakt wie `_StandCard` (event_detail_screen.dart:1327 ff.). `flutter analyze` und Tests fangen Verstösse NICHT; visuelle Prüfung vor Deploy ist Pflicht (Memory «UI vor Deploy testen»).

- [ ] **Step 1: Tab-Datei mit Geräteliste + Formular-Sheet schreiben**

`lib/presentation/screens/events/event_technik_tab.dart` (vollständig):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_colors.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';
import 'package:sbs_projer_app/data/repositories/event_geraet_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_leitung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

/// Technik-Tab im Event-Detail: Anstiche (Orion, Mehrfachanstich) mit ihren
/// Leitungen, darunter die Durchlaufkühler. Erfassungswerkzeug fürs Openair
/// Gampel — Spec: docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
///
/// CanvasKit-Regel: KEIN ExpansionTile — Karten-Köpfe aus InkWell+Row mit
/// eigenem Auf/Zu-Zustand (Vorbild _StandCard, drei bestätigte Render-Vorfälle).
class EventTechnikTab extends ConsumerStatefulWidget {
  final EventLocal event;
  const EventTechnikTab({super.key, required this.event});

  @override
  ConsumerState<EventTechnikTab> createState() => _EventTechnikTabState();
}

class _EventTechnikTabState extends ConsumerState<EventTechnikTab> {
  final _suchController = TextEditingController();
  String _suche = '';

  EventLocal get event => widget.event;
  String get eventId => event.serverId!;

  @override
  void dispose() {
    _suchController.dispose();
    super.dispose();
  }

  void _neuLaden() {
    ref.invalidate(eventGeraeteProvider(eventId));
    ref.invalidate(eventLeitungenProvider(eventId));
  }

  @override
  Widget build(BuildContext context) {
    final geraete =
        ref.watch(eventGeraeteProvider(eventId)).valueOrNull ??
            <EventGeraetLocal>[];
    final leitungen =
        ref.watch(eventLeitungenProvider(eventId)).valueOrNull ??
            <EventLeitungLocal>[];
    final anstiche =
        geraete.where((g) => EventGeraet.istAnstich(g.typ)).toList();
    final kuehler =
        geraete.where((g) => !EventGeraet.istAnstich(g.typ)).toList();

    // Nummernsuche: exakte Treffer über alle Anstiche (Nummern sind nur je
    // Anstich eindeutig — bei Mehrdeutigkeit erscheinen alle Treffer).
    final treffer = _suche.trim().isEmpty
        ? <EventLeitungLocal>[]
        : leitungen.where((l) => leitungNummerPasst(_suche, l.nummer)).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Nummernsuche ──
        TextField(
          controller: _suchController,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: 'Leitungsnummer suchen …',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: _suche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _suchController.clear();
                      setState(() => _suche = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _suche = v),
        ),
        if (_suche.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          if (treffer.isEmpty)
            const Text(
              'Keine Leitung mit dieser Nummer.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            for (final l in treffer)
              _LeitungZeile(
                leitung: l,
                geraete: geraete,
                eventId: eventId,
                mitQuelle: true,
                onChanged: _neuLaden,
              ),
          const Divider(height: 24),
        ],
        const SizedBox(height: 12),

        // ── Anstiche ──
        Row(
          children: [
            const Expanded(
              child: Text(
                'Anstiche',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Anstich'),
              onPressed: () => _geraetBearbeiten(anstich: true),
            ),
          ],
        ),
        if (anstiche.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Noch keine Anstiche erfasst.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        for (final g in anstiche)
          _GeraetCard(
            geraet: g,
            geraete: geraete,
            leitungen: leitungen.where((l) => l.quelleId == g.serverId).toList(),
            eventId: eventId,
            onEdit: () => _geraetBearbeiten(geraet: g, anstich: true),
            onChanged: _neuLaden,
          ),
        const SizedBox(height: 16),

        // ── Durchlaufkühler ──
        Row(
          children: [
            const Expanded(
              child: Text(
                'Durchlaufkühler',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Kühler'),
              onPressed: () => _geraetBearbeiten(anstich: false),
            ),
          ],
        ),
        if (kuehler.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Noch keine Durchlaufkühler erfasst.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        for (final g in kuehler)
          _GeraetCard(
            geraet: g,
            geraete: geraete,
            leitungen:
                leitungen.where((l) => l.kuehlerId == g.serverId).toList(),
            eventId: eventId,
            onEdit: () => _geraetBearbeiten(geraet: g, anstich: false),
            onChanged: _neuLaden,
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  /// Formular-Sheet für Anstich oder Kühler (neu + bearbeiten).
  Future<void> _geraetBearbeiten({
    EventGeraetLocal? geraet,
    required bool anstich,
  }) async {
    final gespeichert = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GeraetFormSheet(
        eventId: eventId,
        geraet: geraet,
        anstich: anstich,
      ),
    );
    if (gespeichert == true) _neuLaden();
  }
}

// ─── Geräte-Karte (CanvasKit-sicher: InkWell + Rows, kein ExpansionTile) ───

class _GeraetCard extends ConsumerStatefulWidget {
  final EventGeraetLocal geraet;
  final List<EventGeraetLocal> geraete;
  final List<EventLeitungLocal> leitungen;
  final String eventId;
  final VoidCallback onEdit;
  final VoidCallback onChanged;

  const _GeraetCard({
    required this.geraet,
    required this.geraete,
    required this.leitungen,
    required this.eventId,
    required this.onEdit,
    required this.onChanged,
  });

  @override
  ConsumerState<_GeraetCard> createState() => _GeraetCardState();
}

class _GeraetCardState extends ConsumerState<_GeraetCard> {
  bool _offen = false;

  EventGeraetLocal get g => widget.geraet;
  bool get istAnstich => EventGeraet.istAnstich(g.typ);

  @override
  Widget build(BuildContext context) {
    final leitungen = List.of(widget.leitungen)
      ..sort((a, b) => vergleicheLeitungsNummern(a.nummer, b.nummer));
    final angeschlossen = leitungen.where((l) => l.standId != null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _offen = !_offen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    istAnstich ? Icons.propane_tank : Icons.ac_unit,
                    size: 22,
                    color: g.inBetrieb ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.bezeichnung,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            EventGeraet.typLabel(g.typ),
                            if (g.typ == 'mehrfachanstich' &&
                                g.anzahlTanks != null)
                              '${g.anzahlTanks} Tanks',
                            if ((g.standortNotiz ?? '').trim().isNotEmpty)
                              g.standortNotiz!.trim(),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (leitungen.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      istAnstich
                          ? '$angeschlossen/${leitungen.length}'
                          : '${leitungen.length}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: istAnstich && angeschlossen == leitungen.length
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    _offen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_offen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Inbetriebnahme + Verwaltung
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            g.inBetrieb = !g.inBetrieb;
                            g.inBetriebAm =
                                g.inBetrieb ? DateTime.now() : null;
                            await EventGeraetRepository.save(g);
                            widget.onChanged();
                          },
                          child: Row(
                            children: [
                              Icon(
                                g.inBetrieb
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: g.inBetrieb
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                g.inBetrieb ? 'In Betrieb' : 'Nicht in Betrieb',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (istAnstich)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.playlist_add, size: 18),
                          label: const Text('Leitungen'),
                          onPressed: () => _leitungenErzeugen(context),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _loeschen(context),
                      ),
                    ],
                  ),
                  if ((g.notizen ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        g.notizen!.trim(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  // Leitungen des Anstichs (beim Kühler: durchlaufende)
                  if (leitungen.isEmpty && istAnstich)
                    const Text(
                      'Noch keine Leitungen — über «Leitungen» erzeugen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  for (final l in leitungen)
                    _LeitungZeile(
                      leitung: l,
                      geraete: widget.geraete,
                      eventId: widget.eventId,
                      onChanged: widget.onChanged,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _leitungenErzeugen(BuildContext context) async {
    final vonC = TextEditingController(text: '1');
    final bisC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leitungen erzeugen — ${g.bezeichnung}'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: vonC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Von'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: bisC,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Bis'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erzeugen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final von = int.tryParse(vonC.text.trim());
    final bis = int.tryParse(bisC.text.trim());
    if (von == null || bis == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte Zahlen eingeben (z. B. 1 bis 12)')),
        );
      }
      return;
    }
    try {
      final n = await EventLeitungRepository.erzeugeLeitungen(
        eventId: widget.eventId,
        quelleId: g.serverId!,
        von: von,
        bis: bis,
      );
      widget.onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 0
                  ? 'Alle Nummern existieren schon'
                  : '$n Leitungen angelegt',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _loeschen(BuildContext context) async {
    final anzahl = widget.leitungen.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${istAnstich ? 'Anstich' : 'Kühler'} löschen'),
        content: Text(
          '«${g.bezeichnung}» wirklich löschen?'
          '${istAnstich && anzahl > 0 ? '\n\n$anzahl Leitungen werden mit gelöscht.' : ''}'
          '${!istAnstich && anzahl > 0 ? '\n\n$anzahl Leitungen verlieren ihre Kühler-Zuordnung.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EventGeraetRepository.delete(g.routeId);
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

// ─── Leitungs-Zeile ───

class _LeitungZeile extends ConsumerWidget {
  final EventLeitungLocal leitung;
  final List<EventGeraetLocal> geraete;
  final String eventId;
  final bool mitQuelle;
  final VoidCallback onChanged;

  const _LeitungZeile({
    required this.leitung,
    required this.geraete,
    required this.eventId,
    this.mitQuelle = false,
    required this.onChanged,
  });

  String? _geraetName(String? id) {
    if (id == null) return null;
    for (final g in geraete) {
      if (g.serverId == id) return g.bezeichnung;
    }
    return '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staende =
        ref.watch(eventStaendeProvider(eventId)).valueOrNull ?? [];
    String? standName;
    for (final s in staende) {
      if (s.serverId == leitung.standId) {
        standName = s.standnummer != null && s.standnummer!.isNotEmpty
            ? '${s.standnummer} ${s.name}'
            : s.name;
        break;
      }
    }
    final teile = <String>[
      if (mitQuelle) '${_geraetName(leitung.quelleId)}',
      standName ?? 'kein Ziel',
      if (leitung.kuehlerId != null) 'über ${_geraetName(leitung.kuehlerId)}',
      if ((leitung.notiz ?? '').trim().isNotEmpty) leitung.notiz!.trim(),
    ];

    return InkWell(
      onTap: () async {
        final gespeichert = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => _LeitungFormSheet(
            leitung: leitung,
            geraete: geraete,
            eventId: eventId,
          ),
        );
        if (gespeichert == true) onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                leitung.nummer,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                teile.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: leitung.standId == null
                      ? AppColors.textSecondary
                      : null,
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                leitung.inBetrieb = !leitung.inBetrieb;
                leitung.inBetriebAm =
                    leitung.inBetrieb ? DateTime.now() : null;
                await EventLeitungRepository.save(leitung);
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  leitung.inBetrieb
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: leitung.inBetrieb
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Geräte-Formular ───

class _GeraetFormSheet extends StatefulWidget {
  final String eventId;
  final EventGeraetLocal? geraet;
  final bool anstich;

  const _GeraetFormSheet({
    required this.eventId,
    this.geraet,
    required this.anstich,
  });

  @override
  State<_GeraetFormSheet> createState() => _GeraetFormSheetState();
}

class _GeraetFormSheetState extends State<_GeraetFormSheet> {
  late String _typ;
  late final TextEditingController _bezeichnung;
  late final TextEditingController _standort;
  late final TextEditingController _notizen;
  int _anzahlTanks = 1;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    final g = widget.geraet;
    _typ = g?.typ ?? (widget.anstich ? 'orion_1000' : 'durchlaufkuehler');
    _bezeichnung = TextEditingController(text: g?.bezeichnung ?? '');
    _standort = TextEditingController(text: g?.standortNotiz ?? '');
    _notizen = TextEditingController(text: g?.notizen ?? '');
    _anzahlTanks = g?.anzahlTanks ?? 1;
  }

  @override
  void dispose() {
    _bezeichnung.dispose();
    _standort.dispose();
    _notizen.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_speichert) return; // Doppeltipp-Riegel vor dem ersten await
    final bezeichnung = _bezeichnung.text.trim();
    if (bezeichnung.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bezeichnung fehlt')),
      );
      return;
    }
    setState(() => _speichert = true);
    try {
      final g = widget.geraet ?? EventGeraetLocal();
      g
        ..eventId = widget.eventId
        ..typ = _typ
        ..bezeichnung = bezeichnung
        ..anzahlTanks = _typ == 'mehrfachanstich' ? _anzahlTanks : null
        ..standortNotiz =
            _standort.text.trim().isEmpty ? null : _standort.text.trim()
        ..notizen = _notizen.text.trim().isEmpty ? null : _notizen.text.trim();
      await EventGeraetRepository.save(g);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typen = widget.anstich
        ? EventGeraet.typen.where(EventGeraet.istAnstich).toList()
        : ['durchlaufkuehler'];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.geraet == null
                ? (widget.anstich ? 'Neuer Anstich' : 'Neuer Kühler')
                : 'Bearbeiten',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (typen.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _typ,
              decoration: const InputDecoration(labelText: 'Typ'),
              items: [
                for (final t in typen)
                  DropdownMenuItem(
                    value: t,
                    child: Text(EventGeraet.typLabel(t)),
                  ),
              ],
              onChanged: (v) => setState(() => _typ = v ?? _typ),
            ),
          if (_typ == 'mehrfachanstich') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _anzahlTanks,
              decoration: const InputDecoration(labelText: 'Anzahl Tanks'),
              items: [
                for (var n = 1; n <= 4; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (v) => setState(() => _anzahlTanks = v ?? 1),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _bezeichnung,
            autofocus: widget.geraet == null,
            decoration: const InputDecoration(
              labelText: 'Bezeichnung *',
              hintText: 'z. B. Anstich A, Kühlzelt Nord',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _standort,
            decoration: const InputDecoration(
              labelText: 'Standort',
              hintText: 'z. B. Kühlzelt hinter Hauptbühne',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notizen,
            decoration: const InputDecoration(labelText: 'Notizen'),
          ),
          const SizedBox(height: 16),
          // CanvasKit-sicherer Speichern-Knopf (kein FilledButton — der war
          // am 13.08. im Lageplan-Screen klick-tot).
          InkWell(
            onTap: _speichert ? null : _speichern,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _speichert ? 'Speichert …' : 'Speichern',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leitungs-Formular ───

class _LeitungFormSheet extends ConsumerStatefulWidget {
  final EventLeitungLocal leitung;
  final List<EventGeraetLocal> geraete;
  final String eventId;

  const _LeitungFormSheet({
    required this.leitung,
    required this.geraete,
    required this.eventId,
  });

  @override
  ConsumerState<_LeitungFormSheet> createState() => _LeitungFormSheetState();
}

class _LeitungFormSheetState extends ConsumerState<_LeitungFormSheet> {
  late String? _standId;
  late String? _standAnlageId;
  late String? _kuehlerId;
  late final TextEditingController _notiz;
  bool _speichert = false;

  EventLeitungLocal get l => widget.leitung;

  @override
  void initState() {
    super.initState();
    _standId = l.standId;
    _standAnlageId = l.standAnlageId;
    _kuehlerId = l.kuehlerId;
    _notiz = TextEditingController(text: l.notiz ?? '');
  }

  @override
  void dispose() {
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_speichert) return;
    setState(() => _speichert = true);
    try {
      l
        ..standId = _standId
        ..standAnlageId = _standAnlageId
        ..kuehlerId = _kuehlerId
        ..notiz = _notiz.text.trim().isEmpty ? null : _notiz.text.trim();
      await EventLeitungRepository.save(l);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _loeschen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leitung löschen'),
        content: Text('Leitung ${l.nummer} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EventLeitungRepository.delete(l.routeId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staende =
        ref.watch(eventStaendeProvider(widget.eventId)).valueOrNull ?? [];
    final kuehler = widget.geraete
        .where((g) => !EventGeraet.istAnstich(g.typ))
        .toList();
    // Gerätezeilen des gewählten Stands (abhängiges Dropdown).
    final anlagen = _standId == null
        ? <EventStandAnlageLocal>[]
        : (ref.watch(eventStandAnlagenProvider(_standId!)).valueOrNull ??
            <EventStandAnlageLocal>[]);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Leitung ${l.nummer}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: _loeschen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _standId,
            decoration: const InputDecoration(labelText: 'Ziel-Stand'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— kein Ziel —')),
              for (final s in staende)
                if (s.serverId != null)
                  DropdownMenuItem(
                    value: s.serverId,
                    child: Text(
                      s.standnummer != null && s.standnummer!.isNotEmpty
                          ? '${s.standnummer} ${s.name}'
                          : s.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: (v) => setState(() {
              _standId = v;
              _standAnlageId = null; // Gerätezeile hängt am Stand
            }),
          ),
          if (anlagen.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _standAnlageId,
              decoration: const InputDecoration(labelText: 'Gerät am Stand'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('— nicht zugeordnet —'),
                ),
                for (final a in anlagen)
                  if (a.serverId != null)
                    DropdownMenuItem(
                      value: a.serverId,
                      child: Text(
                        '${EventStandAnlage.typKurz(a.typ)}'
                        '${a.anzahl > 1 ? ' (${a.anzahl}×)' : ''}',
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => _standAnlageId = v),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _kuehlerId,
            decoration: const InputDecoration(
              labelText: 'Begleitkühlung (Durchlaufkühler)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— ohne —')),
              for (final k in kuehler)
                if (k.serverId != null)
                  DropdownMenuItem(
                    value: k.serverId,
                    child: Text(k.bezeichnung),
                  ),
            ],
            onChanged: (v) => setState(() => _kuehlerId = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notiz,
            decoration: const InputDecoration(labelText: 'Notiz'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _speichert ? null : _speichern,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _speichert ? 'Speichert …' : 'Speichern',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Tab im Detail-Screen einhängen**

In `event_detail_screen.dart`:
1. Import oben: `import 'package:sbs_projer_app/presentation/screens/events/event_technik_tab.dart';`
2. Zeile 67: `_tabController = TabController(length: 6, vsync: this);`
3. Tab-Liste (Zeile 490–494), nach `Tab(text: 'Stände'),`:
```dart
                  Tab(text: 'Technik'),
```
4. TabBarView (Zeile 501–505), nach `_StaendeTab(event: event),`:
```dart
                    EventTechnikTab(event: event),
```
(Reihenfolge Tab-Liste und TabBarView muss identisch sein: Kontakte | Stände | Technik | Einsätze | Zeit | Dokumente.)

- [ ] **Step 3: Analyse + volle Testsuite**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze && flutter test
```
Erwartet: keine neuen analyze-Fehler, alle Tests grün (Stand vor diesem Plan: 1097).

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/events/
git commit -m "feat: Technik-Tab - Anstiche/Kuehler-CRUD, Leitungen erzeugen/bearbeiten/abhaken, Nummernsuche"
```

---

### Task 10: Gegenrichtung in der Stand-Karte

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/events/event_detail_screen.dart` (`_StandCardState.build`, aufgeklappter Bereich ab Zeile 1432)

- [ ] **Step 1: Import + Hinweis-Zeilen ergänzen**

Imports oben ergänzen (falls nicht schon durch Task 9 vorhanden):
```dart
import 'package:sbs_projer_app/core/util/event_technik.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
```

In `_StandCardState.build`, direkt nach der `standKontakte`-Berechnung (~Zeile 1296), die Hinweise bauen:
```dart
    // Gegenrichtung der Event-Technik: «7, 9 ← Anstich A» — der Pikett-Anruf
    // nennt den Stand, nicht die Leitung (Spec Anstiche & Leitungen 14.08.).
    final geraete =
        ref.watch(eventGeraeteProvider(stand.eventId)).valueOrNull ??
            <EventGeraetLocal>[];
    final alleLeitungen =
        ref.watch(eventLeitungenProvider(stand.eventId)).valueOrNull ??
            <EventLeitungLocal>[];
    final leitungsHinweise = stand.serverId == null
        ? const <String>[]
        : leitungsHinweiseFuerStand(
            standId: stand.serverId!,
            leitungen: [
              for (final l in alleLeitungen)
                (nummer: l.nummer, quelleId: l.quelleId, standId: l.standId),
            ],
            quelleNamen: {
              for (final g in geraete)
                if (g.serverId != null) g.serverId!: g.bezeichnung,
            },
          );
```

Im **aufgeklappten Bereich** (`if (_offen) …`, Zeile 1432 ff.), nach dem `kontaktText`-Block (~Zeile 1492) einfügen:
```dart
                  if (leitungsHinweise.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              leitungsHinweise.join('\n'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
```

- [ ] **Step 2: Analyse + volle Testsuite**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/events/event_detail_screen.dart
git commit -m "feat: Stand-Karte zeigt Leitungen mit Quelle (Gegenrichtung Technik)"
```

---

### Task 11: Version, Deploy, visuelle Prüfung

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml` (Zeile 4)
- Modify: `sbs_projer_app/lib/core/app_version.dart`

- [ ] **Step 1: Version bumpen — BEIDE Stellen**

`pubspec.yaml` Zeile 4: `version: 0.86.0+696` → `version: 0.87.0+697`
`lib/core/app_version.dart`: `const String kAppVersion = '0.86.0';` → `'0.87.0'`

- [ ] **Step 2: Wächter-Test + volle Suite**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test
```
Erwartet: alle grün, insbesondere `app_version_test.dart`, `canvaskit_sichere_widgets_test.dart`, `pagination_stabil_test.dart`.

- [ ] **Step 3: Committen + pushen (VOR dem Deploy — nie stash!)**

```bash
git add -A && git commit -m "chore: v0.87.0 - Event-Technik (Anstiche & Leitungen) fuer Gampel" && git push origin main
```

- [ ] **Step 4: Build + Cache-Bust + Deploy** (exakt die CLAUDE.md-Sequenz)

```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
```
```bash
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
```
```bash
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.87.0 — Event-Technik: Anstiche & Leitungen (Gampel)"
git push origin gh-pages
git checkout main
```

- [ ] **Step 5: Visuelle Prüfung im Browser (Pflicht — Memory «UI vor Deploy testen»)**

Live-App öffnen (`https://danielproyer.github.io/sbs-projer-dev/`), Version 0.87.0 auf der Startseite verifizieren, dann: Events → Openair Gampel → Tab «Technik» → Anstich anlegen → «Leitungen» 1–12 erzeugen → eine Leitung öffnen, Ziel setzen → Haken toggeln. Screenshot der Geräteliste machen. **CanvasKit-Renderfehler sind hier die Hauptgefahr — sichtbar nur im Browser, nie in Tests.**

- [ ] **Step 6: Klicktest Daniel + ToDo.md**

In `ToDo.md` einen Abschnitt «ERLEDIGT 14./15.08. (v0.87.0): Event-Technik Anstiche & Leitungen» mit offenem Klicktest-Punkt für Daniel anlegen (Muster: bestehende Einträge). Daniel testet am Handy vor dem Gampel-Aufbau (17.08.).

---

## Offene Punkte ausserhalb dieses Plans

- **Stände für Gampel erfassen** (aktuell 0, kein Vorjahr) — Datenarbeit durch Daniel, kein Code.
- Position der Geräte auf der Karte, Materiallisten, PDF — bewusst Projekt Heineken (Spec, «Nicht-Ziele»).
