# Steuern-Screen, Dokumente-Modul und Abschlussprüfung (Audit neu) — Design

**Datum:** 02.09.2026 · **Status:** von Daniel abschnittsweise freigegeben (Fragen 1–5 + Abschnitte 1–4) · **Bauweise:** generisches Dokumente-Modul mit Steuer-Sicht (Variante 2)

## 1. Ziel

1. Alle Steuerunterlagen 2019 ff. (Steuererklärungen, Jahresrechnungen, Verfügungen, Rechnungen, Mahnungen, Bewertungsmeldungen, Zinsausweise, Lohnausweise) sind in der App abgelegt und pro Jahr abrufbar.
2. Ein Screen **Steuern** unter Buchhaltung zeigt je Jahr Veranlagung (Soll), bezahlte Steuern (Ist), Buchhaltungsgewinn und Dossier-Vollständigkeit; Steuerzahlungen sind fest einem Jahr und einer Steuerart zugeordnet.
3. Der Audit-Screen wird zur **Abschlussprüfung mit Jahreswahl** (Ampel-Regeln) inklusive Bank-Wächter-Detail.

Nicht Teil dieses Vorhabens: Erzeugung der Jahresrechnung (Bilanz/ER mit Vorjahr + Anhang) in der App — bleibt vorerst das reportlab-PDF (`00_Buchhaltung/Jahresrechnung 2025.pdf`).

## 2. Datenmodell

### 2.1 `dokumente` (Migration 182)

| Spalte | Typ | Bemerkung |
|---|---|---|
| id | uuid PK | `uuid_generate_v4()` |
| user_id | uuid NOT NULL | RLS wie `buchungs_belege` |
| bereich | text NOT NULL | CHECK `steuern, versicherungen, vertraege, behoerden, bank, sonstiges` |
| typ | text NOT NULL | kein CHECK; Steuern-Vorschläge: `steuererklaerung, jahresrechnung, veranlagung, rechnung_provisorisch, rechnung_definitiv, mahnung, einspracheentscheid, bussverfuegung, bewertung_stammanteile, zinsausweis, lohnausweis, brief, sonstiges` |
| kategorie | text | Steuern: `bund, kanton, mwst, busse`; andere Bereiche frei (z. B. `suva`, `axa`) |
| jahr | int | Steuer-/Geschäftsjahr, nullbar |
| dokument_datum | date | |
| betrag | numeric(12,2) | nullbar; negativ = Saldo zu Gunsten der Firma |
| referenz | text | Rechnungs-/Verfügungsnummer |
| titel | text NOT NULL | Anzeigename |
| notizen | text | |
| dateiname, dateityp | text NOT NULL | |
| groesse_bytes | int | |
| seiten | int | |
| storage_pfad | text NOT NULL UNIQUE | `$userId/$bereich/$jahr/$id_$dateiname` (jahr fehlt → `ohne-jahr`) |
| buchung_id | uuid FK buchungen ON DELETE SET NULL | Rechnung ↔ Zahlung |
| created_at, updated_at | timestamptz | |

Bucket **`dokumente`** (privat, 20 MB, `application/pdf`, `image/jpeg`, `image/png`), Storage-Policies analog `buchungs-belege` (nur eigener `user_id`-Ordner). Index auf `(user_id, bereich, jahr)`.

### 2.2 `steuerjahre` (Migration 183)

| Spalte | Typ | Bemerkung |
|---|---|---|
| id | uuid PK | |
| user_id | uuid NOT NULL | UNIQUE `(user_id, jahr)` |
| jahr | int NOT NULL | |
| status | text NOT NULL DEFAULT `offen` | CHECK `offen, eingereicht, veranlagt, ermessen` |
| eingereicht_am, veranlagt_am | date | |
| steuerbarer_gewinn, steuerbares_kapital, verlustvortrag_verrechnet | numeric(12,2) | aus der Verfügung; nullbar |
| bund_provisorisch, bund_definitiv, kanton_provisorisch, kanton_definitiv | numeric(12,2) | Kanton = Gewinn + Kapital + Gemeinde + Kultus; nullbar |
| notizen | text | |
| created_at, updated_at | timestamptz | |

### 2.3 `buchungen` (Migration 184)

