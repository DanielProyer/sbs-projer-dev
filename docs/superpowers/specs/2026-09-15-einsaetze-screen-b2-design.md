# Ein Einsätze-Screen für alle Typen (B2) — Design

**Datum:** 15.09.2026 · **Entscheide:** Daniel · **Grundlage:** `docs/app-analyse-2026-09.md` (B2, Befund 3)

## Problem

Für die Arbeit sind Reinigung, Störung, Montage, Eigenauftrag,
Eröffnungsreinigung und Pikett dasselbe: ein Einsatz bei einem Betrieb an
einem Tag, der verrechnet wird. Im Code sind es sechs Welten mit vier
Status-Vokabularen — «fertig» heisst je nach Typ `abgeschlossen` oder
`behoben`, und «verrechnet» ist nirgends ein Status, sondern überall ein
zweites Feld daneben. Sechs Listen-Screens mit 2'528 Zeilen bauen dieselbe
Ansicht sechsmal; der Aufgaben-Screen, die Heute-Karte, der Tourenplan und die
Heineken-Rechnung setzen die Vereinigung jeweils neu zusammen. So fällt nicht
auf, wenn `anlage_detail_screen.dart:878` eine Störung mit `'abgeschlossen'`
vergleicht — einem Wert, den Störungen nie tragen.

## Was die Ist-Aufnahme ergab (15.09.2026)

Jede Zahl ist gemessen, in der Datenbank oder im Code.

1. **Die Datenbank kennt nur «fertig».** Je Tabelle genau ein Statuswert:
   8'647 Reinigungen `abgeschlossen`, 1'141 Störungen `behoben`, 822 Montagen
   `abgeschlossen`, 123 Eigenaufträge `behoben`. Keine offene Störung, eine
   geplante Montage, null angefangene Einsätze. «Geplant» und «in Arbeit»
   leben im Tourenplan, in `termine` (5 geplante Eröffnungsreinigungen) und
   flüchtig zwischen Anlegen und Abschliessen — nicht in den Tabellen.
2. **`abgerechnet` heisst nur «in einer Heineken-Monatsrechnung».** Alle 204
   Reinigungen mit Barzahlung, Tresen-, Mail- oder Postrechnung seit Juli
   tragen `false`, obwohl sie längst verrechnet sind. Die Heineken-Rechnung
   grenzt ihre Quellen allein über den Datumsbereich ab und setzt das Flag
   erst nach dem Erstellen.
3. **Die v2 hängt nicht an den Statusspalten.** Ihre Zeitleiste
   (`betrieb_zeitleiste_sicht`) leitet den Status aus dem Ende-Zeitpunkt ab.
   Eine Migration wäre nicht blockiert — die Datenbank ist trotzdem geteilt.
4. **Die sechs Listen sind ein Skelett.** Alle haben Suchfeld, «+»-Knopf,
   Jahr/Monat-Leiste und Tipp auf die Detailseite; Reinigungen und Störungen
   dazu einen Regionen-Filter, Störungen noch Typ, Art und Bereich. Genutzt
   werden drei: Reinigungen 13×, Störungen 11×, Montagen 5× — Eigenaufträge
   1×, Eröffnungen und Pikett 0×, **der Aufgaben-Screen 0×**.
5. **Rund 37 verstreute Statusvergleiche** in `lib/`: 16× `'abgeschlossen'`,
   10× `'offen'`, 6× `'in_bearbeitung'`, 3× `'geplant'`, 2× `'behoben'`. Das
   ist eine obere Grenze — die Zählung trifft auch `zahlungsstatus == 'offen'`
   der Rechnungen; exakt zählt erst der Ratschen-Wächter (Bauteil 7). Dazu die
   Ableitung in `tour_filter.dart`, die es einmal richtig macht.

## Entscheide

**Ableiten statt migrieren.** Der einheitliche Status ist eine reine Funktion
aus vorhandenen Feldern — keine Datenbankänderung, keine CHECK-Constraints,
keine Absprache mit dem Heineken-Projekt. Die Migration aus der Analyse würde
vier Erledigt-Wörter umbenennen und 37 Codestellen anfassen, brächte der
Oberfläche aber nichts, was die Ableitung nicht auch bringt. Und «verrechnet»
müsste ohnehin abgeleitet werden (Befund 2). Ein gespeicherter zweiter
Wahrheitswert wäre genau das Muster, das im September Ertragsbuchungen
gekostet hat: zwei Felder, die auseinanderlaufen können.

