# Historie-Backfill Werkstatt-Aufträge (Auswertung Phase 2a) — Design

**Datum:** 2026-07-12 · **Status:** in Abnahme

## Ziel

Die historischen **Heineken-Werkstatt-Aufträge** aus `00_SBS_Projer_70.xlsm` (Ordner `00_Buchhaltung`,
Vollpfad `D:/01_SBS_Projer_GmbH/00_SBS_Projer_70.xlsm`) als **echte App-Datensätze** nacherfassen, sodass sich
die Buchhaltungs-Auswertung (`/buchhaltung/auswertung`) **rückwirkend füllt**. Die Auswertung berechnet
„Rechnung HK" live aus diesen Kategorien (Σ netto × MwSt) — es sind **keine** separaten Rechnungs-Datensätze
nötig.

## Umfang

**In Scope (dieses Projekt):** 5 Kategorien, Zeitraum **2019-01-01 → 2025-11-30**:

| Kategorie | Excel-Blatt | Zeilen (Total) | Ziel-Tabelle |
|---|---|--:|---|
| Störung | `Störung` | 1079 | `stoerungen` |
| Montage | `Montage` | 780 | `montagen` |
| Eigenauftrag | `Eigenauftrag` | 120 | `eigenauftraege` |
| Eröffnung/Endreinigung | `EE_Reinigung` | 151 | `eroeffnungsreinigungen` |
| Pikett | `Pikett` | 103 | `pikett_dienste` |

**Explizit NICHT in Scope (separate Folgeschritte, User-Entscheidung 12.07.2026):**
- **BK-Pauschale** — hat KEINE Einzel-Datensätze im Excel (nur Jahres-Summe Anzahl×180 im Auswertung-Blatt).
  Eigener fokussierter Folgeschritt; Quelle dort klären (aus Bergkunde-Betrieben × Reinigungen ableiten o. ä.).
- **Reinigungen** — bereits vollständig in der App (8621, ab 2019). Kein Backfill.
- **Heineken-Monatsrechnungen** — werden später generiert und gegen die realen PDF-Rechnungen (vorhanden seit
  2019) abgeglichen. Nicht Teil dieses Projekts.
- **Volle Feld-Treue** (Material-Positionen, Artikel-Nummern etc.) — nur soweit für Auswertung/Listen nötig
  (siehe Mapping). Material-Positionen werden NICHT mitimportiert.

## Kernanforderung: NICHTS DOPPELT ERFASSEN

Zweifacher Schutz, zusammen mathematisch duplikatfrei:

1. **Datumsgrenze.** Nur Excel-Zeilen mit `datum < 2025-12-01` importieren. Die App besitzt in allen 5
   Tabellen ausschliesslich Datensätze **ab Dez 2025** (geprüft 12.07.2026: früheste App-Daten
   stoerungen 2025-12-02, montagen 2025-12-01, eigenauftraege 2025-12-03, eroeffnungsreinigungen 2025-12-03,
   pikett 2025-12-05). Damit **null Überlappung** mit Live-Daten.
2. **Stabiler Import-Schlüssel (`legacy_id`).** Neue nullbare Spalte `legacy_id text` auf den 5 Tabellen +
   **partieller Unique-Index** `(user_id, legacy_id) WHERE legacy_id IS NOT NULL`. Der Import schreibt die
   stabile Excel-ID hinein (Störung/Montage/Eigenauftrag/EE = `ID <Kategorie>` z. B. `0213_2019_05_03`;
   Pikett = `ID Pikett` z. B. `2019_24`). Der Import macht **Upsert on conflict (user_id, legacy_id)** →
   ein zweiter Lauf erzeugt **keine** Duplikate, sondern aktualisiert. Live-Datensätze haben `legacy_id = null`
   und sind vom Index ausgenommen.

## Migration (`Datenbank/migrations/`)

