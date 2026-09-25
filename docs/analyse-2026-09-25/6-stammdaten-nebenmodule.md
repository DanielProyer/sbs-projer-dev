# Analyse 6 — Stammdaten und Nebenmodule (Stand v0.138.0, 25.09.2026)

Nur gelesen, nichts geändert. Pfade relativ zu `sbs_projer_app/lib/`. Zahlen aus der Live-DB (SELECT, 25.09.) und `route_nutzung` (09.–25.09.).

## 0. Wichtigste Befunde vorab

| # | Befund | Schwere |
|---|---|---|
| **F1** | **Ferien aus dem Betriebsformular erreichen den Tourenplan nicht.** Das Formular liest/schreibt nur die alten 5 Spaltenpaare (`screens/betriebe/betrieb_form_screen.dart:181-192`, `:572-581`). Tourenplan und Heineken-Raster lesen seit Migration 160 die Tabelle `betrieb_ferien`, sobald sie geladen ist — dann schweigen die alten Spalten (`presentation/providers/betrieb_providers.dart:29-45`, `core/util/betrieb_ferien.dart:23-35`). Das Betriebs-Detail lädt dagegen per `BetriebRepository.getById` (`betrieb_detail_screen.dart:50`) **ohne** Perioden und zeigt die alten Spalten → Detail zeigt die Ferien, die Planung nicht. **Live: 9 Perioden nur in den Altspalten**, u. a. Edelweiss Vals 01.–26.12., Posta Veglia Flond 02.–23.11., Surselva Disentis 11.10.–04.11. (alle nach dem 31.07. erfasst). `betrieb_ferien` hat nur die 39 Import-Zeilen, letzte Änderung 31.07. | **hoch** (Fahrt zu geschlossenem Betrieb) |
| F2 | **Mahnung und Rechnung wählen die Mailadresse verschieden.** Rechnung: nur `betrieb_rechnungsadressen.email`, sonst intern (`services/rechnung/reinigung_rechnung_versand.dart:289-305`, Entscheid 16.07.). Mahnung: Rechnungsadresse, **sonst `betriebe.email`** (`core/util/mahnregeln.dart:329-340`) — der Kommentar «wie die Rechnung» (`:321`) stimmt nicht. Live: 131 Betriebe haben nur eine Betriebs-Mail, bei 32 weichen Betriebs- und RA-Mail ab. Noch harmlos, weil `mahnwesenScharf = false` (`core/config/mail_config.dart`). | mittel (vor dem Scharfstellen klären) |
| F3 | Rechnungs-Mailversand ist doppelt implementiert: `reinigung_rechnung_versand.dart:289` und Kopie in `screens/reinigungen/reinigung_form_screen.dart:970-990` (+ Nachversand `rechnung_detail_screen.dart:717`). | niedrig/Wartung |
| F4 | Firmenkontakt in PDFs hartcodiert statt aus `geschaeft_einstellungen`: `services/pdf/rechnung_pdf_service.dart:176`, `mahnschreiben_pdf_service.dart:393`, `kontoauszug_pdf_service.dart:475` («Tel 076 566 58 06 \| sbs.projer@gmail.com»), `heineken_pdf_service.dart:22`, `bestellung_pdf_service.dart:20`; dazu `data/models/geschaeft_einstellungen.dart:46` `kMail`. | niedrig |
| F5 | Zwei Modelle/Repos/Formulare für **dieselbe Tabelle `kontakte`**: `BetriebKontakt` + `betrieb_kontakt_repository.dart` + `betrieb_kontakt_form_screen.dart` (312 Z.) und `Kontakt` + `kontakt_repository.dart` + `kontakt_form_screen.dart` (501 Z.). | niedrig/Wartung |

## 1. Betriebs-Detail (`screens/betriebe/betrieb_detail_screen.dart`, 2023 Z., eine lange ListView, keine Tabs)

**Nutzung:** meistbesuchter Stammdaten-Screen — `/betriebe/:id` 100 Aufrufe (51 Handy), `/bearbeiten` 35, `/rechnungsadresse` 11.

