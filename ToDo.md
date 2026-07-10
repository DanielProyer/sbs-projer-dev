# ToDo-Liste — Daniel Projer (SBS Projer App)

**Stand:** 10.07.2026 · **Live:** v0.26.0

---

## 🟢 Betrieb-Lifecycle & Auto-„mein Kunde" (live v0.26.0 · 10.07.2026)
- [x] ✓ **Auto-„mein Kunde"**: reine Funktion `istMeinKundeVorschlag(status, zapfsysteme)` — inaktiv/geschlossen → false, sonst Konventionell/Orion → true. Greift im Formular bei Status-/Zapfsystem-Wechsel (manueller Override bleibt).
- [x] ✓ **Bereinigung (Migration 127)**: Clavadeleralp & Weissfluhjoch (Saisonbetriebe, fälschlich inaktiv) → aktiv; AMERON, Valentinos + 104 geschlossene → mein Kunde=false. Saisonbetriebe geschützt.
- [x] ✓ **Dauerhafte Schliessung**: Status „geschlossen" im Formular + Schliessungsgrund (Umnutzung/Abbruch/Konkurs/Sonstiges) + -datum; im Detail angezeigt.
- [x] ✓ **Sichtbarkeit**: Betriebe-Liste default nur aktive; Karte nur aktive/saisonpause + Filter-Chip „Inaktive/geschl.".
- [x] ✓ Qualität: subagent-getrieben, neue TDD-Suite (7 Tests), **263 Tests grün**, Web-Build sauber.
- [x] ✓ **Live geprüft** (10.07.2026): Formular-Auto-„mein Kunde" + Override, Schliessungsfelder, Liste/Karte-Sichtbarkeit — alles funktioniert.

---

## 🟢 Betrieb-Paket (live v0.25.0 · 10.07.2026)
- [x] ✓ **B — kundenabhängige Felder:** Rechnungsstellung + Zahlernamen erscheinen im Formular und Detail nur bei „mein Kunde".
- [x] ✓ **A — Google-Datenübernahme:** Button „Aus Google übernehmen" im Betrieb-Formular → Bestätigungs-Dialog (alle Häkchen default an) → übernimmt Adresse/Telefon/Website/Koordinaten/Öffnungszeiten. Edge-Function `betrieb-google-lookup` deployed (Key server-seitig).
- [x] ✓ **C — Betriebe-Karte:** Umschalter Liste↔Karte, Marker farbig nach Fälligkeit (schlimmste Anlage), Filter (meine Kunden/Region/nur fällige), Legende, Popup „Öffnen"/„Route", Zähler „X ohne Standort" → Formular.
- [x] ✓ **D — Route:** „Route in Google Maps"-Button im Betrieb-Detail und im Karten-Popup.
- [x] ✓ Qualität: subagent-getrieben, 3 neue TDD-Suites, **256 Tests grün**, Web-Build sauber.
- [x] ✓ **Google-API-Key gesetzt** (10.07.2026): `GOOGLE_PLACES_KEY` als Supabase-Secret hinterlegt, Edge-Function per echtem Testbetrieb verifiziert (Adresse/Telefon/Website/Koordinaten/Öffnungszeiten kommen zurück). Baustein A produktiv.

---

## 🟢 Events-Modul scharfgestellt + Testdaten weg (v0.23.1 · 10.07.2026)
- [x] ✓ **Testdaten gelöscht:** Event „Openair Val Lumnezia 2026" (+2 Kontakt-Zuordnungen, 3 Stände, 5 Anlagen, 5 Einsätze, 5 Aufwand-Zeilen) per Cascade entfernt; 2 Test-Lager-Abbuchungen zurückgebucht. Globale Kontakte bleiben.
- [x] ✓ **Abschluss-Mail scharfgestellt:** `eventScharf = true` in `mail_config.dart` — Abschlussbericht geht jetzt an die echten Empfänger (Eventverantwortlicher/RSL). **Events-Modul E1–E5 + Feinschliff produktiv.**

---

## 🟢 Events-Feinschliff 2 (live v0.23.0 · 10.07.2026)
- [x] ✓ **Einsatz-Formular:** Stand-Auswahl ganz oben; **ein** Material-Feld (Autocomplete mit Freitext-Option oben + Lager-Artikeln), Menge nur bei Lager-Artikel. Verwendetes Material (Lager oder Freitext) wird immer gespeichert.
- [x] ✓ **PDF:** verwendetes Material der Pikett-Einsätze inkl. Menge in der Einsatz-Tabelle.
- [x] ✓ **Stand-Kontakt:** bei „Kontakt zuordnen" mit Rolle „Stand" ist der konkrete **Stand auswählbar** (Migration 125: `event_kontakte.stand_id`); die Stand-Karte zeigt den zugeordneten Kontakt (Name · Tel) direkt an.
- [x] ✓ Qualität: subagent-getrieben (3 + Verifikation), finaler Review **APPROVED**, 244 Tests grün.
- [ ] **🟡 Weiterhin offen:** Testdaten „Openair Val Lumnezia 2026" löschen + Mail scharfstellen (`eventScharf=true`) NACH deiner Abnahme.

---

