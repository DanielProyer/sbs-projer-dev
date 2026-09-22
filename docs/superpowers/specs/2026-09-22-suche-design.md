# Suche — Design

**Datum:** 22.09.2026 · **Stand der App:** v0.132.0 · **Teil 2 von 3** der
Bedienungs-Vereinfachung (Teil 1: Navigation «Mehr», siehe
`2026-09-22-navigation-mehr-design.md`).

## Ziel

Alles, was selten gebraucht wird, soll trotzdem in Sekunden erreichbar sein:
ein Betrieb, eine Person, eine Rechnung, ein Bereich der App. Die Suche ist
kein Ersatz für die Ordnung unter «Mehr», sondern die Abkürzung daran vorbei.

## Ausgangslage

- Betriebe (`betriebeProvider`), Personen (`kontakteProvider`) und **alle**
  Rechnungen (`rechnungenStreamProvider`, ganzer Bestand) sind app-weit im
  Speicher. Die Bereiche sind Daten in `lib/core/config/bereiche.dart`.
- Es gibt schon Suchfelder in den Listen (Betriebe, Personen, Forderungen),
  aber keine Stelle, die über die Listen hinweg sucht.
- Jeder Screen baut seine eigene AppBar (101 Routen). Eine Lupe «in jeder
  Kopfzeile» hiesse 100 Eingriffe.

## 1. Einstiege

| Wo | Was | Öffnet |
|---|---|---|
| **Heute**, Kopfzeile | Lupe links neben der Sync-Anzeige | `/suche` per `push` |
| **Mehr**, zuoberst über «Unterwegs» | Ein Feld, das wie ein Suchfeld aussieht (Platzhalter «Betrieb, Person, Rechnung, Bereich …»), aber nur ein Tipp-Ziel ist | `/suche` per `push` |

Von jedem Screen aus ist die Suche damit in zwei Tipps erreichbar (Leiste →
Heute oder Mehr → Suche). Die Suchlogik gibt es nur einmal, auf `/suche`. In
der Leiste leuchtet dort «Mehr».

## 2. Trefferregeln

**Eingabe:** ein Textfeld. Treffer ab dem **2. Zeichen**, ohne Enter.

**Normalisierung** (für Suchtext und Felder gleich): Kleinbuchstaben; `ä→a`,
`ö→o`, `ü→u`, `ß→ss`, Akzente weg; Mehrfach-Leerzeichen zu einem.

**Mehrere Wörter:** Der Suchtext wird an Leerzeichen geteilt; **jedes** Wort
muss in der Zusammenfassung der Suchfelder eines Treffers vorkommen. «pub
cham» findet «Chleina Pub» in Cham.

| Gruppe | Suchfelder | Trefferzeile | Tipp öffnet |
|---|---|---|---|
| **Betriebe** | Name, Ort, Betriebsnummer (`betriebNr`), `heineken_nr` | Name · Ort, Status-Punkt (aktiv / Saisonpause / inaktiv / geschlossen) | `/betriebe/:id` |
| **Personen** | Vorname, Nachname, Telefon (auch ohne Leerzeichen/`+41`), Betriebsname | «Vorname Nachname» · Betrieb; rechts Anruf-Symbol, wenn Telefon vorhanden | Zeile: `/kontakte/:id/bearbeiten`; Symbol: `tel:` |
| **Rechnungen** | Rechnungsnummer (Teilstück genügt: «1449»), Betriebsname | Nummer · Betrieb · Betrag brutto · Zahlungsstatus | `/rechnungen/:id` |
| **Bereiche** | Titel und Untertitel aller Einträge aus `kAlleBereiche` und der fünf Leisten-Ziele, plus feste **Stichwörter** je Eintrag (neues Feld `stichwoerter` in `BereichEintrag`, z. B. MwSt-Abrechnung: «mwst», «mehrwertsteuer», «estv») | Titel · Gruppe (z. B. «Abschlüsse und Steuern») | die Zielroute |

**Reihenfolge innerhalb einer Gruppe:**
1. Treffer, bei denen ein Suchfeld mit dem Suchtext **beginnt**, vor Treffern
   mit dem Text in der Mitte.
2. Betriebe: operative (`istBetriebOperativ`) vor inaktiven/geschlossenen.
3. Rechnungen: neueste zuerst (Rechnungsdatum absteigend).
4. Sonst: alphabetisch nach Titel.

**Deckel:** höchstens **5 Treffer je Gruppe**. Gibt es mehr, steht darunter
«alle N anzeigen» und führt in die jeweilige Liste mit vorbefülltem Suchfeld:
Betriebe → `/betriebe?suche=…`, Personen → `/kontakte?suche=…`, Rechnungen →
`/rechnungen?suche=…` (die drei Listen-Screens lesen den Parameter und füllen
ihr bestehendes Suchfeld). Bereiche haben keinen Deckel (die Liste ist klein).

**Reihenfolge der Gruppen:** Betriebe · Personen · Rechnungen · Bereiche.
**Sonderfall nur Ziffern** (z. B. «1449», «0137», «079»): Rechnungen ·
Betriebe · Personen · Bereiche.

Gruppen ohne Treffer erscheinen nicht. Kein Treffer in keiner Gruppe:
«Nichts gefunden für ‹xyz›».

**Nicht gesucht:** Heineken-Monatsrechnungen (eine pro Monat, über den Reiter
schneller), Reinigungen, Störungen, Montagen, Dokumente, Anlagen.

## 3. Die Suchseite

