# Kundenguthaben (schlank) — v0.137.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Eine Überzahlung (Buchung Soll 1020 / Haben **2030 Kundenguthaben**, `beleg_id` = die überzahlte Rechnung) wird bei der **nächsten Kundenrechnung** desselben Betriebs verrechnet: Die Rechnung behält Betrag, Ertrag und MWST, zeigt aber «abzüglich Guthaben» und «zu zahlen», der QR-Schein lautet auf «zu zahlen». Zahlt der Kunde diesen Betrag, bucht der Bankabgleich die Differenz als **Verrechnung 2030 an 1100** statt als Verlust 3805.

**Entscheid Daniel 25.09.2026:** schlanke Variante (Verrechnung beim Zuordnen), kein Umbau des Mahnwesens auf «zu zahlen». Rechnungen mit verrechnetem Guthaben werden vom Mahnlauf ausgenommen und dort als eigene Sektion gezeigt.

**Ist-Fall:** Chesa Davos Dorf, Buchung 30.00 (1020/2030, beleg_id = Rechnung 2026-04-0513, 16.09.2026). Nächste Reinigung Ende November.

**Regeln:** `CLAUDE.md` (CanvasKit, Pagination, NULL-Falle, `pdfDokument()`), App `sbs_projer_app/`, Flutter `export PATH="$PATH:/c/flutter/bin"`, kein `git stash`, Commits mit `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`, nach jedem Task `flutter test` (Stand 2150) grün und `flutter analyze` ≤ 56.

---

### Task 1: Migration 205, Modell, Guthaben-Quelle

**Files:** Create `Datenbank/migrations/205_rechnung_guthaben_verrechnet.sql` (Controller wendet an), Modify `lib/data/models/rechnung.dart`, `lib/services/rechnung/mahnlauf_service.dart` (`_mitQrReferenz` kopiert das neue Feld), Create `lib/core/util/guthaben.dart`, `lib/data/repositories/guthaben_repository.dart`, Tests `test/guthaben_test.dart`, `test/rechnung_model_test.dart` (anlegen oder ergänzen).

- [ ] Migration:
```sql
-- 205: Verrechnetes Kundenguthaben auf der Rechnung (25.09.2026)
alter table rechnungen add column if not exists guthaben_verrechnet numeric(10,2) not null default 0
  check (guthaben_verrechnet >= 0);
comment on column rechnungen.guthaben_verrechnet is
  'Aus Konto 2030 verrechnetes Kundenguthaben; zu zahlen = betrag_brutto - guthaben_verrechnet';
```
- [ ] `Rechnung`: Feld `final double guthabenVerrechnet;` (fromJson `guthaben_verrechnet` → 0 bei null, toJson), Getter `double get zuZahlen => betragBrutto - guthabenVerrechnet;` (nie < 0). `copyWith` und `_mitQrReferenz` mitziehen. Test: fromJson ohne Feld → 0; mit 30 → zuZahlen 113.75.
- [ ] `lib/core/util/guthaben.dart` (rein, Tests):
```dart
/// Offenes Guthaben je Betrieb aus Buchungen auf 2030:
/// Haben 2030 = Guthaben entstanden, Soll 2030 = verrechnet/ausbezahlt.
/// [betriebVonRechnung]: beleg_id (Rechnung) → betrieb_id.
Map<String, double> offenesGuthabenJeBetrieb(List<Buchung> buchungen2030, Map<String, String> betriebVonRechnung);
/// Abzug für eine neue Rechnung: min(guthaben, brutto), auf 5 Rappen, nie negativ.
double guthabenAbzug({required double guthaben, required double brutto});
```
  Stornierte Buchungen und Storno-Gegenbuchungen zählen nicht (`zaehltFuerSaldo`, vorhanden). Buchungen ohne `beleg_id` oder ohne bekannte Rechnung werden ignoriert (im Ergebnis unter Schlüssel `''` summiert, damit die Übersicht sie melden kann).
- [ ] `GuthabenRepository.offenesGuthaben(String betriebId) → Future<double>`: Buchungen mit `soll_konto = 2030 or haben_konto = 2030` laden (`.or(...)`, `.order('id')`, seitenweise), zugehörige Rechnungen per `inFilter('id', …)` in Blöcken (`kInFilterBlock`) → `offenesGuthabenJeBetrieb` → Wert für `betriebId` (0 wenn keiner).
- [ ] Commit `feat(rechnungen): Kundenguthaben — Migration 205, Modell, Quelle`.

### Task 2: Verrechnung auf der neuen Rechnung, PDF, Mail, Detail

**Files:** `lib/services/rechnung/rechnung_service.dart` (`createFromReinigung` ~Z. 61–138), `lib/services/rechnung/jahresrechnung_service.dart` (~Z. 126–251), `lib/services/pdf/rechnung_pdf_service.dart` (Z. 45 brutto, Z. 91–98 QR, `_buildSummen` Z. 324–362), Mail-Texte `reinigung_rechnung_versand.dart:149-162`, `reinigung_form_screen.dart:997-1010`, `rechnung_detail_screen.dart:805-817` und Anzeige `:582`, Test `test/rechnung_pdf_guthaben_test.dart`.

