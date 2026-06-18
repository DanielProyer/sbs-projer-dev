# Geschäfts-Einstellungen + Settings-Umbau — Design

**Datum:** 2026-06-18 · **Status:** Spec zur Freigabe durch Daniel

---

## 1. Ziel

1. Neue Einstellungs-Kategorie **Geschäft** (Firmen-Stammdaten): Name, Strasse, PLZ/Ort, Geschäftsführer (Vorname+Name), Telefon, Mail Geschäft, Mail Privat, MWST-Nummer, UID-Nummer.
2. **Lohn-Einstellungen** umbauen: Arbeitgeber-Eingabe entfällt (kommt aus Geschäft), Arbeitnehmer-Daten (Name/Vorname/Adresse/Ort) aus Geschäft **vorbefüllen** (überschreibbar, pro Jahr).
3. Geschäfts-Daten verdrahten in: **Report-Mail-Empfänger** (Bilanz/ER), **Bericht-PDF-Briefkopf** (Bilanz/ER), **Kundenrechnung-PDF** (nur Firmenname/Adresse + optional MWST-Nr.; IBAN/QR bleiben).
4. Den gesamten Einstellungen-Screen **sauber gruppieren und schön darstellen**.

**Leitprinzip (kritisch):** Überall **Fallback auf die heutigen fix codierten Werte**, solange das Geschäft leer/ungesetzt ist — die App funktioniert unverändert weiter. QR-/IBAN-Logik der Kundenrechnung bleibt **unangetastet**.

---

## 2. Ausgangslage (Ist)

- **`einstellungen_screen.dart`** dreht sich komplett um **Preise** (Provider `aktuellePreiseProvider`): Sektionen Biersorten, Heineken (PO-Nr. + Kontakt-Zuweisungen), Reinigungs-/Störungs-/Weitere Preise, MwSt-Sätze, „Neue Preise erfassen". Keine Firmen-Stammdaten.
- **`LohnEinstellungen`** (`data/models/lohn_einstellungen.dart`): pro Jahr (`jahr`), Sätze (AHV/ALV/NBU/BU/BVG/FAK/KTG) + Arbeitnehmer (`arbeitnehmer_name/_vorname/_adresse/_plz_ort/_ahv_nr/_geburtsdatum`) + Arbeitgeber (`arbeitgeber_name/_adresse/_plz_ort`). Supabase-Tabelle `lohn_einstellungen` (user + jahr).
- **`lohn_einstellungen_screen.dart`** (`/buchhaltung/lohn`): Formular mit AN- **und** AG-Block (Controller `_agName/_agAdresse/_agPlzOrt`, Default `_agName='SBS Projer GmbH'`). Speichert AG/AN in `LohnEinstellungen`.
- **`lohnausweis_pdf_service.dart`** liest `einst.arbeitgeberName/Adresse/PlzOrt` und `einst.arbeitnehmer*`.
- **`bericht_pdf_common.dart`**: `kopf()` mit statischen Konstanten `firma='SBS Projer GmbH'`, `strasse='Via Rezia 8'`, `ort='7013 Domat/Ems'`.
- **`rechnung_pdf_service.dart`**: Firmen-Konstanten (`_firmaName`, `_firmaStrasse='Via Rezia'`, `_firmaNr='8'`, `_firmaPlz='7013'`, `_firmaOrt='Domat/Ems'`, `_iban='CH6600774010376550601'`). QR-Zahlteil nutzt diese.
- **`BerichtMailService.empfaenger = 'dani.proyer@gmail.com'`** (hardcodiert, mit `TODO(settings)`).
- Gmail-Absender der Edge-Functions: `sbs.projer@gmail.com`. Telefon (aus Mailtext): `076 566 58 06`. Geschäftsführer: `Daniel Projer`.

---

## 3. Architektur-Übersicht