## 🟢 Events-Feinschliff (live v0.22.0 · 10.07.2026)
- [x] ✓ **„Montage generieren"** vom Zeit-Tab ins **3-Punkte-Menü** oben rechts verschoben (Zeit-Tab zeigt nur noch Total-Chip).
- [x] ✓ **PDF-Vorschau vor Versand** im Abschluss-Sheet (Button „PDF-Vorschau", `Printing.layoutPdf`).
- [x] ✓ **Professionelleres Abschluss-PDF** (dunkle Sektions-Header, Zusammenfassungs-Box, Zebra-Tabellen mit dunkler Kopfzeile, Fußzeile mit Datum + Seitenzahl).
- [x] ✓ **Material↔Lager im Pikett-Einsatz** (Migration 124: `event_einsaetze.material_id` + `material_menge`): Lager-Artikel per Autocomplete + Menge; Bestand (`bestand_aktuell`) wird **beim Anlegen** abgebucht (keine Storno-Automatik bei Bearbeiten/Löschen). Freitext-Material bleibt.
- [x] ✓ Qualität: subagent-getrieben (5 + Verifikation), finaler Review **APPROVED**, 244 Tests grün, visuell geprüft (Menü, Vorschau-Button).
- [ ] **🟡 Offen:** ⚠️ Bestand kann negativ werden, wenn Menge > Bestand (keine Validierung — bewusst). Testdaten von „Openair Val Lumnezia 2026" löschen + Mail scharfstellen (`eventScharf=true`) NACH deiner PDF-Abnahme.

---

## 🟢 Events-Modul — Phase E5 (live v0.21.0 · 10.07.2026) — Events-Modul E1–E5 KOMPLETT
Spec `docs/superpowers/specs/2026-07-10-events-e5-design.md`. **Abschluss-Mail** nach dem Event:
- [x] ✓ **Abschlussbericht als PDF** (ohne CHF): Zusammenfassung (Stände/Anlagen-in-Betrieb/Einsätze/Total-Std), Stände mit Anlagen + Inbetriebnahme, Zeit & Aufwand gruppiert nach Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen), Pikett-Einsatzliste. Sonderzeichen (`✓`/`–`/`—`) auf ASCII sanitisiert (Helvetica-Font).
- [x] ✓ **Empfänger-Sheet** (Menüpunkt „Abschluss-Mail senden" im 3-Punkte-Menü): Eventverantwortlicher (`event_heineken`) + RSL automatisch vorgeschlagen, mit E-Mail vorangehakt, ohne E-Mail ausgegraut; weitere Kontakte + freie Mail-Adresse; Versand kommasepariert in einem Aufruf (`send-pdf-mail`).
- [x] ✓ **Scharfstellung:** neuer MailConfig-Bereich `event` (`eventScharf=false`) → Testmodus geht an dich (dani.proyer@gmail.com), Sheet zeigt Hinweis. Keine DB-Migration.
- [x] ✓ Qualität: subagent-getrieben (6 Tasks), finaler Branch-Review **APPROVED**, 244 Tests grün (7 neue). Visueller Web-Test: Menü → Sheet mit RSL-Vorschlag (beat.joerg@heineken.com vorangehakt) + Testmodus-Hinweis, PDF fehlerfrei gebaut.
- [ ] **🟡 Am Handy testen + scharfstellen:** echten **Testversand** auslösen (geht an dein Postfach) und das **PDF prüfen** (Layout, Sonderzeichen, Inhalt). Danach `eventScharf = true` in `lib/core/config/mail_config.dart` setzen + neu deployen, damit die Mail an die echten Empfänger geht.

---

## 🟢 Events-Modul — Phase E4 (live v0.20.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e4-design.md`. Event-Detail jetzt mit **5 Tabs** (Kontakte | Stände | Einsätze | **Zeit** | Dokumente):
- [x] ✓ **Zeit-/Spesenerfassung** (neue Sync-Vertikale `event_aufwand`, Migration 123): Zeilen mit Datum + Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen) + Notiz + Stunden. Neuer Tab „Zeit" mit Total-Stunden-Chip, Erfassungs-Formular, Bearbeiten/Löschen. Spesen werden als zusätzliche Stunden verrechnet (kein CHF-Feld).
- [x] ✓ **Auto-Montage-Generierung**: Button „Montage generieren" aggregiert die Zeit-Zeilen **pro Eventtag** (≤5 Slots, >5 Tage → 4 Tage + „Weitere Tage") und öffnet das bestehende Montage-Formular **vorbefüllt** (Typ Anlass, Betrieb = Veranstaltungs-Betrieb, Startdatum, Slots, Stundensatz aus Preisliste). Du prüfst + speicherst → normaler Heineken-Abrechnungsfluss. Pikettdienst ist ein eigener Zeitblock; die E3-Einsätze bleiben reine Doku (nicht separat verrechnet).
- [x] ✓ Qualität: subagent-getrieben (10 Tasks + Migration), finaler Branch-Review **APPROVED**, 237 Tests grün (5 neue: DTO + 4 Aggregation). Visueller Web-Test: 5 Tabs, Zeit erfassen/Total, „Montage generieren" → Formular korrekt vorbefüllt (Fr 10.7. 16h · Fr 24.7. 8.5h → 24.50h × 80 = 1960 CHF).
- [ ] **🟡 Am Handy bestätigen (native, live):** Zeit-Live-Refresh (im Web erschien der 2. Eintrag erst nach Reload — Supabase Read-after-Write-Latenz; native/Isar instant); „Montage generieren" real speichern und in der Monatsrechnung prüfen.

