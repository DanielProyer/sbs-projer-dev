# Analyse 4 — Tagesbetrieb (Heute, Tourenplan, Einsätze, Formulare, Abschluss, Aufgaben)

Stand v0.138.0, 25.09.2026. Nur gelesen, nichts geändert. Pfade relativ zu `sbs_projer_app/lib/`. Zahlen aus der Produktiv-DB (nur SELECT) und aus `route_nutzung` (seit 10.09.).

## 0. Was die Nutzung sagt

| Route (seit 10.09.) | Handy | PC |
|---|---|---|
| `/reinigungen/neu` | **96** | 2 |
| `/` (Heute) | 54 | 102 |
| `/betriebe/:id` | 49 | 49 |
| `/touren` | 15 | **69** |
| `/spesen` | 11 | – |
| `/montagen/neu` · `/stoerungen/neu` | 9 · 6 | 2 · 5 |
| `/einsaetze` | 9 | 25 |
| `/aufgaben` | 2 | 3 |

- **Im selben Zeitraum 73 Reinigungen angelegt, aber 96 Formular-Öffnungen am Handy**: rund 23 Öffnungen ohne Abschluss (Tab neu geladen, abgebrochen oder doppelt geöffnet). Das ist der messbare Verlust im Hauptweg.
- **Der Tourenplan wird am PC geplant und am Handy kaum geöffnet.** Draussen läuft der Tag über «Heute».
- **Die Planung von Störungen und Montagen wird nicht genutzt:** Seit 01.08. gab es 36 Störungen, davon **0** mit `geplant_am` und 2 mit Arbeitszeiten. Bei 18 Montagen: 1 geplant, 3 mit Arbeitszeiten.
- **Reinigungen seit 01.06. (405, in der App erfasst):** `wasser_kuehler_gewechselt` **0×** · Notizen 2× · Kulanz 2× · Service-Art: Standard 361, Eröffnung 28, Endreinigung 8 · Service-Typ `heigenie` **0× (auch über alle Jahre)** · ohne Protokollfoto 4.
- ⚠️ **Korrektur zu Memory/ToDo:** `uhrzeit_ende` ist bei neuen Reinigungen **nicht** tot. Die App setzt es beim Abschliessen (`reinigung_form_screen.dart:664`, `uhrzeitEnde ??= now`), und alle 405 haben einen Wert. `dauer_minuten` liegt bei 342 davon zwischen 20 und 59 Minuten. Tot ist nur das **Eingabefeld** «Ende», denn der Wert kommt vom Abschluss-Tipp. Die ToDo-Zahl «0 von 1934» betraf den Altbestand.
- Die Zahlungsart beim Abschluss ist in **206 von 250 Fällen (82 %)** gleich wie die Vorgabe des Betriebs.

## 1. Der Weg einer Reinigung (Heute bis bezahlt)

| # | Schritt | Taps | Wo | Bemerkung |
|---|---|---|---|---|
| 1 | Heute: Start-Pfeil am Stopp | 1 | `widgets/heute_liste.dart:434-443` | Betrieb und Anlagen des Besuchs kommen mit |
| 2 | Formular lädt | 0 | `reinigung_form_screen.dart:146-186, 357-500` | Start = Öffnungszeit; Hähne und Service-Typ aus der **letzten Reinigung**; Kulanz-Merker; Bergkunde. Gut vorbelegt. |
| 3 | Scrollen über Betrieb-Karte, Saison-Band, Mahn-Band, Heineken-Monteur-Schalter, Anlagen, Schalter-Hinweis, Zeit, Service-Art, Wasser | 1–2 Wischer | `:1770-1915` | Zwei Felder sind praktisch tot (Wasser 0×; Ende wird automatisch gesetzt) |
| 4 | Protokoll «Digitalisieren», Kamera, Auslöser, OK | 3 | `:535-546, 1917-1950` | Foto bleibt **nur im Speicher** (`_fotoBytes`) |
| 5 | Wischen bis zu «Reinigung abschliessen» | 1–2 Wischer + 1 | `:2008` | Unter Kulanz, Positionen und Preisliste |
| 6 | Abschluss-Dialog: lädt Betrieb und Rechnungsadresse (2 Anfragen), Zahlungsart vorgewählt, «Abschliessen» | 1 | `:1411-1680` | 82 % übernehmen die Vorgabe unverändert |
| 7 | Kette (siehe unten), Snackbars | 0 | `:569-1388` | Rund 10–14 Serveranfragen hintereinander |
| 8 | Dialog «Saisondaten fehlen» (falls unvollständig): «Später» | 0–1 | `:239-270, 1374` | Kommt zusätzlich zum Band im Formular |
| 9 | Zurück auf Heute: der Stopp verschwindet, wenn **alle** Anlagen des Besuchs heute abgeschlossen sind | 0 | `core/util/heute_stopps.dart`, `providers/heute_providers.dart:33-50` | |
| 10 | Bezahlt: Mail/Post über camt-Import (QRR-Abgleich); Bar über die Buchung sofort; Tresen über `uebergeben_am`, dann Bank | 0 | ausserhalb | Mahnlauf fängt Ausstände |

