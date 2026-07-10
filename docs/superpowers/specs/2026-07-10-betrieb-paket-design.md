# Betrieb-Paket — Google-Datenübernahme, kundenabhängige Felder, Betriebe-Karte (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026)
**Herkunft:** Offener Punkt aus Paket 06 („Betriebe Google-Datenübernahme") + User-Anmerkungen.

## Ziel & Kontext

Ein Paket mit drei Betrieb-Bausteinen: (A) Betrieb-Stammdaten per Google anreichern, (B) rein
kundenbezogene Felder nur für eigene Kunden zeigen, (C) eine Karte aller Betriebe mit
Fälligkeits-Farbcodierung. Baut auf Vorhandenem auf: `Betrieb` hat bereits
`latitude`/`longitude`/`oeffnungszeiten`/`ruhetage`; die Fälligkeit ist in
`tour_providers.dart` fertig (`FaelligkeitsStatus` + `getFaelligkeit(anlage)`); die
swisstopo-Karte (flutter_map) stammt aus E3.

## Entscheidungen (mit User geklärt)

- **A Öffnungszeiten** werden mit übernommen (ins bestehende Format + Ruhetage ableiten).
- **A Bestätigungs-Dialog:** pro Feld ein Häkchen, **alle default gesetzt** (User hakt ab, was
  NICHT übernommen werden soll). Keine E-Mail (liefert Google Places nicht).
- **B:** Rechnungsstellung + Zahlername/Zahler-Aliase nur zeigen wenn `istMeinKunde == true`.
- **C Zugang:** Umschalter Liste ↔ Karte in der Betriebe-Liste.
- **C Farben:** volle Fälligkeits-Skala (bestehende `getFaelligkeit`).
- **C Scope:** alle Betriebe mit Filter-Leiste (meine Kunden / Region / nur fällige).
- **C ohne Koordinaten:** Zähler + Liste, von dort direkt der Google-Abgleich (A) zum Nachtragen.
- **D Route-Button:** Betrieb-Detail (und Karten-Popup) bekommen „Route in Google Maps"
  (öffnet die Navigation zum Betrieb).
- **Reihenfolge:** B → A → C → D. **Deploy als v0.25.0.**

## Datenmodell

Voraussichtlich **keine Migration**: `betriebe` hat bereits `latitude`, `longitude`,
`oeffnungszeiten` (jsonb), `ruhetage`, `telefon`, `website`, Adressfelder. Beim Planen das
exakte `oeffnungszeiten`-Format (wie im Betrieb-Formular editiert) verifizieren; falls ein Feld
für die Google-`place_id`/Maps-URL gewünscht ist, wäre das eine additive Spalte — vorerst **nicht**
vorgesehen (YAGNI).

## Baustein A — Google-Datenübernahme

### A.1 Supabase Edge-Function `betrieb-google-lookup`
- Deploy analog `send-pdf-mail` (`--no-verify-jwt`). Secret **`GOOGLE_PLACES_KEY`** (Supabase
  Secret, nie im Client-Bundle — die Web-App ist öffentlich).
- Eingabe (JSON): `{ query: string }` (z. B. „‹Betriebsname› ‹PLZ Ort›").
- Ruft **Google Places API (New)** `POST https://places.googleapis.com/v1/places:searchText`
  mit Header `X-Goog-Api-Key` + `X-Goog-FieldMask`:
  `places.displayName,places.formattedAddress,places.addressComponents,places.internationalPhoneNumber,places.nationalPhoneNumber,places.websiteUri,places.location,places.regularOpeningHours,places.googleMapsUri`.
- Rückgabe (erstes/bestes Ergebnis, normalisiert): `{ name, strasse, nr, plz, ort, telefon,
  website, latitude, longitude, oeffnungszeiten, ruhetage, mapsUri }`. Fehler/kein Treffer →
  `{ error }` bzw. leeres Resultat. Adress-Komponenten aus `addressComponents` (route,
  street_number, postal_code, locality) zusammensetzen; Telefon bevorzugt national, sonst
  international; Öffnungszeiten aus `regularOpeningHours` (periods → App-Format;
  geschlossene Wochentage → `ruhetage`).

### A.2 UI-Flow im Betrieb-Formular
- Button **„Aus Google übernehmen"** (oben im Formular, nur sinnvoll wenn Name gesetzt).
- Klick → Ladeindikator → Function-Aufruf mit `name` + `plz ort`.
- **Bestätigungs-Dialog** (`showDialog`): Liste der gefundenen Felder, je Zeile
  `Checkbox (default an) + Feldname + gefundener Wert` (bei bereits belegtem Feld zusätzlich der
  aktuelle Wert als „ersetzt: …"). Ganz oben der gefundene **Name** zur Kontrolle. Buttons
  „Abbrechen" / „Übernehmen".
- „Übernehmen" schreibt die angehakten Werte in die entsprechenden Controller/State-Felder des
  Formulars (kein Auto-Save; User speichert wie gewohnt). Fehler/kein Treffer → Snackbar.

## Baustein B — Kundenabhängige Felder

- **Betrieb-Formular:** „Rechnungsstellung"-Dropdown und „Zahlername/Zahler-Aliase" nur rendern
  wenn der „mein Kunde"-Schalter (`_istMeinKunde`) an ist (reaktiv via setState).
- **Betrieb-Detail:** dieselben Felder nur zeigen wenn `betrieb.istMeinKunde == true`.
- Werte bleiben in der DB erhalten (nur UI-Ausblendung), damit ein späteres Zurückschalten
  nichts verliert.

## Baustein C — Betriebe-Karte

### C.1 Umschalter in der Betriebe-Liste
- Oben in der Betriebe-Liste ein **SegmentedButton/IconButtons Liste ↔ Karte** (Muster wie
  E3-Stände-Tab). „Liste" = bestehende Ansicht unverändert; „Karte" = neue Karten-Ansicht.

### C.2 Fälligkeit je Betrieb (reine, testbare Funktion)
- `betriebFaelligkeit(List<FaelligkeitsStatus> anlagenStatus) → FaelligkeitsStatus`: den
  **schlimmsten** Status zurückgeben (Rangfolge: ueberfaellig > faellig > baldFaellig >
  endreinigungFaellig > eroeffnungFaellig > nichtFaellig). Leere Liste → nichtFaellig.
- Pro Betrieb dessen Anlagen laden und je Anlage `getFaelligkeit(...)` (bestehend) rechnen,
  dann aggregieren. Beim Planen den vorhandenen Anlagen-pro-Betrieb-Provider/-Query nutzen.

### C.3 Karten-Ansicht
- flutter_map + swisstopo-Luftbild (wie `event_staende_map.dart`, inkl. Repaint-Nudge).
- **Ein Marker je Betrieb** mit Koordinaten; **Farbe** nach `betriebFaelligkeit`:
  🔴 ueberfaellig · 🟠 faellig · 🟡 baldFaellig · 🔵 eroeffnung/endreinigung · 🟢 nichtFaellig.
  Farbwerte aus dem bestehenden Fälligkeits-Farbschema (Tour-Ansicht) wiederverwenden.
- **Auto-Fit** auf die Marker-Bounds; bei 0 Markern Hinweis + Karte auf die Schweiz.
- **Legende** (kompakte Farbleiste) unten/über der Karte.
- **Marker-Tap → Popup:** Betriebsname + Fälligkeits-Label + Button „Öffnen" (→ Betrieb-Detail
  über die bestehende Route).

### C.4 Filter-Leiste
- Über der Karte: **meine Kunden** (Toggle) · **Region** (Dropdown) · **nur fällige** (Toggle:
  überfällig/fällig/bald). Filter wirken auf die angezeigten Marker.

### C.5 Betriebe ohne Koordinaten
- Unter/über der Karte ein **Zähler „X Betriebe ohne Standort"** → tippbar → Liste dieser
  Betriebe → je Eintrag „Standort ergänzen" öffnet das Betrieb-Formular bzw. direkt den
  **Google-Abgleich (A)**, der Koordinaten nachträgt. So werden A und C verzahnt.

## Baustein D — „Route in Google Maps"

- **Betrieb-Detail:** Button/Icon **„Route"** (Navigation). Öffnet Google Maps mit dem Betrieb
  als Ziel:
  - mit Koordinaten: `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>`
  - sonst Adresse: `https://www.google.com/maps/dir/?api=1&destination=<URL-encodierte Adresse>`
  - via `url_launcher` `launchUrl(..., mode: LaunchMode.externalApplication)` (bestehendes Muster).
    Ohne Koordinaten UND ohne Adresse → Button ausgeblendet.
- **Karten-Popup (C.3):** zusätzlich zu „Öffnen" ein „Route"-Button mit derselben Logik.

## Abgrenzung

Keine E-Mail-Übernahme (Google liefert keine). Keine Änderung an bestehender Fälligkeits-/Touren-
Logik (nur Wiederverwendung/Aggregation). Kein Öffnungszeiten-Editor-Umbau (nur Befüllung über A).
Voraussichtlich keine DB-Migration. Kein Native-Test der Edge-Function nötig (Web-first;
Function ist plattformunabhängig).

## Technik-Risiken (verifizieren)

- **Google Places (New) Field-Mask & Kosten:** korrekte Feldnamen; Text Search + Details in einem
  Call; Free-Tier/Guthaben beachten. Ohne gültigen Key gibt die Function einen klaren Fehler
  zurück (UI-Snackbar).
- **Öffnungszeiten-Mapping:** Google `regularOpeningHours.periods` ↔ App-`oeffnungszeiten`-Format;
  geschlossene Tage → `ruhetage`. Format beim Planen exakt gegen das Betrieb-Formular abgleichen;
  im Zweifel Öffnungszeiten konservativ (nur wenn eindeutig mappbar) übernehmen.
- **Marker-Performance:** viele Betriebe (Hunderte) auf flutter_map — bei Bedarf einfache
  Marker (kein Clustering in v1; nachrüstbar).
- **Adress-Parsing** aus `addressComponents` (Strasse/Nr/PLZ/Ort) robust gegen fehlende Teile.

## Tests & Verifikation

- Unit-Tests: `betriebFaelligkeit`-Aggregation (Rangfolge, leere Liste); Adress-/Öffnungszeiten-
  Normalisierung (reine Funktion, mit Beispiel-JSON von Google Places).
- `flutter analyze` ohne neue Findings; Tests grün.
- Visueller Browser-Test (Pflicht): B (Felder erscheinen/verschwinden am „mein Kunde"-Schalter);
  A (Button → Dialog mit vorgehakten Feldern → Übernahme; echter Google-Treffer für einen realen
  Betrieb); C (Karte mit farbigen Markern, Filter, Popup „Öffnen", „ohne Standort"-Zähler).
- Edge-Function nach Deploy mit einem echten Betrieb testen (Key gesetzt).

## Deploy

Ein Paket **v0.25.0** nach Deploy-Workflow (CLAUDE.md). Edge-Function separat deployen
(`supabase functions deploy betrieb-google-lookup --no-verify-jwt`) + Secret `GOOGLE_PLACES_KEY`
setzen (nach Einrichtung des Keys durch den User).
