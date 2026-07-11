# Google-Kalender K2a — Kalibrier-Scan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read-only Scan des Google Kalenders, der bestehende (manuell eingetragene) Termine gegen die Betriebe matcht und eine Vorschau + Statistik zeigt — ändert nichts in Google.

**Architecture:** Neue Edge-Aktion `scan_manual` in `google-calendar-sync` liest `events.list` (paginiert, `singleEvents=true`, überspringt app-getaggte Events) und liefert rohe Events. Das Matching läuft **client-seitig** als reine, voll getestete Funktion gegen die vorhandenen Betriebs-Daten (Name + harte Ort-Bestätigung, konservativ). Ein neuer Screen zeigt die Buckets (eindeutig / mehrdeutig / kein Treffer). Kein Schreibzugriff, keine Migration (die kommt in K2b).

**Tech Stack:** Flutter (Web), Riverpod, GoRouter, Supabase Edge Function (Deno/TS), `functions.invoke`.

**Referenz-Spec:** `docs/superpowers/specs/2026-07-11-google-kalender-k2-design.md`

**Nur-Web-Nutzung.** Deploy am Ende: Edge-Function via CLI + App via gh-pages (v0.34.0).

---

### Task 1: Reine Matching-Funktion (TDD)

Kern des Feature-Risikos. Konservativ: Name (exakt oder ≤1–2 Tippfehler) **plus harte Ort-Bestätigung**; nur genau 1 gültiger Kandidat = eindeutig.

**Files:**
- Test: `sbs_projer_app/test/google_termin_match_test.dart`
- Create: `sbs_projer_app/lib/core/util/google_termin_match.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_termin_match.dart';

// Kandidaten aus den echten Kollisions-Daten
final _betriebe = <BetriebKandidat>[
  const BetriebKandidat(betriebId: 'b-cal-chur', name: 'Calanda', ort: 'Chur'),
  const BetriebKandidat(betriebId: 'b-cal-fels', name: 'Calanda', ort: 'Felsberg'),
  const BetriebKandidat(betriebId: 'b-alp-vals', name: 'Alpina', ort: 'Vals'),
  const BetriebKandidat(betriebId: 'b-alp-breil', name: 'Alpina', ort: 'Breil/Brigels'),
  const BetriebKandidat(betriebId: 'b-bernina', name: 'Bernina', ort: 'Thusis'),
  const BetriebKandidat(betriebId: 'b-bernina-bar', name: 'Bernina Bar', ort: 'Thusis'),
  const BetriebKandidat(betriebId: 'b-raetia-ilanz', name: 'Rätia', ort: 'Ilanz'),
  const BetriebKandidat(betriebId: 'b-braema', name: 'Bräma', ort: 'Davos Platz'),
];

void main() {
  test('Ort disambiguiert Namenskollision: Chur -> Calanda Chur', () {
    final m = matcheTitel('Chur - Calanda Reinigung', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-cal-chur');
  });

  test('Anderer Ort -> anderer Calanda', () {
    final m = matcheTitel('Felsberg Calanda', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-cal-fels');
  });

  test('Name ohne Ort im Titel -> kein Treffer (konservativ)', () {
    final m = matcheTitel('Calanda', _betriebe);
    expect(m.bucket, MatchBucket.keinTreffer);
  });

  test('Alpina in 4 Orten: nur Vals passt', () {
    final m = matcheTitel('Alpina Vals', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-alp-vals');
  });

  test('Ort-Slash-Normalisierung: Breil matcht Breil/Brigels', () {
    final m = matcheTitel('Breil - Alpina', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-alp-breil');
  });

  test('Gattungswort bleibt unterscheidend: "Bernina Thusis" nur Bernina', () {
    final m = matcheTitel('Bernina Thusis', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-bernina');
  });

  test('Beide Bernina im Titel -> mehrdeutig', () {
    final m = matcheTitel('Bernina Bar Thusis', _betriebe);
    expect(m.bucket, MatchBucket.mehrdeutig);
    expect(m.kandidaten.length, 2);
  });

  test('Umlaut-Faltung: Rätia Ilanz', () {
    final m = matcheTitel('Raetia Ilanz Service', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-raetia-ilanz');
  });

  test('Davos-Suffix tolerant: "Davos" matcht "Davos Platz"', () {
    final m = matcheTitel('Davos - Bräma', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-braema');
  });

  test('Tippfehler im Namen (1 Zeichen): Alpna -> Alpina', () {
    final m = matcheTitel('Vals Alpna', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-alp-vals');
  });

  test('Privater Termin -> kein Treffer', () {
    final m = matcheTitel('Zahnarzt Termin 14:00', _betriebe);
    expect(m.bucket, MatchBucket.keinTreffer);
  });

  test('normalisiereOrt: Slash/Bindestrich/Davos', () {
    expect(normalisiereOrt('Breil/Brigels'), 'breil');
    expect(normalisiereOrt('Klosters-Serneus'), 'klosters');
    expect(normalisiereOrt('Davos Platz'), 'davos');
    expect(normalisiereOrt('Disentis/Mustér'), 'disentis');
  });
}
```

