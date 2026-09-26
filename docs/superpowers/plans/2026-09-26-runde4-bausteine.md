# Analyse-Runde 4 «Bausteine & Aufräumen» — v0.143.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Weniger Code und weniger Kopien, ohne Verhaltensänderung: toter Code weg, `flutter analyze` von 56 auf ≤ 16, zentrale `Zahlungsstatus`-Konstante mit Wächter gegen den DB-CHECK, CanvasKit-Wächter über alle Screens, eine Datumsauswahl `zeigeDatumsauswahl()`, gemeinsame Detail-Bausteine (`DetailKarte`/`InfoZeile`), gemeinsame Formular-Bausteine (`BetriebFeld`, `ArbeitszeitBlock`, `MaterialSlots`), MwSt ohne statischen Zustand, eine 5-Rappen-Rundung, Firmendaten (inkl. IBAN) aus einer Quelle.

**Architektur:** Rein mechanische Tasks (1–6) gehen an Sonnet-Implementer, je mit Wächter-Test, der den neuen Zustand festhält. Tasks mit Urteil (7 Formular-Bausteine, 8 Geld/MwSt/Firmendaten) an Opus. Jeder Task ist verhaltensneutral; wo er es nicht ist (Task 8: MwSt-Satz pro Aufruf), steht es ausdrücklich im Task.

**Quelle:** `docs/app-analyse-2026-09-25.md` §3 (Formular-Bausteine, Firmendaten/IBAN/MwSt/Rundung, Toter Code), §5 Q2/Q4/Q7; Einzelberichte `docs/analyse-2026-09-25/1-screens-navigation.md` §2 und §4 Nr. 6–10, `2-datenschicht-toter-code.md` §1 D6–D8 und §2, `5-qualitaet-backend.md` §1 und §2. **Achtung:** Die Berichte sind vom 25.09. (v0.138); Runden 1–3 haben einiges schon entfernt (z. B. `CamtAutoBooker.run`, `ZahlungsdifferenzService.verbuchen`, Debitoren-Header) oder neu benutzt (`BetriebFerienRepository.getFuerBetrieb/loeschen`). **Jeder Löschkandidat wird vor dem Löschen per grep erneut belegt.**

**Nicht in dieser Runde:** Isar-Zweig einfrieren (Konflikt mit der Regel «nativen Isar/Sync-Pfad weiter pflegen — Vorlage für die Android-App»; offene Frage an Daniel), `dart:html` → `package:web`, `initialValue`-Umstellung (braucht Sichtprüfung je Dropdown), `abgleich_vorschau.dart` aufteilen, Events archivieren, Mail-Service (D2).

**Regeln:** `CLAUDE.md` (CanvasKit: `TapKnopf`/`gefahrRueckfrage`; `pdfDokument()`; NULL-Falle), App `sbs_projer_app/`, `export PATH="$PATH:/c/flutter/bin"`, kein `git stash`, Commits enden mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Task `flutter test` komplett grün (Stand 2375) und `flutter analyze` ≤ Vor-Stand (ab Task 2: ≤ 16). **Kein `dart format` über ganze Dateien** (reformatiert fremde Zeilen und erzeugt neue Infos) — nur gezielte Änderungen.

---

### Task 1: Toten Code löschen (Sonnet)

**Files:** Kandidaten aus `docs/analyse-2026-09-25/2-datenschicht-toter-code.md` §2a–2e und `1-screens-navigation.md` §1.6.

