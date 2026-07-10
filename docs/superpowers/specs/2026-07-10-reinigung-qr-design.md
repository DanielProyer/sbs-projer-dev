# Reinigung-QR (Firmenkonto-QR im Reinigungs-Formular) — Design

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026)
**Herkunft:** Paket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Abschnitt „Reinigung": „QR Code
Firmenkonto als Link in neue Reinigung (falls der Kunde direkt mit e-Banking zahlt)".

## Ziel & Kontext

Beim Erfassen einer neuen Reinigung soll ein **Swiss-QR-Code auf das Firmenkonto** auf dem
Bildschirm angezeigt werden, den der Kunde direkt mit seiner Banking-App scannt und vor Ort per
E-Banking zahlt — ohne separate Rechnung.

**Wichtig — schon vorhanden (wiederverwenden):**
- Swiss-QR-Erzeugung in `RechnungPdfService`: `_buildQrData(betrag, kunde, {mitteilung, referenz})`
  baut den SPC-Payload (Version 0200, UTF-8, Creditor strukturiert, optionaler Debitor, Referenz
  `SCOR`/`NON`, unstrukturierte Mitteilung, Trailer `EPD`). Nutzt aktuell **hartcodierte** Firmen-
  Konstanten (`_iban='CH6600774010376550601'`, `_firmaName='SBS Projer GmbH'`, `_firmaStrasse='Via
  Rezia'`, …). QR-Rendering im PDF via `barcode`-Paket + Schweizerkreuz.
- Firmen-IBAN in `geschaeft_einstellungen.firmen_iban` (`CH6600774010376550601`); Loader
  `GeschaeftRepository.get()` → `GeschaeftEinstellungen` mit Fallback-Gettern (`firma`,
  `adresseStrasse`, `adressePlzOrt`, `firmenIban`).
- Test-Referenz: `test/swiss_qr_test.dart` mit `parseSwissQrPayload(...)`.
- `reinigungen`-Preisfelder: `preisBrutto` (double?, Brutto-Total), zusätzlich Netto/MwSt/Grundtarif.
- Pakete vorhanden: `barcode ^2.2.9`, `qr ^3.0.2`, `flutter_svg ^2.0.0`.

## Entscheidungen (mit User geklärt)

- **Betrag:** mit `preisBrutto` **vorbefüllt, editierbar**; kein Preis → offener Betrag (leer).
- **Ort:** Button nur im **neuen-Reinigungs-Formular** (`reinigung_form_screen.dart`). Kein Detail,
  **kein Teilen** (nur On-Screen-Anzeige zum Scannen).
- **Anzeige:** QR **auf dem Bildschirm** (Kunde scannt vom Handy des Monteurs).
- **Keine DB-Migration.** Deploy als **v0.28.0**.

## Baustein A — Reiner QR-Payload (Extraktion + TDD)

### A.1 Neue reine Funktion
`sbs_projer_app/lib/core/util/swiss_qr_bill.dart`:

```
String swissQrPayload({
  required String iban,
  required String creditorName,
  required String creditorStreet,
  required String creditorNr,
  required String creditorPlz,
  required String creditorOrt,
  String creditorLand = 'CH',
  double? betrag,                 // null/<=0 -> leerer Betrag (offen)
  String debtorName = '',
  String debtorStreet = '',
  String debtorNr = '',
  String debtorPlz = '',
  String debtorOrt = '',
  String? referenz,              // gesetzt -> 'SCOR', sonst 'NON'
  String? mitteilung,            // Ustrd, auf 140 Zeichen gekürzt
})
```

Baut exakt die bestehende SPC-Zeilenstruktur (identisch zu `RechnungPdfService._buildQrData`):
`SPC / 0200 / 1 / IBAN / S / creditor… / (leere Ultimate-Creditor-Zeilen) / Betrag('' wenn null/<=0,
sonst 2 Dezimalen) / CHF / Debitor… / Referenztyp / Referenz / Mitteilung / EPD`.

