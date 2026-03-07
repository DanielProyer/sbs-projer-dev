# Analyse: Störungsbereiche (Heineken-Schema)

**Analysedatum**: 12.02.2026
**Dokument**: Störungsbereiche.pdf
**Quelle**: Heineken - Register 12 Handbuch DBO "Einteilung nach Störungsbereichen"

---

## Übersicht: Die 5 Störungsbereiche

Das Heineken-System teilt eine Bier-Zapfanlage in **5 technische Bereiche** ein, die bei Störungen unterschiedliche Komplexität und Bearbeitungszeit haben.

```
┌─────────────────────────────────────────────────────────────┐
│                  BIER-ZAPFANLAGE                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [STÖRUNG 1] ◄── Zapfhahn/Zapfkopf (oben, am Tresen)       │
│       │                                                     │
│       │  [STÖRUNG 2] ◄── Bierleitungen (vom Fass zum Hahn) │
│       │       │                                             │
│  ┌────┴───────┴────┬──────────────┬──────────────┐        │
│  │                 │              │              │         │
│  │  [STÖRUNG 3]    │  [STÖRUNG 4] │  [STÖRUNG 5] │        │
│  │  Vorkühler/     │  Fass/       │  CO2/Gas     │        │
│  │  Durchlauf-     │  Fassanschl. │  Drucksystem │        │
│  │  kühler         │              │              │         │
│  └─────────────────┴──────────────┴──────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Detailbeschreibung der 5 Bereiche

### Störung 1: Zapfhahn/Zapfkopf-Bereich 🟨 (Gelb)

**Lage**: Oberhalb des Tresens, Ausschankbereich

**Komponenten:**
- Zapfhahn (Position 1 in Zeichnung)
- Zapfkopf
- Durchlaufkühler (Endstück)
- Kompensatorhahn (Position 2)

**Typische Störungen:**
- Zapfhahn tropft
- Zapfkopf undicht
- Schaumbildung beim Ausschank
- Durchfluss blockiert
- Zapfhahn verschmutzt

**Komplexität**: Mittel
- Zugang: Leicht (oberirdisch, am Tresen)
- Demontage: Einfach (Zapfhahn/Zapfkopf)
- Werkzeug: Standard

**Heineken-Preis (aus Monatsrechnungen):**
- **115 CHF** (Standard)
- Kombiniert mit Bereich 5: **160-310 CHF**

**Bearbeitungszeit**: ~30-45 Minuten

---

### Störung 2: Leitungsbereich 🟪 (Pink/Magenta)

**Lage**: Zwischen Fass und Zapfhahn (versteckt, unterirdisch/in Wänden)

**Komponenten:**
- Bierleitungen (Position 15 in Zeichnung)
- Kompensatorschlauch (Position 8.6, 6.15, 3.6)
- Leitungsverbindungen
- Isolierung

**Typische Störungen:**
- Leitungen undicht
- Verstopfung in Leitungen
- Bierschaum in Leitungen (Luft im System)
- Verschmutzung/Bakterienbefall
- Leitungsbruch
- Kältebrücken-Probleme

**Komplexität**: Hoch
- Zugang: Schwierig (versteckt, oft durch Wände/Böden)
- Demontage: Aufwendig (Leitungen öffnen, spülen)
- Werkzeug: Spezialwerkzeug + Reinigungsmittel

**Heineken-Preis (aus Monatsrechnungen):**
- **115-215 CHF** (je nach Aufwand)
- Höherer Preis bei längeren Leitungen oder schwierigem Zugang

**Bearbeitungszeit**: ~45-90 Minuten

---

### Störung 3: Vorkühler/Durchlaufkühler 🟩 (Grün)

**Lage**: Keller oder Technikraum (links in der Zeichnung)

**Komponenten:**
- Vorkühler (Position 12.1, 12.2)
- Durchlaufkühler (Position 11, 12.3)
- Kühlaggregat
- Wasserbad
- Thermostat
- Umwälzpumpe

**Typische Störungen:**
- Kühlung funktioniert nicht (Bier zu warm)
- Vorkühler defekt
- Durchlaufkühler undicht
- Wasserstand zu niedrig
- Pumpe defekt
- Temperatur nicht regelbar
- Kompressor ausgefallen

**Komplexität**: Sehr hoch
- Zugang: Mittel (meist im Keller)
- Diagnose: Komplex (Elektronik, Kältetechnik)
- Reparatur: Aufwendig (oft Ersatzteile nötig)
- Werkzeug: Spezialisiert (Kältetechnik)

**Heineken-Preis (aus Monatsrechnungen):**
- **150-250 CHF** (häufigster Störungstyp!)
- Höherer Preis bei Ersatzteilbedarf

**Bearbeitungszeit**: ~60-120 Minuten

**Bemerkung**: Dies ist der **häufigste Störungsbereich** laut Monatsrechnungen!

---

### Störung 4: Fass/Fassanschluss 🟦 (Blau)

**Lage**: Kühlraum/Fassraum (Mitte unten in der Zeichnung)

**Komponenten:**
- Fass (Position 7.11 in Zeichnung)
- Fassanschluss/Fitting (Position 5.3, 6.1)
- Fassventil
- Steigrohr im Fass

**Typische Störungen:**
- Fassanschluss undicht
- Fitting defekt
- Fass leer (keine Störung, aber Wechsel nötig)
- Ventil blockiert
- Steigrohr verstopft
- Falscher Druck am Fass

**Komplexität**: Niedrig-Mittel
- Zugang: Leicht (Fassraum)
- Diagnose: Einfach (visuell)
- Reparatur: Schnell (Fitting wechseln)
- Werkzeug: Standard

**Heineken-Preis (aus Monatsrechnungen):**
- **90-205 CHF**
- Variabler Preis (je nach Aufwand)

**Bearbeitungszeit**: ~20-45 Minuten

---

### Störung 5: CO2/Gas-Drucksystem 🟥 (Rot)

**Lage**: Neben Fassraum oder separat (rechts in der Zeichnung)

**Komponenten:**
- CO2-Flasche (Position 6.7 in Zeichnung)
- Druckminderer (Position 6.3)
- Druckleitungen (Position 6.15)
- Manometer
- Sicherheitsventil

**Typische Störungen:**
- CO2-Flasche leer
- Druckminderer defekt
- Druck zu hoch/zu niedrig
- Gasleitungen undicht
- Manometer zeigt falsch an
- Sicherheitsventil löst aus

**Komplexität**: Mittel
- Zugang: Leicht (meist zugänglich)
- Diagnose: Einfach (Druckmessung)
- Reparatur: Schnell (Flaschenwechsel, Einstellung)
- Werkzeug: Standard (Druckminderer-Schlüssel)

**Heineken-Preis (aus Monatsrechnungen):**
- **105 CHF** (Standard)
- Kombiniert mit Bereich 1: **160 CHF**

**Bearbeitungszeit**: ~15-30 Minuten

---

## Preissystem-Erklärung

### Grundpreise (einzeln)

| Bereich | Beschreibung | Preis | Häufigkeit |
|---------|-------------|-------|------------|
| **1** | Zapfhahn/Zapfkopf | 115 CHF | Mittel |
| **2** | Bierleitungen | 115-215 CHF | Niedrig (aufwendig) |
| **3** | Vorkühler/Durchlaufkühler | 150-250 CHF | **Hoch** (häufigste) |
| **4** | Fass/Fassanschluss | 90-205 CHF | Mittel |
| **5** | CO2/Gas | 105 CHF | Hoch |

### Kombinationen (mehrere Bereiche betroffen)

| Kombination | Beispiel | Preis | Logik |
|-------------|----------|-------|-------|
| **1+5** | Zapfhahn + CO2-Problem | 160-310 CHF | Beide Bereiche müssen bearbeitet werden |
| **3+5** | Kühlung + Druck | 195 CHF | Reduzierter Preis (Synergien) |

**Bemerkung aus Monatsrechnungen:**
```
04.12.2025  589  1+5  Me and All Hotel Flims  160.00 CHF
11.12.2025  580  1+5  Capetta - Avers          310.00 CHF
```
→ Gleiche Kombination, aber unterschiedlicher Preis (abhängig von Aufwand, Anfahrt, Bergkunde?)

---

## Erkenntnisse aus Monatsrechnungen (Okt-Dez 2025)

### Häufigkeitsverteilung (35 Störungen analysiert)

| Bereich | Anzahl | Anteil | Durchschnittspreis |
|---------|--------|--------|-------------------|
| **Bereich 3** | 14 | 40% | 181 CHF |
| **Bereich 5** | 8 | 23% | 105 CHF |
| **Bereich 1** | 4 | 11% | 138 CHF |
| **Bereich 2** | 3 | 9% | 165 CHF |
| **Bereich 4** | 3 | 9% | 133 CHF |
| **Kombinationen** | 3 | 9% | 242 CHF |

**Wichtigste Erkenntnis:**
→ **Bereich 3 (Kühlsystem) verursacht 40% aller Störungen!**

**Gründe:**
- Komplexe Technik (Kühlaggregate, Pumpen, Thermostate)
- Mechanischer Verschleiß
- Elektronik-Ausfälle
- Wartungsintensiv

---

## Saisonale Muster

### Winter (November-Dezember):
- **Mehr Störungen Bereich 3** (Kühlung)
- Grund: Höhere Belastung (Wintersaison, mehr Ausschank)
- Bergkunden haben oft Kühlprobleme (Kälte draußen, Wärme drinnen)

### Allgemein:
- **Bereich 5 (CO2)**: Häufig bei Saisonstart (leere Flaschen nach Pause)
- **Bereich 1 (Zapfhahn)**: Gleichmäßig verteilt (Verschleiß)
- **Bereich 2 (Leitungen)**: Selten (nur bei größeren Problemen)

---

## Integration in die App

### Störungsmeldung erfassen

**Workflow in der App:**

```
1. Kunde ruft an: "Zapfanlage funktioniert nicht!"
2. App öffnen → "Neue Störung erfassen"
3. Kunde auswählen (z.B. 0137 - Hotel Zur Krone)
4. Symptome erfassen:
   ☐ Bier zu warm
   ☐ Kein Bier fließt
   ☐ Schaumbildung
   ☐ Zapfhahn tropft
   ☐ CO2 leer
   ☐ Leitungen undicht
