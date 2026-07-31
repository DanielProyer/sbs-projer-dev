# Betriebsferien und Öffnungszeiten aktuell halten — Design

**Datum:** 31.07.2026
**Anlass:** Daniel stand erneut vor einem Betrieb, der überraschend Betriebsferien hatte.
**Umfang (Entscheid Daniel 31.07.):** Bausteine A, B, D, F — dazu ein regelmässiger Abgleich über Google **und** Website. Kein Vortages-Check-Screen (Baustein C entfällt).

---

## 1. Ausgangslage

Die Tourenplanung verarbeitet Ferien bereits korrekt: `touren_saison.dart` liefert mit `schliessungsGrund()` den konkreten Grund («Betriebsferien bis 16.08.», Ruhetag, Zwischensaison), und `faelligkeitsAnker()` startet die Fälligkeits-Uhr erst bei der Wiedereröffnung. **Das Problem ist ausschliesslich die Datenpflege.**

| Datenlage 31.07.2026 (294 aktive Betriebe) | |
|---|---|
| mit mindestens einer Ferienperiode | 36 |
| ausdrücklich «keine Betriebsferien» | 14 |
| **ohne jede Aussage zu Ferien** | **244 (83 %)** |
| erfasste Perioden gesamt | 40 (39 mit Start 2026) |
| Öffnungszeiten mit Inhalt / Ruhetage | 209 / 214 |
| Website hinterlegt | 259 |

Dazu drei strukturelle Lücken:

1. **Eine vergebliche Fahrt hinterlässt keine Spur.** Der Betrieb von heute ist morgen wieder unbekannt.
2. **Ferien sind Kalenderdaten in fünf festen Spaltenpaaren** (`ferien_start`/`ferien_ende` bis `ferien5_*`). Sie altern jedes Jahr, und es gibt kein Feld, das sagt, wann eine Angabe zuletzt bestätigt wurde — `updated_at` taugt nicht dafür, weil Massen-Updates alle 294 Betriebe in den letzten 90 Tagen berührt haben.
3. **Kein geplanter Lauf vorhanden.** `pg_cron` ist nicht aktiviert (nur `pg_net`), GitHub Actions gibt es nicht.

---

## 2. Leitgedanke

Zwei Klassen von Wissen, die nicht vermischt werden dürfen:

- **Bestätigtes Wissen** — vom Kunden gesagt oder von Daniel vor Ort erlebt. Steuert die Planung.
- **Hinweise** — aus Google, Website oder dem Vorjahr abgeleitet. Warnen, planen aber nichts um und überschreiben nie eine bestätigte Angabe.

Eine automatisch geholte Angabe wird deshalb **nie still übernommen**, sondern landet als Vorschlag in einer Prüfliste. Der Grund ist praktisch: Google und Websites sind bei kleinen Landgasthöfen oft veraltet, und eine still überschriebene Öffnungszeit wäre schlimmer als gar keine — sie sähe gepflegt aus.

---

## 3. Datenmodell

### 3.1 Neue Tabelle `betrieb_ferien` (ersetzt die fünf Spaltenpaare)

Die fünf festen Slots sind der Grund, warum Baustein D (Vorjahres-Hinweis) sonst ein Behelf würde: Trägt Daniel 2027 neue Ferien ein, verdrängen sie die Historie, aus der der Hinweis stammt. Eine Tabelle mit einer Zeile je Periode löst das dauerhaft und trägt zugleich Quelle und Bestätigungsdatum.

```
betrieb_ferien
  id            uuid pk
  betrieb_id    uuid  -> betriebe(id) on delete cascade
  von           date  not null
  bis           date  not null
  quelle        text  -- 'kunde' | 'vor_ort' | 'website' | 'google' | 'import'
  bestaetigt_am timestamptz
  notiz         text
  user_id       uuid  (RLS wie überall)
  check (bis >= von)
```

