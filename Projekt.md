# SBS Projer App - Projekt-Übersicht

**Projekt**: Service-Management App für Zapfanlagen-Service
**Kunde**: Daniel Projer, SBS Projer GmbH
**Stand**: 07.08.2026
**Tech-Stack**: Flutter + Supabase
**Version**: 0.72.10+663 (Buchhaltungs-Fahrplan Schritte 1–3 erledigt: Heineken-Rundung v0.72.5, Storno-Reparatur v0.72.6 + Migration 166, MwSt-Doppelbuchung behoben v0.72.7 inkl. Bereinigung von 977 Trennbuchungen per Snapshot-Migration, camt-Stichtag/Richtung v0.72.8; camt-Import-Gesamtprüfung mit Härtung v0.72.9; Sammelzahler + Zahlernamen-Lernen v0.72.10 — 135 Zahler-Aliase auf 123 Betrieben; 83 Original-Monatsrechnungs-PDFs 2019–2026 in den Storage geladen + Regenerier-Sperre v0.72.4; MWST-Stand geklärt: Q4/2025 eingereicht, Berichtigung 2025 = 1'508.62 rappengenau, Q1+Q2/2026 Frist Ende August) (v0.64.0: **echte Strassenroute in der Tages-Karte** — der neue `TagesrouteService` holt den gefahrenen Verlauf bei OSRM (GeoJSON) statt Luftlinien quer über Berge und Seen; die Karte ist sofort mit der Luftlinie da und schärft nach, bei fehlender Autoroute oder ohne Netz bleibt die Luftlinie dünner und blasser stehen. v0.63.0: **Routen-Optimierung** im Tagesplan (Nächster-Nachbar + 2-opt, Termin-Anker bleiben fix, kann nie verschlechtern), neuer Screen **Auswertung Arbeitstage** (km/Stunden/Besuche je Monat, getrennte Nenner je Kennzahl), **Pause-Knopf** in der Arbeitstag-Karte (Migration 159, Tagessumme + laufende Pause + Wegpunkt-Stempel). v0.62.0: **OpenStreetMap als dritter Kartenhintergrund und neuer Standard** — swisstopo-Karte und Luftbild bleiben; Quellenangabe folgt dem gewählten Dienst; Event-Stände-Karte bleibt auf Luftbild. Google Maps als Hintergrund ist lizenzrechtlich ausgeschlossen (Kacheln nur mit Google-Renderer). v0.61.0: **Störungen/Pausen verderben die Fahrzeit-Lernkurve nicht mehr** — 23 % der beobachteten Werte lagen über 2× der echten Route, Ø 43 min zu viel. Neu ein Routing-Referenzwert je Betriebspaar (Migration 158, 2'882 Werte per OSRM-Matrix), `lueckePlausibel()` lernt nur im Fenster 0,5×–2×, 652 verdorbene Altwerte bereinigt (Rollback vorhanden). v0.60.1: neue Betriebe bekommen ihre Anfahrtszeiten ab Domat/Ems und Chur automatisch beim Speichern — Edge-Function `anfahrt-google` rechnet neu auch Einzelbetriebe und hat OSRM als kostenlosen Rückfall. v0.60.0 **Grundsatzfund**: Störungen und Montagen liessen sich gar nicht planen — beide Formulare schrieben den Status hart auf erledigt, weshalb alle 1'106 Störungen «behoben» und alle 809 Montagen «abgeschlossen» sind und der Tourenplan nie einen Eintrag fand. Neu: Schalter «Erst geplant» in beiden Formularen (Wegpunkt-Stempel nur bei erledigten Einsätzen), gemeinsame Helfer `stoerungOffen`/`montageOffen`. Dazu: Ein Tag mit erfasstem Feierabend gilt als abgeschlossen und wird statisch mit den Ist-Zeiten gezeigt, statt den Rest-Plan hinter «jetzt» zu schieben. v0.59.0: Servicezeiten + Ruhetage direkt am Tagesplan-Block, Warnung nennt den konkreten Grund (Ruhetag/Betriebsferien bis .../Zwischensaison), neue Warnung «Termin verpasst» wenn ein Anker vor der geplanten Ankunft liegt. v0.58.1: **Anfahrtszeit-Bug behoben** — Sonne Seehotel Eich zeigte 346 statt 117 min; die Heuristik war an Bergstrecken kalibriert und skalierte nicht (Median-Fehler über 100 km: 249 min). Umwegfaktor und Schnitt laufen jetzt distanzabhängig (2.20→1.45 / 32→78 km/h), kalibriert an 804 echten Routen: Median-Fehler 7 statt 35 min; Rüstzuschlag additiv 5 min; Anfahrt/Heimweg nehmen primär die gerechneten `anfahrtszeiten`-Werte, Startort per GPS erkannt. Migration 157 hält Google- und OSRM-Werte nebeneinander, Edge-Function `anfahrt-google` wartet auf Aktivierung der Routes API. v0.58.0: neuer **Aufgaben-Screen** als Kachel — anstehende Arbeiten chronologisch: eigene Aufgaben, offene Störungen, geplante Montagen, Eröffnungs-/Endreinigungen; Events in die Liste unten verschoben; Migration 156 `anfahrtszeiten` mit 804 OSRM-Routen von beiden Startorten zu allen Betrieben als Grundlage der Routen-Optimierung; v0.56.1: vergangene Tage mit gemessenen Ist-Zeiten; v0.56.2: Betriebsseite aus dem Block-Sheet verlinkt, fällige Geschwister-Anlagen bei Plan-Übernahme/Bulk ergänzt — Sunset-Fall, Arbeitstag-Fehleingaben-Schutz; v0.56.3: Startbildschirm kompakt ohne Scrollen; **v0.57.0 Nachtpaket 31.07.**: vergangene Tage zeigen die TATSÄCHLICHEN Reinigungen statt gespeicherter Pläne — readonly-Zeitachse, Tap öffnet die Reinigung; Plan-Übernahme lädt die echten Reinigungen des Quelltags ohne Störungen/Montagen; neue **Tages-Karte** (map-Icon im Tagesplan-Header): nummerierte Besuchs-Marker + Wegpunkt-Stempel auf swisstopo, zeitlich verbundene Linie, aussagekräftig ab 31.07.; GPS mit bis zu 3 Messungen, genaueste gewinnt — Openair-Befund; alle 16 Test-Tagespläne gelöscht, Arbeitstag-Daten 30.07. erhalten)