5. App schlägt Bereich vor:
   → "Vermutlich Bereich 3 (Kühlung)"
   → "Geschätzter Preis: 150-250 CHF"
6. Termin planen (sofort oder später)
7. Route optimieren (falls mehrere Störungen am Tag)
```

### Vor-Ort-Diagnose

**Bestätigung des Bereichs:**

```
1. Vor Ort angekommen
2. Diagnose durchführen:
   - Temperatur messen → Bereich 3 bestätigt
   - Fehlerquelle identifizieren → Durchlaufkühler defekt
3. In App eintragen:
   ☑ Bereich 3 (Durchlaufkühler)
   ☐ Bereich 5 (zusätzlich CO2 nachfüllen)
4. Preis wird automatisch berechnet:
   → Bereich 3: 200 CHF (Ersatzteil nötig)
   → Total: 200 CHF
5. Service durchführen
6. Protokoll erstellen (wie Reinigung)
7. Unterschrift einholen
8. Abgeschlossen!
```

### Automatische Preisberechnung

**Logik in der App:**

```python
def berechne_stoerungspreis(bereiche, zusatz_faktoren):
    """
    Berechnet Störungspreis basierend auf Bereichen

    Args:
        bereiche: Liste der betroffenen Bereiche (z.B. [3] oder [1, 5])
        zusatz_faktoren: Dict mit Zusatzfaktoren
            - bergkunde: Boolean
            - ersatzteil: Boolean
            - mehrfach: Boolean (>1 Bereich)

    Returns:
        Preis in CHF
    """

    # Basis-Preise pro Bereich
    preise = {
        1: 115,   # Zapfhahn
        2: 165,   # Leitungen (Durchschnitt 115-215)
        3: 200,   # Kühlung (Durchschnitt 150-250)
        4: 147,   # Fass (Durchschnitt 90-205)
        5: 105    # CO2
    }

    # Berechne Basis
    if len(bereiche) == 1:
        basis = preise[bereiche[0]]
    else:
        # Mehrere Bereiche: Addiere, aber mit Rabatt
        basis = sum(preise[b] for b in bereiche) * 0.8

    # Zusatzfaktoren
    if zusatz_faktoren.get('ersatzteil'):
        basis += 50  # Ersatzteil-Zuschlag

    if zusatz_faktoren.get('schwieriger_zugang'):
        basis += 30  # Zugangs-Zuschlag

    # Bergkunde: Anfahrtspauschale separat (nicht hier)

    return round(basis, 2)