- **Migration der 40 bestehenden Perioden** mit `quelle = 'import'`, `bestaetigt_am = null`.
- Die alten Spalten bleiben zunächst stehen (nicht gelöscht), damit ein Rückweg offen ist; entfernt werden sie in einem späteren Aufräumschritt, wenn die neue Struktur im Feld bestätigt ist.
- `betrieb_ferien.dart` behält seine Aussenform (`istInFerien`, `ferienStarts`, `ferienEnden`, `ferienSlots`), liest die Perioden aber aus der neuen Quelle. Damit bleiben Tourenplan, Heineken-Raster, Kalender-Sync und PDF unverändert.

### 3.2 Neue Felder auf `betriebe`

```
ferien_bestaetigt_am   timestamptz  -- wann zuletzt jemand die Ferienfrage beantwortet hat
ferien_frage_ruht_bis  date         -- «weiss nicht» → 30 Tage Ruhe, damit die Frage nicht nervt
google_place_id        text         -- einmalig gespeichert, macht den Abgleich billig und eindeutig
oeffnungszeiten_geprueft_am timestamptz
```

`keine_betriebsferien` bleibt wie bisher, wird aber zusammen mit `ferien_bestaetigt_am` gesetzt.

### 3.3 Neue Tabelle `betrieb_vorschlaege`

```
betrieb_vorschlaege
  id           uuid pk
  betrieb_id   uuid
  feld         text     -- 'ruhetage' | 'oeffnungszeiten' | 'ferien' | 'status'
  alt_wert     jsonb
  neu_wert     jsonb
  quelle       text     -- 'google' | 'website'
  konfidenz    numeric
  gefunden_am  timestamptz
  status       text     -- 'offen' | 'uebernommen' | 'verworfen'
  user_id      uuid
```

Ein Vorschlag je (Betrieb, Feld, Quelle) — ein neuer Lauf aktualisiert den offenen Eintrag, statt Dubletten zu häufen.

---

## 4. Bausteine

### A — «War geschlossen» im Tagesplan

Im Block-Sheet des Tagesplans ein Knopf **«War geschlossen»**. Er fragt nach dem Grund:

- **Betriebsferien** → Datumsbereich (vorbelegt: heute bis heute + 14 Tage, anpassbar) → schreibt eine Periode mit `quelle = 'vor_ort'`, `bestaetigt_am = jetzt`
- **Ruhetag** → Wochentag (vorbelegt: heutiger) → ergänzt `ruhetage`
- **Niemand da / anderes** → Notiz, keine Datenänderung am Betrieb

In allen Fällen wird ein Wegpunkt mit `quelle = 'vergeblich'` gestempelt (Zeit + GPS + Notiz). Damit ist die Leerfahrt dokumentiert und später auswertbar.

**Ausdrücklich keine Neuplanung** (Entscheid Daniel): Der Besuch verschwindet aus dem Tagesplan, bleibt in der Fällig-Liste und wird von Daniel selbst neu eingeplant. Ein Hinweis-Text sagt das.

### B — Ferienfrage beim Reinigungs-Abschluss

Im Abschluss-Dialog der Reinigung eine zusätzliche, **nicht blockierende** Zeile «Nächste Betriebsferien?» mit drei Antworten:

- **Keine geplant** → `keine_betriebsferien = true`, `ferien_bestaetigt_am = jetzt`
- **Von–bis** → Periode mit `quelle = 'kunde'`, `bestaetigt_am = jetzt`
- **Weiss nicht** → `ferien_frage_ruht_bis = heute + 30 Tage`

Die Zeile erscheint **nur**, wenn `ferien_bestaetigt_am` fehlt oder älter als 12 Monate ist und die Frage nicht ruht. Bei rund acht Besuchen am Tag sind die 244 Lücken damit innerhalb eines Reinigungszyklus geschlossen, ohne einen einzigen zusätzlichen Anruf.

### D — Vorjahres-Hinweis

Liegt der geplante Tag in einer Periode desselben Betriebs aus einem **früheren Jahr** (Tagesdatum minus 1 oder 2 Jahre innerhalb der Periode, mit ±5 Tagen Toleranz für verschobene Wochen), zeigt der Tagesplan-Block ein graues Band:

> «Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen»

Reine Anzeige: keine Fälligkeitsverschiebung, keine Umplanung, keine Vermischung mit bestätigten Ferien. Der Hinweis verschwindet, sobald für das laufende Jahr eine Aussage vorliegt (Periode erfasst oder «keine geplant» bestätigt).

