# Design: Automatische Zahlungsübernahme & Rechnungskontrolle aus camt.053

**Datum:** 2026-06-08
**Status:** Design freigegeben (Daniel), Spec zur Review
**Autor:** Claude + Daniel Projer

## 1. Ziel & Kontext

Daniel lädt künftig **einmal pro Monat** den GKB-Bankauszug (camt.053, Konto IBAN CH66…0601) in die App. Die App soll danach **selbständig**:

1. Alle Zahlungen in die Buchhaltung übernehmen (Buchungen erstellen).
2. Die **Rechnungskontrolle** durchführen: eingehende Kundenzahlungen den offenen Rechnungen zuordnen und diese auf `bezahlt` setzen.

Was nicht eindeutig zugeordnet werden kann, geht **nie** in eine falsche Buchung, sondern in eine **Prüfliste**, die Daniel manuell auflöst.

### Bestehende Infrastruktur (wird wiederverwendet)
- `Camt053Parser` — camt.053 → `CamtStatement` (wird **erweitert**).
- `CamtBetriebMatcher` — Fuzzy-Match Parteiname → Betrieb.
- `CamtImportService` — Buchung + Bankbeleg-PDF (wird **erweitert/abgelöst**).
- `ZahlungsdifferenzService.verbuchen` / `.verbuchenSammel` — Zahlungseingang inkl. Über-/Unterzahlung, Skonto, 5-Rappen-Rundung. **Bereits vorhanden** — Kern für Teil-/Sammelzahlungen.
- `HeinekenBuchungService.createZahlungseingang` — Heineken-Rechnung → bezahlt.
- `BankbelegPdfService` — Bankbeleg-PDF.
- `BuchungsVorlage` — Konten-Vorlagen (soll/haben/MwSt) für Auto-Buchung.

## 2. Grundsatzentscheidungen (mit Daniel geklärt)

| Thema | Entscheidung |
|---|---|
| **Stichtag** | Automatik gilt nur für Transaktionen mit **Buchungsdatum ≥ 01.07.2026**. Alles davor bleibt im bestehenden System (inkl. ~498 alte offene Rechnungen). |
| **Datei-Umfang** | Künftig nur „letzter Monat". Dedup trotzdem robust bauen (Datei darf gefahrlos doppelt hochgeladen werden). |
| **Automatik-Level** | Eindeutige Treffer auto-buchen, unklare → Prüfliste. |
| **Rechnungs-Match** | Teil- und Sammelzahlungen unterstützt. |
| **Ausgaben** | Auto-Buchen per Regelwerk (Empfänger → Buchungsvorlage). |
| **Heineken-Eingang** | Heineken-Monatsabrechnung → bestehender `bezahlt`-Workflow. |

## 3. Architektur — Pipeline

```
camt-Upload (XML)
  → Camt053Parser (erweitert)      Sammelaufträge splitten, ESR/QR-Ref, Tx-Schlüssel
  → Stichtag-Filter                nur Buchungsdatum ≥ 01.07.2026 → Automatik
  → Dedup                          bereits verarbeitete Tx überspringen
  → Klassifizierer                 jede Tx → genau eine Kategorie
  → ┬ Eindeutig → Auto-Booker      Buchung(en) + Rechnung-Update + Bankbeleg-PDF
    └ Unklar    → Prüfliste        persistent, manuelle Auflösung
  → Ergebnis-Report
```

Jede Komponente hat **einen** Zweck, ist isoliert testbar und kommuniziert über klar definierte Datentypen (`CamtTransaction`, `TxKategorie`, `MatchErgebnis`).

## 4. Komponenten

### 4.1 Parser-Erweiterung (`Camt053Parser`)
**Heute:** liest pro `<Ntry>` nur die **erste** `<TxDtls>` → Sammelaufträge (eine Bankbuchung = mehrere Lieferantenzahlungen) werden falsch erfasst (Betrag = Batch-Total, Partei = nur erste).

**Neu:**
- Pro `<Ntry>` **alle** `<TxDtls>` als je eine `CamtTransaction` ausgeben (Batch-Split). Bei nur einer TxDtls wie bisher.
- Strukturierte Referenz lesen: `RmtInf/Strd/CdtrRefInf/Ref` (ESR/QR/ISR) zusätzlich zu `Ustrd`.
- Eindeutiger **Transaktions-Schlüssel** pro (Teil-)Tx:
  1. `TxDtls/Refs/AcctSvcrRef` (enthält `/n`-Suffix, z.B. `ZV20230103/569426/1`), sonst
  2. Komposit-Hash aus `BookgDt + Amt + CdtDbtInd + Parteiname + (Ref|EndToEndId)`.
