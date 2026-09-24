# Mahnwesen Teil 3 — Hinweis beim Service, bar einkassieren (v0.136.0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wer eine Reinigung, Störung oder Montage für einen Betrieb mit gemahnten Rechnungen erfasst, sieht oben ein Band (orange ab 1. Mahnung, rot bei Mahnfall mit «nur gegen Barzahlung»); antippen zeigt die offenen Rechnungen, erlaubt **bar einkassieren** (Kasse 1000) und **Rechnung mit QR zeigen** (Kunde zahlt per E-Banking-App).

**Architecture:** Reine Regel `mahnHinweis(...)` entscheidet Stufe/Text. `BarzahlungService` bucht Soll 1000 / Haben 1100 je Rechnung, setzt die Rechnung bezahlt (gegen den DB-Stand) und merkt sich den Vorher-Stand in der Buchung, damit «Barzahlung rückgängig» im Rechnungsdetail sauber zurücksetzt. Ein Widget `MahnHinweisBand(betriebId)` mit Sheet wird in die drei Formulare eingefügt.

**Tech Stack:** Flutter Web (CanvasKit), Riverpod, Supabase.

**Spec:** `docs/superpowers/specs/2026-09-23-mahnwesen-design.md` §6. **Entscheid Daniel 24.09.2026:** kein TWINT (Geschäftskonto hat keines) — vor Ort nur bar; sonst QR-Rechnung per E-Banking oder Mail. Bar → Kasse 1000.

**Allgemeine Regeln** (siehe `CLAUDE.md`): App in `sbs_projer_app/`, Flutter `export PATH="$PATH:/c/flutter/bin"`; CanvasKit: nur `GestureDetector`/`InkWell` + `Container` + `Row`/`Column`, Aktionen via `TapKnopf` (`gefahr: true` für Unumkehrbares); keine rohen Exceptions im UI (`kurzeFehlermeldung(e)`); Pagination `.order('id')`; nie `.neq()` auf nullbaren Spalten; Datum in UTC-Tagen; kein `git stash`; Commits mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Task `flutter test` grün (Stand 2115) und `flutter analyze` ≤ 56. Neue Dateien NICHT `*_form_screen.dart` nennen (Formular-Wächter).

---

### Task 1: Reine Regel `mahnHinweis`

**Files:** Create `lib/core/util/mahn_hinweis.dart`, Test `test/mahn_hinweis_test.dart`.

```dart
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

enum MahnHinweisStufe { keine, gemahnt, mahnfall }

class MahnHinweis {
  final MahnHinweisStufe stufe;
  /// Offene Rechnungen des Betriebs im Mahnbereich (ab 2026), älteste zuerst.
  final List<Rechnung> offene;
  final int anzahlGemahnt;
  final double summeOffen;
  /// Datum der frühesten 1. Mahnung unter den gemahnten Rechnungen.
  final DateTime? ersteMahnungAm;
  const MahnHinweis({required this.stufe, required this.offene,
      required this.anzahlGemahnt, required this.summeOffen, this.ersteMahnungAm});

  /// «2 Rechnungen gemahnt, CHF 188.10 offen (1. Mahnung vom 20.07.2026)»;
  /// bei Mahnfall zusätzlich « — nur gegen Barzahlung».
  String get text { /* siehe Tests */ }
}

/// [rechnungen] = alle Rechnungen des Betriebs; [imMahnfall] = Rechnung-Ids
/// in sperrenden Mahnfällen des Betriebs (sperrtRechnungen).
MahnHinweis mahnHinweis({required List<Rechnung> rechnungen, required Set<String> imMahnfall});
```

Regeln: `offene` = `imMahnbereich(r)`; gemahnt = Status `mahnung_1` oder `mahnung_2`; `stufe` = `mahnfall`, wenn eine offene Rechnung in `imMahnfall` ist, sonst `gemahnt`, wenn `anzahlGemahnt > 0`, sonst `keine`. `summeOffen` über alle `offene` (nicht nur gemahnte), gerundet auf 2 Stellen. Zahlformat mit Tausender-Apostroph wie sonst in der App (Grep nach vorhandenem CHF-Formatter, z. B. `chf(`/`NumberFormat`), Datum `dd.MM.yyyy`.