```

**Beispiele:**
```python
# Einfache Störung Bereich 3
berechne_stoerungspreis([3], {})
→ 200 CHF

# Bereich 1+5 kombiniert
berechne_stoerungspreis([1, 5], {})
→ (115 + 105) * 0.8 = 176 CHF

# Bereich 3 mit Ersatzteil
berechne_stoerungspreis([3], {'ersatzteil': True})
→ 200 + 50 = 250 CHF
```

---

## Datenmodell-Erweiterung

### Entität: Störung

```sql
Stoerung {
  ID: INT (Primary Key)
  Betrieb_ID: INT (Foreign Key)
  Anlage_ID: INT (Foreign Key)
  Datum: DATE
  Uhrzeit_Meldung: TIME
  Uhrzeit_Beginn: TIME
  Uhrzeit_Ende: TIME

  -- Bereich(e)
  Bereich_1: BOOLEAN  -- Zapfhahn
  Bereich_2: BOOLEAN  -- Leitungen
  Bereich_3: BOOLEAN  -- Kühlung
  Bereich_4: BOOLEAN  -- Fass
  Bereich_5: BOOLEAN  -- CO2

  -- Symptome (Mehrfachauswahl)
  Symptom_Kein_Bier: BOOLEAN
  Symptom_Zu_Warm: BOOLEAN
  Symptom_Schaum: BOOLEAN
  Symptom_Tropft: BOOLEAN
  Symptom_Undicht: BOOLEAN
  Symptom_Kein_Druck: BOOLEAN
  Symptom_Sonstiges: TEXT

  -- Diagnose
  Fehlerquelle: TEXT
  Massnahme: TEXT

  -- Abrechnung
  Stoerungsnummer: VARCHAR(20)  -- z.B. "493"
  Preis_Berechnet: DECIMAL(10,2)  -- Automatisch
  Preis_Final: DECIMAL(10,2)      -- Falls manuell angepasst
  Bergkunde_Pauschale: BOOLEAN    -- +180 CHF
  Ersatzteil_Verbaut: BOOLEAN
  Ersatzteil_Bezeichnung: TEXT
  Ersatzteil_Kosten: DECIMAL(10,2)

  -- Status
  Status: ENUM('Gemeldet', 'In_Bearbeitung', 'Abgeschlossen')
  Prioritaet: ENUM('Normal', 'Dringend', 'Notfall')

  -- Dokumentation
  Foto_Vorher: TEXT  -- Pfad oder Base64
  Foto_Nachher: TEXT
  Bemerkung: TEXT

  -- Heineken-Abrechnung
  Heineken_Rechnung_ID: INT (Foreign Key)
  Abgerechnet: BOOLEAN

  -- Metadaten
  Erstellt_Am: DATETIME
  Servicemonteur_ID: INT
  GPS_Latitude: DECIMAL(10,8)
  GPS_Longitude: DECIMAL(11,8)
}
```

---

## Statistiken & Reporting

### Dashboard-Widgets

**1. Störungshäufigkeit nach Bereich (Balkendiagramm)**
```
Bereich 3 (Kühlung):      ████████████████████ 40%
Bereich 5 (CO2):          ███████████ 23%
Bereich 1 (Zapfhahn):     █████ 11%
Bereich 2 (Leitungen):    ████ 9%
Bereich 4 (Fass):         ████ 9%
Kombinationen:            ████ 9%
```

**2. Durchschnittliche Bearbeitungszeit**
```
Bereich 1: 35 min
Bereich 2: 65 min
Bereich 3: 85 min (längste!)
Bereich 4: 30 min
Bereich 5: 20 min (schnellste!)
```

**3. Umsatz pro Bereich (pro Monat)**
```
Bereich 3: 2'800 CHF (40% der Störungen × 200 CHF)
Bereich 5: 840 CHF
Bereich 1: 462 CHF
...
```

**4. Problematische Anlagen (Top 10)**
```
Anlage "Hotel XY, Davos": 8 Störungen (6× Bereich 3)
→ Empfehlung: Kühlsystem austauschen oder intensivere Wartung
```

---

## Wartungsempfehlungen basierend auf Bereich

### Bereich 3 (Kühlung) - Wartungsintensiv!

**Problem**: 40% aller Störungen
**Lösung**: Präventive Wartung

**Wartungsplan für App:**
```
Anlage "Hotel Zur Krone, Arosa"
  ├─ Bereich 3 (Kühlung): 4 Störungen in 6 Monaten
  ├─ Empfehlung:
  │   "Kühlsystem zeigt Verschleiß. Empfehlung:
  │    - Monatliche Wartung statt alle 4 Wochen
  │    - Thermostat-Check
  │    - Pumpe reinigen/ersetzen"
  └─ Nächste Wartung: in 2 Wochen
