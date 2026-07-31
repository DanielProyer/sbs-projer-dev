# Einsatzplanung mit Spracheingabe — Design

**Datum:** 31.07.2026
**Anlass:** Daniel: «die Planung von Störungen und Montagen gefällt mir noch nicht», dazu Zeiterfassung für beide und der Wunsch, **per Spracheingabe zu planen**. Später sollen auch Eröffnungs- und Endreinigungen per Sprache erfasst werden, mit Erinnerungen, damit keine Termine verpasst werden.

---

## 1. Warum die Planung heute nicht funktioniert

Der Befund ist eindeutig — und die Zahlen zeigen, dass die bisherige Lösung im Alltag nicht angekommen ist:

| | |
|---|---|
| Störungen gesamt | **1'108**, davon Status «behoben»: **alle** |
| Montagen gesamt | **810**, davon «abgeschlossen»: **alle** |
| Störungen mit erfasster Startzeit | 109 · **mit Endzeit: 0** |
| Montagen mit erfasster Startzeit | **0** |

Der Schalter «Erst geplant» (v0.60.0) wurde seit dem Einbau **kein einziges Mal** benutzt. Das liegt nicht am Schalter, sondern an vier strukturellen Mängeln:

**a) Es gibt kein Plandatum.** Beide Tabellen haben genau ein Datumsfeld `datum`, im Code ausdrücklich als *Meldedatum* kommentiert. «Gemeldet am» und «geplant für» sind dasselbe Feld — man kann einen Termin gar nicht ausdrücken, ohne das Meldedatum zu verfälschen.

**b) Offene Einsätze erscheinen an jedem Tag.** `faelligeEintraegeProvider` filtert Störungen und Montagen bewusst **nicht** nach Datum. Eine offene Störung steht in der Fällig-Liste jedes beliebigen Tages gleich da. Bei wachsender Zahl offener Einsätze wird die Liste unbrauchbar.

**c) Der Termin lebt im Tagesplan, nicht am Einsatz.** Eine Uhrzeit lässt sich nur als `ankerZeit` am **Tagesplan-Eintrag** setzen. Nimmt man den Block aus dem Plan, ist die Uhrzeit weg — sie steht nirgends am Störungs-Datensatz. Plan und Einsatz sind zwei getrennte Welten ohne Rückkopplung.

**d) Zeiterfassung existiert nur auf dem Papier.** `uhrzeit_ende` und `dauer_minuten` gibt es in beiden Modellen, werden aber von keinem Formular geschrieben. Bei Störungen erfasst ein Freitextfeld den «Störungseingang» — die 109 vorhandenen Werte sind uneinheitlich (am 30.07. tragen zwei verschiedene Störungen dieselbe Zeit 11:43, das ist eher der Erfassungs- als der Anrufzeitpunkt).

**Wichtige Entwarnung zur Abrechnung:** `dauer_minuten` ist bei Störungen, Montagen und Reinigungen eine **gerechnete** Spalte (Ende minus Start). Abgerechnet wird davon unabhängig — bei Montagen über `dauer_stunden` und `stundensatz`, bei Störungen über Pauschalen (`preis_basis`, Störungsbereiche, Zuschläge). Eine gemessene Arbeitszeit ändert also **keine einzige Rechnung**. Sie dient der Tagesplanung, der Auswertung und der Fahrzeit-Lernkurve.

---

## 2. Leitgedanke

Drei Zeitbegriffe, die heute in einem Feld zusammenfallen, werden getrennt — jeder mit klarem Namen:

| Begriff | Bedeutung | Beispiel |
|---|---|---|
| **gemeldet** | Wann kam der Auftrag herein | Anruf Dienstag 08:15 |
| **geplant** | Wann will ich hin | Mittwoch 14:00, ca. 45 min |
| **gearbeitet** | Wann war ich tatsächlich dort | Mittwoch 14:20–15:05 |

Erst diese Trennung macht alles andere möglich: eine Fällig-Liste, die nur zeigt was ansteht; einen Tagesplan, der geplante Einsätze automatisch am richtigen Tag hat; eine Auswertung, die echte Arbeitszeit kennt; und eine Reaktionszeit-Statistik (gemeldet → gearbeitet), die heute niemand berechnen kann.

---

## 3. Datenmodell

Neue Spalten auf **`stoerungen`** und **`montagen`** (gleiche Namen, damit die Logik geteilt werden kann):

