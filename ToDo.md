# ToDo-Liste — Daniel Projer (SBS Projer App)

**Stand:** 20.07.2026 · **Live:** v0.51.1

---

## 🟢 (GELÖST 16.07. — siehe „Ursache der 38 — GELÖST" oben) Archiv: Warum fehlten 38 Rechnungen?
**Historie der Fehlersuche, als Referenz behalten.** Hat mit der Rundung NICHTS zu tun (das war ein zweiter, eigener Fehler).

**Symptom:** 38 abgeschlossene Tresen-Reinigungen (26.06.–13.07., CHF 3'656.05) bekamen beim Abschluss keine Rechnung. Nur bei Tresen aufgefallen, weil dort Protokoll + QR direkt aus der Reinigung kommen und ohne Rechnung funktionieren — bei `rechnung_mail`/`rechnung_post` merkte Daniel es sofort und holte es manuell nach (deshalb sahen diese Kategorien „sauber" aus, waren es aber nicht).

**Was BEWIESEN ausgeschlossen ist:**
- **Sequenz-Kollision** (meine Diagnose vom 14.07. in `fbca510` — FALSCH): Zwischen 26.06. und 30.06. stieg `rechnungsnummer_seq` um genau 1, obwohl 8 Fälle ausfielen → es wurde gar kein Insert versucht. Die „verbrannten" Nummern 645→1002 stammen vom Excel-Import am 13.06.
- **Referenz-Kollision:** Keine der 38 Wunsch-Referenzen war belegt (geprüft).
- **`kIsWeb`/Android:** Daniel schliesst im Browser ab.
- **Cache/Service Worker:** Fehler trat auch im Inkognito auf.

**Beste verbliebene Spur:** Die Ausfälle beginnen exakt am **26.06.** — einen Tag nach dem SCOR-Deploy. Am 25.06. war zwischen **15:40 (v0.13.0 „TP-C QR-Referenz")** und **16:10 (v0.13.2 „QR-Referenz-Kollisions-Fix")** eine Fassung live, die bei Kollision eine `PostgrestException` warf statt es erneut zu versuchen (`d3f4fa1` zeigt den Diff). Damals stand die Buchung im SELBEN try-Block → beides fiel aus, was zum Befund passt (die 38 hatten weder Rechnung noch Buchung; letztere kam erst per Nachtrag am 14.07.).
**Widerspruch dazu:** Ein fehlgeschlagener Insert hätte eine Sequenznummer verbrannt — hat er nicht. Also passt auch diese Spur noch nicht lückenlos.

**WARUM es unsichtbar blieb — GEFUNDEN (15.07. abends):** Der Block hatte einen komplett stummen catch:
```dart
} catch (e) { debugPrint('Rechnungs-/Buchungserstellung fehlgeschlagen: $e'); }
```
Rechnung UND Buchung standen darin, `createFromReinigung` machte `rethrow` → beides fiel gemeinsam und spurlos aus. Seit `fbca510` (14.07.) gibt es eine rote SnackBar und getrennte try-Blöcke — eine SnackBar, die nach 12 Sek. verschwindet, hätte die 38 Fälle aber nicht verhindert. Deshalb die zugesagte Warnung (siehe unten).

**Weiter eingegrenzt (15.07. abends):**
- **Nicht Betriebs-inhärent:** 36 der 37 betroffenen Betriebe bekamen VOR dem 26.06. problemlos automatische Rechnungen.
- **Saubere Trennung ab 26.06.:** 37 Betriebe danach NIE wieder automatisch erfolgreich, 5 Betriebe durchgehend erfolgreich — **kein einziger gemischt**. Also kein Zufalls-/Netzwerkfehler, sondern ein deterministisches Merkmal.
- **Nicht der SCOR-Code:** `scor_referenz.dart` seit 26.06. unverändert; die Suffix-Retry-Schleife war am 26.06. bereits drin (Fix `d3f4fa1` kam am 25.06. um 16:09, also VOR dem ersten Ausfall). Damit ist auch die „kaputte Zwischenversion 15:40–16:10"-Spur entwertet.
- **Derselbe Code funktioniert heute:** Der Nachtrag hat alle 38 über `createFromReinigung` fehlerfrei verarbeitet.
- **Kein Insert wurde versucht** (Sequenz unberührt) → Abbruch vor dem Insert, ODER gar keine Ausnahme: `if (betrieb != null)` umschloss den ganzen Block, `betrieb == null` überspringt alles lautlos.
- **Nicht `betriebe.updated_at`:** trennt die Gruppen nicht.
- **Neue Spur:** Am 26.06. um 06:10 ging **v0.16.3 „Eingangsrechnungen (Scan→KI→Kreditoren-Buchung, TP-0..2)"** live — der Morgen des ersten Ausfalltags.

### Stand der Jagd (15.07. spätabends) — statische Analyse ERSCHÖPFT

**Der Fehler ist vermutlich NOCH AKTIV.** `fbca510` (14.07.) hat nur die try/catch-Struktur umgebaut — Betrieb-Laden und Bedingung sind unverändert, es wurde nichts repariert. Am 14.07. gab es schlicht **keine** Tresen-Reinigung, und seither gibt es genau **einen** Datenpunkt: Postresidenz am 15.07. (erfolgreich — wie Spescha/Hemingway damals auch). Bei 38:3 löst die nächste Tresen-Reinigung ihn mit hoher Wahrscheinlichkeit wieder aus.

**Weiter ausgeschlossen (15.07. spätabends):**
- **Kein anderer Abschluss-Weg:** `r.status='abgeschlossen'` wird NUR in `reinigung_form_screen.dart:427` gesetzt, an derselben `abschliessen`-Bedingung wie der Rechnungsblock.
- **Keine Datenunterschiede:** 38 Ausfälle vs. 3 Treffer sind in ALLEN Feldern identisch (preisliste_id, anlage_id, anlage_ids, service_art, service_typ, Unterschrift, Foto, Checkliste, hahn_temperaturen, ist_synced).
- **Nicht tageweise:** Am 30.06. fielen Lenzerhorn (07:51) und Grotto (09:31) aus, **Spescha (10:20) gelang** (Rechnung 336 ms später), Cafe Bar (12:12) fiel wieder aus. Gleicher Tag, gleicher Code → keine kaputte Sitzung, kein kaputter Deploy-Stand.
- **Alle Reinigungen gleich erfasst:** `uhrzeit_ende` = Minute von `created_at` → alle in einem Zug erfasst UND abgeschlossen, kein Draft-vs-Sofort-Unterschied.
- **Die drei Schritte vor dem Insert können NICHT werfen:** `_loadMwst` behält bei fehlender Preisliste den Default (kein `!`), `_buildPositionen` ist null-geguarded, der Nummernbau nutzt `?? '0000'`.

**Damit bleibt GENAU EIN Zweig übrig:**
```dart
final betrieb = _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
if (betrieb != null) { … }   // null -> weder Rechnung noch Buchung, lautlos
```
Das erklärt jede Beobachtung: kein Insert (Sequenz unberührt), keine Ausnahme, keine Meldung, und dass Rechnung UND Buchung gemeinsam fehlten. Warum `betrieb` null sein sollte (dreifach geladen: Provider synchron in `initState`, in `_loadReinigung`, async in `_loadPreisData`) ist offen.

**v0.48.4 macht diesen Zweig laut** (30 Sek. rote SnackBar + `debugPrint` mit `betriebId`, `_betrieb`, `widget.betriebId`).

### REPRODUKTION VERSUCHT — BEIDE MALE FEHLGESCHLAGEN (15.07. spätabends)
Zwei echte Test-Reinigungen bei Betrieben, die am 13.07. noch ausfielen. **Beide liefen sauber durch**, danach exakt auf Baseline zurückgerollt (Sequenz per `setval` auf 1290).

| Test | Betrieb | Ergebnis |
|---|---|---|
| Desktop-Browser | Espresso Bar Landquart | Rechnung 2026-07-1291 + 2 Buchungen ✅ |
| **Handy + sofortige Bildschirmsperre** | Hotel Chur | Rechnung 2026-07-1292 + 2 Buchungen ✅ |

**Damit ist der Fehler heute unter keiner Bedingung reproduzierbar** — nicht am Rechner, nicht am Handy, nicht mit eingefrorenem Tab. Er hängt nicht an Daten, Betrieb, Gerät oder Ablauf. Zwischen dem 13. und 15.07. hat ihn etwas behoben; was, ist unbekannt.

### Ehrliche Bilanz: SECHS Hypothesen, alle widerlegt
1. Sequenz-Kollision (Diagnose 14.07., `fbca510`) — Sequenz stieg um 1 bei 6 Ausfällen.
2. Referenz-Kollision — keine der 38 Wunsch-Referenzen war belegt.
3. `kIsWeb`/Android — Daniel schliesst im Browser ab.
4. Service Worker / Cache — Fehler trat auch im Inkognito auf; Hash lokal == gh-pages == live.
5. Stummer catch als Ursache — war nur der Stand vom 26.06.; die rote Meldung kam im Ausfallfenster dazu, Daniel sah nie eine.
6. Eingefrorener Tab beim Handy-Einstecken — Test widerlegt.

**Konsequenz:** Statt der siebten Hypothese → **Erkennung gebaut** (Warnung, siehe unten). Der Fehler kostete 3 Wochen und CHF 3'656, weil ihn niemand SAH — nicht, weil er unauffindbar war.

**Falls er wiederkommt:** Die Warnung zeigt es am nächsten Tag. Zusätzlich meldet sich seit v0.48.4 der `betrieb == null`-Zweig laut (30 Sek. rote SnackBar + `debugPrint` mit `betriebId`) — der einzige Zweig, der ohne Ausnahme und ohne Spur aussteigen kann. Dann: **Meldung fotografieren**, das entscheidet die Frage in einer Minute.

---

## 🔴 OFFEN: Nächste Schritte
- **Live-Check Tourenplan v0.51.0 durch Daniel:** Fällig-Liste muss jetzt die Saison-Kunden zeigen (Stand 17.07. spätabends: 8 überfällig inkl. Tgantieni, 1 fällig Mountain Plaza, 2 bald fällig Waldhuus/Jschalp; 5 korrekt noch nicht fällig, weil erst kürzlich geöffnet — Soll = Saisonstart + Rhythmus).
- ~~Furt, Wangs~~ **ERLEDIGT 20.07.:** Anlage war demontiert (korrekt erfasst), nur der Betrieb stand noch auf aktiv → jetzt `inaktiv` mit Grund „Anlage demontiert" (inaktiv_seit 20.07., Demontage-Datum unbekannt). Falls Daniel das echte Demontage-Datum kennt: im Betriebs-Formular nachziehen.
- ~~Detailfrage Warnleiste~~ **ERLEDIGT 20.07. (v0.51.1):** Saisonpause-Betriebe werden jetzt auch gemeldet (Entscheid Daniel; operativ = aktiv+saisonpause, nur inaktiv/geschlossen aussen vor).
- **Warnleiste „Saisondaten fehlen" zeigt aktuell 15 Betriebe** — überwiegend Winter-Betriebe (Davos/Laax/Lenzerheide: Fuxägufer, Piz Piz, Frosch, Bolgenschanze, Il Pub, Indy Bar, Snake Bar, Acla Grischuna, Clubhotel, Dischma, Hotel Sport Klosters, Kartitscha, Obertor Parpan/Ilanz, Gemsli Mels), deren Endreinigung im Frühjahr war und deren **nächster Winterstart noch nicht eingetragen** ist. Daniel pflegt die Saisondaten nach, sobald bekannt — die Uhr startet dann automatisch; bis dahin erinnert die Leiste.

---

## 🟢 Fälligkeit ab Saisonstart (live v0.51.0 · 17.07.2026) — Tgantieni-Fall behoben
Spec `docs/superpowers/specs/2026-07-17-faelligkeit-saisonstart-design.md`, Plan `docs/superpowers/plans/2026-07-17-faelligkeit-saisonstart.md`. Subagenten-getrieben (4 Tasks + Reviews), 442 Tests grün, keine DB-Änderung.

**Befund:** 17 Saison-Kunden waren bis 78 Tage wieder offen, ohne je im Tourenplan zu erscheinen. Drei Zahnräder: `eroeffnungFaellig` blieb nach Endreinigung FÜR IMMER (Saison-Prüfung kehrte früh zurück, Uhr lief nie an), der Standard-Filter zeigte nur überfällig+fällig, der Auto-Termin nur exakt am Eröffnungstag.

**Regel (Daniel):** Uhr-Anker = Wiedereröffnung, wenn der Betrieb nach der letzten Reinigung zu war (Saisonpause/Ferien; Ruhetage zählen nicht) — gilt für Endreinigung am Schluss UND Eröffnungsreinigung vor dem Start. Danach normale Stufen ab Anker + Rhythmus.

- Neu `faelligkeitsAnker()` in `touren_saison.dart` (7 Tests); `getFaelligkeit` nutzt den Anker für JEDE Service-Art (ersetzt den harten „Endreinigung+28"-Block), 7 Szenario-Tests (Tgantieni-Timeline).
- Eröffnungs-Hinweis nur noch im Fenster 7 Tage vor Start; entfällt automatisch nach einer Pausen-Reinigung (Service-Art-Wechsel).
- **Warnleiste „Saisondaten fehlen"** im Tourenplan (Endreinigung ohne gepflegten Saisonstart/Ferien-Ende → Uhr kann nicht starten), Muster der Rechnungs-Warnung, stumm bei 0.
- Standard-Filter zeigt jetzt auch Eröffnung/Endreinigung.
- Bekannte Grenze (Review, unkritisch): Bei Monats-Rhythmen kann das Soll 1–2 Tage später liegen als der Kalender-Trigger der DB (feste 60/90-Tage vs. Kalendermonate) — nie früher.

---
- **158 Mail-Betriebe ohne Rechnungsadresse-E-Mail** (Stand 16.07. nach Bereinigung; deren Rechnung geht bis zur Erfassung sichtbar an den Test-Empfänger). **Erledigt:** Die 14 Kandidaten mit `betriebe.email` sind abgearbeitet — 8 hat Daniel selbst erfasst (inkl. der Sonderfälle Blue Cinema/Swisscom, Clubhotel/Mountain Hotels, Piaggio Dosch), Concordia war schon versorgt, **5 Nicht-Kunden auf `heineken` umgestellt** (Alpensonne Arosa, Alpina Brigels, FC Schluein, Little Coffee, Sneki Bar — standen fälschlich auf `rechnung_mail`, hätten als Dialog-Vorbelegung eine Rechnung an Nicht-Kunden vorgeschlagen). Die 158 restlichen erfasst Daniel laufend beim Abschluss (der neue Dialog bietet Warnung + Feld).
- ~~Live-Test v0.50.0~~ **ERLEDIGT 17.07. im Echtbetrieb:** 10 Reinigungen (7 Tresen/Mail → Rechnung+Debitor, 1 Bar → Kasse, 1 Heineken → korrekt nichts, 2 Mail), alle mit fixierter `zahlungsart` auf der Reinigung, alle Beträge auf 5 Rappen, DB-verifiziert. Keine Fehler beobachtet, Warnung leer. Kein Test-Rollback nötig (echte Daten).

---

## 🟢 Zahlungsart pro Reinigung (live v0.50.0 · 16.07.2026) — Ursache der 38 BEHOBEN
Spec `docs/superpowers/specs/2026-07-16-zahlungsart-pro-reinigung-design.md`, Plan `docs/superpowers/plans/2026-07-16-zahlungsart-pro-reinigung.md`. Subagenten-getrieben (8 Tasks, je Spec- + Qualitäts-Review, Final-Review vor Deploy), 428 Tests grün, Migration 144 auf Prod.

- **Kern:** `reinigungen.zahlungsart` wird beim Abschluss fixiert und ist via `resolveZahlungsart()` ALLEIN massgebend für Buchung, Rechnung, Versand, Detail-Recovery, PDF-Fusszeile und Detail-Anzeige. Betriebs-Wert = nur noch Default/Fallback für Altbestand (NULL).
- **Abschluss-Dialog:** Betrieb wird FRISCH geladen (der Cache-Fall der 4 vom 13.07.); Checkbox „Auch als Standard übernehmen" (default AUS — der stille Rückschreib-Effekt ist weg); Klartext-Zeile, was der Abschluss auslöst (rot bei Mail ohne E-Mail); Rechnungs-E-Mail direkt erfassbar (legt Rechnungsadresse vorbefüllt an — Versand läuft NUR über `betrieb_rechnungsadressen.email`, `betriebe.email` ist Info).
- **QR-Tab** trägt bei Rechnungsarten dieselbe SCOR-Referenz wie die Rechnung (byte-identisch gegen Live-DB verifiziert: RF32202606260476) → spontane Direktzahlung camt-zuordenbar. Bar bleibt referenzlos.
- **Warnung:** Entscheidung als getestete reine Funktion `warnungsGrund()` — Kasse-Buchung (1000) = bar erledigt (die 10 Fehlalarme weg), NEU auch „ohne Buchung"-Check (fängt die Durchfall-Klasse selbst). Live-Verify: 0 Treffer.
- **Suchlauf 1:** 0 verlorene Reinigungen seit 01.12.2025 — nichts offen.
- **Review-Funde gefixt:** Doppeltap-Guard im Abschluss (Critical — hätte Doppelrechnung erzeugt), Retry behält User-Wahl, E-Mail-Speicherfehler sichtbar, Label im Korrektur-Service, Perf (Betrieb-Fetch ~856→~280), 2 Display-Lecks (Detail + Protokoll-PDF zeigten Betriebs- statt fixierter Art).
- **Rest-Grenze (bewusst):** Wählt man im Dialog absichtlich `heineken` für einen Nicht-Heineken-Betrieb, greift nur die Klartext-Warnung im Dialog (Warnung flaggt heineken nicht — by design, Spec Abschnitt 4).

---

## 🟢 Ursache der 38 fehlenden Rechnungen — GELÖST (16.07.2026, Hinweis Daniel)
Nach 6 widerlegten Hypothesen brachte Daniels Hinweis („ich habe einige Änderungen an der Zahlungsart vorgenommen") die Lösung: **34 der 38** Reinigungen passierten, als die Betriebe noch `rechnungsstellung='heineken'` hatten (Serie erst am **10.07.** auf Tresen umgestellt) — `heineken` fiel in Buchungs- UND Rechnungs-Service lautlos durch (`return null`: keine Rechnung, keine Buchung, keine Ausnahme, keine Sequenznummer). **Die restlichen 4** (13.07.: Surselva 2×, Hotel Chur, Espresso Bar) nutzten den veralteten Formular-Cache statt des frischen DB-Werts (Betriebe waren schon Tresen). Erklärt auch, warum die Reproduktion am 15.07. scheiterte: dieselben Betriebe, aber NACH der Umstellung mit frischem Cache. Behoben durch v0.50.0 (Zahlungsart pro Reinigung, frischer Betrieb im Dialog).

---
- **10 Reinigungen ohne Rechnung entscheiden (~CHF 1'011)** — die neue Warnung zeigt sie beim ersten Öffnen. Sartons Valbella (3×), Dieschen (2×), Rössli Cham (2×), Seerestaurant Immensee (2×), Central Bad Ragaz. Leistungen Dez 2025 – Apr 2026, alle Tresen, **alle im April nacherfasst** (`created_at` 22.–27.04. bei Leistungsdatum Monate davor) → eigenes Muster, nichts mit den 38 zu tun. **Daniel entscheidet, ob noch verrechnet wird** — nichts angefasst.
- **camt-Test fortsetzen:** 🟡 Manuell (v. a. Davos Klosters → Routing über `heineken_nr`, 0151 = Armando Klosters), ⚪ Nicht zugeordnet, Übriges (Buchung müsste seit Migration 140 gehen).
- **Backups aufräumen** (erst nach Daniels OK): `_bak_nachtrag_20260715_rechnungen`, `_bak_nachtrag_20260715_positionen`, `_bak_camt_20260715_*`, ggf. `_bak_rundung_*_20260714`.
- **`kAppVersion` in `core/app_version.dart` bei jedem Version-Bump mitziehen** (manuell, Duplikat zu `pubspec.yaml` Zeile 4). Steht jetzt im Forderungen-Titel — wenn er nicht zur erwarteten Version passt, läuft alter Code.

---

## 🟢 Warnung „Reinigungen ohne Rechnung" (live v0.49.0 · 15.07.2026)
Die Antwort auf einen Fehler, den wir nicht finden konnten — und deshalb die einzige, die trägt: Sie fragt **nicht nach dem Warum**, sondern zeigt, **dass** eine Rechnung fehlt. Wirkt bei jeder Ursache, auch bei einer, die nie verstanden wird. Hätte aus drei Wochen und CHF 3'656 einen Tag und eine Reinigung gemacht.

- `services/rechnung/reinigungen_ohne_rechnung.dart` + `reinigungenOhneRechnungProvider`, rote Leiste in den Forderungen, antippen → Liste.
- **Stumm, solange nichts fehlt** — eine Warnung, die immer leuchtet, wird ignoriert. Deshalb Stichtag **01.12.2025** + `quelle != 'excel_import'`: die 1519 Excel-Zeilen sind über den Voll-Import abgedeckt und hätten sie dauerhaft auf Alarm gestellt.
- **Meldet, repariert nicht** (Vorgabe Daniel): Nachholen über das Rechnungs-Menü im Reinigungs-Detail.
- Positionen werden gezielt in 200er-Blöcken abgefragt (`inFilter`) — **nie** `select()` über die ganze Tabelle (1000-Zeilen-Limit, siehe unten).
- **Version im Forderungen-Titel** (`Forderungen · v0.49.0`) — dass stundenlang nicht feststellbar war, welcher Code im Browser läuft, hat am 15.07. drei Fehldiagnosen verursacht.
- Temporärer Nachtrag (Service + Menüpunkt + Dialog) wieder entfernt, wie zugesagt.

---

## 🟢 38 fehlende Tresen-Rechnungen nachgetragen (15.07.2026, CHF 3'656.05)
Ausgelöst durch Daniels Frage, warum die Reinigung Alpenblick Arosa (26.06.) nicht in den Forderungen steht. Alle 38 sind erledigt: 0 krumm, 0 Abweichung zur Reinigung, Summe 3'656.05 = 3'656.05, `versendet_am` = Reinigungsdatum (bei Tresen wird die Rechnung vor Ort abgegeben), QR-Referenz identisch mit der, die sie am Reinigungstag bekommen hätten (hängt nur an Datum + Betriebnummer). PDF stichprobenweise geprüft: 138.35. Keine Doppelbuchung (`createFromReinigung` bucht nicht).

**Zwei eigene Fehler, beide vom Trockenlauf gefangen — nicht von Tests oder Analyse:**
1. **v0.48.0 zeigte 45 statt 38.** Die bereits verrechneten Reinigungen wurden mit EINEM `select()` über `rechnungs_positionen` geladen → PostgREST liefert max. 1000 Zeilen, bei 4971 blieben 3971 unsichtbar und galten als unverrechnet. 7 Reinigungen mit bestehender Rechnung standen auf der Liste → ein Klick hätte 7 **Doppelrechnungen** erzeugt. Gefixt: gezielte Abfrage per `inFilter` + Einzelcheck unmittelbar vor jedem Anlegen.
2. **30 von 38 Rechnungen krumm** (74.59 statt 74.60) — siehe nächster Abschnitt.

---

## 🟢 Rundung: Der Rechnungsbetrag kommt vom TRIGGER, nicht von der App (Migration 143 · 15.07.2026)
**Der teuerste Irrtum des Tages.** `update_rechnung_summen()` auf `rechnungs_positionen` summiert `betrag_brutto` bei JEDEM Positions-Insert aus den Positionen und überschreibt damit den App-Wert (App schrieb 138.35, Trigger machte 138.37 daraus).

Deshalb waren **Migration 139** (Reinigungs-Trigger, 14.07.) und der **Dart-Fix in `rechnung_service`** (v0.48.2) beide wirkungslos — sie sassen auf der falschen Ebene. Mein Backfill vom 14.07. hat nur Symptome beseitigt; der Nachtrag reproduzierte den Fehler prompt.

**Vier falsche Diagnosen, bis der Trigger gefunden war:** Sequenz-Kollision, Referenz-Kollision, `kIsWeb`, Service-Worker/Cache. Beweislage, die keinen Sinn ergab: `vorschauBrutto` zeigte 138.35, der Insert schrieb 138.35 (RETURNING), Hash lokal == gh-pages == live — und die DB hatte 138.37. Auflösung: Ich hatte nur Trigger auf `rechnungen` geprüft, nie auf `rechnungs_positionen`.

**Regel (Daniel):** Kundenrechnungen IMMER auf 5 Rappen, **nur `heineken_monat` ungerundet**. Migration 143 setzt das im Trigger um (MwSt aus dem gerundeten Brutto abgeleitet → Netto + MwSt = Brutto exakt). Die 38 wurden dadurch in der DB selbst korrigiert, ohne neuen Lauf.

**Die Dart-Rundung bleibt nötig:** Das PDF entsteht aus dem Rechnungs-Objekt VOR dem Trigger. Beide Seiten runden jetzt gleich, sonst laufen PDF und Datenbank auseinander. Zentral in `core/util/rundung.dart` (9 Tests) statt wie bisher 5× dupliziert — und die alten Kopien rundeten ausgerechnet erst bei der **Anzeige** (`rechnungen_list_screen:853`, `rechnung_detail_screen:269`): gespeichert 74.59, angezeigt 74.60. Genau deshalb war der Fehler monatelang unsichtbar.

**Lehre fürs Nächste:** Bei falschen Werten in der DB zuerst fragen, WER den Wert schreibt — App, Trigger auf der Zieltabelle, oder Trigger auf einer abhängigen Tabelle. Und: Sichtbarkeit (Versionsanzeige, Betragsvorschau) hätte die Frage in Minuten statt Stunden beantwortet.

---

## 🟢 Material abgeholt → Bestände in einem Klick (live v0.47.0 · 15.07.2026 — Live-Test durch Daniel ausstehend)
Spec `docs/superpowers/specs/2026-07-15-material-abgeholt-bestand-design.md`, Plan `docs/superpowers/plans/2026-07-15-material-abgeholt.md`. Subagenten-getrieben, 400 Tests grün, 0 Analyze-Fehler.

- **Neue Bestellungen-Liste** `/materialien/bestellungen` (AppBar-Icon 🧾 auf `/materialien`). Schliesst die Lücke, dass gesendete Bestellungen + ihre PDFs bisher **gar nicht mehr auffindbar** waren (`getAll()`/`getById()` waren toter Code). Status-Badge, PDF öffnen, aufklappbar mit „bestellt X · erhalten Y".
- **„Material abgeholt"** (nur bei Status `gesendet`) → Kontroll-Dialog: nach Kategorie gruppiert wie die Bestellung, Checkbox links (default an), Menge vorbefüllt + korrigierbar, Freitext-Positionen ohne `lager_id` ausgegraut → **„Bestände buchen"**. Stimmt alles: einfach bestätigen.
- **„Buchung rückgängig"** (bei `abgeholt`) → Bestände zurück, Status wieder `gesendet`.
- **Restmengen** brauchen keine Extra-Mechanik: der Artikel bleibt unter Mindestbestand und steht via Generated Column `bestand_niedrig` automatisch wieder auf der nächsten Bestellliste. Teillieferungs-Verfolgung bewusst NICHT gebaut (YAGNI).
- **Migration 141:** Status `abgeholt`, `abgeholt_am`, `menge_erhalten numeric(10,2)` + zwei **atomare RPCs** (`material_bestellung_abholen`/`_rueckgaengig`, SECURITY INVOKER, relatives `bestand_aktuell + delta`).

**Wichtigster Fund im Review:** Der Status-Guard war zuerst ein nacktes `SELECT` → TOCTOU-Race: zwei gleichzeitige Aufrufe (Doppeltap) hätten beide passiert und die Bestände **doppelt gezählt** (lautlos, Rückgängig nimmt nur die Hälfte). Gefixt mit `FOR UPDATE` auf der Bestellzeile. Zusätzlich geschlossen: stille Null-Buchung bei falschen `p_mengen`-Keys, stiller 0-Zeilen-Update bei nicht zugreifbarer `lager_id`, ungeschützter Positions-Ladefehler (Netz weg im Heineken-Lager), und „angehakt aber nicht gebucht" bei Komma-Eingabe (Gboard liefert `1,5`).

**Bekannte Grenzen (bewusst):** `digitsOnly` im Mengenfeld → keine Dezimalmengen (deckt sich mit dem bestehenden Bestell-Screen); `GREATEST(0,…)` beim Rückgängig klemmt lautlos bei 0; `p_mengen=NULL` würde den Key-Guard umgehen (vom Dart-Client aus unmöglich, da `abholPayload` immer eine Map liefert).

**Offen:** Live-Test durch Daniel (siehe Plan, Task 7 Step 9).

---

## 🟢 camt-Test 15.07. zurückgerollt — Gelerntes BLEIBT (Abend 15.07.2026)
Rollback ausgeführt und verifiziert: camt-Buchungen 0, Rechnungs-Status auf Baseline (bezahlt 3508), camt-Dateien 12, Prüfliste 4 mit zurückgesetztem Status.
**Bewusst erhalten (Entscheid Daniel):** 4 gelernte Zahlernamen (`betriebe.zahler_aliase`) UND 16 camt-Regeln (14 Baseline + 2 neue) — beides ist Wissen, das jeden weiteren Import einfacher macht. Die 38 nachgetragenen Rechnungen hat das Rollback nicht angefasst (Versanddatum intakt).
Runbook: `scratchpad/ROLLBACK_camt_20260715.md`.

**Neu an der Prüfliste (v0.47.2):** „Regel anlegen" befüllt die IBAN vor (Migration 142: `camt_pruefliste.partei_iban` + `beleg_ref` — der Parser las sie, die Tabelle speicherte sie nie) und **bucht die Zahlung mit** („Speichern & buchen"). Das ist nötig, nicht bequem: `bereitsVerarbeitet` enthält ALLE Prüflisten-txKeys unabhängig vom Status → die Transaktion ist dauerhaft blockiert, eine neue Regel hätte sie NIE erfasst; bloss ausblenden = Zahlung still nie gebucht. Ausserdem: IBAN-Vergleich normalisiert (`RegelMatcher.normIban`) — eine gruppiert eingetippte IBAN („CH04 3000 …") hätte vorher nie gematcht.
**Zu wissen:** Sind Name UND IBAN gesetzt, gilt **oder**, nicht und — die Regel feuert schon beim Namens-Treffer.

---

## 🟢 camt-Abgleich Verbesserungs-Paket (LIVE v0.46.26 · 14.07.2026 — Test-Daten zurückgerollt, Re-Test morgen)
Ganztägige Iteration am camt-Kundenzahlungs-Abgleich (v0.46.21 → v0.46.26), TDD (28 camt-Tests grün). **Test-Buchungen abends komplett zurückgerollt** (8 Buchungen gelöscht, 7 Rechnungen auf Baseline, 6 gelernte Aliase + 9 camt_dateien + 1 Prüflisten-Eintrag entfernt) — DB sauber am Baseline, bereit für Re-Test.

**Umgesetzt & live:**
1. **Matcher-Härtung:** Auto NUR bei QR/SCOR-Referenz + exaktem Namen + gelerntem Alias; alle unscharfen Namens-Treffer → manuell (kein Fehl-Auto wie „Edelweiss Davos AG" → Vals; kein Alias-Festschreiben).
2. **Zahlungseingänge nach Datum absteigend** (Manuell-Dialog + ⚪-Liste).
3. **Vermerk-Parser** (`vermerk_parser.dart`, TDD): erkennt (a) Rechnungsnummer `YYYY-MM-NNNN` (Bindestriche, direkter Forderungs-Match), (b) **Betriebnummer** `NNNN_yyyy_MM_dd` (Davos Klosters, z. B. `0151_2026_04_04` = Heineken-Nr 0151 = Armando) → Routing über `matchByNummer` inkl. **`heineken_nr`**, Datum wählt Forderung vor. Nur Vorauswahl, kein Auto.
4. **Mehr Zahlungs-Infos** (Einzahler/Adresse/Bemerkung) + **PDF-Link** zur erfassten Rechnung (Manuell/⚪) bzw. Beleg (Übriges/Kreditor).
5. **Nicht-zugeordnet gruppiert** nach Einzahler (Ausnahme Davos Klosters/Weisse Arena einzeln); Gruppen-Kopf tippbar → **Mehrfach-Zahlungen + Suche**-Dialog.
6. **Migration 139** (Rundungs-Trigger 5-Rappen, Backfill Live-Periode) + **Migration 140** (`beleg_typ='camt053'` erlaubt → Übriges-Buchung ohne PostgrestException).

**Offen / morgen (Re-Test):**
- Prüfen: routen die 3 „Davos Klosters"-Zahlungen jetzt via `heineken_nr` zum richtigen Betrieb? Falls welche in „Nicht zugeordnet" bleiben → **genaue Bemerkung** an Claude (drittes Format).
- Optional: Davos Klosters/Weisse Arena auch als tippbare Gruppe (Mehrfach-Dialog) statt einzeln — 1-Zeiler, auf Wunsch.
- Reparaturplan Buchhaltung (Excel-Zahlungen/camt-Import) via `/buchhaltungsplan` — nach abgeschlossenem camt-Test.

---

## 🟢 Karten-Hintergrund + Handy-Standort (live v0.26.1–v0.26.4 · 10.07.2026)
- [x] ✓ Umschalter **Luftbild ↔ Strassenkarte** (swisstopo) in Betriebe- + Event-Karte (kostenlos/legal, kein Google-Tile-ToS-Verstoss).
- [x] ✓ **Handy-Standort** als blauer Punkt + weiss/blauer „Mein Standort"-Zentrier-Button; Filter „Inaktive/geschl." entfernt (inaktive/geschlossene auf der Karte generell ausgeblendet).

---

## 🟢 Betrieb-Lifecycle & Auto-„mein Kunde" (live v0.26.0 · 10.07.2026)
- [x] ✓ **Auto-„mein Kunde"**: reine Funktion `istMeinKundeVorschlag(status, zapfsysteme)` — inaktiv/geschlossen → false, sonst Konventionell/Orion → true. Greift im Formular bei Status-/Zapfsystem-Wechsel (manueller Override bleibt).
- [x] ✓ **Bereinigung (Migration 127)**: Clavadeleralp & Weissfluhjoch (Saisonbetriebe, fälschlich inaktiv) → aktiv; AMERON, Valentinos + 104 geschlossene → mein Kunde=false. Saisonbetriebe geschützt.
- [x] ✓ **Dauerhafte Schliessung**: Status „geschlossen" im Formular + Schliessungsgrund (Umnutzung/Abbruch/Konkurs/Sonstiges) + -datum; im Detail angezeigt.
- [x] ✓ **Sichtbarkeit**: Betriebe-Liste default nur aktive; Karte nur aktive/saisonpause + Filter-Chip „Inaktive/geschl.".
- [x] ✓ Qualität: subagent-getrieben, neue TDD-Suite (7 Tests), **263 Tests grün**, Web-Build sauber.
- [x] ✓ **Live geprüft** (10.07.2026): Formular-Auto-„mein Kunde" + Override, Schliessungsfelder, Liste/Karte-Sichtbarkeit — alles funktioniert.

---

## 🟢 Öffnungszeiten von Website (live v0.35.0 · 11.07.2026)
- [x] ✓ **AI-Website-Fallback für Öffnungszeiten:** Google Places hat für viele kleine Betriebe keine Öffnungszeiten (verifiziert: Pagigerstübli → Adresse/Tel/Website/Koordinaten ja, aber keine `regularOpeningHours`). Neuer Button **„Öffnungszeiten von Website"** im Betrieb-Formular → Edge-Function `parse-oeffnungszeiten` liest Startseite + Kontakt-/Öffnungszeiten-Unterseiten, Claude extrahiert Öffnungszeiten + Ruhetage ins App-Format → derselbe Bestätigungs-Dialog wie bei Google (Häkchen). Reine Funktion `oeffnungszeitenAusWebsiteJson` (TDD, 3 Tests). Smoke-Test Pagigerstübli: Mi–Sa 09–22, So 09–21, Ruhetage Mo+Di (Konfidenz 1). **🟡 Offen:** an weiteren Betrieben mit Öffnungszeiten-Seite durchprobieren; ggf. Prompt nachschärfen bei Mittagspausen/Sonderzeiten.

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
---

## 🟢 Events-Feinschliff (live v0.22.0 · 10.07.2026)
- [x] ✓ **„Montage generieren"** vom Zeit-Tab ins **3-Punkte-Menü** oben rechts verschoben (Zeit-Tab zeigt nur noch Total-Chip).
- [x] ✓ **PDF-Vorschau vor Versand** im Abschluss-Sheet (Button „PDF-Vorschau", `Printing.layoutPdf`).
- [x] ✓ **Professionelleres Abschluss-PDF** (dunkle Sektions-Header, Zusammenfassungs-Box, Zebra-Tabellen mit dunkler Kopfzeile, Fußzeile mit Datum + Seitenzahl).
- [x] ✓ **Material↔Lager im Pikett-Einsatz** (Migration 124: `event_einsaetze.material_id` + `material_menge`): Lager-Artikel per Autocomplete + Menge; Bestand (`bestand_aktuell`) wird **beim Anlegen** abgebucht (keine Storno-Automatik bei Bearbeiten/Löschen). Freitext-Material bleibt.
- [x] ✓ Qualität: subagent-getrieben (5 + Verifikation), finaler Review **APPROVED**, 244 Tests grün, visuell geprüft (Menü, Vorschau-Button).
---

## 🟢 Events-Modul — Phase E5 (live v0.21.0 · 10.07.2026) — Events-Modul E1–E5 KOMPLETT
Spec `docs/superpowers/specs/2026-07-10-events-e5-design.md`. **Abschluss-Mail** nach dem Event:
- [x] ✓ **Abschlussbericht als PDF** (ohne CHF): Zusammenfassung (Stände/Anlagen-in-Betrieb/Einsätze/Total-Std), Stände mit Anlagen + Inbetriebnahme, Zeit & Aufwand gruppiert nach Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen), Pikett-Einsatzliste. Sonderzeichen (`✓`/`–`/`—`) auf ASCII sanitisiert (Helvetica-Font).
- [x] ✓ **Empfänger-Sheet** (Menüpunkt „Abschluss-Mail senden" im 3-Punkte-Menü): Eventverantwortlicher (`event_heineken`) + RSL automatisch vorgeschlagen, mit E-Mail vorangehakt, ohne E-Mail ausgegraut; weitere Kontakte + freie Mail-Adresse; Versand kommasepariert in einem Aufruf (`send-pdf-mail`).
- [x] ✓ **Scharfstellung:** neuer MailConfig-Bereich `event` (`eventScharf=false`) → Testmodus geht an dich (dani.proyer@gmail.com), Sheet zeigt Hinweis. Keine DB-Migration.
- [x] ✓ Qualität: subagent-getrieben (6 Tasks), finaler Branch-Review **APPROVED**, 244 Tests grün (7 neue). Visueller Web-Test: Menü → Sheet mit RSL-Vorschlag (beat.joerg@heineken.com vorangehakt) + Testmodus-Hinweis, PDF fehlerfrei gebaut.

---

## 🟢 Events-Modul — Phase E4 (live v0.20.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e4-design.md`. Event-Detail jetzt mit **5 Tabs** (Kontakte | Stände | Einsätze | **Zeit** | Dokumente):
- [x] ✓ **Zeit-/Spesenerfassung** (neue Sync-Vertikale `event_aufwand`, Migration 123): Zeilen mit Datum + Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen) + Notiz + Stunden. Neuer Tab „Zeit" mit Total-Stunden-Chip, Erfassungs-Formular, Bearbeiten/Löschen. Spesen werden als zusätzliche Stunden verrechnet (kein CHF-Feld).
- [x] ✓ **Auto-Montage-Generierung**: Button „Montage generieren" aggregiert die Zeit-Zeilen **pro Eventtag** (≤5 Slots, >5 Tage → 4 Tage + „Weitere Tage") und öffnet das bestehende Montage-Formular **vorbefüllt** (Typ Anlass, Betrieb = Veranstaltungs-Betrieb, Startdatum, Slots, Stundensatz aus Preisliste). Du prüfst + speicherst → normaler Heineken-Abrechnungsfluss. Pikettdienst ist ein eigener Zeitblock; die E3-Einsätze bleiben reine Doku (nicht separat verrechnet).
- [x] ✓ Qualität: subagent-getrieben (10 Tasks + Migration), finaler Branch-Review **APPROVED**, 237 Tests grün (5 neue: DTO + 4 Aggregation). Visueller Web-Test: 5 Tabs, Zeit erfassen/Total, „Montage generieren" → Formular korrekt vorbefüllt (Fr 10.7. 16h · Fr 24.7. 8.5h → 24.50h × 80 = 1960 CHF).
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
- [ ] **🟡 Testdaten aufräumen:** Stand **Signina Bar** hat für den Karten-Test gesetzte GPS-Koordinaten (46.7355 / 9.1378, Vella) — vor Ort neu erfassen/überschreiben.

**Nächste Phase:** **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL, MailConfig-Bereich `event`) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E2 (live v0.18.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e2-design.md`. Event-Detail jetzt mit **3 Tabs** (Kontakte | Stände | Dokumente):
- [x] ✓ **Stände** pro Event-Jahr mit **Schankanlagen** (Typen: Oberthekengerät/OT, Hollandbuffet, Ausschankwagen, Sonstige) — dynamische Anlagen-Zeilen im Stand-Formular, Zusammenfassung „7× OT · 1× Hollandbuffet". Vorjahres-Übernahme (Checkbox im Event-Formular + Menü im Tab, Merge case-insensitive über Stand-Namen).
- [x] ✓ **Dokument-Ablage** pro Event-Jahr: PDF hochladen (Lageplan, Verteilung …) in privaten Storage-Bucket `event-dokumente`, ansehen (signed URL, PDF-Viewer), löschen. Migration 120 (3 Tabellen + Bucket + RLS).
- [x] ✓ Qualität: subagent-getrieben (10 Tasks), finaler Branch-Review **APPROVED** (kritischer Tab-Umbau: Kontakte-Tab unverändert; serverId→Anlagen-Kette + Native-Delete W1 sauber), 228 Tests grün (4 neue). Visueller Web-Test: Tabs, Stand+Anlagen anlegen, Dokumente-Tab bestätigt.

**Nächste Phasen:** **E3** Inbetriebnahme-Checkliste + GPS-Standorte der Stände + Karten-Tab (flutter_map + swisstopo-Luftbild, kein API-Key) + Pikett-Einsätze (Stand + Beschreibung + 1 Material) · **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL + optional, MailConfig-Bereich `event`) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E1 (live v0.17.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-09-events-e1-design.md`, Plan + Ablauf-Kontext `Prompts/07_Events_Ablauf.txt`. Neues Modul: Dashboard-Kachel **Events** → Event-Jahre («Albani Fest 2026»):
- [x] ✓ **Event-Jahr-Entität** (`events`, Migration 119): referenziert Veranstaltungs-Betrieb (zapfsysteme `Veranstaltungen`), Jahr + Termin, Status abgeleitet (kommend «in X Tagen»/laufend/vorbei/Termin offen). Abrechnung bleibt unverändert bei Montage «Anlass».
- [x] ✓ **Kontaktliste pro Event-Jahr** (`event_kontakte`): Rolle auf der Zuordnung (Eventverantwortlicher, RSL, OK, Bau, Stand, Monteur, Stardrinks, Sonstige), Bemerkung, Gruppierung; Kontakte bleiben globale Personen. **Vorjahres-Übernahme** (Checkbox beim Anlegen + Menü, Merge ohne Duplikate).
- [x] ✓ **WhatsApp + Anruf** direkt aus der Liste (wa.me mit CH-Normalisierung, getestet: +41 79 885 20 88 → wa.me/41798852088).
- [x] ✓ Qualität: subagent-getrieben (9 Tasks, je Spec-+Qualitäts-Review), finaler Branch-Review APPROVED, 224 Tests grün (15 neue), visueller Web-Test komplett (Anlegen, Zuordnen, Übernahme, Löschen). Review-Fixes W1+W2 umgesetzt (Native-Delete serverseitig; `KontaktRepository.save` generiert jetzt Client-UUID).
- [ ] **🟡 Bekanntes Verhalten (Multi-Device, W3):** Legen zwei Geräte offline dasselbe Event-Jahr an, scheitert der zweite Push am UNIQUE-Constraint dauerhaft still (`isSynced=false` bleibt). Bei Ein-Personen-Nutzung akzeptabel; fixen falls je zweites Gerät aktiv schreibt.

**Nächste Phasen:** **E2** Lageplan-PDF + Stände + Anlagen pro Stand (Beispieldateien in `00_Event/`, nicht versioniert) · **E3** Inbetriebnahme + GPS-Standorte + Karten-Tab (flutter_map + swisstopo-Luftbild, kein API-Key) + Pikett-Einsätze (1 Material-Slot) · **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL + optional, MailConfig-Bereich `event`).

---

## 🟢 App-Optimierung — Paket 06 (P1 Quick-Wins, live v0.16.20 · 07.07.2026)
Optimierungspaket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Spec/Plan in `docs/superpowers`. P1 = 7 Quick-Wins:
- [x] ✓ **Eigenaufträge:** Status-Filter entfernt.
- [x] ✓ **Störungen:** Filter-Sheet nur noch **Anlagentyp + Km-Abrechnung** (Status raus, auf Wunsch), Badge-Zähler, Anlagentyp-Chips kapitalisiert.
  - [x] ✓ *(v0.45.3 · 11.07.2026)* Dritter Filter **Störungsbereich** (Zapfhahn/Leitung/Kühler/Zapfkopf/Gas, mit Nummer „1 - Zapfhahn") ergänzt; die drei Dropdowns (Typ · Art · Bereich) jetzt als **gleich breite, zentrierte Spalten** (`Expanded`+`isExpanded`, Ellipsis) — Pixel-9-optimiert, kein Überlauf. Isoliert am Web-Build (390px, Worst-Case) verifiziert.
  - [x] ✓ *(v0.46.6 · 12.07.2026)* **Perf Reinigungen laden:** `ReinigungRepository._pagedByUser` lädt die ~8621 Zeilen (Web) nicht mehr in 9 **sequenziellen** 1000er-Seiten, sondern erste Seite + Folgeseiten in **parallelen Wellen** (`Future.wait`, Batch 8) → statt 9 Round-Trips nur noch ~2 Wellen. `.order('id')`-Tiebreaker macht Seitengrenzen deterministisch. Kleine Abfragen (Anlage/Betrieb) bleiben 1 Request. **🟡 Offen:** falls noch zu langsam → Spaltenreduktion oder Zwei-Stufen-Laden (aktuelles Jahr sofort, Historie lazy) als Folgeschritt.
  - [x] ✓ *(v0.46.5 · 12.07.2026)* **Betriebe Regionenfilter — Kategorie „Keine Region":** neue Filter-Option (Sentinel `__keine_region__`) zeigt Betriebe ohne zugewiesene Region (aktuell 109 gesamt, davon 5 operativ). Gilt für Liste + Karte (`_regionPasst`-Helfer). In der Liste greift zusätzlich der Status-Filter.
  - [x] ✓ *(v0.46.4 · 12.07.2026)* **Bugfix Tourenplan Reihenfolge:** Plan-Reihenfolge entsprach nicht der Eingabe. Ursache: Tagesplan wurde gefiltert angezeigt, das Drag-Reorder operiert aber auf dem vollen State mit den **gefilterten Indizes** → Reorder traf falsche Einträge. Fix: Tagesplan zeigt den **vollständigen Plan ungefiltert** in exakt der Eingabe-/manuellen Reihenfolge; Filter (Region+Fälligkeit) gelten nur noch für die „Fällig"-Liste.
  - [x] ✓ *(v0.46.3 · 12.07.2026)* **Bugfix Tourenplan „gespeichert aber leer":** geladene Einträge wurden ausgeblendet, weil (a) `faelligkeit` beim Speichern nicht mit-serialisiert wurde (→ null) und (b) der Tagesplan denselben **Fälligkeitsfilter** (Standard überfällig+fällig) wie die Fällig-Liste anwandte. Fix: `faelligkeit`/`datum`/`zielDatum` mit-serialisieren **+** Tagesplan nur noch nach **Region** filtern (der Fälligkeitsfilter triagiert nur die Fällig-Liste). committete Einträge bleiben immer sichtbar.
  - [x] ✓ *(v0.46.2 · 12.07.2026)* **Bugfix Tourenplan Auto-Save:** Tagespläne wurden teils nicht gespeichert. Ursachen (client-seitig; DB war ok, gestern noch Saves): (1) **Lade-Race** — Einträge vor Rückkehr des async Tages-Fetch wurden von dessen `resetLeer`/`setFromGespeichert` überschrieben + Save abgebrochen; (2) **veralteter Cache** — `gespeicherterTagesplanProvider` nach Save nie invalidiert; (3) **verschluckte Fehler** (fire-and-forget). Fix: Notifier beansprucht den aktiven Tag sofort (`_datum`, Race-Guard im Screen), invalidiert den Cache nach Save, loggt Fehler. Regressionstest (2) grün.
  - [x] ✓ *(v0.46.1 · 11.07.2026)* **Betriebe (Liste):** die drei Filter **Kunden · Status · Zapfsysteme** als gleich breite Spalten nebeneinander (`Expanded`+`isExpanded`); dafür `AppFilterMultiDropdown` um `isExpanded` erweitert (füllt Spalte, Pfeil rechts, Ellipsis). Karte-Ansicht bleibt Kunden + „Nur fällige". Multi-Menü-Öffnen im neuen Pfad verifiziert.
  - [x] ✓ *(v0.46.0 · 11.07.2026)* **App-weiter dezenter Filter-Rahmen:** neues `FilterChrome` (weiße Füllung + graue Umrandung `AppColors.filterBorder`) zentral in `AppFilterDropdown`/`AppFilterMultiDropdown`/`AppJahrMonatLeiste` → deckt 28 Filter über die geteilten Bausteine ab. Zusätzlich 10 Einzelfall-Filter umgestellt (Auswertung, Buchungen-Liste, Bericht-Datumspicker, Heineken-Raster, Lohnlauf, MwSt-Abrechnung inkl. Weißtext-Fix). Abdeckung per **Audit-Workflow** (6 Agenten) verifiziert; visuell am 390px-Web-Build geprüft. SegmentedButtons/Suchfelder/Formularfelder bewusst ausgenommen (haben eigenes Chrome).
- [x] ✓ **Reinigung:** Chip „Protokoll" statt „Foto"; **Service-Art** (Klartext) statt rohem `serviceTyp`; Zeiterfassung **kompakt einzeilig** (Datum/Start/Ende) in **Formular UND Detail-Übersicht**.
- [x] ✓ **Kontakte:** Heineken-Rolle **„Stardrinks"** (Migration 117).
- [x] ✓ **Betriebsferien:** 3 → **5 Slots** (Migration 118); Formular dynamisch (nur belegte Zeilen + „Weitere Ferien"); Detail zeigt Ferien 1–5; zentraler `betrieb_ferien.dart`-Util + **Bugfix** (`isBetriebOffen`/`_isBetriebAktiv` prüften bisher nur Ferien 1) → Touren/Termine/Heineken-Raster umgestellt; 8 neue Unit-Tests.
- [x] ✓ **Visueller Check Betriebsferien (Handy)** — erledigt (User bestätigt 12.07.2026).

Vorgehen: subagent-getrieben (Phase A 5 Tasks parallel, Phase B 5 Ferien-Tasks sequenziell), je Task Spec- + Qualitäts-Review, finaler Branch-Review **APPROVED** (Web-Sync der neuen Ferien-Felder verifiziert), 210 Tests grün. **Migrationen 117 + 118 sind produktiv angewendet.**

**Aus Paket 06 inzwischen erledigt:** Betriebe (Ferien-Zeile + Google-Übernahme v0.25), Reinigung (Service-Art/Zeiterfassung/Protokoll-Chip), Störungen/Eigenaufträge-Filter, Kontakte (Stardrinks + Event-Struktur), **Events-Feature komplett** (E1–E5: Kontakte/Telefonliste, Einsätze+Material, Abschluss-Mail an RSL/Eventverantwortlichen).

**🔴 Aus Paket 06 noch offen (echte Restpunkte):**
- [x] ✓ **Anlagen-Screen + Steckbrief-PDF** (live v0.27.0 · 10.07.2026): Dashboard-Kachel „Anlagen" + Kennzahlen-Kopf (aktiv/nach Typ/überfällig) im vorhandenen `/anlagen`-Screen; **Steckbrief-PDF pro Anlage** (Grunddaten + Fotos aus `anlagen_fotos` + Bierleitungen) mit **Teilen** + **Mail an RSL** (neue Heineken-Zuweisung `rsl`, MailConfig-Bereich `anlage`). Subagent-getrieben, 271 Tests grün. **✓ Scharf** (11.07.2026, User bestätigt „Steckbrief ist schon scharf"; funktioniert). Niederdruck im PDF jetzt mit 1 Kommastelle (v0.43.1).
- [x] ✓ **Reinigung QR-Firmenkonto-Link** (live v0.28.0 · 10.07.2026): Button „QR-Zahlung" im Reinigungs-Formular → Dialog mit Swiss-QR aufs Firmenkonto (Schweizerkreuz), Betrag aus `preisBrutto` vorbefüllt+editierbar. Reine Funktion `swissQrPayload` (TDD) — Rechnungs-QR nutzt sie byte-identisch. **✓ Scan-Test mit Banking-App erledigt** (User bestätigt 12.07.2026).
- [x] ✓ **Tourenplanung T1 — UX & Verhalten** (live v0.29.0 · 10.07.2026): Tagesplan startet **default leer** (Fällig-Liste default überfällig/fällig, andere Kategorien per Filter; Button „Fällige übernehmen"); **Auto-Speicherung** (Speicherbutton entfällt, entprellt); **Ruhetage + Servicezeiten** auf jeder Karte + **Ruhetag-Warnung**; **Inline-Filter** Region + Fälligkeit getrennt (kein Sheet); **grosser Drag-Griff**. Reine Helfer `touren_anzeige.dart` (16 Unit-Tests). **🟡 Offen:** visueller Live-Check `/touren` (Preview-Harness konnte canvaskit nicht rendern).
- [x] ✓ **Tourenplanung T2 — Fälligkeits-Logik & Auto-Termine** (live v0.30.0 · 10.07.2026): Endreinigung/Eröffnung aus Saison-/Ferien-Übergängen des Betriebs abgeleitet (`touren_saison.dart`, kanonischer „offen"-Begriff, 16 Unit-Tests); Endreinigung nur bei Saisonende / Ferien ≥ 21 Tage; Vorlauf 7 Tage; Sektion „Automatische Termine" im Tagesplan-Tab (letzter offener Tag vor Schliessung / erster nach Öffnung, Ruhetage/Ferien übersprungen) mit +übernehmen/alle übernehmen. **🟡 Offen:** visueller Live-Check `/touren` (Saisonübergänge).
- [ ] **Termine — komplette Überarbeitung = Google-Kalender-Hybrid** (Recherche+Entscheidungen in `docs/superpowers/specs/2026-07-10-google-kalender-recherche.md`). Teil-Pakete:
  - [x] ✓ **G1 — Verbindung & Datenmodell** (live v0.31.1 · 11.07.2026, **verbunden verifiziert** mit dani.proyer@gmail.com, Refresh-Token gespeichert): OAuth serverseitig (Edge Functions `google-oauth-exchange`/`google-calendar-disconnect`, PKCE, Token nur in `google_calendar_tokens` RLS-gesperrt, Status-Tabelle), Einstellungen „Google Kalender verbinden/trennen", `Termin`-Mehrfach-Erinnerungen (jsonb + Reminder-Editor, 16 Tests). Fix unterwegs: `index.html`-Cache-Buster erhält jetzt OAuth-`?code/?state`. **🟡 Offen:** realer Erinnerungs-Empfang wird mit G2 getestet (sobald Events geschrieben werden).
  - [x] ✓ **G2 — Push App→Google** (live v0.32.0 · 11.07.2026): Mapping-Tabelle `google_calendar_events`, Edge Function `google-calendar-sync` (Access-Token-Refresh, push + reconcile, Waisen löschen), Sofort-Push nach Speichern/Löschen (Termin nur `status=geplant`, Pikett/Event), Ziel = **Haupt-Kalender** (Präfix „SBS · ", Termin grün / Pikett rot / Event gelb), Erinnerungen (Termin aus Array, Pikett/Event email+popup 1 Tag), Button „Jetzt abgleichen" in Einstellungen. **Abweichung:** kein pg_cron (bräuchte service_role-Key/Secret) — reconcile per Button; Auto-Cron optional dokumentiert. **🟡 Offen:** Live-Test (Termin/Pikett/Event → Google, ändern/löschen, Erinnerungs-Empfang Pixel 9).
  - [x] ✓ **K1 — App-Kalender abgelöst → Google Kalender** (live v0.33.0 · 11.07.2026): Entscheidung des Users — Google Kalender wird **der eine Kalender** (App-Kalender-Design überzeugte nicht). Komplettes **Termin-Modul entfernt** (Screens/Formular/Repo/Provider/Mapper/DTO/Locals/Web-Stubs/Export + `ReminderService`/`ReminderTime`/`erinnerung_util` + 3 Routen + Sync-Tier + Isar-Methoden + Schema), Dashboard-Kachel „Termine" → **„Google Kalender"** (öffnet calendar.google.com). Pikett & Events bleiben Geschäftsobjekte und pushen weiter (G2). Neu: beim **Speichern eines Betriebs mit Saison/Ferien** kommt ein **Bestätigungs-Dialog** (Eröffnung/Endreinigung, Häkchen default an) → nach Bestätigung landen die Reinigungen im Google Kalender (grün, Erinnerung E-Mail+Popup 1 Tag vorher). Reine Funktion `betriebReinigungen` (7 TDD-Tests), Edge-Function-Aktion `sync_reinigungen` (entity_type `betrieb_reinigung`, Migration 132 entity_id→text), reconcile lässt Reinigungen unangetastet. 311 Tests grün, analyze/Web-Build sauber. **🟡 Offen (Live-Test, User):** Betrieb mit Saison/Ferien speichern → Dialog erscheint → in Google eintragen → Termine + Erinnerung prüfen; Betrieb ohne Google-Verbindung → kein Dialog; Dashboard-Kachel öffnet Google Kalender.
  - **K2 — Bestehende Google-Termine den Betrieben zuordnen & taggen.** Spec `docs/superpowers/specs/2026-07-11-google-kalender-k2-design.md`. Zweistufig (User-Entscheid: konservativ, Farbe+Erinnerung+Tag, Zukunft+jüngste Vergangenheit, Lavendel colorId 1):
    - [x] ✓ **K2a — Kalibrier-Scan** (live v0.34.0 · 11.07.2026): read-only Edge-Aktion `scan_manual` (`events.list`, paginiert, `singleEvents`, überspringt SBS-getaggte) + reine Matching-Funktion `google_termin_match.dart` (Name + **harte Ort-Bestätigung**, Umlaut-/Slash-/Davos-Normalisierung, Tippfehler-Toleranz, nur genau-1-Treffer = eindeutig; 12 TDD-Tests aus echten Kollisionen Alpina×4/Calanda/Bernina-Bar). Neuer Screen (Einstellungen → „Bestehende Termine zuordnen"): Zeitraum (Default heute…+2 Jahre), Scan-Button, Statistik-Chips, Bucket-Liste. **Ändert nichts in Google.**
    - [x] ✓ **Matching v2** (v0.36.0, nach Live-Test kalibriert): Anker-Token statt Vollname (Gattungswörter Gasthof/Pizzeria/Openair toleriert), kompakte Orte (BadRagaz↔Bad Ragaz), Unique-Name-ohne-Ort (matcht auch wenn Ort im Titel fehlt/abweicht, sofern Name global eindeutig — z.B. Pagigerstübli, Fasan, Openair Val Lumnezia), Bernina/Bernina Bar via Vollname-Tiebreak getrennt; **Privat ausgeblendet** (Geburtstag/Ferien), **Pikett erkannt** (eigener Chip). 23 TDD-Tests (echte Fälle). **Daten-Hinweis:** einige Betriebe haben abweichende Orte ggü. Kalender (Pagigerstübli=Arosa, Fasan=Seewis Dorf) — matcht trotzdem, ggf. Ort in Stammdaten prüfen.
    - **🟡 Offen (User):** erneut scannen + Buckets prüfen → dann K2b.
    - [x] ✓ **K2b — Taggen + Rückgängig** (live v0.37.0 · 11.07.2026): Migration 133 (`entity_type` `betrieb_manuell`) + 134 (`original_color_id`/`original_reminders`). Edge-Aktionen `apply_tags` (**nur PATCH**: colorId 1 Lavendel + Erinnerung email+popup 1440 + `extendedProperties`-Tag; Titel/Notizen/Datum NIE) + `untag_manual` (**voll reversibel** — Original-Farbe/-Erinnerung werden beim Taggen gesichert und beim Untag exakt wiederhergestellt). Häkchen-Freigabe-UI: eindeutige vorangehakt, mehrdeutige mit Betrieb-Dropdown, kein-Treffer/Pikett ausgegraut; „X Termine taggen" + „Tags entfernen"; getaggte verschwinden aus der Liste. **Adversarial verifiziert** (4-Lens-Workflow): Titel/Notiz-Sicherheit + Client-Logik sauber; die anfänglich gefundene Reversibilitäts-Lücke (Original nicht gesichert), PATCH-vor-Mapping-Waisen und colorId:null-Kopplung wurden vor Deploy gefixt (Rollback bei DB-Fehler, colorId-Retry-Netz). **🟡 Offen (User-Live-Test):** eindeutige taggen → Lavendel+Erinnerung in Google prüfen; „Tags entfernen" → Ursprungszustand zurück; Spezialfall colorId:null (Termin ohne Original-Farbe) beim Untag beobachten.
    - [x] ✓ **Feinschliff (v0.37.1):** Fuzzy-Anker-Fix (Token „crusch"~„grusch" machte Ustria Crusch Alva zum Geister-Kandidat → „Grüsch - Fasan" jetzt eindeutig; Unique-Name-ohne-Ort zählt nur EXAKTE Anker); mehrdeutige Einträge (z.B. „Davos - Seehof und Chesa") per **FilterChips mehrfach wählbar** → beide Betriebe taggbar (betrieb_id kommasepariert in extendedProperties).

---

## 🔴 OFFEN — relevant

### Auswertung Umsatz/Arbeiten (Buchhaltung) — NEU 11.07.2026
Spec `docs/superpowers/specs/2026-07-11-buchhaltung-auswertung-design.md`. App-Pendant zum Excel-Blatt „Auswertung" (`00_SBS_Projer_70`).
- [x] ✓ **Phase 1 (live v0.45.2 · 11.07.2026, User bestätigt „klappt"):** Neuer Screen `/buchhaltung/auswertung` — Umsatz/Arbeiten nach Jahr+Monat, 3 Modi (Jahr / Jahre / **Monatsvergleich über Jahre**), Charts (`fl_chart`, grün dezent), **netto/brutto umschaltbar**, professionelle Tabelle (Monat·Anzahl·Kunde·Heineken·Total, Zeile aufklappbar → Kategorien). Rein **live** aus App-Daten (Reinigung volle Historie 2019+, übrige Kategorien + Heineken-Split ab Dez 2025). Kunde/Heineken-Split via `betrieb.rechnungsstellung=='heineken'`. Reines Aggregat TDD (9 Tests), adversariale Review (5 Low-Funde gefixt). **Render-Bug** (Charts+Tabelle unsichtbar) per Browser-Reproduktion isoliert: KPI-`Row(crossAxisAlignment.stretch)` in `ListView` → unendliche Höhe → blockierte Folge-Kinder (Release verschluckt Assert) → Fix `IntrinsicHeight` (v0.45.2). **🟡 Offen (User):** Live-Zahlen gegen Excel abgleichen (v.a. ein 2026-Monat wo alle Daten da sind).
- [x] ✓ **Phase 2a — Werkstatt-Aufträge backfilled (12.07.2026):** Störung/Montage/Eigenauftrag/Eröffnung+Endreinigung/Pikett aus Excel `00_SBS_Projer_70` für **2019 → 30.11.2025** als echte App-Datensätze importiert = **2'035 Datensätze** (Störung 999, Montage 712, EE 124, Eigenauftrag 108, Pikett 92). Spec/Plan in docs/superpowers (2026-07-12-historie-backfill-werkstattauftraege). Migration 135 (`extern_id`/`quelle` + partielle Unique-Indizes), Import-Skript `Datenbank/import/extract_werkstatt.py` (idempotent, `ON CONFLICT DO NOTHING`, Datumsgrenze <01.12.2025 → null Überlappung, Betrieb-Mapping via `match_betriebe.py`, Waisen→betrieb_id=null). **Abnahme: alle 5 Kategorien × 2019–2024 = 30/30 exakt gegen Excel-„Auswertung"** (Anzahl + Netto). Kanarienvogel-Import fing 2 Bugs: nicht-eindeutige Excel-IDs (deterministischer `#n`-Suffix) + `stoerungsnummer` NOT-NULL (Fallback/Spalte). Idempotenz + Live-Daten-Unberührtheit verifiziert. **KEINE Buchungen** — reine operative Auftrags-Datensätze; die Auswertung liest sie. **🟡 Offen (User):** App-Auswertung am Handy sichten (Modus „Jahre" → Heineken-Spalte 2019–2025 gefüllt).
- [x] ✓ **Bugfix Pagination (v0.46.7 · 12.07.2026):** Nach dem Backfill hatte **stoerungen 1095 Zeilen** → `StoerungRepository.getAll()` (Web) lud ohne Pagination → **PostgREST-1000-Deckel** → Liste UND App-Auswertung verloren still ~95 Störungen (vom User bemerkt). Fix: alle 5 Werkstatt-Repos (stoerung/montage/eigenauftrag/ee/pikett) paginieren jetzt (erste Seite + Folgeseiten parallel, `.order(datum/-_start).order(id)`), analog reinigung_repository. montagen (802) war der nächste Kandidat.
- [ ] **Phase 2b (Folgeschritt):** **BK-Pauschale** nacherfassen (kein Einzel-Beleg im Excel — Quelle klären: Bergkunde-Betriebe × Reinigungen o. per Jahr).
- [ ] **Phase 2c (Folgeschritt):** historische **Heineken-Monatsrechnungen** generieren & gegen die realen PDF-Rechnungen (seit 2019) abgleichen. *Erst hier entstehen ggf. echte Buchungen.*

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
- [x] ✓ **Sicherheit: `verify_jwt=true` für `parse-rechnung` + `parse-beleg`** (11.07.2026): via `supabase/config.toml` (`[functions.*] verify_jwt = true`) + Redeploy. Smoke-Test bestätigt: Aufruf **ohne** Auth → `401 UNAUTHORIZED_NO_AUTH_HEADER`, mit gültigem JWT → erreicht die Funktion (App unverändert). Schützt Claude-/API-Credits gegen offene Endpoint-Aufrufe. **Zusätzlich `auth.getUser()`-Self-Guard** in beiden Functions (11.07.2026): anon-Key-Aufruf → `401 unauthorized`, nur echte eingeloggte User lösen Claude aus. Verifiziert: App sendet User-JWT via `functions.invoke` (wie google-calendar-sync, dessen Guard im K2-Scan funktionierte) → Dokument-Scannen unverändert.
- [x] ✗ **DB-UNIQUE-Index verworfen** (statt umgesetzt): würde den bewussten Sammel-/Teilzahlungs-Pfad brechen (mehrere 'zahlung'-Buchungen je Beleg bzw. gleicher tx_key — Memory-Merksatz). App-seitige Idempotenz-Guards sind hier das richtige Mittel. *Optional offen:* 5-Rappen-/Spesen-Toleranz beim Kreditor-Betragsmatch (heute exakt = sicher).

### Scharfstellung / Live-Betrieb (Buchhaltung 01.07.2026)
Strategie: **Voll-Übernahme** (kein Clean-Start) — Historie lückenlos 27.03.2019→heute im System, Bilanz geht an allen Jahresenden auf, Salden laufen weiter. „Scharfstellen" = nur noch:
- [ ] **Mail-Bereiche scharfstellen:** `mahnwesenScharf` in `mail_config.dart` (steht noch auf Test-Empfänger; `bestellungScharf` seit 14.07. scharf).
- [ ] **camt-Auto-Buchung produktiv** — ⚠️ Korrektur 14.07.: technischer Code-Stichtag ist **11.03.2026** (hardcoded `camt_stichtag.dart`, exakt Excel-Bankende), NICHT 01.07.; „01.07." war nur organisatorisch. Bestätigungs-Flow gebaut, aber **0 von 270 TX gebucht**.
- [ ] **2026 gezielt** auf vereinzelte Test-Buchungen durchsehen (NICHT pauschal; echte Live-Buchungen bleiben).

### Buchhaltung-Vollcheck 14.07.2026 (5-Agenten-Audit App↔Excel↔camt) — Reparaturplan Voll-Übernahme
Befunde komplett in Memory `buchhaltung_vollcheck_2026_07.md`. Positiv: Import 2019–Nov 2025 journalgetreu (ER-Jahre ±0.12 CHF), Live-Ertragsseite ab Dez 2025 vollständig (CHF 0 fehlt), keine Excel↔Live-Doppelbuchung. Kritisch ist die **Geldseite**:
- [ ] **(1) Delta-Import 220 Zahlungseingänge** aus Excel-Journal (01.12.2025–11.03.2026, CHF 55'191.70: 217× 1020/1100 + 3× 1020/1000) — fehlen komplett in DB → Bank-Saldo DB −51'869.44 statt real +3'322.26 (per 11.03., camt-verifiziert). id_bs vorhanden → idempotent per belegnummer. Vorher 1 Zeile klären: `020_2025_12_05_XXX_00007460` (74.60, „UNKLAR welcher Betrieb").
- [ ] **(2) Frischer GKB-camt-Export ab 20.06.2026** ziehen + importieren — ab 21.06. fehlen sogar Rohdaten (24-Tage-Loch, der 01.07. liegt mittendrin). Dedup via txKey, überlappend ok.
- [ ] **(3) Die 270 camt-TX (12.03.–20.06.) im Bestätigungs-Flow verbuchen** (Credits 51'775.75 / Debits 47'694.04): Kundenzahlungen-Abgleich gegen 1'526 offene Rechnungen, Ausgaben-Regeln bestätigen. Prüfliste: die 2 Heineken-Gutschriften (7'104.98 + 5'794.81) matchen jetzt EXAKT auf die heute erstellten Feb+März-Monatsrechnungen.
- [ ] **(4) Zahlungsstatus-Pflege**: 532 Live-Rechnungen ab Dez 2025 (54'571.83) nie auf bezahlt gesetzt (414 Tresen = längst bezahlt) — via camt-Abgleich bzw. Tresen pauschal abhaken (Entscheidung Daniel).
- [ ] **(5) MwSt-Aufsetzpunkt** (Entscheidung Daniel): 2200/1171/1170-DB-Salden sind für die Alt-Ära unbrauchbar (Excel buchte MwSt nur im Hauptbuch-Sheet, nie im Journal → nie importiert; Alt-Ertrag steht brutto, ~83'430 MwSt-Anteil 2019–2025). Empfehlung: Aufsetzkorrektur per 31.12.2025 mit Excel-Bilanzwerten (2200: 17'223.38 / 1171: 1'148.11 / 1170: 3'654.08).
- [ ] **(6) EK/Gewinnvortrag** (Entscheidung Daniel): 13 Jahresabschluss-Buchungen (9000/9100/2970/2980) wurden als storniert importiert → Gewinnvortrag 35'319.11 fehlt, Bilanzgleichung geht nie auf. Entstornieren/nachbuchen ODER dokumentiert als reine Verkehrszahlen-Buchhaltung lassen.
- [ ] **(7) Prozesse ab Stichtag scharf**: Heineken **Juni-Rechnung überfällig** (wartet: mind. 402.14 Reinigungen + 1'620 Pauschalen); Eingangsrechnungs-Scan produktiv nutzen (23 Scans alle „verworfen", Aufwand seit 08.06. NIRGENDS erfasst); Lohnlauf ab Juli via App (`lohn_abrechnungen` leer, bisher nur Excel).
- [ ] **(8) Excel einfrieren**: Journal offiziell per 11.03.2026 (Bank) / faktisch tot seit 08.06.; die 90 Zeilen ohne „Gebucht=X" sind seit 20.06. in der DB → X nachtragen oder Datei archivieren (sonst Doppelimport-Risiko).
- [ ] **(9) Klärungen klein**: 14 Ertrags-Belegvarianten Excel↔App (1'510.30, Rundung/Datum/Preis — Liste beim Audit); Kassenbestand real prüfen (DB 1000 = 23'477.48, ungewöhnlich hoch); `abgerechnet`-Flags 42 Pauschalen + 22 Heineken-Reinigungen Dez–Mai auf true (kosmetisch, verifiziert enthalten).
- [ ] **(10) Hygiene/Code**: 8 von 9 camt_dateien-Duplikat-Archivzeilen löschen; Forderungs-Abgleich-Filter um Mahnstatus erweitern (aktuell nur offen/gesendet); beleg_id-Doppelsemantik dokumentieren (815× reinigungen.id vs. 6× rechnungen.id bei beleg_typ='rechnung'); Heineken 04/2026 Netto/Brutto-2-Rappen (netto als brutto−mwst ableiten).

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
- [x] ✓ Import-Archiv-Dateiname: echter `picked.name` wird jetzt mitgeführt (Fallback `camt.xml`). (11.07.2026)
- [ ] `verbuche` nicht in echte DB-Transaktion geklammert (durch Idempotenz-Guard abgesichert).
- [ ] camt I2: Netzfehler nach Buchung vor Rechnung-Update → verwirrender Prüflisten-Eintrag (kein Doppelbuchen) — Transaktionalität verbessern.
- [ ] camt-Regeln beobachten/verengen: `'abschluss'` (Substring breit); Lohn „daniel proyer" ggf. → IBAN `CH7909000000870500683`; Heineken „heineken" → „heineken switzerland".
- [x] ✓ Saldo-Parsing-Bug gefixt (11.07.2026): `OPBD/CLBD` werden jetzt über `Bal>Tp>CdOrPrtry>Cd` gelesen (vorher immer 0). Feld weiterhin ungenutzt, aber korrekt; 2 Tests ergänzt.
- [ ] Phase 0a Follow-up: 11 alte camt-Vorlagen `ist_aktiv=true` (FK-Schutz) — optional Regeln auf neue Geschäftsfälle umhängen, dann Alt-Vorlagen deaktivieren (tauchen sonst im manuellen Dropdown auf).
- [x] ✓ Hub: toter Code `forderungenProvider` / `mahnwesenDashboardProvider` bereits entfernt (Grep 11.07.2026: keine Vorkommen mehr).
- [x] ✓ **App-weite UI-Vereinheitlichung** (Filter/Dropdowns) KOMPLETT (v0.38–v0.44 · 11.07.2026): einheitliche Filter-Bausteine (`widgets/filter/`: `AppFilterBar`/`AppFilterDropdown`/`AppFilterMultiDropdown`/`AppMultiToggleChips`/`AppJahrMonatLeiste`), **Region-Filter oben rechts (AppBar)** auf allen betrieb-bezogenen Listen (Touren/Betriebe/Anlagen/Reinigungen/Störungen), kompakte (Mehrfach-)Dropdowns statt Chip-Reihen/Sheets/AppBar-Popups, **Zombie-Schutz** überall, **Betrieb-Status-Semantik** (operativ=aktiv+saisonpause via `istBetriebOperativ`), gemeinsames **`AppJahrMonatLeiste`** (8 Screens, −285 Zeilen). Prio 1–5 alle deployed, je adversarial gereviewt (mehrere echte Bugs vorab gefixt). Zusätzlich: **Anlagen-Typ-Filter** (Warmanstich/Kaltanstich/Buffetanstich/Orion), **Steckbrief-Niederdruck** mit 1 Kommastelle, Reinigung-Betrieb-Auswahl nur meine Kunden (operativ).

---

## 🟢 BACKLOG (kein Zeitdruck)
- [ ] **GIS Regionen-Polygone** für 15 Regionen (KML/GeoJSON, WGS84/EPSG:4326). Tools: QGIS / Google Earth Pro / My Maps.
- [ ] **Franchise: geteilte zentrale Regionen (ferne Zukunft).** Heute sind Regionen pro Nutzer (`regionen.user_id` + RLS `user_isolation`), erfassbar über Einstellungen → Regionen (v0.46.20). Sobald mehrere Franchisenehmer sich Regionen **teilen** (N:M Franchisenehmer↔Region, User-Wunsch 14.07.2026): `regionen` zu **zentral gepflegtem, geteiltem Katalog** umbauen — Ownership weg von `user_id`, **Admin-Rolle** schreibt, Franchisenehmer wählen nur aus (`RegionenScreen._kannBearbeiten=false` für Nicht-Admins). Umsetzung bleibt lokal in `RegionRepository` + RLS; `betriebe.region_id`-FK stabil halten (bestehende 14 Regionen in Katalog migrieren, IDs behalten). Zuordnung Franchisenehmer→genutzte Regionen via Verknüpfungstabelle. Erst angehen, wenn 2. Franchisenehmer real ansteht (YAGNI).
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