- Neue Felder auf `CamtTransaction`: `txKey` (String), `strukturierteReferenz` (String?), `isBatchChild` (bool).

### 4.2 Stichtag-Filter
- Konstante `kCamtAutomatikStichtag = DateTime(2026,7,1)`.
- Transaktionen mit `bookingDate < Stichtag` werden **nicht** automatisiert (Kategorie `vorStichtag`, in UI ausgegraut). Verhindert Kollision mit dem bestehenden System.

### 4.3 Dedup / Idempotenz
- Schon verarbeitete Tx werden über `txKey` erkannt und übersprungen.
- `txKey` wird auf der erzeugten `Buchung` gespeichert (Feld `camt_tx_key`, neu) **und** auf Prüflisten-Einträgen.
- Vor dem Verarbeiten: Set aller existierenden `camt_tx_key` laden → O(1)-Check.

### 4.4 Klassifizierer
Jede Tx ab Stichtag → genau eine Kategorie:

| Kategorie | Erkennung | Zielaktion |
|---|---|---|
| `kundenzahlung` | CRDT + Betrieb erkannt (`CamtBetriebMatcher`) | Rechnungs-Matcher (4.5) |
| `heinekenEingang` | CRDT + Parteiname enthält „Heineken" | Heineken-Pfad (4.6) |
| `bargeldEinzahlung` | CRDT + `AddtlNtryInf` enthält „Geldautomaten"/„Posteinzahlung"/„SIX Token" | Regel „Bank an Kasse" (4.7) |
| `ausgabe` | DBIT + Regel-Treffer (4.7) | Auto-Buchung via Vorlage |
| `saldovortrag` | `AddtlNtryInf` = „Saldovortrag" | ignorieren (keine Buchung) |
| `unbekannt` | nichts trifft eindeutig | Prüfliste (4.8) |

### 4.5 Rechnungs-Matcher (Kundenzahlungen) — NEU
Eingänge tragen **keine** Referenznummer → Match über **Betrieb + Betrag** gegen offene Rechnungen (`zahlungsstatus ∈ {offen, gesendet}`) des erkannten Betriebs, mit Buchungsdatum-Plausibilität.

Logik (5-Rappen-genau):
1. **Genau 1 offene Rechnung, Betrag = Zahlbetrag** → Auto: `ZahlungsdifferenzService.verbuchen` + Rechnung `bezahlt`, `zahlung_eingegangen_am`, `zahlung_betrag`.
2. **Summe einer eindeutigen Teilmenge offener Rechnungen = Zahlbetrag** → Auto: `verbuchenSammel` + alle `bezahlt`. (Eindeutig = nur eine Kombination ergibt die Summe; sonst Prüfliste.)
3. **Betrag weicht ab** (Über-/Unter-/Teilzahlung, Skonto) → **Prüfliste** mit Vorschlag (wahrscheinlichste Rechnung[en]); nach Bestätigung läuft die vorhandene Differenz-Logik.
4. **Betrieb unklar / kein plausibler Betrag** → **Prüfliste**.

> Buchungsdatum: `ZahlungsdifferenzService` nutzt heute `DateTime.now()`. **Anpassung:** optionaler `datum`-Parameter, damit das echte Valuta-/Buchungsdatum der Bank verwendet wird.

### 4.6 Heineken-Pfad — NEU
- CRDT von „Heineken Switzerland AG" → passende `rechnungstyp = heineken_monat`-Rechnung über Betrag (und ggf. Periode/`heineken_monat`).
- Treffer → `HeinekenBuchungService.createZahlungseingang` (setzt `bezahlt`, löst Zahlungseingangs-Buchung).
- Kein eindeutiger Treffer → Prüfliste.

### 4.7 Ausgaben-Regelwerk — NEU (Phase 2)
- Neue Tabelle `camt_regel`: **Empfänger-Muster (Name-Substring und/oder Cdtr-IBAN) → `buchungs_vorlage_id`**, plus Priorität.
- Beim Import: DBIT-Tx trifft Regel → Auto-Buchung mit Konten/MwSt der Vorlage; `txKey` gespeichert; Bankbeleg-PDF.
- Kein Treffer → Prüfliste, Button **„Regel anlegen"** (einmal einrichten, danach automatisch).
- Startregeln aus den wiederkehrenden Empfängern: Heineken-Franchise, AXA (BVG/Sachvers.), Ausgleichskasse (AHV), ESTV (MwSt), Steuerverw. GR, Suva, Swisscom/Sunrise, Daniel Proyer (GF-Lohn), Bargeld-Einzahlung (Bank an Kasse), Bank-„Abschluss" (Bankspesen/Zinsen).
- **Konkrete Kontonummern** legt Daniel beim Regel-Anlegen fest (bzw. via vorhandene `BuchungsVorlage`-Stammdaten) — nicht im Code hartkodiert.