```

**Automatische Alerts:**
- Bei >3 Störungen im gleichen Bereich: "Empfehlung: Intensivierte Wartung"
- Bei wiederholten Störungen: "Eventuell Ersatz nötig (Kostenvoranschlag)"

---

## Schulungsmaterial für Franchise-Nehmer

**Wenn andere Franchise-Nehmer die App nutzen:**

### Modul: "Störungsbereiche erkennen"

**Kapitel 1: Die 5 Bereiche**
- Video: 3D-Animation der Zapfanlage
- Interaktive Grafik: Klick auf Bereich → Erklärung
- Quiz: "Welcher Bereich ist betroffen?"

**Kapitel 2: Typische Symptome**
| Symptom | Wahrscheinlicher Bereich |
|---------|--------------------------|
| Bier zu warm | Bereich 3 (Kühlung) |
| Kein Bier fließt | Bereich 4 (Fass) oder 5 (CO2) |
| Schaumbildung | Bereich 1 (Zapfhahn) oder 3 (Kühlung) |
| Zapfhahn tropft | Bereich 1 (Zapfhahn) |
| Keine Kohlensäure | Bereich 5 (CO2) |

**Kapitel 3: Schnelldiagnose**
- Checkliste zum Ausdrucken
- Telefonische Ferndiagnose (Kunde anleiten)

---

## Integration mit Heineken-System

### Automatische Störungsmeldung an Heineken

**Falls Heineken benachrichtigt werden muss:**

```
Störung erfasst
  ├─ App prüft: Ist Heineken-Kunde?
  ├─ Falls ja: Automatische Email an Heineken
  │   "Störung gemeldet:
  │    Kunde: Hotel Zur Krone (0137)
  │    Bereich: 3 (Kühlung)
  │    Status: In Bearbeitung
  │    Voraussichtliche Fertigstellung: heute 15:00"
  └─ Nach Abschluss: Update-Email
      "Störung behoben:
       Bereich: 3 (Durchlaufkühler)
       Massnahme: Thermostat ersetzt
       Kosten: 200 CHF"
