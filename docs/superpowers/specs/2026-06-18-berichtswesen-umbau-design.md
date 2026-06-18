# Berichtswesen-Umbau (Bilanz / Erfolgsrechnung / MwSt) — Design

**Datum:** 2026-06-18 · **Status:** Spec zur Freigabe durch Daniel

---

## 1. Ziel

Das Buchhaltungs-Berichtswesen umbauen und aufwerten:

1. **MwSt-Abrechnung** wird ein **eigener Screen** (raus aus „Berichte").
2. **Bilanz + Erfolgsrechnung** wandern in **einen Screen mit 2 Tabs** (übernimmt die „Berichte"-Rolle).
3. **Stichtag der Bilanz** und **Periode der Erfolgsrechnung** frei wählbar (Presets + freie Datumswahl).
4. Bilanz und Erfolgsrechnung **professioneller darstellen**.
5. Erfolgsrechnung bekommt zusätzlich (eine Scroll-Seite, aufklappbar): **Kontenklassen-Übersicht** und **Konten-Übersicht**.
6. **PDF-Generierung** für Bilanz und Erfolgsrechnung, mit **Mail-Versand**.

Nicht im Scope: MwSt-Abrechnung bleibt quartalsweise (kein Datum/PDF/Mail); Settings-Umbau (nur Vorbereitung über TODO-Marker).

---

## 2. Ausgangslage (Ist)

- `berichte_screen.dart`: 2 Tabs **Erfolgsrechnung + MwSt**, Jahr-Picker (`_selectedJahr`), Route `/buchhaltung/berichte`.
- `bilanz_screen.dart`: separat, nur 31.12.-Jahr-Picker, Route `/buchhaltung/bilanz`.
- Services rechnen bereits zeitraumfähig:
  - `BilanzService.saldiPerStichtag(buchungen, stichtag)` + `gruppiere(...)` + `kumuliertesErgebnis(...)`.
  - `ErfolgsrechnungService.berechne(buchungen, von:, bis:)`.
- Provider sind aber jahr-gebunden: `bilanzProvider(int jahr)` (rechnet 31.12.), `erfolgsrechnungStufenProvider(int jahr)` (1.1.–31.12.), `mwstQuartalDetailProvider(int jahr)`.
- PDF-Standard: `printing`-Package (`Printing.sharePdf`/`layoutPdf`) in 8 Screens.
- Mail: Edge Function `send-rechnung-mail` hängt nur **Storage**-PDFs an (kann kein Inline-PDF).
- `MailConfig`: Test-/Scharf-Logik pro Bereich — für interne Berichte **nicht** zutreffend.

---

## 3. Architektur-Übersicht

```
presentation/screens/buchhaltung/
  berichte_screen.dart          → UMBAU: Tabs [Bilanz | Erfolgsrechnung], Datum-Steuerung
  mwst_abrechnung_screen.dart   → NEU: MwSt-Quartalsansicht (aus berichte herausgelöst)
  bilanz_screen.dart            → ENTFERNT (Inhalt wird Bilanz-Tab; Route → Redirect auf /berichte)
  widgets/
    bilanz_view.dart            → NEU: reine Bilanz-Darstellung (Tab + Basis fürs PDF-Layout)
    erfolgsrechnung_view.dart   → NEU: Scroll-Seite Stufen + aufklappbar Klassen + Konten
    bericht_datum_picker.dart   → NEU: Presets + freie Datumswahl (Stichtag bzw. von–bis)

services/buchhaltung/
  erfolgsrechnung_service.dart  → ERWEITERN: kontenAufstellung(von,bis)
  (bilanz_service.dart bleibt — generalisiert bereits auf Stichtag)

services/pdf/
  bericht_pdf_common.dart       → NEU: Firmenkopf/Helfer (Format, Footer)
  bilanz_pdf_service.dart       → NEU: A4, zweispaltig Aktiven/Passiven
  erfolgsrechnung_pdf_service.dart → NEU: A4, 3 Ebenen (Stufen+Klassen+Konten)

services/mail/
  bericht_mail_service.dart     → NEU: ruft Edge Function send-pdf-mail mit Inline-PDF

presentation/providers/buchhaltung_providers.dart
  bilanzProvider                → KEY-WECHSEL: family<BilanzDaten, DateTime> (Stichtag)
  erfolgsrechnungStufenProvider → KEY-WECHSEL: family<ErfolgsrechnungDaten, Zeitraum>
  erKontenAufstellungProvider   → NEU: family<ErKontenAufstellung, Zeitraum>

core/util/chf_format.dart       → NEU: Schweizer Betragsformat 1'234.55
core/config/router.dart         → /buchhaltung/mwst (neu); /buchhaltung/bilanz → Redirect

supabase/functions/send-pdf-mail/index.ts → NEU: Inline-PDF-Mail (Gmail)
```

`Zeitraum` = kleines value-Objekt `{DateTime von; DateTime bis}` mit Wert-Gleichheit (Dart `record` `(DateTime von, DateTime bis)` oder eigene `@immutable`-Klasse mit `==`/`hashCode`) als Riverpod-Family-Key. Stichtag-Key = `DateTime` (auf Datum normalisiert, ohne Zeitanteil).

---

## 4. Komponenten im Detail

### 4.1 Screen-/Navigationsstruktur

- **`BerichteScreen`** (Route `/buchhaltung/berichte`, Titel **„Bilanz & Erfolgsrechnung"**): `TabController(length: 2)`, Tabs **Bilanz** | **Erfolgsrechnung**. Datum-Steuerung pro Tab (s. 4.2). AppBar-Action je Tab: **PDF/Teilen** + **Mail**.
- **`MwstAbrechnungScreen`** (Route `/buchhaltung/mwst`, Titel **„MwSt-Abrechnung"**): exakt der heutige `_MwstTab`-Inhalt (Jahr-Picker in AppBar + Quartals-`SegmentedButton`). Kein Datum/PDF/Mail.
- **Dashboard** (`buchhaltung_dashboard_screen.dart`): Kachel „Berichte" → **„Bilanz & Erfolgsrechnung"** (Untertitel „Bilanz & Erfolgsrechnung per Datum"); **neue Kachel** „MwSt-Abrechnung" (Icon `account_balance`, Untertitel „Quartals-Abrechnung ESTV") → `/buchhaltung/mwst`. Bestehende „Bilanz"-Kachel entfällt (in den kombinierten Screen integriert).
- **Router**: `/buchhaltung/bilanz` bleibt als **Redirect** auf `/buchhaltung/berichte` (Bookmarks/alte Verweise).

### 4.2 Datumswahl (`bericht_datum_picker.dart`)

Eine kompakte Steuerleiste oben im jeweiligen Tab.

- **Bilanz-Tab (Stichtag):** Preset-Chips `Per 31.12. <Vorjahr>`, `Heute` + Button „Datum…" (`showDatePicker`, 2019‑01‑01 bis heute). Default **heute**. Liegt der Stichtag `>=` heute oder im noch offenen laufenden Jahr → Badge **„provisorisch"**.
- **Erfolgsrechnung-Tab (von–bis):** Preset-Chips `Geschäftsjahr <Jahr>`, `Quartal`, `Monat`, `YTD` (1.1. lfd. Jahr–heute) + zwei Buttons „Von…"/„Bis…". Default **laufendes Geschäftsjahr** (1.1.–31.12. aktuelles Jahr). Jahr-Auswahl für die Presets via Jahr-Picker (2019…aktuell).
- Auswahl liegt im `BerichteScreen`-State (`_stichtag`, `_von`, `_bis`); ändert die Provider-Family-Argumente.

### 4.3 Erfolgsrechnung-Tab (`erfolgsrechnung_view.dart`) — Scroll-Seite, aufklappbar

1. **Stufengliederung** (immer offen): bestehende KMU-Stufenlogik (`erfolgsrechnungStufenProvider`), aber neu formatiert — Tausender-Trennzeichen (`chf_format`), klarere Hierarchie (Stufen-Totale fett + dezente Trennlinien), Jahresergebnis hervorgehoben (farbiges Feld). Titel zeigt den gewählten Zeitraum: „Erfolgsrechnung 01.01.2026 – 30.06.2026".
2. **Kontenklassen** (`ExpansionTile`, default zu): Klassen 3–8 mit Netto-Summe und Anteil am Nettoerlös in %. Quelle: `erKontenAufstellungProvider`.
3. **Alle Konten** (`ExpansionTile`, default zu): nach Klasse gruppiert, je Konto `<nr> <bezeichnung> … <summe>`. Nur Konten mit Bewegung im Zeitraum (Summe ≠ 0). Quelle: `erKontenAufstellungProvider`.

**Vorzeichen-Konvention (eindeutig):** Pro Konto wird der Perioden-Netto-Saldo `Soll−Haben` berechnet. Für **Ertragsklassen (3, 7)** wird `−(Soll−Haben)` angezeigt (Ertrag positiv), für **Aufwandsklassen (4, 5, 6, 8)** `Soll−Haben` (Aufwand positiv). Klassensumme = Summe der so dargestellten Kontowerte. So sind alle ausgewiesenen Beträge „natürlich" positiv bei normalem Verlauf.

### 4.4 Bilanz-Tab (`bilanz_view.dart`) — professionellere Darstellung

- Kopf: „Bilanz per TT.MM.JJJJ" + „provisorisch"-Badge (s. 4.2).
- **Aktiven** und **Passiven** als zwei saubere Abschnitte (Cards): Gruppentitel (Umlaufvermögen / Anlagevermögen bzw. Kurz-/Langfristiges FK / Eigenkapital), Kontozeilen `1000 Kasse … 1'234.55` (Tausender-Trennzeichen, Beträge rechtsbündig in tabellarischer Spalte), Zwischensumme je Gruppe, **fettes Total** je Seite.
- **Bilanz-Check-Badge** unten: grün „Aktiven = Passiven ✓" oder rot mit Differenz (`differenz.abs() < 0.005`).
- Datenquelle unverändert: `bilanzProvider(stichtag)` inkl. EK-Split Gewinnvortrag/Jahresergebnis.

### 4.5 Betragsformat (`core/util/chf_format.dart`)

Reine Hilfsfunktion `String chf(double v)` → Schweizer Format mit Tausender-Apostroph und 2 Dezimalstellen, z. B. `-1'234.55`. Implementierung über `intl` `NumberFormat` mit nachträglichem Ersetzen des Gruppierungszeichens durch `'` (Apostroph), damit unabhängig von der Locale-Konfiguration. Wird in Views **und** PDFs genutzt.

### 4.6 Provider-Anpassungen (`buchhaltung_providers.dart`)

- `bilanzProvider` → `FutureProvider.family<BilanzDaten, DateTime>`: rechnet `saldiPerStichtag(stichtag)` und `saldiPerStichtag(31.12. des Vorjahres von stichtag)`; EK-Split wie heute (`gewinnvortrag = resVor`, `jahresergebnis = resBis − resVor`). Generalisiert sauber auf beliebige Stichtage (z. B. 30.06.2026 → Vortrag per 31.12.2025, Jahresergebnis 01.01.–30.06.2026).
- `erfolgsrechnungStufenProvider` → `family<ErfolgsrechnungDaten, Zeitraum>`: ruft `ErfolgsrechnungService.berechne(von, bis)`.
- **`erKontenAufstellungProvider`** (neu) → `family<ErKontenAufstellung, Zeitraum>`: ruft `ErfolgsrechnungService.kontenAufstellung(von, bis)` + reichert mit `KontoInfo` (Bezeichnung) an.
- Alte jahr-basierte Aufrufe (Dashboard nutzt `erfolgsrechnungProvider(year)` aus DB-View — separat, unverändert).

### 4.7 Service-Erweiterung (`erfolgsrechnung_service.dart`)

Neue **reine** Methode:

```dart
// nr = Kontonummer, bezeichnung = null im Service (wird im Provider gefüllt)
class ErKonto { final int nr; final String? bezeichnung; final double summe; }
class ErKlasse { final int klasse; final double summe; final List<ErKonto> konten; }
class ErKontenAufstellung { final List<ErKlasse> klassen; final double nettoerloes; }

static ErKontenAufstellung kontenAufstellung(
  List<BuchungSaldo> buchungen, {required DateTime von, required DateTime bis});
```

- Baut die `shm`-Map (`Soll−Haben` je Konto über `SaldoExpansion`, gleiche Filterung wie `berechne`).
- Gruppiert Konten nach Klasse (`nr ~/ 1000`) für Klassen 3–8.
- Wendet die Vorzeichen-Konvention aus 4.3 an; lässt Konten mit Summe 0 weg; sortiert Konten aufsteigend, Klassen 3→8.
- `nettoerloes` = dargestellte Summe Klasse 3 (für die %-Anteile).
- Der Service lässt `ErKonto.bezeichnung = null` (stammdatenfrei/testbar). Der **Provider** `erKontenAufstellungProvider` mappt die Struktur auf eine Variante **mit** Bezeichnung (Lookup über `KontoRepository`), die die View direkt anzeigt.

### 4.8 PDF (`bilanz_pdf_service.dart`, `erfolgsrechnung_pdf_service.dart`, `bericht_pdf_common.dart`)

- `bericht_pdf_common.dart`: Firmenkopf (SBS Projer GmbH, Via Rezia 8, 7013 Domat/Ems) als `pw.Widget`, Footer mit Erstell-Datum, gemeinsames Theme/Format (`chf`).
- **`BilanzPdfService.generate(BilanzDaten, DateTime stichtag) → Future<Uint8List>`**: A4 Hochformat, klassisch **zweispaltig** — Aktiven links, Passiven rechts, Gruppen + Konten + Totale, Differenz-Zeile.
- **`ErfolgsrechnungPdfService.generate(ErfolgsrechnungDaten stufen, ErKontenAufstellung konten, Zeitraum) → Future<Uint8List>`**: A4, **alle drei Ebenen** mehrseitig (Seite 1 Stufengliederung, dann Kontenklassen-Tabelle, dann Konten nach Klasse). `pw.MultiPage` für Seitenumbruch.
- Aufruf in der AppBar: `Printing.sharePdf(bytes, filename)` (Vorschau/Teilen/Drucken) — Pattern wie `lohnlauf_screen.dart`.

### 4.9 Mail (`bericht_mail_service.dart` + Edge Function `send-pdf-mail`)

- **Empfänger fix `dani.proyer@gmail.com`.** Im Code klar als `// TODO(settings): später E-Mail des Geschäftsführers aus den Einstellungen` markiert (eine zentrale Konstante/Funktion, damit der spätere Settings-Umbau nur diese eine Stelle trifft).
- UI: AppBar-Action „Per Mail senden" → Bestätigungsdialog „Bilanz/Erfolgsrechnung als PDF an dani.proyer@gmail.com senden?" → bei Ja PDF erzeugen, base64-kodieren, Edge Function aufrufen, SnackBar-Rückmeldung.
- **Edge Function `send-pdf-mail`** (neu): Request `{to, subject, bodyText, filename, pdfBase64}`. Baut MIME-Mail mit Inline-PDF-Anhang (Gmail-Helfer aus `send-rechnung-mail` kopiert: `getGmailAccessToken`, `buildMimeMessage`, `encodeEmailDomain`, base64). Kein Storage-Zugriff. Antwort `{success, messageId}`.
  - Deploy: `supabase functions deploy send-pdf-mail --no-verify-jwt` (gleiche Gmail-Secrets wie bestehend).
- Geht **direkt** an die Adresse (kein `MailConfig`-Test-Umweg, da interner Bericht).

---

## 5. Tests (TDD, reine Services)

- `erfolgsrechnung_service_test.dart` → `kontenAufstellung`:
  - Aufwand-Konto (z. B. 4000) erscheint mit positivem Wert in Klasse 4.
  - Ertrags-Konto (3400) erscheint mit positivem Wert in Klasse 3 (Vorzeichen-Konvention).
  - Konto mit Saldo 0 fehlt; Konten/Klassen korrekt sortiert; Klassensumme = Σ Konten.
  - Zeitraum-Filter: Buchung außerhalb von–bis zählt nicht.
- `bilanz_service_test.dart` → Stichtag mitten im Jahr: EK-Split = Gewinnvortrag (per 31.12. Vorjahr) + Jahresergebnis (Jahresbeginn–Stichtag); Aktiven=Passiven (Differenz ≈ 0).
- `chf_format_test.dart` → `chf(1234.5)=="1'234.50"`, `chf(-1234.55)=="-1'234.55"`, `chf(0)=="0.00"`, `chf(1000000)=="1'000'000.00"`.
- PDF-/Screen-Code: kein Unit-Test (folgt bestehendem Projekt-Muster); Verifikation via `flutter analyze` + manueller Klick.

---

## 6. Erfolgskriterien

- MwSt-Abrechnung ist ein eigener Screen; „Bilanz & Erfolgsrechnung" hat 2 Tabs.
- Bilanz-Stichtag und ER-Zeitraum frei wählbar (Presets + Datum); Werte stimmen mit der bisherigen Jahres-Ansicht überein, wenn Geschäftsjahr/31.12. gewählt ist.
- Erfolgsrechnung zeigt Stufen + aufklappbar Kontenklassen + alle Konten.
- Bilanz & ER sind sauber/tabellarisch mit Tausender-Trennzeichen formatiert; Bilanz-Check sichtbar.
- Für Bilanz & ER lässt sich ein PDF erzeugen/teilen und per Mail an `dani.proyer@gmail.com` senden.
- `flutter analyze` ohne Errors; neue Service-Tests grün; bestehende Tests bleiben grün.

---

## 7. Offene/zukünftige Punkte (nicht in diesem Scope)

- Mail-Empfänger später aus Einstellungen (E-Mail des Geschäftsführers) statt fix — Code-Stelle ist markiert.
- MwSt-Abrechnung evtl. später ebenfalls PDF/Mail.
- Deploy der Edge Function `send-pdf-mail` ist Teil der Umsetzung (separater Schritt, einmalig).