**Im günstigsten Fall 6 Taps und 2–4 Wischer.** Wer gegen die Vorgabe mit Mail abrechnet, kommt auf 7–8.

**Die Abschlusskette in Reihenfolge** (`_save`, `:569`):

1. Foto hochladen.
2. Reinigung speichern.
3. Fahrzeit lernen (unawaited).
4. Wegpunkt (unawaited).
5. **Pausen-Prüfung (await, holt GPS, kann einen Dialog zeigen)**, `:799`.
6. HeiGenie-Mail (toter Pfad).
7. Kulanz-Merker löschen.
8. Rechnung anlegen.
9. PDF-Prüfung.
10. Rechnungsadresse abfragen.
11. Mail über Edge Function.
12. Status-Update.
13. Buchung.
14. Nachholen, bis 20 s.
15. Bergkundenpauschale.
16. Invalidieren.
17. Saison-Dialog.
18. Zurück.

### Wo der Nutzer am Handy scheitern kann

| # | Stelle | Datei:Zeile | Folge | Schwere |
|---|---|---|---|---|
| F1 | **Foto-Upload scheitert still.** Im `catch` steht nur `debugPrint`, danach wird die Reinigung **ohne Protokoll** abgeschlossen, Rechnung und Mail laufen trotzdem | `reinigung_form_screen.dart:686-690` | Das Protokoll ist das Foto (Memory). Es fehlt, und niemand merkt es. Die 4 Fälle ohne Foto seit Juni passen dazu. Keine Aufgabe erkennt das. | **hoch** |
| F2 | **Foto und Formular leben nur im Tab.** Es gibt keinen Entwurf und kein Zwischenspeichern für eine neue Reinigung (Knopf «Speichern» nur bei `_isEdit`, `:1987`). Die Kamera-App schiebt Chrome in den Hintergrund, und Android verwirft Tabs dann gern. | `:535, 1987-2025` | Alles weg. Wahrscheinliche Mitursache für die 96 Öffnungen gegenüber 73 Reinigungen. | **hoch** |
| F3 | Die Kette hängt am Client (Memory «Kette bricht ab»). Die Buchung wird inzwischen nachgeholt; Bergkundenpauschale (`:1337`), HeiGenie- und RSL-Mail (`montage_form_screen.dart:836`) nur mit `debugPrint` | wie oben | Pauschale fällt erst im Monatsabschluss auf (Regel `BergkundenpauschalenRegel`); die RSL-Mail hat keinen Nachholweg | mittel |
| F4 | **Pausen-Prüfung mit `await` mitten in der Kette**, vor Rechnung und Buchung (holt GPS, eventuell Dialog) | `:797-803` | Verlängert das Fenster, in dem das Wegstecken die Buchung kostet | mittel (nur bei laufender Pause) |
| F5 | Dialog-Knopf «Abschliessen» und Haupt-Knopf sind `FilledButton.icon` | `:1610, :2008` | CanvasKit-Falle aus CLAUDE.md, praktisch bisher unauffällig (73 Abschlüsse). Kein Wächter prüft «kritische Aktion» ausser Gefahr-Knöpfen | niedrig (Regelbruch) |
| F6 | Zweimal «Saisondaten fehlen» pro Besuch: Band `:188` plus Dialog nach dem Abschluss `:1374` | | Wird zur Gewohnheit weggetippt | niedrig |

## 2. Die sechs Formulare

### Feldvergleich

