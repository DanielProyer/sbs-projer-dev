# Forderungen-Hub – Konsolidierung Debitoren/Rechnungen/Mahnwesen – Design

**Datum:** 2026-06-13 · **Status:** Spec zur Freigabe durch Daniel

---

## 1. Ziel

Die drei überlappenden Einstiege **Rechnungsliste**, **Mahnwesen** und **Debitoren** zu **einem** „Forderungen"-Hub zusammenführen — ein Ort für offene Kundenforderungen, Mahnwesen-Aktionen und Debitoren-/Abschreibungs-Übersicht. Weniger Screens, eine zentrale Status-Logik, keine doppelten Ansichten.

## 2. Ausgangslage (Redundanz)

- **RechnungenListScreen** (`/rechnungen`, ~1100 Z.): vollständige Liste, Status-Filter, Sammelzahlung, Status-Dialog → ruft `MahnwesenService` + `ZahlungsdifferenzService`.
- **MahnwesenScreen** (`/buchhaltung/mahnwesen`): Teilmenge der offenen Rechnungen mit „empfohlener Aktion" (aus DB-View `view_mahnwesen_dashboard`) + Eskalations-/Abschreib-Aktion → **redundant** zur Rechnungsliste.
- **DebitorenScreen** (`/buchhaltung/debitoren`): nur Konto-Salden (1100/1109) + Sammel-Abschreibung/Delkredere — **zeigt nicht die Rechnungen** dahinter.
- Status-Übergänge an **zwei** Stellen (Rechnungsliste-Dialog + Mahnwesen-Aktionen).

## 3. Lösung: Forderungen-Hub

### 3.1 `ForderungService` (zentral) — `lib/services/rechnung/forderung_service.dart`
- **`empfohleneAktion(Rechnung r) → String`** (rein, TDD): bildet die View-Logik in Dart ab (`DateTime.now()` statt `CURRENT_DATE`):
  - `bezahlt`/`abgeschrieben` oder `rechnungstyp == 'heineken_monat'` → `'warten'`
  - `offen` & überfällig ≥ 5 Tage → `'erinnerung_faellig'`
  - `erinnert` & `erinnerungAm != null` & ≥ 25 Tage → `'mahnung_1_faellig'`
  - `mahnung_1` & `mahnung1Am != null` & ≥ 30 Tage → `'mahnung_2_faellig'`
  - `mahnung_2` → `'eskalation'`
  - sonst → `'warten'`
- **`istMahnfaellig(Rechnung r) → bool`** = `empfohleneAktion(r) != 'warten'`.
- Die Status-Übergänge (eskalieren/abschreiben/Zahlung) bleiben in `MahnwesenService`/`ZahlungsdifferenzService` — der Hub UND die Detail-Ansicht nutzen sie über **einen** gemeinsamen Aufruf (keine duplizierte Dialog-Logik).

### 3.2 Provider
- **`forderungenProvider`** (FutureProvider): alle Kundenrechnungen (`rechnungstyp = 'rechnung_kunde'`) + lokal berechnete `empfohleneAktion` — ersetzt `mahnwesenDashboardProvider` (DB-View entfällt aus der Nutzung).
- `debitorenUebersichtProvider` bleibt (Salden-Kopf), wird im Hub genutzt.
- `mahnwesenDashboardProvider` + `offeneRechnungenViewProvider` werden entfernt/zusammengeführt (Nutzer auf `forderungenProvider` umstellen).

### 3.3 Hub-Screen (erweiterte Rechnungsliste, umbenannt zu Forderungen)
- **Status-Filter-Chips** inkl. **„Mahnfällig"** (`ForderungService.istMahnfaellig`) → ersetzt MahnwesenScreen.
- **Einklappbarer Debitoren-Kopf:** Salden (1100 gesamt / native offen / historisch / 1109 Delkredere) + Buttons **„Sammel-Abschreibung"** + **„Delkredere 5 %"** (Logik aus DebitorenScreen verschoben) → ersetzt DebitorenScreen.
- **Zeilen-Aktion** bei mahnfälligen: zeigt die empfohlene Aktion + Button „Mahnen/Eskalieren" / „Abschreiben" (über den zentralen Handler). Sammelzahlung wie bisher.

### 3.4 Aufräumen
- Routen `/buchhaltung/mahnwesen` und `/buchhaltung/debitoren` → **Redirect auf den Hub** (`/buchhaltung/forderungen` bzw. `/rechnungen`); die beiden Screen-Dateien werden entfernt, ihre genutzte Logik ist im Hub/Service.
- Dashboard (`buchhaltung_dashboard_screen`) + `home_screen`: die Tiles „Rechnungen"/„Mahnwesen"/„Debitoren" → **ein** Tile „Forderungen".

## 4. Architektur-Einheiten
- `forderung_service.dart` (rein, TDD) · `forderungenProvider` (rechnung_providers) · Hub-Screen (erweiterte rechnungen_list_screen) · Routen-Redirects + Tile-Konsolidierung · entfernte Screens (mahnwesen_screen, debitoren_screen).

## 5. Tests (TDD)
- `ForderungService.empfohleneAktion`: je Fall (offen<5T→warten, offen≥5T→erinnerung_faellig, erinnert≥25T→mahnung_1_faellig, mahnung_1≥30T→mahnung_2_faellig, mahnung_2→eskalation, bezahlt→warten, heineken→warten). Datum über injizierbares „heute" oder relativ zu `DateTime.now()` mit konstruierten Fälligkeiten.
- `istMahnfaellig`: true für die Fälligkeits-Fälle, false für warten.

## 6. Erfolgskriterien
- Ein Einstieg „Forderungen" ersetzt drei Screens; Mahnfällig-Filter + Debitoren-Kopf integriert.
- Status-Übergänge laufen über einen zentralen Pfad (keine Doppel-Logik).
- Mahnwesen-/Debitoren-Routen leiten auf den Hub um; Tiles zusammengeführt.
- Bestehende Funktionen (Sammelzahlung, Eskalation, Abschreibung, Sammel-Abschreibung, Delkredere) weiterhin verfügbar; keine Regression; alle Tests grün.

## 7. Nicht im Scope
- Heineken-Rechnungen (bleiben separater Bereich; Typ-Filter im Hub später).
- DB-View `view_mahnwesen_dashboard` bleibt bestehen (nur nicht mehr genutzt).
- PDF-Service-Vereinheitlichung (separat).