| Abschnitt (Zeile) | Inhalt |
|---|---|
| AppBar (82-114) | Route Maps, **Kontoauszug-PDF**, **Protokolle-PDF je Jahr**, Bearbeiten, Löschen |
| Status-Chips (123) | Bergkunde, Saison … |
| Adresse (126), Kontakt (141) | `betriebe.telefon/email/website` |
| Details (171) | Status, Schliessung, Zapfsysteme, Mein Kunde, Bergkunde, Saison, Rechnungsstellung, Region |
| Nummern (214) | Betrieb-Nr (= `heineken_nr`), WE, AG |
| Saison (232), Ruhetage/Ferien (255), Öffnungszeiten (280), Servicezeiten (293) | |
| Service-Hinweis (321), Notizen (347) | |
| Kontaktpersonen `_KontakteSection` (731) | Tabelle `kontakte` |
| Rechnungsadresse (951), Anlagen (1052) | |
| Geplanter Service (1129), Reinigungen (1668), Störungen (1280), Eigenaufträge (1434) | |

**Fehlt im Detail / liegt anderswo**

| Information | Wo heute |
|---|---|
| Offene Rechnungen, Saldo | nur als PDF (Kontoauszug) bzw. `/rechnungen/pro-betrieb` (`offen_pro_betrieb_screen.dart`) — keine Zahl im Detail |
| Mahnstand / Mahnfall | `/rechnungen/mahnlauf`, `mahnfall_screen.dart` |
| Kundenguthaben (v0.137) | nur in Rechnungs-Detail/Mahnlauf/camt-Dialog |
| Montagen, Heineken-Rechnungspositionen | nur in eigenen Listen |
| Saison-Historie (`betrieb_saison_historie`) | nur im Formular (`betrieb_form_screen.dart:241`) |
| Ferien-Quelle/Bestätigung, offene Vorschläge (`betrieb_vorschlaege`) | `/betriebe/vorschlaege` |
| Fotos (Protokoll-Fotos) | nur via Reinigung bzw. PDF-Bündel |

**Doppelte Felder (E-Mail/Telefon)**

| Feld | Quelle | Live | Wofür benutzt |
|---|---|---|---|
| `betriebe.email` | Betriebsformular | 200/449 | Anzeige, Mahn-**Fallback** (F2), Vorlage für RA-Knopf (`betrieb_rechnungsadresse_form_screen.dart:55`, `core/util/adresse_aus_betrieb.dart:70`) |
| `betrieb_rechnungsadressen.email` | RA-Formular | 78/80 | **einziger** Rechnungsempfänger |
| `kontakte.email` (kategorie betrieb) | Personen | 3/108 | kein Versand, nur Google-Sync |
| `betriebe.telefon` / `kontakte.telefon` | | | beide → Google-Kontakte |

**Vorschlag «Betriebs-Akte»:** Kopf (Name, Status, Anruf/Route/Mail), dann aufklappbare Blöcke in Reihenfolge der Nutzung: *Heute wichtig* (Hinweis, Kulanz, nächster Termin, Ferien) → *Geld* (offen CHF, älteste Fälligkeit, Mahnstufe, Guthaben, Knöpfe Kontoauszug/Pro-Betrieb) → *Anlagen* → *Verlauf* (Reinigungen/Störungen/Montagen/Eigenaufträge gemischt, chronologisch) → *Stammdaten* (Adresse, RA, Personen, Nummern, Zeiten). CanvasKit-Regel beachten (kein `ExpansionTile dense`). Aufwand ~1–1.5 Tage.

## 2. Kontakte/Personen

