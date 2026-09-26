# Fahrtenerkennung — kritische Bewertung des v2-Konzepts und Einbauplan für die Alt-App

Stand 26.09.2026. Auftrag Daniel: «schau dir die Fahrtenerkennung der Heineken-App
sehr genau an, überlege, was man besser machen könnte, recherchiere, überlege, wie
du das in dieser App einbauen kannst, sei kritisch, hinterfrage das aktuelle
Konzept.» Rahmenentscheid Daniel: **keine gekaufte Bibliothek** (Transistorsoft
500 USD), wir bauen selbst.

Grundlage: Vollerkundung von `D:\Projekte\Heineken` (HEAD `fd8d6c6`, App
0.258.0; Spec-Bewegungserkennung-v2 S0–S8, Code unter `lib/core/bewegung/`,
Kotlin-Dienst, Migrationen), Bestandsaufnahme dieser App (Wegpunkte, Arbeitstag,
Anfahrtszeiten, Tages-Karte) und Recherche zum Stand der Technik (Quellen am
Ende).

---

## 1. Was das v2-Konzept richtig macht

Das soll vorneweg stehen, weil die Kritik unten hart ist:

- **Bluetooth des Autos als billiges Tor.** Genau so machen es TripLog und
  MileageWise; es filtert Zug, Velo und Fussweg ohne einen einzigen GPS-Fix.
- **Doppelprüfung** Bluetooth UND Bewegung ≥ 15 km/h — wenig Fehlalarme.
- **Rohdaten bleiben auf dem Gerät**, auf den Server gehen nur Abschnitte.
  Das ist datenschutzrechtlich (revDSG, Art. 26 ArGV 3 für Angestellte) die
  richtige Grenze.
- **Schwellen aus Messungen** statt aus dem Bauch: 60 s Mindestfahrt (kürzeste
  echte Fahrt 90 s, Zittern < 40 s), 30 min Ankunftsfenster (Median 9, p90 22),
  300 m Betriebsnähe (Median 267 m).
- **Kurzhalt-Regeln** (5 min, 20 min an bekannter Tankstelle), **Handstart
  schlägt Automatik**, Dubletten-Fenster, Doppler-Geschwindigkeit als
  Bewegungsbeleg, warmer Empfänger gegen den Kaltstart.
- **Reine Regel-Funktionen mit vielen Proben** (rund 220 Dart-Tests).

## 2. Grundsatzkritik am Konzept

### 2.1 Der Zweck ist verrutscht, das Konzept nicht mitgewachsen

Am 04.08. war der Zweck «Selbstkontrolle und Auswertung, nicht Lohn, nicht
Verrechnung». Heute schreibt die Erkennung **sofort in die Kette, die zugleich
Rechnungs- und Lohngrundlage ist** (Sicht `einsatz_zeit`, Montage = Stunden × 80,
«Arbeitszeit ist Lohn»). Eine Heuristik mit 45-s-Takt, 60-s-Fenster und bis zu
45 s spätem Fahrtende ist als Selbstkontrolle gut. Als Grundlage für eine
Rechnung an Heineken oder einen Lohn braucht sie eine **explizite Bestätigung**,
sonst landet jeder Erkennungsfehler direkt im Geld.

**Vorschlag:** Die Automatik schlägt vor, sie verrechnet nicht. Verrechnungs-
relevante Zeiten (Montage, Störung) gelten erst nach Danis Tipp in der Abend-
Durchsicht als «bestätigt»; bis dahin sind sie «vorläufig» und in der
Monatsrechnung gesperrt. Die Spec sagt bei Montage schon «gemessen aus der
Abschnittslogik, verrechnet bestätigt» — das muss in der Rechnung erzwungen
sein, nicht nur im Text stehen.

### 2.2 Zwei Erkennungspfade, zwei Wahrheiten

Das ist die grösste Schwäche. Ob eine Fahrt km hat, einen Ort hat, Halte hat
oder die 60-s-Regel gilt, hängt davon ab, **ob die App gerade offen war**:

| | Vordergrund-Wächter (App offen) | Hintergrund-Nachtrag (App zu) |
|---|---|---|
| Segmentierer / Halte in einer Fahrt | ja | **nein** — eine Bluetooth-Sitzung = eine Fahrt |
| 60-s-Mindestfahrt | ja | **nein** |
| Ort am Fahrtende (S6, S7, Tankstellen-Regel) | ja | **nein** (Befund: Ort wird nicht gebucht, obwohl vorhanden) |
| Kilometer (`strecke_m`) | **nein** (Dublette im Nachtrag übersprungen) | ja |
| Aktivitätserkennung | im Code, aber faktisch tot | gar nicht |

Die Spec (§4, Entscheid 2) wollte den Segmentierer als **reine Funktion über die
Spur** mit rückwirkender Selbstkorrektur. Gebaut ist ein Entprell-Fenster im
Wächter, und die Spur (JSONL) wird nach dem Nachtrag gelöscht.

**Vorschlag: ein einziger Pfad.** Der Kotlin-Dienst sammelt IMMER die Spur
(lokale SQLite-Tabelle statt JSONL, mit Akkustand), Dart wertet IMMER aus der
Spur aus — auch bei offener App. Der «Wächter» wird zur Live-Sicht auf dieselbe
Auswertung. Damit gibt es genau eine Segmentierung, einen km-Wert, einen Ort,
und jeder Fehler ist an einer Stelle zu beheben. Das ist Spec S1 und §4, nur
konsequent.

### 2.3 Bluetooth ist der einzige Hintergrund-Auslöser — ein Single Point of Failure

Ohne Bluetooth (Radio aus, anderes Fahrzeug, Mitfahrt, Kopplung verloren) wird
im Hintergrund **nichts** erkannt. Der S3-Rückfall über die Aktivitätserkennung
ist im Vordergrund tot (GPS-Fixe werden ohne Bluetooth geleert, also ist
`bewegtSich` nie wahr) und im Hintergrund nicht vorhanden (`BewegungKanal` nur
bei offener App). Am 08.09. lief die Erkennung **acht Feldtage lang gar nicht**,
ohne dass es jemand merkte — das ist das Symptom.

**Vorschlag:**
1. **Zweites Tor: Activity Recognition Transition API** (`IN_VEHICLE` ENTER/EXIT
   über PendingIntent). Das ist ein System-Broadcast, der ohne laufenden Dienst
   ankommt, sehr sparsam ist (das System bündelt die Sensor-Aufwachungen) und
   laut Android als Ausnahme gilt, aus der ein Vordergrunddienst auch aus dem
   Hintergrund gestartet werden darf — genau wie der Bluetooth-Broadcast.
   ENTER startet den `FahrtDienst`, wie heute der Bluetooth-Connect. Bekannte
   Schwäche: im Stau mischt die Erkennung IN_VEHICLE/STILL — deshalb bleibt
   die GPS-Bewegung die zweite Hälfte der Doppelprüfung.
2. **Ausfall-Erkennung als Befund in der Abend-Durchsicht:** «Heute 5 Einsätze,
   aber 0 erkannte Fahrten — läuft die Erkennung?» Das hätte die acht Leertage
   am ersten Abend gemeldet.
3. Play-Services-Abhängigkeit ist schon da (Activity Recognition); Fused
   Location kostet nichts zusätzlich (siehe 2.4).

### 2.4 Messung: 30 s ohne Mindestdistanz, LocationManager statt Fused

- Im Hintergrund alle 30 s ein Fix, Mindestdistanz 0 m. Auf der Autobahn sind
  das rund 1 km zwischen zwei Punkten; auf Bergstrassen unterschätzt die
  Luftlinie zwischen den Fixen die Strecke deutlich. Für **km je Fahrt** ist das
  zu grob. Akku ist während der Fahrt kein Argument (Ladekabel).
- `LocationManager` mit GPS + NETWORK statt `FusedLocationProvider`: Fused
  bündelt GPS, WLAN und Funkzellen, ist sparsamer und liefert mit
  `PRIORITY_HIGH_ACCURACY` plus Distanzfilter genau das, was eine Fahrt
  braucht.