- [ ] **Schritt 1: Belegen.** Für jeden Kandidaten: `grep -rn "<Name>" lib test` (Dateien: Importpfad bzw. Klassenname; Methoden: `.<methode>(`; Provider: Providername). Nur löschen, was in `lib/` keinen Aufrufer ausser der eigenen Definition hat. Treffer nur in `test/` → Test mitlöschen, wenn er ausschliesslich das Tote prüft. Ergebnis als Liste im Commit-Text.
  - **Ganze Dateien (2a):** `services/pdf/reinigung_pdf_service.dart`, `services/pdf/reinigung_pdf_storage.dart`, `services/camt/camt_import_service.dart`, `services/pdf/bankbeleg_pdf_service.dart`, `presentation/widgets/system_diagram/` (ganzer Ordner), `presentation/screens/betriebe/betrieb_kontakt_form_screen.dart`, `presentation/screens/materialien/bestellliste_screen.dart`, `presentation/providers/auth_provider.dart`, `data/models/formular.dart`, `data/models/user_profile.dart`, `presentation/widgets/filter/app_filter_sheet.dart`, `presentation/widgets/filter/app_active_filters.dart` (+ `test/widgets/app_filter_widgets_test.dart`, soweit nur dafür), `presentation/providers/kachel_zaehler_providers.dart` (+ `test/kachel_zaehler_test.dart`; `kommenderSonntag` vorher prüfen — ist er irgendwo in `lib` benutzt, in eine passende Util-Datei verschieben statt löschen).
  - **Funktionen (2b)**, soweit noch vorhanden: `tourVorschlagErweitertProvider`, `faelligeAnlagenCountProvider`, `tagesplanLoeschen()` (tour_providers), `HeinekenPdfService.generate`, `generateAnfahrtspauschale`, `CamtBetriebMatcher.matchAll`, `BuchungService.getKontoSaldo`, `RechnungService.brauchtRechnung`, `MwstSatzService.reduzierterSatzFuerDatum` (nur wenn weiterhin ohne Aufrufer), `getMahnfallSignedUrl`, `ProtokollFotoStorage.deleteFoto`, `pdf_schrift.zuruecksetzen`, `ConnectivityService.dispose`, `BarzahlungService.darfKassieren` (+ Test).
  - **Repository-Methoden (2c):** die 29 der Liste, je einzeln belegt (viele `count()`).
  - **Provider (2d):** die 45 der Liste, je einzeln belegt.
  - **pubspec (2e):** `riverpod_annotation`, `riverpod_generator` entfernen, wenn kein `@riverpod`/`part '*.g.dart'` mit riverpod existiert (`grep -rn "@riverpod\|riverpod_annotation" lib`); danach `flutter pub get`.
  - **Router:** Gast-Redirects in `lib/core/config/router.dart` (~Z. 327–371), die auf `/eigenauftraege` bzw. `/eroeffnungsreinigungen` zeigen, auf `/einsaetze` biegen (Routen gibt es seit v0.106 nicht mehr).
- [ ] **Schritt 2:** löschen, `flutter pub get`, `flutter analyze` (darf nicht steigen; ungenutzte Imports, die dadurch entstehen, mit entfernen), `flutter test`.
- [ ] **Schritt 3: Commit** `chore: toten Code entfernt (Analyse 25.09. §2) — <n> Dateien, <m> Funktionen/Provider/Methoden`.

---

### Task 2: `flutter analyze` 56 → ≤ 16 (Sonnet)

**Files:** `sbs_projer_app/analysis_options.yaml`, die in `5-qualitaet-backend.md` §2 genannten Dateien.

- [ ] `analysis_options.yaml`: unter `analyzer:` `exclude: ["**/*.g.dart"]` (12 Isar-Infos weg).
- [ ] `curly_braces_in_flow_control_structures`: **nur** diese Regel automatisch: `dart fix --apply --code=curly_braces_in_flow_control_structures` (kein `dart format`).
- [ ] `use_build_context_synchronously` (18): je Stelle `if (!context.mounted) return;` mit **demselben** Kontext, der danach benutzt wird (in `State`-Klassen `mounted` nur, wenn danach `this.context` benutzt wird; nach einem Dialog-`ctx` den Screen-Kontext prüfen). Stellen: stoerung_detail, montage_detail, eigenauftrag_detail, bergkundenpauschale_detail, app.dart.
- [ ] `unintended_html_in_doc_comment` / `dangling_library_doc_comments` (3): Backticks bzw. `library;`.
- [ ] Nicht anfassen: 6× `initialValue`, 8× `dart:html` (eigener Punkt, Sichtprüfung).
- [ ] Wächter `test/analyze_ratsche_test.dart`: *kein* Analyzer-Aufruf im Test (zu langsam) — stattdessen im Commit die neue Zahl nennen; die Regel «≤ Vor-Stand» gilt für alle weiteren Tasks.
- [ ] `flutter analyze` (Ziel ≤ 16), `flutter test`. **Commit** `chore: analyze 56 → <n> (g.dart ausgeschlossen, context.mounted, curly braces, Doc-Kommentare)`.

