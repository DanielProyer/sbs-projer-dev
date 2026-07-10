# Betrieb-Lifecycle & Auto-„mein Kunde" (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026, inkl. Daten-Check)
**Herkunft:** User-Wunsch — inaktive Betriebe automatisch aus „mein Kunde" nehmen, Reaktivierung
automatisch, und ein sauberer Umgang mit dauerhaft geschlossenen Betrieben (Umnutzung/Abbruch).

## Ziel & Kontext

Der `istMeinKunde`-Flag wird heute manuell gepflegt (mit einer kleinen Auto-Regel im Formular, die
nur auf `zapfsysteme` reagiert). Dadurch sind in der DB noch Betriebe „mein Kunde", obwohl sie
inaktiv oder geschlossen sind. Dieses Paket macht `istMeinKunde` weitgehend automatisch (mit
manuellem Override), bereinigt den Bestand und formalisiert den Lebenszyklus eines Betriebs inkl.
dauerhafter Schliessung mit Grund/Datum.

## Verifizierte Fakten (Ist-Zustand, DB-Check 10.07.2026)

- `betriebe.status` genutzte Werte: `aktiv` (290), `inaktiv` (12), `geschlossen` (104).
- „mein Kunde"=true bei nicht-aktiven: **4 inaktiv** + **104 geschlossen**.
- **Wichtig — Fehl-Einordnung gefunden:** 2 der 4 inaktiv-true sind **Saisonbetriebe**
  (`ist_saisonbetrieb=true`): **Clavadeleralp** und **Weissfluhjoch** (beide Davos). Das sind echte
  Saisonkunden (ausserhalb der Saison), die fälschlich auf `inaktiv` stehen — sie dürfen **nicht**
  auf „mein Kunde=false". Die anderen 2 (AMERON, Valentinos) sind echte inaktive ohne Saison.
- Alle **104 geschlossen** sind sauber dauerhaft zu: **0 Saisonbetriebe, 0 mit Ferien**.
- **Formular-Status-Dropdown** (`betrieb_form_screen.dart:795`) bietet aktuell `aktiv`, `inaktiv`,
  `saisonpause` — **`geschlossen` fehlt** (die 104 kamen per Import).
- **Betriebe-Liste-Filter** kennt `alle/aktiv/inaktiv/geschlossen`, Default `alle`.
- „Konventionell/Orion" sind **Zapfsysteme** (`betriebe.zapfsysteme`, Chips
  `['David','Konventionell','Higenie','Orion','Veranstaltungen']`), **kein** Anlagentyp
  (`anlagen.typ_anlage` = Warmanstich/Kaltanstich/Buffetanstich/Orion).
- Bestehende Formular-Auto-Regel: `mein Kunde = false`, wenn `zapfsysteme` nicht leer ist und
  ausschliesslich aus `{David, Higenie, Veranstaltungen}` besteht (`betrieb_form_screen.dart:372`).
- Fälligkeits-/Touren-Logik filtert `aktiv` bereits selbst; Karte ignoriert inaktive seit v0.25.2.

## Kernprinzip: Saison/Ferien ≠ inaktiv

Ein saisonal oder ferienbedingt geschlossener Betrieb ist **weiterhin Kunde**. Das wird über
**Status `aktiv` + Saison-/Ferien-Flags** abgebildet (bzw. Status `saisonpause`), **nicht** über
`inaktiv`. `inaktiv` bedeutet „kein Kunde mehr / ruhend", `geschlossen` „dauerhaft weg".

**Kunde-relevant & sichtbar** = `{aktiv, saisonpause}` · **nicht** = `{inaktiv, geschlossen}`.

## Entscheidungen (mit User geklärt)

- **B „mein Kunde":** Auto-Vorschlag **mit manuellem Override** (Schalter bleibt).
- **Daten-Korrektur:** Clavadeleralp & Weissfluhjoch (Saisonbetriebe) → Status `inaktiv`→`aktiv`,
  mein Kunde bleibt true. AMERON & Valentinos → mein Kunde=false.
- **C Schliessung:** dauerhaft geschlossene Betriebe bekommen **Grund + Datum**.
- **D Sichtbarkeit:** **inaktive UND geschlossene** Betriebe standardmässig aus Karte + Betriebs-Liste
  ausblenden (nur per Filter sichtbar); `aktiv`/`saisonpause` bleiben sichtbar.
- **Deploy:** ein Paket als **v0.26.0**.

## Status-Vokabular

- **`aktiv`** — wird betreut / Kunde. Saison- und Ferienbetriebe laufen normal hierüber (mit den
  bestehenden Saison-/Ferien-Flags).
- **`saisonpause`** — saisonal geschlossen, **weiterhin Kunde** (für „mein Kunde" und Sichtbarkeit wie
  `aktiv` behandelt). Selten genutzt (aktuell 0 Betriebe).
- **`inaktiv`** — kein Kunde mehr / ruhend → mein Kunde false, ausgeblendet.
- **`geschlossen`** — dauerhaft zu (Umnutzung/Abbruch/Konkurs) → mein Kunde false, ausgeblendet.
- Formular-Dropdown erhält zusätzlich **`geschlossen`**; `saisonpause` bleibt erhalten.

## Baustein B — Auto-„mein Kunde" mit Override

### B.1 Reine Funktion (testbar)

`istMeinKundeVorschlag(String status, List<String> zapfsysteme) → bool`:

- `status == 'inaktiv'` **oder** `status == 'geschlossen'` → **false**.
- sonst (`aktiv`/`saisonpause`/unbekannt) → **true**, wenn `zapfsysteme` `'Konventionell'` **oder**
  `'Orion'` enthält; sonst **false**.