```
geplant_am        date        -- Zieltag; null = noch nicht eingeplant
geplant_zeit      time        -- optionaler Wunschtermin ("um 14:00")
geplant_dauer_min int         -- geschätzte Dauer, Vorgabe je Art
arbeit_von        time        -- tatsächlicher Arbeitsbeginn
arbeit_bis        time        -- tatsächliches Arbeitsende
gemeldet_am       timestamptz -- wann der Auftrag hereinkam (nur Störung)
```

- **`datum` behält seine Bedeutung** als Einsatzdatum (wann erledigt) — kein Umbau bestehender Auswertungen.
- **Die 109 Störungs-Startzeiten** ziehen nach `gemeldet_am` um (Datum + Uhrzeit zusammengesetzt), mit Rollback-Skript. Weil ihre Bedeutung uneinheitlich ist, wird das im Migrations-Kommentar festgehalten — sie sind ein Anhaltspunkt, keine belastbare Reaktionszeit-Grundlage.
- **`arbeit_von`/`arbeit_bis` sind bewusst NICHT die Quelle von `dauer_minuten`** (das bleibt an `uhrzeit_start`/`uhrzeit_ende` hängen, um die generierte Spalte nicht anzufassen). Die Ist-Dauer rechnet die App aus den neuen Feldern.

**Status-Werte** bleiben wie sie sind (`offen`/`in_bearbeitung`/`behoben` bzw. `geplant`/`in_bearbeitung`/`abgeschlossen`) — sie funktionieren, sie wurden nur nie gesetzt.

---

## 4. Planung — was sich im Alltag ändert

**Fällig-Liste im Tourenplan:** zeigt künftig nur noch Einsätze, die für diesen Tag geplant sind oder **gar kein** Plandatum haben (Rückstand). Ein für Freitag geplanter Einsatz taucht am Mittwoch nicht mehr auf. Das behebt Mangel (b).

**Einplanen mit einem Tipp:** Aus der Fällig-Liste und aus dem Aufgaben-Screen führt ein Knopf «Einplanen» zu Tag und optionaler Uhrzeit. Das schreibt `geplant_am`/`geplant_zeit` **an den Einsatz** und legt ihn in den Tagesplan des Zieltags. Zieht man den Block im Plan auf eine andere Zeit, wird das an den Einsatz zurückgeschrieben — Plan und Datensatz bleiben in Deckung. Das behebt Mangel (c).

**Dauer-Vorgaben statt pauschal 60 Minuten:** je Montage-Typ und je Störungsbereich ein eigener Vorgabewert, der sich später aus der Historie schärfen lässt (wie bei den Reinigungen). Anfangswerte werden aus den erfassten Daten abgeleitet, sobald genug Ist-Zeiten vorliegen — bis dahin bleibt 60 Minuten die Vorgabe.

**Zeiterfassung beim Erledigen:** Öffnet Daniel einen geplanten Einsatz und drückt «Beginn», wird `arbeit_von` gesetzt; beim Speichern `arbeit_bis`. Für den häufigen Fall «erst hinterher erfasst» gibt es zwei Felder zum Nachtragen, vorbelegt mit einem Vorschlag aus der Plan-Zeit. Der Wegpunkt-Stempel (heute nur bei sofort erledigten Einsätzen) entsteht künftig auch beim **Abschliessen eines geplanten** Einsatzes — sonst fehlt der Fahrzeit-Lernkurve genau der Weg, den Daniel wirklich gefahren ist.

---

## 5. Spracheingabe

### 5.1 Der Weg: diktieren, nicht Spracherkennung bauen

Die Recherche ist eindeutig: **Wir bauen keine Spracherkennung.** Die Web Speech API im Browser schickt das Audio zur Erkennung an Google-Server, funktioniert also **offline gar nicht** — und Daniel ist regelmässig in Bündner Funklöchern unterwegs. Dazu kommen dokumentierte Chromium-Fehler bei fortlaufender Erkennung auf Android. Audio aufnehmen und serverseitig transkribieren (Whisper, Deepgram) hat dasselbe Offline-Problem und kostet pro Minute.

**Stattdessen:** Ein grosses Freitextfeld «Was soll ich eintragen?». Daniel tippt darauf und diktiert über das **Mikrofon der Gboard-Tastatur** — die Diktierfunktion läuft auf Betriebssystem-Ebene, funktioniert in jedem Textfeld auch in der Web-App, kostet nichts und braucht von uns keine einzige Zeile Code. Auf dem Pixel läuft ein Teil davon sogar auf dem Gerät selbst.