- [ ] Tests zuerst (rot): keine Mahnung → `keine`; eine `mahnung_1` → `gemahnt`, Text «1 Rechnung gemahnt, CHF 94.05 offen (1. Mahnung vom 20.07.2026)»; zwei gemahnt + eine offene → Anzahl 2, Summe aller drei; Rechnung in `imMahnfall` → `mahnfall`, Text endet mit « — nur gegen Barzahlung»; bezahlte/Altlast (2025) zählen nicht; Plural «Rechnungen».
- [ ] Implementieren, grün, `flutter test`/`analyze`, Commit `feat(mahnwesen): Regel fuer Hinweis beim Service`.

---

### Task 2: `BarzahlungService` + Rückgängig

**Files:** Create `lib/services/rechnung/barzahlung_service.dart`, Test `test/barzahlung_service_test.dart`; Modify `lib/presentation/screens/rechnungen/rechnung_detail_screen.dart`.

API:

```dart
class BarzahlungFehler implements Exception { final String meldung; BarzahlungFehler(this.meldung); @override String toString() => meldung; }

class BarzahlungService {
  static const kKasse = 1000;
  /// Je Rechnung: frisch laden; abbrechen (nichts buchen) wenn eine schon
  /// bezahlt/abgeschrieben ist oder eine Zahlung gebucht hat
  /// (`hatGebuchteZahlung` aus lib/core/util/einzel_abschreibung.dart bzw.
  /// BuchungRepository.getByBeleg). Dann je Rechnung:
  ///  Buchung Soll 1000 / Haben 1100, betrag = betragBrutto, zahlungsweg
  ///  'kasse', beleg_typ 'zahlung', beleg_id = rechnung.id, belegnummer =
  ///  rechnungsnummer, beschreibung 'Barzahlung <Nr> (vor Ort)', notizen =
  ///  jsonEncode(vorherStand(r)) (MahnlaufService.vorherStand wiederverwenden).
  ///  Danach Rechnung: zahlungsstatus 'bezahlt', zahlung_eingegangen_am =
  ///  datum, zahlung_betrag = betragBrutto — per RechnungRepository.updateWennStatus
  ///  gegen den geladenen Status; 0 Zeilen → Buchung dieser Rechnung löschen
  ///  und BarzahlungFehler('Rechnung … wurde inzwischen geändert').
  static Future<void> kassieren(List<Rechnung> rechnungen, {DateTime? datum});

  /// Aktive Barzahlungs-Buchung der Rechnung (Soll 1000, Haben 1100,
  /// beleg_id, zahlungsweg 'kasse', nicht storniert) oder null.
  static Future<Buchung?> barzahlungZu(String rechnungId);

  /// Löscht die Barzahlungs-Buchung und setzt die Rechnung auf den in
  /// `notizen` gespeicherten Vorher-Stand zurück (Fallback: 'offen', Zahlungs-
  /// felder null). Nur wenn die Rechnung noch 'bezahlt' ist.
  static Future<void> rueckgaengig(Rechnung rechnung);

  /// Rein: Vorher-Stand aus der Buchungsnotiz lesen (robust gegen null/Unsinn).
  static Map<String, dynamic>? vorherAusNotiz(String? notizen);
}
```

- [ ] Tests (rein): `vorherAusNotiz` mit gültigem JSON, null, kaputtem Text; Entscheidfunktion `darfKassieren(Rechnung r, {required bool hatZahlung})` (false bei bezahlt/abgeschrieben/hatZahlung/`zahlungEingegangenAm != null`).
- [ ] Implementieren. Datum: heute als UTC-Tag.
- [ ] Rechnungsdetail: Gibt es eine Barzahlung (`barzahlungZu`), Zeile «Bar bezahlt am …» und `TapKnopf(text: 'Barzahlung rückgängig', gefahr: true)` mit Bestätigungsdialog (Dialog-Knöpfe `TapKnopf`), danach neu laden.
- [ ] `flutter test`/`analyze`, Commit `feat(rechnungen): Barzahlung vor Ort mit Rueckgaengig`.

