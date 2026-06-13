# Phase 2c – Abschreibungs-Werkzeug (Debitoren) – Design

**Datum:** 2026-06-13 · **Status:** Spec zur Freigabe durch Daniel
**Übergeordnet:** Phase 2 (Aufräumen), Sub-Projekt 2c. Daniel entscheidet ohne Treuhänder ([[buchhaltung-ohne-treuhaender]]).

---

## 1. Ziel

Ein In-App-Werkzeug, mit dem Daniel **jederzeit selbst** über Debitoren-Abschreibungen entscheidet, das **korrekt verbucht** (Debitorenverlust netto + MWST-Rückholung) und die **MWST-Abrechnung** des Ursprungs-Quartals entsprechend anpasst. Plus pauschale Wertberichtigung (Delkredere).

## 2. Ausgangslage

- Bestehendes `MahnwesenService.abschreiben` bucht **falsch**: ganze Summe auf Soll 3805 / Haben 1100, **ohne MWST-Rückholung** (GF-1.9-Fehler).
- Native offene Rechnungen liegen als Einzelsätze in `rechnungen` (ab Dez 2025, ~59k). Die **alten Debitoren 2019–2024 (~116k)** existieren nur als Aggregat-Saldo auf Konto 1100 (keine Einzelrechnungen).
- MWST-Vorschau (`mwstQuartalDetailProvider`) berechnet Umsatzsteuer aus `haben_konto=3400` und Vorsteuer fehlerhaft aus `betrag_brutto` — erfasst Abschreibungs-Rückholungen (2200-Soll) nicht.

## 3. Buchungslogik (entschieden)

Abschreibung brutto X (Schweizer KMU, **rückdatiert aufs Ursprungs-Quartal**) = **zwei Buchungen** (Modell hat 1 Soll/Haben pro Zeile):
1. **Soll 3805 / Haben 1100**, Betrag = **netto** = `round(X/(1+satz/100), 2)`
2. **Soll 2200 / Haben 1100**, Betrag = **mwst** = `X − netto` (nur wenn satz > 0)

`satz` = `MwstSatzService.satzFuerDatum(rechnungsdatum)` (7.7 % bis 2023, 8.1 % ab 2024). Zusammen: 1100 −= brutto, 3805 += netto (Verlust), 2200 += mwst (Soll = Rückholung, mindert die geschuldete MWST). Der Verlust mindert das Ergebnis → Bilanz rechnet das automatisch ([[phase0a_buchungsmodell]] Phase 2b).

**Delkredere** (pauschale Wertberichtigung, 5 % der verbleibenden Debitoren): **Soll 3805 / Haben 1109** (Bildung) bzw. **Soll 1109 / Haben 3805** (Auflösung/Anpassung) über die Differenz zum Zielsaldo. Kein MWST.

## 4. Komponenten

### K1 — `AbschreibungService` (rein + Buchung; TDD)
`lib/services/buchhaltung/abschreibung_service.dart`
- `(double netto, double mwst) split(double brutto, double satz)` — reine Funktion (`netto = round(brutto/(1+satz/100),2)`, `mwst = brutto − netto`); TDD.
- `Future<void> abschreiben({required double brutto, required DateTime datum, required String beschreibung, String? belegnummer, String? belegId})` — Satz via `MwstSatzService.satzFuerDatum(datum)`; erzeugt die 1–2 Buchungen (datiert `datum`, `beleg_typ='abschreibung'`, `notizen='Phase2c Abschreibung'`).
- `Future<void> delkredereSetzen({required double zielSaldo, required DateTime datum})` — liest aktuellen 1109-Saldo, bucht die Differenz (3805/1109 oder 1109/3805).

### K2 — `MahnwesenService.abschreiben` auf K1 umstellen
Bisherige falsche Einzelbuchung ersetzen: `AbschreibungService.abschreiben(brutto: r.betragBrutto, datum: r.rechnungsdatum, beschreibung: 'Debitorenverlust <Nr>', belegnummer: r.rechnungsnummer, belegId: r.id)`; Status weiterhin `'abgeschrieben'`. → korrekte MWST-Rückholung, rückdatiert aufs Rechnungs-Quartal.

### K3 — Sammel-Abschreibung (historische Debitoren) — UI
Dialog/Screen-Aktion: Eingabe **Betrag (brutto), Datum, Bezeichnung** → `AbschreibungService.abschreiben(...)` ohne belegId (belegnummer z. B. `ABSCHR-HIST`). Für die alten 2019–2024-Debitoren ohne Einzelrechnung.

### K4 — MWST-Vorschau korrekt (`mwstQuartalDetailProvider` Fix)
Pro Quartal über `SaldoExpansion` die Konto-Bewegungen rechnen (lädt `soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto, ist_storniert, quartal`):
- `umsatzsteuer` = −(Quartals-Saldo Konto 2200) → erfasst Verkäufe (impliziter MWST-Leg) **und** Abschreibungs-Rückholungen (expliziter 2200-Soll).
- `vorsteuer` = Quartals-Saldo 1170 + 1171.
- `umsatz` = −(Quartals-Saldo 3400) (netto).
- `zahllast` = umsatzsteuer − vorsteuer.
Behebt zugleich den vorbestehenden Vorsteuer-Bug.

### K5 — Debitoren-Übersicht (Hub) — Screen
`/buchhaltung/debitoren` + Dashboard-Tile. Zeigt:
- **Native offene Rechnungen** (Provider über `rechnungen`, Status ≠ bezahlt/abgeschrieben) — Liste mit „Abschreiben"-Aktion je Rechnung (→ K2).
- **Historischer Debitoren-Aggregat** (1100-Saldo minus native offene Summe) — mit „Sammel-Abschreibung" (→ K3).
- **Delkredere-Status** (1109-Saldo) + „Delkredere auf 5 % der Debitoren setzen" (→ K1.delkredereSetzen, zielSaldo = 5 % des Netto-Debitorenbestands).

## 5. Architektur-Einheiten
- `abschreibung_service.dart` (rein/Buchung, TDD) · `mahnwesen_service.dart` (umstellen) · `mwstQuartalDetailProvider` (umstellen) · `debitoren_screen.dart` + Sammel-Abschreibung-Dialog + Provider · Route/Tile.

## 6. Tests (TDD)
- `AbschreibungService.split`: 7.7 % und 8.1 % korrekt (netto+mwst=brutto); satz 0 → netto=brutto, mwst=0.
- Buchungs-Erzeugung: 2 Buchungen mit korrekten Konten/Beträgen/Datum (über einen testbaren Pfad / Mock-Repository oder reine Split-Prüfung + Integrationscheck).
- MWST-Vorschau: nach einer rückdatierten Abschreibung sinkt die Umsatzsteuer des Ursprungs-Quartals um die Rückholung (SQL-Verifikation).

## 7. Erfolgskriterien
- Abschreibung bucht netto auf 3805 + MWST auf 2200 / 1100, rückdatiert; MWST-Vorschau des Ursprungs-Quartals zeigt die Rückholung.
- Daniel kann jederzeit native Rechnungen einzeln + alte Debitoren als Sammelbuchung abschreiben + Delkredere setzen.
- Debitorenverlust mindert Ergebnis; Bilanz bleibt ausgeglichen.
- Bestehende Tests/Screens unverändert; kein Deploy.

## 8. Nicht im Scope
- Per-Einzelrechnung-Abschreibung für die alten 2019–2024-Debitoren (keine Einzelsätze vorhanden → nur Sammelbuchung).
- Automatische Abschreib-Vorschläge/Alterung über die Mahnwesen-Logik hinaus.
