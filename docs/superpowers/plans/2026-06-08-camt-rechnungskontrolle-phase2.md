# camt-Auto-Buchung Phase 2 — Ausgaben-Regelwerk (Implementierungsplan)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Ausgaben (DBIT) und Bargeld/Bank-Abschluss werden ab Stichtag automatisch über ein Regelwerk (Empfänger-Muster → Buchungsvorlage) verbucht; ohne Regel → Prüfliste. Inkl. Regel-Verwaltung-UI und Dashboard-Einstieg.

**Architecture:** Neue Tabelle `camt_regel` (match_name / match_iban / prioritaet → buchungs_vorlage_id). Reiner `RegelMatcher` (Volltext aus Name+Zusatzinfo+IBAN). `CamtAusgabeBooker` erzeugt eine Buchung aus Vorlage+Transaktion (MwSt/Vorsteuer-Split, `camt_tx_key` direkt gestempelt). Verdrahtung in `CamtAutoBooker` (Kategorien `ausgabe` + `bargeldEinzahlung`). 4 neue Vorlagen (5700/5720/5730/8900) + Startregeln als Seed.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase, flutter_test.

**Referenz:** `docs/superpowers/specs/2026-06-08-camt-rechnungskontrolle-design.md` §4.7, `…-buchungsvorlagen-vorschlag.md`. Phase 1 ist auf demselben Branch fertig.

**Bekannte Vorlage-IDs (geschaeftsfall_id):** Franchise Heineken Zahlung 19.1 (2000/1020) · Nettolohn 22.7 (2002/1020) · MWST-Zahlung 25.4 (2202/1020) · Internetabo 15.1 (6510/1020 +VSt1171) · Haftpflicht 24.1 (6300/1020) · Bankgebühren 20.1 (6940/1020) · Zahlungseingang bar 2.1 (1020/1000). Neue Vorlagen: 30.1 AHV (5700/1020) · 30.2 BVG (5720/1020) · 30.3 Suva (5730/1020) · 30.4 kant. Steuern (8900/1020).

---

## Task 1: Migration — camt_regel + 4 neue Vorlagen + Startregeln

**Files:** Create `Datenbank/migrations/088_camt_regel.sql`. Apply via Supabase MCP (Projekt `pltbaqqwpnmdajwgnhpd`).

- [ ] Migration: Tabelle + Seed.

```sql
CREATE TABLE IF NOT EXISTS camt_regel (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  bezeichnung TEXT NOT NULL,
  match_name TEXT,         -- Substring (case-insensitive) in Name+Zusatzinfo
  match_iban TEXT,         -- exakte Gegenpartei-IBAN
  buchungs_vorlage_id UUID NOT NULL REFERENCES buchungs_vorlagen(id),
  prioritaet INT NOT NULL DEFAULT 0,
  ist_aktiv BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE camt_regel ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own rows" ON camt_regel
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

Seed der 4 neuen Vorlagen (user_id = der Daniel-User; in DB ermitteln: `SELECT id FROM auth.users` bzw. denselben user_id wie bestehende buchungs_vorlagen). MwSt = 0, kein mwst_konto:
- 30.1 'Sozialversicherung AHV (Ausgleichskasse)' soll 5700 haben 1020
- 30.2 'BVG / Pensionskasse' soll 5720 haben 1020
- 30.3 'Unfallversicherung Suva' soll 5730 haben 1020
- 30.4 'Direkte Steuern Kanton' soll 8900 haben 1020

Seed Startregeln (match_name lowercase; buchungs_vorlage_id via Subquery auf bezeichnung/geschaeftsfall_id, gleicher user_id):
| bezeichnung | match_name | Vorlage |
|---|---|---|
| Heineken Franchise | heineken | Franchisegebühr Heineken Zahlung |
| GF-Lohn Daniel | daniel proyer | Nettolohn auszahlen |
| MwSt ESTV | eidgenössische steuerverwaltung | MWST-Zahlung an Bund |
| Swisscom | swisscom | Internetabo Dauerauftrag |
| Sunrise | sunrise | Internetabo Dauerauftrag |
| AXA Sachvers. | axa versicherungen | Haftpflichtversicherung |
| AXA BVG | axa stiftung | BVG / Pensionskasse |
| Ausgleichskasse AHV | ausgleichskasse | Sozialversicherung AHV (Ausgleichskasse) |
| Suva | suva | Unfallversicherung Suva |
| Steuerverwaltung GR | steuerverwaltung kanton | Direkte Steuern Kanton |
| Bargeld-Automat | geldautomaten | Zahlungseingang bar |
| Posteinzahlung | posteinzahlung | Zahlungseingang bar |
| Bank-Abschluss | abschluss | Bankgebühren |

- [ ] Verify: `SELECT count(*) FROM camt_regel;` (13) und 4 neue Vorlagen vorhanden.
- [ ] Commit Migrationsdatei.

---

## Task 2: CamtRegel Model + Repository
**Files:** Create `lib/data/models/camt_regel.dart`, `lib/data/repositories/camt_regel_repository.dart`.
- DTO: id?, bezeichnung, matchName?, matchIban?, buchungsVorlageId, prioritaet, istAktiv. fromJson/toInsert(userId) (user_id via `SupabaseService.dataUserId`-Muster wie andere Repos).
- Repo: `getAktive()` (ist_aktiv=true, order prioritaet desc), `getAll()`, `insert(regel)`, `setAktiv(id,bool)`, `delete(id)`. Online-only.
- [ ] analyze + commit.

---

## Task 3: Regel-Matcher (TDD, reine Logik)
**Files:** Create `lib/services/camt/regel_matcher.dart`, Test `test/regel_matcher_test.dart`.

```dart
import 'package:sbs_projer_app/data/models/camt_regel.dart';

