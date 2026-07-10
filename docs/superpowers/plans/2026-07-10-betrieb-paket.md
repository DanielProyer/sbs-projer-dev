# Betrieb-Paket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drei Betrieb-Bausteine bauen: (A) Stammdaten per Google Places anreichern, (B) rein kundenbezogene Felder nur für eigene Kunden zeigen, (C) Betriebe-Karte mit Fälligkeits-Farbcodierung, (D) „Route in Google Maps"-Button.

**Architecture:** Flutter + Supabase + Riverpod (kIsWeb-Branching, Web = Supabase-Direktzugriff). Google-Key bleibt in einer Supabase-Edge-Function (`--no-verify-jwt`, Secret `GOOGLE_PLACES_KEY`); die Edge-Function ist ein dünner authentifizierter Proxy, die Normalisierung des Google-Resultats passiert in einer **reinen, getesteten Dart-Funktion** (Web-Bundle ist öffentlich → Key nie im Client). Die Karte nutzt das aus E3 vorhandene `flutter_map` + swisstopo-Luftbild und die bestehende Fälligkeitslogik (`FaelligkeitsStatus` + `getFaelligkeit`) aus `tour_providers.dart`.

**Tech Stack:** Dart/Flutter, flutter_map ^8.3.1, latlong2, url_launcher, Supabase Edge Functions (Deno/TS), Google Places API (New) `places:searchText`.

**Referenz-Spec:** `docs/superpowers/specs/2026-07-10-betrieb-paket-design.md`

**Reihenfolge:** B → A → C → D. **Deploy als v0.25.0.**

**Wichtige vorab verifizierte Fakten (nicht erneut recherchieren):**
- `Betrieb`/`BetriebLocal` haben bereits `latitude`, `longitude` (double?), `oeffnungszeitenJson` (String, JSON), `ruhetage` (List<String>), `zahlerAliase`, `rechnungsstellung`, `istMeinKunde`, Adressfelder. **Keine Migration nötig.**
- **Öffnungszeiten-Format** (im Formular als `_oeffnungszeiten`): `Map<String, List<Map<String,String>>>`, Wochentag-Keys genau `'Mo','Di','Mi','Do','Fr','Sa','So'`, jeder Slot `{'von':'HH:MM','bis':'HH:MM'}`. Als JSON in `oeffnungszeitenJson`.
- **Ruhetage-Format**: Liste von `'Mo'..'So'` (oder `['keine']`).
- Im **Betrieb-Formular** (`betrieb_form_screen.dart`) ist das Rechnungsstellung-Dropdown bereits mit `if (_istMeinKunde)` umschlossen (Zeile 396). Der **Zahlernamen-Block** (Zeilen ~423–465) ist NICHT umschlossen. Das Formular speichert aktuell **kein** `latitude`/`longitude` (fehlt im Save-Block bei Zeile ~185–229) — Baustein A muss das ergänzen.
- Im **Betrieb-Detail** (`betrieb_detail_screen.dart`) ist die Rechnungsstellung-Zeile (Zeile 126) unbedingt sichtbar; Zahlernamen werden im Detail gar nicht angezeigt.
- **Fälligkeits-Farben** (aus `tourenplanung_screen.dart` `_labels`): ueberfaellig→`AppColors.error`, faellig→`AppColors.warning`, baldFaellig→`AppColors.success`, endreinigungFaellig→`Color(0xFFEA580C)`, eroeffnungFaellig→`AppColors.info`, nichtFaellig→(kein Eintrag; grau).
- **Anlagen laden**: `anlagenProvider` (Provider<List<AnlageLocal>>) liefert ALLE Anlagen; jede hat `betriebId` (= Betrieb-`serverId`), `reinigungRhythmus`, `letzteReinigung`, `naechsteReinigung`. Für die Karte alle Anlagen einmal laden und in-memory nach `betriebId` gruppieren (nicht N Einzelqueries).
- `BetriebLocal.routeId` == `serverId`. Navigation Detail: `context.push('/betriebe/${betrieb.routeId}')`, Formular: `.../bearbeiten`.
- **Edge-Function-Aufruf** aus Dart: `SupabaseService.client.functions.invoke('name', body: {...})`, dann `response.status` prüfen, `response.data` (Map) lesen. Muster: `beleg_scan_service.dart`.
- **Edge-Function-Vorlage**: `supabase/functions/parse-beleg/index.ts` (CORS, Secret via `Deno.env.get`, `fetch`, Fehler-JSON).

---

## File Structure

**Neu:**
- `supabase/functions/betrieb-google-lookup/index.ts` — Edge-Function (Proxy zu Google Places, Key server-seitig).
- `sbs_projer_app/lib/data/models/google_betrieb_daten.dart` — Result-Model + reine Normalisierungsfunktion `betriebAusGooglePlace`.
- `sbs_projer_app/lib/services/betrieb/betrieb_google_service.dart` — ruft die Edge-Function, gibt `GoogleBetriebDaten` zurück.
- `sbs_projer_app/lib/core/util/betrieb_faelligkeit.dart` — reine Funktion `betriebFaelligkeit(...)`.
- `sbs_projer_app/lib/core/util/google_maps_route.dart` — reine Funktion `googleMapsRouteUrl(...)`.
- `sbs_projer_app/lib/presentation/screens/betriebe/betriebe_map.dart` — Karten-Ansicht (Marker, Filter, Legende, Popup, ohne-Standort).
- Tests: `test/google_betrieb_daten_test.dart`, `test/betrieb_faelligkeit_test.dart`, `test/google_maps_route_test.dart`.

**Geändert:**
- `betrieb_form_screen.dart` — B: Zahlernamen-Block konditional; A: lat/lng-State + Google-Button + Dialog.
- `betrieb_detail_screen.dart` — B: Rechnungsstellung konditional; D: Route-Button.
- `betriebe_list_screen.dart` — C: Umschalter Liste↔Karte.
- `tour_providers.dart` — C: öffentliche Helfer `faelligkeitFarbe`/`faelligkeitLabel` (Farbschema teilen).
- `pubspec.yaml` — Version-Bump v0.25.0.

---

## Baustein B — Kundenabhängige Felder

### Task B1: Betrieb-Formular — Zahlernamen nur bei „mein Kunde"

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart` (Zahlernamen-Block ~423–466)

- [ ] **Step 1: Zahlernamen-Block in `if (_istMeinKunde) ...[ ]` einfassen**

Der Block beginnt mit dem Kommentar `// === Zahlernamen-Aliase (Bank zu Betrieb-Lernen) ===` und enthält Titel-`Text`, Hinweis-`Text`, `SizedBox`, das `if (_zahlerAliase.isNotEmpty) Wrap(...)`, die `Row` mit `_aliasController` und den abschliessenden `const SizedBox(height: 16)`. Diesen gesamten Block (bis und mit dem `SizedBox(height: 16)` **vor** `// === Adresse ===`) in eine Collection-`if`-Liste umschliessen:

```dart
            if (_istMeinKunde) ...[
              // === Zahlernamen-Aliase (Bank zu Betrieb-Lernen) ===
              Text('Zahlernamen (Bank)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const Text(
                'Namen, unter denen dieser Betrieb Zahlungen überweist. '
                'Wird beim Bankauszug-Import automatisch gelernt.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (_zahlerAliase.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in _zahlerAliase)
                      InputChip(
                        label: Text(a),
                        onDeleted: () => setState(() => _zahlerAliase.remove(a)),
                      ),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aliasController,
                      decoration: const InputDecoration(
                        labelText: 'Zahlername hinzufügen',
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _aliasHinzufuegen(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Hinzufügen',
                    onPressed: _aliasHinzufuegen,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
```

Hinweis: Werte in `_zahlerAliase` bleiben im State erhalten (werden weiter beim Speichern geschrieben), nur die UI wird ausgeblendet. Das `const SizedBox(height: 16)` vor `// === Adresse ===` (das dem Block folgte) wird Teil des Blocks — es darf **kein** doppeltes bleiben. Prüfen, dass zwischen `]` und `// === Adresse ===` kein zurückbleibendes `const SizedBox(height: 16)` mehr steht.

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betrieb_form_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart
git commit -m "feat(betrieb): Zahlernamen im Formular nur bei mein Kunde"
```

### Task B2: Betrieb-Detail — Rechnungsstellung nur bei „mein Kunde"

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart:126`

- [ ] **Step 1: Rechnungsstellung-Zeile konditional machen**

Ersetze die unbedingte Zeile

```dart
              _InfoRow('Rechnungsstellung', _rechnungsstellungLabel(betrieb.rechnungsstellung)),
```

durch (Collection-`if`, da innerhalb einer `children:`-Liste):

```dart
              if (betrieb.istMeinKunde)
                _InfoRow('Rechnungsstellung', _rechnungsstellungLabel(betrieb.rechnungsstellung)),
```

Die Zeile `_InfoRow('Mein Kunde', ...)` bleibt unverändert sichtbar.

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betrieb_detail_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart
git commit -m "feat(betrieb): Rechnungsstellung im Detail nur bei mein Kunde"
```

---

## Baustein A — Google-Datenübernahme

### Task A1: Edge-Function `betrieb-google-lookup` (Proxy)

**Files:**
- Create: `supabase/functions/betrieb-google-lookup/index.ts`

Die Funktion ist ein **dünner Proxy**: sie hält den Google-Key server-seitig, ruft Places API (New) `searchText` mit der FieldMask und gibt das **rohe** beste Place-Objekt zurück (`{ place }`) bzw. `{ error }`. Die Normalisierung erfolgt in Task A2 (reine, testbare Dart-Funktion).

- [ ] **Step 1: Function schreiben**

```typescript
// Supabase Edge Function: betrieb-google-lookup
// Sucht einen Betrieb via Google Places API (New) Text Search und gibt das
// beste rohe Place-Objekt zurueck. Der API-Key bleibt server-seitig.
// Deploy: supabase functions deploy betrieb-google-lookup --no-verify-jwt
// Secret: supabase secrets set GOOGLE_PLACES_KEY=...

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FIELD_MASK = [
  "places.displayName",
  "places.formattedAddress",
  "places.addressComponents",
  "places.internationalPhoneNumber",
  "places.nationalPhoneNumber",
  "places.websiteUri",
  "places.location",
  "places.regularOpeningHours",
  "places.googleMapsUri",
].join(",");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  try {
    const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");
    if (!apiKey) {
      return json({ error: "GOOGLE_PLACES_KEY not configured" }, 500);
    }

    const { query } = await req.json();
    if (!query || typeof query !== "string" || query.trim().length === 0) {
      return json({ error: "query is required" }, 400);
    }

    const response = await fetch(
      "https://places.googleapis.com/v1/places:searchText",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": FIELD_MASK,
        },
        body: JSON.stringify({
          textQuery: query,
          languageCode: "de",
          regionCode: "CH",
        }),
      },
    );

    if (!response.ok) {
      const details = await response.text();
      console.error(`Places API error ${response.status}: ${details}`);
      return json(
        { error: `Places API error: ${response.status}`, details },
        502,
      );
    }

    const data = await response.json();
    const place = Array.isArray(data.places) ? data.places[0] : null;
    if (!place) {
      return json({ error: "no_result" }, 200);
    }
    return json({ place });
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    return json({ error: `Fehler: ${msg}` }, 500);
  }
});
```

- [ ] **Step 2: Commit** (Deploy erfolgt im Abschluss-Task, nach Key-Einrichtung durch den User)

```bash
git add supabase/functions/betrieb-google-lookup/index.ts
git commit -m "feat(betrieb): Edge-Function betrieb-google-lookup (Places-Proxy)"
```

### Task A2: Result-Model + reine Normalisierung `betriebAusGooglePlace` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/data/models/google_betrieb_daten.dart`
- Test: `sbs_projer_app/test/google_betrieb_daten_test.dart`

`betriebAusGooglePlace(Map place)` wandelt ein rohes Google-Place-Objekt in `GoogleBetriebDaten` um. Adresse aus `addressComponents` (types `route`, `street_number`, `postal_code`, `locality`); Telefon bevorzugt `nationalPhoneNumber`, sonst `internationalPhoneNumber`; Öffnungszeiten aus `regularOpeningHours.periods` (Google `open.day`: 0=So..6=Sa) ins App-Format (`Mo..So` → Liste `{'von':'HH:MM','bis':'HH:MM'}`); Wochentage ganz ohne Period → `ruhetage`.

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';