> Detaillierter aktueller Stand & offene Punkte: **`ToDo.md`** (Projekt-Root) + Memory.
> Zuletzt (07.08.2026): **Buchhaltungs-Fahrplan Schritte 1–3 + camt-Gesamtprüfung + Heineken-Originale** (v0.72.4–v0.72.10): **Heineken-Monatsrechnungen** — die 83 historischen PDFs (05/2019–03/2026) im Storage waren 3-Seiten-Skelette aus dem Daten-Backfill vom 14.07.; die versendeten **Original-PDFs mit den Heineken-Formularen** (aus `00_Buchhaltung/Monatsrechnungen Heineken 2019-2026/`, ab 08/2023 Kombi-Datei, davor aus Einzel-PDFs zusammengeführt) wurden über eine temporäre token-geschützte Edge Function hochgeladen (83/83 Brutto-verifiziert, Hashes geprüft; Function danach stillgelegt) + **Sperre «PDF neu generieren»** für Monate vor 04/2026 (v0.72.4). **Fahrplan Schritt 1 (B2)**: Heineken-Buchung ohne 5-Rappen-Rundung (`heinekenBuchungsBetraege`), 3 Buchungen korrigiert, Invariante brutto=netto+mwst DB-weit sauber (v0.72.5). **Schritt 2 (B6+B1)**: Storno-Mechanik repariert (Gegenbuchung datiert aufs Original, ohne mwst_konto, Trennbuchungen mitstorniert; Ausschluss-Filter in getAllSaldi/MWST-Provider/5 Guards; Migration 166 MWST-View; v0.72.6) — dann die 4 Trennbuchungs-Codepfade gestrichen und **977 MwSt-/VSt-Trennbuchungen per Snapshot-Migration bereinigt** (Ertrag +10'219.98, 2200 −10'219.98; `snapshot_mwst_trennbuchungen`; v0.72.7). **Schritt 3 (Code)**: camt-Stichtag exklusiv (11.03. war Excel-gebucht) + Ausgabe-Booker richtungsbewusst (v0.72.8). **MWST geklärt**: ePortal-Check + Portal-PDFs Q2–Q4/2025 → Q4/2025 ist eingereicht, Netto-statt-Brutto in allen 4 Quartalen belegt, **Berichtigung 2025 = 1'508.62 rappengenau** (Vorlage `docs/mwst-q4-2025-nachreichung.md`); Q1+Q2/2026 Frist Ende August, Erinnerung Di 11.08. 19:00. **camt-Import-Gesamtprüfung** (`docs/camt-import-pruefung-2026-08-07.md`): Geschäftsfall-Vorlagen-Crash im Ausgabe-Booker gefixt, offene Prüflisten-Fälle re-importierbar (Heineken-Gutschriften 7'104.98/5'794.81 werden buchbar), Sammelzahler (Davos Klosters/Weisse Arena/**Goodfast**) nie auto, Archiv erst nach Verarbeitung, Dateien-Duplikate bereinigt (v0.72.9/10). **Zahlernamen-Lernen**: 1'606 Historik-Gutschriften gegen bezahlte Rechnungen gematcht → 57 Aliase automatisch; Internet-Recherche (3 Agenten, Zefix/Impressen) klärte die 53 offenen Fälle → +55 Aliase, 2 Korrekturen (Alpenblick-Arosa, Lenzerhorn=Zwei-Betriebe-Zahler), AlpinTrend-Gruppe erklärt 5 Zahler; **Endstand 123 Betriebe / 135 Aliase** (`docs/camt-zahlernamen-lernen-2026-08-07.md`). Stammdaten: Goodfast-Vierergruppe (Grischa/Golden Dragon/Jodys/Bräma) auf Rechnung Mail mit Grischa-Adresse; Franchise-Vorlage neu 6301+VSt 1170. Offen: frischer GKB-camt-Export (Daniel) → Nachhol-Import, dann Fahrplan Schritte 4–7. Details `ToDo.md`.
> Zuletzt (01.–07.08.2026 früh): **Betriebsdaten aktuell halten + Einsatzplanung mit Sprache + Prüfberichte** (v0.65.0–v0.72.3): **v0.65.0 Ferien-Paket** (Migrationen 160/161): eigene `betrieb_ferien`-Vertikale, Google-+Website-Abgleich als Edge Functions mit täglichem pg_cron-Lauf und Prüfliste für Änderungsvorschläge, «War geschlossen»-Knopf (Ferien/Ruhetag/Leerfahrt), graues Vorjahres-Band im Tourenplan; Ferienfrage beim Abschluss in v0.72.1 wieder entfernt (Entscheid Daniel). **v0.66.0**: vergessene Pause wird erkannt. **v0.67.0–v0.70.x Einsatzplanung** (Migrationen 163/164): Störungen/Montagen echt planbar (Plan-/Arbeitszeitfelder, Dauer-Vorgaben, Sichtbarkeitsregel), geplante Einsätze im Google-Kalender mit Erinnerung, **Diktier-Knopf** auf der Startseite (Edge Function `parse-einsatz`, erkennt auch neue Betriebe), Eröffnungs-/Endreinigungen als bestätigte Termine. **v0.71.0** (Migration 165): Tresen-Übergabe und Mailversand getrennt (`uebergeben_am`/`versendet_am`). **v0.72.0**: Saison-Reinigungen am Schliessungstag planbar (Fall Löwen Grossdietwil) + bestätigte Termine im Tourenplan; Datenpflege (20 Winterfenster-Jahreszahlen, 12 fehlende Anlagen, Golden-Dragon-Anlage). **v0.72.2**: Arbeitstag-Auswertung lädt Besuche monatsweise; `kAppVersion`-Test gegen Auseinanderlaufen. Beleg-Scan liest Beträge aus der MwSt-Tabelle. **Datenprüfung 05.08.** (`docs/datenpruefung-2026-08-05.md`): MwSt-Doppelbuchung + camt-Stichtag-Off-by-One entdeckt, Geldseite still seit 11.03., Forderungen 173'123. **Buchhaltungs-Gesamtprüfung 06.08.** (`docs/buchhaltungspruefung-2026-08-06.md`, 4 Agenten): Fahrplan mit 7 Schritten + 12 Entscheidungsfragen; Nachtrag: Netto-statt-Brutto-Deklarationsfehler 2025. **v0.72.3**: Buckets `material-fotos`/`raster-pdfs` privat (Sicherheitsbefund Projekt Heineken). Details `ToDo.md`.
> Zuletzt (30.07.2026): **Live-Tagesplan + Arbeitstag am Startbildschirm + Datenreparatur Zeiten** (v0.55.1–v0.56.0, 702 Tests): **v0.56.0 Live-Modus** — der heutige Tagesplan zeigt Erledigtes mit den **gemessenen** Zeiten (grüne Blöcke «X min gemessen», gemessene Fahrten, gelbe frei-Fenster ab 3 min, rote Jetzt-Linie), Rest-Plan rechnet ab jetzt weiter, Minutentakt-Timer; Ist-Quellen: abgeschlossene Reinigungen (uhrzeit_start/ende) + **Wegpunkt-Stempel** für Störung/Montage (`berechneZeitplanMitIst` in `zeitplan.dart`). **Wegpunkte** (Migration 155, `wegpunkt_repository.dart`): Zeit+GPS+Kontext bei Reinigungs-Abschluss, Störung, Montage, Arbeitsbeginn, Feierabend — ereignisbasiert statt Dauer-GPS (Web-App drosselt Hintergrund); dazu **Fahrzeit-Lern-Guard**: liegt ein Störungs-/Montage-Stempel zwischen zwei Reinigungen, wird die Lücke nicht als Fahrzeit gelernt. **Arbeitstag-Karte auf dem Startbildschirm** (Migrationen 153/154): «Jetzt starten» mit km-Stand + GPS-Position (Daniel startet von Domat/Ems ODER Chur), «Feierabend» mit End-km + End-GPS → Tages-km ohne Privatfahrten; Startort-Fallback Via Rezia 8 in Geschäftseinstellungen. **Zeitauswahl überall 24h** ohne AM/PM (`zeit_auswahl.dart`, alle 5 Stellen). **Excel-Zeiten-Nachtrag** (Sheet Reinigung, Spalten Dauer/Zeit Beginn/Ende): 7'636 Reinigungen haben jetzt echte Uhrzeiten (vorher 895; 842 im Excel ohne Zeit, 145 ohne Match), fahrzeiten-Beobachtungen komplett neu aufgebaut — **3'045 Paare** aus 5'616 Übergängen (vorher 216, teils durch 1-Minüter vergiftet), Heuristik-Faktor 2.2→**2.5** (Median 2.53). Rollback-Skripte unter `Datenbank/wartung/`. Ausserdem neue globale Arbeitsregel: Modell/Aufwand je Aufgabe vorschlagen. Details `ToDo.md`.
> Zuletzt (29.07.2026): **Tourenplan als Tageszeitplan v0.55.0** (Spec+Plan `docs/superpowers/…2026-07-29-tourenplan-zeitachse…`, 9 Tasks subagent-getrieben mit je 2-stufigem Review; 691 Tests): Tagesplan-Tab rendert die geordnete Liste auf einer **Zeitleiste ab 06:00** — Besuchs-Blöcke in Dauer-Höhe, Fahrzeit-Verbinder, gelbe Wartezeit bei **Termin-Ankern**, Anfahrt/Heimweg ab Startort (neu in Geschäftseinstellungen). **Besuchs-Blöcke** bündeln alle heute fälligen Anlagen eines Betriebs (Chip «n von m», Sheet mit Anlagen-Auswahl/Dauer/Anker); Dauer = **Median je (Betrieb, Anlagenzahl)** (`besuch_dauer.dart`, Kurve 28/33/54/86 min), manuell übersteuerbar. **Fahrzeiten lernende Kaskade** (`fahrzeiten`-Tabelle, Migration 152): 216 beobachtete Paare aus historischen Reinigungs-Uhrzeiten (Backfill), Edge-Function `fahrzeit-route` (OSRM, gecached), Heuristik Luftlinie×**2.2** (kalibriert an 180 Paaren — inkl. Parkieren/Umladen); Nachführung beim Abschliessen einer Reinigung. Warnungen Ruhetag/Ferien + Servicezeit (Ankunft–Ende), **Plan-Übernahme von beliebigem Datum** (nicht Fällige grau «übernommen»), Arbeitsbeginn/-ende + km-Stand am Tagesplan erfasst (Auswertung = späteres Paket). Dazu Fällig-Liste: «Betrieb - Ort» eine Grösse, «zuletzt dd.MM.yyyy» unterm Badge. Review-Fixes u.a.: Backfill-Join (Ketten am selben Betrieb), Chip-Sichtbarkeit bei kurzen Blöcken, Alle-Filter-Kontamination der Bündelung. Vormittags ausserdem v0.54.17–20: Tourenfilter einzeilig (Saison zusammengefasst, «Alle»), Saisonprüfung repariert (35 unsichtbare Betriebe), Servicezeiten/Ruhetage-Fixes, Google-Fehler verständlich, Kontakte-Sync eine Karte je Betrieb «Ort - Betrieb (Person)» + Heineken-/Event-Schema, batchUpdate gegen Timeout. Details `ToDo.md`.
> Zuletzt (28.07.2026): **Spesen-Scanner produktiv + Buchhaltung aufgeräumt** — drei Blöcke. **(1) Spesen-Scanner v0.53.9–v0.54.9**: Kategorien nachgeschärft (Baumaterial → 4004), **Tabakwaren als Privatbezug 2260** (nicht gebucht bei Zahlungsweg privat), Korrektur-Schritt vor dem Buchen (Positionen bearbeiten/löschen/hinzufügen), Beleg drehen direkt nach der Aufnahme, Dubletten-Warnung, Bar-Rundung nur aufs Total (`beleg_korrektur.dart`, 20 Tests), Ausrichtung per KI (`bild_drehung`) statt EXIF, Doppeltipp-Riegel vor dem ersten `await` (Ursache einer Doppelbuchung), eine Konfidenz-Schwelle 0.85. **40 Belege produktiv erfasst** (09.06.–27.07., CHF 2'198.87, geprüft). Dazu «Speicher aufräumen» in den Einstellungen (RPC `verwaiste_belege`, Migration 151) — 215 Waisen gelöscht; Versionsanzeige auf der Startseite; Spesen-Zähler auf der Kachel. **(2) camt-Abgleich v0.54.10–v0.54.14**: Manuell-Fälle ohne Zahlung verschwinden, Mehrfachzuordnung derselben Forderung verhindert (frische DB-Prüfung), Minderzahlung rot und richtig benannt (Fall Sartons), Warnung wenn die Rechnung jünger ist als die Zahlung (Fall Marsöl), **Zahlungen paarweise zu Forderungen** (neueste zu neuester, `zahlung_paarung.dart`) — jede Rechnung trägt Datum und camt-Schlüssel *ihrer* Zahlung. 560 Tests grün. **(3) Buchhaltungs-Datenarbeit (keine App-Änderung)**: Excel-Delta-Import (220 Zahlungseingänge, Bank per 11.03. exakt 3'322.26 = E-Banking), **147 Rechnungen aus der Excel-Quelle** (Sheet Reinigung, Spalte Einzahlungsdatum) auf bezahlt gesetzt — ein erster Ansatz über Betragsbilanzen hätte ~100 falsch geschlossen; **Mischbetriebe entwirrt** (708 Reinigungen + 456 Rechnungen an den richtigen Betrieb, 28 erloschene Häuser als geschlossene Betriebe angelegt, 9 Duplikate/Dubletten beseitigt), 464 Anlagenbezüge und 363 QR-Referenzen nachgetragen, `heineken_nr` normalisiert. Schlussprüfung gegen das Excel: 6'509 Reinigungen bestätigt, **0 falsch**; Bank/Debitoren/Kasse unverändert. Alle Eingriffe einzeln rückgängig machbar (`Datenbank/wartung/rollback_*.sql`). **Abends nach Daniels Stichprobe zwei weitere Import-Fehler vom 19.06. gefunden und behoben:** (a) die **Hahn-Zuschläge** fehlten bei allen 7'786 importierten Reinigungen — für 2025 war der Betrag dadurch nur der Grundtarif (858 Stück, CHF 8'542 zu niedrig; Fall Lindemann's 21.11.2025: 74.60 statt 113.50), korrigiert über die Excel-Mengen inkl. MwSt-Wechsel 7.7→8.1 % per 01.01.2024 — **Netto stimmt jetzt bei allen 7'116 mit dem Excel**; (b) **222 „Zusätzliche Anlage"-Zeilen** waren als eigene Reinigung angelegt und hatten über den Preis-Trigger CHF 16'572 Scheinumsatz erhalten — 203 mit der Hauptreinigung zusammengeführt (Anlage wandert in `anlage_ids`), 18 auf 0.00 gesetzt (werden beim anderen Betrieb verrechnet). Rechnungen und Buchhaltung blieben unberührt. **v0.54.15/16:** camt-Abgleich nur noch mit Forderungen bis ein Jahr zurück (`abgleich_fenster.dart`), ältere im Zuordnungs-Dialog zuschaltbar. Details `ToDo.md`.
> Zuletzt (26.07.2026 abends): **Heineken-Fixes + Event-PDF** (v0.53.1–v0.53.3, alle von Daniel bestätigt): **v0.53.1** Monatsrechnungs-PDF öffnet immer mit frischer Signed-URL (gespeicherte lief nach 1 h ab → «PDF lässt sich nicht mehr öffnen»). **v0.53.2** Störungsrapport kreuzte das falsche System an — die B/D/K/H/O-Kreuze kamen aus den Störungs-BEREICHEN (1=Zapfhahn…5=Gas) statt aus `anlage_typ` (Centro Trun/Clubhotel/Stadtcafé); dazu Menüpunkt «PDF neu generieren» im Monatsrechnungs-Detail — Juni-Rechnung korrigiert regeneriert. **v0.53.3** Event-Abschluss-PDF: Vorschau im neuen Tab (Blob-URL statt Druckdialog, neuer Helfer `pdf_tab_oeffner`), Kategorien als unteilbare Blöcke (kein Umbruch mitten in Pikett-Einsätzen; >20 Zeilen bleiben teilbar). Details `ToDo.md`.
> Zuvor (22.–26.07.2026): **Google-Kontakte-Sync + Aufgaben-Erinnerungen** (v0.52.0–v0.53.0, beide Abnahmen bestanden): **Kontakte-Sync** — App-Kontakte + operative Betriebe landen via People API im Google-Adressbuch (Label «SBS App», `clientData.sbs_id`-Schutzregel, Reconcile-Edge-Function `google-contacts-sync`, entprellter Auto-Sync nach Kontakt-/Betrieb-Speichern, Contact Picker in beiden Formularen mit +41-Nummern-Normalisierung v0.52.1) → Anrufer-Erkennung auf dem Pixel; alter nativer flutter_contacts-Sync komplett entfernt (Migrationen 148/149). Dazu v0.52.2 (Standard-Checkbox im Abschluss-Dialog nur bei Abweichung) und v0.52.3 (Bald-fällig default sichtbar — Planungsdatum wirkt im Tourenplan, 32 unsichtbare Anlagen). **Aufgaben-Erinnerungen v0.53.0** — Dashboard-Karte + globale Glocke bis erledigt: 4 frische Detektoren (Heineken-Monatsrechnung zweistufig, MWST alle offenen der letzten 4 Quartale mit Fristen, Mahnlauf via ForderungService, Saisondaten) + eigene Aufgaben, Snooze 1/3/7, MWST-Marker im Screen (Migration 150, 22 Detektor-Tests, subagenten-getrieben mit 3 substanziellen Review-Fixes). Details `ToDo.md`.
> Zuvor (21.07.2026): **Muloin-Fix + DB-Sicherheit** (v0.51.2, Migrationen 145–147): Eröffnungs-Hinweis feuerte fälschlich, wenn die Endreinigung selbst in der Pause lag (Muloin: 30.06. in den Ferien 26.06.–27.07.) — Regel jetzt wörtlich: jede Pausen-Reinigung unterdrückt Hinweis + Auto-Termin, Uhr ab Wiedereröffnung (Muloin fällig 25.08.); TDD, 447 Tests grün, deployed. Danach Supabase-Sicherheitsmail abgearbeitet: **145** RLS auf den 11 `_bak_*`-Tabellen (waren via Anon-Key lesbar!), **146** alle 8 Views auf `security_invoker` (umgingen RLS; anon sah z. B. offene Rechnungen — verifiziert jetzt 0 Zeilen, eingeloggt unverändert), **147** alle Backup-Tabellen gelöscht (OK Daniel). Security-Advisor ohne ERROR. Zudem 100 Betriebe ohne Region gesichtet (2 aktive Events, 97 geschlossene Alt-Daten). Details `ToDo.md`.
> Zuvor (17.–20.07.2026): **Fälligkeit ab Saisonstart** (v0.51.0/v0.51.1): Tgantieni-Fall — 17 Saison-Kunden waren bis 78 Tage wieder offen, ohne im Tourenplan zu erscheinen (ewiges `eroeffnungFaellig` + Filter-Default + Auto-Termin nur am Eröffnungstag). Regel Daniel: **Uhr-Anker = Wiedereröffnung** (`faelligkeitsAnker`, TDD), Eröffnungs-Hinweis nur noch 7 Tage vor Start, **Warnleiste „Saisondaten fehlen"** im Tourenplan (zeigt aktuell 15 Winter-Betriebe ohne eingetragenen nächsten Winterstart), Filter-Default inkl. Eröffnung/Endreinigung, Saisonpause-Betriebe mitgemeldet. Furt Wangs nachgetragen (Anlage demontiert → Betrieb inaktiv). Details `ToDo.md`.
> Zuvor (15.–17.07.2026): **Zahlungsart pro Reinigung** (v0.50.0) — **Ursache der 38 fehlenden Rechnungen GELÖST** (Hinweis Daniel: Zahlungsart-Umstellungen; 34× Betrieb war noch `heineken`, 4× veralteter Formular-Cache): `reinigungen.zahlungsart` wird beim Abschluss fixiert (Migration 144) und ist via `resolveZahlungsart` allein massgebend für Buchung/Rechnung/Versand; Abschluss-Dialog mit frischem Betrieb, Standard-Checkbox, Klartext, Rechnungs-E-Mail-Erfassung (Versand NUR via Rechnungsadresse); QR-Tab mit SCOR-Referenz; Warnung „Reinigungen ohne Rechnung" (v0.49.0) mit Kasse-Ausschluss + ohne-Buchung-Check; **Migration 143** (Rechnungsbetrag kommt vom Positions-Trigger → dort 5-Rappen-Rundung, heineken_monat ungerundet); 38 Rechnungen (CHF 3'656.05) nachfakturiert; Tresen-Rechnung im Detail nacherstellbar (v0.49.1); Versionsanzeige `kAppVersion` im Forderungen-Titel. Live-Test 17.07. im Echtbetrieb bestanden (10/10 DB-verifiziert). Details `ToDo.md`.
> Zuvor (15.07.2026): **Material abgeholt → Bestände in einem Klick** (v0.47.0): neue **Bestellungen-Liste** `/materialien/bestellungen` (schliesst die Lücke, dass gesendete Bestellungen + PDFs bisher unauffindbar waren) mit „Material abgeholt" → Kontroll-Dialog (nach Kategorie gruppiert, Mengen vorbefüllt/korrigierbar, Freitext-Positionen ausgegraut) → Bestände buchen, plus „Buchung rückgängig". **Migration 141**: Status `abgeholt`, `abgeholt_am`, `menge_erhalten` + zwei **atomare RPCs** (relatives `bestand_aktuell + delta`, `FOR UPDATE`-Guard gegen Doppelbuchung). Restmengen laufen über `bestand_niedrig` automatisch auf die nächste Bestellliste — keine Teillieferungs-Verfolgung. Subagenten-getrieben, 400 Tests grün. Live-Test durch Daniel offen. Details `ToDo.md`.
> Zuvor (14.07.2026): **camt-Kundenzahlungs-Abgleich überarbeitet** (v0.46.21–v0.46.26): Matcher-Härtung (Auto nur bei Referenz/exaktem Namen/gelerntem Alias, unscharf → manuell), Vermerk-Parser (Rechnungsnummer + Davos-Klosters-Betriebnummer via `heineken_nr`, nur Vorauswahl), mehr Zahlungs-Infos + PDF-/Beleg-Links, „Nicht zugeordnet" nach Einzahler gruppiert + Mehrfach-Zuordnungs-Dialog. **Migration 139** (Preis-Trigger auf 5-Rappen-Rundung + Backfill Live-Periode) + **Migration 140** (`beleg_typ='camt053'`). camt-Test-Buchungen am Abend vollständig zurückgerollt (Baseline). Re-Test morgen. Details `ToDo.md`.
> Zuletzt (10.07.2026): **Events-Modul Phase E5** (v0.21.0) — **Events-Modul E1–E5 komplett**: **Abschluss-Mail** nach dem Event. Menüpunkt „Abschluss-Mail senden" → **PDF-Abschlussbericht** (ohne CHF: Zusammenfassung, Stände/Inbetriebnahme, Zeit & Aufwand nach Kategorie, Pikett-Einsätze) + **Empfänger-Sheet** (Eventverantwortlicher + RSL automatisch vorgeschlagen, freie Mail hinzufügbar, kommaseparierter Versand via `send-pdf-mail`). MailConfig-Bereich `event` (`eventScharf=false` → Testmodus). Keine DB-Migration. Scharfstellen (`eventScharf=true`) nach Handy-Testversand.
> Zuvor (10.07.2026): **Events-Modul Phase E4** (v0.20.0): Event-Detail auf **5 Tabs** (Kontakte | Stände | Einsätze | **Zeit** | Dokumente). **Zeit-/Spesenerfassung** (neue Sync-Vertikale `event_aufwand`, Migration 123): Zeilen mit Datum/Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen)/Notiz/Stunden, Total-Chip. **Auto-Montage-Generierung**: „Montage generieren" aggregiert pro Eventtag (≤5 Slots) und öffnet das Montage-Formular (Typ Anlass, Veranstaltungs-Betrieb) vorbefüllt → normaler Heineken-Abrechnungsfluss. Spesen als zusätzliche Stunden. Nächste Phase E5 (Abschluss-Mail Einsatzliste + Zeiten/Spesen als PDF).
> Zuvor (10.07.2026): **Events-Modul Phase E3** (v0.19.0): Event-Detail auf **4 Tabs** (Kontakte | Stände | Einsätze | Dokumente). **Inbetriebnahme pro Anlage** (Live-Checkbox + Fortschritt-Chip, id-basierter Stand-Save). **GPS-Standort pro Stand** (geolocator). **Karten-Umschalter im Stände-Tab** mit swisstopo-Luftbild (flutter_map, kein API-Key), Marker pro Stand. **Pikett-Einsätze** (neuer Tab, minimales Formular; Migration 122 `event_einsaetze` + Stand-lat/lng + Anlage-in_betrieb). Nächste Phase E4 (Abschluss-Mail Einsatzliste als PDF).
> Zuvor (10.07.2026): **Events-Modul Phase E2** (v0.18.0): Event-Detail auf 3 Tabs (Kontakte | Stände | Dokumente). **Stände** mit Schankanlagen (OT/Hollandbuffet/Ausschankwagen), dynamisches Stand-Formular, Vorjahres-Übernahme. **Dokument-Ablage** (PDF-Upload in Storage-Bucket `event-dokumente`, ansehen/löschen; Migration 120).
> **Events-Modul Phase E1** (v0.17.0): neue Dashboard-Kachel «Events» mit Event-Jahren (Migration 119: `events` + `event_kontakte`), Kontaktliste pro Event-Jahr mit Rollen (Eventverantwortlicher/RSL/OK/Bau/Stand/…), Vorjahres-Übernahme, WhatsApp-/Anruf-Buttons; Abrechnung bleibt bei Montage «Anlass». Phasen E2–E4 (Lageplan/Stände, GPS-Karte + Einsätze, Abschluss-Mail) geplant — siehe ToDo.md. Zudem build_runner-Fix (null-aware Elements ersetzt, Lint deaktiviert).
> 07.07.2026: **App-Optimierung Paket 06 – P1 Quick-Wins** (v0.16.20): Eigenaufträge-Filter entfernt, Störungen-Filter auf Anlagentyp + Km-Abrechnung, Reinigung-UI (Chip „Protokoll", Service-Art, kompakte Zeiterfassung), Kontakt-Rolle „Stardrinks" (Migration 117), **Betriebsferien 3 → 5 Slots** (Migration 118, dynamisches Formular, zentraler Ferien-Util + Bugfix „nur Ferien 1 geprüft"). P2–P9 aus Paket 06 offen (siehe ToDo.md).
> Juni 2026: Buchhaltung-Voll-Migration 2019–2025, camt-Import, Forderungs-Hub, **Eingangsrechnungen TP-0…7 komplett** (Scan→KI/QR→Lernen→Kreditoren-Buchung→GKB-Zahlungsfile pain.001→camt-Kreditor-Abschluss→Reversibilität→Datenhygiene). **Eingangsrechnung-Kategorien** (15 KI-inhaltsbasierte Kategorien, löst Bussen-Erkennung kanton-unabhängig, v0.16.18). **camt-Screens in „Bankauszug Import" zusammengeführt** (4 Tabs Import·Prüfliste·Regeln·Dateien, Dashboard auf eine Kachel reduziert, v0.16.19). Alter camt-Abgleich-Screen entfernt (v0.16.17).

---

## 📊 PROJEKT-STATUS

### Aktueller Stand: **Phase 4 - Polish & Testing** 📅

| Phase | Status | Fortschritt | Fertig am |
|-------|--------|-------------|-----------|
| **Phase 0: Planung & Analyse** | ✅ Abgeschlossen | 100% | 12.02.2026 |
| **Phase 1: Setup & Grundlagen** | ✅ Abgeschlossen | 100% | 20.02.2026 |
| **Phase 2: Core Features (MVP)** | ✅ Abgeschlossen | 100% | 14.03.2026 |
| **Phase 3: Administration** | ✅ Abgeschlossen | 100% | 15.03.2026 |
| **Phase 3b: Buchhaltung-Erweiterung** | ✅ Abgeschlossen | 100% | 31.03.2026 |
| **Phase 4: Polish & Testing** | 🔄 In Arbeit | 30% | - |
| **Phase 5: Deployment & Launch** | 🔄 Vorgezogen | 20% | - |

---

## ✅ ERLEDIGTE ARBEITSPAKETE

### 1. Geschäftsanalyse & Dokumentation

#### ✅ Geschäftsbeschreibung
- **Datei**: `Prompts/02_Geschäftsbeschreibung.md`
- **Status**: Komplett ausgefüllt
- **Inhalt**:
  - Firmendetails (One-man operation, Heineken-Franchise)
  - 250 Kunden, 4-Wochen-Rhythmus
  - Budget: 200 CHF/Monat max
  - Ziel: 80% Zeitersparnis bei Administration

#### ✅ Excel-Analyse
- **Datei**: `Datenanalyse/01_Excel_Analyse_Zusammenfassung.md`
- **Status**: Vollständige Analyse von 37 Excel-Sheets
- **Key Findings**:
  - 4,144 Reinigungen (Hauptgeschäft)
  - 1,029 Störungen
  - 1,203 Montagen
  - Komplettes ERP-System in Excel

#### ✅ Heineken Monatsrechnungen
- **Datei**: `Datenanalyse/02_Heineken_Monatsrechnungen_Analyse.md`
- **Status**: 3 Monate analysiert (Okt-Dez 2025)
- **Key Findings**:
  - 8 Abrechnungskategorien
  - Q4 2025: 20,593 CHF an Heineken
  - 5 Störungsbereiche identifiziert

#### ✅ Reinigungsprotokolle
- **Datei**: `Datenanalyse/03_Reinigungsprotokolle_Analyse.md`
- **Status**: 4 PDFs analysiert
- **Key Findings**:
  - 17-Punkt-Checkliste dokumentiert
  - Zeitersparnis: 25 Min → 4 Min pro Service
  - Potenzial: 1,450 Stunden/Jahr sparen

#### ✅ Störungsbereiche
- **Datei**: `Datenanalyse/04_Störungsbereiche_Analyse.md`
- **Status**: Heineken-Diagramm analysiert
- **Key Findings**:
  - 5 technische Bereiche mit unterschiedlichen Preisen
  - Bereich 3 (Kühlsystem) = 40% aller Störungen

#### ✅ Preisliste Heineken
- **Datei**: `Datenanalyse/05_Preisliste_Heineken_Analyse.md`
- **Status**: Offizielle Preisliste analysiert
- **Key Findings**:
  - Alle Preise excl. MWST (8.1%)
  - Bergkunden vs. Normalkunden-Unterscheidung

#### ✅ Preissystem Final
- **Datei**: `Datenanalyse/06_Preissystem_Final.md`
- **Status**: Alle Preisregeln geklärt
- **Key Findings**:
  - Pikett = 160 CHF (2 Tage)
  - Bergkunden zahlen ~2.4× mehr
  - Ersatzteile immer kostenlos für Kunden

#### ✅ Geschäftsabläufe
- **Datei**: `Prompts/03_Geschäftsabläufe.md`
- **Status**: Vollständig dokumentiert (9 Abschnitte)
- **Inhalt**:
  1. Tourenplanung (Tour von vor 1 Monat)
  2. Service-Durchführung beim Kunden
  3. Fahrt zwischen Kunden
  4. Ende des Tages/Woche
  5. Störungen (flexibel dazwischengeschoben)
  6. Montagen
  7. Pikett-Dienst (1 Wochenende/Monat)
  8. Eröffnungen/Endreinigungen
  9. Top 5 Zeitfresser/Frustrationen

**Wichtigste Erkenntnisse:**
- Betrieb → Anlage (1:n) ist KRITISCH
- Offline-Fähigkeit MUSS funktionieren
- Administration = größter Zeitfresser (5-10h/Woche)
- Materialverwaltung im Auto = kritisches Feature
- Zeitersparnis-Potenzial: 6-8 Stunden/Woche

---

### 2. Technische Architektur

#### ✅ Tech-Stack-Analyse
- **Datei**: `Architektur/01_Tech_Stack_Analyse.md`
- **Status**: 4 Optionen verglichen, Entscheidung getroffen
- **Entscheidung**: **Flutter + Supabase** (56/60 Punkte)
- **Begründung**:
  - Beste Offline-Fähigkeit
  - Eine Codebase (Web + iOS + Android)
  - PostgreSQL perfekt für Betrieb→Anlage
  - Kosten: 0-23 CHF/Monat (weit unter Budget)
  - Multi-Tenant-ready

#### ✅ Datenmodell (Finalisiert & Live)
- **Datei**: `Architektur/02_Datenmodell.md`
- **Status**: Finalisiert und in Supabase ausgeführt (17.02.2026)
- **Inhalt**:
  - 24 Tabellen live in Supabase
  - 24 RLS Policies aktiv
  - 20 Trigger/Functions aktiv
  - 7 Views erstellt
  - Seed-Daten: 11 Regionen, 20 Kategorien, 43 Konten, 74 Buchungsvorlagen, 883 Artikel
- **DB-Zugriff**: Direkter Zugriff via Python (`Datenbank/db_query.py`)

---

## 📋 OFFENE ARBEITSPAKETE

### Phase 1: Setup & Grundlagen (Woche 1-2)

| Aufgabe | Status | Priorität | Abhängigkeiten |
|---------|--------|-----------|----------------|
| ✅ Supabase Account | Vorhanden | - | - |
| ✅ GitHub Account | Vorhanden | - | - |
| ✅ Datenmodell finalisieren | Abgeschlossen | 🔴 Hoch | 12.02.2026 |
| ✅ Supabase Projekt Setup | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Migration Scripts ausführen | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ DB-Direktzugriff (Python) | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Flutter Projekt initialisieren | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Packages installieren (25+) | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Projekt-Struktur aufsetzen | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Supabase Client konfigurieren | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Isar DB einrichten (13 Collections) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Sync-Service (komplett, 12 Entitäten) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ ConnectivityService (Online/Offline) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ 12 Mapper + 4 Repositories + 3 Providers | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| 🔄 Authentication (Login ✅, Provider ausstehend) | Teilweise | 🔴 Hoch | 17.02.2026 |
| ✅ Navigation (GoRouter, 16 Routes + Auth-Guard) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Design System / Theme (Material 3, AppColors) | Abgeschlossen | 🟡 Mittel | 20.02.2026 |

### Phase 2: Core Features (MVP) (Woche 3-8)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Datenmodell in Code (24 DTOs + 13 Isar) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Offline-Sync-Logik (12 Entitäten) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Authentication (Supabase Auth) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Betriebe CRUD (Liste, Detail, Form, Providers) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Betrieb MVP (Kontakte, Rechnungsadresse, Form-Erweiterungen) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Anlagen CRUD (Liste, Detail, Form, Providers, Bierleitungen) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Anlagen MVP (Dropdown-Fixes, Bierleitung CRUD, Gas-Validierung) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Reinigungen CRUD (Liste, Detail, Form, Providers, Service-Flow) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Störungen CRUD (Liste, Detail, Form, Providers, Störungsnummer) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Web-Deployment (GitHub Pages) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Android APK (Emulator getestet) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Isar Extension Bug Fix + Repository Refactoring | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Tourenplanung (Basis) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Service-Protokoll (Unterschriften, Fotos, Preis) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Unterschriften-Funktion | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Foto-Upload | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Preis-Kalkulator | Abgeschlossen | 🟡 Mittel | 11.03.2026 |
| ✅ Reinigungsprotokoll-PDF (Heineken FOR 1220) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |

### Phase 3: Administration (Woche 9-12)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Kundenrechnung-Generierung (PDF + QR-Einzahlungsschein) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |
| ✅ Materialverwaltung (CRUD, Bestellliste, Material-Picker) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |
| ✅ Störungs-Management (Entkopplung, Vereinfachung, MwSt-Entfernung) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Montage-Management (CRUD, Betrieb-Autocomplete, Material) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Pikett-Dienste (CRUD, Pauschale 80 CHF) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Eigenaufträge (CRUD, 30 CHF Pauschale, Material) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Eröffnungsreinigungen (CRUD, Bergkunde auto-detect, Preise aus DB) | Abgeschlossen | 🔴 Hoch | 14.03.2026 |
| ✅ Betrieb-Verbesserungen (Ferien, Ruhetage, Saison→Datum) | Abgeschlossen | 🟡 Mittel | 14.03.2026 |
| ✅ Heineken Monatsrechnung (8 Kategorien, Combined PDF) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |
| ✅ Heineken PDF-Formulare (6 Rapport-Typen als Beilagen) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |
| ✅ Mahnwesen (Überfällige Rechnungen, Mahnstufen 0-3) | Abgeschlossen | 🟡 Mittel | 15.03.2026 |
| ✅ Buchhaltung komplett (Dashboard, Kontenplan, Journal, Buchungen, Berichte) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |

### Phase 3b: Buchhaltung-Erweiterung (KW 13-14)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Spesen-Scanner OCR (Claude Haiku, Edge Function, Kamera-direkt) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Vorsteuer-Buchungen (separate MwSt auf Konto 1171) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Mischkauf-Handling (Essen + Benzin auf einem Beleg) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ TWINT/Karte Zahlungsweg-Erkennung (auto aus Beleg) | Abgeschlossen | 🟡 Mittel | 31.03.2026 |
| ✅ camt.053 Bankimport (XML-Parser, Duplikat-Erkennung) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Beleg-Viewer (url_launcher, Signed URL) | Abgeschlossen | 🟡 Mittel | 31.03.2026 |
| ✅ Provider-Invalidation (Kontenplan/Journal live-update) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Termine CRUD (Kalender, Betrieb-Zuordnung) | Abgeschlossen | 🟡 Mittel | 31.03.2026 |

### Phase 4: Polish & Testing (Woche 13-16)

| Aufgabe | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 🔄 UI/UX Verbesserungen | In Arbeit | 🟡 Mittel | 5 Tage |
| 📅 Offline-Sync Testing | Ausstehend | 🔴 Hoch | 3 Tage |
| 📅 Performance-Optimierung | Ausstehend | 🟡 Mittel | 3 Tage |
| 🔄 Beta-Testing mit Daniel | In Arbeit | 🔴 Hoch | 5 Tage |
| 🔄 Bug-Fixes | In Arbeit | 🔴 Hoch | 5 Tage |

### Phase 5: Deployment & Launch (Woche 17-18)

| Aufgabe | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 📅 App Store Submission (iOS) | Ausstehend | 🔴 Hoch | 2 Tage |
| 📅 Google Play Submission (Android) | Ausstehend | 🔴 Hoch | 2 Tage |
| ✅ Web Deployment (GitHub Pages) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| 📅 Dokumentation (Benutzerhandbuch) | Ausstehend | 🟡 Mittel | 2 Tage |
| 📅 Training für Daniel | Ausstehend | 🔴 Hoch | 1 Tag |
| 📅 Excel-Daten-Migration | Ausstehend | 🟡 Mittel | 2 Tage |

---

## 🎯 MVP FEATURES (Must-Have für Launch)

| Feature | Beschreibung | Status |
|---------|--------------|--------|
| **Betriebe & Anlagen** | CRUD, Suche, Filter | ✅ Erledigt |
| **Tourenplanung** | Tour von vor 1 Monat, Drag & Drop | ✅ Erledigt |
| **Service-Protokoll** | 17-Punkt-Checkliste + PDF | ✅ Erledigt |
| **Unterschriften** | Digital auf Smartphone | ✅ Erledigt |
| **Fotos** | Probleme dokumentieren | ✅ Erledigt |
| **Offline-Sync** | Funktioniert ohne Internet | ✅ Erledigt |
| **Rechnungen** | PDF mit QR-Einzahlungsschein | ✅ Erledigt |
| **Materialverwaltung** | Bestand tracken, Bestellliste | ✅ Erledigt |
| **Störungen** | Mit Störungsnummer, flexibel | ✅ Erledigt |
| **Montagen** | Zeiterfassung, 80 CHF/h | ✅ Erledigt |
| **Pikett** | Pauschale 80 CHF, Datum | ✅ Erledigt |
| **Eigenaufträge** | 30 CHF Pauschale, Material | ✅ Erledigt |
| **Eröffnungsreinigungen** | Bergkunde auto-detect, 60/135 CHF | ✅ Erledigt |
| **Spesen-Scanner (OCR)** | Beleg fotografieren → automatische Buchung | ✅ Erledigt |
| **Bankimport (camt.053)** | XML-Import, Duplikat-Erkennung | ✅ Erledigt |
| **Vorsteuer-Buchungen** | Separate MwSt-Einträge auf Konto 1171 | ✅ Erledigt |
| **Termine** | Kalender, CRUD, Betrieb-Zuordnung | ✅ Erledigt |

**Geschätzte MVP-Entwicklungszeit**: 12-16 Wochen

---

## 🔮 POST-MVP FEATURES (Nice-to-Have)

| Feature | Beschreibung | Priorität |
|---------|--------------|-----------|
| **Mahnwesen** | Automatische Mahnungen | 🟡 Mittel |
| **Internet-Abgleich** | Google Business API für Öffnungszeiten | 🟢 Niedrig |
| **GPS-Tracking** | Automatische Fahrzeiten | 🟢 Niedrig |
| **Routenoptimierung** | Optimale Reihenfolge vorschlagen | 🟡 Mittel |
| **Statistiken** | Dashboard mit KPIs | 🟡 Mittel |
| **Multi-User** | Für Franchise-Partner | 🟡 Mittel |
| **Push-Notifications** | Erinnerungen, Pikett-Benachrichtigungen | 🟢 Niedrig |

---

## 📁 DOKUMENTE-ÜBERSICHT

### Projektbeschreibung
- `Prompts/01_Projektansatz.md` - Initialer Projektansatz
- `Prompts/02_Geschäftsbeschreibung.md` - Ausgefüllte Geschäftsbeschreibung
- `Prompts/03_Geschäftsabläufe.md` - Detaillierte Workflow-Dokumentation

### Datenanalyse
- `Datenanalyse/01_Excel_Analyse_Zusammenfassung.md`
- `Datenanalyse/02_Heineken_Monatsrechnungen_Analyse.md`
- `Datenanalyse/03_Reinigungsprotokolle_Analyse.md`
- `Datenanalyse/04_Störungsbereiche_Analyse.md`
- `Datenanalyse/05_Preisliste_Heineken_Analyse.md`
- `Datenanalyse/06_Preissystem_Final.md`

### Architektur
- `Architektur/01_Tech_Stack_Analyse.md` - Tech-Stack-Entscheidung
- `Architektur/02_Datenmodell.md` - PostgreSQL-Schema (In Review)
- `Architektur/03_Roadmap.md` - Detaillierter Zeitplan

### Projekt-Management
- `00_Projekt_Uebersicht.md` - **Diese Datei** (Dashboard)

---

## 💰 BUDGET-ÜBERSICHT

### Entwicklungskosten
- **Self-Development**: 0 CHF (Daniel entwickelt mit Claude)

### Betriebskosten (Monatlich)

| Jahr | Monat | Details |
|------|-------|---------|
| **Ab 20.02.2026** | **23 CHF** | Supabase Pro (25 USD ≈ 23 CHF) |

### Einmalige Kosten

| Posten | Kosten | Wann |
|--------|--------|------|
| Apple Developer Account | 99 USD (~90 CHF) | Jahr 1 |
| Google Play Developer | 25 USD (~23 CHF) | Jahr 1 (einmalig) |
| **Total einmalig** | **~113 CHF** | |

**→ Weit unter Budget von 200 CHF/Monat!**

---

## 📊 ZEITERSPARNIS-POTENZIAL

### Aktueller Zeitaufwand (pro Woche)

| Aufgabe | Aktuell | Mit App | Ersparnis |
|---------|---------|---------|-----------|
| Protokolle digitalisieren | 2-3h | 0h | 2-3h |
| Rechnungen erstellen | 2-3h | 0.5h | 1.5-2.5h |
| Excel-Eingabe | 1-2h | 0h | 1-2h |
| Materialnachbestellung | 0.5h | 0.1h | 0.4h |
| Papierkram pro Service (21 Min × 40 Services/Woche) | 14h | 2.7h | 11.3h |
| **TOTAL pro Woche** | **19.5-20.5h** | **3.3h** | **16.2-17.2h** |

**Jährliche Zeitersparnis**: ~840 Stunden = **105 Arbeitstage!**

**ROI**: Bei 80 CHF/h Stundensatz = **67,200 CHF/Jahr gespart**

---

## 🚀 NÄCHSTE SCHRITTE

### Erledigt am 17.02.2026
1. ✅ Supabase DB komplett live (24 Tabellen, alle Seeds)
2. ✅ Direkter DB-Zugriff via Python eingerichtet
3. ✅ Flutter 3.41.1 + Android Studio installiert
4. ✅ Flutter Projekt erstellt (`sbs_projer_app`)
5. ✅ 25+ Packages installiert & konfiguriert
6. ✅ Projekt-Struktur (Clean Architecture) aufgesetzt
7. ✅ Supabase Client konfiguriert & getestet
8. ✅ Login Screen – funktioniert mit Supabase Auth
9. ✅ GoRouter mit Auth-Guard
10. ✅ Isar Core-Collections (Betrieb, Anlage, Region, Reinigung)
11. ✅ Supabase DTOs (Betrieb, Anlage, Region)

### Erledigt am 20.02.2026
12. ✅ Alle 24 Supabase DTOs erstellt (fromJson/toJson)
13. ✅ Alle 12 Isar Local-Models + SyncMetaLocal (13 Collections total)
14. ✅ `@Index()` auf serverId + isSynced für alle 12 Local-Models
15. ✅ 12 Mapper-Klassen (Local ↔ DTO Konvertierung)
16. ✅ ConnectivityService (Online/Offline-Erkennung, Stream)
17. ✅ SyncService (~580 Zeilen, Push/Pull für alle 12 Entitäten)
    - Push: isSynced=false → Supabase upsert
    - Pull: Incremental (updated_at > lastPullAt), Bierleitung: Full-Pull
    - Konflikt: Last Write Wins (Timestamp-Vergleich)
    - Auto-Sync bei Connectivity-Change
    - Tier-basierte Sync-Reihenfolge (FK-Abhängigkeiten)
18. ✅ 4 Core-Repositories (Region, Betrieb, Anlage, Reinigung)
19. ✅ 3 Riverpod Providers (Connectivity, Sync, Betrieb)
20. ✅ Login-Integration (SyncService startet nach Login)
21. ✅ `flutter analyze` – 0 eigene Issues
22. ✅ Design System (AppColors, AppTheme.light, Material 3)
23. ✅ Dashboard / Home Screen (Kacheln mit Live-Counts, Sync-Banner, Menü)
24. ✅ Betriebe CRUD (Liste mit Suche/Filter, Detail mit Sektionen, Form)
25. ✅ Betrieb-Provider (Stream, List, Count)
26. ✅ Anlagen CRUD (Liste, Detail mit Bierleitungen, Form)
27. ✅ Anlagen-Provider (Stream, List, Count, byBetrieb Family)
28. ✅ BierleitungRepository (CRUD + watchByAnlage)
29. ✅ Betrieb-Detail mit Anlagen-Sektion (Stream, "Neue Anlage"-Button)
30. ✅ GoRouter: 12 Routes (Login, Home, 4× Betriebe, 4× Anlagen, 4× Reinigungen)
31. ✅ Supabase auf Pro-Plan upgraded
32. ✅ Reinigungen CRUD (Liste mit Suche/Status-Filter, Detail mit Checkliste+Progress-Ring, Form mit Service-Flow)
33. ✅ Reinigung-Provider (Stream, List, Count, byAnlage, byBetrieb)
34. ✅ Reinigungen in Anlage-Detail (Sektion mit Stream, "Neue Reinigung"-Button)
35. ✅ Service-Flow: 4 Anlagen-Checks + 12 Service-Punkte + Zeiterfassung + Abschliessen
36. ✅ Störungen CRUD (Liste mit Suche/Status-Filter, Detail mit Bereich 1-5/Preis/Material, Form mit Pikett/Bergkunde)
37. ✅ Störung-Provider (Stream, List, Count, byAnlage, byBetrieb)
38. ✅ Störungen in Anlage-Detail (Sektion mit Stream, "Neue Störung"-Button)
39. ✅ Störungsnummer-Generator (STR-YYYYMM-NNN)
40. ✅ GoRouter: 16 Routes (Login, Home, 4× Betriebe, 4× Anlagen, 4× Reinigungen, 4× Störungen)
41. ✅ Navigation: context.go() → context.push() (27 Stellen, Back-Buttons überall)
42. ✅ Windows Desktop Build (Visual Studio C++, Developer Mode)

### Erledigt am 07.03.2026
43. ✅ Web-Deployment auf GitHub Pages (Conditional Exports, kIsWeb-Branching)
44. ✅ Alle 6 Repositories mit Web-Support (Supabase direkt auf Web, Isar auf Native)
45. ✅ `routeId` Getter auf allen Local Models (Web: serverId, Native: id)
46. ✅ String-basierte IDs im Router und allen 12 Screens
47. ✅ Web-Stubs für Isar Models (`*_local_web.dart`)
48. ✅ Web-Shortcuts für Connectivity/Sync Provider
49. ✅ Android APK Build + Emulator-Test (Sync funktioniert)
50. ✅ Isar Extension Bug behoben (Extensions funktionieren nicht auf `dynamic`)
51. ✅ IsarService mit typed Query Methods (alle Isar-Queries zentral gewrappt)
52. ✅ 6 Repositories auf `IsarService.xxxMethod()` Pattern refactored
53. ✅ Web-Build + Native-Build beide fehlerfrei (`flutter analyze`)
54. ✅ Betrieb-Formular erweitert (Heineken-Nr → Betrieb Nr, Rechnungsstellung-Dropdown, Saison-Details, Region-Dropdown)
55. ✅ DB Migration 008 (betrieb_nr, rechnungsstellung Enum, saison_start/ende)
56. ✅ BetriebKontakt CRUD komplett (Repository, Form-Screen, Detail-Section, Web-Stubs, Sync)
57. ✅ BetriebRechnungsadresse CRUD komplett (Isar Model, Mapper, Repository, Form-Screen, Detail-Section, Web-Stubs, Sync)
58. ✅ 8 Repositories (+ BetriebKontakt, BetriebRechnungsadresse)
59. ✅ 19 Routes im GoRouter (+ Kontakt-Create/Edit, Rechnungsadresse)
60. ✅ Betrieb MVP abgeschlossen
61. ✅ Anlage-Formular: Vorkühler-Dropdown korrigiert ('nass'/'trocken' → DB-Werte 'Fasskühler'/'Kühlzelle'/'Buffet')
62. ✅ Anlage-Formular: Durchlaufkühler Freitext → Dropdown (9 DB-Optionen)
63. ✅ Anlage-Formular: Säulen-Typ Freitext → Dropdown (14 DB-Optionen)
64. ✅ Anlage-Formular: Gas-Typ 1/2 Freitext → Dropdown (3 DB-Optionen) + Cross-Validierung
65. ✅ Anlage-Formular: Reinigung-Rhythmus korrigiert (8 korrekte DB-Optionen)
66. ✅ Anlage-Formular: Status 'stillgelegt' hinzugefügt
67. ✅ Anlage-Detail: Vorkühler-Label Fix
68. ✅ Bierleitung CRUD komplett (Form-Screen, Auto-Nummer, Add/Edit/Delete im Detail)
69. ✅ 21 Routes im GoRouter (+ Bierleitung-Create/Edit)
70. ✅ Anlagen MVP abgeschlossen
71. ✅ Gast-User in Supabase erstellt (`gast@sbsprojer.ch`)
72. ✅ DB Migration 009: RLS SELECT-Policies für Gast auf 9 Tabellen
73. ✅ SupabaseService erweitert: `isGuest`, `dataUserId` (Gast sieht Daniels Live-Daten)
74. ✅ 8 Repositories: `_userId` → `SupabaseService.dataUserId`
75. ✅ GoRouter: Redirect-Guard für Form-Routes (Gast kann keine `/neu`/`/bearbeiten`-URLs aufrufen)
76. ✅ 5 UI-Screens: Create/Edit/Delete-Buttons für Gast ausgeblendet (3-Schicht-Sicherheit: DB + Router + UI)
77. ✅ Web-Build + Deploy auf GitHub Pages mit Gastzugang

### Erledigt am 11.03.2026
78. ✅ Auth Provider (authStateProvider, isAuthenticatedProvider, currentUserProvider)
79. ✅ Passwort vergessen (Dialog mit Reset-Link, redirectTo Web-App)
80. ✅ Reaktiver Auth-Guard (GoRouter refreshListenable, automatischer Redirect)
81. ✅ Session-Refresh beim App-Start (bei Fehler automatisch signOut)
82. ✅ Passwort-Recovery-Dialog (Neues Passwort setzen nach Reset-Link)
83. ✅ Tourenplanung Basis (Kalender-Wochenansicht, Tour-Vorschlag ±2 Tage, Drag & Drop, Filter, Dashboard-Kachel)
84. ✅ Unterschriften (Signature-Widget, Techniker + Kunde, Base64-PNG)
85. ✅ Fotos (image_picker, Supabase Storage, Max 4/Anlage, Grid + Vollbild)
86. ✅ Preis-Kalkulator (Reinigung + Störung, Live-Preview, Preisliste aus DB)
87. ✅ Betriebe-Filter erweitert (Meine Kunden, Region Multi-Select, Status Default Aktiv)
88. ✅ Bierleitung-Delete Refresh-Fix + Hahn-Typ Dropdown
89. ✅ BackButton-Fix (context.pop statt Navigator.maybePop)
90. ✅ Löschen-Funktion für Betriebe, Anlagen, Reinigungen & Störungen (Cascade)
91. ✅ Checkliste-Notizen pro Punkt (Migration 013)

### Erledigt am 12.03.2026
92. ✅ Reinigungsprotokoll-PDF (Heineken FOR 1220/Vers.04, Supabase Storage, Printing)
93. ✅ Kundenrechnung komplett:
    - RechnungRepository + RechnungsPositionRepository (Supabase-only)
    - RechnungService (Auto-Erstellung bei Reinigung-Abschluss)
    - RechnungPdfService (A4-PDF mit Swiss QR-Einzahlungsschein)
    - RechnungPdfStorage (Bucket: rechnung-pdfs)
    - Rechnungen-Liste + Detail-Screen (Suche, Status-Filter, PDF-Druck)
    - Rechnung-Providers (Stream, Count, offene, byBetrieb)
    - Dashboard-Kachel ("X offen")
    - Routes: /rechnungen, /rechnungen/:id

### Erledigt am 12.03.2026 (Abend)
94. ✅ Materialverwaltung komplett:
    - 4 Repositories (Lager, MaterialKategorie, MaterialArtikel, MaterialVerbrauch)
    - Material-Providers (materialienStream, materialCount, niedrigCount)
    - Materialien-Liste (Suche, Kategorie-Filter, Bestand-Filter niedrig)
    - Material-Detail (Bestand-Visualisierung, Info, Verbrauchshistorie, Quick-Bestand-Anpassung)
    - Material-Formular (Kategorie, Einheit, Bestand aktuell/mindest/optimal, Lieferant, Heineken-Artikel-Picker)
    - Bestellliste (niedrige Bestände, Fehlmenge, Zwischenablage-Export)
    - Dashboard-Kachel "Material" mit "X niedrig" Badge
    - Material-Picker in Störungs-Formular (5 progressive Slots)
    - Störung-Detail: Lager-Namen statt UUIDs
    - 5 Routes (/materialien, /bestellliste, /neu, /:id, /:id/bearbeiten)

### Erledigt am 13.03.2026
95. ✅ Montage CRUD komplett (Liste, Detail, Form, Router, Home, Betrieb-Detail Section, Sync)
96. ✅ Montage vereinfacht (Beschreibung als Pflichtfeld, Datum, Uhrzeit, Betrieb-Autocomplete, Material 3 Slots)
97. ✅ Betrieb: Ruhetage + Ferien-Management für alle Betriebe (DB Migration 014)
98. ✅ Pikett-Dienste CRUD komplett (Liste, Detail, Form, Router, Home, Sync, Pauschale 80 CHF)
99. ✅ Störungen von Anlage entkoppelt (DB Migration 016, anlage_id optional, betrieb_id direkt)
100. ✅ Störungs-Formular vereinfacht (Betrieb-Autocomplete, MwSt entfernt, Preis-Keys fix)
101. ✅ Störungen-Section auf Betrieb-Detail + Autocomplete im Form
102. ✅ Eigenauftrag CRUD komplett (Migration 017, Model, Local, Mapper, IsarService, Repository, Providers, 3 Screens, Router, Home, Betrieb-Detail Section, Sync)
103. ✅ Eigenauftrag: Lösung + Notizen Felder entfernt (nicht benötigt)

### Erledigt am 14.03.2026
104. ✅ Saison-Felder von Monat (int) zu Datum umgestellt (DB Migration 018, DatePicker statt Dropdown)
105. ✅ Eröffnungsreinigung CRUD komplett:
    - DB Migration 019 (eroeffnungsreinigungen Tabelle + RLS)
    - DTO, Isar Local Model, Web-Stub, Conditional Export, Mapper
    - IsarService Methoden + Web-Stubs (8 Methoden)
    - Repository + Providers
    - 3 Screens (Liste, Detail, Form)
    - Betrieb-Autocomplete → automatische Bergkunde-Erkennung
    - Preis automatisch aus Preistabelle (Normal 60 CHF, Bergkunde 135 CHF)
    - Eröffnungsreinigungen-Section auf Betrieb-Detail
    - Router (4 Routes) + Home Tile + Sync

### Erledigt am 15.03.2026
106. ✅ Heineken Monatsrechnung komplett:
    - HeinekenRechnungService (8 Kategorien aggregieren, Supabase-Queries)
    - HeinekenPdfService (Übersicht + Detail im Heineken-Format)
    - HeinekenMonatsDaten Model (Summen + Raw Data)
    - 3 Screens: Liste, Generierung (Monats-Picker + Vorschau), Detail
    - Heineken Providers + Router + Home-Kachel
107. ✅ 6 Heineken Rapport-PDFs:
    - HeinekenRapportService: F_Störung, F_Eigenauftrag, F_EE_Reinigung, F_Montage, F_Pikett, F_Pauschale
    - buildXPage() + generateX() Pattern für Wiederverwendung
108. ✅ Rapport-PDFs an Monatsrechnung angehängt:
    - Combined PDF: Hauptrechnung + alle Rapport-Beilagen in einem Dokument
    - _addRapportPages() mit 6 Sektionen
109. ✅ Buchhaltung komplett:
    - 3 Repositories: KontoRepository, BuchungRepository, BuchungsVorlageRepository
    - 4 Provider-Dateien (Konten, Buchungen, Vorlagen, Buchhaltung-Aggregate)
    - BuchungService (Buchung aus Vorlage, Kontosaldo-Berechnung)
    - 7 Screens: Dashboard, Kontenplan, Journal, Buchung-Detail, Buchung-Formular, Berichte, Mahnwesen
    - Berichte: Erfolgsrechnung (monatlich/jährlich) + MwSt-Abrechnung (quartalsweise) aus DB-Views
    - Mahnwesen: Überfällige Rechnungen, Mahnstufen 0-3
    - 7 neue Routes unter /buchhaltung/*
    - Home-Kachel "Buchhaltung"

### Erledigt am 18.03.2026
110. ✅ Rechnungsadresse: Betrieb-Feld unter Firma verschoben, auto-gefüllt (non-editable)
111. ✅ Hahn-Typ "Higenie" zu Bierleitung-Dropdown hinzugefügt
112. ✅ Durchlaufkühler "Orion" + "V100" zu Anlagen-Dropdown hinzugefügt (+ DB Migrationen 028, 029)
113. ✅ Säulen-Typ "Cola Säule" zu Anlagen-Dropdown hinzugefügt (+ DB Migration 030)
114. ✅ Tourenplanung Fällig-Tab komplett überarbeitet:
    - Fälligkeit dynamisch berechnet aus letzteReinigung + reinigungRhythmus
    - Neue Anlagen (nie gereinigt) erscheinen als "überfällig"
    - auf-Abruf/Selbstreiniger ausgeschlossen
    - Ruhetag-Check entfernt (alle aktiven Betriebe unabhängig vom Wochentag)
    - Letzte Reinigung als separate Zeile angezeigt ("Noch nie gereinigt" in rot)
115. ✅ Viewport Meta-Tag in web/index.html hinzugefügt
116. ✅ Kontakt-Formular: Handykontakte importieren + auf Handy speichern (PhoneContactService)

### Erledigt am 31.03.2026
117. ✅ camt.053 Bankimport komplett:
    - XML-Parser (UTF-8, Hierarchie-Fix)
    - Web File Picker (dart:html statt file_picker)
    - Duplikat-Erkennung (Referenz-basiert)
    - Auto-Betrieb-Matching
118. ✅ Spesen-Scanner mit OCR komplett:
    - Supabase Edge Function `parse-beleg` (Claude Haiku 4.5 API)
    - BelegScanResult Model (Geschäft, Datum, Positionen, Konfidenz, Zahlungsmethode)
    - BelegScanService (Base64-Encode → Edge Function → JSON-Parse)
    - SpesenImportService (Aufwand-Buchung + Vorsteuer-Buchung pro Position)
    - SpesenScannerScreen (Kamera-direkt, OCR-Ergebnis, Zahlungsweg, Buchen)
    - Mischkauf-Handling (Essen 2.6% + Benzin 8.1% als separate Buchungen)
    - TWINT/Karte/Bar-Erkennung (automatische Zahlungsweg-Vorauswahl)
    - Konten-Mapping: Essen→5820, Benzin→6200, Bar→1000, Bank→1020, Privat→2260, Vorsteuer→1171
119. ✅ Vorsteuer-Buchungen:
    - Separate Buchung pro Position: Soll 1171 (Vorsteuer) / Haben Zahlungskonto
    - MwSt-Betrag als eigene Buchungszeile im Journal
120. ✅ Beleg-Viewer:
    - Belege in Buchungs-Detail direkt öffnen (url_launcher, Signed URL)
    - Beleg-Quelle "Spesen-Scanner" Label
121. ✅ Provider-Invalidation:
    - SpesenScannerScreen → ConsumerStatefulWidget (ref.invalidate)
    - kontoSaldiProvider watched buchungenStreamProvider (live-update Kontenplan)
122. ✅ Termine CRUD komplett:
    - DB Migration 037, Model, Local, Mapper, Repository, Providers
    - IsarService + Web-Stubs, Sync, Router, Screens
123. ✅ DB-Migrationen 031-038 (Gas-Typ, Durchlaufkühler, Biersorten, Bierleitung aktiv, Termine, Beleg-Quelle)

### Erledigt am 21.04.2026
124. ✅ Störungsliste: Anlagentyp-Icons → Anfangsbuchstaben → Störungsnummer im Avatar (Format 001)
125. ✅ Störungsliste: 2-Zeilen-Subtitle (Ort·Datum / Anlagentyp·Bereich·Preis)
126. ✅ Störungsliste: Anlagentyp-Filter (PopupMenuButton mit Chip-Anzeige)
127. ✅ Störungsliste: Monatsgruppierung mit Preissummen (Header pro Monat + Gesamtsumme)
128. ✅ Störungs-Formular: Anlagentyp-Auswahl (FilterChips, Betrieb-Vorauswahl aus Zapfsystemen)
129. ✅ Störungs-Formular: "Heineken-Nr" → "Störungsnummer" umbenannt
130. ✅ Störungs-Formular: Notizen-Feld entfernt (Beschreibung reicht)
131. ✅ Störungs-Formular: Material-Dropdown öffnet nach oben (Tastatur-Fix für Mobile)
132. ✅ Störungs-Detail: Anlagentyp-Icon + Label, Icon build statt warning
133. ✅ Uhrzeiten überall HH:mm statt HH:mm:ss (Störung, Reinigung, PDF-Rapport)
134. ✅ Betrieb-Formular: "Mein Kunde" auto-false wenn nur David/Heigenie
135. ✅ Betrieb-Detail: Saison anzeigen auch ohne Datumswerte
136. ✅ 5-Rappen-Rundung für alle CHF-Beträge + zahlungsweg CHECK Constraint
137. ✅ Reinigung-Buchung: Automatische Buchung mit korrekter MwSt bei Tresen/Mail/Post
138. ✅ camt.053 Import: XML-Parser Hierarchie + Web File Picker Fix

### Erledigt am 07.05.2026
139. ✅ Performance: Shared Betrieb-Provider (betriebNameMap, betriebOrtMap, betriebRegionIdMap) — 8 Screens refactored
140. ✅ Performance: Home Screen in Sub-ConsumerWidgets aufgeteilt (_SyncIndicator, _KachelGrid, _WeitereSection, _TagesUebersicht)
141. ✅ Performance: TagesUebersicht-Logik in eigenen Provider extrahiert
142. ✅ Home Screen: 2x5 Kachel-Grid (Betriebe, Reinigungen, Störungen, Montagen, Eigenaufträge, Eröffnungen, Kontakte, Termine, Tourenplanung, Spesen) — optimiert für Pixel 9
143. ✅ Montage-Formular: HeiGenie Service Protokoll-Anzeige wie bei Reinigungen (full width statt 200px)
144. ✅ Belegscanner: Rundungsdifferenzen (≤0.05 CHF) werden in grösste Position gemergt
145. ✅ Buchungsvorlage Parkgebühren Privat/Twint (GF 5.2, Soll 6270, Haben 2260, 0% MwSt)
146. ✅ Heineken Monatsrechnung: Kilometerabrechnungen zeigen keinen Bereich mehr (statt "Konventionell")
147. ✅ Kontakt-Rolle «Vertreter» für Heineken hinzugefügt

### Erledigt am 08.05.2026
148. ✅ Kontakt-Sync Stufe 1: App-Kontakte aufs Handy pushen (Bulk-Push mit Labels „SBS Kunden"/„SBS Heineken"/„SBS Event")
149. ✅ Buchungsvorlagen: 37 Duplikate bereinigt (GF-Nummern dedupliziert)
150. ✅ Beleg-Erfassung im Buchungsformular (PDF/Foto/Kamera Upload, BelegUploadWidget)
151. ✅ Lohnbuchhaltung komplett:
    - DB Migration 076 (lohn_einstellungen + lohn_abrechnungen + 4 neue Konten: 5710 FAK, 5720 BVG AG, 5730 UVG AG, 5740 KTG AG)
    - LohnEinstellungen Model (Versicherungs-Sätze pro User/Jahr, Lohnausweis-Daten)
    - LohnAbrechnung Model (flexible Auszahlungen, Datum-basiert, mehrere pro Monat möglich)
    - LohnRepository (berechnen mit 5-Rappen-Rundung, buchen mit 7-11 Buchungen via beleg_id, stornieren)
    - LohnlaufScreen (Jahresübersicht, Neuer Lohnlauf mit Live-Berechnung, Detail, Storno)
    - LohnEinstellungenScreen (Sozialversicherungs-Sätze, BVG-Fixbeträge, Lohnausweis-Daten)
    - LohnausweisPdfService (Schweizer Lohnausweis Formular 11 als PDF)
    - Buchhaltung-Dashboard: NavTile „Lohnbuchhaltung"

### Erledigt am 09.-10.05.2026
152. ✅ Betrieb: Servicezeiten (Morgen/Nachmittag) für Betriebe hinzugefügt
153. ✅ Betrieb: WE-Nummer + AG-Nummer Felder (Nummern-Kategorie in Form/Detail, Zahlentastatur)
154. ✅ Betrieb: Region in Detail-Ansicht anzeigen
155. ✅ Heineken Monatsraster komplett:
    - RasterPdfService (Querformat A4, gruppiert nach Regionen, jede Region auf eigener Seite)
    - HeinekenRasterScreen (Datensammlung: Betriebe, Anlagen, Bierleitungen, Reinigungen, Kontakte)
    - Rotpunkt-Logik (kleinstes Reinigungsintervall > 6 Wochen)
    - Bierleitungen-Zählung über alle Anlagen
    - Bemerkungen: Servicezeiten + Kontakt-Telefon
    - Zahlung: BZ/RG/HS aus Rechnungsstellung
    - Monatswerte: Tag, (E) bei Eröffnung/Endreinigung, F=Ferien, A=Inaktiv, G=Geschlossen
    - PDF-Cache pro Jahr (Jahreswechsel behält generiertes PDF)
    - Mail-Versand via Edge Function (send-raster-mail, Storage Bucket raster-pdfs)
    - Mobilfreundliches Layout (Button + Wrap)
156. ✅ Service Worker deaktiviert (--pwa-strategy=none):
    - Webapp nach Deploy sofort aktuell nach einfachem Refresh
    - Kein Löschen von Browserdaten mehr nötig
    - Deploy-Workflow in CLAUDE.md aktualisiert
157. ✅ 3 neue Regionen: Sempach, Küssnacht, Cham (DB: 15 Regionen total)

### Erledigt am 10.–11.05.2026
158. ✅ Heineken Monatsraster: Cache-Buster auf PDF-Download-URL
159. ✅ Heineken Monatsraster: PDF Layout-Verbesserungen
160. ✅ Heineken Raster-Mail: Text mit aktuellem Datum
161. ✅ Zahlungsdifferenz-Handling bei Rechnungen + Pikett-Formular anpassen
162. ✅ Heineken Störungsformular: Pikett KW Sonderzeichen-Fix + Km-System
163. ✅ Pikett-Monatszuordnung: nach Montag der KW (statt Pikett-Datum)
164. ✅ Eröffnung/Endreinigung: Störungsnummer + Art im Formular anzeigen
165. ✅ Heineken Monatsrechnung: Gratisreinigungen fehlen nach Neuerstellen — Fix
166. ✅ Heineken PDF: 5 Verbesserungen (Layout, Formatierung)
167. ✅ Pikett-Dienste Kachel: Gruppierung nach Montag der KW
168. ✅ DST-Bug in Kalenderwochen-Berechnung behoben (UTC statt lokale Zeit)
169. ✅ Heineken PDF: Seitenumbruch-Fix + verbrauchtes Material anzeigen
170. ✅ Material-Formular: Heineken-Beschreibung + Foto-Optimierung
171. ✅ Material-Foto komplett überarbeitet:
    - Supabase Storage INSERT-Policy erstellt (Fotos konnten vorher nicht hochgeladen werden)
    - Foto-Crop-Editor (crop_your_image, fixCropRect, Rotation, Dark Theme)
    - Zwei-Datei Upload (HighRes + Preview 400px/60% JPEG)
    - Lazy HighRes Loading (Preview auf Detailseite, HighRes on-demand)
    - PopScope gegen Browser-Back-Verwechslung
    - Lade-Spinner beim Foto-Ändern
172. ✅ Material-Liste: Subtitle neu DBO-Nummer + Kategorie (ohne Einheit), einzeilig

### Erledigt am 14.05.2026
173. ✅ Material: bestand_niedrig Fix (< statt <=) — Bestand = Mindest zeigt kein Warnsignal mehr
174. ✅ Material: Foto-Spinner Fix — Spinner wird jetzt beim Ändern bestehender Fotos angezeigt
175. ✅ Material: "Auf Optimal auffüllen" Button im Bestand-Anpassen-Dialog
176. ✅ Material-Liste: Sortierung nach DBO-Nummer (Artikel ohne DBO am Ende, alphabetisch)
177. ✅ Material: Stück pro Packung Feld (bei Einheit „Packung" erscheint zusätzliches Eingabefeld)
178. ✅ Materialbestellung komplett:
    - MaterialBestellungScreen (Empfänger aus Heineken Kontaktzuweisung, Auto-Niedrig-Toggle)
    - Drei Sektionen: Verbrauchsmaterial, Reinigungsmaterial, Weitere Artikel
    - Checkbox + editierbare Mengen pro Artikel
    - Artikel vormerken (Bookmark-Icon in Material-Detail + Liste)
    - BestellungPdfService (PDF mit Heineken-Green Branding, DBO/Artikel/Menge/Einheit Tabelle)
    - MaterialBestellungRepository (CRUD, Bestell-Nr MB-001, PDF-Upload, signierte URLs)
    - DB: material_bestellungen + material_bestellpositionen Tabellen mit RLS
    - Storage: bestellung-pdfs Bucket mit RLS-Policies
    - Edge Function send-rechnung-mail erweitert (bestellungId + Materialbestellung.pdf Anhang)
    - MailConfig: bestellung-Bereich für Test-/Scharfmodus
    - Bestellhistorie in DB gespeichert (Status: entwurf → gesendet)
    - vorgemerkt-Flag auf Lager-Tabelle + Toggle in Detail/Liste

### Erledigt am 15.–16.05.2026
179. ✅ Material-Suche: durchsucht jetzt auch Beschreibung, Notizen und Lieferant
180. ✅ Material-Liste: +1/-1 Buttons für Bestand direkt in der Liste (später in Detail verschoben)
181. ✅ Materialbestellung: Dropdown-Auswahl, je 2 Positionen pro Kategorie
182. ✅ Materialbestellung: Reihenfolge Reinigung → Verbrauch → Vorgemerkte → Niedrig-Switch
183. ✅ Materialbestellung-PDF: Reinigungsmaterial vor Verbrauchsmaterial, DBO-Sortierung
184. ✅ Material UI: Minus-Button, Löschen im Formular, Titel mehrzeilig
185. ✅ Manual-PDF Upload/Anzeige für Material-Artikel (Anleitungen für Thermostaten etc.)
186. ✅ Manual-PDF: nur für relevante Kategorien (Elektronik, Thermostat, Pumpe, Fasskühler, Bierkühler, Säule)
187. ✅ +/- Buttons: von Materialliste in Detailscreen verschoben, Bestellliste-Screen entfernt
188. ✅ +/- Buttons: aktualisieren Materialliste sofort (Provider-Invalidierung)
189. ✅ Material-Auswahl: speichert jetzt auch ohne Dropdown-Klick (Text-Matching Fallback in Montage/Störung/Eigenauftrag)
190. ✅ Material-Bestand: aktualisiert sich nach Service-Speicherung (materialienStreamProvider invalidiert in 3 Formularen)
191. ✅ Material-Filter: zeigt nur Kategorien mit tatsächlichen Einträgen

### Erledigt am 19.–29.05.2026
192. ✅ Heineken-Monatsrechnung: Status-Workflow gefixt (offen → gesendet → freigegeben → bezahlt) + HeiGenie-Mail-Bedingung
193. ✅ Heineken-Rechnung: alle Status-Buttons immer im Body sichtbar
194. ✅ Buchhaltung: Rechnungs-Nachversand-Screen
     - Rechnungsadresse-Join via betriebe genestet (PostgREST-Fix)
     - betrag_brutto als String → double.tryParse, 5-Rappen-Rundung in Anzeige
     - 2 separate Queries + defensive .toString()-Casts (Type-Error-Fix)
     - PDF-Link on-demand neu signieren (gecachte URL läuft nach 1h ab)
     - betriebe.email als Fallback-Empfänger, versendet_am aus DB ignoriert
195. ✅ CLAUDE.md: DB-MCP-Zugriff dokumentiert, Deploy ohne git stash, Zahlungsstatus-Section
196. ✅ Projekt-Review mit Opus 4.8 (v0.10.97+379):
     - Bugfix: Reinigung-Zahlungsstatus 'versendet' → 'gesendet' (PostgrestException nach Migration 083)
     - Bugfix: Heineken Anfahrtspauschale-Fallback reaktiviert (_toDoubleN statt _toDouble lieferte stets 0)
     - Kontakt-Entity voll in Isar integriert (8 IsarService-Methoden, KontaktLocal.routeId, Schema) → Native-Build kompiliert wieder
     - Dead Code in PDF-Services entfernt, ~30 Lints bereinigt (initialValue, null-aware-Elements, debugPrint), barcode als direkte Dependency
     - flutter analyze: 0 Errors (vorher 11 versteckte Compile-Fehler), nur noch akzeptierte Infos + generierter Isar-Code

### Erledigt am 30.05.2026 (Mail-Versand scharfstellen + Bereinigung)
197. ✅ Reinigungsrechnungen scharfgestellt (`reinigungScharf=true`):
     - Beim Service-Abschluss echte Kunden-Email statt `null` ermitteln (betrieb_rechnungsadressen.email → Fallback betriebe.email)
     - Fehlt eine Kundenadresse → Versand an Daniel + orange Warnung
198. ✅ Montage scharfgestellt (`montageScharf=true`): HeiGenie-Service-Protokoll-Mail geht an echten RSL-Kontakt (mit PDF) statt Test-Empfänger
199. ✅ Nachversand-Screen erweitert:
     - Respektiert jetzt MailConfig (Testmodus) statt direktem Versand
     - Reinigungsprotokoll wird angehängt (Pfad über rechnungs_positionen → reinigungen.protokoll_foto_pfad)
     - Banner spiegelt tatsächlichen Modus (TESTMODUS/SCHARF)
     - versendet-Markierung aus DB (`versendet_am`) statt nur Session-State → bleibt nach Reload erhalten
     - Piaggio Dosch (2026-05-0615) aus Liste ausgeblendet (manuell versendet, Ausschlussliste statt versandart-Änderung)
200. ✅ Mail-Adressen-Bereinigung (Fix "Invalid To header" / Gmail 400):
     - `MailConfig.bereinige()`: entfernt Zero-Width-Spaces (U+200B–U+200D), BOM, NBSP + trim; `empfaenger()` gibt immer bereinigt zurück
     - DB-Korrektur: Padelta-Email (chur@padelta.ch) hatte 2× U+200B
     - Edge Function `send-rechnung-mail` v7: `encodeEmailDomain()` kodiert IDN-/Umlaut-Domains via Punycode (z.B. teehütte-klosters.ch → xn--…)
201. ✅ `versendet_am` nur bei scharfem Versand setzen:
     - `MailConfig.istScharf(bereich)`; Nachversand + Service-Abschluss markieren im Testmodus nicht mehr als versendet
     - DB-Korrektur: Mountain Plaza (2026-05-0636) + Padelta (2026-05-0596) versendet_am zurückgesetzt (waren Testmodus/fehlgeschlagen)

### Erledigt am 31.05.–01.06.2026 (Heineken WE/AG + Termin-Erinnerungen)
202. ✅ Heineken WE-/AG-Nummern aus Kundenliste (DBO-Export) zugeordnet:
     - 205 eindeutige Outlets gegen 285 Betriebe gematcht (Name + Ort-Abgleich, pg_trgm)
     - 155 Betriebe mit WE/AG ergänzt (vorher 10) — nur eindeutige Treffer automatisch
     - Mehrdeutige/ortsabweichende Fälle bewusst ausgelassen + dem User vorgelegt
     - 3 Spezialfälle manuell bestätigt (Cuntera/Curaglia, Bernina→Pizzeria, Bolgen Plaza)
     - Reine DB-Änderung (keine Code-/App-Änderung)
203. ✅ Termin-Erinnerungen (Popup/Alarm) — neues Feature (v0.10.106):
     - DB-Migration 086: `erinnerung_aktiv` (bool) + `erinnerung_vorlauf_minuten` (int)
     - Pro Termin aktivierbar (Standard aus) + frei wählbare Vorlaufzeit (0 Min–1 Woche)
     - `ReminderService` (Conditional Export): Android = `flutter_local_notifications`
       (echte System-Benachrichtigung, auch bei geschlossener App); Web = Timer-Scheduler
       + Browser-Notification + In-App-Hinweis (kein Push-Server)
     - Zeitpunkt-Berechnung mit Unit-Tests (mit Uhrzeit / 08:00-Bezug ohne Uhrzeit)
     - UI: Toggle + Vorlauf-Dropdown im Termin-Formular, Glocken-Icon im Kalender
     - Anbindung an Termin-save/delete + rescheduleAll beim App-Start
     - Design-Spec + Plan: `docs/superpowers/specs|plans/2026-05-31-termin-erinnerungen*`
     - OFFEN: Android-Funktion mangels Gerät nur via analyze/Build verifiziert (echter Test beim APK-Build)

### Erledigt am 02.06.2026 (Nachversand-PDF, Tourenplanung, Kalender-Saisonlogik)
204. ✅ Nachversand: Rechnungs-PDF wird live neu generiert (Fällig = Versanddatum + 30 Tage,
     Rechnungsdatum bleibt); DB unberührt (Rechnungskontrolle erst ab 01.07. in App).
     `Rechnung.copyWith()` ergänzt (v0.10.107)
205. ✅ Tourenplanung: neue Fälligkeitsstufen relativ zum Rhythmus — bald fällig ab Soll
     (4W), fällig ab Soll+1W (5W), überfällig ab Soll+2W (6W) (v0.10.108)
206. ✅ Kalender: Saison-/Ferien-Vorschläge werden synchronisiert statt nur hinzugefügt —
     veraltete 'vorgeschlagene' Auto-Termine entfernt, neue erstellt; automatisch beim
     Betrieb-Speichern + Button. Bestätigte/manuelle Termine bleiben (v0.10.109)
207. ✅ Kalender: keine Eröffnungsreinigung am Saisonstart, wenn letzte Reinigung eine
     Endreinigung war (service_art='endreinigung' → Anlagen sauber eingelagert). Tour-
     Fälligkeit war bereits korrekt (Saisonstart+4W). 39 veraltete Eröffnungs-Vorschläge
     einmalig bereinigt (v0.10.110)

### Erledigt am 02.06.2026 (Post-Rechnungen)
208. ✅ Bei Rechnungsart "Per Post" wird beim Reinigungs-Abschluss die Rechnung (+ Protokoll)
     per Mail an Daniel (dani.proyer@gmail.com) gesendet — zum Ausdrucken/Postversand.
     Bisher wurde nur bei "Per E-Mail" gemailt (v0.10.111)
209. ✅ Post-Rechnung: versendet_am + zahlungsstatus='gesendet' beim Abschluss (Versandtag =
     Abschlusstag, Zahlungsfrist läuft ab Service). 3 heutige Post-Rechnungen (Spiga,
     Franziskaner, Fondue Beizli) nachträglich gemailt + Versanddatum gesetzt (v0.10.112)

### Erledigt am 01.06.2026 (Datenkorrekturen)
- ✅ Rechnungen Jatzmeder + Milez auf unversendet gesetzt (neue Rechnungsadresse/Mail in Betrieben erfasst; PDF wird beim Nachversand mit aktueller Adresse generiert)

### Temporär aktiv (Stand 02.06.2026)
- **Rechnungs-Nachversand-Screen** bleibt bis zur vollständigen Abarbeitung des Backlogs (ab 18.02.2026), dann entfernen (Datei + Route + Dashboard-Tile).
- **Mail-Scharfstellung:** reinigung ✅ / heineken ✅ / montage ✅ / heigenie ✅ — bestellung & mahnwesen noch im Testmodus.

### Nächste Schritte (Phase 4: Polish & Testing)
1. ☐ Buchhaltung scharfstellen bis 01.07.2026 (Eröffnungsbilanz, Heineken-Buchungen, Zahlungseingänge)
2. ☐ Heineken Monatsrechnung testen (wenn mehr Aufträge erfasst sind)
3. ☐ Heineken Rapport-PDFs Layout-Fehler beheben
4. ☐ Materialbestellung testen (scharfstellen wenn bereit)
   - Edge Function send-rechnung-mail redeployen (bestellungId-Support)
   - MailConfig bestellungScharf auf true setzen
5. ☐ UI/UX Verbesserungen (alle Screens durchgehen)
6. ☐ Beta-Testing mit Daniel (reale Umgebung)
7. ☐ Bug-Fixes
8. ☐ App Store Submissions (iOS + Android)
9. ☐ Performance: Lazy Route Loading, Image Compression, Pagination, select() Columns

### Offene DB-Migrationen (im Supabase SQL Editor ausführen)
- Keine — alle Migrationen bis 080 sind ausgeführt

---

## 📞 KONTAKTE & RESSOURCEN

### Accounts
- **Supabase**: ✅ Vorhanden
- **GitHub**: ✅ Vorhanden
- **Apple Developer**: ⏳ Benötigt für iOS-Deployment
- **Google Play Developer**: ⏳ Benötigt für Android-Deployment

### Links
- Supabase Dashboard: [https://supabase.com/dashboard](https://supabase.com/dashboard)
- Flutter Docs: [https://flutter.dev/docs](https://flutter.dev/docs)
- Supabase Docs: [https://supabase.com/docs](https://supabase.com/docs)

---

**Zuletzt aktualisiert**: 02.06.2026 – Nachversand-PDF live; Tourenplanung-Fälligkeitsstufen 4/5/6 Wochen; Kalender Saison-/Ferien-Vorschläge synchronisieren + keine Eröffnungsreinigung nach Endreinigung; Post-Rechnungen werden zum Ausdrucken an Daniel gemailt (versendet_am = Abschlusstag). App-Version 0.10.112+394.
**Nächstes Update**: Laufend (Phase 4 Polish & Testing, Buchhaltung + Rechnungskontrolle scharfstellen bis 01.07.2026)