class RegelMatcher {
  /// Findet die Vorlage-ID der am besten passenden aktiven Regel, sonst null.
  /// Match: match_iban == partyIban ODER match_name als Substring in
  /// "partyName additionalInfo" (case-insensitive). Höchste prioritaet gewinnt.
  static String? matchVorlageId({
    String? partyName, String? partyIban, String? additionalInfo,
    required List<CamtRegel> regeln,
  }) {
    final text = '${partyName ?? ''} ${additionalInfo ?? ''}'.toLowerCase();
    CamtRegel? best;
    for (final r in regeln) {
      final ibanHit = r.matchIban != null && r.matchIban!.isNotEmpty && r.matchIban == partyIban;
      final nameHit = r.matchName != null && r.matchName!.isNotEmpty &&
          text.contains(r.matchName!.toLowerCase());
      if (ibanHit || nameHit) {
        if (best == null || r.prioritaet > best.prioritaet) best = r;
      }
    }
    return best?.buchungsVorlageId;
  }
}
```
Tests: name-substring hit; iban hit; no hit → null; höhere prioritaet gewinnt bei zwei Treffern.
- [ ] TDD rot→grün, commit.

---

## Task 4: Ausgabe-Booker (Buchung aus Vorlage + Transaktion)
**Files:** Create `lib/services/camt/camt_ausgabe_booker.dart`.

Erzeugt EINE Buchung aus Vorlage+Transaktion mit MwSt/Vorsteuer-Split und stempelt `camt_tx_key` direkt (robuster Dedup). Muster aus dem alten `CamtImportService._createBuchung` (MwSt-Berechnung) + Felder wie `BuchungRepository.create` erwartet.

```dart
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