void main() {
  group('betriebAusGooglePlace', () {
    test('parst Adresse, Telefon (national bevorzugt), Website, Koordinaten', () {
      final place = {
        'displayName': {'text': 'Restaurant Sonne'},
        'formattedAddress': 'Dorfstrasse 12, 7000 Chur, Schweiz',
        'addressComponents': [
          {'types': ['route'], 'longText': 'Dorfstrasse'},
          {'types': ['street_number'], 'longText': '12'},
          {'types': ['postal_code'], 'longText': '7000'},
          {'types': ['locality'], 'longText': 'Chur'},
        ],
        'nationalPhoneNumber': '081 123 45 67',
        'internationalPhoneNumber': '+41 81 123 45 67',
        'websiteUri': 'https://sonne-chur.ch',
        'location': {'latitude': 46.85, 'longitude': 9.53},
        'googleMapsUri': 'https://maps.google.com/?cid=123',
      };

      final d = betriebAusGooglePlace(place);

      expect(d.name, 'Restaurant Sonne');
      expect(d.strasse, 'Dorfstrasse');
      expect(d.nr, '12');
      expect(d.plz, '7000');
      expect(d.ort, 'Chur');
      expect(d.telefon, '081 123 45 67');
      expect(d.website, 'https://sonne-chur.ch');
      expect(d.latitude, 46.85);
      expect(d.longitude, 9.53);
      expect(d.mapsUri, 'https://maps.google.com/?cid=123');
    });

    test('faellt auf internationale Telefonnummer zurueck', () {
      final d = betriebAusGooglePlace({
        'internationalPhoneNumber': '+41 81 999 00 11',
      });
      expect(d.telefon, '+41 81 999 00 11');
    });

    test('mappt regularOpeningHours auf oeffnungszeiten und ruhetage', () {
      // Mo (day 1) 08:00-12:00 und 13:30-18:00; So (day 0) geschlossen -> Ruhetag
      final place = {
        'regularOpeningHours': {
          'periods': [
            {
              'open': {'day': 1, 'hour': 8, 'minute': 0},
              'close': {'day': 1, 'hour': 12, 'minute': 0},
            },
            {
              'open': {'day': 1, 'hour': 13, 'minute': 30},
              'close': {'day': 1, 'hour': 18, 'minute': 0},
            },
          ],
        },
      };

      final d = betriebAusGooglePlace(place);

      expect(d.oeffnungszeiten['Mo'], [
        {'von': '08:00', 'bis': '12:00'},
        {'von': '13:30', 'bis': '18:00'},
      ]);
      // Tage ohne Period sind Ruhetage
      expect(d.ruhetage, containsAll(['Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']));
      expect(d.ruhetage, isNot(contains('Mo')));
    });

    test('ohne regularOpeningHours: leere Oeffnungszeiten, keine Ruhetage', () {
      final d = betriebAusGooglePlace({'displayName': {'text': 'X'}});
      expect(d.oeffnungszeiten.values.every((l) => l.isEmpty), isTrue);
      expect(d.ruhetage, isEmpty);
    });

    test('fehlende Adressteile bleiben null', () {
      final d = betriebAusGooglePlace({
        'addressComponents': [
          {'types': ['locality'], 'longText': 'Chur'},
        ],
      });
      expect(d.strasse, isNull);
      expect(d.nr, isNull);
      expect(d.plz, isNull);
      expect(d.ort, 'Chur');
    });
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/google_betrieb_daten_test.dart`
Expected: FAIL („Target of URI doesn't exist" / `betriebAusGooglePlace` undefined).

- [ ] **Step 3: Model + Funktion implementieren**

```dart
/// Normalisierte Betrieb-Daten aus einem Google-Places-Resultat.
class GoogleBetriebDaten {
  final String? name;
  final String? strasse;
  final String? nr;
  final String? plz;
  final String? ort;
  final String? telefon;
  final String? website;
  final double? latitude;
  final double? longitude;
  final String? mapsUri;

  /// App-Format: Wochentag ('Mo'..'So') -> Liste {'von':'HH:MM','bis':'HH:MM'}.
  final Map<String, List<Map<String, String>>> oeffnungszeiten;

  /// Wochentage ('Mo'..'So'), die laut Google geschlossen sind.
  final List<String> ruhetage;

  GoogleBetriebDaten({
    this.name,
    this.strasse,
    this.nr,
    this.plz,
    this.ort,
    this.telefon,
    this.website,
    this.latitude,
    this.longitude,
    this.mapsUri,
    required this.oeffnungszeiten,
    required this.ruhetage,
  });
}

/// Google-`open.day` (0=So..6=Sa) -> App-Wochentag-Kürzel.
const _googleDayToTag = {
  0: 'So',
  1: 'Mo',
  2: 'Di',
  3: 'Mi',
  4: 'Do',
  5: 'Fr',
  6: 'Sa',
};

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String? _addressComponent(List components, String type) {
  for (final c in components) {
    final types = (c['types'] as List?)?.map((t) => t.toString()) ?? const [];
    if (types.contains(type)) {
      return c['longText']?.toString() ?? c['shortText']?.toString();
    }
  }
  return null;
}

String _hhmm(Map timePoint) {
  final h = (timePoint['hour'] as num?)?.toInt() ?? 0;
  final m = (timePoint['minute'] as num?)?.toInt() ?? 0;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Wandelt ein rohes Google-Place-Objekt in [GoogleBetriebDaten] um.
GoogleBetriebDaten betriebAusGooglePlace(Map place) {
  final components = (place['addressComponents'] as List?) ?? const [];

  final loc = place['location'];
  double? lat, lng;
  if (loc is Map) {
    lat = (loc['latitude'] as num?)?.toDouble();
    lng = (loc['longitude'] as num?)?.toDouble();
  }

  final oeffnungszeiten = <String, List<Map<String, String>>>{
    for (final t in _wochentage) t: [],
  };
  final ruhetage = <String>[];

  final oh = place['regularOpeningHours'];
  if (oh is Map && oh['periods'] is List) {
    for (final p in (oh['periods'] as List)) {
      if (p is! Map) continue;
      final open = p['open'];
      final close = p['close'];
      if (open is! Map) continue;
      final tag = _googleDayToTag[(open['day'] as num?)?.toInt()];
      if (tag == null) continue;
      oeffnungszeiten[tag]!.add({
        'von': _hhmm(open),
        'bis': close is Map ? _hhmm(close) : '',
      });
    }
    // Nur wenn Google ueberhaupt Oeffnungszeiten geliefert hat, leere Tage
    // als Ruhetage markieren.
    for (final t in _wochentage) {
      if (oeffnungszeiten[t]!.isEmpty) ruhetage.add(t);
    }
  }

  return GoogleBetriebDaten(
    name: place['displayName'] is Map
        ? place['displayName']['text']?.toString()
        : null,
    strasse: _addressComponent(components, 'route'),
    nr: _addressComponent(components, 'street_number'),
    plz: _addressComponent(components, 'postal_code'),
    ort: _addressComponent(components, 'locality'),
    telefon: place['nationalPhoneNumber']?.toString() ??
        place['internationalPhoneNumber']?.toString(),
    website: place['websiteUri']?.toString(),
    latitude: lat,
    longitude: lng,
    mapsUri: place['googleMapsUri']?.toString(),
    oeffnungszeiten: oeffnungszeiten,
    ruhetage: ruhetage,
  );
}
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/google_betrieb_daten_test.dart`
Expected: PASS (alle 5 Tests grün).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/data/models/google_betrieb_daten.dart sbs_projer_app/test/google_betrieb_daten_test.dart
git commit -m "feat(betrieb): reine Normalisierung betriebAusGooglePlace (TDD)"
```

### Task A3: Dart-Service `BetriebGoogleService.lookup`

**Files:**
- Create: `sbs_projer_app/lib/services/betrieb/betrieb_google_service.dart`

- [ ] **Step 1: Service implementieren**

```dart
import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ruft die Edge-Function `betrieb-google-lookup` und normalisiert das
/// Resultat zu [GoogleBetriebDaten].
class BetriebGoogleService {
  /// Sucht einen Betrieb. [query] z.B. "‹Name› ‹PLZ Ort›".
  /// Wirft [BetriebGoogleException] bei Fehler / keinem Treffer.
  static Future<GoogleBetriebDaten> lookup(String query) async {
    final response = await SupabaseService.client.functions.invoke(
      'betrieb-google-lookup',
      body: {'query': query},
    );

    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final msg = data is Map ? data['error'] : 'Unbekannter Fehler';
      throw BetriebGoogleException(msg?.toString() ?? 'Unbekannter Fehler');
    }
    if (data['error'] == 'no_result') {
      throw BetriebGoogleException('Kein Google-Treffer gefunden.');
    }
    if (data['error'] != null) {
      throw BetriebGoogleException(data['error'].toString());
    }
    final place = data['place'];
    if (place is! Map) {
      throw BetriebGoogleException('Ungültige Antwort von Google.');
    }
    return betriebAusGooglePlace(place);
  }
}

class BetriebGoogleException implements Exception {
  final String message;
  BetriebGoogleException(this.message);
  @override
  String toString() => message;
}
```

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/betrieb/betrieb_google_service.dart`
Expected: keine Findings.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/services/betrieb/betrieb_google_service.dart
git commit -m "feat(betrieb): BetriebGoogleService.lookup (Edge-Function-Aufruf)"
```

### Task A4: Formular — lat/lng-State + Google-Button + Bestätigungs-Dialog

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart`

- [ ] **Step 1: Import + lat/lng-State ergänzen**

Oben bei den anderen Service-/Model-Imports:

```dart
import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';
import 'package:sbs_projer_app/services/betrieb/betrieb_google_service.dart';
```

Bei den State-Feldern (z.B. neben `List<String> _ruhetage = [];`):

```dart
  double? _latitude;
  double? _longitude;
  bool _googleLoading = false;
```

- [ ] **Step 2: lat/lng beim Laden übernehmen (in `_loadBetrieb`)**

Im `setState`-Block von `_loadBetrieb` (dort wo `_ruhetage = ...` gesetzt wird) ergänzen:

```dart
      _latitude = betrieb.latitude;
      _longitude = betrieb.longitude;
```

- [ ] **Step 3: lat/lng beim Speichern schreiben (im Save-Block)**

Im Save-Block (bei den anderen `betrieb.xxx = ...`-Zuweisungen, z.B. nach `betrieb.oeffnungszeitenJson = ...`) ergänzen:

```dart
      betrieb.latitude = _latitude;
      betrieb.longitude = _longitude;
```

- [ ] **Step 4: Google-Button oben im Formular einfügen**

Direkt nach dem `_nameController`-Feld (dem ersten Textfeld im Formular) einen Button einfügen. Der Button ist nur aktiv, wenn ein Name gesetzt ist:

```dart
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _googleLoading ? null : _ausGoogleUebernehmen,
              icon: _googleLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.travel_explore),
              label: const Text('Aus Google übernehmen'),
            ),
            const SizedBox(height: 8),
```

- [ ] **Step 5: Lookup- + Dialog-Logik als Methoden ergänzen**

Im State (z.B. neben `_aliasHinzufuegen`) diese Methoden hinzufügen. Der Dialog listet je gefundenes, nicht-leeres Feld eine Checkbox (default an) mit Feldname + Wert (und, falls das Formularfeld schon belegt ist, den aktuellen Wert als „ersetzt: …").

```dart
  Future<void> _ausGoogleUebernehmen() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('Bitte zuerst den Betriebsnamen eingeben.');
      return;
    }
    final ortTeil = [_plzController.text.trim(), _ortController.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final query = ortTeil.isEmpty ? name : '$name $ortTeil';

    setState(() => _googleLoading = true);
    try {
      final daten = await BetriebGoogleService.lookup(query);
      if (!mounted) return;
      await _zeigeUebernahmeDialog(daten);
    } on BetriebGoogleException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('Google-Abgleich fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _zeigeUebernahmeDialog(GoogleBetriebDaten d) async {
    // Kandidatenfelder: (Schluessel, Anzeige-Label, gefundener Wert-Text,
    // aktueller Formularwert-Text, Uebernehmen-Callback).
    final hatOeffnungszeiten =
        d.oeffnungszeiten.values.any((l) => l.isNotEmpty);
    final kandidaten = <_GoogleFeld>[
      if (d.strasse != null || d.nr != null)
        _GoogleFeld(
          'Adresse',
          '${d.strasse ?? ''} ${d.nr ?? ''}'.trim(),
          '${_strasseController.text} ${_nrController.text}'.trim(),
          () {
            if (d.strasse != null) _strasseController.text = d.strasse!;
            if (d.nr != null) _nrController.text = d.nr!;
          },
        ),
      if (d.plz != null)
        _GoogleFeld('PLZ', d.plz!, _plzController.text,
            () => _plzController.text = d.plz!),
      if (d.ort != null)
        _GoogleFeld('Ort', d.ort!, _ortController.text,
            () => _ortController.text = d.ort!),
      if (d.telefon != null)
        _GoogleFeld('Telefon', d.telefon!, _telefonController.text,
            () => _telefonController.text = d.telefon!),
      if (d.website != null)
        _GoogleFeld('Website', d.website!, _websiteController.text,
            () => _websiteController.text = d.website!),
      if (d.latitude != null && d.longitude != null)
        _GoogleFeld(
          'Koordinaten',
          '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}',
          (_latitude != null && _longitude != null)
              ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
              : '',
          () {
            _latitude = d.latitude;
            _longitude = d.longitude;
          },
        ),
      if (hatOeffnungszeiten)
        _GoogleFeld(
          'Öffnungszeiten',
          _oeffnungszeitenKurz(d.oeffnungszeiten),
          '',
          () {
            setState(() {
              for (final t in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
                _oeffnungszeiten[t] =
                    List<Map<String, String>>.from(d.oeffnungszeiten[t] ?? []);
              }
              // Ruhetage aus Google uebernehmen (nur wenn Zeiten kamen).
              if (d.ruhetage.isNotEmpty) {
                _ruhetage = List<String>.from(d.ruhetage);
              }
            });
          },
        ),
    ];

    if (kandidaten.isEmpty) {
      _snack('Google lieferte keine übernehmbaren Felder.');
      return;
    }

    final auswahl = {for (final k in kandidaten) k: true};

    final uebernehmen = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Google-Daten übernehmen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (d.name != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Gefunden: ${d.name}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                for (final k in kandidaten)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: auswahl[k],
                    onChanged: (v) =>
                        setDialogState(() => auswahl[k] = v ?? false),
                    title: Text('${k.label}: ${k.wert}'),
                    subtitle: k.aktuell.isNotEmpty
                        ? Text('ersetzt: ${k.aktuell}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey))
                        : null,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => ctx.pop(false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => ctx.pop(true),
                child: const Text('Übernehmen')),
          ],
        ),
      ),
    );

    if (uebernehmen == true) {
      setState(() {
        for (final k in kandidaten) {
          if (auswahl[k] == true) k.uebernehmen();
        }
      });
      _snack('Google-Daten übernommen. Zum Sichern speichern.');
    }
  }

  String _oeffnungszeitenKurz(Map<String, List<Map<String, String>>> oz) {
    final tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
        .where((t) => (oz[t] ?? []).isNotEmpty)
        .toList();
    return '${tage.length} Tag(e) mit Zeiten';
  }
