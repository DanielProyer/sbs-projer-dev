# Vorschlag: Buchungsvorlagen/Regeln für camt-Auto-Buchung

**Datum:** 2026-06-08 · **Status:** Vorschlag zur Freigabe durch Daniel
Basierend auf **allen** Buchungstypen der camt-Datei (2019–2026) und dem bestehenden Kontenplan (38 Buchungsvorlagen).

Legende: ✅ = bestehende Vorlage nutzbar · 🆕 = neue Vorlage nötig (Konten-Vorschlag) · 🔎 = bewusst in Prüfliste (Einzelfall, keine Regel)

## A. Eingänge (CRDT)

| camt-Typ | Häufigkeit | Vorlage / Behandlung | Soll/Haben |
|---|---|---|---|
| Kundenzahlung (Reinigung) | 2527× | ✅ Zahlungseingang Kunde | 1020 / 1100 |
| Heineken-Monatsabrechnung | 53× | ✅ Zahlungseingang Heineken | 1020 / 1100 |
| Bargeld-/Post-/SIX-Einzahlung | 48× | ✅ Zahlungseingang bar | 1020 / 1000 |
| Steuerrückerstattung ESTV/EFV | ~4× | 🔎 Prüfliste (MwSt-Guthaben → meist 1020/2202, fallweise) | — |

## B. Ausgänge (DBIT) — wiederkehrend (Regel sinnvoll)

| Empfänger | Häufigkeit | Vorlage / Behandlung | Soll/Haben | MwSt |
|---|---|---|---|---|
| Heineken (Franchise) | 45× | ✅ Franchisegebühr Heineken Zahlung | 2000 / 1020 | – |
| Daniel Proyer (GF-Lohn) | 107× | ✅ Nettolohn auszahlen | 2002 / 1020 | – |
| ESTV (MwSt) | 17× | ✅ MWST-Zahlung an Bund | 2202 / 1020 | – |
| Swisscom / Sunrise | 45× | ✅ Internetabo Dauerauftrag | 6510 / 1020 | VSt 1171 |
| AXA Versicherungen (Sach) | 8× | ✅ Haftpflichtversicherung | 6300 / 1020 | – |
| Bank-„Abschluss" (Quartal) | 17× | ✅ Bankgebühren | 6940 / 1020 | – |
| **Ausgleichskasse GR (AHV/IV/EO/ALV)** | 18× | 🆕 Sozialversicherung AHV | **5700 / 1020** | – |
| **AXA Stiftung (BVG/Pensionskasse)** | 11× | 🆕 BVG/Pensionskasse | **5720 / 1020** | – |
| **Suva (UVG/Unfall)** | 4× | 🆕 Unfallversicherung Suva | **5730 / 1020** | – |
| **Steuerverwaltung Kanton GR** | 11× | 🆕 Direkte Steuern Kanton | **8900 / 1020** | – |

## C. Ausgänge (DBIT) — Einzelfälle → Prüfliste (keine Regel)

Selten/einmalig, lohnt keine Regel — landen sicher in der Prüfliste, Daniel bucht manuell:
Gemeinde Domat/Ems & Flims (Gebühren), Kantonspolizei BE/GR/GL & Strassenverkehrsamt (Bussen 🔎 6280), Vögele Recycling, Betreibungs-/Konkursamt, Intrum (Inkasso), Garage Arpagaus (✅ Autoreparatur 2000/1020), Helsana, Pascal Racine (Kunden-Rückzahlung).

## D. Out of Scope
- Konto …602 **Corona-Kredit** (Amortisation/Zins/Übertrag) — vor Stichtag 01.07.2026 vollständig getilgt, tritt in Automatik nicht mehr auf.

## E. Neue Buchungsvorlagen (von Daniel bestätigt 2026-06-08)
Direkte Aufwandsbuchung gegen Bank (kein Treuhänder, vereinfachtes Lohnschema):
1. Ausgleichskasse AHV/IV/EO/ALV → **5700 / 1020** (keine MwSt)
2. AXA Stiftung BVG/berufliche Vorsorge → **5720 / 1020** (keine MwSt)
3. Suva Unfallversicherung UVG → **5730 / 1020** (keine MwSt)
4. Steuerverwaltung Kanton GR (direkte Steuern) → **8900 / 1020** (keine MwSt)

Diese 4 Vorlagen werden als Stammdaten angelegt (Phase 2) und den Empfängern per `camt_regel` zugeordnet.

## F. Freigabe-Workflow (bestätigt)
**Nur unklare Fälle** in die Prüfliste; **eindeutige Treffer** (Betrieb+Betrag exakt bzw. bekannte Ausgaben-Regel) werden **sofort** gebucht — wie im Design (Abschnitt 2 der Spec).
