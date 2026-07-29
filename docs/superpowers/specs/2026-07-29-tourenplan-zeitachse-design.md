# Tourenplan als Tageszeitplan — Design

Stand 29.07.2026, mit Daniel abgestimmt (Grundprinzip, Tagesstart, Fahrzeiten-Kaskade,
Warnungen, Besuchs-Blöcke, Totzeit, Arbeitstag-Rahmen). Status: zur Freigabe.

## Ziel

Der Tagesplan-Tab der Tourenplanung wird von einer sortierten Liste zu einem
**berechneten Tageszeitplan**: Zeitleiste links (ab 06:00), Einträge als Blöcke in der
Höhe ihrer voraussichtlichen Dauer, Fahrzeiten als Verbinder dazwischen. Daniel ordnet
weiterhin nur die Reihenfolge — die Uhrzeiten rechnet die App ab Arbeitsbeginn.
Störungen und Montagen sind gleichwertig einplanbar; der ganze Arbeitstag inkl.
Anfahrt und Heimweg wird sichtbar.

## Entscheidungen (Daniel, 29.07.2026)

| Frage | Entscheid |
|---|---|
| Zeitachse | Berechnet aus Reihenfolge; kein freies Platzieren |
| Tagesstart | 06:00 Standard, pro Tag anpassbar (= Arbeitsbeginn) |
| Fahrzeiten | Lernende Kaskade: beobachtet → Route → Heuristik |
| Warnungen | Ruhetag/Ferien-Konflikt + Servicezeit-Konflikt (keine Tagesende-Warnung) |
| Plan-Einheit | Besuch beim Betrieb (nicht die einzelne Anlage) |
| Mittagspause | Gibt es nicht — kein Pause-Block. Stattdessen Termin-Anker + sichtbare Wartezeit |
| Arbeitstag | Arbeitsbeginn/-ende + km-Stand abends erfassen; Anfahrt/Heimweg ab Zuhause im Plan |
| Auswertungen | NICHT in diesem Paket — nur Datenerfassung |
| Routen-Optimierung | NICHT in diesem Paket — Reihenfolge bleibt Handarbeit |

## Datenlage (geprüft 29.07.2026)

- 8'472 Reinigungen; 889 mit `uhrzeit_start`+`uhrzeit_ende`, 446 mit `dauer_minuten`,
  187 Betriebe mit Dauer-Historie. Median 28 min.
- `anlage_ids` (jsonb-Array) hält die Zusatzanlagen eines Besuchs. Median-Dauern nach
  Anlagenzahl: 2 → 33 min (243 Besuche), 3 → 54 min (39), 4 → 86 min (7).
- 292 von 293 aktiven Betrieben haben GPS-Koordinaten.
- `tagesplaene` existiert (datum, eintraege jsonb) — Erweiterung, keine neue Entität.

## Architektur

Reine, getestete Logik in `lib/core/util/`, UI liest sie über Provider. Drei neue
Util-Dateien, eine DB-Migration, eine Edge-Function, Umbau des Tagesplan-Tabs.

### 1. Besuchs-Blöcke (Plan-Einheit)

Ein Plan-Eintrag vom Typ Reinigung repräsentiert einen **Besuch bei einem Betrieb**
mit einer Menge gewählter Anlagen.

- Übernahme aus der Fällig-Liste (Tap/Drag auf eine Anlage): Es entsteht EIN Block für
  den Betrieb; alle weiteren **heute fälligen** Anlagen desselben Betriebs werden
  automatisch mit aufgenommen. Existiert der Besuchs-Block schon, wird die Anlage dort
  ergänzt statt einen zweiten Block zu erzeugen.
- Block-Chip «n von m Anlagen» → Bottom-Sheet mit Checkboxen aller **aktiven** Anlagen
  des Betriebs (fällige vorangehakt). Anlagen mit Status ≠ aktiv erscheinen nicht.
- `TourEintrag` wird erweitert: `anlageIds: List<String>` (ersetzt das einzelne
  `anlageId` für Reinigungen; Altpläne mit einzelnem `anlageId` werden beim Laden
  migriert), `dauerMinuten: int?` (manuelle Übersteuerung), `ankerZeit: String?`
  (Termin-Anker «frühestens HH:mm»).