**Fünf Stufen statt vier.** Die Analyse sah `geplant → in Arbeit → erledigt →
verrechnet`. Eine gemeldete Störung ohne Termin ist aber weder geplant noch in
Arbeit — sie ist **offen**. Das ist der Zustand, den Daniel morgens sucht.

**«Verrechnet» bei Reinigungen: `abgerechnet` oder Ertragsbuchung vorhanden.**
Die beiden Signale schliessen sich aus und ergänzen sich: Heineken-Reinigungen
bekommen keine eigene Ertragsbuchung (die entsteht erst mit der Monatsrechnung)
und tragen `abgerechnet`; alle anderen Zahlungsarten — Bar, Tresen, Mail,
Post, Jahresrechnung — bekommen beim Abschluss eine Buchung und tragen nie
`abgerechnet`. Das **Oder** macht die Zahlungsart als Eingabe überflüssig und
deckt auch die 8'439 Altdaten ohne Zahlungsart ab. Die Buchungs-Prüfung hat die
App schon (`BuchungNachholService.finde`, Frühwarnung vom 10.09.2026).
Störungen, Montagen, Eigenaufträge und Pikett laufen ausnahmslos über Heineken
(keine Zahlungsart am Modell, die 5'159 Kundenrechnungen sind alle
Reinigungen) — dort gilt `abgerechnet`.

**Alle sechs Typen plus Termine.** Der Sinn des Screens ist, dass es nur einen
gibt; seltene Typen kosten im Filter nichts. Die geplanten Eröffnungs- und
Endreinigungen aus `termine` gehören dazu, sonst fehlte ausgerechnet das
Geplante.

**Der Aufgaben-Screen bleibt in B2 unangetastet.** Null Öffnungen in sechs
Tagen — die Glocke ist der Weg. Sein Umbau gehört zu B6 («ein
Aufgaben-Begriff»). Das weicht von der Analyse ab und ist so entschieden.

**Die alten Listen bleiben einen Auslieferungszyklus erreichbar** und werden
danach entfernt. Ein Test hält fest, ab welcher Version.

**Zeile B** — zwei Zeilen wie die Heute-Liste: Betrieb gross, darunter Typ,
Ort und Datum; rechts Status-Badge und Betrag. Nach Tag zu gruppieren (Variante
C) bleibt möglich, ist nur eine Sortierung mit Kopfzeilen.

## Bauteile

### 1. Der abgeleitete Status — `lib/core/util/einsatz_status.dart`

```dart
enum EinsatzStatus { offen, geplant, inArbeit, erledigt, verrechnet }
enum EinsatzKennzeichen { keines, abgebrochen, nichtBehebbar }
```

Je Typ eine reine Funktion mit **primitiven Eingaben** — kein Modell, damit
die Tests ohne Isar und Supabase auskommen und die Regel für die v2 lesbar
bleibt:

| Funktion | Eingaben | offen | geplant | in Arbeit | erledigt | verrechnet |
|---|---|---|---|---|---|---|
| `reinigungStatus` | `status`, `abgerechnet`, `hatBuchung` | — | — | `offen` | `abgeschlossen` | `abgerechnet` **oder** `hatBuchung` |
| `stoerungStatus` | `status`, `geplantAm`, `arbeitVon`, `arbeitBis`, `abgerechnet` | `offen` ohne Termin | `offen` mit `geplantAm` | `in_bearbeitung`, oder `arbeitVon` ohne `arbeitBis` | `behoben`, `nicht_behebbar` | `abgerechnet` |
| `montageStatus` | `status`, `arbeitVon`, `arbeitBis`, `abgerechnet` | — | `geplant` | `in_bearbeitung`, oder `arbeitVon` ohne `arbeitBis` | `abgeschlossen` | `abgerechnet` |
| `eigenauftragStatus` | `status`, `abgerechnet` | — | — | `nachbearbeitung_noetig` | `behoben`, `nicht_behebbar` | `abgerechnet` |
| `eroeffnungsreinigungStatus` | `abgerechnet` | — | — | — | immer | `abgerechnet` |
| `terminStatus` | `status` | `vorgeschlagen` | `geplant` | — | `erledigt` | — |
| `pikettStatus` | `istAktiv`, `abgerechnet` | — | — | `istAktiv` | sonst | `abgerechnet` |

Kennzeichen: Reinigung `storniert`, Montage `abgebrochen`, Termin `abgesagt` →
**abgebrochen**; Störung und Eigenauftrag `nicht_behebbar` → **nicht
behebbar**. Beide bleiben sichtbar, statt in «erledigt» zu verschwinden.