- `steuerjahr int NULL`, `steuerart text NULL` CHECK `bund, kanton, mwst, busse`.
- View `view_steuerjahr_zahlungen(user_id, steuerjahr, steuerart, bezahlt)`: Summe über nicht stornierte Buchungen mit gesetztem `steuerjahr`; Zahlung = `betrag_brutto`, wenn Soll ∈ {8900, 2208, 2202} und Haben ∈ {1000, 1020}; Rückzahlung = `−betrag_brutto`, wenn Soll ∈ {1000, 1020} und Haben ∈ {8900, 2208, 2202}.

### 2.4 Abgeleitet (Client)

- **Buchhaltungsgewinn je Jahr:** `ErfolgsrechnungService.berechne` (bestehend).
- **Soll/Ist je Steuerart:** provisorisch, definitiv (aus `steuerjahre`), bezahlt (View), offen = definitiv − bezahlt (fehlt definitiv: provisorisch − bezahlt); negativ = Guthaben.
- **Dossier-Vollständigkeit:** Pflicht-Typen je Jahr `steuererklaerung, jahresrechnung, lohnausweis, zinsausweis, veranlagung (bund), veranlagung (kanton)`; für das laufende Jahr nur `jahresrechnung, lohnausweis, zinsausweis`.

## 3. Screens (Smartphone-first, CanvasKit-Regeln: kritische Knöpfe/Zeilen aus `GestureDetector`/`InkWell` + `Container`, keine `ExpansionTile dense`)

### 3.1 Dashboard
Neue `_NavTile` «Steuern» (Icon `account_balance`) → `/buchhaltung/steuern`. Bank-Wächter-Karte erhält Link «Details» → `/buchhaltung/audit?jahr=<laufend>`.

### 3.2 `/buchhaltung/steuern` — `SteuernScreen`
- Summenzeile «Total bezahlte Steuern 2019–heute».
- Eine Karte je Jahr (neu → alt): Jahr, Status-Chip, Zeile *Gewinn (Buchhaltung) · steuerbar · Steuern definitiv (Bund + Kanton)*, Zeile *bezahlt / offen bzw. Guthaben* mit Ampelpunkt (grün ±0.05, rot Schuld, blau Guthaben), Dossier-Zähler «x/y Unterlagen». Jahre = Vereinigung aus `steuerjahre`, Buchungen mit `steuerjahr` und Dokumenten; Tippen → Jahresdetail. Knopf «Jahr anlegen» für fehlende Jahre.

### 3.3 `/buchhaltung/steuern/:jahr` — `SteuerjahrScreen` (vier Abschnitte, scrollbar)
1. **Veranlagung** — Formular für alle `steuerjahre`-Felder; Speichern-Knopf nach Vorbild `ArbeitBeendenKnopf`.
2. **Soll/Ist** — Tabelle Bund | Kanton | Busse | MWST × provisorisch / definitiv / bezahlt / offen-Guthaben; Hinweiszeile Buchhaltungsgewinn vs. steuerbar (Differenz, z. B. Bussen-Aufrechnung).
3. **Zahlungen** — Buchungen mit `steuerjahr = jahr` (Datum, Text, Betrag, Steuerart-Chip, Beleg-Symbol bei verknüpftem Dokument); darunter «Nicht zugeordnete Steuerbuchungen» (Soll/Haben 8900 oder 2208 oder ESTV-2202-Zahlungen ohne `steuerjahr`) mit Knopf «Zuordnen» (Dialog Jahr + Steuerart → Update der Buchung).
4. **Dokumente** — Dossier-Checkliste (Pflicht-Typen ✓/–), Liste gruppiert nach Typ (Titel, Datum, Betrag, Referenz), Tippen öffnet PDF via Signed-URL in neuem Tab (`pdf_tab_oeffner`), Bilder inline; Upload-Knopf → `DokumentUploadDialog` (Bereich fix `steuern`, Jahr vorbelegt).

### 3.4 `/dokumente` — `DokumenteScreen` (generisch)
Filter-Dropdowns Bereich + Jahr (Bausteine aus `widgets/filter/`), Liste (`DokumentListe`), Upload (`DokumentUploadDialog` mit Bereich, Typ [Vorschlagsliste je Bereich, frei editierbar], Kategorie, Jahr, Datum, Betrag, Referenz, Titel, Datei aus PDF/Galerie/Kamera wie `BelegUploadWidget`), Löschen mit Rückfrage. Home-Kachel «Dokumente» unter Verwaltung. Verknüpfung mit Buchung: optionales Feld «Zahlung» (Auswahl aus Steuerbuchungen des Jahres) — nur bei Bereich `steuern`.

