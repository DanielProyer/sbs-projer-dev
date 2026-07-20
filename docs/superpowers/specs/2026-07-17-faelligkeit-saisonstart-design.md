# Fälligkeit ab Saisonstart — Design

**Datum:** 17.07.2026 · **Status:** Regeln von Daniel vorgegeben (Chat), Spec zur Review

## Problem

Nach einer Endreinigung bekommt ein Saisonbetrieb den Status `eroeffnungFaellig` —
und behält ihn **für immer** (die Saison-Prüfung in `getFaelligkeit` kehrt früh
zurück, die reguläre Rhythmus-Uhr läuft nie wieder an). Gleichzeitig zeigt der
Standard-Filter der Fällig-Liste nur `ueberfaellig` + `faellig`, und der
Auto-Termin erscheint nur exakt am Eröffnungstag. Ergebnis: **17 Kunden** waren
am 17.07.2026 wieder offen (bis 78 Tage), ohne je im Tourenplan aufzutauchen
(Tgantieni-Fall).

## Regel (Daniel, 17.07.2026)

1. **Uhr-Anker = Wiedereröffnung:** War der Betrieb am Tag nach der letzten
   Reinigung **geschlossen** (Saisonpause oder Betriebsferien), startet die
   Fälligkeits-Zählung erst bei der Wiedereröffnung (Saisonstart bzw.
   Ferien-Ende + 1) — nicht am Reinigungsdatum. Gilt für die Endreinigung
   am/nach Saisonschluss UND für eine Eröffnungsreinigung, die vor dem
   Saisonstart gemacht wird. Mitten in der Saison: unverändert
   (Anker = Reinigungsdatum). Danach die normalen Stufen:
   Soll = Anker + Rhythmus → bald fällig, +1 Woche fällig, +2 Wochen überfällig.
2. **Eröffnungs-Hinweis bleibt, aber begrenzt:** `eroeffnungFaellig` erscheint
   nur im Fenster **7 Tage vor bis zum Saisonstart** — und NUR, wenn in der
   Saisonpause keine Reinigung stattgefunden hat (sonst ist der
   Eröffnungsservice erledigt; es zählt allein die Uhr ab Saisonstart).
   Das ewige `tage < 0`-Verhalten entfällt. Der Auto-Termin am Eröffnungstag
   bleibt unverändert.
3. **Meldung bei fehlenden Saisondaten:** Ist der Anker nicht bestimmbar
   (letzte Reinigung = Endreinigung, aber kein künftiger Saisonstart / kein
   Ferien-Ende gepflegt), zeigt die **Tourenplanung eine Warnleiste** (Muster
   der Rechnungs-Warnung in den Forderungen: stumm, solange nichts fehlt;
   antippen → Liste der Betriebe). Keine stille Nicht-Fälligkeit mehr.
4. **Standard-Filter:** `eroeffnungFaellig` + `endreinigungFaellig` werden in
   den Default des Fälligkeits-Filters aufgenommen (die Planungsfenster sollen
   ohne Filter-Klick sichtbar sein).

## Umsetzung

### A. Anker-Logik (`tour_providers.getFaelligkeit`, reine Funktion in `touren_saison.dart`)

Neue reine Funktion (TDD):

```dart
/// Anker für die Fälligkeits-Uhr: Wiedereröffnung, falls der Betrieb am Tag
/// nach der letzten Reinigung geschlossen war (Saisonpause/Ferien — Ruhetage
/// zählen NICHT als geschlossen); sonst die letzte Reinigung selbst.
/// null = Anker nicht bestimmbar (geschlossen, aber keine Wiedereröffnung
/// gepflegt) → Aufrufer zeigt Meldung.
DateTime? faelligkeitsAnker(BetriebLocal b, DateTime letzteReinigung);
```

- „geschlossen" = `!_inAktiverSaison || istInFerien` am Tag `letzteReinigung + 1`
  (bewusst OHNE Ruhetag — ein Ruhetag nach einer normalen Reinigung darf den
  Anker nicht verschieben).