**Vorrang:** Treffen mehrere Stufen zu, gilt die höchste — `abgerechnet` auf
einer Störung `in_bearbeitung` zeigt «verrechnet». Ein Kennzeichen ändert die
Stufe nicht, es steht daneben.

Unbekannte Statuswerte werfen nicht, sie ergeben «offen» — so fällt ein neuer
Wert in der Liste auf, statt die Liste zu stürzen.

### 2. Die Einsatz-Sicht — `lib/core/util/einsatz.dart`

```dart
class Einsatz {
  final EinsatzTyp typ;          // reinigung, stoerung, montage, eigenauftrag, eroeffnung, termin, pikett
  final String routeId;          // für die bestehende Detailseite
  final String? betriebId;
  final String betriebName;
  final String? betriebOrt;
  final String? betriebNr;       // für die Suche nach A9
  final String? regionId;
  final DateTime datum;
  final String? zeit;            // nur bei geplanten Terminen (HH:mm)
  final String? beschreibung;    // Störung/Montage: was diktiert oder erfasst wurde
  final EinsatzStatus status;
  final EinsatzKennzeichen kennzeichen;
  final double? betragCHF;       // null bei geplanten und bei Terminen
}
```

Je Typ eine Funktion `einsatzAusReinigung(ReinigungLocal, {betrieb, hatBuchung})`
usw., die das lokale Modell in die Sicht übersetzt und dabei die Statusfunktion
aus Bauteil 1 aufruft. Kein neues Datenmodell, keine Tabelle — die Sicht wird
aus den geladenen Daten berechnet, wie `TourEintrag` es für den Tourenplan tut.

Betrag: Reinigung `preisBrutto`, Störung `preisNetto`, Montage `kostenArbeit`,
Eigenauftrag und Pikett `pauschale`, Eröffnung `preis`. Termine haben keinen.

### 3. Die Buchungs-Abfrage — `BuchungRepository.belegIdsMitBuchung`

```dart
static Future<Set<String>> belegIdsMitBuchung({required DateTime ab, required DateTime bis})
```

Liefert die `beleg_id`s aller nicht stornierten Buchungen mit `beleg_typ =
'rechnung'` im Zeitraum. **Eine** Anfrage je geladenem Jahr; die bestehende
`getByBeleg(id)` wäre eine Anfrage je Zeile — tausend pro Jahr.

### 4. Die Provider — `lib/presentation/providers/einsatz_providers.dart`

- `belegIdsMitBuchungProvider(jahr)` — Bauteil 3, gecacht je Jahr.
- `einsaetzeProvider(jahr)` — vereinigt `reinigungenByJahrProvider(jahr)`,
  `stoerungenProvider`, `montagenProvider`, `eigenauftraegeProvider`,
  `eroeffnungsreinigungenProvider`, `pikettDiensteProvider` und
  `offeneTermineProvider` zu `List<Einsatz>`, sortiert nach Datum absteigend.
  Betriebsname, Ort, Nummer und Region kommen aus den bestehenden
  Lookup-Providern (`betriebNameMapProvider` usw.).