```

Und die kleine Hilfsklasse (Datei-Ende, ausserhalb des State):

```dart
class _GoogleFeld {
  final String label;
  final String wert;
  final String aktuell;
  final void Function() uebernehmen;
  _GoogleFeld(this.label, this.wert, this.aktuell, this.uebernehmen);
}
```

Hinweis: `ctx.pop(...)` erfordert den bereits vorhandenen go_router-Import (`context.pop` wird im Projekt genutzt). Falls im Formular nicht vorhanden, stattdessen `Navigator.pop(ctx, false)` / `Navigator.pop(ctx, true)` verwenden.

- [ ] **Step 6: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betrieb_form_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart
git commit -m "feat(betrieb): Google-Datenuebernahme (Button + Bestaetigungs-Dialog, lat/lng persistiert)"
```

---

## Baustein C — Betriebe-Karte

### Task C1: Fälligkeits-Helfer + reine `betriebFaelligkeit` (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart` (öffentliche Helfer ergänzen)
- Create: `sbs_projer_app/lib/core/util/betrieb_faelligkeit.dart`
- Test: `sbs_projer_app/test/betrieb_faelligkeit_test.dart`

- [ ] **Step 1: Öffentliche Farb-/Label-Helfer in `tour_providers.dart` ergänzen**