**Vorschlag:** Während einer Fahrt Fused mit **5 s / 50 m**; im Stillstand
(Aktivität STILL oder keine Bewegung 2 min) auf 60 s / 200 m drosseln; ausserhalb
einer Fahrt gar nichts (Tor über Bluetooth/Activity). Das ist das Muster aller
Fahrtenbuch-Apps (Start ab ~8 km/h, Ende nach 5–15 min Stillstand).

### 2.5 Kilometer: Luftlinie zwischen Fixen ist kein Fahrtenbuch-km

`fahrt_strecke.dart` summiert Haversine-Distanzen. Sparse Fixe unterschätzen,
verrauschte Fixe überschätzen. Entscheid 4 der Spec («km aus der Spur gegen
Zählerstand, Abweichung als Befund») ist nicht gebaut.

**Vorschlag:** km je Fahrt aus dem **Strassen-Matching** der Spur (OSRM
`/match`, wie die Tages-Karte der Alt-App schon OSRM nutzt), nachts als Batch
über die Warteschlange; Zählerstand-Differenz des Tages als Kontrolle; Abweichung
> 5 % oder > 5 km als Befund in der Durchsicht («Zähler sagt 212 km, Fahrten
sagen 196 — 16 km fehlen: privat oder Umweg?»). Erst damit wird «Grundlage für
ein Fahrtenbuch» (S5) wahr.

### 2.6 Fahrtende nur über Bluetooth-Trennung

Bei verbundenem Bluetooth endet die Fahrt nie an einem Stillstand — richtig
gegen Ampeln, falsch beim Kunden mit laufendem Motor (Winter, Ausladen mit
Radio an) oder wenn das Auto die Verbindung hält. Die Fahrtenbuch-Apps beenden
nach 5 (Everlance) bis 15 min (MileIQ) Stillstand, unabhängig vom Trigger.

**Vorschlag:** Stillstand ≥ 5 min innerhalb 150 m beendet die Fahrt auch bei
verbundenem Bluetooth (der Segmentierer über die Spur macht das von selbst,
siehe 2.2); die Bluetooth-Trennung bleibt das «sichere» Ende ohne Fenster.

### 2.7 Sofortiges Schreiben in die Kette statt «vorläufig bis Feierabend»

Automatik-Abschnitte werden sofort in die Kette geschrieben, die Rechnungs-
grundlage ist; Fenster von 60 s / 5 min sind Entprellung, keine Korrektur.
Handreparaturen der Kette per Migration (01.09., 02.09.) zeigen, was das kostet.

**Vorschlag:** Spur → **Fahrten lokal** (korrigierbar, mit Selbstkorrektur
frischer Segmente) → erst beim Tagesabschluss in die Kette. Bis dahin sieht Dani
sie als «vorläufig» in der Zeitleiste. Das entkoppelt Erkennungsfehler von Lohn
und Rechnung und macht die Abend-Durchsicht zum einzigen Ort, an dem etwas
verbindlich wird — ein Tipp, wie heute.

### 2.8 Fahrtenbuch oder nicht? Der Entscheid fehlt

Wenn je ein Fahrtenbuch für die Steuer gewollt ist (Privatanteil effektiv statt
0,9 % pauschal — der Wechsel ist nur beim Fahrzeugwechsel möglich), verlangt die
ESTV: **lückenlos**, je Fahrt Datum, Start, Ziel, Zweck, km-Stand, und
**manipulationssicher** (nachträgliche Änderungen ausgeschlossen oder
nachvollziehbar; Excel reicht nicht). Heute: private Fahrten liegen nur lokal
(bei Handyverlust weg), es gibt keine Änderungshistorie der Kette (Soft-Delete,
Ereignisse in der Warteschlange — das könnte ein Audit-Log werden), Fahrten
ohne Zweck.

