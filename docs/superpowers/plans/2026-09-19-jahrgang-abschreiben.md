# «Jahrgang abschreiben» — geführter Abschluss-Schritt (Umsetzungsplan)

**Ziel:** Aus der Abschlussprüfung heraus die verjährten Jahrgänge eines Geschäftsjahres in einem Klick abschreiben — mit Vorschau (Tresen / gestellt / nie gestellt, Summen netto + MWST je Satz), Freigabe, Buchungen je Rechnung, Statuswechsel, Rücknahme und dem Ziff.-235-Wert in der MWST-Abrechnung.

**Konzept:** `docs/buchhaltung/abschreibungen-jahrgaenge.md` (Entscheide 19.09.2026: minus 5, 2020 + 2021 im Abschluss 2026, keine Nachfaktura).

**Architektur:**
- **Atomar in der Datenbank.** PostgREST kennt keine Transaktionen; 160 Rechnungen × 2 Buchungen + Status dürfen nicht halb durchlaufen. Deshalb eine SQL-Funktion `abschreibung_jahrgang_buchen(geschaeftsjahr, rechnung_ids[])`, die alles in einer Transaktion bucht und die Auswahl nochmals prüft (offen, Kundenrechnung, Jahrgang ≤ Jahr − 5, keine Zahlung, Summen stimmig). Gegenstück `abschreibung_lauf_zuruecknehmen(lauf_id)`.
- **Snapshot = Lauf-Tabellen.** `abschreibung_laeufe` (ein Lauf je Geschäftsjahr, Summen, MWST-Quartal) + `abschreibung_positionen` (je Rechnung: Status vorher, Beträge, Buchungs-IDs). Ersetzt das Schema-Snapshot-Verfahren von 2019; der 2019er-Lauf wird nachgetragen, damit Q3/2026 seinen Ziff.-235-Wert zeigt.
- **Vorschau rein in Dart** (`jahrgang_abschreibung.dart`): Auswahl, Kategorie, Summen je Satz — ohne Repository, damit testbar. Die SQL-Funktion rechnet dieselben Beträge aus denselben Spalten; die Vorschau zeigt, was gebucht wird.
- **MWST aus `rechnungen.mwst_betrag`**, nie aus dem Satz des Buchungstages. Der alte `AbschreibungService.abschreiben` bekommt einen `mwst`-Parameter; das Mahnwesen übergibt ihn.

**Tech-Stack:** Flutter · Riverpod · Supabase (SQL-Funktion) · `flutter_test`

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `Datenbank/migrations/194_abschreibung_jahrgang.sql` | Tabellen, RLS, Funktionen, 2019er-Lauf nachtragen | **Neu** |
| `lib/services/buchhaltung/jahrgang_abschreibung.dart` | `AbschreibKategorie`, `verjaehrtBis`, `auswahlFuer`, `Vorschau` | **Neu** |
| `lib/data/models/abschreibung_lauf.dart` | DTOs Lauf + Position | **Neu** |
| `lib/data/repositories/abschreibung_lauf_repository.dart` | `getAll`, `getPositionen`, `buchen` (rpc), `zuruecknehmen` (rpc) | **Neu** |
| `lib/presentation/providers/abschreibung_providers.dart` | Vorschau- und Läufe-Provider | **Neu** |
| `lib/presentation/screens/buchhaltung/jahrgang_abschreiben_screen.dart` | Screen + `JahrgangAbschreibenInhalt` | **Neu** |
| `lib/core/config/router.dart` | `/buchhaltung/abschreibung?jahr=` | Ändern |
| `lib/services/buchhaltung/abschluss_regeln.dart` | `DebitorenVerjaehrtRegel` → Route auf den Schritt | Ändern |
| `lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart` | Zeilen Ziff. 235 + Rückholung je Satz | Ändern |
| `lib/services/buchhaltung/abschreibung_service.dart`, `mahnwesen_service.dart` | `mwst`-Parameter | Ändern |
| `test/jahrgang_abschreibung_test.dart` | reine Logik | **Neu** |
| `test/jahrgang_abschreiben_layout_test.dart` | 360 px, grosse Schrift | **Neu** |

## Schritte

- [x] 1 Migration 194 schreiben, anwenden, Funktion in einer Transaktion probebuchen und zurückrollen
- [x] 2 Logik + Tests (Kategorie, Grenze, Auswahl, Summen je Satz, Ausschlüsse)
- [x] 3 DTOs, Repository, Provider
- [x] 4 Screen: Vorschau, Freigabe-Dialog, Lauf-Karte mit Rücknahme (`TapKnopf gefahr`)
- [x] 5 Router, Prüfregel-Route, MWST-Screen Ziff. 235
- [x] 6 `AbschreibungService` + Mahnwesen auf `mwst_betrag`
- [x] 7a analyze (56, Basis), 1712 Tests grün, Doku/ToDo/Memory
- [ ] 7b Browser-Check (Login Daniel nötig) → Deploy v0.116.0