Unsere Aufgabe ist damit nicht das Hören, sondern das **Verstehen**.

### 5.2 Verstehen: Edge-Function `parse-einsatz`

Nach dem Muster der bestehenden `parse-beleg`/`parse-protokoll`-Funktionen: Text rein, strukturierter Vorschlag raus.

Eingabe: der diktierte Text, das heutige Datum (für «morgen», «nächsten Dienstag») und eine **Kurzliste der Betriebe** (Name + Ort + Id) zur Zuordnung.

Ausgabe:
```json
{
  "art": "stoerung|montage|eroeffnungsreinigung|endreinigung|aufgabe",
  "betrieb_id": "…", "betrieb_name_erkannt": "Sunset",
  "geplant_am": "2026-08-01", "geplant_zeit": "14:00",
  "geplant_dauer_min": 45,
  "beschreibung": "Zapfhahn tropft",
  "konfidenz": 0.0, "rueckfrage": "…"
}
```

Regeln im Prompt: relative Datumsangaben auflösen; Betrieb nur zuordnen, wenn er eindeutig ist, sonst Kandidaten zurückgeben; **nichts erfinden** — was nicht gesagt wurde, bleibt leer; bei Unklarheit eine `rueckfrage` formulieren statt zu raten.

### 5.2a Wo der Knopf sitzt (Entscheid Daniel 31.07.)

**Prominent auf der Startseite**, nicht in einem Untermenü. Begründung aus Daniels Alltag: «Ich bekomme häufig Anrufe während dem Autofahren oder zwischendurch während der Arbeit» — der Knopf muss ohne Suchen und ohne Scrollen erreichbar sein, mit grosser Trefffläche und einhändig bedienbar.

**Was mit einem erkannten Einsatz passiert:** Steht ein Datum im Diktat, wird er **gleich eingeplant**; ohne Datum entsteht ein offener Eintrag, den Daniel wie gewohnt einplant. Das entspricht der natürlichen Lesart von «morgen um vierzehn Uhr Störung beim Sunset».

### 5.3 Bestätigen statt blind anlegen

Das Ergebnis erscheint als **vorausgefülltes Formular**, nicht als fertiger Eintrag. Daniel sieht auf einen Blick, was verstanden wurde, korrigiert bei Bedarf und speichert. Grund: Ein falsch verstandener Betrieb oder ein um eine Woche verschobener Termin fällt beim Bestätigen sofort auf — nach dem stillen Anlegen erst, wenn er vor der falschen Tür steht.

### 5.4 Offline — der entscheidende Teil

Ohne Netz schlägt der KI-Aufruf fehl. Dann wird der **Rohtext lokal als Entwurf** gespeichert («3 Diktate warten auf Auswertung»), und die App wertet ihn aus, sobald wieder Empfang da ist. Das Diktat selbst geht nie verloren — genau das ist der Unterschied zu einer Lösung, die Spracherkennung online braucht.

### 5.4a Neue Betriebe diktieren (Erweiterung Daniel 31.07.)

Daniel bekommt Anrufe unterwegs — auch solche, aus denen ein **neuer Kunde** wird. Er nennt Name und Ort, dazu Anlagentyp und ob es sein Kunde ist; alles Übrige holt die App:

> «Neuer Betrieb Restaurant Adler in Chur, Heigenie-Anlage, mein Kunde»

Die Auswertung liefert dann `art: "neuer_betrieb"` mit `betrieb_neu_name`, `betrieb_neu_ort`, `anlagen_typ` und `ist_mein_kunde`. Adresse, Telefon, Website und Koordinaten kommen aus dem bestehenden Google-Lookup (`BetriebGoogleService`), die Öffnungszeiten bei Bedarf zusätzlich von der Website (`parse-oeffnungszeiten`) — beides existiert bereits und wird nur wiederverwendet.

**Auch hier wird bestätigt, nicht still angelegt.** Die gefundenen Google-Daten erscheinen zur Kontrolle, bevor der Betrieb entsteht. Ein aus einem Telefonat heraus falsch angelegter Betrieb wäre schwer zu bemerken und würde die Stammdaten verschmutzen.

Bei den Produktnamen ist Grosszügigkeit nötig: Die Tastatur-Spracherkennung verhört sich bei «HeiGenie» regelmässig («Hei Genie», «Heigeni», «Heikeni»).

