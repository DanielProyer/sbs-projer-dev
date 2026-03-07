# ToDo-Liste - Daniel Projer

**Stand**: 12.02.2026
**Für**: SBS Projer App Entwicklung

---

## 🔴 VOR DEVELOPMENT-START

### Daten-Vorbereitung

- [ ] **Regionen-Polygone erstellen (GIS)**
  - KML-Dateien für alle 11 Regionen erstellen:
    - Arosa
    - Chur
    - Davos
    - Domleschg
    - Flims/Laax/Falera
    - Lenzerheide
    - Oberland
    - Prättigau
    - Rheintal
    - Rheinwald
    - Innerschweiz
  - Format: KML oder GeoJSON
  - Koordinatensystem: WGS84 (EPSG:4326)
  - **Notiz**: Evtl. ergeben sich andere Gebietsaufteilungen beim Erstellen
  - **Wann**: Kann später gemacht werden, nicht kritisch für MVP

---

## 🟡 WÄHREND DEVELOPMENT

### Testing & Feedback

- [ ] **Beta-Testing Phase**
  - App auf echten Geräten testen
  - Real-World-Szenarien durchspielen
  - Offline-Modus testen (Bergkunden ohne Netz)
  - Feedback an Entwickler

### Daten-Migration

- [ ] **Excel-Daten vorbereiten**
  - Aktuelle Excel-Datei sichern
  - Letzte Änderungen eintragen
  - Bereit für Import

---

## 🟢 NACH MVP-LAUNCH

### Erweiterungen

- [ ] **Andere Franchise-Partner einladen**
  - Kontakte sammeln
  - Interesse abklären
  - Onboarding planen

- [ ] **Zusätzliche Regionen definieren**
  - Regionen der anderen Partner erfassen
  - KML-Dateien erstellen

### Schulung

- [ ] **Andere Partner schulen**
  - Training-Sessions organisieren
  - Dokumentation teilen
  - Support anbieten

---

## 📝 NOTIZEN

### GIS / Regionen-Polygone

**Warum Polygone?**
- Präzise Abgrenzung der Regionen
- "Liegt Betrieb X in meiner Region?" → Automatische Prüfung
- Bessere Visualisierung auf Karte

**Workflow:**
1. QGIS oder Google Earth Pro öffnen
2. Regionen-Grenzen nachzeichnen
3. Als KML exportieren
4. In App importieren

**Tools:**
- QGIS (Open Source)
- Google Earth Pro (kostenlos)
- Google My Maps (Online)

---

## ✅ ERLEDIGT

- [x] Geschäftsabläufe dokumentiert (alle 9 Abschnitte)
- [x] Excel-Daten analysiert
- [x] Regionen-Liste erstellt (11 Regionen)
- [x] Tech-Stack-Entscheidung (Flutter + Supabase)
- [x] Datenmodell entworfen

---

**Zuletzt aktualisiert**: 12.02.2026