Eine SQL-Migration:
- `ALTER TABLE {stoerungen, montagen, eigenauftraege, eroeffnungsreinigungen, pikett_dienste} ADD COLUMN legacy_id text;`
- Je Tabelle: `CREATE UNIQUE INDEX … ON <t> (user_id, legacy_id) WHERE legacy_id IS NOT NULL;`
- `ALTER TABLE eigenauftraege ALTER COLUMN betrieb_id DROP NOT NULL;` — konsistent mit den Schwester-Tabellen
  (dort ist `betrieb_id` bereits nullable), damit Waisen-Aufträge (Betrieb nicht in App) importierbar sind.

## Import-Mechanismus

Einmaliges **Python-Skript** in `Datenbank/` (Muster wie frühere Excel-Importe), NICHT App-Code:
- Liest die `.xlsm` via `openpyxl` (`data_only=True`).
- Verbindet zu Supabase-Prod (`pltbaqqwpnmdajwgnhpd`) mit Service-Role (umgeht RLS; setzt `user_id` explizit
  = Daniels User-ID, wird zu Beginn aus `auth.users` geholt — es gibt nur einen aktiven User).
- Baut die Betrieb-Mapping-Tabelle (s. u.), transformiert je Zeile, **upsert** on `(user_id, legacy_id)`.
- **Idempotent + wiederholbar.** Trockenlauf-Modus (`--dry-run`) druckt nur Zusammenfassung + Verifikation.

## Feld-Mapping (Auswertungs-relevant)

Datum: Excel-Spalte `Datum` (bei Pikett → `datum_start`). Pflichtfelder der Zieltabellen sind alle im Excel
vorhanden. `user_id` = Daniel. `legacy_id` = Excel-ID. `abgerechnet` = true (historisch abgerechnet).

| Kategorie | Netto-Betrag (Excel → App) | weitere Pflicht-/Kernfelder |
|---|---|---|
| Störung | `Total Störung` → `preis_netto` | `anlage_typ` ← `Anlagentyp`; `problem_beschreibung` ← `Bemerkung`; `stoerungsnummer` ← `Störungsnummer`; `ist_kilometerabrechnung=false` |
| Montage | `Betrag` → `kosten_arbeit` | `montage_typ` ← `Montagetyp` (NOT NULL); `beschreibung` ← `Bemerkung`; `dauer_stunden` ← `Anzahl Stunden` |
| Eigenauftrag | `Total` → `pauschale` | `problem_beschreibung` ← `Beschreibung` (NOT NULL); `stoerungsnummer` ← `Störungsnummer` |
| Eröffnung/Endr. | `Rechnungsbetrag` → `preis` | `art` ← `Eröffnung / Endreinigung` (NOT NULL, Werte „Eröffnung"/„Endreinigung"); `ist_bergkunde` ← `Bergkunde=='Ja'` |
| Pikett | `Betrag` → `pauschale_gesamt` | `datum_start` ← `Datum`; `anzahl_feiertage` ← `Feiertage`; `referenz_nr` ← `ID Pikett` (`2019_24`) |

**Netto/Brutto-Interpretation** wird über die Verifikation (s. u.) fixiert: die Excel-Betragsfelder gelten als
**netto**, wenn ihre Jahres-Summe die Netto-Spalte des Auswertung-Blatts trifft. Falls eine Summe genau um den
MwSt-Faktor abweicht, wird der Wert vor dem Schreiben durch den Faktor geteilt (date-aware: 7.7 % bis 2023,
8.1 % ab 2024). Erwartung nach Sichtung: die Excel-Werte sind bereits netto.

## Betrieb-Zuordnung