---

### Task 3: `Zahlungsstatus`-Konstante und Wächter gegen den DB-CHECK (Sonnet)

**Files:** Create `lib/core/util/zahlungsstatus.dart`, `test/zahlungsstatus_waechter_test.dart`.

- [ ] `lib/core/util/zahlungsstatus.dart`:
```dart
/// Erlaubte Werte von `rechnungen.zahlungsstatus` — dieselbe Liste wie der
/// CHECK der letzten Migration, die ihn setzt (083, siehe Wächter). Früher
/// benutzte Werte (entwurf, versendet, gestellt, teilbezahlt, ueberfaellig,
/// storniert) werfen seit 081–083 eine PostgrestException.
abstract final class Zahlungsstatus {
  static const offen = 'offen';
  static const gesendet = 'gesendet';
  static const freigegeben = 'freigegeben';
  static const bezahlt = 'bezahlt';
  static const erinnert = 'erinnert';
  static const mahnung1 = 'mahnung_1';
  static const mahnung2 = 'mahnung_2';
  static const abgeschrieben = 'abgeschrieben';
  static const alle = {offen, gesendet, freigegeben, bezahlt, erinnert, mahnung1, mahnung2, abgeschrieben};
  static const erledigt = {bezahlt, abgeschrieben};
  static const gemahnt = {erinnert, mahnung1, mahnung2};
  static const altwerte = {'entwurf', 'versendet', 'gestellt', 'teilbezahlt', 'ueberfaellig', 'storniert'};
}
```
- [ ] Wächter `test/zahlungsstatus_waechter_test.dart`: (a) liest alle `Datenbank/migrations/*.sql` (Pfad relativ `../Datenbank/migrations`), sucht den **zuletzt** (nach Dateiname sortiert) gesetzten CHECK auf `zahlungsstatus` (Regex auf `zahlungsstatus\s+IN\s*\(([^)]*)\)` in einem `CHECK`), parst die Werte und vergleicht mit `Zahlungsstatus.alle`; (b) kein Dart-File in `lib/` enthält ein Altwert-Literal im Rechnungskontext: Treffer `'versendet'|'gestellt'|'teilbezahlt'|'ueberfaellig'` (Wort in Anführungszeichen) sind verboten, **ausser** in `zahlungsstatus.dart` selbst und in Dateien einer Ausnahmeliste (vorher grep: z. B. `'storniert'` ist bei Buchungen/anderen Tabellen legitim — deshalb `storniert` und `entwurf` nicht global verbieten, nur prüfen, dass `'zahlungsstatus': '<altwert>'` nirgends steht).
- [ ] Bestehende Helfer (`rechnung_status.dart`: `istZahlbar`, `statusNachVersand`; `offene_pro_betrieb.dart` `kErledigteStatus`) auf die Konstanten umstellen (nur diese zwei Dateien; das Ersetzen aller ~300 Literale ist **nicht** Teil des Tasks).
- [ ] Tests, analyze. **Commit** `feat(rechnungen): Zahlungsstatus-Konstante + Waechter gegen den DB-CHECK (Q4)`.

---

### Task 4: CanvasKit-Wächter v2 und Migrationsnummern-Wächter (Sonnet)

**Files:** `test/canvaskit_sichere_widgets_test.dart` (ergänzen), Create `test/canvaskit_ratsche_test.dart`, `test/migrationsnummern_waechter_test.dart`.