| Quelle | Tabelle | Rolle | Richtung |
|---|---|---|---|
| Betriebs-Telefon/Mail | `betriebe` | Wahrheit für «den Betrieb» | App → Google |
| Personen | `kontakte` (108 betrieb, 5 heineken, 8 event) | Wahrheit für Personen | App → Google |
| Heineken-Rollen | `heineken_kontakt_zuweisungen` (`kontakt_repository.dart:120-152`) | welche Person bekommt Mahnfall/HeiGenie/Bestellung | — |
| Event-Rollen | `event_kontakte` (eventId, kontaktId, rolle) | Verknüpfung | — |
| Rechnungsadresse | `betrieb_rechnungsadressen` | Wahrheit für Rechnungsversand | — |
| Google-Kontakte | People API | **nur Kopie** (Anrufer-Erkennung) | einseitig App → Google, Edge Function `supabase/functions/google-contacts-sync/index.ts:89-191` (legt an/ändert/**löscht** in Google) |
| Handy-Adressbuch | Contact-Picker (`services/google/kontakt_picker_web.dart`) | manueller Import ins Formular | Handy → App, einmalig |

**Welche Mail gewinnt beim Rechnungsversand:** immer `betrieb_rechnungsadressen.email` (`reinigung_rechnung_versand.dart:289-305`; `reinigung_form_screen.dart:970`; `rechnung_detail_screen.dart:717`). Fehlt sie → Mail an Test-/Internadresse mit Hinweis. `betriebe.email` und Hauptkontakt-Mail spielen **keine** Rolle. Mahnung: RA → `betriebe.email` (F2). HeiGenie/Mahnfall: Heineken-Zuweisung (`reinigung_form_screen.dart:838`, `mahnfall_service.dart:124`). Live: 69 aktive «per Mail»-Betriebe ohne RA-Mail, davon nur 2 `ist_mein_kunde` und 0 mit Reinigung 2026 → aktuell kein Versandloch.

## 3. Anlagen / Material / Lager / Bestellung

| Modul | Tabelle (Live) | Zweck | Nutzung 09.–25.09. |
|---|---|---|---|
| Anlagen | `anlagen` 303, Bierleitungen | Technik je Betrieb, Steckbrief-Mail an RSL (`anlage_steckbrief_sheet.dart`) | Detail 12, Liste 2 (Liste nur noch über Stammdaten, `stammdaten_screen.dart:100`) |
| Material-Katalog | `material` 937 | Heineken-Artikel mit DBO/SAP | `/materialien` 4, Detail 3 |
| Lager | `lager` 57 (`material_id`, Bestand, Mindest) | eigener Bestand, Zähler «N niedrig» auf der Kachel | im Material-Detail |
| Bestellung | `material_bestellungen` 4 (letzte 15.09.), Positionen | Bestellung an Heineken-Kontakt, Abhol-Dialog bucht Zugang (`widgets/abhol_dialog.dart`) | bestellen 1, Liste 1 |
| Verbrauch | `material_verbrauch` 29 (letzter 11.09.) | Abgang aus Montage/Eigenauftrag/Event | — |
| Eingangsrechnungen | Kreditoren | **kein** Bezug zu Lager/Material | — |

Überschneidungen: Kachel «Material» = Katalog + Lager + Bestellung in einem (`materialien_list_screen`, `material_bestellung_screen` 817 Z., `bestellliste_screen`, `material_bestellungen_screen`) — zwei Listen für Bestellungen (Bestellliste = Vorgemerktes vs. Bestellungen = Historie). Reinigungen verbuchen keinen Verbrauch (Reinigungsmittel) → Lagerbestand nur halb gepflegt. Spesen-Scanner kennt das Stichwort «material», bucht aber nicht ins Lager. Nebenbefund: «Manual/Foto löschen» mit `FilledButton` (`material_detail_screen.dart:461`, ~`:712`) — CanvasKit-Falle, der Wächter fängt nur rote Knöpfe.

`route_nutzung` (Migration 190) wird im Code benutzt: `screens/auswertungen/nutzung_screen.dart` (Route `/auswertungen/nutzung`).

## 4. Events

| Umfang | Wert |
|---|---|
| Screens `screens/events/` | 12 Dateien, **9 059 Z.** (Detail 2 863, Technik-Tab 1 531) |
| Modelle/Repos/Provider/Local | ~3 000 Z. (+ `.g.dart`) |
| Migrationen | ~23 (event/stand/lageplan/kühler/gampel) |
| Tests | 7 Dateien |
| Verflechtung | `home_screen.dart:53` (`EventKarten`), `sync_service.dart:28-32`, Google-Kontakte-Sync liest `event_kontakte/events/event_staende`, gcal-`entity_type 'event'` (Migration 198), `MailConfig.eventScharf`, Edge `typenschild-lesen` |
| Daten | 3 Events, 31 Stände, letzte Änderung 13.08.2026 |
| Nutzung | `/events` 1, `/events/:id` 1 (seit 09.09.) |

Gampel läuft im eigenen Repo und exportiert in `event_aufwand` dieser DB → **Tabellen müssen bleiben**.

| Option | Aufwand | Risiko |
|---|---|---|
| **A: ausblenden** (Eintrag aus `kBereichMehr` in `core/config/bereiche.dart` nehmen, Route + Code bleiben, Kopfkommentar «eingefroren») | 15 min + Wächter-Test `menue_ziele_test` prüfen | sehr klein |
| B: archivieren (Screens in `lib/archiv/`, Router-Einträge raus, Home-Karte raus) | ~0.5 Tag | mittel: Sync, Kontakte-Sync, Tests hängen daran |
| C: löschen inkl. Tabellen | 1–2 Tage | hoch: Gampel-Export, Google-Kontakte (würde Event-Personen in Google löschen) |

**Empfehlung A.**

## 5. «Mehr» — Einstellungen / Stammdaten / Auswertungen

| Seite | Inhalt | Bemerkung |
|---|---|---|
| Stammdaten (`stammdaten_screen.dart`, 538 Z.) | Geschäft (`geschaeft_einstellungen`, Formular `widgets/geschaeft_form.dart`), Anlagen-Liste, Lohn-Einstellungen, MwSt-Sätze, Preise (Reinigung/Störung/Weitere), Biersorten, Regionen, Heineken (PO-Nummer, Kontakt-Zuweisungen) | Geschäftsdaten **gibt es** — sie werden nur von den PDFs nicht benutzt (F4). «Lohn-Einstellungen» doppelt: auch im Bereich Lohn. Material-Kategorien fehlen hier. |
| Einstellungen (`einstellungen_screen.dart`, 585 Z.) | Google-Kalender (verbinden, abgleichen, Termine zuordnen `/google-termine`), Google-Kontakte-Sync, Speicher (verwaiste Belege), Sync | `MailConfig`-Schalter (Test/Scharf je Bereich) nur im Code, nicht sichtbar — gehört als Anzeige hierher. Version/Build-Anzeige prüfen. |
| Auswertungen (`kBereichAuswertungen`) | Umsatz (`/buchhaltung/auswertung`), Arbeitstage, Nutzung der App | ok |
| Betriebe-Werkzeuge ohne Menüeintrag | `/betriebe/servicezeiten` (7), `/betriebe/saisondaten` (5, nur aus Tourenplan), `/betriebe/vorschlaege` (1, nur via Aufgabe) | Kandidaten für einen «Pflege»-Block in der Betriebsliste |

Nutzung «Mehr»-Ziele seit 09.09.: `/mehr` 30, `/stammdaten` 2, `/einstellungen` 1, `/einstellungen/regionen` 1, `/dokumente` 1, `/kontakte` 4, `/events` 1.

## 6. Priorisierte Vorschläge

| Prio | Vorschlag | Aufwand | Risiko |
|---|---|---|---|
| **1** | **F1 Ferien reparieren:** Formular auf `betrieb_ferien` umstellen (Perioden anlegen/löschen via `BetriebFerienRepository`), Detail über `betriebeProvider` bzw. mit geladenen Perioden; einmalige Nachübernahme der 9 Altspalten-Perioden (Migration wie 160, `quelle='kunde'`); danach Altspalten nicht mehr schreiben + Wächter-Test | 0.5–1 Tag | mittel (Planungslogik), mit Tests gut abgesichert — **Sofortmassnahme:** die 3 künftigen Perioden (Vals, Flond, Disentis) in `betrieb_ferien` nachtragen |
| 2 | F2 entscheiden: Mahnung wie Rechnung nur an RA-Mail (oder Rechnung auch mit Fallback) — **vor** `mahnwesenScharf = true`; Kommentar `mahnregeln.dart:321` korrigieren | 1 h | klein |
| 3 | Betriebs-Akte: Geld-Block (offen, Mahnstufe, Guthaben) im Detail, danach Umbau in Blöcke | 0.5 Tag (Geld-Block) / 1.5 Tage (ganz) | klein–mittel (CanvasKit, visuell prüfen) |
| 4 | Events aus «Mehr» ausblenden (Option A) | 15 min | sehr klein |
| 5 | F4 PDFs lesen Telefon/Mail aus `geschaeft_einstellungen` | 1–2 h | klein |
| 6 | F3 Rechnungs-Mailversand auf `ReinigungRechnungVersand` zusammenziehen | 2–3 h | mittel (Kernprozess) |
| 7 | F5 `BetriebKontakt` in `Kontakt` aufgehen lassen (ein Formular mit Vorbelegung `betriebId`) | 0.5 Tag | klein |
| 8 | `betriebe.email` klar als «Info» beschriften und im RA-Formular Abweichung (32 Fälle) anzeigen | 1 h | klein |
| 9 | Material: `FilledButton` in Lösch-Dialogen → `TapKnopf(gefahr: true)`; Wächter auf alle Lösch-Dialoge ausweiten | 30 min | klein |
| 10 | Einstellungen: Mail-Schalter (Test/Scharf je Bereich) als Nur-Lese-Anzeige | 1 h | klein |