```
data/models/geschaeft_einstellungen.dart        → NEU: Model + fromJson/toJson + Fallback-Getter
data/repositories/geschaeft_repository.dart      → NEU: get() / update() (Supabase-direkt)
presentation/providers/geschaeft_providers.dart  → NEU: geschaeftProvider (FutureProvider, gecacht)

services/buchhaltung/geschaeft_mapping.dart      → NEU: reine Helfer (AG aus Geschäft, AN-Prefill) + Tests

presentation/screens/einstellungen/
  einstellungen_screen.dart                      → UMBAU: Gruppierung + neue Geschäft-Sektion
  widgets/geschaeft_form.dart                     → NEU: editierbares Geschäft-Formular

presentation/screens/buchhaltung/
  lohn_einstellungen_screen.dart                  → UMBAU: AG-Block raus, AN-Prefill, AG-Snapshot beim Speichern
  berichte_screen.dart                            → ÄNDERN: Mail-Empfänger + Firma aus Geschäft an PDF/Mail

services/pdf/
  bericht_pdf_common.dart                         → ÄNDERN: kopf() nimmt Firma-Daten (Fallback Konstanten)
  bilanz_pdf_service.dart / erfolgsrechnung_pdf_service.dart → Firma-Param durchreichen
  rechnung_pdf_service.dart                        → ÄNDERN: optionale Firma-Params (Default = heutige Konstanten); IBAN/QR unverändert

services/mail/bericht_mail_service.dart           → ÄNDERN: send(to: ...) Parameter

Datenbank/migrations/096_geschaeft_einstellungen.sql → NEU: Tabelle + RLS + Default-Zeile (heutige Werte)
```

---

## 4. Datenmodell

### 4.1 Tabelle `geschaeft_einstellungen` (Migration 096)
Eine Zeile pro User. Spalten:
`id uuid pk default gen_random_uuid()`, `user_id uuid not null`, `firma_name text`, `strasse text`, `plz_ort text`, `gf_vorname text`, `gf_name text`, `telefon text`, `mail_geschaeft text`, `mail_privat text`, `mwst_nummer text`, `uid_nummer text`, `created_at timestamptz default now()`, `updated_at timestamptz default now()`.
- **RLS analog `lohn_einstellungen`** (Besitzer liest/schreibt eigene Zeile; bestehendes Gast-Lese-Muster mitziehen, falls vorhanden).
- **Default-Zeile** für Daniel (`user_id = 1e1ec2dd-7836-4d8e-8256-c5649d994ee2`) mit den heutigen Werten: firma_name `SBS Projer GmbH`, strasse `Via Rezia 8`, plz_ort `7013 Domat/Ems`, gf_vorname `Daniel`, gf_name `Projer`, telefon `076 566 58 06`, mail_geschaeft `sbs.projer@gmail.com`, mail_privat `dani.proyer@gmail.com`, mwst_nummer `''`, uid_nummer `''`.
- Eindeutigkeit: ein Datensatz pro user_id (Unique auf `user_id`).

### 4.2 Dart-Model `GeschaeftEinstellungen`
Felder wie Tabelle. `fromJson`/`toJson`. **Fallback-Konstanten** als `static const` (= heutige Werte). Getter mit Fallback, damit Konsumenten nie leer dastehen:
- `firma` → `firma_name` falls gesetzt, sonst Konstante.
- `adresseStrasse`, `adressePlzOrt`, `telefonOrFallback`.
- `gfVollname` → `'$gf_vorname $gf_name'.trim()`.
- `mailEmpfaenger` → `mail_geschaeft` ?? `mail_privat` ?? `'dani.proyer@gmail.com'`.
- `mwstZeile` → `'MWST $mwst_nummer'` falls gesetzt, sonst leer.

### 4.3 Repository + Provider
- `GeschaeftRepository.get()` → lädt die Zeile des aktuellen Users; **falls keine existiert, gibt es ein Default-Objekt mit Konstanten zurück** (Sicherheitsnetz). `update(Map<String,dynamic>)` → upsert auf `user_id`.
- `geschaeftProvider` = `FutureProvider<GeschaeftEinstellungen>`; nach Speichern `ref.invalidate(geschaeftProvider)`.

