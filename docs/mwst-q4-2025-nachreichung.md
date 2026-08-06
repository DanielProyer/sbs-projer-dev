# MWST Q4/2025 — Nachreichung inkl. Korrektur 2025

**Erstellt 06.08.2026** auf Auftrag Daniel («korrigiere die 858 bei der Q4
Nachreichung»). Alle Werte aus dem Buchungsjournal, belegweise gerechnet und um
die MwSt-Doppelbuchung bereinigt (Trennbuchungen tragen kein `mwst_konto` und
sind damit sauber ausgeschlossen). Die Einreichung selbst läuft über das
ESTV-ePortal — das kann nur Daniel (Login), dieses Dokument ist die Vorlage.

## Registrierungsdaten (fürs Portal)

| | |
|---|---|
| Firma | SBS Projer GmbH, Via Rezia 8, 7013 Domat/Ems |
| MWST-Nr. | CHE-413.083.919 MWST |
| ESTV-ID | 052.0248.5626 |
| Methode | **Effektiv**, quartalsweise, seit 01.05.2019 |

> **Die wichtigste Regel fürs Formular:** Ziffer 200 verlangt den Umsatz
> **BRUTTO** (inkl. MWST). Genau hier ist 2025 dreimal der Netto-Wert
> eingetragen worden — daher die Unterdeklaration von 857.53.

## Ausgangslage

| Periode | deklariert/bezahlt | rechnerisch korrekt | Differenz |
|---|---:|---:|---:|
| Q1/2025 (eingereicht 06.10.2025) | 2'641.54 | 2'886.03 | −244.49 |
| Q2/2025 (bezahlt 06.10.2025) | 2'185.33 | 2'445.76 | −260.43 |
| Q3/2025 (bezahlt 10.02.2026) | 3'333.74 | 3'686.35 | −352.61 |
| **Summe Q1–Q3** | **8'160.61** | **9'018.14** | **−857.53** |
| Q4/2025 (NICHT eingereicht) | — | 2'386.13 | |

Jahr 2025 gesamt (Journal, bereinigt): Umsatz netto 197'566.76 / **brutto
213'571.17** · Umsatzsteuer 16'004.41 · Vorsteuer 4'600.14 (1170: 3'392.28,
1171: 1'207.86) · **Jahres-Zahllast 11'404.27**.

Kontrolle: 11'404.27 − 8'160.61 bereits bezahlt = **3'243.66 noch geschuldet**
= Q4 pur (2'386.13) + Korrektur (857.53). Die Rechnung schliesst exakt.

## Empfohlener Weg: Q4 einreichen + Jahresabstimmung im selben Portalbesuch

**Schritt 1 — Q4/2025 einreichen** (Werte pur, aus dem Journal):

```
Ziff. 200  Total Entgelte (BRUTTO!)          46'980.99
Ziff. 289  Abzüge                                 0.00
Ziff. 299  Steuerbarer Gesamtumsatz          46'980.99
Ziff. 303  Normalsatz 8.1 %   → Steuer        3'521.05
Ziff. 399  Total geschuldete Steuer           3'521.05
Ziff. 400  Vorsteuer Material/DL                286.85   (Konto 1171)
Ziff. 405  Vorsteuer Invest./Betrieb            848.07   (Konto 1170, Franchise)
Ziff. 479  Total Vorsteuer                    1'134.92
Ziff. 500  Zu bezahlender Betrag              2'386.13
```

(Zur 400/405-Zuordnung: fachlich gehört die Franchisegebühr in 405 und das
Material in 400 — bisherige Abrechnungen hatten es andersherum beschriftet;
steuerlich zählt nur das Total 479.)

**Schritt 2 — Berichtigungsabrechnung / Jahresabstimmung 2025** (gleich
anschliessend im Portal; das Portal vergleicht selbst mit dem bereits
Deklarierten):

```
Jahreswerte 2025 (korrigiert):
Ziff. 200  Total Entgelte (BRUTTO)           213'571.17
Ziff. 303  Normalsatz 8.1 %   → Steuer        16'004.41
Ziff. 479  Total Vorsteuer                     4'600.14
           (400: 1'207.86 · 405: 3'392.28)
```

→ Ergibt zusammen mit Schritt 1 automatisch die Nachforderung von **857.53**.
Total aus beiden Schritten: **3'243.66**.

## Alternative: alles in ein einziges Q4-Formular

Falls das Portal keine separate Berichtigung anbietet (oder es schneller gehen
soll): die Korrektur direkt in Q4 einrechnen. Dafür gilt Ziff. 200 =
Jahresbrutto 213'571.17 minus die in Q1–Q3 **deklarierten** Ziff.-200-Werte.
Q1 ist bekannt (51'017.09); **Q2 und Q3 bitte als PDF aus dem ePortal laden**
(Abrechnungsarchiv) und die Ziff.-200-Werte einsetzen — dann rechne ich die
Formularzeile auf den Rappen fertig. Ohne die zwei PDFs wäre diese Variante
Schätzung; der empfohlene Weg oben braucht sie nicht.

## Hinweise

- **Verzugszins:** Valuta für Q4/2025 war der 01.03.2026 — die ESTV stellt den
  Zins automatisch in Rechnung (separater Bescheid, bei diesen Beträgen
  überschaubar). Keine Selbstberechnung nötig.
- **Zahlung:** QR-Zahlteil kommt mit der Einreichebestätigung; Betrag dann als
  Bankzahlung ausführen. Die Buchung dazu (2202/1020) und die überfälligen
  Saldierungen 2200/1170/1171→2202 für alle sieben offenen Quartale machen wir
  im Aufräum-Schub (Fahrplan Schritt 5) — **nicht von Hand vorwegnehmen**.
- **Q1/2026 bleibt offen** (ebenfalls überfällig): Entwurfswert heute 3'323.02,
  aber die Vorsteuer ist erst nach Fahrplan-Schritten 3–4 vollständig
  (Bank-Nachhol-Import 12.–31.03., Franchise-Nachbuchung). Erst danach
  einreichen — oder pragmatisch mit heutigem Stand und Nachtrag über die
  Jahresabstimmung 2026. Entscheid Daniel.
- **Geklärt 06.08.2026:** Der Heineken-Franchise-Vertrag läuft 2026 unverändert
  (3'772.70/Monat brutto). Die Nachbuchungen Jan–Aug (8 × 3'490.01 + 8 × 282.69
  Vorsteuer) stehen damit fest auf dem Fahrplan (Schritt 4); die
  Rechnungsbelege von Heineken dazu ablegen (Belegpflicht für den
  Vorsteuerabzug).
- **PDF-Ablage:** Die Einreichebestätigungen (Q4/2025 + Berichtigung) in
  `00_Rechnungen/02_MWST Abrechnung/` legen — dort fehlen auch Q2/2025 und
  Q3/2025 noch.