### 3.5 Wiederverwendbare Bausteine
`DokumentRepository` (list/upload/delete/signedUrl, kIsWeb-Branching wie `BuchungsBelegRepository`), `DokumentListe`, `DokumentUploadDialog`, `SteuerjahrRepository`, `SteuerzahlungRepository` (Buchungen mit/ohne `steuerjahr`, Update), `SteuerjahrRechner` (reine Soll/Ist- und Dossier-Logik, testbar).

## 4. Abschlussprüfung (Audit neu)

### 4.1 Service
`AbschlussPruefService.pruefe(AbschlussKontext) → List<Pruefbefund>`; `Pruefbefund { regelId, gruppe, status (gruen|gelb|rot), titel, ist, soll, hinweis, aktionRoute? }`. Kontext: Buchungen (`BuchungSaldo` + Rohdaten für Steuer-/Rechnungsregeln), Konten, Stichtag 31.12.jahr (laufendes Jahr: heute), camt-Dateien (Zeiträume, Anfangs-/Schlusssaldo), Rechnungen (offene mit Datum/Betrieb/Betrag), Steuerbuchungen ohne Jahr, Dokumente je Jahr. Jede Regel ist eine eigene Klasse mit `pruefe(kontext)`; Regeln sind rein (keine DB).

### 4.2 Regeln

| Gruppe | Regel | grün | gelb | rot |
|---|---|---|---|---|
| Bank & Kasse | Bank 1020 per Stichtag vs. camt-Schlusssaldo (letzte Datei ≤ Stichtag) | Differenz ≤ 0.05 | keine camt-Datei | Differenz > 0.05 |
| Bank & Kasse | camt-Lückenkette: Anfangssaldo_n = Schlusssaldo_{n−1}, keine Kalendertage ohne Datei | lückenlos | Tageslücke | Saldosprung |
| Bank & Kasse | Kasse 1000 | 0 ≤ Saldo ≤ 10'000 | > 10'000 (Kassensturz) | < 0 |
| MWST | 2200/1170/1171 je abgeschlossenes Quartal saldiert | 0 ± 0.05 | — | Rest ≠ 0 |
| MWST | 2202 Vorzeichen | Haben oder 0 | Soll-Saldo | — |
| Debitoren | Offene Rechnungen älter als 5 Jahre (Rechnungsdatum < Stichtag − 5 J.) | 0 | — | > 0 (Anzahl, Summe) |
| Debitoren | Delkredere 1109 = 5 % von 1100 | ± 50 | Abweichung > 50 | 1109 = 0 bei 1100 > 0 |
| Debitoren | «offen»-Rechnungen mit gleichem Betrag+Betrieb in Zahlungen der letzten 60 Tage vor Stichtag | 0 | > 0 | — |
| Abschluss | Steuerrückstellung 2208 per Stichtag | > 0 | laufendes Jahr | 0 bei abgeschlossenem Jahr |
| Abschluss | Negative Aktiv-/Passivsalden (Klasse 1 < 0 ausser 1109; Klasse 2 > 0 ausser 2970/2980) | keine | — | vorhanden |
| Abschluss | Lohnkonten 2270–2273 | Haben/0 | Soll-Saldo | — |
| Abschluss | Konten mit «FEHLER» im Namen | 0 | — | ≠ 0 |
| Steuern | Steuerbuchungen ohne `steuerjahr` | 0 | > 0 (→ Steuern) | — |
| Steuern | Abgeschlossenes Jahr, Status `offen`, kein Dokument `steuererklaerung` | — | vorhanden (→ Einreichung 30.09.) | — |

### 4.3 Screen
`AuditScreen` mit Jahr-Dropdown (Default laufendes Jahr, `?jahr=` aus Route), Summenzeile «x rot · y gelb · z grün», Gruppen-Karten; Regelzeile = Ampelpunkt, Titel, Ist/Soll, Hinweis, optional Aktion (Navigation). Rot/gelb zuerst, grüne eingeklappt (Zähler). `AuditService`/`auditBefundeProvider` werden entfernt; Guard-Test stellt sicher, dass `AuditService` nirgends mehr referenziert wird.

## 5. camt-Integration