### 2. Dauer-Schätzung — `lib/core/util/besuch_dauer.dart`

`geschaetzteDauer({betriebHistorie, anlagenZahl})` mit Kaskade:

1. **Median** der historischen Besuche dieses Betriebs mit **gleicher Anlagenzahl**
   (Dauer aus `dauer_minuten`, sonst aus `uhrzeit_start/ende`; nur 5–300 min gültig).
2. Sonst: Median aller Besuche des Betriebs, skaliert über die globale Kurve
   (Verhältnis der globalen Mediane je Anlagenzahl; Stützwerte 1→28, 2→33, 3→54,
   4→86 min, darüber linear fortgeschrieben).
3. Sonst: 60 min.

Median statt «Durchschnitt ohne Ausreisser»: unempfindlich gegen einzelne
Langläufer, ohne willkürliche Grenze. Störung/Montage: Standard 60 min.
Jede Dauer ist am Block manuell übersteuerbar (`dauerMinuten`).

Historie kommt aus den lokal vorhandenen Reinigungen (Provider), Web wie Native.

### 3. Fahrzeiten — lernende Kaskade

**Neue Tabelle `fahrzeiten`** (Migration):
`id, user_id, von_betrieb_id, nach_betrieb_id, minuten int, quelle text
('beobachtet'|'route'|'heuristik'), anzahl int default 1, updated_at`.
Unique auf (user_id, von, nach). Richtungsabhängig gespeichert, Abfrage prüft beide
Richtungen (beobachtet bevorzugt in gespeicherter Richtung, sonst Gegenrichtung).

Kaskade in `lib/core/util/fahrzeit.dart` + Repository:

1. **Beobachtet**: Eintrag `quelle='beobachtet'` (Median echter Übergänge). Backfill
   einmalig per Migration aus den 889 historischen Reinigungen: Übergänge = Ende bei
   Betrieb A → Start bei Betrieb B am selben Tag, 3–120 min gültig. Läuft danach
   weiter: Beim Abschliessen einer Reinigung mit Uhrzeiten wird der Übergang zum
   vorherigen Betrieb des Tages nachgeführt (gleitender Median über `anzahl`).
2. **Route**: Fehlt ein Eintrag, ruft die App die Edge-Function `fahrzeit-route`
   (Proxy auf den OSRM-Demo-Server, `router.project-osrm.org`, Profil driving; kein
   API-Key nötig; Ergebnis wird als `quelle='route'` in `fahrzeiten` gecached — jede
   Strecke wird höchstens einmal geroutet). Beobachtungen überschreiben Route-Einträge.
3. **Heuristik** (offline/Ausfall): Luftlinie (Haversine) × Faktor. Faktor wird beim
   Backfill aus den beobachteten Paaren kalibriert (Median von beobachtet/Luftlinie),
   Startwert 1.6, Annahme 45 km/h Schnitt im Berggebiet; Ergebnis NICHT in die
   Tabelle geschrieben (nur Anzeige), damit später Route/Beobachtung nachrücken.

Anfahrt und Heimweg nutzen dieselbe Kaskade mit dem **Startort** aus
`geschaeft_einstellungen` (zwei neue Spalten `startort_lat/lng`; Erfassung im
Einstellungen-Formular, Vorbefüllung per bestehendem Google-Lookup optional).

### 4. Zeitplan-Berechnung — `lib/core/util/zeitplan.dart`

Reine Funktion: `berechneZeitplan({eintraege, arbeitsbeginn, fahrzeiten, dauern})`
→ Liste von Segmenten (Anfahrt | Besuch | Fahrt | Wartezeit | Heimweg) mit Start/Ende.

- Ablauf: Arbeitsbeginn → Anfahrt → Block 1 → Fahrt → Block 2 → … → Heimweg.
- **Termin-Anker**: Hat ein Block `ankerZeit` und die berechnete Ankunft liegt davor,
  wird ein Wartezeit-Segment eingeschoben (gelb, «⏳ n min Wartezeit»). Ankunft nach
  Anker: kein Effekt (nur Anzeige des Ankers am Block).
