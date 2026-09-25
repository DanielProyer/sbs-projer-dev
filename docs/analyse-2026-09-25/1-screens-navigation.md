# Analyse 1: Screens, Navigation und Doppelspurigkeiten (Stand v0.138.0, 25.09.2026)

Nur gelesen, nichts geändert. Basis: `lib/core/config/router.dart` (95 GoRoutes, davon 7 reine Redirects), `bereiche.dart`, `navigation_ziele.dart`, 117 Dateien unter `presentation/screens` (≈ 69'400 Zeilen) und `presentation/widgets`. Die Nutzungszahlen stammen aus `route_nutzung` vom 09. bis 25.09.2026, Angabe als **Gesamt/Handy**. Befunde A1–A9 und B1–B7 der Analyse 09/2026 wiederhole ich nicht. Wo ein Punkt dort nur teilweise erledigt ist, steht es ausdrücklich dabei.

Flags: **D** = Doppelspurigkeit · **U** = nur über Umweg erreichbar · **V** = veraltet oder eingefroren · **G** = über 1500 Zeilen · **T** = toter Code

---

## 0. Die fünf wichtigsten Befunde

1. **Möglicher Doppel-Datensatz beim Start-Pfeil.** Im Tagesplan stehen Störungen und Montagen als **bestehende** Datensätze (`id: 's_<routeId>'`, `tour_providers.dart:684/1610`). Der Start-Pfeil in Heute (`heute_liste.dart:443–448`) und «Störung/Montage erfassen» im Block-Sheet des Tourenplans (`tourenplanung_screen.dart:1880–1905`) öffnen aber `/stoerungen/neu` bzw. `/montagen/neu`. Das legt einen **zweiten** Einsatz an, statt den geplanten zu bearbeiten. Bitte fachlich klären (Kleinfix).
2. **Der meistgenutzte Vorgang hängt noch an Material-Buttons.** `/reinigungen/neu` hatte 113 Aufrufe, 111 davon am Handy, und ist damit der häufigste Pfad überhaupt. Trotzdem sitzt «Reinigung abschliessen» auf `FilledButton.icon`/`OutlinedButton.icon` (`reinigung_form_screen.dart:1989/2000/2008`) und die Bestätigung auf `FilledButton` (`:1464ff`). Störung und Montage nutzen dafür `ArbeitBeendenKnopf`. B7 hat nur den Rot-Wächter geliefert, das gemeinsame «Arbeit beenden»-Widget für alle Typen fehlt noch.
3. **Der Gefahr-Wächter hat drei Lücken.** 17 unumkehrbare Bestätigungen laufen weiter über Material-Buttons (Liste in §3.2). Die Gründe:
   - Er prüft nur `X(`, nicht `X.icon(`.
   - Er erkennt nur `AppColors.error`, nicht `Colors.red`.
   - Einen **ungefärbten** `FilledButton('Löschen')` findet er gar nicht.

   Zwei rote Knöpfe haben zudem **keine Rückfrage**: «Leeren» des ganzen Tagesplans (`tourenplanung_screen.dart:1091` → `leeren()` sofort gespeichert) und Google-Kalender «Trennen» (`einstellungen_screen.dart:319`).
4. **Auf der Betriebsseite fehlen Montagen ganz.** `betrieb_detail_screen.dart` hat drei eigene Einsatz-Sektionen (Reinigungen, Störungen, Eigenaufträge), jede mit eigener Zeilen-Klasse. Montagen, Eröffnungs- und Pikett-Einsätze fehlen dort ganz; «montage» kommt in der Datei 0-mal vor. Auf der Anlagenseite fehlen die Montagen ebenfalls.
5. **Die sechs Einsatz-Detail- und Formularseiten sind Kopien statt Bausteine.** Beispiele:
   - `_SectionCard` steht 11-mal im Code, `_InfoRow` 13-mal (textgleich).
   - Die Betrieb-Autocomplete gibt es 5-mal (~85 Zeilen je Kopie).
   - Material-Slots, Arbeit beginnen/beenden und Zeitfelder sind zwischen Störung und Montage fast identisch (~400 Zeilen doppelt).
   - Es gibt 29 einzelne `showDatePicker`-Aufrufe ohne gemeinsamen Helfer (bei der Zeit gibt es ihn: `zeigeZeitauswahl`).

---

## 1. Inventar

### 1.1 Navigation (Gerüst)
| Screen / Route | Zeilen | Zweck | Einstiege | Nutzung | Flag |
|---|---|---|---|---|---|
| `HomeScreen` `/` | 190 | Heute: Event-Karten, Aufgaben-Karte, Arbeitstag, Heute-Liste, FABs Diktieren und Beleg | Leiste | 161/57 | |
| `BereichScreen` `/mehr` `/bank` `/abschluesse` `/auswertungen` | 68 | datengetriebene Menüseiten aus `bereiche.dart` | Leiste «Mehr», Bereichseinträge | 30/7 · 6 · 1 · 2 | |
| `SucheScreen` `/suche` | 241 | Betriebe, Personen, Rechnungen, Bereiche | Lupe Heute, Feld auf Mehr | 2/2 | |
| `LoginScreen` `/login` | 192 | Anmeldung, Passwort zurücksetzen | Redirect | – | |

### 1.2 Unterwegs: Einsätze, Betriebe, Tour
| Screen / Route | Zeilen | Zweck | Einstiege | Nutzung | Flag |
|---|---|---|---|---|---|
| `EinsaetzeScreen` `/einsaetze` | 356 | eine Liste für alle Einsatztypen, «+»-Typwahl | Leiste, Monatsabschluss, Suche (Pikett) | 34/9 | |
| `ReinigungBetriebAuswahlScreen` `/reinigungen/neu` ohne betriebId | 102 | Vollbild-Betriebswahl nur für Reinigung (ListTile-Zeilen) | Einsätze «+» | (in 113) | **D** zur Autocomplete der anderen Formulare |
| `ReinigungFormScreen` `/reinigungen/neu`, `/:id/bearbeiten` | 2818 | Erfassung inkl. Anlagen, Fotos, Positionen, QR, Abschlusskette | Heute ▶, Tour-Sheet, Betrieb, Diktat, Einsätze | **113/111** | **G** (`_save` allein 820 Zeilen, 569–1389) |
| `ReinigungDetailScreen` `/reinigungen/:id` | 1286 | Anzeige, Protokoll-Foto, Rechnung erstellen und senden | Betrieb, Anlage, Tour, Bergkunden, Einsätze | 8/2 | **D** (Detail-Gerüst) |
| `StoerungFormScreen` `/stoerungen/neu`, `/:id/bearbeiten` | 1519 | Störung mit Zeiterfassung, Material, Preis | Heute ▶, Tour, Betrieb, Anlage, Einsätze | 13/8 · 3/2 | **G**, **D** zu Montage |
| `StoerungDetailScreen` `/stoerungen/:id` | 873 | Anzeige, Erledigt, Rapport-PDF | Tour, Betrieb, Anlage, Einsätze | 4/3 | **D** |
| `MontageFormScreen` `/montagen/neu`, `/:id/bearbeiten` | 2180 | Montage und Anlass-Slots, Heigenie, Fotos, Zeit | Heute ▶, Tour, Einsätze | 11/9 | **G**, **D** |
| `MontageDetailScreen` `/montagen/:id` | 777 | Anzeige, Erledigt, Rapport | Tour, Einsätze (**nicht** Betrieb/Anlage) | – | **D**, **U** |
| `EigenauftragFormScreen` / `DetailScreen` | 548 / 460 | Eigenauftrag | Betrieb, Einsätze | 1 (Liste) | **D** |
| `EroeffnungsreinigungFormScreen` / `DetailScreen` | 387 / 353 | Saisoneröffnung (Beleg) | Einsätze | 1/1 | **D**, **U** (nicht auf der Betriebsseite) |
| `PikettDienstFormScreen` / `DetailScreen` | 487 / 380 | Wochenend-Pikett | Einsätze (`?typ=pikett`) | 0 | **D** |
| `TourenplanungScreen` `/touren` | 2813 | Woche, Tagesplan-Zeitachse, Fällig, Block-Sheet | Leiste, Heute, Aufgaben | 86/16 | **G** |
| `TagesKarteScreen` (keine Route) | 316 | GPS-Stempel des Tages auf der Karte | nur Icon im Tourenplan (`MaterialPageRoute`, :346) | wird nicht gezählt | **U** |
| `BetriebeListScreen` `/betriebe` | 537 | Liste, Karte, Reiter Personen | Leiste, Suche | 70/17 | |
| `BetriebeMap` (Widget) | 273 | Karte mit Popup «Route/Öffnen» (Filled/Outlined) | Betriebe-Liste | – | |
| `BetriebDetailScreen` `/betriebe/:id` | 2023 | Stamm, Kontakte, Rechnungsadresse, Anlagen, Servicetermin, 3 Einsatz-Sektionen | Heute, Tour, Suche, fast alle Details | 100/51 | **G**, Montagen fehlen |
| `BetriebFormScreen` `/betriebe/neu`, `/:id/bearbeiten` | 2082 | Stammdaten, Google-Übernahme, Öffnungszeiten, Saison | Liste, Detail | 35/11 · 7/4 | **G** |
| `BetriebRechnungsadresseFormScreen` | 481 | Rechnungsadresse | Detail, Rechnungsdetail | 11/5 | |
| `ServicezeitDurchsichtScreen` `/betriebe/servicezeiten` | 557 | Servicezeiten reihum bestätigen | nur Uhr-Icon in der Betriebe-Liste | 7/1 | **U** |
| `SaisonNachtragScreen` `/betriebe/saisondaten` | 527 | Saisonlücken nachtragen | nur Warnband im Tourenplan | 5/0 | **U** |
| `BetriebVorschlaegeScreen` `/betriebe/vorschlaege` | 310 | Google/Website-Änderungen prüfen | **nur** über die Aufgabe (`aufgabe.dart:208`); ohne Aufgabe unerreichbar | 1 | **U** |
| `BetriebKontaktFormScreen` | 312 | alter Kontakt-Formular-Screen | **nirgends importiert** | – | **T** |
| `KontakteListScreen` `/kontakte` | 536 | Personen (Reiter der Betriebe) | Reiter, Suche | 4/1 | |
| `KontaktFormScreen` (3 Routen) | 501 | Person neu/bearbeiten, eigene Betrieb-Autocomplete | Betrieb, Kontakte, Event, Suche | 4 | **D** (Betriebfeld) |
| `AnlagenListScreen` `/anlagen` | 337 | globale Anlagenliste | **nur** Stammdaten → «Anlagen» | 2/0 | **U** |
| `AnlageDetailScreen` `/anlagen/:id` | 1373 | Anlage, Leitungen, Fotos, Steckbrief, Reinigungen, Störungen (keine Montagen) | Betrieb, Tour, Stör./Mont.-Detail, Reinigungsform | 12/4 | |
| `AnlageFormScreen`, `BierleitungFormScreen` | 532 / 383 | Anlage / Leitung | Betrieb, Anlage | 2 | |
| `AufgabenScreen` `/aufgaben` | 132 | vollständige Aufgabenliste | Mehr-Kachel, Aufgaben-Sheet | 5/2 | **D** leicht (Glocke, Home-Karte, Sheet, Kachel; seit B6 gewollt) |
| `SpesenScannerScreen` `/spesen` | 1376 | Beleg-Scanner, 6 `FilledButton` | Home-FAB «Beleg» (neu), Mehr-Kachel | 11/11 | **D** (zwei Einstiege, gewollt) |
| `MaterialienListScreen`, `MaterialDetailScreen`, `MaterialFormScreen` | 253 / 1239 / 513 | Lager | Mehr-Kachel | 4 · 3 | |
| `MaterialBestellungScreen` `/materialien/bestellen`, `…/bestellungen` | 817 / 358 | Bestellung, Abholung | Materialliste | 1 · 1 | |
| `BestelllisteScreen` | 132 | alte Bestellliste | **nirgends importiert** | – | **T** |

### 1.3 Büro
| Screen / Route | Zeilen | Zweck | Einstiege | Nutzung | Flag |
|---|---|---|---|---|---|
| `RechnungenListScreen` `/rechnungen` | 1277 | Kundenrechnungen, Reiter Heineken / Pro Betrieb / Jährlich | Mehr, Suche, Aufgaben, Buchhaltung | 33/4 | |
| `OffenProBetriebScreen` `/rechnungen/pro-betrieb` | 523 | alles Offene eines Betriebs | Reiter **und** eigene Karte in der Liste (:587) | 14/5 | **D** (zwei Wege auf derselben Seite) |
| `RechnungDetailScreen` `/rechnungen/:id` | 1206 | Detail, Zahlung, Mahnung, Neuversand | Liste, Suche, Buchung, Mahnwesen | 15/3 | |
| `MahnlaufScreen`, `MahnfallScreen` | 1152 / 1034 | Mahnwesen | Liste, Detail, Aufgaben | 6/6 · 1 | |
| `HeinekenRechnungenListScreen` `/heineken` (+ `/neu`, `/:id`, `/raster`, `/zuweisungen`) | 279 / 381 / 815 / 428 / 281 | Monatsrechnung Heineken | Reiter, Aufgaben, Monatsabschluss | 8 · 1 · 6 · 0 · 1 | Raster **U** (nur AppBar-Icon); Zuweisungen **D** (3 Einstiege: Stammdaten, Heineken-AppBar, Materialbestellung) |
| `JahresrechnungGenerateScreen` `/jahresrechnung` | 758 | Jahresrechnungen | Reiter | 3 | |
| `BergkundenpauschaleListScreen` / `DetailScreen` | 344 / 237 | Pauschalen | **nur** Karte unten in der Heineken-Liste (:258) und Monatsabschluss; nicht in der Suche | 4/0 | **U** |
| `BuchhaltungDashboardScreen` `/buchhaltung` | 302 | Kennzahlen, Aufgaben, Bücher | Mehr | 32/4 | |
| `KontenplanScreen`, `BuchungenListScreen`, `BuchungDetailScreen`, `BuchungFormScreen` | 178 / 326 / 295 / 742 | Bücher | Buchhaltung | 2 | |
| `BerichteScreen` `/buchhaltung/berichte` (+ Redirect `/bilanz`) | 217 | Bilanz/ER (Material-`TabBar`) | Buchhaltung | 1 | |
| `AuswertungScreen` `/buchhaltung/auswertung` | 702 | Umsatz und Arbeiten | Auswertungen | 10/0 | Pfad liegt unter `/buchhaltung`, Eintrag unter «Auswertungen» → Bereichszähler zählt Buchhaltung |
| `ArbeitstagAuswertungScreen`, `NutzungScreen` | 523 / 358 | Auswertungen | Auswertungen | 6/2 · 1 | |
| `CamtBankauszugScreen` `/buchhaltung/camt-import` (+ 3 Redirects) | 74 + Tabs 1198/307/395/187 | Bank-Import, Prüfliste, Regeln, Dateien (Material-`TabBar`) | Bank, Aufgaben | 6/0 | `abgleich_vorschau.dart` 1911 **G** |
| `Eingangsrechnung*` (Liste, Upload, Detail, Regeln, Zahlungsfile) | 404 / 655 / 922 / 495 / 482 | Kreditoren | Bank | – | |
| `LohnlaufScreen` `/buchhaltung/lohn` | 696 | Lohnlauf | Mehr | 2 | |
| `LohnEinstellungenScreen` `/buchhaltung/lohn/einstellungen` | 346 | Sozialversicherungssätze | **nur** Stammdaten; aus dem Lohnlauf kein Link | 1 | **U** |
| `Monatsabschluss`, `MwstAbrechnung`, `Audit`, `JahrgangAbschreiben`, `Steuern`, `Steuerjahr` | 203 / 294 / 257 / 580 / 264 / 662 | Abschlüsse | Abschlüsse, Aufgaben | 1–4 | Abschreiben nur aus dem Audit (gewollt) |
| `DokumenteScreen` `/dokumente` | 152 | Ablage | Mehr | 1 | |

### 1.4 Einrichtung
| Screen / Route | Zeilen | Zweck | Einstiege | Nutzung | Flag |
|---|---|---|---|---|---|
| `StammdatenScreen` `/stammdaten` | 538 | Firma, Anlagen, Lohnsätze, MWST, Preise, Biersorten, Regionen, Zuweisungen (ListTile-Liste) | Mehr | 2/1 | |
| `PreisVersionFormScreen`, `BiersortenScreen`, `RegionenScreen` | 533 / 460 / 297 | Stammdaten | Stammdaten | 0–1 | |
| `EinstellungenScreen` `/einstellungen` | 585 | Google Kalender/Kontakte, Speicher, Abmelden | Mehr | 1/1 | |
| `GoogleTermineScreen` `/google-termine` | 424 | Termine zuordnen | **nur** Einstellungen | 0 | **U** (Befund 6.7 von 09/2026 weiter offen) |

### 1.5 Events (eingefroren)
| Screens | Zeilen | Nutzung | Flag |
|---|---|---|---|
| `events_list`, `event_detail`, `event_form`, `event_stand_form`, `event_einsatz_form`, `event_aufwand_form`, `event_lageplan`, `event_staende_map`, `event_technik_tab`, `event_technik_kuehler`, `event_abschluss_sheet`, `stand_position_dialog` | **≈ 9'030** (detail 2863, technik_tab 1531) | `/events` 1, `/events/:id` 1; 3 Events in der DB | **V**, **G** |

Die Events stehen noch als **Kachel in der ersten Gruppe «Unterwegs»** auf Mehr (`bereiche.dart:153`), dazu `EventKarten` auf Heute. Laut Memory läuft Gampel im eigenen Repo, das Technik-Zielmodell liegt im Heineken-Projekt.

### 1.6 Toter Code (nirgends importiert)
`betriebe/betrieb_kontakt_form_screen.dart` (312), `materialien/bestellliste_screen.dart` (132), `widgets/system_diagram/*` (4 Diagramme + components, ≈ 390), `widgets/filter/app_filter_sheet.dart` (70), `providers/auth_provider.dart` (17). Nur noch in Tests verwendet: `providers/kachel_zaehler_providers.dart`, `widgets/filter/app_active_filters.dart`.

Nebenbei: Die Gast-Redirects in `router.dart:327/343/354/370` zeigen auf `/eigenauftraege` und `/eroeffnungsreinigungen`. Diese Listen-Routen gibt es seit v0.106 nicht mehr. Solange der Gast deaktiviert ist, schadet das nicht; bei einer Reaktivierung ergäbe es eine 404.

---

## 2. Einsatz-Detail- und Formularseiten: kopiert statt geteilt

### 2.1 Detailseiten (Reinigung, Störung, Montage, Eigenauftrag, Eröffnung, Pikett)
| Baustein | Stand | Belege |
|---|---|---|
| AppBar PDF, Stift, Papierkorb | 6× von Hand, gleiche Reihenfolge und Gast-Weiche | z. B. `stoerung_detail_screen.dart:155–173`, `montage_detail_screen.dart:99–115` |
| Lösch-Bestätigung und «Löschen nur mit Internetverbindung» | 6× kopiert (Dialog mit TapKnopf, sauber) | `stoerung_detail:603`, `eigenauftrag_detail:281` … |
| Rapport-PDF: Spinner-Dialog, Betrieb laden, Material-Namen, `Printing.layoutPdf` | 5× kopiert (Stör/Mont/Eigen/Eröff/Pikett) | `stoerung_detail:521–600`, `eigenauftrag_detail:224–279` |
| «Erledigt»-Ablauf (Rückfrage, Arbeitszeit, Status, Snackbar) | 2× fast identisch; Bestätigung ist ein **FilledButton** | `stoerung_detail:461–515`, `montage_detail:335–390` |
| `_SectionCard`, `_InfoRow` | textgleich in 11 bzw. 13 Dateien (auch Betrieb, Anlage, Material, Rechnung) | `diff` = 0 Zeilen |
| Betrieb-/Anlage-Karte | `_BetriebAnlageCard` 2× (Stör/Mont, ListTile), `_BetriebCard` 2× (Eigen/Eröff, textgleich, ListTile) | |
| «Nicht gefunden»-Seite | 13 Dateien | |

**Geteilt ist bereits:** `ArbeitBeendenKnopf` (nur Stör/Mont), `TapKnopf`, `EinsatzZeile` (nur Einsätze-Liste), `kurzeFehlermeldung`.

### 2.2 Formulare
| Baustein | Reinigung | Störung | Montage | Eigenauftrag | Eröffnung | Pikett | geteilt? |
|---|---|---|---|---|---|---|---|
| Betriebfeld | Karte (vorgewählt) plus eigener Vollbild-Wähler | Autocomplete :1193 | Autocomplete :1796 | Autocomplete :286 | Autocomplete :242 | – | **nein**; nur die Suchregel `betriebPasst()` (A9). 5 Kopien inkl. `kontakt_form:187`, Abweichung ≤ 32 Zeilen |
| Anlagen-Auswahl | Mehrfach `_buildAnlagenAuswahl` :2079 | `anlageId` per Query | `anlageId` per Query | – | – | – | nein |
| Arbeit beginnen/beenden, Live-Timer, Zeitfelder | eigene Zeiterfassung (GPS) | `_arbeitBeginnen/Beenden`, `_ensureLaufendZeitTimer`, `_buildArbeitBeginnBlock`, `_buildArbeitZeitfelder` | dasselbe, Blockdiff 24 Zeilen | keine | keine | Tage und Zeiten | nur `ArbeitBeendenKnopf` und `zeigeZeitauswahl` |
| Material-Slots | – | 5 Slots `_buildMaterialSlots` :1025 | 5 Slots :1669, **16 Zeilen Unterschied auf ~140** | 3 Slots, eigene Variante | – | – | nein |
| Foto | Kamera/Galerie-Knöpfe | – | eigene Sektion (~106 Diff-Zeilen zu Reinigung) | – | – | – | nein; `ImagePicker` an 9 Stellen, das Sheet «Galerie/Kamera» als ListTile 3× (`anlage_detail:450`, `material_detail:587`, `buchung_form:511`) |
| Datum | `showDatePicker` | dito | 2× | dito | dito | – | nein: 29 Aufrufe in 27 Dateien, private `_DatePickerField`/`_DatumFeld` 4× (`betrieb_form:1850`, `event_form:420`, `saison_nachtrag:479`, `war_geschlossen_sheet:433`) |
| Speichern-Knopf | `FilledButton` (+ Outlined «abschliessen») | `FilledButton` :1001 | `FilledButton` :1291 | `FilledButton.icon` :267 | `FilledButton.icon` :217 | `FilledButton` :357 | nein; alles Material |
| Verwerfen-Schutz | `UngespeichertSchutz` | ✓ | ✓ | ✓ | ✓ | ✓ | **ja** (A7) |

---

## 3. Dialoge und Sheets

### 3.1 Muster
183 Aufrufe insgesamt:

| Muster | Anzahl |
|---|---|
| `showDialog` mit TextButton und **TapKnopf** | 44 (davon 9 nur TapKnopf) |
| `showDialog` mit TextButton und **FilledButton** | 38 (7 davon mit ListTile-Inhalt) |
| `showDialog` nur mit TextButtons | 15 |
| `showDialog` eigen oder Spinner | 25, davon **10 ad-hoc-Spinner** `Center(CircularProgressIndicator)`, obwohl es `FortschrittsDialog` gibt (nur 2 Nutzer) |
| `showModalBottomSheet` eigen gebaut (GestureDetector) | 20 |
| `showModalBottomSheet` mit ListTile | 6 |
| `showModalBottomSheet` mit Material-Buttons | 3 (`betriebe_map:170`, `heineken_rechnung_generate:105`, `app_filter_sheet` tot) |
| `showModalBottomSheet` mit TapKnopf | 2 |
| `showDatePicker` / `showTimePicker` | 29 / 1 (im Helfer) |

Dazu kommen vier private Knopf-Nachbauten für dieselbe Aufgabe: `_SheetAktion` 3× (`tourenplanung:2169`, `diktat_sheet:1180`, `einplanen_sheet:387`), `_RundKnopf` 2×, `_PrimaryButton` (Diktat) und `_KnopfKlein` (Arbeitstag). TapKnopf deckt davon das meiste ab. Für Reiter gibt es zwei Mechanismen: `BereichReiter` (routenbasiert, CanvasKit-sicher, 6 Screens) und die Material-`TabBar` (Tourenplan, Camt, Berichte, Event).

### 3.2 Verstösse gegen die CanvasKit-/Gefahr-Regel, die kein Wächter fängt
**Unumkehrbar, bestätigt über einen Material-Button:**
- `FilledButton «Löschen»`: `anlage_detail_screen.dart:1208` (Bierleitung), `bergkundenpauschale_detail_screen.dart:185`, `camt/camt_regeln_tab.dart:247`, `eingangsrechnungen/kreditor_regeln_screen.dart:43`, `material_detail_screen.dart:461` (Manual), `:712` (Foto), `material_form_screen.dart:359` (**`Colors.red`**, rutscht deshalb durch)
- `FilledButton «Rückgängig»`: `rechnung_detail_screen.dart:279` (**Zahlung rückgängig**), `material_bestellungen_screen.dart:150`
- `FilledButton «Abschreiben»`: `rechnungen/widgets/debitoren_header.dart:149`
- `FilledButton «Entfernen»`: `google_termine_screen.dart:148`, `event_lageplan_screen.dart:242`
- `TextButton «Löschen»/«Verwerfen»` als Bestätigung: `widgets/dokumente/dokument_liste.dart:186`, `steuerjahr_screen.dart:108`, `event_technik_tab.dart:790/1325`

**Rot, aber als `.icon`-Variante (Wächter-Regex `X\(` greift nicht):**
- `einstellungen_screen.dart:319` «Trennen», **ohne Rückfrage**
- `tourenplanung_screen.dart:1091` «Leeren», **ohne Rückfrage**, speichert sofort (`tour_providers.dart:1389`)
- `material_detail_screen.dart:568`, `material_form_screen.dart:331`, `event_detail_screen.dart:1722`

**Kritisch, aber nicht zerstörend (Material-Button im Hauptpfad):**
- Reinigung abschliessen, Speichern und Bestätigung (`reinigung_form_screen.dart:1464ff, 1989–2020`)
- Rechnung «Senden» (`reinigung_detail_screen.dart:451`)
- «Neu versenden» (`rechnung_detail_screen.dart:729`)
- «Erledigt» (`stoerung_detail:473`, `montage_detail:347`)
- Spesen «Trotzdem buchen» und die Scanner-Knöpfe (`spesen_scanner_screen.dart:350/419/449`; der Scanner hängt seit v0.138 direkt am Home-FAB)
- Speichern in allen 6 Einsatzformularen

**Nicht in der Dateiliste von `canvaskit_sichere_widgets_test.dart`, obwohl täglich genutzt:**
- `reinigung_form_screen.dart` (5 Filled, 5 Outlined, 5 ListTile, 1 ExpansionTile)
- `reinigung_betrieb_auswahl_screen.dart` (ListTile-Zeilen)
- `tourenplanung_screen.dart` (TabBar)
- `spesen_scanner_screen.dart`
- `betriebe_list_screen.dart` (2 ListTile)

Bereits sauber und nur zum Festschreiben aufzunehmen: `einsaetze_screen.dart`, `betrieb_detail_screen.dart`.

---

## 4. Vorschläge, priorisiert (Nutzen am Handy / Aufwand)

| # | Was | Warum | Dateien | Aufwand |
|---|---|---|---|---|
| **1** | Start-Pfeil und «Störung/Montage erfassen» öffnen den **bestehenden** Einsatz (`/stoerungen/<id>/bearbeiten` bzw. `/montagen/<id>/bearbeiten`, ID aus `eintrag.id.substring(2)`) statt `/neu` | verhindert Doppel-Datensätze im Tagesgeschäft. **Vorher fachlich bestätigen lassen** | `widgets/heute_liste.dart:443–448`, `touren/tourenplanung_screen.dart:1878–1905` | Kleinfix |
| **2** | Rückfrage vor «Tagesplan leeren» und «Google trennen»; beide als TapKnopf | ein Fehltipp löscht heute den ganzen Tag | `tourenplanung_screen.dart:339/1091`, `einstellungen_screen.dart:319` | Kleinfix |
| **3** | Gefahr-Wächter schärfen: Regex `(Filled\|Elevated\|Outlined\|Text)Button(\.icon\|\.tonal\|\.tonalIcon)?\(`, dazu `Colors.red` und Beschriftungen (`Löschen\|Entfernen\|Rückgängig\|Abschreiben\|Verwerfen\|Stornier`) in Dialog-`actions`. Danach die 17 Stellen aus §3.2 auf `TapKnopf(gefahr: true)` umstellen | Regel wirklich erzwingen statt nur Rotfärbung; darunter die Zahlungs-Rücknahme | `test/gefahr_knopf_waechter_test.dart` + 13 Dateien | halber Tag |
| **4** | «Reinigung abschliessen», Speichern und Abschluss-Bestätigung auf `ArbeitBeendenKnopf`/`TapKnopf`; `reinigung_form_screen.dart`, `reinigung_betrieb_auswahl_screen.dart`, `tourenplanung_screen.dart`, `spesen_scanner_screen.dart` in die Liste des CanvasKit-Wächters | häufigster Vorgang der App (113/111); schliesst die zweite Hälfte von B7 | genannte Dateien, `test/canvaskit_sichere_widgets_test.dart` | halber Tag |
| **5** | Betriebsseite: die drei Einsatz-Sektionen durch **eine** «Einsätze»-Sektion mit `EinsatzZeile` ersetzen (alle Typen inkl. Montage, Eröffnung, Pikett, neueste zuerst, «alle anzeigen» → `/einsaetze?betrieb=<id>`), dazu «+»-Typwahl wie auf Einsätze. Auf der Anlagenseite dasselbe | Montagen sind heute auf Betrieb/Anlage unsichtbar; spart ~450 Zeilen | `betrieb_detail_screen.dart:1280–1830`, `anlage_detail_screen.dart`, `core/util/einsatz.dart` (Filter `betriebId`) | 1 Tag |
| **6** | Gemeinsames `BetriebFeld` (Autocomplete mit `betriebPasst`, Parameter `nurMeineKunden`) statt 5 Kopien; `ReinigungBetriebAuswahlScreen` nutzt denselben Baustein oder fällt weg (Reinigungsform mit leerem Betriebsfeld) | A9 hat nur die Regel vereinheitlicht, nicht die Oberfläche | `stoerung_form:1193`, `montage_form:1796`, `eigenauftrag_form:286`, `eroeffnungsreinigung_form:242`, `kontakt_form:187`, `reinigung_betrieb_auswahl_screen.dart` | halber Tag |
| **7** | `zeigeDatumsauswahl()` analog zu `zeigeZeitauswahl()` plus Wächter; private `_DatePickerField`/`_DatumFeld` durch ein `DatumFeld` ersetzen | 29 Aufrufe mit uneinheitlichem Locale, Bereich und Hilfetext | 27 Dateien (mechanisch, Sonnet-tauglich) | halber Tag |
| **8** | Einsatz-Bausteine für Störung und Montage auslagern: `ArbeitszeitBlock` (Beginnen/Beenden/Timer/Zeitfelder) und `MaterialSlots` (N Slots, Lager-Autocomplete); Eigenauftrag nutzt `MaterialSlots(3)` | ~400 doppelte Zeilen; Fixes landen heute nur in einer Hälfte | `stoerung_form_screen.dart`, `montage_form_screen.dart`, `eigenauftrag_form_screen.dart` → `widgets/einsatz/` | 1 Tag |
| **9** | Gemeinsames Detail-Gerüst: `DetailKarte`/`InfoZeile` (ersetzt 11+13 Kopien), `LoeschenBestaetigen()`, `RapportPdfZeigen()` mit `FortschrittsDialog`, `EinsatzBetriebKarte` ohne ListTile. Liegt aus 09/2026 noch als Punkt «ohne Nummer» offen | vereinheitlicht 6 Detailseiten plus Betrieb/Anlage/Material/Rechnung und ersetzt 10 ad-hoc-Spinner | 13 Detail-Dateien → `widgets/detail/` | 1 Tag (mechanisch) |
| **10** | Toten Code entfernen: `betrieb_kontakt_form_screen.dart`, `bestellliste_screen.dart`, `system_diagram/`, `app_filter_sheet.dart`, `auth_provider.dart`; Gast-Redirects auf `/einsaetze` biegen | ≈ 920 Zeilen weniger, keine Verwechslung beim Suchen | genannte Dateien, `router.dart:327–371` | Kleinfix |
| **11** | Events: Kachel aus «Unterwegs» in «Einrichtung» verschieben oder ganz aus Mehr nehmen (Route bleibt). Mittelfristig mit Daniel klären, ob der Ordner (≈ 9000 Zeilen, 3 Events) archiviert wird | bester Platz auf Mehr belegt von einer Funktion mit 1 Aufruf in 16 Tagen | `bereiche.dart:153`, ggf. `home_screen.dart` (`EventKarten`) | Kleinfix / Entscheid |
| **12** | Umwege schliessen, jeweils ein Eintrag: «Änderungsvorschläge» als Zeile auf der Betriebe-Liste (heute nur über die Aufgabe); «Google-Termine zuordnen» in die Tour-AppBar oder nach Mehr → Unterwegs; Link «Sätze» im Lohnlauf zu `/buchhaltung/lohn/einstellungen`; Bergkundenpauschalen und Anlagen als `kSuchZusatzZiele` in die Suche; Tages-Karte als echte Route `/touren/karte` (dann gezählt und verlinkbar) | fünf Screens sind nur über einen versteckten Weg erreichbar | `bereiche.dart`, `betriebe_list_screen.dart`, `lohnlauf_screen.dart`, `router.dart`, `tourenplanung_screen.dart:346` | halber Tag |
| **13** | Doppel-Einstiege bereinigen: Karte «Pro Betrieb» in der Rechnungsliste (:587) entfernen, weil der Reiter reicht; Heineken-Zuweisungen nur noch in Stammdaten plus Heineken-AppBar, nicht in der Materialbestellung. `AuswertungScreen` nach `/auswertungen/umsatz` verlegen (Redirect vom alten Pfad), sonst zählt er als Buchhaltungs-Aufgabe | weniger Wege zum Gleichen | `rechnungen_list_screen.dart:587`, `material_bestellung_screen.dart`, `router.dart`, `bereiche.dart` | Kleinfix |
| **14** | Grosse Dateien aufteilen, nur bei ohnehin fälligem Umbau: Reinigungsform (`_save` 820 Zeilen → Service `ReinigungAbschluss`; Abschluss-Dialog, Foto, Positionen als Widgets), Tourenplan (`_TagesplanZeitachse` ~590, `_BlockSheet` ~380, `_FaelligEintragKarte` ~220 → `touren/widgets/`), Betriebsform (Öffnungszeiten-Form und Dialog ~350 → eigene Datei), `abgleich_vorschau.dart` (4 Dialoge → `camt/dialoge.dart`). Events **nicht** aufteilen (eingefroren) | Lesbarkeit und Testbarkeit; kein direkter Nutzen am Handy | genannte Dateien | Tag+ je Datei |
| **15** | Tourenplan-Reiter (Tagesplan/Fällig) auf `BereichReiter`-Bauart oder eigene GestureDetector-Leiste; Galerie/Kamera-Sheet als ein Helfer `zeigeFotoQuelle()` statt 3 ListTile-Sheets; `_SheetAktion`/`_RundKnopf` in `widgets/` zusammenführen | CanvasKit-Konsistenz auf Handy-Screens | `tourenplanung_screen.dart:312`, `anlage_detail:450`, `material_detail:587`, `buchung_form:511`, `diktat_sheet`, `einplanen_sheet` | halber Tag |

**Reihenfolge-Empfehlung:** zuerst 1 und 2 (Datenrisiko, je Minuten), dann 3 und 4 (Wächter und Hauptpfad), dann 5 und 6 (sichtbarer Alltagsnutzen), danach 7–10 als mechanische Aufräumrunde (Sonnet-Implementer). 11–15 nach Entscheid und Gelegenheit.

**Offene Fragen an Daniel:**
- Zu (1): Soll der Start-Pfeil bei einer geplanten Störung wirklich einen neuen Datensatz anlegen?
- Zu (11): Werden Events in dieser App noch gebraucht?