**Vorschlag:** Entscheiden. (a) Pauschale 0,9 % bleibt → dann ist «privat nur
lokal» in Ordnung, aber die Doku sagt es klar, und die private km-Zahl dient
nur der Plausibilität. (b) Fahrtenbuch als Ziel → alle Fahrten auf den Server
(privat ohne Ort, nur Datum/Dauer/km), Änderungslog je Abschnitt, Zweck aus dem
Einsatz. Der aktuelle Zwischenzustand («Grundlage für ein Fahrtenbuch», aber
kein Fahrtenbuch) ist der schlechteste: Aufwand ohne Nutzen.

### 2.9 Zuverlässigkeit ist nicht belegt

Feldproben S1–S8 alle offen, Kotlin ohne eine einzige Probe, die Messgrösse der
Spec («null gelöschte Abschnitte je Tag») nie gemessen, die Feldproben-SQL
veraltet.

**Vorschlag:** Eine Kennzahl, die die App selbst führt: je Tag erkannt /
bestätigt / korrigiert / gelöscht, nach 10 Feldtagen im Blatt «Tag» sichtbar.
Ohne diese Zahl lässt sich kein Schwellenwert begründet ändern.

## 3. Konkrete Code-Befunde (aus der Erkundung, im Feld nicht belegt)

Nach Gewicht:

1. **S3-Start tot** (`fahrt_waechter.dart:259-266`): ohne Bluetooth werden Fixe
   geleert → Aktivitätserkennung kann nie eine Fahrt beginnen; beim Ende ohne
   Bluetooth entscheidet allein «anders ≥ 75».
2. **Nachgetragene Fahrten ohne Ort** (`dienste.dart:734-738, 769-773`): S6, S7
   und die 20-min-Tankstellenregel greifen nur bei Fahrten, die der Vordergrund
   beendet hat — also nicht im Fall «Handy im Hosensack», für den S7 gebaut ist.
3. **Vordergrund-Fahrten ohne km** (`dienste.dart:701-717`): live gebuchte
   Fahrten werden im Nachtrag als Dublette übersprungen, bevor `strecke`
   nachgetragen wird.
4. **«privat» an einer Zeile stuft alle offenen Fahrten des Tages um**
   (`fahrten_seite.dart:69-74`).
5. **Private Morgenfahrt vor dem Tagesstart wird Arbeitszeit** (`fahrt_zuordnung`
   prüft nur den Feierabend, nicht den Tagesbeginn).
6. `fahrten_lokal.abschnitt_id` speichert das Literal `'gebucht'`
   (`dienste.dart:664`); «übersprungen» bekommt trotzdem `zuordnung='abschnitt'`.
7. Nachtrag läuft nur beim Öffnen/Zurückkehren — bleibt die App offen, gibt es
   weder Nachtrag noch Tagesstart-Knopf bis zur nächsten Rückkehr.
8. `fahrten_lokal` ohne Index und ohne Aufräumen; `FahrtProtokoll` liest bei jedem
   Schreiben die ganze Datei.
9. `POST_NOTIFICATIONS` wird nie angefragt; veraltete Kommentare/Texte zu «kein
   Hintergrundrecht» an fünf Stellen; `Werkzeuge/Fahrterkennung-Feldprobe.sql`
   misst noch den alten Behelf.

## 4. Empfohlene Zielarchitektur (für beide Apps)

```
Auslöser (sparsam, ohne laufenden Dienst):
  Bluetooth ACL_CONNECTED  ─┐
  Activity IN_VEHICLE ENTER ─┴─► FahrtDienst (Foreground, type=location)
                                   Fused 5 s / 50 m während Bewegung,
                                   60 s / 200 m im Stillstand,
                                   Ende: BT getrennt ODER IN_VEHICLE EXIT
                                         ODER 5 min Stillstand ≤ 150 m
                                   → Spur in SQLite (lat, lon, acc, speed, t, akku)

Auswertung (reines Dart, EIN Pfad, auch bei offener App):
  Spur ─► Stay-Point-Segmentierung (δ 150 m, τ 5 min) ─► Fahrten + Halte
       ─► Halt deuten: Betrieb ≤ 300 m > bekannter Ort ≤ 150 m > Startort ≤ 2 km > unbekannt
       ─► km: OSRM-Match der Spur (Batch, offline-fähig), Luftlinie nur als Vorschau
       ─► Kurzhalt 5/20 min, Handstart-Schutz, Dubletten (bestehende Regeln)
       ─► Fahrten «vorläufig» (lokal, korrigierbar)

Verbindlich wird es an einer Stelle:
  Abend-Durchsicht: Fahrten + Halte + Zähler-Differenz + Befunde
  → ein Tipp = in die Kette; verrechnungsrelevante Zeiten erst danach frei.
```

