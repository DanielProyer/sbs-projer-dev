# Anlagen-Screen + Steckbrief-PDF (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026)
**Herkunft:** Paket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Abschnitt „Anlagen".

## Ziel & Kontext

Anlagen sollen als eigener Bereich sichtbar werden (Dashboard-Kachel + Kennzahlen) und pro Anlage ein
professioneller **Steckbrief als PDF** erzeugt werden, der **geteilt** oder **per Mail an den RSL**
versendet werden kann.

**Wichtig — schon vorhanden (nicht neu bauen):**
- Globaler Screen `/anlagen` (`AnlagenListScreen`, `anlagenProvider` = alle Anlagen) mit Suche +
  Status-Filter + Betrieb-Zuordnung. **Ist aber nicht vom Dashboard verlinkt.**
- Anlage-Detail/-Formular/Bierleitungen existieren.
- **Anlagen-Fotos existieren**: Tabelle `anlagen_fotos` (`anlage_id`, `foto_nummer` 1–4, `foto_url` =
  Storage-Pfad, `beschreibung`), Bucket `anlagen-fotos`, `AnlageFotoRepository` (getByAnlage, upload,
  delete, getSignedUrl). Max 4 Fotos je Anlage, Upload im Anlage-Detail (`_FotosSection`).
- **Heineken-Zuweisungen**: generische Tabelle `heineken_kontakt_zuweisungen` (`funktion` text +
  `kontakt_id`); `KontaktRepository.getHeinekenZuweisung(funktion)` → `KontaktLocal?`. Screen
  `HeinekenZuweisungenScreen` mit fixer `_funktionen`-Liste. Montage nutzt `heigenie_service` für die
  RSL-Mail (`send-pdf-mail`).
- PDF-Muster: `services/pdf/bericht_pdf_common.dart` + `printing`-Paket (`Printing.sharePdf`).
- MailConfig-Bereichsmuster (`event`, `reinigung`, …) in `core/config/mail_config.dart`.

## Entscheidungen (mit User geklärt)

- **Kein Sammel-PDF** (nur Steckbrief pro Anlage).
- Steckbrief hat **zwei Aktionen**: **Teilen** und **Mail an RSL**.
- **RSL-Empfänger**: neue **Heineken-Zuweisung `rsl`** (einmal im Zuweisungen-Screen setzen) → wird
  vorausgefüllt; vor Versand kurzes **Bestätigen/Bearbeiten** der Adresse.
- **Fotos** kommen aus dem bestehenden `anlagen_fotos`/Bucket (max 4).
- **Keine DB-Migration** (Fotos + Zuweisungs-Tabelle existieren; `rsl`-Funktion ist nur Code).
- Deploy als **v0.27.0**.

## Baustein A — Dashboard-Kachel + Kennzahlen

### A.1 Dashboard-Kachel
- `home_screen.dart`: neue Kachel **„Anlagen"** direkt bei/unter „Bergkundenpauschalen"
  (`context.push('/anlagen')`), passendes Icon (z. B. `Icons.propane_tank_outlined`).

### A.2 Kennzahlen (reine, testbare Funktion)
- `anlagenKennzahlen(List<AnlageLocal> anlagen, DateTime jetzt) → AnlagenKennzahlen`:
  - `gesamt` = Anzahl Status `aktiv`.
  - `nachTyp` = Map Typ→Anzahl (aktiv), Typen `Warmanstich/Kaltanstich/Buffetanstich/Orion` +
    Rest unter `Sonstige`.
  - `ueberfaellig` = Anzahl aktiv mit `naechsteReinigung != null && naechsteReinigung` vor `jetzt`.
  - `ohneRhythmus` = Anzahl aktiv mit `reinigungRhythmus` leer/`keiner`.
- Anzeige als kompakter **Kennzahlen-Kopf** (Stat-Chips) über der Liste im `AnlagenListScreen`.

## Baustein B — Steckbrief-PDF

### B.1 PDF-Service (rein)
- Neu `services/pdf/anlage_pdf_service.dart`, Funktion
  `steckbrief({required AnlageLocal anlage, BetriebLocal? betrieb, required List<Uint8List> fotos,
  List<BierleitungLocal> bierleitungen = const []}) → Future<Uint8List>`.