- [ ] Beim Anlegen einer Kundenrechnung/Jahresrechnung (nur wenn `betragBrutto > 0`): `guthaben = await GuthabenRepository.offenesGuthaben(betriebId)`; `'guthaben_verrechnet': guthabenAbzug(guthaben:, brutto:)`. Schlägt das Laden fehl → 0 (Rechnung darf nie am Guthaben scheitern; `debugPrint`).
- [ ] PDF: `_buildSummen` zeigt bei `guthabenVerrechnet > 0` zusätzlich «abzüglich Kundenguthaben −CHF 30.00» und fett «Zu zahlen CHF 113.75»; QR-Betrag = `_roundTo5Rappen(rechnung.zuZahlen)`; über der Zahlteil-Linie ein Hinweis «Ihr Guthaben aus der Überzahlung wurde verrechnet.» Test: PDF-Bytes werden erzeugt (Smoke), reine Funktion `summenZeilen(rechnung)` liefert die Zeilen (Test mit/ohne Guthaben).
- [ ] Mail-Texte: «offener Betrag von CHF …» → `zuZahlen`; bei Guthaben Zusatzsatz «(nach Verrechnung Ihres Guthabens von CHF 30.00)».
- [ ] Rechnungsdetail: unter «Total» Zeilen «Guthaben verrechnet» und «Zu zahlen», wenn > 0.
- [ ] Commit `feat(rechnungen): Guthaben auf der naechsten Rechnung verrechnen (PDF, QR, Mail)`.

### Task 3: Bankabgleich, Barzahlung, Mahnlauf, Kontoauszug

**Files:** `lib/services/buchhaltung/zahlungsdifferenz_service.dart`, `lib/core/util/zahlungsdifferenz_text.dart`, `lib/services/camt/forderungs_abgleich_service.dart` (Z. 97–98, 292, 316), `lib/services/camt/rechnung_matcher.dart`, `lib/services/camt/camt_auto_booker.dart:88`, `kundenzahlung_zuordnen_dialog.dart:74-78`, `abgleich_vorschau.dart` (fordSumme/Exakt-Treffer/Paarung), `lib/services/rechnung/barzahlung_service.dart` (kassierBetrag), `lib/presentation/providers/mahnlauf_provider.dart` + `mahnlauf_screen.dart`, `lib/services/pdf/kontoauszug_pdf_service.dart` (Z. 176–219), Tests.

- [ ] **Matching/Summen mit `zuZahlen`:** überall, wo eine Zahlung gegen den Rechnungsbetrag geprüft oder summiert wird (`fordSumme`, Exakt-Treffer, `RechnungMatcher`, Summe mehrerer Nummern), `r.zuZahlen` statt `r.betragBrutto`. `'zahlung_betrag'` beim Setzen auf bezahlt = tatsächlich gezahlt (`zuZahlen`).
- [ ] **`ZahlungsdifferenzService`** (`verbuchenSammel` und `verbuchen`): Hauptbuchung 1020/1100 = `zuZahlen` (5 Rappen). Ist `guthabenVerrechnet > 0`, zusätzlich je Rechnung **Soll 2030 / Haben 1100** über `guthabenVerrechnet`, `beleg_typ 'sonstiges'`, `zahlungsweg 'intern'`, `beleg_id` = Rechnung, Beschreibung «Verrechnung Kundenguthaben <Nr>». Die Differenz (3805/8000) rechnet gegen die Summe der `zuZahlen`. Reine Funktion `differenzPlan(rechnungen, zahlbetrag)` mit Tests (kein Guthaben → wie heute; Guthaben 30 und Zahlung 113.75 → keine Differenz, eine Verrechnungszeile; Zahlung 143.75 trotz Guthaben → Mehrzahlung 30 auf 8000? NEIN: dann bleibt das Guthaben bestehen — Verrechnung nur, wenn die Zahlung ≤ zuZahlen + 0.05; sonst Hauptbuchung über den Zahlbetrag, keine Verrechnungszeile, `guthaben_verrechnet` der Rechnung auf 0 zurücksetzen, Hinweis im Ergebnis).
- [ ] `bewerteDifferenz`-Text: bei verrechnetem Guthaben «Kundenguthaben CHF 30.00 wird verrechnet (2030)».
- [ ] **Barzahlung:** `kassierBetrag(r.zuZahlen)`; bei Guthaben zusätzlich die Verrechnungsbuchung wie oben (gleiche reine Planfunktion nutzen).
- [ ] **Mahnlauf:** Rechnungen mit `guthabenVerrechnet > 0` gehören nicht in mahnfällig/inFrist/eskalation, sondern in neue Liste `mitGuthaben` (Sektion «Mit Guthaben verrechnet — manuell prüfen», Zeilen wie «Erst zustellen»). `passendeGutschrift`-Beträge = `zuZahlen`.
- [ ] **Kontoauszug:** bei `guthabenVerrechnet > 0` Haben-Zeile «Verrechnung Guthaben» am Rechnungsdatum; Saldo entsprechend.
- [ ] Commit `feat(buchhaltung): Guthaben-Verrechnung im Bankabgleich, Barzahlung, Mahnlauf, Kontoauszug`.

### Task 4: Release v0.137.0 (Controller)

- [ ] Migration 205 anwenden; Review (Opus); Nachbesserung.
- [ ] Browser 360 px: Rechnungsdetail 2026-04-0513 (Chesa) und Guthaben-Quelle prüfen (30.00), Test-PDF einer Rechnung mit `guthaben_verrechnet` per SQL setzen und PDF neu erzeugen, danach zurück.
- [ ] Chesa-Notiz am Betrieb anpassen («Guthaben wird automatisch mit der nächsten Rechnung verrechnet»), ToDo-Eintrag erledigen.
- [ ] Version 0.137.0+790, Chronik, Projekt.md, Commit, Push, Deploy, Live-Version.