---

### Task 3: Band + Sheet, in drei Formulare

**Files:** Create `lib/presentation/widgets/mahn_hinweis_band.dart`, `lib/presentation/providers/mahn_hinweis_provider.dart`; Modify `reinigung_form_screen.dart` (nach `_saisonBand()`, ~Z. 1776), `stoerung_form_screen.dart` (unter `_buildBetriebField()`, ~Z. 797), `montage_form_screen.dart` (unter `_buildBetriebField()`, ~Z. 945; nicht wenn `_betriebDisabled`); `test/canvaskit_sichere_widgets_test.dart` (Band-Datei aufnehmen).

- [ ] Provider `mahnHinweisProvider = FutureProvider.autoDispose.family<MahnHinweis, String>(betriebId)`: Rechnungen des Betriebs ab `kMahnStart` (gezielte Abfrage `RechnungRepository` nach betrieb_id + rechnungsdatum >= 2026-01-01, `.order('rechnungsdatum').order('id')`, seitenweise wie `getKundenrechnungenAb`) + `MahnfallRepository.getSperrendeFaelle()` gefiltert auf den Betrieb → `mahnHinweis(...)`. Fehler → `keine` (Band ist nur Hinweis, darf das Formular nie blockieren).
- [ ] Widget `MahnHinweisBand({required String? betriebId})`: bei null/`keine`/Laden → `SizedBox.shrink()`. Sonst Band wie `_saisonBand()` (InkWell → Container, Radius 8, `AppColors.warning` bzw. `AppColors.error` mit `withAlpha(30)`/Rahmen `withAlpha(100)`, Icon, `Expanded(Text(hinweis.text))`, `chevron_right`). Tap → `showModalBottomSheet` (Muster `saison_abmachung_sheet.dart`):
  - Titel «Offene Rechnungen», je Rechnung Zeile (Nummer, Datum, Status-Text, Betrag) mit Häkchen (Standard: alle an) als `GestureDetector`, und je Zeile Link «QR zeigen» → Signed URL des Rechnungs-PDFs (`RechnungPdfStorage.getSignedUrl(r.id)`) im neuen Tab öffnen (Muster im Rechnungsdetail suchen).
  - Total der angehakten.
  - `TapKnopf(text: 'Bar einkassieren — CHF <Total>', primaer: true)` → Bestätigungsdialog «CHF … bar erhalten?» → `BarzahlungService.kassieren(...)` → Snackbar «Bar verbucht (Kasse)»; danach `ref.invalidate(mahnHinweisProvider(betriebId))`. Stecken Rechnungen in einem Mahnfall und sind danach alle bezahlt: Hinweis «Mahnfall abschliessen» mit Link `/rechnungen/mahnfall/<id>`.
  - Fehler als `kurzeFehlermeldung(e)`.
- [ ] In die drei Formulare einfügen (Störung/Montage: reagiert auf `_betriebId`-Wechsel, weil der Provider per family neu lädt).
- [ ] Widget-Test `test/mahn_hinweis_band_test.dart`: überschriebener Provider mit `gemahnt` → Text sichtbar; `keine` → nichts gerendert.
- [ ] `flutter test`/`analyze`, Web-Build `--base-href "/" --pwa-strategy=none`, Commit `feat(mahnwesen): Hinweis beim Service mit bar einkassieren`.

---

### Task 4: Release v0.136.0 (Controller)

- [ ] Review (Opus) über Tasks 1–3, Nachbesserung.
- [ ] Browser 360 px: Test-Rechnung eines Betriebs per SQL auf `mahnung_1` setzen (Vorher notieren), neue Reinigung für den Betrieb öffnen → oranges Band, Sheet, «QR zeigen». Einkassieren mit einer Test-Rechnung durchspielen, Buchung 1000/1100 in der DB prüfen, «Barzahlung rückgängig» → Buchung weg, Rechnung zurück auf Vorher-Stand; Test-Stand zurücksetzen.
- [ ] Version 0.136.0+789, Doku (Chronik, ToDo-Klicktest, Projekt.md), Commit, Push, Deploy, Live-Version prüfen.
