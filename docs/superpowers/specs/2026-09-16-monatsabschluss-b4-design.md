# Monatsabschluss als geführte Checkliste (B4) — Entwurf

Stand 16.09.2026 · Vorschlag B4 aus `docs/app-analyse-2026-09.md` · nutzt B2 (`einsatz_lage.dart`, `belegIdsMitBuchung`) und B3 (Offen-Block, `istVorrat`).

## 1. Befund

Die App prüft den **Jahres**abschluss mit 17 Regeln (`abschluss_regeln.dart`, 665 Zeilen) — sauber gebaut: eine abstrakte `AbschlussRegel` (`id`, `gruppe`, `titel`, `pruefe(kontext)`), ein `AbschlussKontext`, der alle Daten einmal vorlädt, und ein `Pruefbefund` mit rot/gelb/grün, Ist, Soll, Hinweis und `aktionRoute`.

Für den **Monat** gibt es nichts. Dabei ist der Monat der Takt des Geschäfts: Heineken-Monatsrechnung, Lohnlauf, Bankauszug. Genau der Fehlertyp «Kette bricht ab» — am 03./04.09.2026 fehlten zwei Ertragsbuchungen, weil das Handy mitten im Abschluss wegging — wird monatlich sichtbar, bevor er teuer wird.

In der Datenbank gibt es **keinen Monats-Status**; nichts hält fest, dass ein Monat abgeschlossen wäre.

## 2. Entscheidungen

1. **Eine Kontrolle, kein Ritual.** Kein «Monat schliessen»-Häkchen, keine neue Tabelle. Die Regeln lesen den Ist-Zustand; was grün ist, ist erledigt. Ein Zustand, den niemand pflegt, wird schnell unehrlich — und die Datenbank ist mit der v2 geteilt.
2. **Dasselbe Muster, eigene Dateien.** Die 17 Jahresregeln werden nicht angefasst; `Pruefbefund` und `PruefStatus` werden geteilt.
3. **Zehn Regeln** in vier Gruppen (Einsätze, Heineken, Bank, Lohn).
4. **Ein Detektor auf der Büro-Startseite** (B3): «August: 3 Punkte offen», als **Vorrat** — also nicht in der Glocke.
5. **Der laufende Monat wird nicht rot bewertet.** Was erst am Monatsende fällig ist, meldet dort gelb mit «Monat läuft noch».

## 3. Bauteile

### 3.1 `lib/services/buchhaltung/monats_pruef_service.dart` — Kontext und Lauf

```dart
class MonatsKontext {
  final int jahr, monat;
  final DateTime heute;
  DateTime get von;            // erster Tag des Monats
  DateTime get bis;            // letzter Tag des Monats
  bool get istLaufenderMonat;  // jahr/monat == heute
  // vorgeladene Daten (siehe 3.3)
}

List<Pruefbefund> pruefeMonat(MonatsKontext k);
```

`pruefeMonat` läuft über `alleMonatsRegeln()` und sortiert wie das Jahres-Pendant: erst nach Status (rot, gelb, grün), dann nach Regelrang. `Pruefbefund` und `PruefStatus` kommen unverändert aus `abschluss_pruef_service.dart`.

### 3.2 `lib/services/buchhaltung/monats_regeln.dart` — die zehn Regeln

Abstrakte `MonatsRegel` mit `id`, `gruppe`, `titel`, `pruefe(MonatsKontext)` und dem `befund(...)`-Helfer — wörtlich nach dem Vorbild `AbschlussRegel`.

| Regel-Id | Gruppe | Prüft | Rot, wenn |
|---|---|---|---|
| `reinigungen_offen` | Einsätze | Reinigungen des Monats mit Status ≠ `abgeschlossen`/`storniert` | mindestens eine offen |
| `einsaetze_offen` | Einsätze | Störungen und Montagen des Monats, deren Lage (`einsatz_lage.dart`, B2) offen/geplant/inArbeit ist | mindestens einer offen |
| `ertragsbuchungen` | Einsätze | abgeschlossene Reinigungen ohne Ertragsbuchung (`belegIdsMitBuchung`, B2); Kulanz und Nullpreis zählen nicht | mindestens eine fehlt |
| `versandvermerk` | Einsätze | Rechnungen des Monats mit `zahlungsart = rechnung_mail` und `zahlungsstatus = offen` | mindestens eine |
| `heineken_rechnung` | Heineken | Rechnung mit `rechnungstyp = heineken_monat`, `heineken_monat` = Monatserster | fehlt |
| `heineken_gesendet` | Heineken | deren Status ist mindestens `gesendet` | — (gelb) |
| `heineken_freigegeben` | Heineken | deren Status ist mindestens `freigegeben` (löst Debitoren/Ertrag) | — (gelb) |
| `bergkundenpauschalen` | Heineken | Berg-Reinigungen des Monats ohne Pauschale (`bergkundenpauschalen.datum`) | — (gelb) |
| `bank_abgedeckt` | Bank | eine camt-Datei deckt den Monat ab (`von ≤ Monatsanfang`, `bis ≥ Monatsende`) **und** kein offener Prüflisten-Eintrag mit `bookingDatum` im Monat | — (gelb) |
| `lohnlauf` | Lohn | `lohn_abrechnungen`-Zeile mit `jahr`/`monat` des Monats | — (gelb) |