| Feld / Baustein | Reinigung (2818 Z.) | Störung (1519) | Montage (2180) | Eigenauftrag (548) | Eröffnung (387) | Pikett (487) |
|---|---|---|---|---|---|---|
| Betrieb | Karte, fest aus Route | `_buildBetriebField` | `_buildBetriebField` | `_buildBetriebField` | `_buildBetriebField` | – |
| Anlagen | Mehrfachwahl | Anlagentyp-Chips | – | – | – | – |
| Datum | ✓ | ✓ | ✓ (Anlass: Startdatum) | ✓ | ✓ | Jahr + KW |
| Uhrzeit Start/Ende | Freitext; Ende **tot** (automatisch) | «Störungseingang» (= `uhrzeit_start`, **doppelt** zu `gemeldet_am`) | `uhrzeit_*` **0 von 815** | – | – | Zeiten je Tag |
| Arbeit von/bis + Beginn/Beenden | – | ✓ (kopiert) | ✓ (kopiert) | – | – | – |
| «Erst geplant» | – | ✓ (0 Nutzungen seit Aug.) | ✓ (1) | – | – | – |
| Referenz-Nr. | – | Störungsnummer | – | Störungsnr.* | Störungsnr.* | – |
| Beschreibung / Notizen | Notizen (2×) | Beschreibung + Notizen | Beschreibung | Beschreibung* | – | – |
| Preis/Positionen | Service-Typ + 5 Hahn-Zähler + Kulanz + Bergkunde + QR | Anfahrt-km, Zusatz, Pikett-WE, Bergkunde | Stunden/Betrag, Stundensatz, Tage & Spesen | Anzahl × 30 | Art + Preis (Bergkunde) | Pauschale, Feiertage |
| Material (3 Slots) | – | ✓ | ✓ | ✓ (dreifach kopiert) | – | – |
| Foto | Protokoll | – | HeiGenie-Protokoll | – | – | – |
| Sonderschalter | Heineken-Monteur, Kulanz, Service-Art, Wasser (**0×**) | Kilometerabrechnung (12× seit Juni) | Typ (7 Werte) | Status | Eröffnung/Endreinigung | – |
| Mail beim Speichern | Kunde / Post / HeiGenie (**toter Pfad**, `:832-900`) | – | RSL (HeiGenie) | – | – | – |
| Mahn-Hinweis-Band | ✓ | ✓ | ✓ | – | – | – |
| UngespeichertSchutz (A7) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### Geteilt oder kopiert

| Baustein | Status |
|---|---|
| `UngespeichertSchutz`/Mixin, `MahnHinweisBand`, `zeit_auswahl`, `arbeit_beenden_knopf`, `pause_pruefen_helfer`, `betriebPasst()` | **geteilt** |
| `_buildBetriebField` (Autocomplete-Oberfläche) | 4 Kopien; Störung und Eigenauftrag weichen in 84 von 98 Zeilen nur kosmetisch ab |
| `_buildArbeitBeginnBlock` + `_buildArbeitZeitfelder` | 2 Kopien, fast gleich (`stoerung_form_screen.dart:1426-1519` gegenüber `montage_form_screen.dart:1999-2104`; Montage zusätzlich mit Stundenvorschlag) |
| Material-Slots | 3 Kopien (Störung, Montage, Eigenauftrag) |
| Foto-Sektion (Kamera/Galerie/PDF) | 2 Kopien (Reinigung `:2249`, Montage `:1394`) |
| `_sectionTitle`, `_preisRow`, `_formatDate` | in jedem Formular |

**Doppelte Fachwege:**

- **HeiGenie** geht einmal als Reinigungs-Service-Typ (0× genutzt, eigene Mail) und einmal als Montage-Typ (12×, RSL-Mail).
- **Eröffnung/Endreinigung** geht einmal als Service-Art der Reinigung (36×) und einmal als eigenes Belegformular (3× seit Aug.).

### Gemeinsames Gerüst: realistisch?

**Als Bausteine ja, als ein Formular nein.**

- **Bausteine ja:** Ein `EinsatzKopf` (Betrieb + Datum + Referenz), ein `ArbeitszeitBlock`, ein `MaterialSlots` und eine `ProtokollFoto`-Sektion als Widgets. Das sind rund 1'000 Zeilen weniger, ohne Risiko, weil sich nur die Oberfläche ändert und die Speicherlogik je Typ bleibt. Aufwand 2–3 Tage.
- **Ein Formular für alle nein:** Die Speicherlogik ist grundverschieden. Die Reinigung hat Rechnung, Buchung und Mail; die Störung einen Pauschaltarif und Pikett-Logik; die Montage Stunden und die Regel «`dauer_stunden` nie überschreiben»; Pikett ist ein Wochenobjekt. Sechs Tabellen, geteilte DB mit der v2. Das gehört als **C1** in die v2 (dort ein Modell mit Typ). Hier wäre es ein grosser Umbau am produktiven Geldweg.