- [ ] `canvaskit_ratsche_test.dart`: zählt in `lib/**/*.dart` (ohne `events/`) Vorkommen von `FilledButton` und `OutlinedButton` (Regex `\b(FilledButton|OutlinedButton)(\.icon|\.tonal|\.tonalIcon)?\(`); Erwartung `<= <heutige Zahl>` (Zahl beim Schreiben ermitteln und als Konstante mit Datum eintragen, Kommentar: «Ratsche — darf nur sinken; neue Knöpfe sind TapKnopf»). Zusätzlich: innerhalb eines `actions: [`-Blocks einer `AppBar(` darf kein Filled/Outlined stehen (einfacher Heuristik-Parser: ab `AppBar(` bis zur schliessenden Klammer der `actions`-Liste; Vorfall 13.08.2026 Lageplan-Speichern).
- [ ] `migrationsnummern_waechter_test.dart`: Dateinamen in `../Datenbank/migrations` → Nummer + optionaler Buchstabe; bekannte Doppel `083`, `091`, `092` und Lücken `008`, `009` als Ausnahme-Konstanten (Kommentar: auf dem Server so geführt, nicht umbenennen); jede andere doppelte Nummer ohne Suffix oder neue Lücke → Fehler.
- [ ] Tests grün. **Commit** `test: CanvasKit-Ratsche ueber alle Screens, AppBar-Knoepfe, Migrationsnummern (Q2)`.

---

### Task 5: `zeigeDatumsauswahl()` und `DatumFeld` (Sonnet)

**Files:** Create `lib/presentation/widgets/datum_auswahl.dart`, `test/datumsauswahl_waechter_test.dart`; Modify alle Dateien mit `showDatePicker(` (29 Aufrufe in 27 Dateien) und die privaten `_DatePickerField`/`_DatumFeld` (`betrieb_form_screen.dart`, `event_form*`, `saison_nachtrag_screen.dart`, `war_geschlossen_sheet.dart`).

- [ ] `datum_auswahl.dart` (Muster `zeit_auswahl.dart`):
```dart
import 'package:flutter/material.dart';

/// EINE Datumsauswahl für die ganze App (Runde 4). Deutsch, Montag als
/// Wochenbeginn (Locale de_CH aus der App), Bereich standardmässig
/// 2019 … heute + 2 Jahre. Wächter: test/datumsauswahl_waechter_test.dart.
Future<DateTime?> zeigeDatumsauswahl(
  BuildContext context, {
  required DateTime initial,
  DateTime? erstes,
  DateTime? letztes,
  String? hilfetext,
}) {
  final first = erstes ?? DateTime(2019);
  final last = letztes ?? DateTime.now().add(const Duration(days: 730));
  var init = initial;
  if (init.isBefore(first)) init = first;
  if (init.isAfter(last)) init = last;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first,
    lastDate: last,
    helpText: hilfetext,
  );
}

/// Anzeige- und Auswahlfeld für ein Datum (ersetzt die privaten
/// _DatePickerField/_DatumFeld-Kopien). InkWell + InputDecorator —
/// CanvasKit-sicher.
class DatumFeld extends StatelessWidget {
  final String label;
  final DateTime? wert;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? erstes;
  final DateTime? letztes;
  final bool loeschbar;
  const DatumFeld({super.key, required this.label, required this.wert, required this.onChanged,
      this.erstes, this.letztes, this.loeschbar = true});

  static String text(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await zeigeDatumsauswahl(context,
            initial: wert ?? DateTime.now(), erstes: erstes, letztes: letztes);
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: loeschbar && wert != null
              ? InkWell(onTap: () => onChanged(null), child: const Icon(Icons.clear, size: 18))
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(text(wert)),
      ),
    );
  }
}
```
- [ ] Jeden `showDatePicker(`-Aufruf durch `zeigeDatumsauswahl(context, initial: …, erstes: <bisheriges firstDate>, letztes: <bisheriges lastDate>)` ersetzen — **bisherige Grenzen 1:1 übernehmen** (keine Verhaltensänderung). Die privaten Feld-Klassen durch `DatumFeld` ersetzen, wenn ihr Verhalten gleich ist (Label, Wert, Löschen); weichen sie ab, als Parameter abbilden oder die private Klasse behalten und im Commit nennen.
- [ ] Wächter `test/datumsauswahl_waechter_test.dart`: `showDatePicker(` kommt in `lib/` nur in `datum_auswahl.dart` vor (Muster `zeitauswahl_waechter_test.dart` lesen und nachbauen).
- [ ] Tests, analyze. **Commit** `refactor(ui): eine Datumsauswahl zeigeDatumsauswahl/DatumFeld + Waechter`.

