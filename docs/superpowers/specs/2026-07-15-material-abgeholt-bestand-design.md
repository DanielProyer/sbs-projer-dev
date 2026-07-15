# Material abgeholt → Bestände in einem Klick — Design

**Datum:** 15.07.2026
**Ziel:** Nach dem Abholen einer Materialbestellung bei Heineken sollen alle Lager-Bestände mit einem Klick nachgeführt werden, statt jeden Artikel einzeln zu korrigieren.

---

## Ausgangslage (verifiziert am Code + Prod-DB)

- `material_bestellungen`: `status` CHECK erlaubt heute nur **`entwurf` / `gesendet` / `storniert`** — es gibt **kein „abgeholt"**. Aktuell 2 Bestellungen, beide `gesendet`.
- `material_bestellpositionen`: trägt bereits **`lager_id`**, **`menge`** (bestellt), sowie Snapshots `bestand_aktuell` / `bestand_optimal` (Stand bei Bestellung), `dbo_nr`, `sap_nr`, `name`, `einheit`, `sortierung`.
- Bestand liegt in **`lager.bestand_aktuell`** (numeric). `lager.bestand_niedrig` ist eine **Generated Column** (`bestand_aktuell < bestand_mindest`) → führt sich beim Bestands-Update automatisch nach.
- Bestell-Flow heute: Lager-Artikel mit `bestand_niedrig` → Bestellliste → Bestellung + PDF → an Heineken (`gesendet`). Danach endet die Automatik — genau hier setzt dieses Feature an.

## Entscheidungen (Daniel, 15.07.2026)

1. **Abweichungen kommen vor** (Teillieferung/fehlender Artikel) → **Kontroll-Liste vor dem Buchen**, keine blinde Buchung.
2. **Restmengen werden NICHT nachverfolgt** → nach dem Buchen gilt die Bestellung als erledigt. Liegt der Bestand weiterhin unter dem Mindestbestand, erscheint der Artikel über `bestand_niedrig` automatisch wieder auf der nächsten Bestellliste. Keine Teillieferungs-Maschinerie (YAGNI).
3. **„Buchung rückgängig" wird eingebaut** (billig, da die erhaltene Menge gespeichert wird).

---

## Datenmodell (Migration 141)

```sql
ALTER TABLE material_bestellungen DROP CONSTRAINT IF EXISTS material_bestellungen_status_check;
ALTER TABLE material_bestellungen ADD CONSTRAINT material_bestellungen_status_check
  CHECK (status IN ('entwurf','gesendet','abgeholt','storniert'));

ALTER TABLE material_bestellungen   ADD COLUMN IF NOT EXISTS abgeholt_am date;
ALTER TABLE material_bestellpositionen ADD COLUMN IF NOT EXISTS menge_erhalten numeric;
```

- `status` neu: **`entwurf → gesendet → abgeholt`** (`storniert` bleibt unverändert).
- `abgeholt_am`: Datum der Abholung (Anzeige + Beleg).
- `menge_erhalten`: was **tatsächlich** kam (null = noch nicht gebucht). Doppelnutzen: Beleg „bestellt vs. erhalten" + Basis für Rückgängig.

**Modell/DTO:** `MaterialBestellung` um `abgeholtAm`, `MaterialBestellposition` um `mengeErhalten` erweitern (fromJson/toJson). Beide sind Supabase-only (kein Isar-Layer) → nur DTO anfassen.

---

## Atomarität — warum RPC statt Update-Schleife

Eine client-seitige Schleife (Bestand lesen → addieren → schreiben, Position für Position) hat ein **Teilausfall-Problem**: bricht sie nach der Hälfte ab, sind einige Bestände erhöht, der Status bleibt aber `gesendet`. Ein zweiter Klick würde diese Artikel **doppelt** addieren — ein stiller Lagerfehler. Deshalb:

- Die Buchung läuft in **einer Postgres-Transaktion** (RPC) → **alles oder nichts**.
- Das Update ist **relativ** (`bestand_aktuell = bestand_aktuell + delta`) → kein Lesen/Schreiben-Rennen, keine veralteten Zwischenstände.
- Die RPC **prüft den Status** (`gesendet` beim Buchen, `abgeholt` beim Rückgängig) und wirft sonst → Doppelbuchung ist auch bei Doppelklick/Retry unmöglich.

## Reine Funktion (TDD)

Datei `lib/core/util/bestand_buchung.dart`, Test `test/bestand_buchung_test.dart`.
Die Funktion bereitet die Buchung auf (Dialog-Logik + Nutzlast der RPC); die Arithmetik auf dem Bestand macht die RPC relativ.

