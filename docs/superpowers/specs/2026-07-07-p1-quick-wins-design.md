# P1 Quick Wins — Design (Optimierungspaket 06)

**Datum:** 2026-07-07
**Quelle:** `Prompts/06_Optimierung_App_2026_07_07.txt`
**Status:** Vom User abgenommen (07.07.2026)

Grundregel: Bestehende Funktionen werden nicht tangiert. Einziger DB-Eingriff ist Punkt 7
(rein additive, optionale Spalten).

## 1. Eigenaufträge: Filter entfernen

Der Status-PopupMenuButton oben rechts in
`sbs_projer_app/lib/presentation/screens/eigenauftraege/eigenauftrag_list_screen.dart` (Z. 97–107)
wird ersatzlos entfernt. Suche und Jahr/Monat-Dropdowns bleiben. Der interne `_statusFilter`
und zugehörige Filterlogik werden mitentfernt (Filter zeigt danach immer alle).

## 2. Störungen: Filter erweitern (Anlagentyp + Km-Abrechnung)

Das Filter-Icon oben rechts in
`sbs_projer_app/lib/presentation/screens/stoerungen/stoerungen_list_screen.dart` (Z. 98–108)
öffnet statt des Status-PopupMenus ein BottomSheet mit drei Sektionen:

- **Status**: Alle / Offen / Behoben / Nicht behebbar (bestehende Logik)
- **Anlagentyp**: dynamisch aus den `anlageTyp`-Werten der geladenen Störungen abgeleitet
  (distinct, sortiert; Störungen ohne Typ unter „Ohne Anlagentyp")
- **Km-Abrechnung**: Alle / Nur mit Km-Abrechnung / Nur ohne (`istKilometerabrechnung`)

Filter-Icon bekommt Badge mit Anzahl aktiver Filter (Muster analog Tourenplanung).

## 3. Reinigung: Chip „Foto" → „Protokoll"

`sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_detail_screen.dart` Z. 896–901:
Label `'Foto'` → `'Protokoll'`, Icon `Icons.photo_camera` → `Icons.description`.

## 4. Reinigung: Service-Art statt roher Service-Typ

`reinigung_detail_screen.dart` Z. 127–128 zeigt aktuell den rohen `serviceTyp`
(z. B. `reinigung_bier`). Neu: Zeile zeigt die **Service-Art** mit Label
(„Standardservice" / „Endreinigung" / „Eröffnungsservice", Feld `serviceArt`).
`serviceTyp` bleibt intern für die Preisberechnung vollständig unangetastet.

## 5. Reinigung: Zeiterfassung kompakter

`sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart` Z. 941–992:
Statt Datum (eigene Zeile) + Row(Start, Ende) neu **eine Zeile mit drei Feldern**
(Datum | Start | Ende), Datum mit grösserem Flex. Heineken-Monteur-Sonderfall
(nur Datum sichtbar) bleibt erhalten.

## 6. Kontakte: Heineken-Rolle „Stardrinks"

`sbs_projer_app/lib/data/models/kontakt.dart`: `'stardrinks'` in `rollenFuerKategorie('heineken')`
ergänzen + Label „Stardrinks" in `rolleLabel` und `rolleLabelStatic`.
Vorab prüfen, ob die DB einen CHECK-Constraint auf `kontakte.rolle` hat
(Migration 067/075) — falls ja, Migration zur Erweiterung.

## 7. Betriebsferien: kompakte Anzeige + Erweiterung auf 5 Slots

**UI** (`betrieb_form_screen.dart` Z. 746–832): Statt immer drei Ferien-Zeilen werden nur
belegte Zeilen angezeigt (mindestens Ferien 1), darunter „+ Weitere Ferien"-Button bis max. 5.
Leeren einer Zeile blendet sie nach Speichern wieder aus.

**Model/DB**: Neue optionale Felder `ferien4Start/Ende`, `ferien5Start/Ende`:

- DB-Migration `betriebe`: 4 neue nullable Spalten (`ferien4_start`, `ferien4_ende`,
  `ferien5_start`, `ferien5_ende`)
- Isar-Model `betrieb_local.dart` + `dart run build_runner build`
- Web-Stub `web/betrieb_local_web.dart`, DTO `betrieb.dart`, Mapper
- **Logik-Erweiterung**: `tour_providers.dart` (`_isBetriebAktiv`,
  `_naechsteSchliessung`, `_naechsteOeffnung`) und die Kalender-Termin-Generierung
  (Saison-/Ferien-Termine, Aufruf in `betrieb_form_screen.dart` Z. 219) berücksichtigen
  heute Ferien 1–3 → auf 1–5 erweitern. Ferienperioden dafür als Liste behandeln
  statt Einzelfelder zu duplizieren.

Bestehende Daten bleiben unberührt; alle neuen Spalten sind nullable.

## Umsetzungsreihenfolge & Abschluss

1. Punkte 1–6 (reine UI/Model-Labels, risikolos)
2. Punkt 7 (DB-Migration zuletzt)
3. `flutter analyze` + bestehende Tests
4. Visueller Test im Browser (Pflicht vor Deploy bei UI-Änderungen)
5. Version bumpen, Deploy gh-pages, ToDo.md/Projekt.md nachführen