- [ ] **Step 2: Test ausführen (FAIL)**

Run (Flutter im PATH): `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/google_termin_match_test.dart`
Expected: FAIL — `google_termin_match.dart` existiert nicht / Symbole unbekannt.

- [ ] **Step 3: Implementierung**

Create `sbs_projer_app/lib/core/util/google_termin_match.dart`:

```dart
/// Reine Matching-Logik für Google-Kalender K2: ordnet einen Termin-Titel
/// konservativ einem Betrieb zu (Name + harte Ort-Bestätigung).

enum MatchBucket { eindeutig, mehrdeutig, keinTreffer }

class BetriebKandidat {
  final String betriebId; // serverId
  final String name;
  final String ort;
  const BetriebKandidat({
    required this.betriebId,
    required this.name,
    required this.ort,
  });
}

class TerminMatch {
  final MatchBucket bucket;
  final BetriebKandidat? treffer; // gesetzt bei eindeutig
  final List<BetriebKandidat> kandidaten; // gültige Kandidaten (bei mehrdeutig ≥2)
  final String grund;
  const TerminMatch({
    required this.bucket,
    this.treffer,
    this.kandidaten = const [],
    required this.grund,
  });
}

/// Umlaut-/Akzent-Faltung auf ASCII-Basis.
String _falte(String s) {
  const map = {
    'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a',
    'ö': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
    'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ç': 'c', 'ñ': 'n', 'ß': 'ss',
  };
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(map[ch] ?? ch);
  }
  return b.toString();
}

/// Normalisiert beliebigen Text: falten, Satzzeichen -> Space, Whitespace-Kollaps.
String normalisiereText(String s) {
  final gefaltet = _falte(s);
  final ersetzt = gefaltet.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return ersetzt.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Ort zusätzlich: Teil vor '/' oder '-' nehmen, Davos-Suffix entfernen.
String normalisiereOrt(String s) {
  var vor = s.split('/').first.split('-').first;
  var n = normalisiereText(vor);
  if (n.startsWith('davos')) n = 'davos';
  if (n.isEmpty) n = normalisiereText(s);
  return n;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    cur[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      cur[j + 1] = [cur[j] + 1, prev[j + 1] + 1, prev[j] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = cur[j];
    }
  }
  return prev[b.length];
}

/// Kommt [needle] (normalisiert, Token-Folge) im [haystackTokens] vor — exakt
/// oder mit ≤[maxDist] Editierdistanz über ein gleitendes Fenster?
bool _enthaelt(List<String> haystackTokens, String needle, int maxDist) {
  final needleTokens = needle.split(' ');
  final n = needleTokens.length;
  if (n == 0 || haystackTokens.length < n) return false;
  for (var i = 0; i + n <= haystackTokens.length; i++) {
    final fenster = haystackTokens.sublist(i, i + n).join(' ');
    if (fenster == needle) return true;
    if (_levenshtein(fenster, needle) <= maxDist) return true;
  }
  return false;
}

int _maxTippfehler(String normName) => normName.replaceAll(' ', '').length <= 6 ? 1 : 2;

/// Matcht einen Titel gegen die Betriebe. Konservativ:
/// Name (exakt/≤Tippfehler) UND Ort (exakt/≤1) müssen im Titel stehen.
TerminMatch matcheTitel(String titel, List<BetriebKandidat> betriebe) {
  final normTitel = normalisiereText(titel);
  if (normTitel.isEmpty) {
    return const TerminMatch(bucket: MatchBucket.keinTreffer, grund: 'Leerer Titel');
  }
  final titelTokens = normTitel.split(' ');
  final gueltig = <BetriebKandidat>[];
  for (final b in betriebe) {
    final normName = normalisiereText(b.name);
    if (normName.isEmpty) continue;
    if (!_enthaelt(titelTokens, normName, _maxTippfehler(normName))) continue;
    final normOrt = normalisiereOrt(b.ort);
    if (normOrt.isEmpty) continue;
    if (!_enthaelt(titelTokens, normOrt, 1)) continue;
    gueltig.add(b);
  }
  if (gueltig.isEmpty) {
    return const TerminMatch(
        bucket: MatchBucket.keinTreffer, grund: 'Kein Betrieb mit Name + Ort erkannt');
  }
  if (gueltig.length == 1) {
    return TerminMatch(
        bucket: MatchBucket.eindeutig,
        treffer: gueltig.first,
        kandidaten: gueltig,
        grund: 'Name + Ort eindeutig');
  }
  return TerminMatch(
      bucket: MatchBucket.mehrdeutig,
      kandidaten: gueltig,
      grund: '${gueltig.length} mögliche Betriebe');
}
```