### 5.5 Betriebs-Zuordnung

Bei 294 Betrieben mit teils ähnlichen Namen («Sunset», «Sunset Seehotel») entscheidet die Trefferqualität über den Nutzen. Zwei Stufen: erst ein Fuzzy-Vergleich in der App gegen Name und Ort, dann die KI-Zuordnung mit der Kandidatenliste. Bleibt es mehrdeutig, fragt das Formular nach — mit den zwei, drei besten Treffern zur Auswahl. Gelernte Zuordnungen («Sunset» → Sunset Seehotel Eich) werden gespeichert, wie beim Alias-Lernen des Zahlungsabgleichs.

---

## 6. Verknüpfung mit Tagesplan, Aufgaben und Kalender

### 6.1 Der Befund: drei Quellen, die nichts voneinander wissen

- **Tagesplan**: `faelligeEintraegeProvider` listet offene Einsätze (ohne Datumsfilter), `autoTermineProvider` rechnet Eröffnungs-/Endreinigungen aus den Saisondaten — beides **flüchtig**, nichts davon wird gespeichert.
- **Google-Kalender**: einseitiger Push App → Google, aber nur für drei Dinge: Pikett, Events und die Saison-Reinigungen eines Betriebs (letztere nur, wenn man beim Speichern des Betriebs einen Dialog bestätigt). **Störungen und Montagen werden gar nicht synchronisiert.**
- **Tabelle `termine`**: existiert in der Datenbank mit 219 Zeilen (135 Endreinigungen, 84 Eröffnungsreinigungen), alle mit Status `vorgeschlagen`, zuletzt geändert am 11.07.2026, **keine einzige mit aktiver Erinnerung** — und im Flutter-Code gibt es dazu keinen einzigen Zugriff. Ein verwaister Rest aus einem früheren Anlauf, samt bereits vorhandenen Feldern `erinnerung_aktiv`, `erinnerung_vorlauf_minuten`, `erinnerungen`.

Dieselbe Endreinigung kann heute also an drei Stellen entstehen, ohne dass eine von der anderen weiss.

### 6.2 Erinnerungen: nur Google kann das

Der entscheidende Punkt für den Wunsch «dass ich keine Termine verpasse»: **Eine Web-App kann keine Erinnerung zustellen, wenn sie geschlossen ist.** Die Aufgaben-Glocke funktioniert nur im offenen Browser-Tab. `flutter_local_notifications` steht zwar in der Projektdatei, wird aber nirgends verwendet — und würde im Web ohnehin nichts nützen.

Was den Nutzer zuverlässig erreicht, ist der **Google-Kalender**: Der bestehende Sync setzt bereits Erinnerungen (E-Mail und Popup, 24 Stunden vorher) für Pikett, Events und Saison-Reinigungen. Diese Infrastruktur ist vorhanden und erprobt.

**Daraus folgt die Architektur-Entscheidung:** Jeder geplante Einsatz wird in den Google-Kalender gepusht — mit Erinnerung. Die App plant, Google erinnert. Das ist kein Notbehelf, sondern nutzt den Kanal, der auf dem Handy ohnehin schon läuft, samt Erinnerung am Handgelenk.

### 6.3 Ein Termin entsteht durch Bestätigung

Statt einer vierten parallelen Quelle gilt eine klare Regel:

**Berechnet bleibt berechnet, bestätigt wird gespeichert.** Die Saison-Logik rechnet weiterhin, welche Eröffnungs- und Endreinigungen anstehen — das passt sich automatisch an, wenn sich Saisondaten ändern. Erst wenn Daniel einen solchen Vorschlag annimmt («Einplanen»), entsteht ein persistenter Termin mit Datum, Erinnerung und Kalendereintrag.

Konkret:
- **Störungen und Montagen** tragen ihren Termin selbst (`geplant_am`/`geplant_zeit`, Abschnitt 3) — keine zusätzliche Tabelle.
- **Eröffnungs- und Endreinigungen** haben kein Fachobjekt vor der Ausführung (`eroeffnungsreinigungen` ist ein reines Abrechnungsobjekt, das erst hinterher entsteht). Für sie wird die vorhandene Tabelle **`termine` wiederbelebt** — sie hat bereits den passenden Zuschnitt inklusive Erinnerungsfeldern. Die 219 veralteten Vorschlagszeilen werden dabei entfernt, da die Berechnung sie jederzeit neu liefert. *(Löschung von Daten → braucht Daniels Zustimmung, siehe offene Punkte.)*