### A.2 Bestehenden Rechnungs-QR umstellen (verhaltens-erhaltend)
`RechnungPdfService._buildQrData(...)` ruft künftig `swissQrPayload(...)` mit den bisherigen
Konstanten und dem Kunden als Debitor. Ergebnis muss **byte-identisch** zur heutigen Ausgabe sein
(Tests sichern das ab).

## Baustein B — On-Screen-QR-Widget

`sbs_projer_app/lib/presentation/widgets/swiss_qr_ansicht.dart`:
- `SwissQrAnsicht(payload, size)`: rendert den QR aus dem Payload via
  `Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium).toSvg(payload, width, height)`
  → `SvgPicture.string(...)`, mit **Schweizerkreuz** (kleines schwarzes Quadrat mit weissem Kreuz,
  ~1/6 der QR-Grösse) mittig via `Stack`. Weisser Hintergrund/Padding, damit scanbar.

## Baustein C — QR-Dialog im Reinigungs-Formular

`reinigung_form_screen.dart`:
- Button/ListTile **„QR-Zahlung"** (Icon `qr_code_2`) im Formular (bei den Preis-/Rechnungsfeldern).
- Klick → `showDialog` mit `_ReinigungQrDialog` (StatefulWidget, eigener Datei-Abschnitt oder Datei):
  - lädt einmalig `GeschaeftRepository.get()` → Firma/IBAN/Adresse (IBAN leer → Hinweis „Firmen-IBAN
    in den Einstellungen hinterlegen", QR ausgeblendet).
  - **Betrag-Feld** vorbefüllt mit `preisBrutto` (falls gesetzt), editierbar (Dezimal). Leer = offen.
  - baut Payload live via `swissQrPayload(iban, creditor…, betrag: eingegeben, referenz: null,
    mitteilung: 'Reinigung · ‹Betriebname› · ‹dd.MM.yyyy›')`.
  - zeigt **`SwissQrAnsicht`** + darunter Empfänger (Firma), IBAN (formatiert), Betrag als Text.
  - Adress-Zerlegung Firmenstrasse → Strasse/Nr (einfacher Split am letzten Leerzeichen);
    `adressePlzOrt` → PLZ/Ort (Split am ersten Leerzeichen). Robust gegen fehlende Teile.
- Der Betriebname/das Datum kommen aus dem aktuell im Formular bearbeiteten Reinigungs-Kontext
  (Betrieb + `datum`/heute).

## Abgrenzung

- Kein Teilen/PDF, kein Detail-Button (nur Formular). Keine Persistenz (QR wird flüchtig erzeugt).
- Keine Änderung am Rechnungs-QR-Verhalten (nur interne Extraktion, byte-identisch).
- Keine DB-Migration. Keine QR-IBAN-Sonderlogik (normale IBAN, Referenztyp `NON`).

## Tests & Verifikation

- **Unit-Tests** `swissQrPayload`: korrekte SPC-Struktur (Zeilenanzahl, Header/Trailer); Betrag null
  → leere Betragszeile, sonst 2 Dezimalen; `referenz` gesetzt → `SCOR`, sonst `NON`; Debitor leer →
  Address-Type leer; Mitteilung > 140 → gekürzt. **Round-Trip:** `parseSwissQrPayload(swissQrPayload(
  …))` liefert IBAN/Betrag/Referenz zurück (nutzt bestehende `parseSwissQrPayload`).
- **Regressions-Sicherung:** bestehende Rechnungs-QR-/swiss_qr-Tests bleiben grün (byte-identische
  Extraktion).
- `flutter analyze` ohne neue Findings; alle Tests grün.
- **Visueller Browser-Test** (Pflicht): neue Reinigung → „QR-Zahlung" → Dialog zeigt scanbaren QR
  (Schweizerkreuz), Betrag vorbefüllt aus preisBrutto + editierbar, Empfänger/IBAN korrekt; realer
  Scan-Test mit einer Banking-App (QR wird erkannt, Empfänger = SBS Projer, Betrag stimmt).

## Deploy

Ein Paket **v0.28.0** nach Deploy-Workflow (CLAUDE.md). Keine Migration, keine Edge-Function.