- Wiedereröffnung via bestehendem `oeffnungNach(b, letzteReinigung)`.
- `getFaelligkeit` ersetzt den bisherigen Spezialblock
  „Endreinigung + 28 Tage hart codiert" (Z. 173-185) durch:
  `naechste = max(bisheriges naechste, anker + rhythmusTage)` — wie der alte
  Block nur nach hinten korrigierend (ein gepflegtes `anlage.naechsteReinigung`
  vor der Wiedereröffnung, z. B. Tgantieni 27.04., wird überstimmt), mit dem
  Anlagen-Rhythmus statt fix 28 Tagen.
  Der Anker gilt für JEDE letzte Reinigung (nicht nur `endreinigung`) — damit
  ist auch die Eröffnungsreinigung vor Saisonstart abgedeckt.
- Liegt die Wiedereröffnung in der Zukunft (Betrieb noch zu), ist
  `naechste` entsprechend in der Zukunft → `nichtFaellig` (wie bisher; die
  Pause selbst filtert zusätzlich `_isBetriebAktiv`).

### B. Eröffnungs-Hinweis begrenzen (`_getSaisonFaelligkeit`)

- Branch `letzteServiceArt == 'endreinigung' || null`: `eroeffnungFaellig`
  nur noch für `0 <= tage <= 7` (Fenster vor dem Start). Der
  `tage < 0`-Zweig (ewig) wird ERSATZLOS gestrichen — danach übernimmt die
  Anker-Uhr aus A.
- Zusatzbedingung „keine Reinigung in der Pause" (Daniel): ist durch die
  bestehende Branch-Bedingung `letzteServiceArt ∈ {endreinigung, null}`
  bereits **inhärent** erfüllt — jede Reinigung in der Pause (z. B.
  `eroeffnungsservice`) überschreibt die letzte Service-Art, der Branch feuert
  dann nicht mehr. Kein zusätzlicher Code, aber ein expliziter Test dafür.

### C. Warnleiste „Saisondaten fehlen" (Tourenplanung)

- Neuer Provider `saisonAnkerFehltProvider`: Betriebe (aktiv, mein Kunde),
  deren letzte abgeschlossene Reinigung eine `endreinigung` ist UND
  `faelligkeitsAnker(...) == null`.
- UI im Tourenplan-Screen über der Fällig-Liste, Muster `_warnungOhneRechnung`
  (rote/orange Leiste, antippen → Dialog mit Betriebsliste, Hinweis
  „Saisonstart bzw. Ferien-Ende beim Betrieb pflegen"). Stumm bei 0.

### D. Filter-Default

`selectedFaelligkeitProvider`-Default um `endreinigungFaellig` +
`eroeffnungFaellig` erweitern.

## Erwartete Wirkung (Stichprobe, Stand 17.07.2026)

- Tgantieni (Endreinigung 30.03., Start 06.06., 4-Wochen): Soll 04.07. →
  heute **fällig**, ab 18.07. überfällig — erscheint im Standard-Filter.
- Chesa/Seehof (offen seit 03.05.): **überfällig**.
- Alle 17 Betriebe der Kontroll-Liste erscheinen mit korrekter Stufe.

## NICHT in diesem Paket

- Keine Änderung an Auto-Terminen (Eröffnungs-/Endreinigungs-Zieltag).
- Keine Änderung der Endreinigungs-Vorlauf-Logik (7 Tage vor Schliessung).
- Keine DB-Änderungen (reine Client-Logik).

## Tests (TDD, `test/touren_saison_test.dart` erweitern bzw. neu)

- `faelligkeitsAnker`: Endreinigung am Saisonschluss → Saisonstart;
  Eröffnungsreinigung 3 Tage vor Start → Saisonstart; Reinigung mitten in der
  Saison → Reinigungsdatum; Reinigung gefolgt von Ruhetag → Reinigungsdatum
  (kein Shift); Endreinigung ohne gepflegten Start → null; Ferien-Fall
  (Ende + 1).
- `getFaelligkeit` mit Anker: Tgantieni-Szenario (06.06./4 Wochen, Stichtage
  03.07. nichtFällig / 05.07. baldFällig / 12.07. fällig / 19.07. überfällig);
  kein ewiges eroeffnungFaellig mehr nach Saisonstart; Hinweis-Fenster −7..0
  aktiv; Hinweis unterdrückt nach Reinigung in der Pause.
