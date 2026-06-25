# Eingangsrechnungen — Implementation Plan (TP-0 bis TP-2 + Outline TP-3..7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) oder superpowers:executing-plans. Steps nutzen Checkbox-(`- [ ]`)-Syntax.

**Goal:** Geschäftsrelevante Post (ClearScanner-PDFs) hochladen → KI erkennt Rechnung vs. Info → Kreditoren-Buchung + GKB-Zahlungsfile + camt-Abschluss + Lieferanten-Lernen.

**Architecture:** Externes Scannen (ClearScanner) → PDF-Upload (bestehendes `BelegUploadWidget` + Bucket `buchungs-belege`). Eigene Edge-Function `parse-rechnung` (Claude Haiku 4.5) + Swiss-QR-Decode liefert strukturierte Felder. Bestätigte Rechnung → 2-stufige Kreditoren-Buchung (Aufwand+Vorsteuer an 2000; später 2000 an Bank via camt). Lernen über `kreditor_regel`.

**Tech Stack:** Flutter + Supabase (Postgres + Edge Functions/Deno) + Riverpod. Buchhaltung Bruttomethode, date-aware MwSt. ISO 20022 pain.001.001.09.ch.03 (TP-4).

**Spec:** `docs/superpowers/specs/2026-06-25-eingangsrechnungen-design.md` (Datenmodell, GKB-Format, Seed-Regeln aus den 17 Scan-Kategorien, Status-Lifecycle).

---

## Hinweise für alle Tasks

- Setup je Bash-Session: `export PATH="$PATH:/c/flutter/bin"` + `cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"`.
- Migrationen: Datei in `Datenbank/migrations/NNN_*.sql` schreiben **und sofort** via Supabase-MCP `apply_migration` (Projekt `pltbaqqwpnmdajwgnhpd`) anwenden + `execute_sql` verifizieren.
- **Rechnungen/Buchungen ist `eingangsrechnung` Supabase-only** (kein Isar) — wie `Rechnung` (Repository `kIsWeb`-frei, nur Supabase).
- **In-Body-Aktionsbuttons als `GestureDetector`+`Container`** (Material-Buttons rendern in CanvasKit teils nicht — bestätigtes Muster). Dialog-Buttons sind ok.
- Vor jedem Deploy: `flutter analyze` 0 Errors + `flutter test` grün; Deploy nach `CLAUDE.md` (Version bumpen → bauen → cache-busten → gh-pages). **Reihenfolge: Version bumpen, DANN bauen.**
- Branch: `feature/eingangsrechnungen` (vor TP-0 anlegen, nicht auf `main` implementieren).

## Umsetzungs-Abweichungen vom Plan (Stand 25.06.2026, nach Entscheidungen)

- **QR-Erkennung (Task 1.3 entfällt):** Kein QR-Decoder. `parse-rechnung` liest die im Zahlteil **gedruckten** Felder (IBAN/Referenz/Betrag/Typ) per KI. Echter Swiss-QR-Decoder vertagt auf TP-6.
- **Scan-Erfassung:** extern via **ClearScanner → PDF-Upload** (`FilePicker`, PDF-only im MVP). Kein App-Kamera-Scanner.
- **Beleg-Storage:** NICHT via `BuchungsBelegRepository`/`beleg_id` (dessen `buchung_id` hat FK auf `buchungen`, existiert beim Scannen noch nicht) — stattdessen Migration **107** (`beleg_pfad`, `beleg_dateiname`) + `EingangsrechnungRepository.uploadBeleg`/`signedBelegUrl` im selben Bucket `buchungs-belege` unter Pfad `{userId}/eingangsrechnung/{id}/...`.
- **Erkennungs-Output:** `RechnungScanResult` (Felder s. `lib/data/models/rechnung_scan_result.dart`); Service `RechnungScanService.scan`.

---

# TP-0 — Fundament (Migration + Modell + Repository + Upload)

## Task 0.1: Migration `eingangsrechnung`

**Files:** Create `Datenbank/migrations/106_eingangsrechnung.sql`