```

---

## Nächste Schritte

1. ✅ Struktur verstanden - 5 Störungsbereiche klar definiert
2. ⏭️ **Preislogik finalisieren** - Exakte Regeln für Preisberechnung
3. ⏭️ **Symptom-Katalog erstellen** - Alle möglichen Symptome erfassen
4. ⏭️ **Entscheidungsbaum** - Welches Symptom → Welcher Bereich?
5. ⏭️ **App-Mockup** - Störungserfassung visualisieren

---

## Anhang: Technische Zeichnung erklärt

### Komponenten-Nummerierung (aus Zeichnung)

| Nr. | Komponente | Bereich |
|-----|------------|---------|
| 1 | Zapfhahn | 1 |
| 2 | Kompensatorhahn | 1 |
| 15 | Bierleitung | 2 |
| 8.6 | Kompensatorschlauch | 2 |
| 6.15 | Schlauchleitung | 2 |
| 3.6 | Verbindung | 2 |
| 12.1 | Vorkühler | 3 |
| 12.2 | OR (?) | 3 |
| 11 | Durchlaufkühler (Aggregat) | 3 |
| 12.3 | Durchlaufkühler (Ausgang) | 3 |
| 7.11 | Fass | 4 |
| 5.3 | Fassanschluss | 4 |
| 6.1 | Fitting | 4 |
| 6.7 | CO2-Flasche | 5 |
| 6.3 | Druckminderer | 5 |

**Quelle**: Heineken Register 12 Handbuch DBO

---

## Zusammenfassung

**Wichtigste Erkenntnisse:**

1. ✅ **5 definierte Störungsbereiche** mit unterschiedlichen Preisen
2. ✅ **Bereich 3 (Kühlung) = 40% aller Störungen** → Hauptproblemzone
3. ✅ **Preise sind festgelegt** (kein Rätselraten mehr!)
4. ✅ **Kombinationen möglich** (mehrere Bereiche gleichzeitig)
5. ✅ **System ist standardisiert** (Heineken-weit einheitlich)

**Für die App bedeutet das:**
- Dropdown: "Bereich auswählen" (1-5)
- Automatische Preisberechnung
- Statistiken nach Bereich
- Wartungsempfehlungen bei häufigen Störungen
- Schulungsmaterial für neue Franchise-Nehmer
