# Excel-Import der Buchhaltungs-Historie – Design

**Datum:** 2026-06-13 · **Status:** Spec zur Freigabe durch Daniel
**Übergeordnet:** Phase 1 (Historie-Import), Teil 2 von 2. Teil 1 (MWST-korrekte Saldo-Expansion) ist abgeschlossen und Voraussetzung für den Abgleich.

---

## 1. Ziel & Scope

Die bestehende Excel-Buchhaltung (`00_Buchhaltung/00_SBS_Projer_70.xlsm`, Sheet **Journal**) wird **1:1** in die App-Tabelle `buchungen` importiert — als eingefrorene Historie. Danach wird **Jahr für Jahr** geprüft, dass die aus den importierten Buchungen berechnete App-Bilanz/ER den Excel-Zahlen entspricht.

**Import-Umfang:** Journal-Zeilen mit `datum < 2025-12-01` = **14'552 Zeilen** (27.03.2019 – Nov 2025), davon 9'522 mit MWST. user = Daniel (`1e1ec2dd-7836-4d8e-8256-c5649d994ee2`).

**Naht (entschieden):** Die nativen App-Buchungen ab Dez 2025 (1'482 Zeilen, mit Reinigungen/Rechnungen/Belegen verknüpft) bleiben **unberührt**. Die importierte Historie liefert die implizite Eröffnungsbilanz für den Go-Forward.

**Treue (entschieden):** **1:1** — gleiche Konten/Beträge wie Excel. Bekannte Fehler (Konten 8090/9100, fehlende MWST-Rückbuchung bei Abschreibungen) werden **nicht** beim Import korrigiert, sondern erst in Phase 2 (Aufräumen). So ist der Abgleich ein exakter Treue-Beweis.

## 2. ETL-Pipeline (Python → Batch-SQL)

Einmaliger, reproduzierbarer Import. Skripte unter `Datenbank/import/`. Kein App-Code, kein Deploy.

### 2.1 Spalten-Mapping (Journal → buchungen)
| Journal | buchungen | Hinweis |
|---|---|---|
| `ID BS` | `belegnummer` | strukturierter Beleg-Schlüssel |
| `Datum` | `datum` | + `geschaeftsjahr`/`monat`/`quartal` abgeleitet |
| `Betrag` | `betrag_brutto` | brutto; **negativ erlaubt** (13 Korrektur-Zeilen) |
| `Soll Konto` | `soll_konto` | int |
| `Haben Konto` | `haben_konto` | int |
| `MWST Konto` | `mwst_konto` | `-`/leer → NULL |
| `MWST-Satz` | `mwst_satz` | `-`/leer → 0 |
| `Bemerkung` | `beschreibung` | Pflichtfeld; falls leer → `Geschäftsfall`-Bezeichnung |
| `Belegordner` | `belegordner` | |
| — | `ist_storniert` | immer `false` (Journal kennt kein Storno; Korrekturen sind eigene Zeilen) |
| — | `user_id` | Daniel |
| — | `vorlage_id`, `beleg_id`, `beleg_typ`, `camt_tx_key` | NULL |

### 2.2 netto/MWST-Berechnung (nicht im Journal vorhanden)
Pro Zeile aus brutto + Satz:
- `netto = round(betrag_brutto / (1 + mwst_satz/100), 2)`
- `mwst_betrag = betrag_brutto − netto` (Residuum → keine Summen-Drift)
- ohne MWST (Satz 0): `netto = brutto`, `mwst_betrag = 0`, `mwst_konto = NULL`

### 2.3 Einfügen
In Batches (~1'000 Zeilen) via `mcp__supabase__execute_sql` (parametrisiert/escaped). Textfelder sauber escapen (Hochkommas, Zeilenumbrüche in `beschreibung`).

## 3. Konten-Abdeckung (Vorbereitung)

Alle 48 im Journal verwendeten Konten müssen in `konten` existieren (für Namen + Bilanz-Gruppierung; der Saldo-Vergleich selbst läuft über die Kontonummer). **5 fehlen** aktuell — werden vorab ergänzt (Migration), Bezeichnung/Kategorie aus dem Excel-Kontenrahmen:

| Konto | Bezeichnung | Kategorie | Hinweis |
|---|---|---|---|
| 2970 | Gewinn-/Verlustvortrag | Eigenkapital | |
| 2980 | Jahresgewinn/-verlust | Eigenkapital | |
| 5005 | Lohnersatz (EO/KAE) | Lohnaufwand | |
| 8090 | FEHLER – sollte 8900 (Phase 2) | Steuern | Tippfehler-Konto, faithful importiert |
| 9100 | FEHLER – sollte 9010 (Phase 2) | Abschluss | Tippfehler-Konto, faithful importiert |

Die beiden Fehler-Konten werden **bewusst** angelegt (damit die importierten Zeilen einen benannten Bezug haben) und in Phase 2 zusammen mit ihren Buchungen korrigiert.

## 4. Sicherheit & Idempotenz

- **Reversibel:** Vor (Re-)Import `DELETE FROM buchungen WHERE user_id = <Daniel> AND datum < '2025-12-01'` (dort aktuell 0 Zeilen → erster Lauf löscht nichts; spätere Wiederholungen sind sauber).
- Die nativen Buchungen ab Dez 2025 werden vom Scope-Filter **nie** berührt.
- Import-Skript + ergänzende Konten-Migration werden committet → wiederholbar.

## 5. Validierung (Pilot 2019 zuerst)

Zweistufig:

**A — Treue-Gate (automatisch).** Ein Python-Skript `validate_import.py` berechnet aus dem **Journal** eine Referenz mit denselben Saldo-Regeln wie die App (SaldoExpansion: netto auf Aufwand/Ertrag, MWST aufs Steuerkonto, brutto auf Bank/Debitor):
- **per-Konto-Saldo** kumuliert je Jahresende (31.12.2019 … 31.12.2024, 30.11.2025)
- **per-Jahr-Erfolgsrechnung** (Nettoerlös, Aufwand-Stufen)

Gegenprobe: dieselben Werte aus den **importierten `buchungen`** (per SQL bzw. den App-Service-Regeln). **Pass bei |Diff| ≤ 0.05 pro Konto**; **jede Diff ≠ 0 wird protokolliert** (Konto, Jahr, Soll/Ist). Fängt verlorene/verfälschte Zeilen und Mapping-Fehler.

**B — Plausibilität gegen Excel (Stichprobe).** Zentrale Konten-Saldi (z. B. Bank 1020, Debitoren 1100, Vorsteuer 1170/1171, Umsatzsteuer 2200, Eigenkapital 2800) zu einem Stichtag werden gegen die **Excel-Bilanz/Hauptbuch-Sheets** verglichen — bestätigt, dass die netto/MWST-**Rundung** der Excel entspricht. Bei systematischer Rappen-Drift wird die Rundung an Excel angeglichen.

**Reihenfolge:** Erst **2019** (Treue-Gate + Stichprobe) grün, dann die übrigen Jahre. Ergebnis: ein Diff-Report; verbleibende (toleranzgedeckte) Differenzen sind dokumentiert.

## 6. Architektur-Einheiten

- `Datenbank/import/extract_journal.py` — liest Sheet Journal, filtert `datum < 2025-12-01`, transformiert (Mapping §2.1 + netto/MWST §2.2), gibt strukturierte Zeilen aus.
- `Datenbank/migrations/NNN_konten_fehlend_historie.sql` — ergänzt die 5 fehlenden Konten (§3).
- Batch-Insert in `buchungen` (via MCP `execute_sql`, gesteuert aus dem Import-Lauf).
- `Datenbank/import/validate_import.py` — Referenz aus Journal + Vergleich gegen importierte `buchungen`, Diff-Report (§5A).

Jede Einheit hat eine klare Aufgabe und ist einzeln ausführbar.

## 7. Nicht im Scope
- Korrektur der bekannten Fehler (8090/9100, MWST-Rückbuchung bei Abschreibung, negative NBU-Salden etc.) → **Phase 2**.
- Beleg-Scans/Ablage, Verknüpfung Scan↔Buchung → Phase 3.
- camt-Ausbau, Zahlungsdatei → Phase 4.
- Import der Geschäftsfälle/Vorlagen aus Excel (das App-Modell nutzt eigene, optimierte Geschäftsfälle aus Phase 0a; der Import übernimmt nur die fertigen Journal-Soll/Haben).

## 8. Erfolgskriterien
- Alle 14'552 Journal-Zeilen (< Dez 2025) sind als `buchungen` importiert (Zeilenanzahl + Brutto-Summe stimmen mit dem Journal überein).
- Treue-Gate grün: per-Konto-Saldo (Jahresenden) und per-Jahr-ER der App stimmen mit der Journal-Referenz überein (|Diff| ≤ 0.05/Konto; alle Diffs geloggt).
- Stichprobe gegen Excel-Bilanz bestätigt die Rundung.
- Native Buchungen ab Dez 2025 unverändert; Import reproduzierbar/reversibel.