### F + Google — regelmässiger Abgleich

Ein täglicher Lauf über `pg_cron` (Extension aktivieren) stösst per `pg_net` zwei Edge-Functions an, jeweils für die **zehn am längsten nicht geprüften** Betriebe. So ist der ganze Bestand in etwa vier Wochen einmal durch, ohne Lastspitze und ohne Kostenrisiko.

**Google** (`betrieb-google-abgleich`, neu): einmalig `google_place_id` per Textsuche ermitteln und speichern, danach Place Details mit `regularOpeningHours`, `currentOpeningHours` und `businessStatus`. Erzeugt Vorschläge für Öffnungszeiten und Ruhetage; `CLOSED_TEMPORARILY` erzeugt einen Vorschlag «vorübergehend geschlossen — Ferien prüfen».

**Website** (`parse-oeffnungszeiten`, erweitert): Der bestehende Prompt ignoriert Sonderzeiten ausdrücklich. Er wird um Betriebsferien ergänzt («Betriebsferien vom … bis …», auch «Ferien», «Wir sind zurück ab …») und liefert zusätzlich `ferien: [{von, bis}]` mit eigener Konfidenz. Läuft mit Haiku statt eines grösseren Modells — es ist reine Extraktion.

**Ehrliche Einordnung der Trefferquote:** Google kennt vor allem die regulären Öffnungszeiten und meldet Ferien nur, wenn der Wirt selbst «vorübergehend geschlossen» setzt — das ist die Ausnahme. Die Website ist für Ferien die bessere Quelle, weil dort oft ein konkreter Zeitraum steht. Beide zusammen ersetzen die Frage beim Kunden (B) nicht, sie verkleinern nur die Lücke.

### Prüfliste

Neuer Screen **«Änderungsvorschläge»**, erreichbar über den Aufgaben-Screen (Zeile «12 Vorschläge prüfen»). Je Vorschlag: Betrieb, Feld, alter Wert, neuer Wert, Quelle, Datum — mit **Übernehmen** / **Verwerfen** und «Alle von dieser Quelle übernehmen» für den ersten Schwung. Übernehmen schreibt in den Betrieb und setzt `oeffnungszeiten_geprueft_am`.

---

## 5. Was bewusst nicht gebaut wird

- **Kein Vortages-Check-Screen** (Baustein C) — Daniel bevorzugt die Frage beim Besuch.
- **Keine automatische Neuplanung** nach einer Leerfahrt.
- **Keine Servicezeiten** aus fremden Quellen — nur Ruhetage und Öffnungszeiten (Entscheid Daniel).
- **Keine stille Übernahme** von Google- oder Website-Werten.

---

## 6. Reihenfolge

1. Migration: `betrieb_ferien` + neue Felder + `betrieb_vorschlaege`, Übernahme der 40 Perioden
2. `betrieb_ferien.dart` auf die neue Quelle umstellen (Aussenform unverändert, TDD)
3. Baustein A — «War geschlossen»
4. Baustein B — Ferienfrage beim Abschluss
5. Baustein D — Vorjahres-Hinweis (reine Funktion, TDD)
6. Prüflisten-Screen + `betrieb_vorschlaege`-Repository
7. Edge-Function `betrieb-google-abgleich` + `place_id`-Erfassung
8. `parse-oeffnungszeiten` um Ferien erweitern
9. `pg_cron` aktivieren, beide Läufe planen, erster überwachter Durchlauf

Schritte 1–5 bringen für sich genommen schon den Nutzen; 6–9 sind die Automatik obendrauf.

---

## 7. Offene Punkte für Daniel

- **Datenmodell:** Der Umstieg von fünf festen Ferien-Spaltenpaaren auf eine Tabelle ist der grösste Einzelposten. Ohne ihn bleibt der Vorjahres-Hinweis ein Behelf, weil neue Ferien die Historie verdrängen. Einverstanden?
- **Erster Schwung Vorschläge:** 80 Betriebe haben gar keine Ruhetage. Sollen leere Felder direkt gefüllt werden (statt über die Prüfliste zu laufen), oder willst du auch die einzeln sehen?
