# Saison-Historie je Betrieb — Design

**Datum:** 08.09.2026 · **Entscheide:** Daniel · **Umgesetzt in:** v0.98.0

## Problem

Die Saisondaten am Betrieb (`winter_start_datum` … `sommer_ende_datum`) halten
immer nur die laufende Saison. Wird die neue eingetragen, verschwindet die
alte — und damit der einzige Anhaltspunkt dafür, wann ein Betrieb
erfahrungsgemäss öffnet und schliesst.

Sichtbar wurde das am 08.09.2026 über einen zweiten Fehler: Beim Speichern
eines Betriebs schlug der Google-Kalender-Dialog Termine vor, die Monate
zurücklagen (Acla Grischuna: Wintersaison 13.12.2025–29.03.2026). Der Dialog
ist mit v0.97.2 gefixt, die Ursache dahinter bleibt: **53 von 89
Saisonbetrieben tragen abgelaufene Saisondaten**, weil die neue Saison noch
nicht feststeht.

## Entscheide

**Nur Historie zeigen, keine Automatik.** Die App schreibt keine Saisondaten
selbst fort und schlägt auch keine vor. Sie zeigt beim Bearbeiten, was in den
Vorjahren galt — entschieden wird von Hand. Begründung: Geschätzte Werte
steuern sonst Tourenplan und Kalender und sehen dabei aus wie bestätigte.

**Historie wird mitgeschrieben, nicht abgeleitet.** Die naheliegende
Alternative wäre gewesen, die 345 erfassten Endreinigungen seit 2019 als
Saison-Enden zu lesen. Verworfen (Daniel): *«Endreinigungen sind auch nach dem
Saisonschluss möglich, mitten in der Zwischensaison»* — daraus entstünden
falsche Saison-Enden. Die Tabelle startet leer und füllt sich ab jetzt.

**Auslöser ist das Startdatum.** Ändert sich der Start einer Saison, wandert
das bisherige Fenster komplett ins Archiv. Ein geändertes Ende archiviert
nichts — das ist eine Korrektur derselben Saison. Ohne diese Unterscheidung
entstünde beim getrennten Speichern von Ende und Start ein zweiter Eintrag mit
vermischten Daten.

**Auch der Saisonstart wird geführt**, obwohl er sich aus den Reinigungen kaum
belegen liesse (nur 24 erfasste Eröffnungen gegenüber 345 Endreinigungen) —
ab jetzt steht er ja am Betrieb.

## Umsetzung

**Tabelle `betrieb_saison_historie`** (Migration 186): `betrieb_id`, `saison`
(`winter`/`sommer`), `start_datum`, `ende_datum` (nullable — eine Teilangabe
ist besser als keine), `archiviert_am`, `user_id`. RLS wie überall,
eindeutiger Index über (Betrieb, Saison, Start) gegen Dubletten beim Hin- und
Zurückändern.

**`saisonArchivEintrag()`** in `core/util/saison_historie.dart` trifft die
Entscheidung als reine Funktion (7 Tests). **`BetriebSaisonHistorieRepository`**
liest und schreibt; `archiviere()` wirft nie — ein fehlgeschlagenes Archiv darf
das Speichern eines Betriebs nicht verhindern.

**Anzeige** im Betriebs-Formular unter den Saison-Feldern, grau und einzeilig:
`Bisher: 13.12.2025–29.03.2026 · 05.12.2024–31.03.2025` (letzte fünf).

**Bewusst ohne Isar-/Offline-Pfad:** Das Archiv wird nur beim Bearbeiten eines
Betriebs gelesen und geschrieben, und das passiert online. Ein nativer Zweig
wäre heute toter Code; die Android-App (V2) entsteht in einem eigenen
Repository.

**Nicht angefasst:** Betriebsferien haben mit `betrieb_ferien` seit
Migration 160 bereits eine eigene Historie.

## Offen

- Die Historie füllt sich erst mit der nächsten Saisonänderung. Bis dahin
  bleibt die Zeile leer — bewusst in Kauf genommen (siehe Entscheid oben).
- 53 Betriebe mit abgelaufenen Saisondaten sind damit noch nicht gepflegt.
  Ob es dafür eine Prüfliste braucht, ist offen; die Infrastruktur dafür
  existiert (`aufgaben`, `betrieb_vorschlaege`).
