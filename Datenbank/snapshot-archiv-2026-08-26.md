# Archiv der Snapshot-Tabellen (gelöscht am 26.08.2026)

**Anlass:** Supabase meldete am 23.08.2026 einen kritischen Sicherheitsbefund
(`rls_disabled_in_public`) für `snapshot_gampel_testdaten`. Die Tabelle war
sieben Tage lang über PostgREST mit dem anon-Key les- **und schreibbar** — und
dieser Key steckt im ausgelieferten Web-Bundle. RLS wurde sofort aktiviert; die
Log-Prüfung über den gesamten Zeitraum (17.–26.08., rund 4900 API-Zugriffe)
ergab **keinen einzigen Zugriff** auf einen `snapshot`-Pfad.

Danach wurden alle vier Snapshot-Tabellen gelöscht, weil sie ihren Zweck
erfüllt hatten und genau solche Befunde erzeugen. Ihre Inhalte stehen hier.

## 1. snapshot_winterfenster_2026_08_04 (20 Zeilen) — der wichtigste

Rückweg der Winterfenster-Reparatur vom 04.08.2026. **Der Fehler:** Start und
Ende standen im selben Jahr, das Ende lag also *vor* dem Start (z. B. Start
01.12.2026, Ende 01.04.2026). Korrigiert wurde auf Ende im Folgejahr.

| Betrieb | Ort | winter_start (alt) | winter_ende (alt) |
|---|---|---|---|
| Weissfluhgipfel | Davos | 2026-12-01 | 2026-04-01 |
| Hörnlihütte | Arosa | 2026-11-01 | 2026-04-01 |
| Robinson Club | Arosa | 2026-12-01 | 2026-04-01 |
| Seehof | Davos | 2026-12-01 | 2026-04-07 |
| Weissfluhjoch | Davos | 2026-11-01 | 2026-04-01 |
| Jatzmeder | Davos | 2026-12-01 | 2026-04-06 |
| Brüggli | Arosa | 2026-12-01 | 2026-04-01 |
| Hapimag | Flims | 2026-12-04 | 2026-04-13 |
| Jschalp | Davos | 2026-12-05 | 2026-04-12 |
| Strela | Davos | 2026-12-01 | 2026-04-01 |
| Blockhuus | Davos | 2026-12-19 | 2026-04-06 |
| Chalet Güggel | Davos | 2026-12-05 | 2026-04-12 |
| Hold | Arosa | 2026-12-01 | 2026-04-01 |
| Parsennhütte | Davos | 2026-12-01 | 2026-04-12 |
| Pradaschier | Churwalden | 2026-12-01 | 2026-04-01 |
| Stall Valär | Davos | 2026-12-01 | 2026-04-06 |
| Parsenn | Davos | 2026-12-01 | 2026-04-01 |
| Concordia | Davos | 2026-12-01 | 2026-04-12 |
| Höhenweg | Davos | 2026-11-14 | 2026-04-12 |
| Waldhuus | Davos | 2026-11-16 | 2026-04-12 |

## 2. snapshot_golden_dragon_2026_08_05 (6 Zeilen)

Umhängung Golden Dragon; die alte Anlagen-Zuordnung war durchgehend
`32e71602-799c-48fc-a679-a2fcb9f09afe`.

| art | id | alt_wert |
|---|---|---|
| anlage | 9f214ebc-1419-499e-a862-18ee09d00c96 | 32e71602-799c-48fc-a679-a2fcb9f09afe |
| reinigung | 39959f56-ee86-47a5-ba70-1e337f7bd613 | 32e71602-799c-48fc-a679-a2fcb9f09afe |
| reinigung_preis | 39959f56-ee86-47a5-ba70-1e337f7bd613 | 133.00 \| 10.75 \| 143.75 |
| rechnung | ad6cfeff-d5d4-412d-9038-bbaf7f37f924 | 32e71602-799c-48fc-a679-a2fcb9f09afe |
| buchung | 73c5954a-a681-47b4-827b-ca394259050e | «Reinigung Rechnung – Grischa» |
| buchung | 73c71083-a7f3-42a1-9690-921584719619 | «MwSt 8.1% – Reinigung Rechnung Grischa» |

## 3. snapshot_landi_2026_08_06 (2 Zeilen)

LANDI Graubünden AG TopShop Chur, Lebensmittel (Signer Fitnesssalat, Suprima
Calabrese) — Beträge vor der Korrektur:

| id | netto | mwst | brutto |
|---|---|---|---|
| 3c31a995-f3ec-4f90-a65e-dc6db29da50f | 17.84 | 0.46 | 18.30 |
| 9f7ace96-252d-4902-bb69-49688fd5a603 (Vorsteuer 2.6 %) | 0.46 | 0.00 | 0.46 |

## 4. snapshot_gampel_testdaten (4 Zeilen)

Testbestand des Openair Gampel, den der geplante Reset am 17.08.2026 um 06:00
entfernt hat: 1 Stand («Teststand 1», Standnummer 1), 1 Anstich («Testtank
Orion 1», Typ `orion_1000`), 1 Stand-Anlage (Oberthekengerät, 4 Hähne) und
8 Leitungen (Nummern 1–8, nur Nummer 1 mit Ziel-Stand). Alles reine Testdaten,
angelegt am 14.08.2026 — **kein Verlust**, die echte Gampel-Erfassung lief im
eigenen Repo `D:\Projekte\gampel-2026`.
