# Gesamtkonzept: Buchhaltung in der App (SBS Projer GmbH)

**Datum:** 2026-06-09 · **Status:** Konzept zur Freigabe durch Daniel
**Art:** Übergeordnetes Gesamtkonzept (Roadmap). Jeder der 5 Bausteine erhält später eine **eigene** detaillierte Spec + Umsetzungsplan.

---

## 1. Kontext & Ausgangslage

Die App soll künftig die **vollständige, korrekte Buchhaltung** der SBS Projer GmbH übernehmen. Grundlage sind zwei vollständig analysierte Quellen (09.06.2026):

- **Belegseite:** 17 gescannte Belegkategorien (~700 Belege). Details siehe Memory [[rechnungserkennung_historik]].
- **Buchhaltungsseite:** die bestehende Excel-Buchhaltung `00_Buchhaltung/00_SBS_Projer_70.xlsm` — bereits **vollständig digital & doppelt geführt**:
  - **Kontenrahmen** (61 Konten, KMU-Kontenrahmen)
  - **Geschäftsfälle** (88 Buchungsvorlagen: Soll/Haben/MWST-Konto/MWST-Satz/Belegordner)
  - **Journal** (15'452 Buchungen, 27.03.2019 – Mai 2026; eine Zeile pro Buchung mit strukturiertem Beleg-Schlüssel `<Belegordner>_<YYYY_MM_DD>_<Kürzel>_<8-stellig Betrag>`)
  - **Hauptbuch / Bilanz / Erfolgsrechnung** (aus dem Journal abgeleitet)

**Wichtige Randbedingungen (vom Auftraggeber):**
- Daniel hat wenig Buchhaltungswissen → die App muss **führen** und Fehler verhindern.
- Die bestehende Buchhaltung enthält **mit Sicherheit Fehler** → finden & korrigieren.
- Viele **offene Forderungen müssen abgeschrieben** werden (Debitoren per 31.12.2025 = 99'037).
- **MWST-Abrechnung** muss korrekt verbucht/angepasst werden.
- **Zukünftig** sollen Eingangsrechnungen **über Kreditoren** gebucht werden (nicht mehr direkt).
- Falls möglich: **wöchentliche Zahlungsdatei** fürs e-Banking erzeugen.

## 2. Zielbild

Die App wird zum durchgängigen Buchhaltungs-Werkzeug:

**Beleg scannen → App schlägt Buchung vor → Daniel bestätigt → Zahlungen per Datei auslösen → Bankabgleich (camt) bucht aus → Auswertungen (Bilanz / Erfolgsrechnung / MWST) auf Knopfdruck.**

Alles korrekt, nachvollziehbar, geführt. Das Excel wird nach dem Import zur **eingefrorenen Historie**.

## 3. Grundsatzentscheide (bestätigt)

| # | Entscheid | Wahl |
|---|---|---|
| G1 | Bausteine & Reihenfolge | 5 Phasen, Reihenfolge 0 → 4 |
| G2 | Buchungs-Modell | **Geschäftsfall (was) + Zahlungsweg (wie)** getrennt |
| G3 | Bestehende Konten/Vorlagen | kritisch **optimieren/bereinigen**, nicht 1:1 kopieren |
| G4 | Ort der Bereinigung | **in der App** nach dem Import (App = auch Aufräum-Werkzeug, mit Spur) |
| G5 | Go-Live / Umstellung | **Datum offen** — wird festgelegt, wenn Fundament + Bereinigung stehen |
| G6 | Abschreibung offene Forderungen | **korrekt abschreiben + Verlustvortrag** (bis 7 J.); keine künstliche 5-Jahres-Streckung; Höhe mit Treuhänder abstimmen |
| G7 | MWST-Methode | **vereinbart** (wie bei ESTV angemeldet) |
| G8 | Zahlungen | App erzeugt `pain.001`-Datei; **Daniel gibt im e-Banking selbst frei** (App löst kein Geld aus) |

## 4. Kern-Datenmodell (optimiert)

1. **Kontenrahmen** — die 61 Konten als Basis, **bereinigt**: fehlende, aber referenzierte Konten ergänzen; unsaubere/ungenutzte prüfen.
2. **Geschäftsfall + Zahlungsweg** — der Geschäftsfall nennt Aufwand-/Ertragskonto + MWST-Behandlung; der **Zahlungsweg** (Kasse 1000 / Bank 1020 / Privat 2260 / **Kreditor 2000**) bestimmt das Gegenkonto. Reduziert ~88 Vorlagen auf ~30 ohne Doppelung; Kreditoren-Weg ist überall verfügbar.
3. **Journal** — eine Zeile pro Buchung (wie heute), strukturierter Beleg-Schlüssel, mit verknüpftem Scan.
4. **Offene Posten als Rückgrat:** **Kreditoren (2000)** für Eingangsrechnungen, **Debitoren (1100)** für Ausgangsrechnungen → jederzeit ersichtlich, was offen / fällig / zu mahnen ist.
5. **MWST datumsabhängig** (7.7 % bis 2023, 8.1 % ab 2024) statt fest verdrahtet; zwei Vorsteuerkonten (1170 Material/Waren/DL, 1171 übriger Betriebsaufwand).
6. **Auswertungen** (Bilanz, Erfolgsrechnung, MWST-Abrechnung) automatisch aus dem Journal.

**Bereits erkannte Vorlagen-Fehler (in Phase 0 zu korrigieren):** GF 30.2 bucht auf nicht existierendes Konto 8090 (→ 8900); GF 30.6 auf 9100 (→ 9010); GF 50 auf 1120 (existiert nicht); GF 15.3/16.3 „Privat" auf 1010 (→ 2260); „Abgeschriebene Rechnungen" (GF 1.9) ohne MWST-Rückbuchung.

## 5. Die 5 Phasen

### Phase 0 · Fundament
Buchhaltungs-Kern in der App: bereinigter Kontenrahmen, Geschäftsfälle + Zahlungsweg, Journal, Kreditoren/Debitoren, automatische Bilanz/Erfolgsrechnung/MWST. Baut auf den bestehenden Buchungs-Bausteinen des camt-Features auf.
**Ergebnis:** das Gerüst steht.

### Phase 1 · Historie importieren
Excel-Journal (15'452 Buchungen) + Konten in die App laden, alte Geschäftsfälle aufs neue Modell mappen. **Abgleich-Check:** App-Bilanz/ER muss exakt den Excel-Zahlen entsprechen.
**Ergebnis:** vollständiger Ist-Zustand in der App, prüfbar.

### Phase 2 · Aufräumen
App **markiert verdächtige Buchungen** (siehe Abschnitt 7). Gemeinsame Korrektur. **Offene Forderungen abschreiben** (nur tatsächlich Uneinbringliches; Zweifelhaftes als Wertberichtigung/Delkredere) **mit korrekter MWST-Rückbuchung**. MWST-Anpassungen. Verlust → Verlustvortrag.
**Ergebnis:** saubere, ausgeglichene Startbilanz.

### Phase 3 · Neu erfassen (Kreditoren)
Rechnung scannen → OCR (Basis: bestehende Edge Function `parse-beleg`) → App schlägt Geschäftsfall + Zahlungsweg „Kreditor" vor → Daniel bestätigt → gebucht als Aufwand + Vorsteuer an **Kreditor 2000**. Dazu **Beleg-Ablage** (Scan gespeichert, verknüpft, kategorisiert; mehrseitig/Trennblatt-Logik wie analysiert).
**Ergebnis:** neue Rechnungen korrekt & per Kreditor erfasst, Beleg am richtigen Ort.

### Phase 4 · Zahlen & Abgleich
**Wöchentliche Zahlungsdatei** (`pain.001`, ISO 20022) mit fälligen Kreditoren → Daniel lädt sie im GKB-e-Banking hoch und gibt frei. **camt-Import** gleicht Ein-/Ausgänge ab, markiert bezahlt, bucht Kreditoren/Debitoren aus. **Quartalsweise MWST-Abrechnung** auf Knopfdruck.
**Ergebnis:** ein Klick statt manuelles Zahlen; Bank & Buchhaltung synchron.

## 6. Querschnitt-Themen

- **MWST bei Abschreibung:** beim Abschreiben offener Kundenrechnungen wird die damals (vereinbart) abgerechnete MWST korrekt zurückgeholt (Korrektur der alten Vorlage GF 1.9).
- **Zahlungsdatei `pain.001`:** Standard-ISO-20022-Format fürs GKB-e-Banking; App erzeugt nur die Datei, **Freigabe/Auslösung durch Daniel** (volle Kontrolle, kein automatischer Geldfluss).
- **camt-Abgleich:** baut auf dem bestehenden camt-Feature auf; erweitert um Kreditoren-Ausgleich und behördliche Eingänge (Prämien-Rückerstattungen, Unfall-Taggeld, Corona-EO, Kurzarbeit) — diese sind **keine** Kundenzahlungen.
- **Beleg-Ablage:** Scans in der App (Supabase Storage), jeder Beleg mit Buchung verknüpft; die 17 Scan-Kategorien und die Belegordner-Taxonomie der Buchhaltung (010_Reinigung … 990_Firmengruendung) werden zu **einem** Schema zusammengeführt.
- **Privatkonto 2260 (KK Aktionär):** Saldo „Firma schuldet Daniel" (per 31.12.2025 ≈ 15'973) wird transparent geführt; Ausgleich (Rückzahlung/Verrechnung) entscheidet Daniel.
- **Behörden-Disambiguierung fürs Matching:** ESR/QR-Referenz-Präfixe trennen gleichnamige Empfänger (AXA ×3 Verträge, Gemeinde privat/Betrieb, Heineken in 3 Richtungen). Siehe [[camt_buchhaltung]].

## 7. Bekannte Audit-Signale (Eingang Phase 2)

Aus der Bilanz per 31.12.2025 bereits sichtbar:
- **Bilanz unausgeglichen:** Aktiv 118'084 vs. Passiv 103'467 (Differenz ≈ 14'616 — Jahresergebnis 2025 noch nicht verbucht / Abschluss offen).
- **Debitoren 1100 = 99'037** (84 % der Aktiven) → Abschreibungs-Thema.
- **Negative Salden:** 2273 NBU −4'482, 2202 MWST-Abrechnung −5'282 (Vorzeichen/Saldo prüfen).
- **2260 KK Aktionär = 15'973** (aus privat bezahlten Auslagen).
- **2500 Corona-Kredit = −1.35** (praktisch getilgt ✓).
- **Vorlagen-Fehler** (siehe Abschnitt 4) — beim Import als Korrekturen einarbeiten.

Weitere Lohn-/Versicherungs-Themen (für die Detailprüfung): „Vier-Löhne-Knoten" (Lohnausweis-Brutto vs. BVG-/SUVA-/SVA-Basis), Verzugszins-/Mahnkosten durch chronisch verspätete Zahlungen.

## 8. Offene Punkte (später zu entscheiden)

- **Go-Live-Datum** der App als führendes System (G5).
- **Genaue Abschreibungs-Höhe & -Methode** — mit Treuhänder abstimmen (G6).
- **Ersetzt die App das Excel vollständig** oder Parallelbetrieb für eine Übergangszeit?
- Detailfragen je Baustein → in der jeweiligen Phasen-Spec.

## 9. Nächste Schritte

1. Diese Gesamtkonzept-Spec freigeben.
2. Detail-Brainstorming + Spec + Umsetzungsplan für **Phase 0 (Fundament)** starten.
3. Danach Phase für Phase (jede mit eigener Spec → Plan → Umsetzung).
