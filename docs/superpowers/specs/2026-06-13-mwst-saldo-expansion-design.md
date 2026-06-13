# MWST-korrekte Saldo-Expansion – Design

**Datum:** 2026-06-13 · **Status:** Spec zur Freigabe durch Daniel
**Übergeordnet:** Phase 1 (Historie-Import), Teil 1 von 2 — Vorbedingung für den Excel-Abgleich. Teil 2 (Excel-Import) erhält eine eigene Spec.

---

## 1. Problem

Eine `buchung` ist **eine Zeile** mit `soll_konto`, `haben_konto`, `mwst_konto` und den Beträgen `betrag_netto`, `mwst_betrag`, `betrag_brutto`. Die MWST-Buchungszeile ist **implizit** in dieser einen Zeile enthalten (gleiche Struktur wie das Excel-Journal).

Die heutige Saldo-Berechnung verteilt jede Buchung als **brutto auf Soll und brutto auf Haben** und **ignoriert `mwst_konto`**. Das ist für MWST-Buchungen falsch.

**Beispiel (Einnahme, Reinigungsrechnung):** Soll 1100 / Haben 3400 / MWST 2200; netto 87.00, MWST 7.05, brutto 94.05.
- **Korrekt:** Soll Debitor 1100 = 94.05 (brutto); Haben Erlös 3400 = 87.00 (netto); Haben Umsatzsteuer 2200 = 7.05.
- **Heute (falsch):** 1100 += 94.05, 3400 −= 94.05 (Erlös um die MWST überhöht), 2200 = 0 (Umsatzsteuer-Verbindlichkeit fehlt komplett).

Betroffen sind **vier** Stellen, die alle dieselbe fehlerhafte Logik haben:
- `BuchungService.getAllSaldi` und `getKontoSaldo` (live genutzt: Kontenplan-Saldi, Buchhaltungs-Dashboard) → **aktueller Live-Bug**.
- `BilanzService.saldiPerStichtag` und `ErfolgsrechnungService.berechne` (Phase 0b) → blockiert den späteren Excel-Abgleich (App-Bilanz/ER ≠ Excel).

## 2. Lösung: eine gemeinsame Expansions-Funktion

Eine einzelne, reine Helper-Funktion verteilt eine Buchung korrekt auf die beteiligten Konten. **Klassifikation per Kontoklasse von `mwst_konto`** (robust gegen weitere MWST-Konten):
- `mwst_konto` in Klasse 1 (1000–1999) = **Vorsteuer** (Aktiv, Soll-seitig) — z. B. 1170/1171.
- sonst (≥ 2000) = **Umsatzsteuer** (Passiv, Haben-seitig) — z. B. 2200.

Beiträge je Buchung (positiv = Soll/Debit, negativ = Haben/Credit, als Roh-Saldo `Σ Soll − Σ Haben`):

| Fall | `soll_konto` | `mwst_konto` | `haben_konto` |
|---|---|---|---|
| keine MWST (`mwst_betrag == 0` oder `mwst_konto == null`) | +brutto | — | −brutto |
| Vorsteuer (mwst_konto Klasse 1) | +**netto** | +mwst | −brutto |
| Umsatzsteuer (mwst_konto ≥ 2000) | +brutto | −mwst | −**netto** |

Jede Zeile bleibt ausgeglichen: Soll-Summe = Haben-Summe = brutto.
- Vorsteuer: Soll netto + mwst = brutto; Haben brutto. ✓
- Umsatzsteuer: Soll brutto; Haben netto + mwst = brutto. ✓

Diese Roh-Saldi werden danach **unverändert** von der jeweils bestehenden Folgelogik weiterverarbeitet (Vorzeichen-Umkehr für Passiv-/Ertragskonten in `getAllSaldi`; `invertieren` für Passiven in `BilanzService.gruppiere`; Kontonummer-Bereiche in `ErfolgsrechnungService`). Die Expansion ersetzt **nur** den Verteil-Schritt, nicht die Interpretation.

## 3. Komponenten