### 6.4 Was wohin gehört

| Ort | Zeigt | Warum |
|---|---|---|
| **Tagesplan** (Zeitachse) | Einsätze mit `geplant_am` = dieser Tag, an ihrer Uhrzeit | Der Arbeitstag selbst |
| **Fällig-Liste** | ungeplante Einsätze + für heute geplante | Was noch einzuplanen ist |
| **Aufgaben-Screen** | alles Anstehende chronologisch, mit «Einplanen»-Knopf | Der Überblick über Tage hinweg |
| **Google-Kalender** | jeder geplante Einsatz, mit Erinnerung | Erreicht Daniel auch bei geschlossener App |

Der Aufgaben-Screen bekommt damit die Rolle, die ihm heute fehlt: nicht nur anzeigen, sondern **von dort aus einplanen**.

---

## 7. Umsetzung in Etappen

**Etappe 1 — Fundament (ohne Sprache):** Migration der neuen Felder, Fällig-Liste nach Plandatum filtern, «Einplanen» aus Fällig-Liste und Aufgaben-Screen, Rückschreiben der Anker-Zeit, Zeiterfassung beim Erledigen, Wegpunkt auch bei geplanten Einsätzen. **Das allein behebt Daniels Kritik an der Planung** — Sprache ist Komfort obendrauf.

**Etappe 2 — Spracheingabe für Störungen und Montagen:** Freitextfeld, Edge-Function `parse-einsatz`, Bestätigungsformular, Offline-Entwürfe, Betriebs-Zuordnung mit Lernen.

**Etappe 3 — Kalender und Erinnerungen:** Push geplanter Einsätze in den Google-Kalender mit Erinnerung, Rücknahme beim Umplanen oder Erledigen.

**Etappe 4 — Eröffnungs- und Endreinigungen:** `termine` wiederbeleben, Vorschläge annehmen, ebenfalls per Sprache erfassbar, mit Erinnerung.

Jede Etappe ist für sich nutzbar und wird einzeln ausgeliefert.

---

## 8. Entscheide Daniel (31.07.)

**1. Der Lebenslauf eines Einsatzes** — bestätigt und präzisiert:

| Schritt | Was passiert | Felder |
|---|---|---|
| **Anruf kommt** | Störung wird sofort erfasst | `gemeldet_am` = jetzt (änderbar) |
| **Einplanen** | entweder **fixer Termin** (Tag + Uhrzeit) oder **ganztägig** (nur Tag) | `geplant_am` + optional `geplant_zeit` |
| **Durchführung** | Start- und Endzeit werden gemessen | `arbeit_von`, `arbeit_bis` |

Für Montagen gilt dasselbe, nur ohne den Anruf-Schritt.

**Wichtige Folge für `datum`:** Beim Abschliessen wird `datum` auf den Tag gesetzt, an dem tatsächlich gearbeitet wurde. Damit bleibt die Abrechnung (`abrechnungs_monat`) korrekt, während `gemeldet_am` den Anruf festhält. Ohne diese Regel würde eine im Juli gemeldete, im August erledigte Störung im falschen Monat abgerechnet.

**2. Die 219 alten Termin-Vorschläge werden gelöscht** — mit Sicherung, geprüfte Bedingung «keine Daten verlieren» ist erfüllt: keine Notizen (0 von 219), keine Uhrzeiten, kein abweichender Status, keine aktive Erinnerung. Titel und Anlass sind bei allen 219 gesetzt, also systematisch erzeugt. Alles ist aus Betrieb und Saisondaten neu berechenbar. Vollständige Kopie nach `import.termine_vor_loeschung_2026_07_31`.

**3. Kalendereintrag für beide Formen:** mit Uhrzeit als Termin, ohne Uhrzeit als **Ganztages-Eintrag**. Beide mit Erinnerung.

**4. Arbeitszeit per «Beginn»-Knopf, mit GPS.** Beim Antippen werden Zeit **und Standort** erfasst — damit fliesst der Einsatz in dieselbe Wegpunkt-Kette wie Reinigungen und schärft die Fahrzeit-Lernkurve. Nachtragen von Hand bleibt möglich, falls der Knopf vergessen wurde (analog zur Pausen-Erkennung).