- [ ] **Step 4: Test ausführen (PASS)**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/google_termin_match_test.dart`
Expected: alle grün.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/google_termin_match.dart sbs_projer_app/test/google_termin_match_test.dart
git commit -m "feat(gcal): reine Matching-Funktion K2 (Name+Ort konservativ, TDD)"
```

---

### Task 2: Edge-Aktion `scan_manual` (read-only) + Deploy

**Files:**
- Modify: `supabase/functions/google-calendar-sync/index.ts`

- [ ] **Step 1: Aktion + Helper einfügen**

Im Handler-Block (bei den anderen `if (action === ...)`, nach `sync_reinigungen`) ergänzen:

```ts
    if (action === "scan_manual") {
      const { time_min, time_max } = body;
      if (!time_min || !time_max) return json({ error: "missing params" }, 400);
      return json({ ok: true, ...(await scanManual(token, time_min, time_max)) });
    }
```

Am Dateiende (bei den anderen Helfern) hinzufügen:

```ts
// ── K2: bestehende Termine scannen (read-only) ─────────────────
async function scanManual(token: string, timeMin: string, timeMax: string) {
  const events: Any[] = [];
  let skippedTagged = 0;
  let pageToken: string | undefined = undefined;
  do {
    const p = new URLSearchParams({
      singleEvents: "true",
      orderBy: "startTime",
      maxResults: "250",
      timeMin,
      timeMax,
    });
    if (pageToken) p.set("pageToken", pageToken);
    const res = await gfetch(token, `${CAL}?${p.toString()}`, "GET");
    if (!res.ok) throw new Error(`events.list ${res.status}: ${await res.text()}`);
    const data = await res.json();
    for (const ev of data.items ?? []) {
      if (ev.status === "cancelled") continue;
      if (ev.extendedProperties?.private?.app === "sbs_projer") { skippedTagged++; continue; }
      events.push({
        event_id: ev.id,
        summary: ev.summary ?? "",
        start: ev.start?.date ?? ev.start?.dateTime ?? null,
        is_all_day: !!ev.start?.date,
      });
    }
    pageToken = data.nextPageToken;
  } while (pageToken);
  return { events, scanned: events.length, skipped_tagged: skippedTagged };
}
```

(Hinweis: `gfetch(token, url, "GET")` ohne Body existiert bereits; `CAL` und `Any` sind vorhanden.)

