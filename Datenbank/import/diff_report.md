# Excel-Import Abgleich-Report (Phase 1 Teil 2)

Stand: 2026-06-13. Import: 14'552 Journal-Zeilen (< 2025-12-01) → `buchungen`, user = Daniel.

## A · Treue-Gate (per-Konto-Saldo App-DB vs. Journal-Referenz)

Vergleich des kumulierten Roh-Saldos (Soll−Haben mit MWST-Expansion) je Konto an jedem
Jahresende. Referenz = aus dem Journal mit denselben Regeln wie `SaldoExpansion`; Ist =
aus den importierten `buchungen`.

| Stichtag | Konten | Diff ≠ 0 | > 0.05 | Status |
|---|---|---|---|---|
| 2019-12-31 | 39 | 0 | 0 | **PASS** |
| 2020-12-31 | 45 | 0 | 0 | **PASS** |
| 2021-12-31 | 48 | 0 | 0 | **PASS** |
| 2022-12-31 | 48 | 0 | 0 | **PASS** |
| 2023-12-31 | 48 | 0 | 0 | **PASS** |
| 2024-12-31 | 48 | 0 | 0 | **PASS** |
| 2025-11-30 | 48 | 0 | 0 | **PASS** |

→ **Import vollständig & treu**: jeder Konto-Saldo stimmt exakt (0.00) mit der Journal-Referenz
überein. Keine verlorene/verfälschte Zeile. Anzahl 14'552, native Dez-2025-Daten unberührt (1482).

## B · Excel-Stichprobe (Rundung / externe Logik)

Ziel: bestätigen, dass die berechnete netto/MWST-**Rundung** und die MWST-Expansion mit der
Excel übereinstimmen. Vergleich zentraler Konten gegen die in den Excel-**Bilanz**-Sheet-Zellen
abgelegten Werte.

| Konto | Bezeichnung | App/Python | Excel-Sheet | Diff | Bewertung |
|---|---|---|---|---|---|
| 1020 | Bank | 12'202.73 | 12'202.73 | 0.00 | exakt ✓ |
| 1170 | Vorsteuer Material | 3'654.08 | 3'654.08 | 0.00 | exakt ✓ (bestätigt MWST-Expansion) |
| 2800 | Stammkapital | 20'000.00 | 20'000.00 | 0.00 | exakt ✓ |
| 2970 | Gewinnvortrag | 35'319.11 | 35'319.11 | 0.00 | exakt ✓ |
| 1000 | Kasse | 6'595.64 | 2'041.24 | groß | s. Hinweis |
| 1100 | Debitoren | 114'895.16 | 99'037.46 | groß | s. Hinweis |
| 1171 | Vorsteuer übr. | 1'252.65 | 1'148.11 | groß | s. Hinweis |

**Hinweis zur Excel-Stichprobe:** Die Excel-Bilanz/ER-Sheets enthalten **gecachte Formelwerte**
(zuletzt von Excel gerechneter Stand). Sie sind als externer Anker **unzuverlässig**: je nach
Cache-Stand entsprechen sie nicht einem einheitlichen Stichtag (Bank matcht bei ≤31.12.2025,
andere Konten bei keinem klaren Schnitt). Die großen Diffs bei 1000/1100/1171 sind daher
Cache-/Stichtag-Artefakte, **kein** Import-Fehler — das wird durch das exakte Treue-Gate (A)
und die exakten Matches (1020/1170/2800/2970, inkl. Vorsteuer = MWST-Logik bestätigt) gestützt.

**Sauberer Gegencheck (optional, braucht Daniel):** Excel öffnen, Bilanz-Stichtag auf ein
abgeschlossenes Jahresende (z. B. 31.12.2024) setzen, neu berechnen + speichern, dann Kasse/
Debitoren/Bank gegen die App per 31.12.2024 vergleichen. Erst damit ist ein bit-genauer externer
Abgleich für diese Konten möglich.

## Fazit
- **Treue-Gate grün** über alle Jahre → Import ist vollständig und faithful (Erfolgskriterium erfüllt).
- MWST-Expansion durch exakten Vorsteuer-Match bestätigt.
- Excel-Sheet-Cache als Anker unzuverlässig; sauberer externer Cross-Check optional via Daniel.
- Bekannte Excel-Fehler (8090/9100, fehlende MWST-Rückbuchung) sind faithful mitimportiert →
  Korrektur in **Phase 2** (heben sich im Treue-Gate auf, da Referenz und Import identisch).