```dart
/// Verdichtet die im Kontroll-Dialog erfassten Mengen zu Bestands-Deltas
/// pro Lager-Artikel — die Nutzlast für die Abhol-RPC.
///
/// [positionen]: Positionen der Bestellung.
/// [mengen]: positionId → erhaltene Menge (fehlend/<=0 → Position übersprungen).
/// Rückgabe: lagerId → summierte erhaltene Menge (nur buchbare Positionen).
Map<String, double> bestandsDeltas({
  required List<MaterialBestellposition> positionen,
  required Map<String, double> mengen,
});

/// True, wenn die Position überhaupt auf ein Lager buchbar ist
/// (hat `lagerId`) — steuert die Ausgrau-Logik im Dialog.
bool istBuchbar(MaterialBestellposition p);
```

**Regeln (= Testfälle):**
- Position **ohne `lagerId`** → übersprungen (Freitext-Position, kein Lager-Bezug); `istBuchbar` = false.
- Menge **fehlt / 0 / negativ** → übersprungen (= „nicht erhalten").
- Mehrere Positionen auf **denselben `lagerId`** → Mengen werden **summiert** (ein Delta pro Lager-Artikel).
- Leere Eingabe → leere Map (Dialog deaktiviert „Bestände buchen").

---

## Datenzugriff — zwei RPCs (Migration 141)

```sql
-- Bucht die Abholung atomar. p_mengen: {"<positionId>": <menge>, …}
CREATE OR REPLACE FUNCTION material_bestellung_abholen(
  p_bestellung_id uuid, p_mengen jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM material_bestellungen
                 WHERE id = p_bestellung_id AND status = 'gesendet') THEN
    RAISE EXCEPTION 'Bestellung ist nicht im Status "gesendet" (bereits gebucht?)';
  END IF;

  FOR r IN SELECT p.id, p.lager_id, (p_mengen ->> p.id::text)::numeric AS menge
           FROM material_bestellpositionen p
           WHERE p.bestellung_id = p_bestellung_id
             AND p.lager_id IS NOT NULL
             AND (p_mengen ->> p.id::text)::numeric > 0
  LOOP
    UPDATE lager SET bestand_aktuell = bestand_aktuell + r.menge WHERE id = r.lager_id;
    UPDATE material_bestellpositionen SET menge_erhalten = r.menge WHERE id = r.id;
  END LOOP;

  UPDATE material_bestellungen
     SET status = 'abgeholt', abgeholt_am = CURRENT_DATE, updated_at = now()
   WHERE id = p_bestellung_id;
END; $$;

-- Macht die Abholung atomar rückgängig.
CREATE OR REPLACE FUNCTION material_bestellung_abholung_rueckgaengig(
  p_bestellung_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM material_bestellungen
                 WHERE id = p_bestellung_id AND status = 'abgeholt') THEN
    RAISE EXCEPTION 'Bestellung ist nicht im Status "abgeholt"';
  END IF;

  FOR r IN SELECT p.id, p.lager_id, p.menge_erhalten AS menge
           FROM material_bestellpositionen p
           WHERE p.bestellung_id = p_bestellung_id
             AND p.lager_id IS NOT NULL
             AND p.menge_erhalten IS NOT NULL
  LOOP
    -- Klemmung bei 0: negativer Bestand ist fachlich unsinnig (falls seit dem
    -- Buchen bereits Material verbraucht wurde).
    UPDATE lager SET bestand_aktuell = GREATEST(0, bestand_aktuell - r.menge)
     WHERE id = r.lager_id;
    UPDATE material_bestellpositionen SET menge_erhalten = NULL WHERE id = r.id;
  END LOOP;

  UPDATE material_bestellungen
     SET status = 'gesendet', abgeholt_am = NULL, updated_at = now()
   WHERE id = p_bestellung_id;
END; $$;
```

RLS: `SECURITY INVOKER` → die bestehenden `user_isolation`-Policies greifen unverändert (kein Rechte-Loch).

## Repository (`MaterialBestellungRepository`)

```dart
/// Bucht die Abholung atomar (Bestände +, menge_erhalten, Status 'abgeholt').
/// [mengen]: positionId → erhaltene Menge.
static Future<void> abholen(String bestellungId, Map<String, double> mengen) =>
    SupabaseService.client.rpc('material_bestellung_abholen', params: {
      'p_bestellung_id': bestellungId,
      'p_mengen': mengen,
    });

/// Macht die Abholung atomar rückgängig (Bestände −, Status 'gesendet').
static Future<void> abholungRueckgaengig(String bestellungId) =>
    SupabaseService.client.rpc('material_bestellung_abholung_rueckgaengig',
        params: {'p_bestellung_id': bestellungId});
```

**Fehlerfall:** Wirft die RPC (falscher Status / DB-Fehler), wird **nichts** geschrieben (Transaktion) — die UI zeigt die Meldung, der Zustand bleibt konsistent, der Vorgang ist gefahrlos wiederholbar.

---

## UI

### Befund: es fehlt der Ort für den Button

`MaterialBestellungScreen` (`/materialien/bestellen`) ist ein reiner **Erfassungs-Wizard**: erstellen → PDF → mailen → `context.pop()`. Es gibt **keine Ansicht gesendeter Bestellungen**; `MaterialBestellungRepository.getAll()` / `getById()` sind vorhanden, werden aber **von keinem Screen genutzt** (toter Code). Auch das Bestell-PDF ist nach dem Versand nicht mehr auffindbar. Entscheidung Daniel: **neue Bestellungen-Liste** (statt nur einer Karte auf dem Lager-Screen) — schliesst zugleich die Historie-/PDF-Lücke und macht den toten Code nutzbar.

### Neuer Screen `material_bestellungen_screen.dart` — Route `/materialien/bestellungen`

- **Einstieg:** AppBar-Action auf `/materialien` (`MaterialienListScreen`), Icon `Icons.receipt_long`, Tooltip „Bestellungen".
- **Liste** (`getAll()`, neueste zuoberst): pro Bestellung eine Karte mit **Bestell-Nr · Datum**, **Status-Badge** (`gesendet` = blau, `abgeholt` = grün mit „abgeholt am TT.MM.JJJJ", `entwurf`/`storniert` = grau), Anzahl Positionen.
- **Aktionen pro Karte:**
  - **PDF öffnen** (falls `pdf_storage_path` gesetzt) → `getSignedPdfUrl` + `launchUrl`.
  - Status `gesendet` → **„Material abgeholt"** → Kontroll-Dialog (unten).
  - Status `abgeholt` → **„Buchung rückgängig"** (mit Sicherheitsabfrage) → `abholungRueckgaengig` → Status wieder `gesendet`.
- **Leerzustand:** „Noch keine Bestellungen."
- Der Erfassungs-Wizard (`material_bestellung_screen.dart`) bleibt **unverändert**.

- **Aufklappbar** (`ExpansionTile`): zeigt die Positionen — bei `abgeholt` als **„bestellt X · erhalten Y"** (Abweichung hervorgehoben), sonst nur die bestellte Menge. Macht die gebuchte Abholung nachvollziehbar.

### Kontroll-Dialog „Material abgeholt"

- Titel: Bestell-Nr + Datum.
- **Nach Kategorie gruppiert — gleiche Gliederung/Reihenfolge wie die Bestellung** (Gruppen-Kopf = `kategorie_name`, innerhalb nach `sortierung`; Positionen ohne Kategorie unter „Übrige" am Schluss). Daniel kennt die Reihenfolge vom Bestell-PDF → schnelleres Abhaken.
- Pro Position eine Zeile: **Checkbox links** (erhalten, default **an**), Name + `SAP/DBO`, **Mengenfeld** (vorbefüllt = bestellte Menge, editierbar, numerisch), Einheit; darunter klein „bestellt: X".
- Positionen **ohne `lager_id`**: ausgegraut, nicht wählbar, Hinweis „kein Lager-Bezug — wird nicht gebucht".
- Fusszeile: Anzahl zu buchender Positionen + Button **„Bestände buchen"** (deaktiviert, wenn nichts gewählt).
- Stimmt alles → nur bestätigen (= der gewünschte Ein-Klick-Fall).
- Nach Erfolg: Liste neu laden + `materialienStreamProvider` invalidieren (Lager-Bestände sind neu).

**Doppelbuchungs-Schutz:** „Material abgeholt" erscheint nur bei `gesendet`; zusätzlich prüft die RPC den Status serverseitig → auch Doppelklick/Retry kann nicht doppelt buchen.

**CanvasKit-Falle:** Aktions-Buttons im Material-/Bestell-Bereich als `GestureDetector`+`Container` (Material-Buttons rendern dort teils nicht) — bestehendes Projekt-Muster.

---

## Nicht im Scope (bewusst)

- **Teillieferungs-Verfolgung** (Restmenge offen halten, mehrfaches Nachbuchen) — via `bestand_niedrig` automatisch abgedeckt.
- **Lieferschein-/Wareneingangs-Vertikale** (eigene Tabelle) — Overkill für einen Ein-Personen-Betrieb.
- **Buchhaltungs-Buchung** des Materialeinkaufs — Materialbestellung ist reine Lagerführung; der Heineken-Einkauf läuft separat über die Kreditoren/camt-Schiene.

## Verifikation

- **TDD (Dart):** `bestand_buchung_test.dart` deckt die Dialog-/Delta-Regeln ab — Position ohne `lagerId` übersprungen, Menge fehlt/0/negativ übersprungen, gleiches Lager summiert, leere Eingabe → leere Map, `istBuchbar`.
- **SQL-seitig** (Atomarität, Status-Guard, Klemmung bei 0) direkt auf der Prod-DB gegen eine Testbestellung geprüft: buchen → Bestände +, Status `abgeholt`; erneutes Buchen → Exception (kein Doppelzählen); rückgängig → Bestände exakt wie vorher, Status `gesendet`.
- `flutter analyze` 0 Fehler, volle Test-Suite grün.
- **Live-Test durch Daniel:** Bestellung `gesendet` → „Material abgeholt" → Mengen prüfen (inkl. einer Abweichung + einer abgewählten Zeile) → buchen → Lager-Bestände kontrollieren → „Buchung rückgängig" → Bestände wieder wie vorher.