Reinigungen werden wie heute jahresweise geladen (~1'000 pro Jahr), alle
anderen Typen liegen ohnehin vollständig im Speicher.

### 5. Der Screen — `lib/presentation/screens/einsaetze/einsaetze_screen.dart`

Route `/einsaetze`, optional `?typ=reinigung` (Vorwahl im Typ-Filter).

**Filter**, alle aus `widgets/filter/`:
- Typ — `AppFilterMultiDropdown` (keine Chip-Reihe: sechs Typen wären zu lang
  fürs Handy, siehe Regel «kompakte Dropdowns statt Chips»)
- Status — `AppFilterMultiDropdown` über die fünf Stufen
- Jahr/Monat — `AppJahrMonatLeiste`
- Region — `AppFilterMultiDropdown` (heute in Reinigungen und Störungen)
- Suche — `SearchBar` mit `betriebPasst()` aus A9
- **Nur wenn im Typ-Filter genau «Störung» gewählt ist:** die drei
  Störungs-Zusatzfilter Typ, Art, Bereich (Paket 06, auf Daniels Wunsch
  gebaut — sie dürfen nicht verschwinden)

**Zeile** (Variante B), aus `InkWell` + `Container` + `Row`, kein `ListTile`:
- links Typ-Symbol; Mitte: Betrieb fett, darunter «Typ · Ort · Wochentag
  Datum», bei geplanten Terminen mit Uhrzeit, bei Störung und Montage mit der
  Beschreibung; rechts Status-Badge und Betrag (leer bei geplant und Termin).
- Tipp öffnet die bestehende Detailseite des Typs (`/reinigungen/:id` usw.);
  Termine öffnen den Betrieb.

**«+»**: Ist im Typ-Filter genau ein Typ gewählt, direkt in dessen Formular.
Sonst ein Sheet mit den Typen — aus `GestureDetector` + `Container`, kein
`ListTile`.

### 6. Einhängen

- `router.dart`: Route `/einsaetze`.
- `home_screen.dart`: Die Kacheln Reinigungen, Störungen, Montagen,
  Eigenaufträge, Eröffnungen führen auf `/einsaetze?typ=…`; Pikett unter
  «Weitere» ebenso. Die Zähler bleiben (A2).
- Die alten Routen `/reinigungen`, `/stoerungen`, `/montagen`,
  `/eigenauftraege`, `/eroeffnungsreinigungen`, `/pikett` bleiben **einen
  Zyklus** bestehen. `test/alte_listen_ablauf_test.dart` schlägt ab der im
  Test genannten Version an, solange sie noch existieren.

### 7. Der Ratschen-Wächter — `test/status_vergleiche_ratsche_test.dart`

Zählt die `status == '…'`-Vergleiche gegen die Einsatz-Vokabulare in `lib/`
ausserhalb von `einsatz_status.dart` und `tour_filter.dart`. Der Stand nach B2
wird im Test festgeschrieben; **die Zahl darf nur sinken.** So wandern die 37
Stellen ohne Grossaktion auf die eine Funktion, und `anlage_detail_screen.dart:878`
verschwindet, sobald jemand diese Datei anfasst. Kommentare werden vor dem
Zählen ausgeblendet (Lehre vom 10.09.2026).

## Abgrenzung

- **Keine Migration, kein neues Feld, keine neue Tabelle.** Der Status wird
  abgeleitet.
- **Kein Umbau des Aufgaben-Screens** — B6.
- **Keine Löschung der alten Listen in B2** — erst im Folgezyklus.
- **Keine Änderung an den Formularen oder Detailseiten** — der Screen führt
  dorthin, er ersetzt sie nicht.
- **Nicht in B2:** die untere Navigationsleiste (B1), die Büro-Startseite
  (B3), der Monatsabschluss (B4).
- **Für die v2:** Bauteil 1 ist die Spezifikation des Einsatz-Modells (C1) in
  ausführbarer Form. Sie gehört der Heineken-Session übergeben, nicht dort
  nachgebaut.

## Tests

- **Statusableitung:** je Typ tabellengetrieben über alle Statuswerte der
  CHECK-Constraints; Vorrang bei Mehrfachtreffern; Kennzeichen; unbekannter
  Wert ergibt «offen». Die Reinigungs-Regel je Zahlungsart, insbesondere
  Heineken mit `abgerechnet = false` → erledigt, Tresen mit Buchung → verrechnet.
- **Einsatz-Sicht:** je Typ, dass Betrag, Datum und Beschreibung aus den
  richtigen Feldern kommen; Termine ohne Betrag.
- **Screen:** mit echter Schrift (Roboto laden, wie `kachel_text_test.dart`)
  auf 360 px; Zeile ohne `ListTile`/`FilledButton`; Filter Typ und Status
  greifen; Suche findet über Ort (A9); «+» mit genau einem Typ springt direkt.
- **Ratsche:** Startwert festgeschrieben, Gegenprobe mit einem zusätzlichen
  Vergleich muss anschlagen.
- **Ablauf der alten Listen:** schlägt an ab der genannten Version.

## Lieferung

Ein Deploy, die Aufgaben im Plan aber so geordnet, dass die reinen Funktionen
(Bauteile 1–3) zuerst stehen und einzeln geprüft sind, bevor der Screen darauf
gesetzt wird. Vor dem Deploy: Version bumpen (`pubspec.yaml` **und**
`kAppVersion`), Build mit `--pwa-strategy=none`, Cache-Bust, `404.html`
mitliefern; der Screen wird vorher im Browser bei 360 px und am PC angesehen.
Nach dem Deploy Klicktest durch Daniel: eine Reinigung, eine Störung, ein
geplanter Termin — jede Zeile öffnet die richtige Detailseite, der Status
stimmt.