---

### Task 6: Detail-Bausteine `DetailKarte` / `InfoZeile` (Sonnet)

**Files:** Create `lib/presentation/widgets/detail/detail_karte.dart`, `test/detail_bausteine_waechter_test.dart`; Modify die 11 Dateien mit `class _SectionCard` und 13 mit `class _InfoRow` (`grep -rln "class _SectionCard\|class _InfoRow" lib`).

- [ ] `detail_karte.dart`: `DetailKarte({required String titel, required IconData icon, required List<Widget> kinder, Widget? aktion})` und `InfoZeile(String label, String wert, {double labelBreite = 130})` — **Code 1:1 aus `anlage_detail_screen.dart:1293–1370`** übernehmen (leere `kinder` → `SizedBox.shrink`, leeres Label → nur Wert), dazu optional `aktion` rechts im Kopf. Vorher per `diff` prüfen, ob die 11/13 Kopien wirklich textgleich sind (Bericht: diff = 0); Abweichende (z. B. andere Labelbreite, Aktion im Kopf, `onTap`) über Parameter abbilden oder private Klasse behalten und im Commit nennen.
- [ ] In allen Dateien `_SectionCard(title:, icon:, children:)` → `DetailKarte(titel:, icon:, kinder:)`, `_InfoRow(a, b)` → `InfoZeile(a, b)`, private Klassen löschen.
- [ ] Wächter: `class _SectionCard` und `class _InfoRow` kommen in `lib/` nicht mehr vor (Ausnahmen namentlich, falls in Schritt 1 begründet).
- [ ] Tests, analyze. **Commit** `refactor(ui): DetailKarte/InfoZeile statt 11+13 Kopien`.

---

### Task 7: Formular-Bausteine `BetriebFeld`, `ArbeitszeitBlock`, `MaterialSlots` (Opus)

**Files:** Create `lib/presentation/widgets/einsatz/betrieb_feld.dart`, `…/arbeitszeit_block.dart`, `…/material_slots.dart`; Modify `stoerung_form_screen.dart` (~Z. 1193 Betriebfeld, Arbeitszeit-Methoden `_arbeitBeginnen/_arbeitBeenden/_ensureLaufendZeitTimer/_buildArbeitBeginnBlock/_buildArbeitZeitfelder`, `_buildMaterialSlots` ~Z. 1025), `montage_form_screen.dart` (~Z. 1796, ~Z. 1669), `eigenauftrag_form_screen.dart` (~Z. 286, 3 Material-Slots), `eroeffnungsreinigung_form_screen.dart` (~Z. 242), `kontakt_form_screen.dart` (~Z. 187). Zeilen vorher per grep bestätigen.

