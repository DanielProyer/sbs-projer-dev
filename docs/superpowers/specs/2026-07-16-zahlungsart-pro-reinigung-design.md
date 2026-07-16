# Zahlungsart pro Reinigung — Design

**Datum:** 16.07.2026 · **Status:** Von Daniel abgenommen (mündlich im Chat), Spec zur Review

## Problem

Die Zahlungsart lebt heute NUR am Betrieb (`betriebe.rechnungsstellung`). Beim Abschluss
einer Reinigung wird sie von dort gelesen — mit zwei Konstruktionsfehlern, die zusammen
die 38 fehlenden Rechnungen (26.06.–13.07.2026, CHF 3'656.05) verursacht haben:

1. **Falsche Quelle:** Buchung und Rechnung entstehen aus `betrieb.rechnungsstellung`
   zum Abschluss-Zeitpunkt. 34 der 38 Reinigungen passierten, als die Betriebe noch
   `heineken` waren (Daniel stellte die Serie erst am 10.07. auf Tresen um) — und
   `heineken` fällt in BEIDEN Services lautlos durch (`return null`): keine Rechnung,
   keine Buchung, keine Ausnahme, keine Sequenznummer. Die restlichen 4 (13.07.)
   nutzten einen **veralteten Cache**: Der Abschluss-Dialog las `_betrieb` aus dem
   Formular-Cache, obwohl die DB längst Tresen sagte.
2. **Stiller Rückschreib-Effekt:** Der Abschluss-Dialog schrieb die gewählte Art
   dauerhaft in den Betrieb zurück (`BetriebRepository.save`) — was Daniel als
   „für diese Reinigung bestätigen" versteht, änderte die Einstellung für alle
   künftigen Reinigungen.

**Kontext Daniel:** Die Betriebs-Einstellung ist als *Default* gedacht (die meisten
Betriebe zahlen immer gleich). Aktuell läuft eine aktive Migration Tresen→Mail
(weniger Papier, weniger Fehler; Mail-Rechnung mit QR → camt-Abgleich erkennt
Einzahlungen automatisch). Betriebe wechseln gelegentlich die Art (Bar↔EZS,
Tresen→Mail). Heineken-Lokale (14 Konten) bleiben monatlich abgerechnet —
**nie** Einzelrechnung.

## Entscheid (Kern)

**Die Zahlungsart wird pro Reinigung gespeichert (`reinigungen.zahlungsart`) und
NUR dieser Wert ist für Verbuchung und Rechnungserstellung massgebend.**
Der Betriebs-Wert bleibt als Vorbelegung erhalten. Der Rückschreib-Effekt wird
explizit (Checkbox) statt still.

## 1. Datenmodell

- **Migration 144:** `ALTER TABLE reinigungen ADD COLUMN zahlungsart text;`
  CHECK auf dieselben Werte wie `betriebe.rechnungsstellung`:
  `barzahlung, rechnung_tresen, rechnung_mail, rechnung_post, jahresrechnung, heineken`
  (nullable — Altbestand bleibt NULL).
- Entity-Erweiterung nach Projekt-Checkliste (bestehende Entity, kein Neuaufbau):
  DTO `reinigung.dart`, Isar-Local + Web-Stub + Mapper, `build_runner`, Sync unverändert
  (Feld läuft im normalen Push/Pull mit).
- **Kein Backfill.** Für Alt-Reinigungen gilt die Lesekette
  `reinigung.zahlungsart ?? betrieb.rechnungsstellung` (nur in Lese-Pfaden:
  Detail-Screen-Recovery, Warnung). Alle NEU abgeschlossenen Reinigungen haben den
  Wert immer gesetzt.

## 2. Abschluss-Dialog (reinigung_form_screen)

- Dropdown startet mit `reinigung.zahlungsart ?? betrieb.rechnungsstellung ?? 'rechnung_tresen'`.
  **Der Betrieb wird dafür FRISCH geladen** (`getByServerId`), nicht aus dem
  Formular-Cache — das schliesst den 4er-Fall (veralteter Cache).
- Die Wahl schreibt `reinigung.zahlungsart` und gilt **nur für diese Reinigung**.
- **Checkbox „Auch als Standard für diesen Betrieb übernehmen"** (default AUS).
  Nur wenn angehakt, wird `betriebe.rechnungsstellung` aktualisiert.
  → Migration Tresen→Mail: Daniel wählt Mail + hakt an. Einmalige Ausnahme: Haken weg.
- **Klartext-Zeile** unter dem Dropdown, was der Abschluss auslöst:
  - `rechnung_tresen` → „Rechnung + Einzahlungsschein, Übergabe vor Ort, kein Versand"
  - `rechnung_mail` → „Rechnung per Mail an *kunde@…*" (echte Adresse anzeigen)
  - `rechnung_post` → „Rechnung per Mail an dich (Ausdrucken + Post)"
  - `barzahlung` → „Bar kassiert → Kasse, keine Rechnung"
  - `heineken` → „Keine Einzelrechnung — läuft über die Heineken-Monatsabrechnung"
  - `jahresrechnung` → „Keine Einzelrechnung — läuft über die Jahresrechnung"
- **Mail ohne Kunden-E-Mail** (weder `betrieb_rechnungsadressen.email` noch
  `betriebe.email`): Warnhinweis im Dialog + Textfeld, um die E-Mail sofort zu
  erfassen (gespeichert in `betriebe.email`). Abschluss mit Mail bleibt möglich,
  aber die Lücke ist sichtbar und direkt behebbar.

## 3. Verbuchung & Rechnung lesen die Reinigung

- `ReinigungBuchungService.createFromReinigung`: `rs = reinigung.zahlungsart`
  (Pflicht im Neu-Abschluss-Pfad; Betriebs-Fallback nur für Alt-Daten-Recovery).
- `RechnungService.createFromReinigung`: ebenso.
- `reinigung_form_screen` (Mail-/Post-Versandzweige) und
  `reinigung_detail_screen` (Recovery-Knopf): ebenso, mit Fallback-Kette für Altbestand.
- Der Betrieb wird in diesen Pfaden nur noch für Name/Adresse/E-Mail gebraucht —
  nie mehr für die Entscheidung, WAS gebucht wird.

## 4. Sicherheitsnetz — nie wieder lautlos

- Die Klartext-Zeile (Abschnitt 2) macht den Ausgang VOR dem Abschluss sichtbar.
- **Warnung „Reinigungen ohne Rechnung" wird präziser** (`reinigungen_ohne_rechnung.dart`):
  - Rechnungs-Check auf Basis `zahlungsart ?? betrieb.rechnungsstellung`
    ∈ {tresen, mail, post} statt nur aktueller Betriebs-Einstellung.
  - **Bar-Ausschluss über die tatsächliche Buchung** (von Daniel am 16.07.
    freigegeben): Ist die Reinigung auf **Kasse (1000)** gebucht, gilt sie als bar
    erledigt und wird NICHT geflaggt — auch wenn die Fallback-Kette „tresen" sagt.
    Ohne diesen Ausschluss blieben die 10 Bar-Fehlalarme vom 16.07. bestehen
    (Alt-Reinigungen ohne `zahlungsart`, Betrieb inzwischen Tresen). Nur eine
    **Debitor-Buchung (1100)** erwartet eine Rechnung.
  - **Zusätzlich:** abgeschlossene Reinigungen **ohne einzige Buchung** flaggen
    (ausser Kulanz/Heineken-Monteur und Zahlungsart `heineken`/`jahresrechnung`) —
    fängt die Durchfall-Klasse selbst, nicht nur das Rechnungs-Symptom.
- **Einmaliger Suchlauf bei der Umsetzung:** alle abgeschlossenen Reinigungen ab
  01.12.2025 (quelle ≠ excel_import) mit 0 Buchungen, nicht Kulanz/Heineken-Monteur,
  aktueller Betrieb ≠ heineken → Liste an Daniel zur Entscheidung (Migration läuft,
  es können seit 14.07. weitere Fälle entstanden sein).

## 5. camt-Bezug

- Tresen UND Mail erzeugen eine Rechnung mit deterministischer QR-Referenz
  (aus Reinigungsdatum + Betriebsnummer) → camt Stufe 1 matcht über die Referenz.
- **QR im Reinigungstab** („QR-Zahlung"-Knopf, seltener Direktzahler-Fall, bisher 3
  Kunden, die den Betrag von Hand eintippten): erhält bei Zahlungsart
  tresen/mail/post **dieselbe Referenz** (`qrReferenzAusNummer` auf Basis
  Datum + Betriebsnummer) statt Referenztyp NON. Damit ist auch eine spontane
  Direktzahlung per Referenz camt-zuordenbar. Bei `barzahlung` bleibt der QR
  referenzlos (nur Mitteilung), Verhalten für die Kunden unverändert.
  Bekannte, akzeptierte Grenze: Bei einer Referenz-Kollision bekommt die Rechnung
  ein Suffix, der Tab-QR die Basis-Referenz — extrem selten (2 Reinigungen gleicher
  Betrieb gleicher Tag) und der Betrags-/Betriebs-Match fängt es.

## 6. Ausdrücklich NICHT in diesem Paket

- Heineken bleibt monatlich — keine Einzelrechnung, keine Änderung an
  `HeinekenRechnungService`.
- Kein Backfill von `zahlungsart` auf Alt-Reinigungen.
- Keine Änderung an Störungen/Montagen (eigene Verbuchungspfade).
- Kein Umbau des Betriebs-Formulars (Default-Pflege dort bleibt wie sie ist).

## Fehlerbehandlung & Tests

- Neu-Abschluss ohne gesetzte `zahlungsart` darf nicht vorkommen (Formular setzt sie
  immer); Services behandeln NULL defensiv über die Fallback-Kette + `debugPrint`.
- TDD für die reine Logik: Zahlungsart-Auflösung (`zahlungsart ?? betrieb ?? default`),
  Klartext-Mapping, Warnungs-Filter (inkl. „ohne Buchung"-Zweig), QR-Referenz im Tab
  (Rechnungsart → Referenz gesetzt, bar → NON).
- Manuelle Verifikation durch Daniel: 1× Tresen mit Checkbox aus (Betrieb bleibt),
  1× Mail mit Checkbox an (Betrieb wechselt), 1× Mail ohne E-Mail (Warnung + Feld),
  Warnung zeigt anschliessend nichts Neues.