Der reine Dart-Kern (Segmentierung, Haltdeutung, Zuordnung, Regeln) gehört in
ein **eigenes Paket `fahrten_kern`**, das beide Apps einbinden. Beide rechnen
dann identisch, und die rund 220 Proben gelten für beide.

## 5. Einbau in diese App (Alt-App)

Diese App läuft produktiv im Browser; ein Browser trackt nicht im Hintergrund
(Tab-Drosselung, kein JavaScript bei dunklem Bildschirm — deshalb stempelt sie
heute bewusst nur Ereignisse). Ein GPS-Tracking gibt es hier also nur im
Android-Build. Der wichtigere Punkt: **Für einen Servicetechniker, dessen Halte
alle bekannt sind, lässt sich ein Fahrtenbuch zu 90 % ohne GPS ableiten.**

### Stufe 1 — «Fahrten aus der Kette», heute im Web möglich (2–3 Tage)

- Pro Tag die Ereignisse ordnen: Arbeitsbeginn (Startort, `start_lat/lng`),
  Reinigungen (`uhrzeit_start/ende`, Betrieb), Störungen/Montagen
  (`arbeit_von/bis`, Betrieb, Wegpunkt-Stempel), Feierabend (`end_lat/lng`).
- Jede Lücke zwischen zwei Halten ist eine Fahrt: von → nach, Abfahrt = Ende des
  vorigen Halts, Ankunft = Beginn des nächsten.
- km je Fahrt: Startort→Betrieb aus `anfahrtszeiten.distanz_km` (804 Routen
  liegen vor), Betrieb→Betrieb per OSRM-Route (Tages-Karte kann es schon;
  `fahrzeiten` um `distanz_km` erweitern und cachen).
- Kontrolle: Σ Fahrten-km gegen `km_stand − km_start` des Tages → Differenz in
  der Arbeitstag-Auswertung; > 5 km = Frage «privat oder Umweg?».
- Neue Tabelle `fahrten` (datum, von/nach als Typ+Id, abfahrt, ankunft,
  km_route, km_gps, zweck aus dem Einsatz, privat, herkunft `kette|gps|hand`,
  bestätigt_am). Das ist bereits ein Fahrtenbuch mit Datum, Start, Ziel, Zweck,
  km — nur der Zählerstand je Fahrt fehlt (Tageswerte reichen für die
  Plausibilität, nicht für die ESTV-Variante).
- Kein Akku, keine Berechtigung, kein Hintergrunddienst. Der Nutzen ist sofort
  da: Tages-km-Plausibilität, Fahrzeiten-Lernen mit Distanzen, Grundlage für die
  Prüfung der Gebietsfahrt-Pauschale.

### Stufe 2 — Android-Vorlage mit Spur (1–2 Wochen, nur wenn Stufe 1 nicht reicht)

- Kotlin-Dienst wie in §4 (Bluetooth ODER Activity-Transition als Auslöser,
  Fused Location, Spur in SQLite). Der v2-Kotlin-Code ist die Vorlage; Fused und
  das zweite Tor kommen dazu.
- Paket `fahrten_kern` (rein Dart) aus v2 herausgelöst und geteilt.
- Die Spur ergänzt Stufe 1: exakte Zeiten, unbekannte Halte (Tankstelle, Depot,
  privat), km per OSRM-Match. Stufe 1 bleibt der Rückfall, wenn die Spur fehlt —
  genau der Fall, der v2 heute acht Leertage gekostet hat.