- [x] ✓ **UI (v0.20.1):** Event-Tabs füllen die Breite gleichmäßig (kein Scrollen mehr auf dem Handy / Pixel 9), kompaktere Label-Abstände.
- [x] ✓ **GPS-Fix (v0.20.2):** „Standort erfassen" warf im Web `MissingPluginException` — Ursache war ein veralteter Web-Plugin-Registrant ohne `geolocator_web` (Build-Cache). Fix: `flutter clean` + Neubau (Registrant enthält geolocator wieder). Zusätzlich `ACCESS_FINE/COARSE_LOCATION` in `AndroidManifest.xml` ergänzt (für native Builds).

**Nächste Phase:** **E5** Abschluss-Mail (Einsatzliste + Zeiten/Spesen als PDF an Eventverantwortlichen + RSL, MailConfig-Bereich `event`, erst Test dann scharf) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E3 (live v0.19.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e3-design.md`. Event-Detail jetzt mit **4 Tabs** (Kontakte | Stände | Einsätze | Dokumente):
- [x] ✓ **Inbetriebnahme pro Anlage**: Live-Checkbox „in Betrieb" je Schankanlage in der Stand-Karte + Fortschritt-Chip („3/8 in Betrieb" / „✓ komplett"). Stand-Formular speichert Anlagen jetzt **id-basiert** (behält `in_betrieb`/`in_betrieb_am` beim Bearbeiten statt löschen+neu).
- [x] ✓ **GPS-Standort pro Stand** (`geolocator`): Button „Standort erfassen" an der Stand-Karte, einmaliger `getCurrentPosition` (LocationAccuracy.high), Web + native.
- [x] ✓ **Karten-Umschalter im Stände-Tab** (Liste ↔ Karte): `flutter_map` mit **swisstopo-Luftbild** (SWISSIMAGE WMTS, kein API-Key), Marker pro Stand mit GPS, Tap → Stand. Repaint-Nudge (onMapReady move) gegen CanvasKit-Grau-Kacheln.
- [x] ✓ **Einsätze-Tab** (Pikett): minimales Formular (Beschreibung*, Material-Freitext, optionaler Stand, Zeitpunkt=jetzt/editierbar), Liste neueste zuerst, bearbeiten/löschen. Volle Sync-Vertikale `event_einsaetze` (Migration 122). Grundlage für E4-Abschluss-Mail.
- [x] ✓ Qualität: subagent-getrieben (12 Tasks), finaler Branch-Review **APPROVED** (kritischer id-basierter Stand-Save geprüft), 232 Tests grün. Visueller Web-Test: Karte rendert swisstopo sofort, Marker bei Vella; Einsatz anlegen→DB→Liste→löschen; 4 Tabs + FAB-Index korrekt.
- [ ] **🟡 Am Handy bestätigen (native, live):** **GPS-Standort erfassen** (Browser-Automation kann den nativen Geolocation-Dialog nicht bedienen) → Marker erscheint auf swisstopo-Karte; Einsatz-Live-Refresh (im Web erschien neuer Einsatz erst nach Tab-Wechsel — Supabase Read-after-Write-Latenz; native/Isar instant).
- [ ] **🟡 Testdaten aufräumen:** Stand **Signina Bar** hat für den Karten-Test gesetzte GPS-Koordinaten (46.7355 / 9.1378, Vella) — vor Ort neu erfassen/überschreiben.

**Nächste Phase:** **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL, MailConfig-Bereich `event`) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E2 (live v0.18.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e2-design.md`. Event-Detail jetzt mit **3 Tabs** (Kontakte | Stände | Dokumente):
- [x] ✓ **Stände** pro Event-Jahr mit **Schankanlagen** (Typen: Oberthekengerät/OT, Hollandbuffet, Ausschankwagen, Sonstige) — dynamische Anlagen-Zeilen im Stand-Formular, Zusammenfassung „7× OT · 1× Hollandbuffet". Vorjahres-Übernahme (Checkbox im Event-Formular + Menü im Tab, Merge case-insensitive über Stand-Namen).
- [x] ✓ **Dokument-Ablage** pro Event-Jahr: PDF hochladen (Lageplan, Verteilung …) in privaten Storage-Bucket `event-dokumente`, ansehen (signed URL, PDF-Viewer), löschen. Migration 120 (3 Tabellen + Bucket + RLS).
- [x] ✓ Qualität: subagent-getrieben (10 Tasks), finaler Branch-Review **APPROVED** (kritischer Tab-Umbau: Kontakte-Tab unverändert; serverId→Anlagen-Kette + Native-Delete W1 sauber), 228 Tests grün (4 neue). Visueller Web-Test: Tabs, Stand+Anlagen anlegen, Dokumente-Tab bestätigt.
- [ ] **🟡 Am Handy bestätigen:** echter **PDF-Upload** des Lageplans (Datei-Dialog per Web-Automation nicht testbar) + Öffnen/Löschen; sowie ob die Stände-Liste direkt nach dem Anlegen refresht (im Web-Test kam der neue Stand erst nach Tab-Wechsel — evtl. nur Refetch-Latenz, beobachten).
- [ ] **🟡 Kosmetik offen (aus Review):** Anzahl-Feld korrigiert `_anzahl` intern auf 1, aktualisiert aber die sichtbare Eingabe nicht (kein Datenfehler); redundante Provider-Invalidierung nach Stand-Bearbeiten.

**Nächste Phasen:** **E3** Inbetriebnahme-Checkliste + GPS-Standorte der Stände + Karten-Tab (flutter_map + swisstopo-Luftbild, kein API-Key) + Pikett-Einsätze (Stand + Beschreibung + 1 Material) · **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL + optional, MailConfig-Bereich `event`) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E1 (live v0.17.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-09-events-e1-design.md`, Plan + Ablauf-Kontext `Prompts/07_Events_Ablauf.txt`. Neues Modul: Dashboard-Kachel **Events** → Event-Jahre («Albani Fest 2026»):
- [x] ✓ **Event-Jahr-Entität** (`events`, Migration 119): referenziert Veranstaltungs-Betrieb (zapfsysteme `Veranstaltungen`), Jahr + Termin, Status abgeleitet (kommend «in X Tagen»/laufend/vorbei/Termin offen). Abrechnung bleibt unverändert bei Montage «Anlass».
- [x] ✓ **Kontaktliste pro Event-Jahr** (`event_kontakte`): Rolle auf der Zuordnung (Eventverantwortlicher, RSL, OK, Bau, Stand, Monteur, Stardrinks, Sonstige), Bemerkung, Gruppierung; Kontakte bleiben globale Personen. **Vorjahres-Übernahme** (Checkbox beim Anlegen + Menü, Merge ohne Duplikate).
- [x] ✓ **WhatsApp + Anruf** direkt aus der Liste (wa.me mit CH-Normalisierung, getestet: +41 79 885 20 88 → wa.me/41798852088).
- [x] ✓ Qualität: subagent-getrieben (9 Tasks, je Spec-+Qualitäts-Review), finaler Branch-Review APPROVED, 224 Tests grün (15 neue), visueller Web-Test komplett (Anlegen, Zuordnen, Übernahme, Löschen). Review-Fixes W1+W2 umgesetzt (Native-Delete serverseitig; `KontaktRepository.save` generiert jetzt Client-UUID).
- [ ] **🟡 Bekanntes Verhalten (Multi-Device, W3):** Legen zwei Geräte offline dasselbe Event-Jahr an, scheitert der zweite Push am UNIQUE-Constraint dauerhaft still (`isSynced=false` bleibt). Bei Ein-Personen-Nutzung akzeptabel; fixen falls je zweites Gerät aktiv schreibt.
- [ ] **🟡 Kosmetik offen (K1/K3):** Status-Badge/Termin-Format in Liste+Detail dupliziert (gemeinsames Widget lohnenswert bei E2); Web-`getAll` ohne Pagination (irrelevant bei < 1000 Events).

**Nächste Phasen:** **E2** Lageplan-PDF + Stände + Anlagen pro Stand (Beispieldateien in `00_Event/`, nicht versioniert) · **E3** Inbetriebnahme + GPS-Standorte + Karten-Tab (flutter_map + swisstopo-Luftbild, kein API-Key) + Pikett-Einsätze (1 Material-Slot) · **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL + optional, MailConfig-Bereich `event`).

---

## 🟢 App-Optimierung — Paket 06 (P1 Quick-Wins, live v0.16.20 · 07.07.2026)
Optimierungspaket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Spec/Plan in `docs/superpowers`. P1 = 7 Quick-Wins:
- [x] ✓ **Eigenaufträge:** Status-Filter entfernt.
- [x] ✓ **Störungen:** Filter-Sheet nur noch **Anlagentyp + Km-Abrechnung** (Status raus, auf Wunsch), Badge-Zähler, Anlagentyp-Chips kapitalisiert.
- [x] ✓ **Reinigung:** Chip „Protokoll" statt „Foto"; **Service-Art** (Klartext) statt rohem `serviceTyp`; Zeiterfassung **kompakt einzeilig** (Datum/Start/Ende) in **Formular UND Detail-Übersicht**.
- [x] ✓ **Kontakte:** Heineken-Rolle **„Stardrinks"** (Migration 117).
- [x] ✓ **Betriebsferien:** 3 → **5 Slots** (Migration 118); Formular dynamisch (nur belegte Zeilen + „Weitere Ferien"); Detail zeigt Ferien 1–5; zentraler `betrieb_ferien.dart`-Util + **Bugfix** (`isBetriebOffen`/`_isBetriebAktiv` prüften bisher nur Ferien 1) → Touren/Termine/Heineken-Raster umgestellt; 8 neue Unit-Tests.
- [ ] **🟡 Visueller Check Betriebsferien (Handy, live):** Betrieb-Formular „Weitere Ferien" bis 5 + speichern/wieder öffnen, Betrieb-Detail zeigt Ferien 4/5. *(Störungen-Filter, Eigenaufträge, Reinigung-Detail + -Formular bereits am Web-Build bestätigt.)*

Vorgehen: subagent-getrieben (Phase A 5 Tasks parallel, Phase B 5 Ferien-Tasks sequenziell), je Task Spec- + Qualitäts-Review, finaler Branch-Review **APPROVED** (Web-Sync der neuen Ferien-Felder verifiziert), 210 Tests grün. **Migrationen 117 + 118 sind produktiv angewendet.**

**Noch offen aus Paket 06 (P2–P9, nicht begonnen):** Anlagen-Screen + Anlagen-PDF; Betriebe Google-Datenübernahme; Reinigung QR-Firmenkonto-Link; Kontakte Event-Struktur (Jahr/Rolle/WhatsApp); **Termine komplette Überarbeitung**; **Events-Feature** (Telefonliste, Einsätze + Material, Abschluss-Mail an RSL); **Tourenplanung** (UX, Ruhetage/Servicezeiten anzeigen, Default leerer Tagesplan, Auto-Speicherung, Drag-Fläche vergrössern).

---

## 🔴 OFFEN — relevant

### Buchhaltung-Aufräumen
- [x] ✓ **camt-Screens in „Bankauszug Import" integriert** (v0.16.19): Prüfliste, Regeln, Dateien sind jetzt Tabs im Import-Screen (4 Tabs unter einem Host `CamtBankauszugScreen`), Dashboard von 4 camt-Kacheln auf **eine** reduziert. Alte Routen als Redirects (`?tab=`), FAB nur im Regeln-Tab, „Zur Prüfliste" = Tab-Wechsel. Subagent-getrieben (3 Implementer) + adversariale Review (3 Lenses, 0 Bugs — Extraktion zeilengenau treu gegen Originale). Widget-Test (4 Tabs, FAB-Gate). Spec/Plan in docs/superpowers.
- [ ] **🟡 Visueller Check camt-Tabs (bei Gelegenheit):** kurz im Browser durchklicken — v.a. der **Import-Tab** (hatte historisch Render-Eigenheiten: GestureDetector statt Material-Buttons), Tab-Wechsel, FAB nur bei „Regeln", Download im Dateien-Tab, „Regel anlegen" aus der Prüfliste, Direktaufruf alter URLs landet im richtigen Tab.

### Eingangsrechnungen (TP-0..7 ✓ + Kategorien, live v0.16.18) — Scan→KI/QR→Lernen→Buchung→GKB-File→camt-Abschluss→Reversibilität→Datenhygiene→Kategorien
- [ ] **🟡 Kategorien ausführlich testen (bei Gelegenheit):** Grundfunktion bestätigt (Daniel, 29.06. — funktioniert). Noch im Alltag durchprobieren: (a) **Busse** beliebiger Kanton → `busse`/6280; (b) **Info-Doc** → erscheint in „Rechnungen", nach „Nur ablegen" in „Ablage"; (c) Umschalter + Kategorie-Filter; (d) Detail Kategorie ändern → Konto-Vorschlag. **Falls die KI eine Kategorie falsch trifft → Beleg an Claude, Prompt nachschärfen.**
- [x] ✓ **Eingangsrechnung-Kategorien** (v0.16.18): 15 inhaltsbasierte Kategorien (KI klassifiziert aus dem Inhalt → löst Bussen-Erkennung kanton-unabhängig). Tabelle `eingangsrechnung_kategorie` (code→Konto-Default), Spalte `kategorie`, KI-Output (Whitelist-normalisiert), `schlageKontoVor` (Regel > Kategorie-Default > leer, MwSt-gekoppelt), UI: Dropdown in Upload+Detail (Konto-Update bei Wechsel) + Liste „Rechnungen | Ablage"-Umschalter + Kategorie-Filter + Label. Subagent-getrieben (3 Implementer) + adversariale Review (6 Bugs gefixt: Vorsteuer/MwSt, Whitelist, Dropdown-Crash-Guard, Ablage-Sicht, Detail-Konto, Upload-Dropdown). Spec/Plan in docs/superpowers. *Minor offen:* Kategorie-Filter erreicht künftig deaktivierte Kategorien nicht (Designentscheidung).
- [x] ✓ **GKB-Zahlungsfile Test-Upload BESTANDEN** (29.06.): `pain.001.001.09`-File testweise im GKB-E-Banking hochgeladen → **akzeptiert**. Das `.ch.03`-Profil ist damit real bestätigt, das File ist bankfähig.
- [x] ✓ **TP-5/6 End-to-End validiert** (29.06., synthetisches camt): voller Round-Trip mit echter Heineken-Rechnung + synthetischem camt.053 getestet — Belastung → Referenz-Match (QRR) → Stufe-2-Buchung (2000→1020) → Status `bezahlt` → „Zahlung rückgängig" → wieder offen + re-importierbar → Re-Match erscheint. Alles korrekt (per SQL geprüft), Test-Daten aufgeräumt. **Empirisch offen bleibt nur:** ob die GKB im camt bei DBIT die QRR/SCOR-Referenz zurückspielt (sonst greift Fallback IBAN+Betrag) — zeigt sich erst am echten GKB-Auszug.
- [x] ✓ **UX-Cleanup Dashboard** (v0.16.17): alten `camt-Abgleich`-Screen entfernt (Screen + Route + Links + redundante Kachel). Alles läuft über den vereinten „Bankauszug Import" (camt-import = Kundenzahlungen + Kreditoren + Ausgaben).
- [x] ✓ **Storno-Saldo-Fix** (v0.16.15): Bilanz + Erfolgsrechnung überspringen jetzt auch Storno-Gegenbuchungen (`stornoVonId != null`) → ein Storno nettet korrekt auf 0 statt −Original. Geprüft: aktuell 0 Gegenbuchungen (die 13 „stornierten" sind Jahresgewinn-Abschlüsse, kein echter Storno) → keine Änderung bestehender Salden; greift beim ersten echten Storno (z.B. TP-6 Path-B).
- [x] ✓ **TP-7 Datenhygiene** (29.06.2026, Migration 115): 28 inaktive Vorlagen-Duplikate gelöscht (waren ohnehin aus Dropdowns gefiltert); Konten-Altlasten bereinigt — 8090/8500/2850 gelöscht (Platzhalter/Duplikate, 0 Buchungen), 9000/9100 von „FEHLER…"-Namen auf „Gewinn-/Verlustübertrag (Abschluss)" umbenannt. Reine DB-Daten, kein Deploy. *(Hinweis Buchhaltung: Jahresergebnis liegt im Standard auf EINEM Konto 2980; 9000/9100 sind eigentlich Abschlusskonten Erfolgsrechnung/Bilanz — Daniel nutzt sie bewusst als Gewinn-/Verlustübertrag, unkritisch da App das Ergebnis aus den Erfolgskonten rechnet.)*
- [x] ✓ **Cleanup (v0.16.16, 29.06.):** toter Code entfernt (`forderungenProvider`/`mahnwesenDashboardProvider`/`getMahnwesenDashboard`, Invalidierung läuft über `rechnungenStreamProvider`); TP-6 `resetNachBuchungStorno` Fallback via `beleg_id` (verwaiste Zahlungs-Buchung wird freigegeben). **Offen (niedrige Prio):** volle Atomarität der Stufe-2-Rücknahme via DB-RPC/Transaktion — heute self-healing per Retry.
- [x] ✓ AXA-Personenversicherung Seed-Regel: **5730 (Unfall/UVG-Zusatz) von Daniel bestätigt** (29.06.) — bleibt korrekt, nichts zu ändern.
- [ ] Sicherheit: Edge-Functions `parse-rechnung` + `parse-beleg` mit `verify_jwt=false` → auf `true` härtbar (schützt API-Credits). App sendet via `functions.invoke` ohnehin das User-JWT → funktional sicher; braucht aber einen **Edge-Function-Redeploy = eigener Schritt**.
- [x] ✗ **DB-UNIQUE-Index verworfen** (statt umgesetzt): würde den bewussten Sammel-/Teilzahlungs-Pfad brechen (mehrere 'zahlung'-Buchungen je Beleg bzw. gleicher tx_key — Memory-Merksatz). App-seitige Idempotenz-Guards sind hier das richtige Mittel. *Optional offen:* 5-Rappen-/Spesen-Toleranz beim Kreditor-Betragsmatch (heute exakt = sicher).

### Scharfstellung / Live-Betrieb (Buchhaltung 01.07.2026)
Strategie: **Voll-Übernahme** (kein Clean-Start) — Historie lückenlos 27.03.2019→heute im System, Bilanz geht an allen Jahresenden auf, Salden laufen weiter. „Scharfstellen" = nur noch:
- [ ] **Mail-Bereiche scharfstellen:** `bestellungScharf` + `mahnwesenScharf` in `mail_config.dart` (stehen noch auf Test-Empfänger).
- [ ] **camt-Auto-Buchung produktiv** ab Stichtag 01.07.2026 (gebaut, geht automatisch scharf). **Erster Echtlauf Anfang August** (Juli-camt): Ergebnis-Report + Prüfliste durchgehen, neue wiederkehrende Empfänger als Regel anlegen.
- [ ] **2026 gezielt** auf vereinzelte Test-Buchungen durchsehen (NICHT pauschal; echte Live-Buchungen bleiben).

### Buchhaltung — Fachfragen / Sichtprüfung (Daniel)
- [ ] **B1:** Lohnaufwand 5000 liegt ~1–2k/Jahr über Lohnausweis-Brutto — klären (AG-Beiträge/Spesen drin? oder überbucht?). Relevant für AHV-/Steuerbasis.
- [ ] **B3:** MWST-Zahllast 2023 App 8'014 vs. deklariert ≈6'635 (+1'379) — Quartals-Timing/Buchung prüfen (andere Jahre decken sich exakt).
- [ ] **Abschreibungen Alt-Forderungen:** 2019–2022 ≈50k Kandidaten (kaum eintreibbar) — wieviel/welche Kunden definitiv abschreiben (Debitoren-Hub: 3805/1100 netto + 2200 MWST-Rückholung) vs. Delkredere 5%? Daniel entscheidet selbst. (Negative Salden 2202/2273/8900 = Timing-Konten, KEINE Abschreibung.)
- [ ] **1100-Plausibilität** im Debitoren-Screen gegen die offenen CHF 105'240.95 prüfen.
- [ ] **App-Sichtprüfung Scans:** zeigen Protokoll-/Zahlbeleg-Scans an Reinigungen/Forderungen korrekt? (Bucket `reinigung-fotos`, `import/010,020/` → signed URL).
- [ ] **Optional Excel-Gegencheck:** Excel-Bilanz auf 31.12.2024 neu rechnen → bit-genauer Abgleich Kasse/Debitoren/Bank.
- [ ] **Phase 0c:** Offene-Posten-Sicht (Debitoren 1100 / Kreditoren 2000).

### camt / Code-Politur (klein, unkritisch)
- [ ] Import: statische Überschrift „Kundenzahlungen" bleibt nach „Alle verbuchen" stehen.
- [ ] Import-Archiv-Dateiname hart `camt.xml` (nur Anzeige; `picked.name` mitführen).
- [ ] `verbuche` nicht in echte DB-Transaktion geklammert (durch Idempotenz-Guard abgesichert).
- [ ] camt I2: Netzfehler nach Buchung vor Rechnung-Update → verwirrender Prüflisten-Eintrag (kein Doppelbuchen) — Transaktionalität verbessern.
- [ ] camt-Regeln beobachten/verengen: `'abschluss'` (Substring breit); Lohn „daniel proyer" ggf. → IBAN `CH7909000000870500683`; Heineken „heineken" → „heineken switzerland".
- [ ] Saldo-Parsing-Bug (vorbestehend): `OPBD/CLBD` als 0 gelesen (`CdOrPrtry` liegt unter `Tp`). Pipeline nutzt es nicht, aber falsch.
- [ ] Phase 0a Follow-up: 11 alte camt-Vorlagen `ist_aktiv=true` (FK-Schutz) — optional Regeln auf neue Geschäftsfälle umhängen, dann Alt-Vorlagen deaktivieren (tauchen sonst im manuellen Dropdown auf).
- [ ] Hub: toter Code `forderungenProvider` / `mahnwesenDashboardProvider` entfernen (invalidate auf `rechnungenStreamProvider` umbiegen).
- [ ] **App-weite UI-Vereinheitlichung** (Filter/Dropdowns) — eigener grösserer Durchgang. Referenz-Stil: schlichte `DropdownButton` im `Wrap`.

---

## 🟢 BACKLOG (kein Zeitdruck)
- [ ] **GIS Regionen-Polygone** für 15 Regionen (KML/GeoJSON, WGS84/EPSG:4326). Tools: QGIS / Google Earth Pro / My Maps.
- [ ] **Beta-Testing-Phase** (echte Geräte, Real-World, Offline-Modus Bergkunden).
- [ ] **Beleg-Foto** Ausrichtung/Zuschnitt optimieren (Deskew, Crop, Kontrast).
- [ ] **Bulk-Sync Handy-Kontakte ↔ App** (App-Kontakte priorisiert, Matching über normalisierte Nr., Bestätigung vor Übernahme).
- [ ] **Termin-Erinnerungen Folge-Tests:** Web (Browser-Notification + In-App), Android-APK (lokale Benachrichtigung bei geschlossener App, Berechtigungen).
- [ ] **A4 Wiederkehrende Buchungen** / **A5 Monatsabschluss-Checkliste** (nice-to-have; A4 teilweise via Vorlagen + camt-Regeln abgedeckt).
- [ ] **Nach MVP:** Franchise-Partner einladen · zusätzliche Regionen definieren · Partner schulen.

---

## 📌 Merksätze / Design-Entscheidungen (NICHT ändern)
- **Kein DB-Unique-Constraint auf `buchungen(camt_tx_key)`:** der Kundenzahlungs-Pfad stempelt denselben `tx_key` absichtlich auf mehrere Buchungen (Sammelzahlung). Dedup läuft über den In-App-Set (Single-User).
- **App ist alleinige Buchungsquelle** (DB-Trigger `rechnungen_auto_buchung_zahlung` abgeschaltet, Migration 102). „Rechnung gestellt"-Trigger `…_erstellt` bleibt aktiv.
- **Alle Rechnungstypen werden NUR über den camt-Abgleich als bezahlt gebucht** (echtes Bankdatum, `camt_tx_key`/reversibel, gegen echte Bankbewegung). Kein manuelles „Als bezahlt markieren" mehr: Kundenrechnung-Detail-Button + Hub-Sammelzahlung (v0.15.2/0.15.3) und Heineken-Bezahlt-Schritt (v0.15.4) entfernt. Jahresrechnung nutzt denselben Rechnungs-Detail/Hub → automatisch abgedeckt. Heineken: offen→gesendet→freigegeben bleibt manuell, **bezahlt nur via camt** (Button nur noch Anzeige „Zahlung über Bankabgleich").
- **Jede grosse Liste paginieren** (PostgREST deckelt bei 1000).
- **Reversibilität:** alle camt-Buchungen tragen `camt_tx_key` → „mach die camt-Buchungen rückgängig".
- **QR-Bill:** SCOR (RF…) wegen normaler IBAN (keine QR-IBAN); QR-Code braucht zwingend das Schweizerkreuz.
- Historie (`quelle='excel_import'`/Reinigungen/Forderungen) ist echte Daten — **NICHT löschen**.

---

## ✅ Erledigt (Chronik, neueste zuerst)
- **v0.15.2–0.15.4** (25.06) **Manuelles Bezahlt-Markieren komplett entfernt** — Kundenrechnung-Detail-Button (v0.15.2) + Hub-Sammelzahlung (v0.15.3) + Heineken-Bezahlt-Schritt (v0.15.4). Bezahlt läuft für ALLE Rechnungstypen nur noch über den camt-Abgleich (echtes Datum, reversibel). Jahresrechnung automatisch abgedeckt (gleicher Screen). ~530 Zeilen weniger.
- **v0.15.1** (25.06) **Rechnungsadresse-Modell vereinfacht:** Adresse wird nur noch **beim Betrieb** gepflegt (Link „Adresse beim Betrieb bearbeiten" im Rechnungs-Detail → bestehendes Betrieb-Formular). Rechnung hat nur noch **„Rechnung erneut senden"** (Bestätigung → PDF neu mit aktueller Betriebsadresse + **Fällig bis = heute+30** persistiert → Mail an Kunde). Per-Rechnung-Adress-Dialog (v0.15.0) entfernt. Snapshot-Feld `rechnungen.rechnungsadresse` (Migration 105) bleibt technisch bestehen (Resolver Override→Betrieb), wird aber nicht mehr gesetzt.
- **v0.15.0** (25.06) Rechnungsadresse-Dialog im Detail + Neu-Versand (durch v0.15.1 zu „Adresse beim Betrieb" umgebaut). „Neue Buchung"-Kachel entfernt (v0.14.1) + Adress-Button-CanvasKit-Fix (v0.14.2).
- **v0.14.0** (25.06) **Pro-Rechnung Rechnungsadresse** (Override/Snapshot, Migration 105 `rechnungen.rechnungsadresse` jsonb): „Adresse anpassen" im Rechnungs-Detail ändert nur diese eine Rechnung (Betrieb/andere Rechnungen unberührt); PDF/Mahnung nutzen den Override via reinem Resolver `effektiveRechnungsadresse`; „Zurücksetzen" auf Betriebsadresse.
- **v0.13.3** (25.06) Temporären Rechnungs-Nachversand-Screen entfernt (Backlog abgearbeitet).
- **v0.13.2** (25.06) QR-Referenz-Kollision robust (Suffix-Retry statt PostgrestException).
- **v0.13.1** (25.06) Schweizerkreuz im QR-Code (Rechnung+Mahnung) — QR war ohne ungültig.
- **v0.13.0** (25.06) **TP-C QR-Referenz (SCOR)**: Migration 104, Util `scor_referenz.dart`, Vergabe in `RechnungRepository.create`, SCOR in Rechnungs-/Mahnungs-PDF, Matching-Stufe 1. Plan: `docs/superpowers/plans/2026-06-25-camt-qr-referenz-scor.md`.
- **v0.12.x** (25.06) **TP-B Zahler→Betrieb-Lernen**: Aliase am Betrieb (`betriebe.zahler_aliase`, Migration 103), Matching-Stufe 2, Auto-Treffer-Lern-Schalter. Plan: `docs/superpowers/plans/2026-06-25-camt-zahler-betrieb-lernen.md`.
- **v0.11.x** (20.06) **TP-A Import+Abgleich vereint** (Stichtag 11.03, `AbgleichVorschau` geteilt), Bestätigungs-Modus, Doppelbuchung-Fix (Migration 102), Reversibilität, Lohn/Miete-Trennung.
- **v0.10.138** (20.06) camt-Forderungsabgleich **TP2** (Engine `ForderungsAbgleichService`, Archiv `camt_dateien` Migration 101, ⚪-Bucket, existsZeitraum-Dialog).
- **v0.10.133** (19.06) Forderungen-Historie **TP1** (7'786 Reinigungen + 4'438 Rechnungen, offen CHF 105'240.95, Scans verknüpft, Pagination-Fix).
- **v0.10.130** (18.06) Berichtswesen-Umbau, Geschäfts-Einstellungen (`geschaeft_einstellungen`), Lohn-Trennung, MWST-Sätze-Historie, Gast-Account deaktiviert.
- **v0.10.118** (13.06) Forderungen-Hub; Buchhaltung Phase 0b/1/2 (Excel-Voll-Import 14'552 Zeilen 2019–Nov 2025, Bilanz geht auf, Audit/Abschreibungs-Werkzeug, MWST-Bugfixes).
- **Datenkorrektur** (25.06) Phantom-Zahlung 17.05. (4 Rechnungen 2026-05-0611–0614) bereinigt.
- **Früher:** Heineken-Monatsraster + Auto-Buchung, Lohnbuchhaltung, Spesen-OCR, camt.053-Import, Material-Modul, Termine/Kalender, Störungen/Pikett, Kontakt-Sync u.v.m. → siehe git-History + Memory.

---

*Detaillierte Technik-Kontexte: Memory-Index + `docs/superpowers/` (Specs/Pläne) + git-History.*