---

## 5. Geschäft-Einstellungen-UI (`widgets/geschaeft_form.dart`)
Editierbares Formular (TextFormFields) für alle Felder, gruppiert: **Firma** (Name, Strasse, PLZ/Ort, MWST-Nr., UID-Nr.), **Geschäftsführer** (Vorname, Name), **Kontakt** (Telefon, Mail Geschäft, Mail Privat). „Speichern"-Button → `GeschaeftRepository.update(...)` → Provider invalidieren → Snackbar. Eingebettet als oberste Sektion im Einstellungen-Screen (aufklappbare Karte „Geschäft").

---

## 6. Lohn-Einstellungen umbauen (`lohn_einstellungen_screen.dart`)
- **Arbeitgeber-Formularblock entfernt** (Section-Header „Lohnausweis — Arbeitgeber" + Controller `_agName/_agAdresse/_agPlzOrt`). Stattdessen eine **read-only Infozeile** „Arbeitgeber: <Firma>, <Strasse>, <PLZ Ort> (aus Geschäft)".
- **Beim Speichern**: `arbeitgeber_name/_adresse/_plz_ort` werden aus dem Geschäft gesetzt (`firma`, `adresseStrasse`, `adressePlzOrt`) → **`LohnEinstellungen`-Schema unverändert**, `lohnausweis_pdf_service` (liest `einst.arbeitgeber*`) bleibt **unverändert**; jeder Jahrgang behält seinen AG-Snapshot.
- **Arbeitnehmer-Prefill**: beim Laden eines Jahrgangs werden **leere** AN-Felder aus dem Geschäft vorbefüllt: `arbeitnehmer_name←gf_name`, `_vorname←gf_vorname`, `_adresse←adresseStrasse`, `_plz_ort←adressePlzOrt`. Befüllte Felder bleiben unverändert; alles editierbar und pro Jahr gespeichert. AHV-Nr./Geburtsdatum wie bisher manuell.
- Reine Helfer in `geschaeft_mapping.dart`:
  - `arbeitgeberFelder(GeschaeftEinstellungen) → {name, adresse, plzOrt}`
  - `arbeitnehmerPrefill(LohnEinstellungen current, GeschaeftEinstellungen g) → {name, vorname, adresse, plzOrt}` (nur leere Felder ersetzen).
- Screen liest `geschaeftProvider`.

---

## 7. Verdrahtung der Geschäfts-Daten

### 7.1 Report-Mail (Bilanz/ER)
- `BerichtMailService.send` erhält Parameter **`required String to`** (kein hardcodierter Empfänger mehr; `empfaenger`-Konstante entfällt bzw. wird zu reinem Fallback).
- `berichte_screen.dart`: liest `geschaeftProvider`, berechnet Empfänger = `g.mailEmpfaenger`, zeigt ihn im Bestätigungsdialog, übergibt ihn an `send(to: ...)`.

### 7.2 Bericht-PDFs (Bilanz/ER)
- `BerichtPdfCommon.kopf(titel, periode, {String? firma, String? strasse, String? ort, String? mwstZeile})` — nutzt übergebene Werte, sonst die Konstanten. Optional eine kleine MWST/UID-Zeile.
- `BilanzPdfService.generate(...)` / `ErfolgsrechnungPdfService.generate(...)` bekommen optionale Firma-Parameter und reichen sie an `kopf` durch.
- `berichte_screen.dart` übergibt die Geschäfts-Firma-Daten beim PDF-Erzeugen.

### 7.3 Kundenrechnung-PDF (konservativ)
- `RechnungPdfService.generate(...)` bekommt **optionale** benannte Parameter `firmaName`, `firmaStrasse`, `firmaPlzOrt`, `firmaMwst` mit **Default = heutige Konstanten**. Nur der **angezeigte Firmenkopf** nutzt sie; **IBAN, QR-Zahlteil und Zahlungsangaben bleiben unverändert hardcodiert**.
- Aufrufer mit verfügbarem Geschäft (Rechnungs-Detail, Nachversand) übergeben die Werte; alle anderen Aufrufer nutzen die Defaults → **kein Verhaltensbruch**.

---

## 8. Einstellungen sauber gruppieren (`einstellungen_screen.dart`)
Neue Top-Level-Reihenfolge als einheitliche aufklappbare Karten (`_SectionCard`):
1. **Geschäft** (neu, `geschaeft_form.dart`)
2. **Lohn** — Karte mit Einstieg „Lohn-Einstellungen öffnen" (→ `/buchhaltung/lohn`)
3. **Preise** — Reinigung · Störung · Weitere · MwSt + „Neue Preise erfassen" (bestehende Inhalte, gruppiert)
4. **Heineken** — PO-Nr., Kontakt-Zuweisungen (bestehend)
5. **Biersorten** (bestehend)

Einheitliche Icons/Abstände; bestehende Hilfs-Widgets (`_SectionCard`, `_InfoRow`, …) wiederverwenden. **Keine** Preis-Funktion verändern, nur umgruppieren.

---

## 9. „App funktioniert gleich" — Sicherheitsnetz
- `GeschaeftRepository.get()` und alle Getter liefern bei fehlenden Werten die heutigen Konstanten.
- Default-Zeile in Migration 096 = heutige Werte → schon vor jedem Bearbeiten identisches Verhalten.
- `LohnEinstellungen`-Schema unverändert (AG-Spalten bleiben, werden automatisch befüllt).
- `RechnungPdfService` Default-Parameter = heutige Konstanten; QR/IBAN unangetastet.
- Reine Mapping-/Fallback-Logik wird per Unit-Test abgesichert.

---

## 10. Tests (TDD, reine Logik)
- `geschaeft_mapping_test.dart`:
  - `arbeitnehmerPrefill`: leere Felder werden aus Geschäft gefüllt; **bereits gesetzte** AN-Felder bleiben erhalten.
  - `arbeitgeberFelder`: liefert Firma/Strasse/PLZ-Ort aus Geschäft.
- `geschaeft_einstellungen_test.dart`:
  - Fallback-Getter: leeres Model → Konstanten; `mailEmpfaenger`-Reihenfolge (geschaeft→privat→default); `gfVollname`.
- PDF-/Screen-Code: kein Unit-Test (Projekt-Muster), Verifikation via `flutter analyze` + bestehender PDF-Smoke-Test bleibt grün.

---

## 11. Erfolgskriterien
- Neue „Geschäft"-Sektion erfassbar/speicherbar; Felder vollständig.
- Lohn-Screen ohne AG-Eingabe; AN-Felder aus Geschäft vorbefüllt (überschreibbar); Lohnausweis-PDF weiterhin korrekt (AG aus Geschäft-Snapshot).
- Report-Mail geht an die Geschäfts-/GF-Mail; Bericht-PDFs zeigen Geschäfts-Firmendaten.
- Kundenrechnung-PDF unverändert funktionsfähig (QR/IBAN), Firmenkopf aus Geschäft mit Fallback.
- Einstellungen-Screen sauber gruppiert; alle bisherigen Funktionen erhalten.
- `flutter analyze` ohne Errors; neue Tests grün; bestehende Tests bleiben grün.

---

## 12. Nicht im Scope
- IBAN/Bankverbindung als Geschäfts-Feld (QR-Zahlteil bleibt hardcodiert).
- Offline-Isar-Speicherung der Geschäfts-Daten (Supabase-direkt, Browser-primär).
- Mehrere Arbeitnehmer / Mehr-Mandanten (ein Geschäft, ein AN = Geschäftsführer).