### 4.8 Prüfliste — NEU, persistent
- Neue Tabelle `camt_pruefliste`: offene/mehrdeutige Tx überleben zwischen Sessions.
- Felder: `tx_key`, Rohdaten der Tx (Datum, Betrag, Richtung, Parteiname, Referenz, Roh-Kategorie), `vorschlag` (JSON: Betrieb/Rechnung[en]/Vorlage), `status` (`offen`/`erledigt`/`ignoriert`), `fehlertext`.
- UI: Liste mit Vorschlag; Daniel wählt Betrieb/Rechnung(en)/Vorlage → „Verbuchen" → erzeugt Buchung(en) (gleiche Services), markiert `erledigt`.
- Bei Verarbeitungsfehler einer Tx: Tx → Prüfliste mit `fehlertext` (Import bricht nie ab).

### 4.9 Auto-Booker
- Orchestriert für eindeutige Tx: passende Buchung(en) erstellen (über `ZahlungsdifferenzService` / `HeinekenBuchungService` / Vorlage), Rechnungsstatus aktualisieren, Bankbeleg-PDF anhängen, `txKey` persistieren.
- Idempotent: prüft `txKey` und vorhandene `zahlung`-Buchungen pro Rechnung (Letzteres macht `verbuchenSammel` bereits).

## 5. Datenmodell (neue/erweiterte Tabellen)

- `buchungen`: + Spalte `camt_tx_key TEXT NULL` (Index) — Dedup.
- `camt_regel` (neu): `id, user_id, bezeichnung, match_name TEXT NULL, match_iban TEXT NULL, buchungs_vorlage_id, prioritaet INT, ist_aktiv BOOL, created_at, updated_at`.
- `camt_pruefliste` (neu): `id, user_id, tx_key UNIQUE, booking_datum, betrag, richtung, partei_name, referenz, kategorie, vorschlag_json, status, fehlertext, created_at, updated_at`.
- Migrationen unter `Datenbank/migrations/` (durchnummeriert), Isar-Local-Models nur falls offline-relevant (Prüfliste/Regel: vorerst nur Supabase/Web, da Buchhaltung ohnehin online genutzt wird — final beim Plan entscheiden).

## 6. Fehlerbehandlung
- Pro-Tx-Isolation: ein Fehler stoppt den Lauf nicht; betroffene Tx → Prüfliste mit Fehlertext.
- Doppel-Upload: durch `txKey`-Dedup unschädlich.
- Parser-Fehler (ungültiges XML): klare Meldung, kein Teil-Import.

## 7. Out of Scope
- Rückwirkende Verarbeitung vor 01.07.2026 (bewusst, bleibt im Altsystem).
- Corona-Kredit / Konto …602 (vor Stichtag vollständig getilgt — tritt in Automatik nicht mehr auf; etwaige künftige Überträge fallen sicher in die Prüfliste).
- Automatische Lohnabrechnung (Daniel-Proyer-Lohn wird als Aufwand gebucht, nicht abgerechnet).

## 8. Phasen
- **Phase 1 (Rechnungskontrolle scharf):** Parser-Erweiterung, Stichtag-Filter, Dedup, Klassifizierer, Rechnungs-Matcher (Kundenzahlung), Heineken-Pfad, Prüfliste, Auto-Booker, Ergebnis-Report.
- **Phase 2 (Ausgaben):** `camt_regel`-Regelwerk + „Regel anlegen"-UI + Startregeln, Bargeld-Einzahlung, Bank-Abschluss.

## 9. Tests
- Parser: Sammelauftrag-Split (3 TxDtls → 3 Tx), ESR-Ref-Extraktion, txKey-Eindeutigkeit, Stichtag-Grenze.
- Matcher: exakt-1, Sammelsumme-eindeutig, Sammelsumme-mehrdeutig→Prüfliste, Differenz→Prüfliste, kein Betrieb→Prüfliste.
- Dedup: gleiche Datei zweimal → keine Doppel-Buchung.
- Heineken: Betrag/Periode-Match → bezahlt.
- Mit anonymisierten Beispiel-Transaktionen aus der realen camt-Datei.