- [ ] **Step 1: Migration schreiben**
```sql
-- Migration 106: Eingangsrechnungen (Scan -> Kreditoren -> camt-Abschluss)
CREATE TABLE IF NOT EXISTS eingangsrechnung (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  aussteller_name text,
  aussteller_uid text,
  lieferant_iban text,
  qr_referenz text,
  referenz_typ text,                  -- 'QRR' | 'SCOR' | 'NON'
  betrag_brutto numeric,
  mwst_satz numeric,
  vorsteuer_konto int,
  mwst_pflichtig bool DEFAULT true,
  rechnungsnummer text,
  rechnungsdatum date,
  faelligkeit date,
  aufwandskonto int,
  geschaeftsfall_id text,
  ist_nur_info bool NOT NULL DEFAULT false,
  dok_typ text,                       -- 'rechnung'|'mahnung'|'akontorechnung'|'schlussrechnung'|'gutschrift'|'info'
  status text NOT NULL DEFAULT 'erkannt',
  gebucht_am timestamptz,
  zahlung_vorgemerkt bool NOT NULL DEFAULT false,
  zahlungsfile_id uuid,
  exportiert_am timestamptz,
  bezahlt_am date,
  buchung_stufe1_id uuid,
  buchung_stufe2_id uuid,
  camt_tx_key text,
  konfidenz numeric,
  beleg_id uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE eingangsrechnung ENABLE ROW LEVEL SECURITY;
CREATE POLICY eingangsrechnung_owner ON eingangsrechnung
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS eingangsrechnung_status_idx ON eingangsrechnung (user_id, status);
CREATE INDEX IF NOT EXISTS eingangsrechnung_camtkey_idx ON eingangsrechnung (camt_tx_key) WHERE camt_tx_key IS NOT NULL;
```

- [ ] **Step 2: Anwenden + verifizieren** — `apply_migration` (name `eingangsrechnung`), dann `execute_sql`:
```sql
select column_name, data_type from information_schema.columns where table_name='eingangsrechnung' order by ordinal_position;
```
Erwartung: alle Spalten vorhanden.

- [ ] **Step 3: Commit** — `git add Datenbank/migrations/106_eingangsrechnung.sql && git commit -m "feat(db): Migration 106 eingangsrechnung (TP-0)"`

## Task 0.2: DTO `EingangsrechnungLocal`-frei (Supabase-only Modell)

**Files:** Create `sbs_projer_app/lib/data/models/eingangsrechnung.dart`; Test `sbs_projer_app/test/eingangsrechnung_test.dart`

- [ ] **Step 1: Failing-Test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';