class CamtAusgabeBooker {
  static Future<Buchung> book(CamtTransaction tx, BuchungsVorlage vorlage) async {
    final brutto = tx.amount;
    final satz = vorlage.mwstSatz ?? 0;
    final netto = satz > 0 ? (brutto / (1 + satz / 100) * 100).roundToDouble() / 100 : brutto;
    final mwst = (brutto - netto * 100).roundToDouble() / 100; // s. Hinweis
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;
    final beschreibung = tx.partyName != null
        ? '${tx.isCredit ? "Zahlung" : "Belastung"} ${tx.partyName}'
        : (tx.additionalInfo ?? vorlage.bezeichnung);
    return BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': tx.accountServiceRef,
      'vorlage_id': vorlage.id,
      'soll_konto': vorlage.sollKonto,
      'haben_konto': vorlage.habenKonto,
      'mwst_konto': vorlage.mwstKonto,
      'betrag_netto': netto,
      'mwst_satz': satz,
      'mwst_betrag': (brutto - netto * 100).roundToDouble() / 100,
      'betrag_brutto': brutto,
      'beschreibung': beschreibung,
      'zahlungsweg': vorlage.zahlungsweg ?? 'bank',
      'belegordner': vorlage.belegordner ?? 'bank',
      'beleg_typ': 'camt053',
      'geschaeftsjahr': tx.bookingDate.year,
      'camt_tx_key': tx.txKey,
      'notizen': [if (tx.strukturierteReferenz != null) 'Ref: ${tx.strukturierteReferenz}',
                  if (tx.partyIban != null) 'IBAN: ${tx.partyIban}'].join('\n'),
    });
  }
}
```
> Hinweis MwSt: korrekt `final mwst = brutto - netto;` (beide bereits gerundet) — der Implementer korrigiert die Beispiel-Rundung sauber; `mwst_betrag` = `((brutto - netto) * 100).roundToDouble() / 100`. Vorlage- und Buchung-Feldnamen vorher in den Models verifizieren.
- [ ] analyze + commit.

---

## Task 5: Verdrahtung in CamtAutoBooker + Import-Screen
**Files:** Modify `lib/services/camt/camt_auto_booker.dart`, `lib/presentation/screens/buchhaltung/camt_import_screen.dart`.

- `run(...)` um Parameter erweitern: `required List<CamtRegel> regeln`, `required Map<String, BuchungsVorlage> vorlagenById`.
- Branches `bargeldEinzahlung` + `ausgabe` (und ggf. `unbekannt` NUR wenn Regel-Treffer): Regel-Match versuchen:
  ```dart
  final vid = RegelMatcher.matchVorlageId(partyName: tx.partyName, partyIban: tx.partyIban,
      additionalInfo: tx.additionalInfo, regeln: regeln);
  final vorlage = vid != null ? vorlagenById[vid] : null;
  if (vorlage != null) {
    await CamtAusgabeBooker.book(tx, vorlage);
    res.gebucht++;
  } else { await _zurPruefliste(tx, kat, vorschlagBetrieb: match?['name']); res.pruefliste++; }
  ```
  (`unbekannt` bleibt ohne Regel-Lookup → Prüfliste, da es Gutschriften ohne Betriebszuordnung sind.)
- Import-Screen `_doImport`: zusätzlich `regeln = await CamtRegelRepository.getAktive()` und `vorlagenById = {for (v in await BuchungsVorlageRepository.getAll()) v.id: v}` laden und an `run` übergeben.
- [ ] analyze + `flutter test` (alle grün) + commit.

---

## Task 6: Regel-Verwaltung-UI + Dashboard-Tile + „Regel anlegen"
**Files:** Create `lib/presentation/screens/buchhaltung/camt_regeln_screen.dart`, `lib/presentation/providers/camt_regel_providers.dart`; Modify `lib/core/config/router.dart`, `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`, `lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart`.

- Provider `camtRegelnProvider` (FutureProvider → getAll()).
- `CamtRegelnScreen`: Liste aller Regeln (bezeichnung, match_name/iban, Vorlage-Bezeichnung, aktiv-Toggle, löschen). „Neue Regel"-Dialog: bezeichnung, match_name, optional match_iban, Vorlage-Dropdown (aus buchungsVorlagenProvider) → `CamtRegelRepository.insert`.
- Route `/buchhaltung/camt-regeln` (Muster wie Prüfliste-Route).
- Dashboard-Tile(s) im Buchhaltungs-Dashboard: „camt-Prüfliste" → `/buchhaltung/camt-pruefliste`, „camt-Regeln" → `/buchhaltung/camt-regeln` (Stil wie bestehende Tiles).
- Prüfliste-Screen: bei Einträgen der Kategorie ausgabe/bargeld/unbekannt Button „Regel anlegen" → öffnet den Regel-Dialog mit vorausgefülltem match_name (= parteiName).
- [ ] analyze + commit.

---

## Task 7: Verifikation
- [ ] `flutter test` (alle grün) + `flutter analyze` (0 Errors).
- [ ] DB-Check: `camt_regel` 13 Startregeln, 4 neue Vorlagen aktiv.
- [ ] Self-Review gegen Spec §4.7: Ausgaben mit Regel → gebucht; ohne Regel → Prüfliste; Bargeld/Bank-Abschluss erfasst.