- [ ] **Step 2: Deploy**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && npx supabase functions deploy google-calendar-sync --project-ref pltbaqqwpnmdajwgnhpd
```
Expected: „Deployed Function google-calendar-sync".

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/google-calendar-sync/index.ts
git commit -m "feat(gcal): Edge-Aktion scan_manual (Kalender read-only scannen, K2a)"
```

---

### Task 3: Service-Methode `scanManuelleTermine`

**Files:**
- Modify: `sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart`

- [ ] **Step 1: Methode ergänzen**

Vor der schliessenden `}` der Klasse einfügen:

```dart
  /// K2a: Bestehende Google-Termine im Zeitraum scannen (read-only).
  /// [timeMin]/[timeMax] = RFC3339 (z.B. DateTime.toUtc().toIso8601String()).
  /// Rückgabe enthält 'events' (Liste {event_id, summary, start, is_all_day}),
  /// 'scanned', 'skipped_tagged'. Wirft bei Fehler.
  static Future<Map<String, dynamic>> scanManuelleTermine(
    String timeMin,
    String timeMax,
  ) async {
    final res = await SupabaseService.client.functions.invoke(
      'google-calendar-sync',
      body: {'action': 'scan_manual', 'time_min': timeMin, 'time_max': timeMax},
    );
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }
```

- [ ] **Step 2: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/services/google_calendar/google_calendar_sync_service.dart`
Expected: keine neuen Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart
git commit -m "feat(gcal): scanManuelleTermine im Sync-Service (K2a)"
```

---