- [ ] **Schritt 1: Lesen und vergleichen.** Die 5 Betriebfeld-Kopien, die 2 Arbeitszeit-Blöcke (Diff ~24 Zeilen) und die 3 Material-Slot-Varianten (Diff ~16 Zeilen auf ~140) nebeneinanderlegen und die Unterschiede als Parameter festhalten (z. B. `nurMeineKunden`, Anzahl Slots, Lager-Autocomplete an/aus, Zeitfelder editierbar, GPS-Stempel). Suchregel bleibt `betriebPasst()` (A9).
- [ ] **Schritt 2: Tests zuerst** — reine Helfer, die beim Herauslösen entstehen (z. B. Filterung der Betriebe, Slot-Validierung, Dauer-Berechnung), in `test/einsatz_bausteine_test.dart`; Wächter `test/einsatz_bausteine_waechter_test.dart`: die fünf Formulare enthalten `BetriebFeld(`, Störung/Montage `ArbeitszeitBlock(`, Störung/Montage/Eigenauftrag `MaterialSlots(`; die alten privaten Methoden (`_buildMaterialSlots`, `_buildArbeitBeginnBlock`, `_buildArbeitZeitfelder`) existieren nicht mehr.
- [ ] **Schritt 3: Bausteine bauen** als `StatefulWidget`s mit Controller-/Callback-API (State bleibt im Formular, Baustein meldet Änderungen per Callback und ruft `markiereGeaendert` über einen `onGeaendert`-Callback — **UngespeichertSchutz darf nicht brechen**). CanvasKit: Knöpfe `TapKnopf`/`ArbeitBeendenKnopf`, keine Material-Buttons; Zeitauswahl über `zeigeZeitauswahl`.
- [ ] **Schritt 4: einbauen**, Formular für Formular, nach jedem Formular `flutter test`.
- [ ] **Verhaltensneutral:** gleiche Felder, gleiche Validierung, gleiche Speicherdaten. Kein Umbau der Speicherlogik (`_save`).
- [ ] analyze, Tests. **Commit** `refactor(einsaetze): BetriebFeld, ArbeitszeitBlock, MaterialSlots statt Kopien`.

---

### Task 8: MwSt ohne statischen Zustand, eine Rundung, Firmendaten aus einer Quelle (Opus)

**Files:** `lib/services/rechnung/rechnung_service.dart` (`_mwstFaktor` Z. 23–52, 146), `lib/services/rechnung/jahresrechnung_service.dart` (Z. 24–42, 150, 168), `lib/services/buchhaltung/reinigung_buchung_service.dart` (Z. 42–83, 133), Hartwerte `8.1`/`0.081` (grep: `reinigung_form_screen.dart`, `heineken_buchung_service.dart`, `jahresrechnung_generate_screen.dart`, `heineken_monats_daten.dart`); Rundung: `core/util/beleg_korrektur.dart:4` `runde5Rappen` + private Kopien (`jahresrechnung_generate_screen.dart:32`, `montage_form_screen.dart:612`, `reinigung_detail_screen.dart:239`, `reinigung_form_screen.dart:1394`, `reinigung_buchung_service.dart:45`, `mahnschreiben_pdf_service.dart:46`, `rechnung_detail_screen.dart`, `rechnungen_list_screen.dart`); Firmendaten: `heineken_pdf_service.dart:17–25`, `kontoauszug_pdf_service.dart:50/444/447/475`, `qr_zahlteil.dart:21–22`, `rechnung_detail_screen.dart:479`, `bericht_pdf_common.dart:8`, `bestellung_pdf_service.dart:17/19`, `mahnschreiben_pdf_service.dart:375/393`, `rechnung_pdf_service.dart:152/176`; Quelle `lib/data/models/geschaeft_einstellungen.dart`.