Excel-Aufträge referenzieren `ID Betrieb` **numerisch** (z. B. 213); die App nutzt UUIDs. Mapping-Kette je
Excel-Betrieb-ID:
1. **`betriebe.heineken_nr`** = zero-padded Excel-ID (z. B. Excel 213 → `heineken_nr='0213'`), wo gesetzt.
2. Sonst **exakter Name-Match** (Excel-Betrieb-Blatt `Bezeichnung` ↔ `betriebe.name`), nur wenn eindeutig.
3. Sonst **`betrieb_id = null`** (User-Entscheidung „trotzdem importieren"). Der Auftrag zählt korrekt in der
   Auswertung (aggregiert nach Datum/Kategorie); in Listen erscheint er als „Unbekannt".

Das Skript **protokolliert** die Zuordnungs-Statistik (per heineken_nr / per Name / unzuordenbar) und listet
die unzuordenbaren Betrieb-IDs. Hintergrund: Excel hat 812 Betriebe, die App nur 407 — alte/inaktive Betriebe
wurden nie importiert, deren Aufträge bleiben `betrieb_id=null`.

## Verifikation (Abnahme-Kriterium)

Nach dem Import (bzw. im `--dry-run`) je **Jahr × Kategorie** `count(*)` und `sum(netto)` aggregieren und
**exakt gegen das Excel-Blatt „Auswertung"** prüfen (Spalten Störung/Eigenauftrag/Eröffnung+Endr./Montage/
Pikett). Zielwerte (Anzahl / Netto-Total CHF):

| Jahr | Störung | Eigenauftrag | Eröffn.+Endr. | Montage | Pikett |
|---|---|---|---|---|---|
| 2019 | 106 / 12'878.50 | 23 / 840 | 7 / 420 | 63 / 18'712.50 | 8 / 2'225 |
| 2020 | 131 / 16'405 | 20 / 600 | 12 / 720 | 84 / 21'068.80 | 12 / 3'000 |
| 2021 | 151 / 19'605.80 | 17 / 510 | 7 / 495 | 82 / 14'461.20 | 9 / 1'620 |
| 2022 | 179 / 22'975 | 23 / 690 | 25 / 1'500 | 143 / 26'040 | 16 / 2'960 |
| 2023 | 149 / 20'270 | 12 / 420 | 34 / 2'265 | 113 / 22'755 | 15 / 2'480 |
| 2024 | 152 / 21'916.40 | 4 / 120 | 26 / 1'710 | 106 / 23'603.10 | 18 / 3'200 |
| 2025* | teils (nur < Dez) | teils | teils | teils | teils |

\*2025 wird nur bis 30.11. importiert; die Excel-Jahreszeile 2025 umfasst das ganze Jahr inkl. Dez (Dez ist
bereits in der App). Verifikation 2025: importierte Summe + App-Live-Dez-Summe = Excel-Jahreszeile 2025.
Für 2019–2024 muss die importierte Summe die Excel-Zeile **exakt** treffen (Rundung: Schweizer 5-Rappen).

Zusätzlich: nach dem Import zeigt der App-Auswertung-Screen (Modus „Jahre") die Historie mit gefüllter
„Heineken"-Spalte für 2019–2025.

## Ablauf / Reihenfolge

1. Migration schreiben + auf Prod anwenden (legacy_id-Spalten, Indizes, eigenauftraege.betrieb_id nullable).
2. Import-Skript: Excel-Leser + Betrieb-Mapping + je Kategorie Transform + Upsert.
3. `--dry-run` gegen die Verifikations-Tabelle grün bekommen (2019–2024 exakt).
4. Echtlauf. Verifikation erneut gegen DB.
5. App-Auswertung sichten (Historie gefüllt).

## Risiken / offene Detailpunkte (im Plan zu fixieren)

- Netto/Brutto je Betragsfeld — via Verifikation gegen Auswertung-Blatt fixiert.
- `art`-Werte bei EE müssen den DB-CHECK-Constraints entsprechen (Werte „Eröffnung"/„Endreinigung" prüfen).
- `montage_typ`-Werte müssen den DB-CHECK-Constraints der `montagen` entsprechen (Excel-Montagetyp-Werte
  gegen erlaubte Werte mappen).
- Eindeutigkeit des Name-Matchs (Duplikat-Namen) — bei Mehrdeutigkeit `betrieb_id=null` statt falsch zuordnen.

## Out of Scope (Wiederholung)
BK-Pauschale · Heineken-Monatsrechnungen · Material-Positionen · App-UI-Änderungen (die Auswertung liest die
Daten bereits).