### Task 4: Screen (read-only Vorschau) + Route + Einstellungen-Einstieg

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/google_kalender/google_termine_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart`

- [ ] **Step 1: Screen erstellen**

Read-only: Zeitraum (Default −3 bis +12 Monate), „Laden"-Button ruft `scanManuelleTermine`, matcht client-seitig gegen die Betriebe (`betriebeProvider`), gruppiert in Buckets, zeigt Statistik + Listen. Kein Taggen (kommt K2b).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/google_termin_match.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';

class GoogleTermineScreen extends ConsumerStatefulWidget {
  const GoogleTermineScreen({super.key});
  @override
  ConsumerState<GoogleTermineScreen> createState() => _GoogleTermineScreenState();
}

class _EintragVorschau {
  final String titel;
  final String? start;
  final bool ganztags;
  final TerminMatch match;
  _EintragVorschau(this.titel, this.start, this.ganztags, this.match);
}

class _GoogleTermineScreenState extends ConsumerState<GoogleTermineScreen> {
  DateTime _von = DateTime(DateTime.now().year, DateTime.now().month - 3, 1);
  DateTime _bis = DateTime(DateTime.now().year + 1, DateTime.now().month, 1);
  bool _laden = false;
  String? _fehler;
  List<_EintragVorschau>? _eintraege;
  int _skippedTagged = 0;

  Future<void> _scan() async {
    setState(() { _laden = true; _fehler = null; });
    try {
      final betriebeLocals = ref.read(betriebeProvider);
      final kandidaten = [
        for (final b in betriebeLocals)
          if ((b.serverId ?? '').isNotEmpty && (b.ort ?? '').trim().isNotEmpty)
            BetriebKandidat(betriebId: b.serverId!, name: b.name, ort: b.ort!),
      ];
      final res = await GoogleCalendarSyncService.scanManuelleTermine(
        _von.toUtc().toIso8601String(),
        _bis.toUtc().toIso8601String(),
      );
      final rawEvents = (res['events'] as List?) ?? [];
      final out = <_EintragVorschau>[];
      for (final e in rawEvents) {
        final m = e as Map;
        final titel = (m['summary'] as String?) ?? '';
        final match = matcheTitel(titel, kandidaten);
        out.add(_EintragVorschau(
            titel, m['start'] as String?, m['is_all_day'] == true, match));
      }
      out.sort((a, b) => (a.start ?? '').compareTo(b.start ?? ''));
      setState(() {
        _eintraege = out;
        _skippedTagged = (res['skipped_tagged'] as int?) ?? 0;
      });
    } catch (e) {
      setState(() => _fehler = '$e');
    } finally {
      if (mounted) setState(() => _laden = false);
    }
  }

  Future<void> _pickDatum(bool von) async {
    final d = await showDatePicker(
      context: context,
      initialDate: von ? _von : _bis,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => von ? _von = d : _bis = d);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final e = _eintraege;
    return Scaffold(
      appBar: AppBar(title: const Text('Google-Termine zuordnen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan zeigt, welche bestehenden Kalender-Termine sich einem Betrieb '
              'zuordnen lassen. Es wird noch NICHTS geändert (Taggen folgt).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _pickDatum(true),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Von: ${df.format(_von)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _pickDatum(false),
                icon: const Icon(Icons.event, size: 16),
                label: Text('Bis: ${df.format(_bis)}'))),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _laden ? null : _scan,
              icon: _laden
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_laden ? 'Scanne …' : 'Kalender scannen'),
            ),
            if (_fehler != null) ...[
              const SizedBox(height: 12),
              Text(_fehler!, style: const TextStyle(color: Colors.red)),
            ],
            if (e != null) ...[
              const SizedBox(height: 12),
              _Statistik(eintraege: e, skippedTagged: _skippedTagged),
              const SizedBox(height: 8),
              Expanded(child: _Liste(eintraege: e, df: df)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Statistik extends StatelessWidget {
  final List<_EintragVorschau> eintraege;
  final int skippedTagged;
  const _Statistik({required this.eintraege, required this.skippedTagged});
  @override
  Widget build(BuildContext context) {
    int eind = 0, mehr = 0, kein = 0;
    for (final x in eintraege) {
      switch (x.match.bucket) {
        case MatchBucket.eindeutig: eind++; break;
        case MatchBucket.mehrdeutig: mehr++; break;
        case MatchBucket.keinTreffer: kein++; break;
      }
    }
    return Wrap(spacing: 8, children: [
      Chip(label: Text('$eind eindeutig'), backgroundColor: Colors.green.shade100),
      Chip(label: Text('$mehr mehrdeutig'), backgroundColor: Colors.orange.shade100),
      Chip(label: Text('$kein ohne Treffer')),
      if (skippedTagged > 0) Chip(label: Text('$skippedTagged bereits SBS')),
    ]);
  }
}

class _Liste extends StatelessWidget {
  final List<_EintragVorschau> eintraege;
  final DateFormat df;
  const _Liste({required this.eintraege, required this.df});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: eintraege.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final x = eintraege[i];
        final m = x.match;
        final (icon, farbe, sub) = switch (m.bucket) {
          MatchBucket.eindeutig => (
              Icons.check_circle,
              Colors.green,
              '→ ${m.treffer!.name}, ${m.treffer!.ort}'),
          MatchBucket.mehrdeutig => (
              Icons.help_outline,
              Colors.orange,
              'mehrdeutig: ${m.kandidaten.map((k) => '${k.name} (${k.ort})').join(' / ')}'),
          MatchBucket.keinTreffer => (Icons.remove_circle_outline, Colors.grey, m.grund),
        };
        final datum = x.start == null
            ? ''
            : df.format(DateTime.tryParse(x.start!)?.toLocal() ?? DateTime(2000));
        return ListTile(
          dense: true,
          leading: Icon(icon, color: farbe),
          title: Text(x.titel.isEmpty ? '(ohne Titel)' : x.titel),
          subtitle: Text('$datum   $sub'),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Route registrieren**

In `router.dart` Import ergänzen:
```dart
import 'package:sbs_projer_app/presentation/screens/google_kalender/google_termine_screen.dart';
```
Und eine `GoRoute` bei den übrigen Top-Level-Routen hinzufügen:
```dart
    GoRoute(
      path: '/google-termine',
      builder: (context, state) => const GoogleTermineScreen(),
    ),