- [ ] **MwSt (Verhaltensänderung, bewusst):** statische `_mwstFaktor`-Felder entfernen; der Satz wird **pro Aufruf** ermittelt und als Parameter durchgereicht (`final faktor = await _mwstFaktorFuer(datum)` aus der Preisliste `PreisRepository.getAktuell(datum:)` wie bisher, Fallback 0.081 nur an **einer** Stelle als benannte Konstante `kMwstFaktorFallback`). Reine Funktionen (`_nettoAusBrutto(brutto, faktor)` usw.) bekommen den Faktor als Argument → testbar. Test: zwei Reinigungen mit Datum 2023 (7.7 %) und 2024 (8.1 %) im selben Lauf ergeben je den richtigen Satz (Preisliste über einen injizierbaren Loader oder reine Funktion testen). Hartwerte in Screens (`8.1`, `0.081`) durch den Satz aus Preisliste/`MwstSatzService.satzFuerDatum` ersetzen; wo ein Screen nur **anzeigt**, reicht der Satz aus der geladenen Preisliste.
- [ ] **Rundung:** alle Kopien auf `rundeAuf5Rappen` (`core/util/rundung.dart`); `runde5Rappen` aus `beleg_korrektur.dart` löschen und Aufrufer (`spesen_scanner_screen.dart`, `beleg_korrektur.dart`) umstellen. Wächter `test/rundung_waechter_test.dart`: kein `* 20).roundToDouble() / 20` ausser in `rundung.dart`.
- [ ] **Firmendaten:** `GeschaeftEinstellungen` bekommt `kIban = 'CH66 0077 4010 3765 5060 1'` (Fallback) und Getter `ibanFormatiert`/`ibanKompakt` (aus `firmenIban` oder Fallback; kompakt = ohne Leerzeichen). Alle PDF-Services und der QR-Zahlteil lesen IBAN, Adresse, Telefon, MWST-Nr. über ein geladenes `GeschaeftEinstellungen` (Muster der Services, die es schon tun — grep `GeschaeftEinstellungen` in `services/pdf`); wo ein Service heute synchron baut, das Objekt als Parameter übergeben. **Wert der IBAN nicht ändern.** Wächter `test/firmendaten_waechter_test.dart`: `CH66 0077` / `CH6600774010376550601` / `Via Rezia` / `076 566 58 06` kommen in `lib/` nur in `geschaeft_einstellungen.dart` vor.
- [ ] **PDF-Gegenprobe:** Test, der für eine Beispielrechnung die Texte des QR-Zahlteils (IBAN, Empfänger) aus `qr_zahlteil.dart` erzeugt und mit dem Fallback vergleicht (Snapshot der Strings, nicht des PDFs).
- [ ] Tests, analyze. **Commit** `refactor(buchhaltung): MwSt pro Aufruf statt statisch, eine 5-Rappen-Rundung, Firmendaten/IBAN aus GeschaeftEinstellungen`.

---

### Task 9: Browser-Prüfung, Release v0.143.0 (Controller)

- [ ] Lokaler Build `--base-href "/"`, Server `flutter-web`. Prüfen (nur ansehen, nichts speichern ausser wo reversibel): Störung-Formular neu (Betriebsfeld, Arbeitszeit-Block, Material-Slots), Montage-Formular, Eigenauftrag-Formular, eine Detailseite (Anlage, Störung — Karten/Zeilen), ein Datumsfeld (Betrieb bearbeiten → Saison), Rechnungsdetail (IBAN-Zeile), Rechnungs-PDF öffnen (QR-Zahlteil, Fuss), Kontoauszug-PDF (Betrieb → Rechnungen pro Betrieb). Bei 360 px die Formulare einmal durchscrollen. Screenshots ins Scratchpad.
- [ ] Version `0.143.0+796`; Chronik, ToDo (Stand, Klicktest, offene Punkte: Isar-Entscheid, `dart:html`, `initialValue`), Projekt.md, Analyse §6 Runde 4 ✅, Memory.
- [ ] Commit, Push, Deploy gh-pages, Live-Version prüfen.

---

## Reihenfolge und Parallelität (Controller)

1 → 2 (beide ändern viele Dateien, nacheinander) → 3 ∥ 4 (neue Dateien/Tests, disjunkt) → 5 → 6 → Review (1–6) → 7 → 8 → Review (7–8) → 9.

## Selbstprüfung

- Abdeckung §6 Runde 4: Formular-Bausteine (7), `zeigeDatumsauswahl` (5), Detail-Gerüst (6), toter Code (1), Firmendaten/MwSt/Rundung (8), Q2 (4), Q4 (3), Q7 (2). Isar einfrieren bewusst ausgelassen (Begründung oben).
- Namen: `Zahlungsstatus.*`, `zeigeDatumsauswahl`, `DatumFeld`, `DetailKarte`, `InfoZeile`, `BetriebFeld`, `ArbeitszeitBlock`, `MaterialSlots`, `kMwstFaktorFallback`, `GeschaeftEinstellungen.kIban/ibanFormatiert/ibanKompakt`.
- Risiken: `dart format`-Nebenwirkungen (verboten); UngespeichertSchutz bei Task 7; MwSt-Umstellung ändert das Verhalten nur, wo bisher der statische Wert eines früheren Aufrufs galt (gewollt).