Am Ende von `tour_providers.dart` (die Datei importiert bereits Material/AppColors nicht zwingend — daher Import prüfen und ggf. ergänzen: `import 'package:flutter/material.dart';` und `import 'package:sbs_projer_app/core/theme/app_theme.dart';`). Dann:

```dart
/// Farbe je Fälligkeitsstatus (identisch zum Touren-Farbschema).
Color faelligkeitFarbe(FaelligkeitsStatus status) {
  switch (status) {
    case FaelligkeitsStatus.ueberfaellig:
      return AppColors.error;
    case FaelligkeitsStatus.faellig:
      return AppColors.warning;
    case FaelligkeitsStatus.baldFaellig:
      return AppColors.success;
    case FaelligkeitsStatus.endreinigungFaellig:
      return const Color(0xFFEA580C);
    case FaelligkeitsStatus.eroeffnungFaellig:
      return AppColors.info;
    case FaelligkeitsStatus.nichtFaellig:
      return AppColors.textSecondary;
  }
}

/// Kurzlabel je Fälligkeitsstatus.
String faelligkeitLabel(FaelligkeitsStatus status) {
  switch (status) {
    case FaelligkeitsStatus.ueberfaellig:
      return 'Überfällig';
    case FaelligkeitsStatus.faellig:
      return 'Fällig';
    case FaelligkeitsStatus.baldFaellig:
      return 'Bald fällig';
    case FaelligkeitsStatus.endreinigungFaellig:
      return 'Endreinigung';
    case FaelligkeitsStatus.eroeffnungFaellig:
      return 'Eröffnung';
    case FaelligkeitsStatus.nichtFaellig:
      return 'Nicht fällig';
  }
}
```

- [ ] **Step 2: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_faelligkeit.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  group('betriebFaelligkeit', () {
    test('leere Liste -> nichtFaellig', () {
      expect(betriebFaelligkeit([]), FaelligkeitsStatus.nichtFaellig);
    });

    test('gibt den schlimmsten Status zurueck (ueberfaellig schlaegt faellig)', () {
      final r = betriebFaelligkeit([
        FaelligkeitsStatus.nichtFaellig,
        FaelligkeitsStatus.faellig,
        FaelligkeitsStatus.ueberfaellig,
        FaelligkeitsStatus.baldFaellig,
      ]);
      expect(r, FaelligkeitsStatus.ueberfaellig);
    });

    test('Rangfolge faellig > baldFaellig > endreinigung > eroeffnung > nicht', () {
      expect(
        betriebFaelligkeit([
          FaelligkeitsStatus.baldFaellig,
          FaelligkeitsStatus.faellig,
        ]),
        FaelligkeitsStatus.faellig,
      );
      expect(
        betriebFaelligkeit([
          FaelligkeitsStatus.eroeffnungFaellig,
          FaelligkeitsStatus.endreinigungFaellig,
        ]),
        FaelligkeitsStatus.endreinigungFaellig,
      );
      expect(
        betriebFaelligkeit([
          FaelligkeitsStatus.nichtFaellig,
          FaelligkeitsStatus.eroeffnungFaellig,
        ]),
        FaelligkeitsStatus.eroeffnungFaellig,
      );
    });
  });
}
```

- [ ] **Step 3: Test ausführen, Fehlschlag bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/betrieb_faelligkeit_test.dart`
Expected: FAIL (`betriebFaelligkeit` undefined).

- [ ] **Step 4: `betrieb_faelligkeit.dart` implementieren**

```dart
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Rangfolge von schlimm (0) nach unkritisch (hoch).
const _rang = <FaelligkeitsStatus, int>{
  FaelligkeitsStatus.ueberfaellig: 0,
  FaelligkeitsStatus.faellig: 1,
  FaelligkeitsStatus.baldFaellig: 2,
  FaelligkeitsStatus.endreinigungFaellig: 3,
  FaelligkeitsStatus.eroeffnungFaellig: 4,
  FaelligkeitsStatus.nichtFaellig: 5,
};

/// Betrieb-Fälligkeit = schlimmster Status seiner Anlagen.
/// Leere Liste -> [FaelligkeitsStatus.nichtFaellig].
FaelligkeitsStatus betriebFaelligkeit(List<FaelligkeitsStatus> anlagenStatus) {
  if (anlagenStatus.isEmpty) return FaelligkeitsStatus.nichtFaellig;
  return anlagenStatus.reduce(
    (a, b) => (_rang[a] ?? 5) <= (_rang[b] ?? 5) ? a : b,
  );
}
```