```

- [ ] **Step 3: Einstieg in Einstellungen**

In `einstellungen_screen.dart` in der Google-Kalender-Sektion (bei „Jetzt abgleichen"/`reconcile`), nur wenn verbunden, eine `ListTile` ergänzen:
```dart
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Bestehende Termine zuordnen'),
              subtitle: const Text('Google-Termine scannen und Betrieben zuordnen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/google-termine'),
            ),
```
(Falls `context.push` nicht importiert ist: `import 'package:go_router/go_router.dart';` prüfen — im Screen meist vorhanden.)

- [ ] **Step 4: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/google_kalender/ lib/core/config/router.dart lib/presentation/screens/einstellungen/einstellungen_screen.dart`
Expected: keine Errors (Info-Lints ok).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/google_kalender/ sbs_projer_app/lib/core/config/router.dart sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart
git commit -m "feat(gcal): Screen Google-Termine-Scan (read-only Vorschau, K2a)"
```

---

### Task 5: Gesamtverifikation + Deploy v0.34.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml` (Zeile 4)

- [ ] **Step 1: Volle Tests + Analyze**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test 2>&1 | tail -3 && flutter analyze 2>&1 | grep -iE "error -|google_termin|google_kalender" || echo "keine Errors"
```
Expected: alle Tests grün, keine Errors.

- [ ] **Step 2: Version bump**

`pubspec.yaml` Zeile 4: `version: 0.33.0+514` → `version: 0.34.0+515`.

- [ ] **Step 3: Web-Build**

```bash
cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none 2>&1 | tail -3
```
Expected: „√ Built build\web".

- [ ] **Step 4: Cache-Bust + Service Worker löschen**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js && echo "cache-busted $VER"
```

- [ ] **Step 5: Commit main + push**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && git add sbs_projer_app/pubspec.yaml && git commit -m "chore: Version 0.34.0+515 (Google-Kalender K2a Scan)" && git push origin main
```

- [ ] **Step 6: Deploy gh-pages**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && git checkout gh-pages && rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs && cp -r sbs_projer_app/build/web/* . && touch .nojekyll && git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/ && git commit -m "deploy v0.34.0 — Google-Kalender K2a (Termine-Scan, read-only)" && git push origin gh-pages && git checkout main
```

- [ ] **Step 7: Live-Test-Hinweis an User**

Der User öffnet Einstellungen → „Bestehende Termine zuordnen" → Zeitraum wählen → „Kalender scannen". Er prüft die Statistik + Liste (wie viele eindeutig/mehrdeutig/kein Treffer, ob die eindeutigen korrekt sind). **Dieses reale Ergebnis kalibriert K2b** (Schwellen, Normalisierung). Nichts wird verändert.

---

## Self-Review

- **Spec-Abdeckung:** K2a-Teile der Spec (scan_manual read-only, Matching Name+harte Ort-Bestätigung, Buckets, Zeitraum wählbar, Vorschau ohne Schreiben, Wiederverwendung) sind abgedeckt. K2b (Migration 133, apply_tags/untag, Häkchen-Freigabe, colorId 1) bewusst NICHT hier — kommt nach Kalibrierung.
- **Keine Platzhalter:** alle Code-Blöcke vollständig; Tippfehler-Schwelle als konkrete Funktion `_maxTippfehler`.
- **Typkonsistenz:** `BetriebKandidat`/`TerminMatch`/`MatchBucket` in Task 1 definiert und in Task 4 identisch genutzt (`matcheTitel`, `.treffer`, `.kandidaten`, `.bucket`). Service-Methode `scanManuelleTermine(timeMin,timeMax)` in Task 3 = Aufruf in Task 4. Edge liefert `events`/`scanned`/`skipped_tagged` = im Screen gelesen.
- **Verifiziert (Task 4):** `betriebeProvider` ist `Provider<List<BetriebLocal>>` (synchron, liest `betriebeStreamProvider.valueOrNull ?? []`, sortiert nach Name) — `ref.read(betriebeProvider)` liefert direkt die Liste. Ist der Stream beim ersten Scan noch leer, ist die Kandidatenliste leer → Screen zeigt „kein Treffer"; in der Praxis ist die Betriebsliste beim Öffnen der Einstellungen längst geladen.