## 3. Tourenplan (`touren/tourenplanung_screen.dart`, 2813 Z.)

| Zeilen | Inhalt | Gehört wohin |
|---|---|---|
| 44-640 | Screen-State: Laden, Woche/Tag, Region-Filter, 2 Tabs (Tagesplan / Fällig), Saison-Warnungen (`_warnungSaisonAnker`, `_warnungSaisonLuecke` mit eigenen Dialogen) | Saison-Warnungen → eigene Datei `touren_saison_warnungen.dart` |
| 641-982 | Übernehmen einzeln/alle, **Reihenfolge optimieren**, «Plan von Datum übernehmen» | `tagesplan_aktionen.dart` (reine Logik, testbar) |
| 984-1002 | Navigation zum Detail | bleibt |
| 1004-1166 | Header, Typ-Farben, Dauer- und Fahrzeit-Helfer | Helfer → `core/util` |
| 1167-1759 | **Zeitachse**: Live-Modus (Minuten-Timer, Jetzt-Linie), Ist-Ansicht (erledigte Besuche mit echten Zeiten), Fahrzeit-Kaskade inkl. Anfahrt/Heimweg aus `anfahrtszeiten`, Routen nachfordern | **eigene Datei** `tagesplan_zeitachse.dart` (~600 Z.) |
| 1760-2144 | Block-Sheet: Einsatz starten, Anlagen, Dauer, Termin-Anker, «War geschlossen», Einplanung zurückschreiben | eigene Datei `tour_block_sheet.dart` |
| 2275-2455 | `_ArbeitstagZeile` (Plan-Beginn/Ende/km) | eigene Datei; bewusst getrennt von `ArbeitstagKarte` (Ist) |
| 2456-2593 | Info-Zeile (Ruhetage, Servicezeit), Status-Badge | bleibt |
| 2594-2813 | Fällig-Karte + «Einplanen» | eigene Datei |

B5 (Kopfzeile, Wochenzeile) ist seit v0.113.0 erledigt. Ein Aufteilen in 5–6 Dateien ist reine Verschiebung: 1 Tag, kein Verhaltensrisiko.

### Doppelt mit Heute und Einsätze

- **Start-Logik steht dreimal:** `heute_liste.dart:434-450`, `tourenplanung_screen.dart:1863-1907` und die Betriebsseite. Besser wäre eine Funktion `starteEinsatz(TourEintrag)`.
- ⚠️ **Fehler in allen Kopien:** Bei Störung und Montage öffnet der Start-Pfeil **`/stoerungen/neu?betriebId=…`**, also ein **neues** Formular, nicht den geplanten Einsatz (`id = s_<routeId>`). Die Folgen:
  - eine doppelte Störung, die neue sofort «erledigt» (Schalter «Erst geplant» steht auf aus);
  - der geplante Stopp bleibt in Heute offen, weil «erledigt» über den Status der **alten** Störung läuft (`heute_providers.dart:62-71`).

  Wegen 0 geplanten Störungen fällt das heute nicht auf, es trifft aber genau dann, wenn Planung genutzt wird. Richtig wäre: Detailseite beziehungsweise `/stoerungen/<id>/bearbeiten` mit «Arbeit beginnen».
- **Zwei verschiedene Definitionen von «erledigt»:** Heute nimmt den Status beziehungsweise die heute gereinigten Anlagen. Die Zeitachse nimmt für Störung und Montage den «Wegpunkt-Stempel minus geplante Dauer», mit der Begründung «Uhrzeiten werden dort nicht erfasst» (`:1436`). Das ist seit v0.76 überholt: Es gibt `arbeit_von`/`arbeit_bis`.
- `_SheetTitel`/`_SheetAktion` sind in `diktat_sheet.dart:1160-1220` kopiert.
- **Saison-Reinigung aus dem Plan:** Die Route übergibt keine Service-Art. Bei Eröffnung und Endreinigung muss Daniel das Dropdown von Hand umstellen (36 Fälle seit Juni), denn `/reinigungen/neu` kennt nur `betriebId` und `anlageIds` (`core/config/router.dart:326-338`).

## 4. Aufgaben und Glocke

### Detektoren (`providers/aufgaben_detektoren_provider.dart`, `core/util/aufgaben_regeln.dart`, `aufgabe.dart`)