### 3.1 Reiner Helper `lib/services/buchhaltung/saldo_expansion.dart`
```
class SaldoExpansion {
  /// Trägt die korrekten Beiträge einer Buchung in [saldi] ein (Roh-Saldo Soll−Haben).
  static void apply(Map<int,double> saldi, {
    required int sollKonto, required int habenKonto, int? mwstKonto,
    required double betragNetto, required double mwstBetrag, required double betragBrutto,
  });
}
```
- Reine Funktion, kein Supabase/Riverpod, unit-testbar.
- Logik exakt nach der Tabelle in §2.

### 3.2 `BuchungSaldo` erweitern (`bilanz_service.dart`)
Neue **optionale** Felder `mwstKonto` (int?), `betragNetto` (double?), `mwstBetrag` (double, Default 0). Bei Default (`mwstBetrag == 0`) verhält sich die Expansion wie bisher (brutto/brutto) → bestehende Tests und Aufrufer unverändert. `betrag` bleibt = brutto; `betragNetto` Default = `betrag`, wenn nicht gesetzt.

### 3.3 Integration (vier Stellen, alle über `SaldoExpansion.apply`)
- `BilanzService.saldiPerStichtag`: pro nicht-stornierter Buchung ≤ Stichtag → `SaldoExpansion.apply(...)`.
- `ErfolgsrechnungService.berechne`: beim Aufbau der Soll−Haben-Map → `SaldoExpansion.apply(...)`.
- `BuchungService.getAllSaldi` und `getKontoSaldo`: SQL-Select um `mwst_konto, betrag_netto, mwst_betrag` ergänzen, Verteilung über `SaldoExpansion.apply` statt brutto/brutto.
- Provider (`bilanzProvider`, `erfolgsrechnungStufenProvider`): `_toSaldoInput` mappt zusätzlich `mwstKonto/betragNetto/mwstBetrag`.

## 4. Datenfluss
```
buchung (soll, haben, mwst_konto, netto, mwst, brutto)
  └─► SaldoExpansion.apply ─► Roh-Saldo je Konto (Soll−Haben)
        └─► bestehende Interpretation (Vorzeichen-Flip / Bilanz-Gruppierung / ER-Bereiche)
```

## 5. Tests (TDD)
- **`SaldoExpansion.apply`** (rein): Vorsteuer-Ausgabe (z. B. Aufwand 6200 / Vorsteuer 1171 / Bank 1020) → Aufwand=netto, 1171=+mwst, 1020=−brutto; Umsatzsteuer-Einnahme (Debitor 1100 / Erlös 3400 / Umsatzsteuer 2200) → 1100=+brutto, 3400=−netto, 2200=−mwst; ohne MWST → brutto/brutto.
- **`BilanzService`**: eine Einnahme mit MWST (Debitor 1100 / Erlös 3400 / Umsatzsteuer 2200) → 1100 erscheint als Aktiv-Posten = brutto und 2200 als Passiv-Posten (Kurzfristiges Fremdkapital) = mwst. (Der Netto-Erlös 3400 ist Klasse 3 = ER, nicht Bilanz; ein einzelner Geschäftsfall balanciert die Bilanz daher nicht — das wird NICHT asserted.)
- **`ErfolgsrechnungService`**: Nettoerlös = netto (nicht brutto), wenn Erlös-Buchung MWST trägt.
- Bestehende Bilanz-/ER-Tests bleiben grün (MWST-freie Fälle unverändert).

## 6. Erfolgskriterien
- Saldo-Berechnung verteilt MWST korrekt (netto auf Aufwand/Ertrag, MWST aufs Steuerkonto, brutto auf Bank/Debitor) — überall identisch (eine Helper-Quelle).
- Umsatzsteuer 2200 und Vorsteuer 1170/1171 akkumulieren in Bilanz/Kontenplan korrekt; Live-Kontenplan/Dashboard-Saldi sind danach richtig.
- Alle bestehenden Tests grün; neue Tests grün; `flutter analyze` ohne neue Befunde.

## 7. Nicht im Scope
- Der Excel-Import selbst (Teil 2, eigene Spec).
- Phase-2-Korrekturen bekannter Buchungsfehler.
- DB-Schema-Änderungen, Deploy.