Ausgabe-Regeln für «Steuerverwaltung Kanton Graubünden» und «Eidgenössische Steuerverwaltung»: der Bestätigen-Dialog zeigt zwei Zusatzfelder **Steuerjahr** (Vorschlag Vorjahr; bei ESTV das laufende Jahr) und **Steuerart** (Kanton / Bund / MWST / Busse; Vorschlag aus Zahlungsempfänger, ESTV → MWST). Kontierung: Bund/Kanton → 2208, wenn das Steuerjahr eine Rückstellung trägt (2208-Saldo für das Jahr > 0), sonst 8900; MWST → 2202; Busse → 8900. Werte werden in `buchungen.steuerjahr/steuerart` geschrieben.

## 6. Erstbefüllung (einmalig, nach Deploy)

Skript `Datenbank/import/import_steuer_dokumente.py` (Supabase-Client mit Service-Key aus `Datenbank/import/.env`):
- lädt aus `00_Rechnungen/01_Steuern/` (22 PDFs), `Unterlagen/` (27 PDFs, Trennblätter ausgeschlossen, Rückseiten als `sonstiges`), `Steuererklärungen 2019-2024/<jahr>/` (11a, Q, DB, Bilanz, ER, Beilagen-ZIP-Inhalt, Zinsausweis 2024) in den Bucket; Metadaten aus `Datenbank/import/steuer_dokumente_katalog.csv` (aus den Session-Katalogen abgeleitet: Datei, Jahr, Typ, Kategorie, Datum, Betrag, Referenz, Titel, Zahlungs-Belegnummer); idempotent über `storage_pfad`.
- legt `steuerjahre` 2019–2025 an: 2019 (veranlagt, Gewinn −4'973, Kapital 15'000, Bund 0, Kanton 47) · 2020 (veranlagt/Einsprache, −36'284, Kapital 0, Bund 0, Kanton 0; prov. 603.50/717→89) · 2021 (veranlagt, Gewinn 16'072 verrechnet, steuerbar 0, Kapital 2'600, Bund 0, Kanton 11; prov. Kanton 89) · 2022 (veranlagt, 18'049 verrechnet, steuerbar 0, Kapital 12'800, Bund 0, Kanton 56; prov. Kanton 89) · 2023 (ermessen, steuerbar 12'864, Kapital 32'800, Bund 1'088, Kanton 1'279 [+30 Mahngebühr]; prov. Kanton 56) · 2024 (veranlagt, 28'399, Kapital 48'918, Bund 2'405.50, Kanton 2'748; prov. Bund 1'088, Kanton 1'279) · 2025 (offen; prov. Bund 2'405.50, Kanton 2'748).
- setzt `steuerjahr`/`steuerart` auf die 28 bestehenden Steuerbuchungen (Zuordnung laut `docs/buchhaltung/jahresabschluss-2025.md` Abschnitt 8) und verknüpft Rechnungs-PDFs über `buchung_id`.
- Die 2025er-Unterlagen (Jahresrechnung, Lohnausweis, Zinsausweis) lädt Daniel über den Screen.

## 7. Tests

- `abschluss_pruef_service_test.dart`: je Regel eine Gruppe (grün/gelb/rot-Fall), Stichtag-Logik laufendes vs. abgeschlossenes Jahr.
- `steuerjahr_rechner_test.dart`: Soll/Ist inkl. Guthaben, fehlende definitive Werte, Dossier-Vollständigkeit laufendes vs. abgeschlossenes Jahr.
- `dokument_repository_test.dart`: Pfadbildung, Typ-Vorschläge je Bereich.
- `view_steuerjahr_zahlungen`: SQL-Verifikation nach Migration (Summe 2024 = 5'153.50 bezahlt, 2025 = 5'153.50 provisorisch, 2019 = −9.20 Guthaben).
- Guard: kein Import von `audit_service.dart` mehr; `canvaskit_sichere_widgets_test` bleibt grün.

## 8. Auslieferung

1. Migrationen 182–184 (MCP `apply_migration`), Storage-Bucket + Policies.
2. Implementierung nach Plan (Opus-Subagenten je Task, TDD), Review, visueller Browser-Check (Handy-Breite) der drei Screens und des Audits.
3. Deploy v0.96.0 (`kAppVersion` + pubspec), dann Import-Skript, dann Daniels 2025er-Uploads.
4. Doku: ToDo.md, `docs/buchhaltung/jahresabschluss-2025.md` (Dossier-Status), Memory.