- Professionelles Layout (Muster `bericht_pdf_common`): Kopf mit Betrieb (Name + Adresse) + Anlage-
  Bezeichnung/Typ; **Grunddaten-Block** (Typ Anlage, Typ Säule, Seriennummer, Anzahl Hähne, Gas-Typ 1/2,
  Vorkühler, Durchlaufkühler, Booster, Backpython, Hauptdruck bar, Niederdruck ja/nein,
  Reinigungsrhythmus, letzte/nächste Reinigung, Status, Notizen); **Foto-Grid** (bis 4, 2×2);
  optional **Bierleitungen**-Tabelle; Fusszeile mit Datum + Seitenzahl. Sonderzeichen ASCII-sanitisiert
  (Helvetica), analog Event-Abschluss-PDF.

### B.2 Foto-Bytes
- Im Detail/Versand-Flow: `AnlageFotoRepository.getByAnlage(anlage.serverId)` → je Foto Bytes via
  `SupabaseService.client.storage.from('anlagen-fotos').download(foto.fotoUrl)`. Fehlende/gelöschte
  Fotos überspringen. Reihenfolge nach `foto_nummer`.

### B.3 Dateiname/Betreff (reine, testbare Funktion)
- `anlageSteckbriefDateiname(betriebName, anlageBezeichnung) → String`
  (z. B. `Steckbrief_Sonne_Warmanstich-1.pdf`, Sonderzeichen/Slashes ersetzt).
- `anlageMailBetreff(betriebName, anlageBezeichnung) → String`.

## Baustein C — Aktionen im Anlage-Detail

### C.1 Teilen
- Button/Menüpunkt **„Steckbrief teilen"**: baut das PDF (mit Fotos) und öffnet `Printing.sharePdf`.

### C.2 Mail an RSL
- Neue **Heineken-Zuweisung `rsl`**: `('rsl', 'RSL', Icons.person_pin)` in
  `HeinekenZuweisungenScreen._funktionen` + `'rsl': null` in
  `KontaktRepository.getAllHeinekenZuweisungen`. (Kein Migrationsbedarf — generische Tabelle.)
- Button/Menüpunkt **„Steckbrief an RSL"**: lädt RSL via `getHeinekenZuweisung('rsl')`, öffnet ein
  kleines **Bestätigungs-Sheet** mit vorausgefüllter, **editierbarer** Empfänger-Adresse (leer →
  Hinweis „RSL in Heineken-Zuweisungen festlegen"). Versand über `send-pdf-mail` (Base64-PDF, `to`,
  `subject`, Dateiname). Empfänger via `MailConfig.empfaenger(rslMail, bereich: 'anlage')`.
- **MailConfig**: neuer Bereich `anlage` (`anlageScharf = false` initial → Testmodus an
  dani.proyer@gmail.com; im Sheet Hinweis). `istScharf('anlage')`-Zweig ergänzen.

## Abgrenzung

- Kein Sammel-/Listen-PDF. Kein neues Foto-Feature (Fotos existieren). Keine DB-Migration.
- Keine Änderung an bestehender Anlagen-Liste-Funktionalität (nur Kennzahlen-Kopf ergänzen).
- RSL ist **eine** geschäftsweite Zuweisung (nicht pro Region/Betrieb).

## Tests & Verifikation

- **Unit-Tests**: `anlagenKennzahlen` (gesamt/nachTyp/ueberfaellig/ohneRhythmus, inkl. inaktive
  ausgeschlossen); `anlageSteckbriefDateiname`/`anlageMailBetreff` (Sonderzeichen/Slashes).
- **Smoke-Test** `steckbrief(...)` baut ein PDF ohne Exception (mit 0 und mit Fotos-Bytes).
- `flutter analyze` ohne neue Findings; Tests grün.
- **Visueller Browser-Test** (Pflicht): Dashboard-Kachel → Anlagen-Liste mit Kennzahlen-Kopf;
  Anlage-Detail → „Steckbrief teilen" (PDF-Vorschau/Share) + „Steckbrief an RSL" (Sheet mit
  vorausgefüllter Adresse, Testmodus-Hinweis); RSL-Zuweisung im Heineken-Zuweisungen-Screen setzbar.
- Echter Mail-Testversand (an dich, `anlageScharf=false`) + PDF prüfen, dann bei Bedarf scharf.

## Deploy

Ein Paket **v0.27.0** nach Deploy-Workflow (CLAUDE.md). Keine Migration. Keine Edge-Function-Änderung
(nutzt bestehendes `send-pdf-mail`).