### Was hier bewusst NICHT gebaut wird

- Kein Geofencing um 700 Betriebe (Limit 100 pro App, dynamisches Nachladen
  wäre möglich, bringt aber gegenüber der Distanzregel nichts).
- Kein Dauer-Tracking im Web.
- Keine gekaufte Bibliothek (Entscheid Daniel). Das quelloffene Tracelet
  (Apache 2.0, aktiv, aber jung: 62 Stars) wäre der Rückfall, falls der eigene
  Kotlin-Dienst zu viel Pflege braucht — es kapselt genau Fused + Activity +
  Stay/Move-Automat.

## 6. Reihenfolge, die ich empfehle

1. **v2, sofort (Tage):** Befunde 1–5 beheben; Ausfall-Befund in der
   Durchsicht; Kennzahl erkannt/bestätigt/korrigiert.
2. **v2, danach (1–2 Wochen):** ein Pfad über die Spur (SQLite statt JSONL,
   Segmentierer über die Spur, Ort und km für alle Fahrten), Activity-Transition
   als zweites Tor, Fused 5 s / 50 m, «vorläufig bis Feierabend».
3. **Entscheid Daniel:** Fahrtenbuch als Steuerbeleg ja/nein (§2.8).
4. **Alt-App, parallel (2–3 Tage):** Stufe 1 «Fahrten aus der Kette» mit
   Zähler-Kontrolle — läuft im Web, braucht nichts vom Handy.
5. **Später:** `fahrten_kern` als gemeinsames Paket, Android-Spur in der
   Alt-App als Vorlage.

## Quellen

- Android: [Activity Recognition Transition API](https://developer.android.com/develop/sensors-and-location/location/transitions),
  [Geofencing (Limit 100, Dwell, Radius ≥ 100 m)](https://developer.android.com/develop/sensors-and-location/location/geofencing),
  [Background location](https://developer.android.com/develop/sensors-and-location/location/background),
  [Batterie-Szenarien](https://developer.android.com/develop/sensors-and-location/location/battery/scenarios)
- Google Play: [Sensitive permissions / Location (Policy ab 2027)](https://support.google.com/googleplay/android-developer/answer/16909972),
  [Background-Location-Regeln](https://support.google.com/googleplay/android-developer/answer/9799150)
- Fahrtenbuch-Apps: [MileIQ Drive Detection](https://mileiq.com/mileage-tracker/drive-detection),
  [Everlance – how it works](https://www.everlance.com/blog/how-does-everlance-work-an-in-depth-guide),
  [TripLog Auto-Tracking-Vergleich (Bluetooth, MagicTrip)](https://help.triplog.net/en/articles/5539249-auto-tracking-introduction-and-comparison),
  [MileageWise Bluetooth-Trigger](https://www.mileagewise.com/help/new-android-mileage-tracker-app-bluetooth-feature/)
- Bibliotheken: [flutter_background_geolocation – Philosophy of Operation](https://github.com/transistorsoft/flutter_background_geolocation/wiki/Philosophy-of-Operation),
  [Preise (500 USD je App)](https://docs.transistorsoft.com/purchase/),
  [Tracelet (Apache 2.0)](https://github.com/Ikolvi/Tracelet)
- Algorithmen: [Staypoint Detection from Noisy Trajectory Data (2026)](https://arxiv.org/html/2607.19312v1),
  [Stay Point Detection 101](https://medium.com/tblx-insider/data-science-stay-point-detection-101-54335ccb0de4)
- Schweiz: [Privatanteil Geschäftsfahrzeug (Treuhand Suisse)](https://www.treuhandsuisse.ch/blog/geschaeftsfahrzeuge),
  [Fahrtenbuch-Anforderungen (spesen-app.ch)](https://spesen-app.ch/wiki/fahrtenbuch-anforderungen-schweiz-spesen),
  [Privatanteil 2026 (Pfeffersack)](https://pfeffersack.ch/blog/privatanteil-geschaeftsfahrzeug-schweiz)