void main() {
  test('fromJson/toJson round-trip Kernfelder', () {
    final e = Eingangsrechnung.fromJson({
      'id': 'e1', 'user_id': 'u', 'aussteller_name': 'Heineken Switzerland AG',
      'betrag_brutto': '3772.70', 'mwst_satz': '8.1', 'referenz_typ': 'QRR',
      'status': 'erkannt', 'ist_nur_info': false, 'aufwandskonto': 6301,
    });
    expect(e.ausstellerName, 'Heineken Switzerland AG');
    expect(e.betragBrutto, 3772.70);
    expect(e.aufwandskonto, 6301);
    expect(e.toJson()['referenz_typ'], 'QRR');
  });
}
```

- [ ] **Step 2: Test ausführen → FAIL** — `flutter test test/eingangsrechnung_test.dart`

- [ ] **Step 3: Modell implementieren** — analog `lib/data/models/rechnung.dart` (Supabase-DTO mit `fromJson`/`toJson`), Felder gemäss Migration 106. Numerik via `double.tryParse(v.toString())`. `ist_nur_info`/`zahlung_vorgemerkt` als bool mit Default false. Datums-Felder `DateTime?` via `DateTime.parse` (nur Datum). Kernfelder als getter: `ausstellerName`, `lieferantIban`, `qrReferenz`, `referenzTyp`, `betragBrutto`, `mwstSatz`, `vorsteuerKonto`, `rechnungsnummer`, `rechnungsdatum`, `faelligkeit`, `aufwandskonto`, `geschaeftsfallId`, `mwstPflichtig`, `istNurInfo`, `dokTyp`, `status`, `konfidenz`, `belegId`, `camtTxKey`.

- [ ] **Step 4: Test → PASS** — `flutter test test/eingangsrechnung_test.dart` (2 Felder geprüft).

- [ ] **Step 5: Commit** — `git commit -m "feat(model): Eingangsrechnung DTO (TP-0)"`

## Task 0.3: `EingangsrechnungRepository`

**Files:** Create `sbs_projer_app/lib/data/repositories/eingangsrechnung_repository.dart`

- [ ] **Step 1: Implementieren** — Supabase-only (Muster `rechnung_repository.dart`, paginiert!):
```dart
class EingangsrechnungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<Eingangsrechnung> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId; json.remove('id');
    final rows = await SupabaseService.client.from('eingangsrechnung').insert(json).select();
    return Eingangsrechnung.fromJson(rows.first);
  }
  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client.from('eingangsrechnung').update(fields).eq('id', id);
  }
  static Future<List<Eingangsrechnung>> getByStatus(List<String> stati) async {
    final rows = await SupabaseService.client.from('eingangsrechnung')
        .select().eq('user_id', _userId).inFilter('status', stati)
        .order('rechnungsdatum', ascending: false);
    return rows.map((r) => Eingangsrechnung.fromJson(r)).toList();
  }
  static Future<Eingangsrechnung?> getById(String id) async {
    final rows = await SupabaseService.client.from('eingangsrechnung').select().eq('id', id).limit(1);
    return rows.isEmpty ? null : Eingangsrechnung.fromJson(rows.first);
  }
}
```
- [ ] **Step 2: analyze** — `flutter analyze lib/data/repositories/eingangsrechnung_repository.dart` → keine Fehler.
- [ ] **Step 3: Commit** — `git commit -m "feat(repo): EingangsrechnungRepository (TP-0)"`

## Task 0.4: Provider + Dashboard-Kachel + Route (Gerüst)

**Files:** Create `lib/presentation/providers/eingangsrechnung_providers.dart`; Modify `lib/core/config/router.dart`, `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: Provider** — `eingangsrechnungenProvider` (FutureProvider, ruft `getByStatus(['erkannt','bestaetigt','gebucht','zahlung_vorgemerkt','exportiert'])`).
- [ ] **Step 2: Route** `/buchhaltung/eingangsrechnungen` → `EingangsrechnungListeScreen` (Platzhalter-Screen mit Scaffold + „Eingangsrechnungen", wird in TP-1/2 gefüllt).
- [ ] **Step 3: Dashboard-Kachel** „Eingangsrechnungen" (Icon `Icons.mark_email_read`) → `context.push('/buchhaltung/eingangsrechnungen')`.
- [ ] **Step 4: analyze + Commit** — `git commit -m "feat(eingangsrechnung): Gerüst Provider/Route/Kachel (TP-0)"`

---

# TP-1 — Scan + KI-Erkennung

## Task 1.1: Edge Function `parse-rechnung`

**Files:** Create `supabase/functions/parse-rechnung/index.ts` (Template: `supabase/functions/parse-beleg/index.ts`)

- [ ] **Step 1: Function schreiben** — Struktur 1:1 wie `parse-beleg` (CORS, ANTHROPIC_API_KEY, AbortController 50s, Claude `claude-haiku-4-5-20251001`, JSON-Extraktion), ABER: Eingabe `{ file_base64, media_type }`; bei `media_type==='application/pdf'` Content-Block `type:"document"` (source base64), sonst `type:"image"`. Prompt = Schweizer **Eingangsrechnungs**-Spezialist mit Output-Schema:
```json
{ "ist_rechnung": true, "dok_typ": "rechnung", "ist_nur_info": false,
  "aussteller_name": "...", "aussteller_uid": "CHE-...",
  "empfaenger_iban": "CH..", "referenz": "...", "referenz_typ": "QRR",
  "rechnungsnummer": "...", "rechnungsdatum": "YYYY-MM-DD", "faelligkeit": "YYYY-MM-DD",
  "betrag_zahlbar": 0.0, "mwst_satz": 8.1, "mwst_pflichtig": true, "konfidenz": 0.9 }
```
Prompt-Regeln (aus Spec/Memory): „zahlbar = QR-/Saldo-Betrag, NICHT Brutto-Zeile"; hoheitliche Positionen (Feuerwehrabgabe, Fahrbewilligung, Bussen) `mwst_satz=0, mwst_pflichtig=false`; `referenz_typ` QRR (27-stellig), SCOR (`RF…`) oder NON; `ist_nur_info=true` + `dok_typ='info'` bei Vorsorge-/Lohnausweis, Police, Veranlagung, Lohndeklaration, Schadenbericht; Akonto vs. Schlussrechnung über `dok_typ`; konservative `konfidenz`.

- [ ] **Step 2: Deploy** — via Supabase-MCP `deploy_edge_function` (name `parse-rechnung`, verify_jwt=false). (Secret ANTHROPIC_API_KEY ist bereits gesetzt.)
- [ ] **Step 3: Manueller Smoke-Test** — eine Beispiel-Rechnung als base64 an die Function senden (curl o. ä.), prüfen dass valides JSON mit den Feldern kommt. Ergebnis im Commit-Body notieren.
- [ ] **Step 4: Commit** — `git commit -m "feat(edge): parse-rechnung (Claude Vision Eingangsrechnungen) (TP-1)"`

## Task 1.2: `RechnungScanResult` + `RechnungScanService`

**Files:** Create `lib/data/models/rechnung_scan_result.dart`, `lib/services/eingangsrechnung/rechnung_scan_service.dart`; Test `test/rechnung_scan_result_test.dart` (Template: `beleg_scan_result.dart`, `beleg_scan_service.dart`)

- [ ] **Step 1: Failing-Test** für `RechnungScanResult.fromJson` (mappt die parse-rechnung-Antwort → Felder; `betragZahlbar`, `referenzTyp`, `istNurInfo`, `konfidenz`).
- [ ] **Step 2: FAIL.**
- [ ] **Step 3: Model + Service** — `RechnungScanResult` mit allen Output-Feldern. `RechnungScanService.scan(Uint8List bytes, String mediaType)` → `SupabaseService.client.functions.invoke('parse-rechnung', body: {'file_base64': base64Encode(bytes), 'media_type': mediaType})` → `RechnungScanResult.fromJson`.
- [ ] **Step 4: PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(eingangsrechnung): RechnungScanResult + RechnungScanService (TP-1)"`

## Task 1.3: Swiss-QR aus PDF/Bild dekodieren (deterministische Zahldaten)

**Files:** Create `lib/services/eingangsrechnung/swiss_qr_decoder.dart`; Test `test/swiss_qr_decoder_test.dart`

- [ ] **Step 1: Reine Parse-Funktion testen** — `parseSwissQrPayload(String spc)` zerlegt den Swiss-QR-Text (Zeilen, `SPC`-Header) → `{iban, referenzTyp, referenz, betrag, waehrung, cdtrName}`. Testvektor: ein bekannter SPC-Payload (Header SPC/0200/1, IBAN, Betrag, Referenztyp QRR/SCOR/NON, Ref). Assert die Felder.
- [ ] **Step 2: FAIL → implementieren → PASS** — reine String-Zerlegung (Gegenstück zu `_buildQrData` im PDF-Service; Feldreihenfolge gemäss Swiss QR-Bill). Das **Auslesen des QR aus dem PDF-Bild** (Bibliothek wie `mobile_scanner`/`zxing`, oder serverseitig in parse-rechnung) ist separater Integrationsschritt; die reine Payload-Zerlegung ist getestet.
- [ ] **Step 3: Resolver** `effektiveZahldaten(RechnungScanResult ki, Map? qr)` — QR-Daten (falls vorhanden) überschreiben KI-Werte für iban/referenz/betrag (QR ist exakt), KI bleibt für Klassifikation (Konto/Typ). Test: QR vorhanden → QR-IBAN gewinnt; QR null → KI.
- [ ] **Step 4: Commit** — `git commit -m "feat(eingangsrechnung): Swiss-QR-Payload-Decoder + Zahldaten-Resolver (TP-1)"`

## Task 1.4: Upload- + Erkennungs-Screen

**Files:** Create `lib/presentation/screens/eingangsrechnungen/eingangsrechnung_upload_screen.dart`

- [ ] **Step 1: Screen** — nutzt `BelegUploadWidget` (PDF) zum Hochladen; nach Upload: Datei in Bucket `buchungs-belege` via `BuchungsBelegRepository` (beleg_quelle `eingangsrechnung_scan`) + Bytes an `RechnungScanService.scan(...)`. Anzeige der erkannten Felder (read-only Vorschau) + „Übernehmen" → `EingangsrechnungRepository.create({...status:'erkannt', beleg_id, konfidenz, ...})`. Buttons als `GestureDetector` (CanvasKit). Mehrere PDFs nacheinander → mehrere Eingangsrechnungen (Merge erst in TP-6).
- [ ] **Step 2: analyze + Web-Build** — kompiliert.
- [ ] **Step 3: Commit** — `git commit -m "feat(eingangsrechnung): Upload+Erkennungs-Screen (TP-1)"`

---

# TP-2 — Bestätigung + Kreditoren-Buchung (Stufe 1)

## Task 2.1: Reine Buchungs-Berechnung (Netto/Vorsteuer)

**Files:** Create `lib/services/eingangsrechnung/kreditor_buchung.dart`; Test `test/kreditor_buchung_test.dart`

- [ ] **Step 1: Failing-Test**
```dart
test('MwSt-pflichtig: Netto + Vorsteuer aus Brutto (8.1%)', () {
  final r = kreditorBuchungsZeilen(brutto: 108.10, mwstSatz: 8.1,
      aufwandskonto: 6301, vorsteuerKonto: 1170, kreditorKonto: 2000);
  // Netto = 100.00, Vorsteuer = 8.10
  expect(r.length, 2);
  expect(r[0].sollKonto, 6301); expect(r[0].betrag, 100.00); expect(r[0].habenKonto, 2000);
  expect(r[1].sollKonto, 1170); expect(r[1].betrag, 8.10); expect(r[1].habenKonto, 2000);
});
test('MwSt-frei (hoheitlich): nur Aufwand brutto an Kreditor', () {
  final r = kreditorBuchungsZeilen(brutto: 40.00, mwstSatz: 0,
      aufwandskonto: 6275, vorsteuerKonto: null, kreditorKonto: 2000);
  expect(r.length, 1);
  expect(r[0].sollKonto, 6275); expect(r[0].betrag, 40.00);
});
```
- [ ] **Step 2: FAIL → implementieren** — reine Funktion: Netto = round2(brutto / (1 + satz/100)); Vorsteuer = round2(brutto − netto); 2 Zeilen bei satz>0 + vorsteuerKonto!=null, sonst 1 Zeile brutto. (5-Rappen NICHT hier — Buchung ist 2-Stellen; 5-Rappen nur Bank.) → PASS.
- [ ] **Step 3: Commit** — `git commit -m "feat(eingangsrechnung): reine Kreditor-Buchungs-Berechnung (TP-2)"`

## Task 2.2: Stufe-1-Buchung persistieren

**Files:** Create `lib/services/eingangsrechnung/eingangsrechnung_buchung_service.dart`

- [ ] **Step 1: Service** `bucheStufe1(Eingangsrechnung e)` — pro Zeile aus Task 2.1 `BuchungRepository.create({datum: rechnungsdatum, soll_konto, haben_konto, betrag, mwst_konto: vorsteuerKonto (nur Vorsteuer-Zeile), mwst_satz, beleg_typ:'eingangsrechnung', beleg_id, geschaeftsfall_id, bezeichnung})`. Erste Buchung-ID → `eingangsrechnung.buchung_stufe1_id`; `update(e.id, {status:'gebucht', gebucht_am: now, zahlung_vorgemerkt:true})`. (Bei Sonderkonten 2271/2202/2208 ist `kreditorKonto` entsprechend gesteuert, Default 2000.)
- [ ] **Step 2: analyze** — keine Fehler. (IO-Service; reine Logik ist in 2.1 getestet.)
- [ ] **Step 3: Commit** — `git commit -m "feat(eingangsrechnung): Stufe-1-Kreditor-Buchung (TP-2)"`

## Task 2.3: Listen-Screen (nach Status gruppiert)

**Files:** Modify `lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart`

- [ ] **Step 1: Screen** — Gruppen: „Zu bestätigen" (erkannt) / „Offen — vorgemerkt/exportiert" / „Bezahlt" / „Info/Ablage" (ist_nur_info). Zeile: Aussteller · Betrag · Datum · Status-Chip, Tap → Detail. Provider-Invalidierung nach Aktionen.
- [ ] **Step 2: analyze + Commit** — `git commit -m "feat(eingangsrechnung): Listen-Screen (TP-2)"`

## Task 2.4: Detail-Screen — prüfen/korrigieren/bestätigen

**Files:** Create `lib/presentation/screens/eingangsrechnungen/eingangsrechnung_detail_screen.dart`

- [ ] **Step 1: Screen** — zeigt PDF (signierte URL), editierbare Felder (Aussteller, IBAN, Referenz+Typ, Betrag, MwSt-Satz, **Aufwandskonto** Dropdown aus Kontenplan, Fälligkeit). Aktionen (`GestureDetector`): **„Bestätigen & buchen"** → `update(status:'bestaetigt')` + `EingangsrechnungBuchungService.bucheStufe1` ; **„Nur ablegen (Info)"** → `update(status:'abgelegt', ist_nur_info:true)`; **„Verwerfen"** → `update(status:'verworfen')`. Konfidenz-Warnung bei <0.85.
- [ ] **Step 2: analyze + Web-Build + Commit** — `git commit -m "feat(eingangsrechnung): Detail-Screen + Bestätigen/Buchen (TP-2)"`

## Task 2.5: TP-0..2 Gesamtverifikation + Deploy

- [ ] `flutter analyze` 0 Errors · `flutter test` grün · Web-Build ok.
- [ ] Manueller Browser-Test: PDF hochladen → Erkennung → Detail → Bestätigen → Buchung im Journal sichtbar (Aufwand+Vorsteuer an 2000). Info-PDF → Ablage.
- [ ] Version bumpen → Deploy nach `CLAUDE.md`. ToDo.md + Memory aktualisieren.

---

# Outline TP-3 bis TP-7 (Detail-Pläne bei Umsetzungsstart)

### TP-3 — Lieferanten-Lernen (`kreditor_regel`)
- Migration `kreditor_regel` (Spec §Datenmodell) + **Seed-Regeln** aus den 17 Kategorien (Spec §Seed-Regeln) als INSERTs.
- `KreditorMatcher.matchRegel(aussteller, iban, referenz)` — Reihenfolge IBAN → Referenz-Präfix → Name (höchste Priorität); reine Funktion, getestet (inkl. AXA-3-Verträge- + Gemeinde-Präfix-Disambiguierung).
- Auto-Vorbelegung im Detail-Screen (Konto/MwSt/Geschäftsfall vorausgefüllt).
- Lernen bei Bestätigung (idempotent, Konflikt-Check, Muster `entscheideAlias`).
- `kreditor_regeln_screen.dart` (Verwaltung, analog `camt_regeln_screen.dart`).

### TP-4 — GKB-Zahlungsfile (pain.001.001.09.ch.03)
- Reiner `Pain001Writer` (getestet, gegen XSD validierbar): Fall A (QR-IBAN+QRR), B (IBAN+SCOR), C (IBAN+Ustrd); harte Konsistenzregeln; strukturierte Adressen.
- Dbtr-Stammdaten aus `geschaeft_einstellungen` (eigene GKB-IBAN/Adresse) — ggf. Migration/Settings ergänzen.
- `zahlungsfile`-Tracking + `zahlungsfile_export_screen.dart` (vorgemerkte sammeln → XML generieren → Download) → Status `exportiert`.
- IBAN/QR-IBAN/SCOR-Validierung (reuse `scor_referenz.dart`); QRR-mod10-Util.

### TP-5 — camt-Kreditor-Abschluss (Stufe 2)
- `offene_kreditor_repository` (offene Eingangsrechnungen mit Referenz/IBAN).
- `KreditorenAbgleichService` Matching-Kette (Referenz → IBAN+Betrag → Name+Betrag → Fallback Regel).
- `CamtKreditorBooker` (Kreditoren 2000 an Bank 1020, echtes Bankdatum, `setCamtTxKey`, status `bezahlt`).
- Integration als Stufe **vor** Regel-Match in `CamtAutoBooker` (Bestätigungs-Modus beibehalten).

### TP-6 — Info-Docs + Reversibilität + Multi-PDF
- Info-Ablage-Liste verfeinern (Suche/Filter nach dok_typ/Aussteller).
- camt-Reversibilität: Löschen einer Stufe-2-Buchung (`camt_tx_key`) → Eingangsrechnung-Status zurück auf `exportiert`/`gebucht`.
- Multi-PDF-Merge: mehrere hochgeladene PDFs zu einem Dokument zusammenfügen (oder bereits gemergtes ClearScanner-PDF).

### TP-7 — Datenhygiene
- Ausgabe-`BuchungsVorlagen` auf `A-*` konsolidieren/reaktivieren; Konten-Altlasten (8090/9100/Duplikate) bereinigen.

---

## Selbst-Review (Spec-Abdeckung)

- **Scan/Upload (extern ClearScanner, PDF, multi)** → TP-1 (1.4) + TP-6 (Merge).
- **KI-Erkennung Rechnung vs. Info + welche genau** → TP-1 (1.1/1.2) + Seed-Klassifikation TP-3.
- **GKB-Zahlungsfile (pain.001.09)** → TP-4.
- **Kreditoren-Buchung 2-stufig** → TP-2 (Stufe 1) + TP-5 (Stufe 2 via camt).
- **Lernverhalten** → TP-3.
- **Alle Files in App gespeichert** → TP-0/TP-1 (Bucket buchungs-belege, beleg_id).
- **Info-Docs erfassen+ablegen** → TP-2 (2.4) + TP-6.
- **Reversibilität** → TP-6.
- Seed-Wissen der 17 Kategorien → Spec §Seed-Regeln, umgesetzt in TP-3.