Deckt die alte „nur David/Higenie/Veranstaltungen"-Regel als Spezialfall ab (kein Konventionell/
Orion → false) und behandelt Saisonpause korrekt als Kunde.

### B.2 Formular-Verhalten (Override)

- Bei **Status-Änderung** und bei **Zapfsystem-Änderung** wird der `_istMeinKunde`-Schalter auf
  `istMeinKundeVorschlag(...)` gesetzt (ersetzt die bestehende Inline-Auto-Regel).
- Der Schalter bleibt bedienbar: der Vorschlag kann **manuell übersteuert** werden; beim Speichern
  gilt der Schalterwert (kein erneutes Überschreiben im Save).

### B.3 Einmal-Bereinigung (Migration, zweistufig)

```sql
-- (a) Fehl-eingeordnete Saisonbetriebe zurueck auf aktiv (bleiben Kunde)
UPDATE betriebe SET status = 'aktiv'
WHERE status = 'inaktiv' AND ist_saisonbetrieb = true;
-- trifft: Clavadeleralp, Weissfluhjoch

-- (b) Echte inaktive + geschlossene -> mein Kunde false; Saisonbetriebe geschuetzt
UPDATE betriebe SET ist_mein_kunde = false
WHERE status IN ('inaktiv', 'geschlossen')
  AND ist_saisonbetrieb = false
  AND ist_mein_kunde = true;
-- trifft: AMERON, Valentinos + 104 geschlossen = 106
```

Aktive Betriebe bleiben unangetastet (230 aktiv/true, 60 aktiv/false — bewusste Einstellungen). Der
`ist_saisonbetrieb=false`-Schutz verhindert, dass je ein Saisonkunde demoted wird.

## Baustein C — Dauerhafte Schliessung dokumentieren

### C.1 Datenmodell (Migration, additiv)

Neue Spalten auf `betriebe`:
- `schliessungsgrund text` (nullable) — App-Werte: `umnutzung`, `abbruch`, `konkurs`, `sonstiges`
  (kein DB-CHECK; App-seitige Auswahl).
- `schliessungsdatum date` (nullable).

Durch DTO (`Betrieb`), Isar-Local (`BetriebLocal` + Web-Stub), Conditional Export unverändert,
`BetriebMapper` (fromDto/toJson) durchreichen.

### C.2 Formular

- Nur wenn **Status = `geschlossen`**: Dropdown „Schliessungsgrund" (Umnutzung/Abbruch/Konkurs/
  Sonstiges) + Datumsauswahl „Schliessungsdatum". Bei anderem Status ausgeblendet; Werte werden bei
  Nicht-`geschlossen` auf `null` gesetzt (analog zur Ferien-/Saison-Logik).

### C.3 Detail

- Wenn `status == 'geschlossen'`: Zeilen „Schliessungsgrund" (lesbares Label statt Code) und
  „Schliessungsdatum" in der Details-Karte anzeigen.

## Baustein D — Sichtbarkeit

### D.1 Betriebe-Liste

- Default-`_statusFilter` von `'alle'` → **`'aktiv'`** (zeigt standardmässig nur aktive; `saisonpause`
  ist selten und über den Filter erreichbar). Über den bestehenden Status-Filter
  (`alle/aktiv/inaktiv/geschlossen`) sind inaktive/geschlossene erreichbar.

### D.2 Karte

- Marker standardmässig nur `aktiv`/`saisonpause`. Neuer Filter-Schalter „Inaktive/geschlossene
  zeigen" (default aus) in der Karten-Filterleiste; ist er an, werden auch `inaktiv`/`geschlossen`
  (grau/nicht fällig, wie seit v0.25.2) angezeigt.
- Der „ohne Standort"-Zähler zählt konsistent nur die aktuell angezeigte Menge.

## Abgrenzung

- Keine Änderung an der bestehenden Fälligkeits-/Touren-Logik (filtert `aktiv` bereits selbst).
- Kein Hard-/Soft-Delete-Umbau: `geschlossen` bleibt ein Status. Löschen bleibt wie in v0.25.1 (nur
  wenn keine verknüpften Daten).
- Kein DB-CHECK-Constraint für `schliessungsgrund` (App validiert die Auswahl).
- `saisonpause` wird nicht entfernt.

## Tests & Verifikation

- **Unit-Tests** für `istMeinKundeVorschlag`: `inaktiv`/`geschlossen` → false (auch mit Konv/Orion im
  Zapfsystem); `aktiv` + Konventionell → true; `aktiv` + Orion → true; `saisonpause` + Konventionell
  → true; `aktiv` + nur David/Higenie/Veranstaltungen → false; `aktiv` + leere Zapfsysteme → false.
- `flutter analyze` ohne neue Findings; Tests grün.
- **Visueller Browser-Test** (Pflicht): Status-Wechsel schaltet „mein Kunde" korrekt (aktiv+Konv →
  an; auf inaktiv → aus; zurück auf aktiv → an); manueller Override bleibt beim Speichern erhalten;
  Schliessungsgrund/-datum erscheinen nur bei `geschlossen` und im Detail; Liste zeigt default nur
  aktive; Karte blendet inaktiv/geschlossen aus, Filter-Schalter zeigt sie.
- **DB-Backfill** nach Migration verifizieren: Clavadeleralp/Weissfluhjoch sind `aktiv` + mein Kunde;
  keine `status IN ('inaktiv','geschlossen') AND ist_saisonbetrieb=false`-Zeile mehr mit
  `ist_mein_kunde=true`.

## Deploy

Ein Paket **v0.26.0** nach Deploy-Workflow (CLAUDE.md). Migration (2 Spalten + zweistufiger Backfill)
via `apply_migration`; Migrationsdatei in `Datenbank/migrations/127_betrieb_lifecycle.sql` ablegen.
