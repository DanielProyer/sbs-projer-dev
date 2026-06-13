# Phase 2a – Audit-Ansicht + sichere mechanische Korrekturen – Design

**Datum:** 2026-06-13 · **Status:** Spec zur Freigabe durch Daniel
**Übergeordnet:** Phase 2 (Aufräumen), Sub-Projekt 2a. Folge-Teile: 2b (Jahres-Abschluss/9100), 2c (Debitoren-Abschreibung, mit Treuhänder).

---

## 1. Ziel

Nach dem treuen Voll-Import (Phase 1) verdächtige Buchungen/Salden **sichtbar machen** (Audit-Ansicht in der App, read-only) und die **eindeutigen, ermessensfreien** Fehler korrigieren. Entscheidungsbedürftiges (Abschluss-Verschränkung, Debitoren-Abschreibung) bleibt bewusst ausgeklammert.

## 2. Scope

**In 2a:**
- **Audit-Service + Screen** (read-only): kategorisiert auffällige Posten.
- **Korrektur 8090 → 8900** (6 Buchungen, alle Haben, 2021–2023, Steuer-Rückerstattungen; Tippfehler-Konto → Direkte Steuern).
- **Korrektur 2500 Restsaldo** (−1.35 → 0; Rundungs-/Schlussdifferenz Coronakredit).

**NICHT in 2a:**
- 9100 → 9010 + die verschränkten Abschluss-Konten (9000/2970/2980) → **2b** (eigene Analyse; kein reiner Tippfehler).
- Debitoren-Abschreibung (1100 ≈ 116k) → **2c** (Treuhänder).

## 3. Korrektur-Prinzip (entschieden)

**Rückdatiert ins Ursprungsjahr** = die betroffenen Buchungszeilen werden **in-place** auf das richtige Konto umklassiert (nur `soll_konto`/`haben_konto` ändern, `datum` bleibt → historische Bilanz/ER des Jahres werden korrekt). **Spur** über: `notizen`-Vermerk an jeder geänderten Zeile (`Phase2-Korrektur: 8090->8900`), das versionierte Migrationsskript, und die eingefrorene Excel als Original. Bewusst akzeptiert: die per Selbstdeklaration gemeldeten Jahre ändern sich geringfügig.

## 4. Komponenten

### 4.1 `AuditService` (rein, testbar) — `lib/services/buchhaltung/audit_service.dart`
Eingabe: Map `kontonummer → Saldo` (Anzeige-Saldo, wie `BuchungService.getAllSaldi`) + Liste `KontoInfo` (kontonummer, bezeichnung, kategorie). Ausgabe: `List<AuditBefund>` mit `kategorie, konto, bezeichnung, saldo, hinweis`.

**Regeln (4 Kategorien):**
1. **Fehler-Konten:** `bezeichnung` enthält „FEHLER" und |Saldo| > 0.05 → Hinweis „falsches Konto, umbuchen".
2. **Unerwartet negativer Saldo:** Anzeige-Saldo < −0.05 auf Konten der Klasse 1 (Aktiven) oder auf den Steuer-/MWST-Konten 2200/8900 → „negativer Saldo prüfen".
3. **Abschluss-Konten mit Restsaldo:** Konto-Klasse 9 oder Konto 2980, |Saldo| > 0.05 → „Abschlussbuchung unvollständig".
4. **Hoher Debitorensaldo:** Konto 1100, Saldo > 0 → „offene Forderungen prüfen/abschreiben (Phase 2c)".

Reine Funktion `befunde(saldi, konten)`; keine Supabase/Riverpod-Abhängigkeit.

### 4.2 Provider + Screen
- `auditBefundeProvider` (FutureProvider): lädt `BuchungService.getAllSaldi()` + `KontoRepository.getAll()`, ruft `AuditService.befunde`.
- `AuditScreen` (ConsumerWidget, Muster wie `BilanzScreen`): Liste gruppiert nach Kategorie, je Befund Konto/Bezeichnung/Saldo/Hinweis, Farbcodierung (`AppColors`). Route `/buchhaltung/audit` + Dashboard-Tile.

### 4.3 Korrektur-Migration `Datenbank/migrations/093_korrektur_8090_2500.sql`
- `UPDATE buchungen SET haben_konto=8900, notizen=...` WHERE `haben_konto=8090` (und defensiv `soll_konto=8090` → 8900) für `user_id=Daniel`, `datum<'2025-12-01'`.
- 2500-Restsaldo glätten: eine kleine Umbuchung (1.35) im letzten Coronakredit-Jahr, die den Restsaldo auf 0 bringt (Gegenkonto 6940 Bankgebühren / oder Finanzaufwand), mit `notizen`-Vermerk. (Betrag wird beim Umsetzen aus dem Ist-Saldo exakt bestimmt.)

## 5. Datenfluss
```
buchungen ─► getAllSaldi (MWST-korrekt) ─┐
konten ──────────────────────────────────┼─► AuditService.befunde ─► AuditScreen
                                          └─► (separat) Korrektur-Migration aktualisiert buchungen
```

## 6. Tests (TDD)
- `AuditService.befunde`: Fehler-Konto (FEHLER im Namen) wird gelistet; negativer Aktiv-Saldo wird gelistet; Abschluss-Konto mit Restsaldo wird gelistet; 1100>0 wird gelistet; saubere Konten (kein Befund) erzeugen keinen Eintrag; |Saldo|≤0.05 wird ignoriert.
- Korrektur-Verifikation (SQL, kein Unit-Test): nach Migration `count(*)` mit Konto 8090 = 0; 8900-Saldo um +1365.15 verschoben (Vorzeichen beachten); 2500-Saldo = 0.

## 7. Erfolgskriterien
- Audit-Screen zeigt die aktuellen Auffälligkeiten kategorisiert (Fehler-Konten, negative Salden, Abschluss-Reste, hoher Debitorensaldo).
- 8090 hat keine Buchungen mehr (alle → 8900); 8900 enthält die Steuer-Rückerstattungen; historische Jahre 2021–2023 korrigiert.
- 2500-Saldo = 0.
- Bestehende Tests/Screens unverändert; kein Deploy.

## 8. Nicht im Scope
- 9100/Abschluss-Reconciliation (2b), Debitoren-Abschreibung (2c).
- Korrektur-UI in der App (Korrekturen laufen als Migration; die App-Korrektur-Maske kommt ggf. später).
