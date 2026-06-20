# camt-Forderungsabgleich + Datei-Archiv — Design

**Datum:** 2026-06-20 · **Status:** Spec zur Freigabe durch Daniel
**Kontext:** Teilprojekt 2 der Forderungen-Architektur (TP1 Forderungen-Historie-Import ist abgeschlossen).

---

## 0. Ausgangslage (verifiziert)
- **Offene Forderungen:** 1'013 Kundenrechnungen `zahlungsstatus ∈ {offen, gesendet}` (CHF 105'240.95), grossteils historisch (Import TP1). Sie haben **keinen** verbuchten Zahlungseingang (das Excel hatte keinen 020-Beleg → keine Journal-Buchung).
- **Bereits bezahlte Forderungen** (3'425) sind im Journal verbucht — **dürfen nicht** erneut angefasst werden (Doppelbuchung).
- **Voll-camt-Datei** vorhanden (`…20260620…941625813.xml`, camt.053.001.04, GKB IBAN CH6600774010376550601): **2'623 Gutschriften**, 2019–19.06.2026, Summe CHF 742'730. Zahlername steht im Text „Gutschrift <Name>" (nicht im strukturierten `Nm`).
- **Bestehende camt-Pipeline** (Phase 1+2, `lib/services/camt/`): Parser, Klassifizierer, `CamtBetriebMatcher` (exakt→contains→Wort-Overlap), `RechnungMatcher` (Subset-Summe, max 20 Kandidaten/4er-Kombi), `ZahlungsdifferenzService.verbuchenSammel` (Buchung Bank 1020 ← Debitoren 1100 + Über-/Unterzahlung 3805/8000, 5-Rappen-Rundung), Prüfliste, Auto-Booker (Going-forward, Stichtag bisher 01.07.2026 → **wird auf heute 20.06.2026 gesenkt**, da ab heute alles über die App läuft).

---

## 1. Ziel
1. Die **offenen** Forderungen gegen die echten Bank-Gutschriften abgleichen: eindeutig Zahlbares automatisch schliessen + verbuchen, den Rest manuell zuordnen — „damit nichts vergessen geht".
2. **Alle hochgeladenen camt-Dateien archivieren** und die **erfassten Zeiträume** anzeigen (Lücken/Ferien sichtbar).
3. **Wöchentliche Erinnerung**, eine neue camt-Datei hochzuladen.

Der **Stichtag** des Going-forward-Auto-Bookers wird auf **heute (20.06.2026)** gesetzt (`camt_stichtag.dart`): ab heute wird alles über die App erledigt. Die forderungs-getriebene Abgleich-Engine deckt den **Backlog davor** ab (offene Forderungen bis 19.06.2026). Beide teilen sich Matcher/Buchungslogik; Dedup über `txKey` verhindert Doppelverarbeitung am Übergang.

---

## 2. Komponenten
- **`Camt053Parser`** (bestehend, ggf. kleine Ergänzung): Gutschriften → `{txKey, datum, betrag, zahlername, referenz}`. **Verifizieren**, dass der Zahlername aus „Gutschrift <Name>" (AddtlNtryInf/Ustrd) gezogen wird; falls nicht → ergänzen. Saldovortrag/Nicht-Zahlungs-Einträge ignorieren.
- **`ForderungsAbgleichService`** (neu): die forderungs-getriebene Pull-Logik (§3).
- **`CamtBetriebMatcher`** (bestehend): Zahlername → Betrieb.
- **`RechnungMatcher`** (bestehend): eindeutige Subset-Summe offener Forderungen = Zahlbetrag.
- **`ZahlungsdifferenzService.verbuchenSammel`** (bestehend): Verbuchung + Status `bezahlt`.
- **`CamtDateiRepository` + Tabelle `camt_dateien`** (neu): Archiv + Zeiträume (§6).
- **Screens:** `CamtAbgleichScreen` (neu) für den Abgleich-Lauf + manuelle Zuordnung; `CamtDateienScreen` (neu) für die Zeitraum-Übersicht; Dashboard-Hinweis (§7).

---

## 3. Match-Logik (forderungs-getrieben)
Pro **Betrieb mit ≥1 offenen Forderung**:
1. Kandidaten-Gutschriften = camt-Gutschriften, deren Zahlername via `CamtBetriebMatcher` auf diesen Betrieb matcht und die noch nicht verbraucht sind.
2. Pro Gutschrift (chronologisch): `RechnungMatcher.match(zahlbetrag, offeneForderungenDesBetriebs)` → eindeutige Teilmenge (inkl. **Sammelzahlung** über mehrere offene Forderungen, Rappen-exakt).
3. **Eindeutig** → Auto-Vorschlag: Forderung(en) `bezahlt`, `zahlung_eingegangen_am` = Buchungsdatum der Gutschrift, Buchung Bank←Debitoren; Gutschrift + Forderungen als „verbraucht" markieren.
4. **Mehrdeutig / kein exakter Treffer** → Arbeitsliste „manuell zuordnen".

**Toleranzen:** Betrag Rappen-exakt (über-/unterzahlung via verbuchenSammel separat). Datum egal (Zahlung kann lange nach Rechnung kommen). Betrieb-Score < voll → trotzdem Vorschlag, aber als „unsicher" markiert.

---

## 4. Ergebnis-Kategorien + UI (`CamtAbgleichScreen`)
camt hochladen → **Vorschau** (kein Schreibvorgang) mit drei Gruppen:
- **🟢 Auto-gematcht** — Gutschrift ↔ Forderung(en) (+ Betrieb, Datum, Betrag). Aktion: „Alle verbuchen" oder einzeln bestätigen/ablehnen.
- **🟡 Manuell zuordnen** — Gutschriften eines Betriebs ohne eindeutigen Treffer **und** dessen restliche offene Forderungen. Dialog: Gutschrift(en) ↔ Forderung(en) auswählen → Über-/Unterzahlung wird live angezeigt → verbuchen.
- **🔴 Keine Zahlung gefunden** — offene Forderungen, zu denen keine Gutschrift passt → bleiben offen (echt unbezahlt / abzuschreiben). Nur informativ.

Verbuchung erst auf Bestätigung; danach verschwinden die erledigten Posten aus der Vorschau (oder Re-Run).

---

## 5. Buchung & Sicherheit
- **Nur offene Forderungen** werden geschlossen → keine Doppelbuchung bezahlter (deren Zahlung ist im Journal).
- Schliessen erzeugt den **fehlenden Zahlungseingang** (Bank 1020 ← Debitoren 1100) → korrigiert auch Bank-/1100-Saldo.
- **Dedup:** jede Gutschrift nur einmal verbraucht (`txKey` in `camt_transactions`/verbrauchte-Liste); `verbuchenSammel` schützt zusätzlich über `beleg_typ='zahlung'`-Duplikatcheck.
- **Pagination beachten:** offene Forderungen über `RechnungRepository.getAll()` (bereits paginiert) laden.

---

## 6. Camt-Datei-Archiv + erfasste Zeiträume
**Tabelle `camt_dateien`:** `id, user_id, dateiname, hochgeladen_am, zeitraum_von date, zeitraum_bis date, iban text, anzahl_eintraege int, anzahl_gutschriften int, storage_pfad text, created_at`.
- Beim Upload (Abgleich **und** Going-forward): XML in Bucket **`camt-dateien`** ablegen (`{user_id}/{dateiname}`) + Metadaten-Record. `zeitraum_von/bis` aus Statement-`FrToDt` bzw. Min/Max der Buchungsdaten; Anzahl aus dem Parser.
- **`CamtDateienScreen`:** Liste aller Dateien chronologisch nach `zeitraum_von`, mit Zeitraum + Anzahl Gutschriften; **Lücken** zwischen aufeinanderfolgenden Zeiträumen hervorheben (> ~3 Tage Lücke = Warnhinweis). Original-XML per signed URL herunterladbar. Einstieg über das Buchhaltungs-Dashboard.
- Dedup-Hinweis: gleiche Datei (gleicher Dateiname/IBAN+Zeitraum) erneut hochgeladen → Hinweis „bereits erfasst" (kein zweiter Record).

---

## 7. Wöchentliche Upload-Erinnerung
- Dashboard-Kachel/Banner, wenn `max(camt_dateien.zeitraum_bis)` **> 7 Tage** zurückliegt (oder noch keine Datei): „Letzter Bankauszug bis <Datum> — neuen camt-Auszug hochladen" mit Direktlink zum Upload.
- Bewusst simpel: Check beim Laden des Buchhaltungs-Dashboards, keine Push-Notifications/Hooks.

---

## 8. Datenmodell-Änderungen
- **Neu** Tabelle `camt_dateien` (§6) + Storage-Bucket `camt-dateien` (privat).
- Keine Änderung an `rechnungen` nötig (Felder `zahlungsstatus`, `zahlung_eingegangen_am`, `zahlung_betrag`, `einzahlungsbeleg` bestehen). `einzahlungsbeleg` ist auf den **offenen** Forderungen leer → **kein** Match-Anker hier (nur Party-Name + Betrag).
- Verbrauchte Gutschriften: über bestehende `camt_transactions`/txKey-Mechanik oder eine leichte „verbraucht"-Markierung (Detail im Plan).

---

## 9. Abgrenzung (YAGNI / Nicht-Scope)
- **Kein Umbau** der bestehenden Going-forward-Push-Pipeline — nur der **Stichtag** wird auf heute (20.06.2026) gesenkt (eine Konstante in `camt_stichtag.dart`).
- Kein Abgleich der bereits **bezahlten** historischen Forderungen (sind verbucht).
- Keine Ausgaben-/Belastungs-Verarbeitung in diesem TP (nur Gutschriften → Forderungen). Belastungen laufen weiter über die bestehende Ausgaben-/Regel-Logik.
- Keine Push-Notifications; Erinnerung nur als Dashboard-Hinweis.
- Keine automatische Abschreibung der „keine Zahlung gefunden"-Forderungen (nur Anzeige).

**Zukünftige Erweiterung (eigenes TP, nicht hier):** Für die ab heute selbst generierten Mail/Post-Rechnungen eine **eindeutige QR-Referenz** vergeben + auf der Rechnung speichern. Dann matcht der Going-forward-Abgleich **deterministisch** über `CamtTransaction.strukturierteReferenz` → Rechnung (vor dem Name+Betrag-Fallback). Erfordert: QR-Referenz-Generierung beim Rechnung/QR-Erstellen + Feld `rechnungen.qr_referenz` + Referenz-First-Matching im Matcher.

---

## 10. Erfolgskriterien
- Ein camt-Upload erzeugt eine Vorschau mit 🟢/🟡/🔴-Gruppen; eindeutige Treffer lassen sich mit einem Klick verbuchen (Forderung `bezahlt` + Buchung Bank←Debitoren).
- Mehrdeutige Fälle sind über einen Dialog manuell zuordenbar + verbuchbar (inkl. Sammelzahlung-Split).
- Offene Forderungen ohne Zahlung sind klar gelistet.
- Alle hochgeladenen camt-Dateien sind archiviert; die `CamtDateienScreen` zeigt erfasste Zeiträume + Lücken.
- Dashboard erinnert nach > 7 Tagen ohne neuen Auszug.
- Keine Doppelbuchungen (bezahlte Forderungen unangetastet; Dedup über txKey).

---

## 11. Im Plan zu klärende Details
- Parser: Zahlername-Extraktion aus „Gutschrift <Name>" verifizieren/ergänzen; Saldovortrag-/Storno-Einträge filtern.
- „Verbraucht"-Markierung der Gutschriften (txKey-Liste vs. Tabelle).
- Genauer Lücken-Schwellwert in der Zeitraum-Übersicht.
- camt.053.001.04-Namespaces gegen den bestehenden Parser prüfen (gleiche Bank/Format wie bisher → vermutlich kompatibel).
- Performance bei ~1'013 offenen Forderungen × ~2'623 Gutschriften (pro Betrieb klein → unkritisch; Party-Match einmalig vorgruppieren).