| Quelle | Glocke («jetzt»)? | Lärm-Einschätzung |
|---|---|---|
| Heineken-Monatsrechnung Vormonat | ja, ab dem 11. rot | berechtigt, aber Büro |
| MWST (bis 4 Quartale, bis zum Marker) | ja | Büro; steht Monate lang (Q3/2026 bis 30.11.) |
| **Saisondaten fehlen (Anzahl)** | ja | **Dauerbrenner.** Dazu Band und Dialog im Reinigungsformular plus Warnung im Tourenplan: viermal dasselbe |
| **Saison-Lücke (Anzahl)** | ja | Dauerbrenner (25 am 20.09.), dazu Warnung im Tourenplan |
| Mahnlauf / Eskalation / Mahnfälle | ja | Büro |
| Änderungsvorschläge | ja | Büro |
| Eigene Aufgaben (ab −7 Tagen) | ja | ok |
| Einsätze Störung/Montage/Eigenauftrag/Termin (heute oder überfällig) | ja | Tagesbetrieb, gut |
| Saison-Vorschläge und bestätigte Termine | ja (am Tag) | Tagesbetrieb, gut |
| Fehlende Buchungen, Versandvermerk, Bank-Prüfliste, Eingangsrechnungen, Monatsabschluss | nein (Vorrat) | richtig getrennt |

**Die Trennung Frist/Vorrat ist im Code klar** (`jetztFaellig`, `aufgabe.dart:131`). Für den Nutzer ist sie unsichtbar: Die **Aufgabenkarte steht auf Heute über dem Tagesplan** (`home_screen.dart:54`) und mischt Büro-Fristen (MWST, Mahnlauf, Heineken, Saison-Stammdaten) mit dem, was heute draussen zu tun ist. Am Handy im Auto sind MWST und Mahnlauf Rauschen, und sie schieben die Stopps nach unten. Dass `/aufgaben` am Handy nur zweimal geöffnet wurde, spricht dafür, dass die Karte überlesen wird.

Nebenbefund: Der Versandvermerk-Detektor macht **N+1 Abfragen** (bis 500 × `reinigungen`-Query, `aufgaben_detektoren_provider.dart:136-148`), und das bei jedem Neuberechnen der Liste.

### Was aus Sicht Tagesbetrieb fehlt

1. **Reinigung ohne Protokollfoto** (F1). Kein Detektor, keine Monatsregel.
2. **Angefangene Reinigung** (Status `offen`): Sie fehlt in `anstehendeEinsaetzeProvider` (`providers/einsatz_providers.dart:76-95`, nur Störung/Montage/Eigenauftrag/Termin). Heute selten, relevant sobald es Zwischenspeichern gibt (siehe V2).
3. **Laufende Arbeit von gestern** (`arbeit_von` ohne `arbeit_bis`), **Arbeitstag gestern ohne Ende/km**.
4. **Diktat-Entwürfe in der Warteschlange** sind nur im Diktat-Sheet sichtbar (`diktat_sheet.dart:137`), nicht in der Glocke.
5. **RSL- bzw. HeiGenie-Mail nicht versandt**: kein Vermerk, keine Meldung (`montage_form_screen.dart:836`).

## 5. Priorisierte Vorschläge