- **Kopfzeile:** Zurück-Pfeil, das Suchfeld füllt die Breite, rechts ein ×,
  das den Text löscht (Fokus bleibt im Feld). Beim Öffnen liegt der Fokus im
  Feld, die Tastatur ist offen.
- **Leerer Zustand** (unter 2 Zeichen): ein kurzer Hinweis, was gefunden wird,
  darunter **«Zuletzt geöffnet»** mit den letzten 5 Treffern, die über die
  Suche geöffnet wurden (Titel, Untertitel, Route) — lokal per
  `shared_preferences`, neueste zuerst, ohne Duplikate.
- **Treffer:** je Gruppe ein Gruppenkopf und bis zu 5 Zeilen, dann ggf. «alle
  N anzeigen». Zeilen aus `InkWell` + `Container` + `Row` (CanvasKit-Regel):
  Symbol links, Titel (eine Zeile, Ellipse) mit dem Suchtext **fett**
  hervorgehoben, Untertitel darunter, rechts Pfeil oder Anruf-Symbol.
- **Tipp auf einen Treffer:** Route per `push`; «zurück» kommt zur Suche mit
  dem Text zurück. Der Treffer landet in «Zuletzt geöffnet».
- **Tempo:** Treffer werden beim Tippen berechnet, frühestens **150 ms** nach
  dem letzten Zeichen (Debounce im Screen). Die Berechnung ist reines Dart
  über die Provider-Listen, ohne Netzabfrage.

## 4. Bauweise

| Baustein | Datei | Verantwortung |
|---|---|---|
| Regeln | `lib/core/util/suche.dart` | `normalisiere`, `SuchEingabe` (schlanke Records je Gruppe), `suche(eingabe, text) → SuchErgebnis` (Gruppen, Treffer mit Titel/Untertitel/Route/Telefon/Rang, Gesamtzahl je Gruppe). Kein Riverpod, kein Flutter. |
| Stichwörter | `lib/core/config/bereiche.dart` | `BereichEintrag.stichwoerter` (optional, Standard leer) |
| Quellen | `lib/presentation/providers/suche_provider.dart` | `suchEingabeProvider` aus `betriebeProvider`, `kontakteProvider`, `rechnungenProvider`, `kAlleBereiche` + Leisten-Ziele; `suchTextProvider` (State); `suchErgebnisProvider` (abgeleitet) |
| Zuletzt geöffnet | `lib/services/suche/zuletzt_geoeffnet.dart` | lesen/schreiben der letzten 5 (`shared_preferences`, JSON) |
| Screen | `lib/presentation/screens/suche/suche_screen.dart` | Feld, Debounce, Gruppen, leerer Zustand |
| Zeile | `lib/presentation/widgets/such_treffer_zeile.dart` | eine Trefferzeile mit Hervorhebung |
| Einstiege | `home_screen.dart` (Lupe), `bereich_screen.dart` (optionales `kopf`-Widget: Such-Tipp-Feld nur für `kBereichMehr`) | |
| Route | `lib/core/config/router.dart` | `/suche` |
| Listen | `betriebe_list_screen.dart`, `kontakte_list_screen.dart`, `rechnungen_list_screen.dart` | lesen `?suche=` und füllen ihr Suchfeld vor |

**Zuordnung Leiste:** `/suche` lässt «Mehr» leuchten (Standardfall in
`aktivesZiel`), die Leiste bleibt sichtbar.

## 5. Absicherung

- **`test/suche_test.dart`** (reine Regeln): Normalisierung (Ä/ä/a, ß/ss,
  Akzent), Mehrwort «pub cham», Anfang vor Mitte, operativ vor inaktiv,
  Rechnungen neueste zuerst, Rechnungsnummer als Teilstück, Telefon ohne
  Leerzeichen, Ziffern-Sonderfall (Gruppenreihenfolge), Deckel 5 mit
  Gesamtzahl, leere Gruppen fehlen, unter 2 Zeichen keine Treffer.
- **`test/suche_screen_test.dart`** (echtes Widget, Provider überschrieben,
  echter GoRouter): Fokus beim Öffnen, keine Treffer unter 2 Zeichen,
  Gruppen erscheinen, Tipp öffnet die Route und schreibt «Zuletzt geöffnet»,
  «alle N anzeigen» führt mit `?suche=` in die Liste, «Nichts gefunden», ×
  löscht den Text.
- **`test/zuletzt_geoeffnet_test.dart`**: 5er-Deckel, neueste zuerst, keine
  Duplikate (`SharedPreferences.setMockInitialValues`).
- **Wächter:** `suche_screen.dart` und `such_treffer_zeile.dart` in die
  CanvasKit-Dateiliste; `/suche` im Erreichbarkeits-Wächter als Unterseite
  von `home_screen.dart`.
- **Vor dem Deploy:** Sichtprüfung bei 360 px mit offener Tastatur (Heute →
  Lupe, Mehr → Feld, ein Betrieb, eine Person mit Anruf-Symbol, eine
  Rechnungsnummer, «mwst», «alle N anzeigen», «Zuletzt geöffnet»).

## 6. Auslieferung

Ein Schritt: **v0.133.0**. Danach `docs/chronik.md`, `ToDo.md`
(Klicktests), `Projekt.md` (Abschnitt Navigation um die Suche ergänzen).

## Nicht in diesem Teil

- Suche in Reinigungen, Störungen, Montagen, Dokumenten, Anlagen
- Filter oder Sprachsuche
- Server-seitige Suche (nicht nötig, Bestand ist im Speicher)
- Lupe in jeder Kopfzeile