- **Servicezeit-Vorschlag**: Liegt die Ankunft ausserhalb des Servicefensters des
  Betriebs und das nächste Fenster beginnt später, bietet der Block «Anker auf HH:mm
  setzen?» an (ein Tap).
- Warnungen als Flags am Segment: `ruhetagKonflikt` (Betrieb am Plantag zu:
  Ruhetag/Ferien/Saisonpause — via bestehendem `istOffenerTag`), `servicezeitKonflikt`
  (Ankunft–Ende ausserhalb aller Fenster). Rot bzw. orange am Block, keine Blockade.

### 5. UI — Tagesplan-Tab

- Links Zeitleiste ab 06:00, Stundenraster; Ende = max(18:00, Planende). Rechts die
  Blöcke: Höhe proportional zur Dauer (Minimum ~44 px für Tippbarkeit; darunter
  komprimierte Darstellung), Fahrzeit-Verbinder schmal grau («🚗 12 min»), Wartezeit
  gelb, Anfahrt/Heimweg als Randsegmente.
- Reihenfolge ändern: bestehendes Drag-Handle (ReorderableList bleibt die Grundlage,
  die Zeitleiste wird aus denselben Einträgen gezeichnet).
- Block-Tap → Sheet: Anlagen-Auswahl, Dauer übersteuern, Anker setzen/entfernen,
  Eintrag entfernen. CanvasKit-Regel beachten (GestureDetector statt Material-Buttons).
- Kopfzeile: «Start 06:00» (Tap → TimePicker, gespeichert am Tagesplan). Fusszeile
  abends: Arbeitsende + km-Stand (zwei Felder, gespeichert am Tagesplan).
- `tagesplaene` bekommt `arbeitsbeginn text, arbeitsende text, km_stand int`
  (Migration, nullable).

### 6. Plan-Übernahme von beliebigem Datum

Menüpunkt «Plan von Datum übernehmen» im Tagesplan: DatePicker → Einträge jenes
Tages in identischer Reihenfolge in den aktuellen Tag kopieren (Besuche mit ihren
Anlagen). Heute nicht fällige Besuche werden übernommen, aber grau markiert.
Bestehende Einträge des Zieltags bleiben erhalten (Anhängen), doppelte Betriebe
werden nicht dupliziert.

### 7. Fällig-Liste (Kleinkram)

- Titelzeile «Betrieb - Ort» in EINER Schriftgrösse (bisher Ort kleiner).
- Unter dem Fälligkeits-Label das Datum der letzten Reinigung («zuletzt 04.06.2026»).

## Nicht im Umfang

- Auswertungen (km, Stunden, Anfahrtskosten je Kunde) — Daten werden nur erfasst.
- Automatische Routen-Optimierung (beste Reihenfolge).
- Tagesende-Warnung (bewusst abgewählt).
- Google-Kalender-Bezug (separates Projekt G1–G4).

## Tests

- `besuch_dauer_test.dart`: Kaskade, Anlagenzahl-Skalierung, Gültigkeitsfenster,
  Median-Robustheit, Default.
- `fahrzeit_test.dart`: Kaskaden-Reihenfolge, Richtungslogik, Heuristik-Kalibrierung,
  Median-Nachführung.
- `zeitplan_test.dart`: Segmentkette, Anker/Wartezeit, Warn-Flags, Anfahrt/Heimweg,
  leerer Plan.
- Widget-Test Zeitleiste: 360/375/412 px ohne Überlauf, Mindesthöhe der Blöcke.
- Migrations-Backfill: Kontrollzahlen (Anzahl Paare, Median-Stichproben) per SQL.

## Risiken & Umgang

- **OSRM-Demo-Server** ist Fair-Use ohne Garantie → durch Cache selten gebraucht;
  fällt er aus, greift die Heuristik geräuschlos. Später auf eigenen Key (ORS)
  wechselbar, nur die Edge-Function betroffen.
- **Alte Tagespläne** (einzelnes `anlageId`) → Lade-Migration auf `anlageIds`.
- **Wenig Historie bei manchen Betrieben** → Kaskade endet immer bei 60 min; Anzeige
  unterscheidet geschätzt (kursiv/grau «~») von manuell gesetzt.
