# Buchhaltung — Auswertung Umsatz/Arbeiten (Jahr + Monat) — Design

**Datum:** 2026-07-11 · **Status:** abgenommen (Layout + Entscheidungen) → Implementierungsplan folgt

## Ziel

Ein neuer Screen unter **Buchhaltung** (`/buchhaltung/auswertung`, Dashboard-Kachel „Auswertung"), der die
erfassten **Arbeiten** und **Umsätze** nach **Jahr und Monat** auswertet — als App-Pendant zum Blatt
„Auswertung" der Excel-Datei `00_SBS_Projer_70.xlsm` — mit professionellen **grafischen Auswertungen**
(Jahresverlauf, Vorjahresvergleich, Monatsvergleich über Jahre) und einer **detaillierten Tabelle**.
Smartphone-first (Google Pixel 9), übersichtlich, intuitiv.

## Referenz: Excel-Blatt „Auswertung" (rekonstruiert & verifiziert)

Zwei Ebenen: **Jahresübersicht** (1 Zeile/Jahr) + **Monats-Detail** (Jahr × 12 Monate). Je Arbeitsart ein
Paar **Anzahl + Betrag**. Verifizierte Rechenlogik (2019 und 2025 bestätigt):

- **Total (inkl. MWST) = Reinigung (Kunde) + Rechnung HK (Heineken)**
  - 2019: 66'811 + 50'034 = 116'845 ✓ · 2025: 123'869 + 89'966 = 213'835 ✓
- **Rechnung HK (inkl.) = (Reinigung HK + Störung + Eigenauftrag + Eröffnung/Endreinigung + Montage + Pikett + BK-Pauschale) [netto] × MwSt-Faktor**
  - 2025: 83'224 netto × 1.081 = 89'966 ✓
- **Kunde zahlt Reinigungen** (direkt), **Heineken zahlt den Rest** (Monatsrechnung).

## Kategorien & Datenherkunft (App)

Split „Kunde vs. Heineken" läuft über **`betrieb.rechnungsstellung == 'heineken'`**.

| Kategorie | App-Quelle | Datum | Netto-Feld | zählt zu |
|---|---|---|---|---|
| **Reinigung** (Kunde) | `reinigungen` bei Betrieb ≠ heineken | `datum` | `preisNetto` | Kunden-Seite |
| **Reinigung HK** | `reinigungen` bei Betrieb = heineken | `datum` | Heineken-Tarif (s.u.) | Rechnung HK |
| **Störung** | `stoerungen` | `datum` | `preisNetto` | Rechnung HK |
| **Eigenauftrag** | `eigenauftraege` | `datum` | `pauschale` | Rechnung HK |
| **Eröffnung/Endreinigung** | `eroeffnungsreinigungen` | `datum` | `preis` | Rechnung HK |
| **Montage** | `montagen` | `datum` | `kostenArbeit` | Rechnung HK |
| **Pikett** | `pikett_dienste` | `datumStart` | `pauschaleGesamt ?? pauschale` | Rechnung HK |
| **BK-Pauschale** | `bergkundenpauschalen` | `datum` | `betrag` | Rechnung HK |

Abgeleitet je (Jahr, Monat):
- **Rechnung HK** = Σ HK-Kategorien (netto) × MwSt-Faktor des Monats.
- **Total** = Reinigung (Kunde) + Rechnung HK.
- **Anzahl** je Kategorie = Anzahl Datensätze; „Arbeiten gesamt" = Summe aller Kategorien.

**Heineken-Reinigungstarif / exakte Bewertung:** Für „Reinigung HK" und die Heineken-Monatssumme gilt die
bestehende `HeinekenRechnungService`-Logik als fachliche Autorität (bereits produktiv, erzeugt die realen
Abrechnungswerte). Die genaue Feldwahl je Fall wird über **TDD gegen die Excel-Zahlen** (und die Überlappung
Dez 2025, s.u.) fixiert — die Excel-Werte sind die Abnahme-Kriterien.

## MwSt

- Anzeige **umschaltbar netto/brutto** (Segment im Screen).
- Netto = die o.g. Netto-Felder. Brutto = netto × **date-aware MwSt-Faktor** (Preis-Historie; CH 7.7 % bis
  2023, 8.1 % ab 2024). Reinigung/Störung haben `preisBrutto` direkt; Pauschal-Kategorien werden aus netto
  hochgerechnet.

## Datenstrategie (wichtig)

DB-Bestand (geprüft 11.07.2026): `reinigungen` (8621, ab 2019) und `rechnungen` (4967, ab 2019) haben volle
Historie; **Störungen/Montagen/Eigenaufträge/Eröffnung/Bergkunden/Pikett existieren erst ab Dez 2025**;
historische **Heineken-Monatsrechnungen fehlen** (erst ab 2026). Die Excel-Historie 2019–2025 lebt nur im
Excel.

**Entscheidung (User):** Kein separater Aggregat-Historien-Import. Die Auswertung rechnet **rein live** über
die echten App-Datensätze. Die Historie wird in **Phase 2 (eigenes Folge-Projekt)** durch Backfill der
**echten** historischen Datensätze ergänzt (Heineken-Aufträge als reguläre Einträge + Heineken-Rechnungen
nacherfassen & abgleichen) → die Auswertung füllt sich dann automatisch, **ohne Screen-Umbau**.

### Phase 1 (dieser Plan) — sichtbarer Umfang heute
- **Reinigung:** volle Historie (2019+) aus `reinigungen`.
- **Übrige Kategorien + Heineken-Split:** ab **Dez 2025**.
- Ältere Jahre zeigen vorerst v.a. Reinigung — bewusst akzeptiert.

### Phase 2 (später, NICHT in diesem Plan) — in ToDo.md
- Historische Heineken-Aufträge (Störung/Montage/Eigenauftrag/BK/Eröffnung) aus Excel als echte Einträge
  importieren.
- Historische Heineken-Monatsrechnungen nacherfassen & mit den Aufträgen abgleichen.

## Screen-Aufbau (Smartphone-first)

Vertikal gescrollt, in `AppFilterBar`/Karten-Stil der App, **grün dezent** (Akzent, nicht vollflächig).

1. **Kopf:** Titel „Auswertung" + **netto/brutto-Umschalter**.
2. **Modus-Umschalter (3-fach):**
   - **Jahr** — 12 Monate eines Jahres (Jahr-Dropdown), Verlaufskurve mit **Vorjahres-Overlay**.
   - **Jahre** — Jahres-Totale nebeneinander (alle Jahre).
   - **Monatsvergleich** — **ein Monat über alle Jahre** (Monat-Dropdown; z. B. jeder Juni).
3. **KPI-Kopf:** Total-Umsatz + Δ % ggü. Vorjahr + Aufteilung **Kunde / Heineken** (+ „Arbeiten gesamt").
4. **Charts (`fl_chart`):**
   - Jahr-Modus: Linien-/Flächenchart (12 Monate) + gestrichelte Vorjahreslinie + Gitternetz.
   - Jahre-Modus: Balken je Jahr (aktuelles Jahr hervorgehoben).
   - Monatsvergleich: Balken je Jahr für den gewählten Monat.
5. **Detail-Tabelle (professionell, keine Chips):** Spalten **Monat · Anzahl · Kunde · Heineken · Total**,
   rechtsbündige Tausender-Zahlen (Schweizer `'`-Trennung), Zebra-Zeilen, Kopfzeile, fette **Total-Zeile**.
   Zeile antippen → voller **Kategorien-Breakdown** (Reinigung/Reinigung HK/Störung/Montage/… mit Anzahl +
   Betrag). Kein horizontales Seiten-Scrollen; die Basis-Tabelle passt in die Pixel-9-Breite.

## Architektur / Umsetzung

- **Reiner Aggregations-Helfer** `lib/services/auswertung/auswertung_aggregat.dart` (reine Funktionen, TDD):
  Eingaben = die vorhandenen Listen (`reinigungenProvider` etc. — bzw. deren Local-Listen) + Betrieb→
  `rechnungsstellung`-Lookup + MwSt-Faktor-Funktion. Ausgabe = Map `(jahr, monat) → AuswertungMonat`
  (je Kategorie Anzahl + Netto; abgeleitet Kunde/RechnungHK/Total). Zusätzliche Reduktionen: Jahres-Total,
  Monatsvergleich-Serie.
- **Provider** `auswertungProvider` (Riverpod) kombiniert die bestehenden Listen-Provider → Aggregat.
- **Screen** `lib/presentation/screens/buchhaltung/auswertung_screen.dart` + Chart-Widgets.
- **Dependency:** `fl_chart` in `pubspec.yaml`.
- **Routing:** neue `GoRoute` `/buchhaltung/auswertung` (nach `/buchhaltung/berichte`); neue `_NavTile` im
  Buchhaltungs-Dashboard (Icon `Icons.insights`/`bar_chart`). Heineken-Gast-Guard greift (unter `/buchhaltung`).
- **Konsistenz:** dieselbe Preisfeld-Wahl je Typ wie `tagesUebersichtProvider` (Home-Screen) → keine
  widersprüchlichen Zahlen.

## Tests (TDD)

- Reine Aggregat-Funktion gegen **synthetische** Eingaben (Kategorien, Kunde/HK-Split, MwSt netto↔brutto,
  Jahr/Monat-Gruppierung, Monatsvergleich-Serie, leere Monate).
- **Abnahme gegen Excel:** die Aggregat-Logik muss die Excel-Werte reproduzieren, wo die App-Daten vollständig
  sind — insbesondere **Dez 2025** (Überlappung: alle Arbeitstypen live vorhanden + Excel-Zeile vorhanden) und
  **Reinigung** für frühere Jahre. Diese Werte werden als fixe Testfälle hinterlegt.

## Nicht in Phase 1 (Out of Scope)
- Excel-/Historien-Backfill (Phase 2, eigenes Projekt).
- PDF-/Mail-Export der Auswertung (optionale Phase 3, analog `berichte_screen`).
- Filter nach Region/Betrieb.

## Offene technische Detailpunkte (im Plan via TDD zu fixieren)
- Exakte Bewertung „Reinigung HK" (Heineken-Tarif vs. `preisNetto`) → gegen Excel/HeinekenRechnungService.
- „Rechnung HK" live aus Kategorien abgeleitet vs. später aus nacherfassten Heineken-Rechnungen (Phase 2 gleicht ab).