| # | Vorschlag | Nutzen | Aufwand |
|---|---|---|---|
| **V1** | **Foto sofort beim Aufnehmen hochladen** (Pfad aus der vorab erzeugten UUID, die es im Web schon gibt, `:676-678`); Upload-Fehler **rot melden und Abschluss blockieren oder ausdrücklich bestätigen lassen**; Detektor «Reinigung ohne Protokollfoto» (Vorrat) | Schliesst F1. Das Foto ist beim Abschluss schon oben, die Kette wird eine Anfrage kürzer | ½–1 Tag |
| **V2** | **Entwurf der laufenden Reinigung lokal sichern** (localStorage: Betrieb, Anlagen, Start, Foto-Pfad aus V1, Notiz, Hähne) und beim erneuten Öffnen anbieten («Reinigung Hirschen von 09:12 fortsetzen?») | Schliesst F2 (Tab-Verlust durch Kamera oder Wegstecken) | 1 Tag |
| **V3** | **Start bei Störung/Montage öffnet den geplanten Einsatz** (Bearbeiten + «Arbeit beginnen») statt eines neuen; eine gemeinsame `starteEinsatz()` für Heute, Tourenplan und Betriebsseite | Verhindert Duplikate und den ewig offenen Stopp | ½ Tag |
| **V4** | **Service-Art aus dem Plan mitgeben** (`&serviceArt=eroeffnungsservice|endreinigung`, wenn `faelligkeit` Eröffnung oder Ende ist) | 1 Tap weniger und kein falsch abgerechneter Standardservice bei Saison-Reinigungen | ¼ Tag |
| **V5** | **Formular entrümpeln:** «Wasser gewechselt» (0×) und das Ende-Feld ausblenden (Ende kommt vom Abschluss; beim Bearbeiten bleibt es sichtbar); HeiGenie-Service-Typ und HeiGenie-Mail aus der Reinigung entfernen (0× je genutzt, `:832-900`, `:2449`); «Abschliessen» als `TapKnopf` (F5) | Kürzeres Formular, ein Wischer weniger, CanvasKit-Regel eingehalten | ½ Tag |
| **V6** | **Zahlungsart ins Formular** (vorbelegt, als kompakte Zeile oben bei der Betrieb-Karte). Der Dialog erscheint nur noch, wenn nötig: Mail ohne Adresse, Service-Hinweis vorhanden oder Abweichung von der Vorgabe. Sonst schliesst «Abschliessen» direkt ab | 82 % der Abschlüsse sparen 1 Tap und 2 Serveranfragen vor dem Dialog | ½–1 Tag |
| **V7** | **Pausen-Prüfung ans Kettenende** (nach der Buchung) oder `unawaited` (F4); Bergkunde vor die Mail ziehen | Kleineres Abbruchfenster für Buchung und Pauschale | ¼ Tag |
| **V8** | **Heute-Karte nur für draussen:** Auf der Startseite nur Einsätze, Termine, Saison-Vorschläge und eigene Aufgaben. Büro-Fristen (MWST, Heineken, Mahnlauf, Vorschläge, Saison-Stammdaten-Zähler) nur in der Glocke bzw. im Büro. Saison-Zähler als Vorrat statt Frist (Band im Formular und Tourenplan-Warnung bleiben die richtigen Orte) | Tagesplan rückt nach oben, weniger Gewöhnung an rote Karten | ½ Tag |
| **V9** | **Glocke um die Lücken aus Abschnitt 4 ergänzen** (laufende Arbeit von gestern, Arbeitstag ohne Ende, Diktat-Entwürfe, RSL-Mail ohne Vermerk) | Halbe Zustände werden sichtbar | 1 Tag |
| **V10** | **Diktat bei Reinigung:** Den Text wirklich als Notiz mitgeben (`&notiz=`). Heute steht er nur 6 s in einer Snackbar (`diktat_sheet.dart:297-313`), obwohl der Kommentar «wandert als Notiz mit» sagt. Anlagen aus dem heutigen Plan mitgeben, falls der Betrieb im Plan steht | Kein verlorenes Diktat | ¼ Tag |
| **V11** | **Formular-Bausteine** `EinsatzKopf`, `ArbeitszeitBlock`, `MaterialSlots`, `ProtokollFoto` (Abschnitt 2) | ~1'000 Zeilen weniger, Fixes nur noch einmal | 2–3 Tage |
| **V12** | **Tourenplan in 5–6 Dateien aufteilen**; «erledigt» in der Zeitachse auf `arbeit_von`/`arbeit_bis` umstellen, Wegpunkt nur als Rückfall | Wartbarkeit; ehrliche Ist-Zeiten | 1–1½ Tage |
| **V13** | **Abschluss serverseitig** (eine Edge Function oder RPC «reinigung_abschliessen»: Rechnung, Buchung, Pauschale in einer Transaktion, Mail per `waitUntil`) | Beseitigt die Klasse «Kette bricht ab» an der Wurzel | 3–5 Tage; eher als Anforderung für die v2 |
| V14 | Tote Felder in der DB (`uhrzeit_start`/`_ende` bei Montagen, doppelter Störungseingang) | Aufräumen | Entscheid 26.08.: später bzw. v2 |

**Empfohlene Reihenfolge:** V1 + V2 (Datenverlust), V3 (latenter Duplikat-Fehler), dann V4, V5, V7, V10 (je Stunden), dann V6 und V8. V11 und V12 nur, wenn ohnehin an den Formularen gearbeitet wird. V13 und V14 in die v2.

**Planungs-Features:** «Erst geplant» und «Beginn/Beenden» werden seit August praktisch nicht genutzt (0/36 bzw. 2/36). Bevor dort mehr gebaut wird, sollte Daniel gefragt werden, ob Störungen überhaupt vorausgeplant werden oder immer sofort erledigt. Falls sofort erledigt: Schalter und Beginn-Block einklappen.