**Status-Regel:** Grün = erledigt. **Rot** = etwas fehlt, das Geld kostet (offene Reinigung, fehlende Ertragsbuchung, fehlende Heineken-Rechnung, Rechnung ohne Versandvermerk). **Gelb** = unvollständig ohne direkten Verlust (Rechnung erstellt aber nicht freigegeben, Bank noch nicht importiert, Lohnlauf fehlt, Pauschale fehlt).

**Laufender Monat:** `heineken_rechnung`, `heineken_gesendet`, `heineken_freigegeben`, `bank_abgedeckt`, `lohnlauf` und `bergkundenpauschalen` liefern dort **gelb** mit dem Hinweis «Monat läuft noch» statt rot — sie sind erst am Monatsende fällig. Die vier Einsatz-Regeln bewerten auch den laufenden Monat normal: Eine Reinigung von vorgestern, die noch offen steht, ist heute schon ein Befund.

Jede Regel liefert `ist`, `soll` und eine `aktionRoute`: `/einsaetze?typ=reinigung` bzw. `?typ=stoerung`, `/rechnungen`, `/heineken`, `/bergkundenpauschalen`, `/buchhaltung/camt-import`, `/buchhaltung/lohn`.

### 3.3 Der Provider

`monatsPruefungProvider` (`FutureProvider.autoDispose.family<List<Pruefbefund>, ({int jahr, int monat})>`) lädt die Daten **einmal** und parallel — nach dem Vorbild von `abschlussPruefungProvider` (`buchhaltung_providers.dart:169`, `await (…, …).wait`): Reinigungen des Monats, Störungen und Montagen (aus den Speicher-Providern), Rechnungen des Monats, Beleg-Ids mit Buchung, Bergkundenpauschalen, camt-Dateien, offene Prüflisten-Einträge, Lohnabrechnungen des Jahres, Betriebe (für «ist Bergkunde»).

### 3.4 Screen und Detektor

`MonatsabschlussScreen` unter `/buchhaltung/monatsabschluss`, Vorgabe **Vormonat**, Jahr und Monat über die bestehende `AppJahrMonatLeiste`. Darstellung wie der Audit-Screen: je Gruppe eine Überschrift, je Regel eine Zeile mit Ampelpunkt, Titel, Ist/Soll und Sprungziel — aus `InkWell` + `Container` + `Row` (CanvasKit-Regel). Kopfzeile: «3 von 10 Punkten offen» bzw. «Alles erledigt 🎉».

Der Nav-Eintrag kommt in die Gruppe **Abschluss & Berichte** der Büro-Startseite; der Gruppen-Wächter aus B3 verlangt die Zuordnung.

Dazu ein Detektor `monatsabschluss` in `aufgaben_detektoren_provider.dart`, **Vorrat** (nicht in der Glocke), Route `/buchhaltung/monatsabschluss`, Titel «August: 3 Punkte offen» — die Zahl der nicht-grünen Regeln des **Vormonats**. Die Regelfunktion `monatsabschlussAufgabe(int anzahl, String monatName)` liegt wie die übrigen in `aufgaben_regeln.dart`.

## 4. Tests

- `test/monats_regeln_test.dart`: jede der zehn Regeln gegen einen von Hand gebauten `MonatsKontext` — grün, gelb, rot; dazu der Sonderfall «laufender Monat» für die sechs Regeln, die dort gelb liefern.
- `test/monats_pruef_service_test.dart`: `pruefeMonat` sortiert rot vor gelb vor grün und innerhalb des Status nach Regelrang; alle zehn Regeln kommen genau einmal vor.
- `test/aufgaben_regeln_test.dart` erweitert: `monatsabschlussAufgabe` — 0 ergibt `null`, N>0 Titel mit Monatsname und Zahl, `istVorrat: true`, Route.
- `test/monatsabschluss_inhalt_test.dart` (Roboto, 360 px): Gruppen, Ampelfarben, Kopfzeile, Leerzustand, Tipp meldet die Regel; kein `ListTile`.
- `test/buchhaltung_gruppen_waechter_test.dart`: der neue Eintrag steht in «Abschluss & Berichte» (die Liste im Test wird ergänzt).
- `test/canvaskit_sichere_widgets_test.dart`: der neue Screen in der Dateiliste.

## 5. Lieferung

v0.109.0. Sichtprüfung im Browser auf 360 px und 1400 px (Wegwerf-Probe wie bei B1/B2/B3/B6): alle vier Gruppen mit je einer roten, gelben und grünen Zeile, Kopfzeile, Leerzustand.

Klicktest Daniel: Vormonat ist vorgewählt · jede rote Zeile führt ans richtige Ziel · der Detektor auf der Büro-Startseite zeigt dieselbe Zahl wie der Screen · der laufende Monat zeigt bei Heineken, Lohn und Bank «Monat läuft noch» statt rot.