- [ ] **Step 5: Test ausführen, Erfolg bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/betrieb_faelligkeit_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze (tour_providers.dart wegen neuer Imports)**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/providers/tour_providers.dart lib/core/util/betrieb_faelligkeit.dart`
Expected: keine neuen Findings.

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart sbs_projer_app/lib/core/util/betrieb_faelligkeit.dart sbs_projer_app/test/betrieb_faelligkeit_test.dart
git commit -m "feat(betrieb): betriebFaelligkeit-Aggregation + oeffentliche Faelligkeits-Helfer (TDD)"
```

### Task C2: Karten-Widget `betriebe_map.dart` (Marker, Auto-Fit, Legende, Popup)

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/betriebe/betriebe_map.dart`

Diese Task baut die Karte inkl. farbiger Marker (nach `betriebFaelligkeit`), Auto-Fit, Legende und Marker-Popup mit „Öffnen". Filter-Leiste + ohne-Standort-Zähler kommen in C3. Um beides sauber zu trennen, nimmt `BetriebeMap` bereits gefilterte Listen entgegen; die Filter-/Zähler-UI liegt im Eltern-Screen (C4/C3).

- [ ] **Step 1: Widget schreiben**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Ein Betrieb mit seiner aggregierten Fälligkeit für die Karte.
class BetriebMarkerData {
  final BetriebLocal betrieb;
  final FaelligkeitsStatus status;
  const BetriebMarkerData(this.betrieb, this.status);
}

/// swisstopo-Karte mit einem farbigen Marker je Betrieb (mit Koordinaten).
/// Farbe nach [BetriebMarkerData.status]. Tap -> Popup mit «Öffnen».
class BetriebeMap extends StatefulWidget {
  final List<BetriebMarkerData> eintraege;
  final void Function(BetriebLocal) onOeffnen;
  final void Function(BetriebLocal) onRoute;

  const BetriebeMap({
    super.key,
    required this.eintraege,
    required this.onOeffnen,
    required this.onRoute,
  });

  @override
  State<BetriebeMap> createState() => _BetriebeMapState();
}

class _BetriebeMapState extends State<BetriebeMap> {
  final _controller = MapController();

  // Mittelpunkt Schweiz als Fallback (0 Marker).
  static final _schweiz = LatLng(46.8, 8.23);

  @override
  Widget build(BuildContext context) {
    final mitGps = widget.eintraege
        .where((e) =>
            e.betrieb.latitude != null && e.betrieb.longitude != null)
        .toList();
    final punkte = mitGps
        .map((e) => LatLng(e.betrieb.latitude!, e.betrieb.longitude!))
        .toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: punkte.isEmpty
                ? null
                : CameraFit.coordinates(
                    coordinates: punkte,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 16,
                  ),
            initialCenter: punkte.isEmpty ? _schweiz : punkte.first,
            initialZoom: punkte.isEmpty ? 7.5 : 12,
            onMapReady: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final cam = _controller.camera;
                _controller.move(cam.center, cam.zoom + 0.02);
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissimage/default/current/3857/{z}/{x}/{y}.jpeg',
              userAgentPackageName: 'ch.sbsprojer.app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (final e in mitGps)
                  Marker(
                    point: LatLng(
                        e.betrieb.latitude!, e.betrieb.longitude!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _zeigePopup(e),
                      child: Icon(Icons.location_on,
                          color: faelligkeitFarbe(e.status), size: 40),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('© swisstopo')],
            ),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _Legende(),
        ),
      ],
    );
  }

  void _zeigePopup(BetriebMarkerData e) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.betrieb.name,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle,
                      size: 12, color: faelligkeitFarbe(e.status)),
                  const SizedBox(width: 6),
                  Text(faelligkeitLabel(e.status)),
                ],
              ),
              if (e.betrieb.ort != null) ...[
                const SizedBox(height: 4),
                Text(e.betrieb.ort!,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onRoute(e.betrieb);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Route'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onOeffnen(e.betrieb);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Öffnen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  static const _eintraege = [
    (FaelligkeitsStatus.ueberfaellig, 'Überfällig'),
    (FaelligkeitsStatus.faellig, 'Fällig'),
    (FaelligkeitsStatus.baldFaellig, 'Bald'),
    (FaelligkeitsStatus.eroeffnungFaellig, 'Eröffnung'),
    (FaelligkeitsStatus.nichtFaellig, 'OK'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (status, label) in _eintraege)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 10, color: faelligkeitFarbe(status)),
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betriebe_map.dart`
Expected: keine Findings.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betriebe_map.dart
git commit -m "feat(betrieb): Karten-Widget mit farbigen Faelligkeits-Markern + Popup"
```

### Task C3: Betriebe-Liste — Umschalter Liste↔Karte, Fälligkeits-Berechnung, Filter, ohne-Standort

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betriebe_list_screen.dart`

Diese Task verdrahtet die Karte in den Betriebe-Screen: SegmentedButton oben, Aggregation der Fälligkeit je Betrieb aus `anlagenProvider`, Filter-Leiste (meine Kunden / Region / nur fällige) über der Karte und ein „ohne Standort"-Zähler, der zu einer Liste führt, von der aus das Betrieb-Formular geöffnet wird.

- [ ] **Step 1: Imports ergänzen**

```dart
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betriebe_map.dart';
import 'package:sbs_projer_app/core/util/betrieb_faelligkeit.dart';
```

(`tour_providers.dart` und `betrieb_providers.dart` sind bereits importiert.)

- [ ] **Step 2: State-Felder für Ansicht + Kartenfilter**

In `_BetriebeListScreenState` ergänzen:

```dart
  bool _karteAktiv = false;
  bool _karteNurMeine = false;
  bool _karteNurFaellig = false;
  String? _karteRegionId; // null = alle Regionen
```

- [ ] **Step 3: Umschalter in die AppBar-Titelzeile / oben in den Body**

Ganz oben im `body`-`Column` (vor der Suchleiste) einen Umschalter einfügen:

```dart
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.list),
                    label: Text('Liste')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map),
                    label: Text('Karte')),
              ],
              selected: {_karteAktiv},
              onSelectionChanged: (s) =>
                  setState(() => _karteAktiv = s.first),
            ),
          ),
```

- [ ] **Step 4: Fälligkeit je Betrieb aus allen Anlagen aggregieren**

Im `build` (nach `final betriebe = ref.watch(betriebeProvider);`) ergänzen:

```dart
    final anlagen = ref.watch(anlagenProvider);
    // Anlagen einmal nach betriebId gruppieren.
    final anlagenNachBetrieb = <String, List<AnlageLocal>>{};
    for (final a in anlagen) {
      (anlagenNachBetrieb[a.betriebId] ??= []).add(a);
    }
    final jetzt = DateTime.now();
    FaelligkeitsStatus statusFuer(BetriebLocal b) {
      final sid = b.serverId;
      final list = sid == null ? const <AnlageLocal>[] : (anlagenNachBetrieb[sid] ?? const []);
      return betriebFaelligkeit(
        list.map((a) => getFaelligkeit(a, jetzt, betrieb: b)).toList(),
      );
    }
```

- [ ] **Step 5: Body abhängig vom Modus rendern**

Den bestehenden `Expanded`-Listen-Block in ein `if (!_karteAktiv) ... else ...` verpacken. Für die Karte:

```dart
          Expanded(
            child: _karteAktiv
                ? _buildKarte(statusFuer)
                : (filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _BetriebListItem(
                            betrieb: filtered[index],
                            onTap: () => context.push(
                              '/betriebe/${filtered[index].routeId}',
                            ),
                          );
                        },
                      )),
          ),
```

- [ ] **Step 6: `_buildKarte`-Methode implementieren**

In `_BetriebeListScreenState`:

```dart
  Widget _buildKarte(FaelligkeitsStatus Function(BetriebLocal) statusFuer) {
    final alle = ref.read(betriebeProvider);
    final regionen = ref.read(regionenProvider);

    bool istFaellig(FaelligkeitsStatus s) =>
        s == FaelligkeitsStatus.ueberfaellig ||
        s == FaelligkeitsStatus.faellig ||
        s == FaelligkeitsStatus.baldFaellig;

    // Karten-Filter anwenden.
    final gefiltert = alle.where((b) {
      if (_karteNurMeine && !b.istMeinKunde) return false;
      if (_karteRegionId != null && b.regionId != _karteRegionId) return false;
      if (_karteNurFaellig && !istFaellig(statusFuer(b))) return false;
      return true;
    }).toList();

    final mitKoord = gefiltert
        .where((b) => b.latitude != null && b.longitude != null)
        .map((b) => BetriebMarkerData(b, statusFuer(b)))
        .toList();
    final ohneKoord =
        gefiltert.where((b) => b.latitude == null || b.longitude == null).toList();

    return Column(
      children: [
        // Filter-Leiste
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Meine Kunden'),
                selected: _karteNurMeine,
                onSelected: (v) => setState(() => _karteNurMeine = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Nur fällige'),
                selected: _karteNurFaellig,
                onSelected: (v) => setState(() => _karteNurFaellig = v),
              ),
              const SizedBox(width: 8),
              if (regionen.isNotEmpty)
                DropdownButton<String?>(
                  value: _karteRegionId,
                  hint: const Text('Region'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Alle Regionen')),
                    for (final r in regionen)
                      if (r.serverId != null)
                        DropdownMenuItem(value: r.serverId, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _karteRegionId = v),
                ),
            ],
          ),
        ),
        Expanded(
          child: BetriebeMap(
            eintraege: mitKoord,
            onOeffnen: (b) => context.push('/betriebe/${b.routeId}'),
            onRoute: (b) => _oeffneRoute(b),
          ),
        ),
        if (ohneKoord.isNotEmpty)
          TextButton.icon(
            onPressed: () => _zeigeOhneStandort(ohneKoord),
            icon: const Icon(Icons.wrong_location_outlined, size: 18),
            label: Text('${ohneKoord.length} Betriebe ohne Standort'),
          ),
      ],
    );
  }

  void _zeigeOhneStandort(List<BetriebLocal> ohne) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Betriebe ohne Standort',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final b in ohne)
              ListTile(
                title: Text(b.name),
                subtitle: b.ort != null ? Text(b.ort!) : null,
                trailing: const Icon(Icons.edit_location_alt),
                onTap: () {
                  Navigator.pop(ctx);
                  // Betrieb-Formular oeffnen -> dort «Aus Google uebernehmen»
                  // ergaenzt die Koordinaten (Baustein A).
                  context.push('/betriebe/${b.routeId}/bearbeiten');
                },
              ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 7: Route-Öffnen-Hilfsmethode** (nutzt das Util aus Task D1 — diese Task erst nach D1 fertigstellen, ODER den Import/`_oeffneRoute` als Stub bis D1 anlegen)

Um Reihenfolge-Kopplung zu vermeiden: `_oeffneRoute` hier bereits mit dem Util aus D1 implementieren (D1 wird als Teil desselben Pakets umgesetzt; falls C3 vor D1 läuft, D1 vorziehen). Import ergänzen:

```dart
import 'package:sbs_projer_app/core/util/google_maps_route.dart';
import 'package:url_launcher/url_launcher.dart';
```

Methode:

```dart
  Future<void> _oeffneRoute(BetriebLocal b) async {
    final url = googleMapsRouteUrl(
      latitude: b.latitude,
      longitude: b.longitude,
      adresse: [b.strasse, b.nr, b.plz, b.ort]
          .where((s) => s != null && s.isNotEmpty)
          .join(' '),
    );
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Adresse/Koordinaten für Route.')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
```

> **Hinweis an den Ausführenden:** Da C3 das Util `googleMapsRouteUrl` aus **Task D1** verwendet, **Task D1 vor C3 umsetzen** (Ausführungsreihenfolge B → A → C1 → C2 → **D1** → C3). Der Plan-Text listet D am Ende, aber die Abhängigkeit erfordert D1 vor C3.

- [ ] **Step 8: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betriebe_list_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 9: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betriebe_list_screen.dart
git commit -m "feat(betrieb): Umschalter Liste/Karte, Faelligkeits-Aggregation, Kartenfilter, ohne-Standort"
```

---

## Baustein D — „Route in Google Maps"

### Task D1: Route-URL-Util (TDD) + Route-Button im Betrieb-Detail

**Files:**
- Create: `sbs_projer_app/lib/core/util/google_maps_route.dart`
- Test: `sbs_projer_app/test/google_maps_route_test.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart`

> Diese Task **vor Task C3** ausführen (C3 nutzt `googleMapsRouteUrl`).

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_maps_route.dart';

void main() {
  group('googleMapsRouteUrl', () {
    test('Koordinaten haben Vorrang', () {
      final url = googleMapsRouteUrl(
          latitude: 46.85, longitude: 9.53, adresse: 'Dorfstrasse 12 Chur');
      expect(url,
          'https://www.google.com/maps/dir/?api=1&destination=46.85%2C9.53');
    });

    test('ohne Koordinaten: URL-kodierte Adresse', () {
      final url = googleMapsRouteUrl(
          latitude: null, longitude: null, adresse: 'Dorfstrasse 12, 7000 Chur');
      expect(url,
          'https://www.google.com/maps/dir/?api=1&destination=Dorfstrasse+12%2C+7000+Chur');
    });

    test('ohne Koordinaten und ohne Adresse -> null', () {
      expect(googleMapsRouteUrl(latitude: null, longitude: null, adresse: ''),
          isNull);
    });

    test('nur Longitude fehlt -> Fallback Adresse', () {
      final url = googleMapsRouteUrl(
          latitude: 46.85, longitude: null, adresse: 'Chur');
      expect(url, 'https://www.google.com/maps/dir/?api=1&destination=Chur');
    });
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/google_maps_route_test.dart`
Expected: FAIL (`googleMapsRouteUrl` undefined).

- [ ] **Step 3: Util implementieren**

```dart
/// Baut eine Google-Maps-Navigations-URL zum Ziel.
/// Koordinaten haben Vorrang; sonst wird die (URL-kodierte) [adresse] genutzt.
/// Gibt `null` zurück, wenn weder vollständige Koordinaten noch Adresse da sind.
String? googleMapsRouteUrl({
  required double? latitude,
  required double? longitude,
  required String adresse,
}) {
  const base = 'https://www.google.com/maps/dir/?api=1&destination=';
  if (latitude != null && longitude != null) {
    final dest = Uri.encodeComponent('$latitude,$longitude');
    return '$base$dest';
  }
  final adr = adresse.trim();
  if (adr.isEmpty) return null;
  return '$base${Uri.encodeQueryComponent(adr)}';
}
```

Hinweis: `Uri.encodeComponent('46.85,9.53')` → `46.85%2C9.53`; `Uri.encodeQueryComponent('Dorfstrasse 12, 7000 Chur')` → `Dorfstrasse+12%2C+7000+Chur` (Leerzeichen als `+`). Die Tests spiegeln genau dieses Verhalten.

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/google_maps_route_test.dart`
Expected: PASS.

- [ ] **Step 5: Route-Button im Betrieb-Detail (AppBar) ergänzen**

In `betrieb_detail_screen.dart` Import ergänzen:

```dart
import 'package:sbs_projer_app/core/util/google_maps_route.dart';
```

In den AppBar-`actions` von `_BetriebDetailContent` (vor dem Edit-Button, innerhalb/ausserhalb des `isGuest`-Blocks — Route soll auch für Gäste sichtbar sein, daher **vor** dem `if (!SupabaseService.isGuest)`-Spread) einen Button einfügen, der nur erscheint, wenn eine Route möglich ist:

```dart
        actions: [
          if (_routeUrl(betrieb) != null)
            IconButton(
              icon: const Icon(Icons.directions),
              tooltip: 'Route in Google Maps',
              onPressed: () => launchUrl(
                Uri.parse(_routeUrl(betrieb)!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (!SupabaseService.isGuest) ...[
            // ... bestehende Edit-/Löschen-Buttons ...
          ],
        ],
```

Und eine kleine Helfermethode in `_BetriebDetailContent`:

```dart
  String? _routeUrl(BetriebLocal betrieb) => googleMapsRouteUrl(
        latitude: betrieb.latitude,
        longitude: betrieb.longitude,
        adresse: [betrieb.strasse, betrieb.nr, betrieb.plz, betrieb.ort]
            .where((s) => s != null && s.isNotEmpty)
            .join(' '),
      );
```

(`launchUrl`/`LaunchMode` sind über den bereits vorhandenen `url_launcher`-Import verfügbar.)

- [ ] **Step 6: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/core/util/google_maps_route.dart lib/presentation/screens/betriebe/betrieb_detail_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/core/util/google_maps_route.dart sbs_projer_app/test/google_maps_route_test.dart sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart
git commit -m "feat(betrieb): Route-in-Google-Maps-Util (TDD) + Button im Detail"
```

---

## Abschluss: Verifikation, Edge-Function-Deploy & App-Deploy v0.25.0

### Task Z: Gesamtverifikation + Deploy

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml` (Version)

- [ ] **Step 1: Version bumpen**

In `pubspec.yaml` Zeile 4: `version: 0.24.1+491` → `version: 0.25.0+492`.

- [ ] **Step 2: Volle Analyse + alle Tests**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze && flutter test`
Expected: keine neuen Analyze-Findings; alle Tests grün (inkl. `google_betrieb_daten_test`, `betrieb_faelligkeit_test`, `google_maps_route_test`).

- [ ] **Step 3: Edge-Function deployen + Secret setzen** (nachdem der User den Key eingerichtet hat)

```bash
supabase functions deploy betrieb-google-lookup --no-verify-jwt
supabase secrets set GOOGLE_PLACES_KEY=<vom User bereitgestellt>
```

> **Wichtig:** Den Key NICHT in Git/Chat schreiben. Der User richtet den Google-API-Key ein und stellt ihn als Supabase-Secret bereit. Falls der Key zur Deploy-Zeit noch fehlt, Function trotzdem deployen — sie liefert dann `GOOGLE_PLACES_KEY not configured`, bis das Secret gesetzt ist.

- [ ] **Step 4: Visueller Browser-Test (Pflicht, vor Live-Deploy)**

Web-Build starten (`flutter run -d edge`) bzw. Preview und prüfen:
- **B:** Betrieb-Formular — „mein Kunde"-Schalter aus → Rechnungsstellung **und** Zahlernamen verschwinden; an → erscheinen. Betrieb-Detail eines Fremdkunden zeigt keine Rechnungsstellung.
- **A:** Formular „Aus Google übernehmen" mit echtem Betrieb (Key gesetzt) → Dialog mit vorgehakten Feldern → „Übernehmen" füllt Felder → Speichern persistiert lat/lng.
- **C:** Betriebe-Liste → Umschalter „Karte" → farbige Marker, Legende, Filter (meine Kunden/Region/nur fällige) wirken, Marker-Tap-Popup „Öffnen"/„Route", „X ohne Standort"-Zähler → Liste → Formular.
- **D:** Betrieb-Detail Route-Icon öffnet Google Maps; Karten-Popup „Route" ebenso.

- [ ] **Step 5: Version-Commit**

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version 0.25.0+492 (Betrieb-Paket)"
```

- [ ] **Step 6: Deploy nach gh-pages** (Workflow aus `CLAUDE.md`, vorher alle Änderungen committen + `main` pushen; **kein** `git stash`)

```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.25.0 — Betrieb-Paket (Google-Uebernahme, kundenabh. Felder, Karte, Route)"
git push origin gh-pages
git checkout main
git push origin main
```

---

## Zusammenfassung der Ausführungsreihenfolge

**Empfohlene Task-Reihenfolge (wegen Util-Abhängigkeit D1 → C3):**
B1 → B2 → A1 → A2 → A3 → A4 → C1 → C2 → **D1** → C3 → Z

Jede Task ist eigenständig committbar; UI-Tasks werden im Abschluss-Task (Z) einmal gesammelt visuell verifiziert und deployt.
