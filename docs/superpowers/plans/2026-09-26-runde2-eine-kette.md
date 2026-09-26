# Analyse-Runde 2 «Eine Kette» — v0.140.0 + v0.141.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Die Reinigungs-Abschlusskette (Rechnung → Versand → Buchung → Nachholen → Pauschale) existiert genau **einmal** als Service, den Formular und Detail-Screen gemeinsam aufrufen; das Bearbeiten einer abgeschlossenen Reinigung löscht nie mehr blind Rechnung und Buchungen (R1); das Protokollfoto wird sofort hochgeladen und ein Fehler ist sichtbar (T1); die Pausen-Prüfung läuft erst nach der Kette (T5); das Formular ist entrümpelt und CanvasKit-sicher (T6); Betriebsferien werden im Formular, im Detail und im Heineken-Raster aus `betrieb_ferien` gelesen und gepflegt (R7).

**Architektur:** Neuer `ReinigungAbschlussService.abschliessen(r, betrieb)` (services/rechnung) bündelt, was heute in `_save` (820 Zeilen) und `ReinigungRechnungVersand.erstelleUndSende` doppelt liegt; er gibt ein `AbschlussErgebnis` mit Meldungen zurück, das Formular zeigt sie nur noch an. Korrekturen laufen über eine reine Sperr-Regel (`korrekturSperre`) plus Storno statt Löschen. Ferien bekommen ein wiederverwendbares Widget `BetriebFerienListe` auf dem bestehenden `BetriebFerienRepository`. Zwei Auslieferungen: **v0.140.0** (Tasks 1–6, Kette) und **v0.141.0** (Task 7, Ferien).

**Befunde:** `docs/app-analyse-2026-09-25.md` §2 R1/R7, §3 Zeile 1, §4 T1/T5/T6. Erkundung 26.09.2026: `_save` Schritte 1–16 (Reihenfolge heute: Speichern → Fahrzeit → Pausen-Prüfung → Korrektur → HeiGenie → Kulanz → Rechnung/Mail → Buchung → Nachholen → Pauschale); Korrektur-Service löscht hart (`deleteByBeleg`, `RechnungRepository.delete`) ohne jede Prüfung; Foto-Fehler nur `debugPrint`; Heineken-Raster liest entgegen der Analyse **noch die Altspalten** (`BetriebRepository.getAll()` statt `betriebeProvider`); es gibt kein UI zum Pflegen von `betrieb_ferien` ausser dem «War geschlossen»-Sheet.

**Regeln:** `CLAUDE.md` (CanvasKit: kritische Knöpfe nur `TapKnopf`/`gefahrRueckfrage`; Pagination `.order('id')`; NULL-Falle: kein `.neq()` auf nullbaren Spalten; `pdfDokument()`), App-Ordner `sbs_projer_app/`, Flutter `export PATH="$PATH:/c/flutter/bin"`, kein `git stash`, Commits enden mit `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Nach jedem Task `flutter test` grün (Stand 2301) und `flutter analyze` ≤ 56 Issues. Mahnwesen bleibt im Testmodus (nicht anfassen). Keine Migration nötig.

**Nicht in dieser Runde:** Storno + Neuausstellung einer versendeten Rechnung (gehört zu ZahlungKern, Runde 3); Entwurf-Sicherung der laufenden Reinigung (T2); Entfernen der Altspalten `ferien*_start/ende` aus Model/DB (Folgemigration nach Runde 2, siehe Task 7 Schritt 8).

---

### Task 1: Sperr-Regel und Vergleich «preisrelevant geändert» (rein, R1)

**Files:**
- Create: `sbs_projer_app/lib/core/util/reinigung_korrektur_regel.dart`
- Test: `sbs_projer_app/test/reinigung_korrektur_regel_test.dart`

- [ ] **Schritt 1: Test schreiben** (`test/reinigung_korrektur_regel_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/reinigung_korrektur_regel.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _rg({
  String status = 'offen',
  DateTime? versendetAm,
  DateTime? uebergebenAm,
  DateTime? zahlungEingegangenAm,
  int mahnungStufe = 0,
  DateTime? rechnungsdatum,
}) =>
    Rechnung.fromJson({
      'id': 'r1',
      'user_id': 'u',
      'rechnungsnummer': '2026-09-26-0001',
      'rechnungstyp': 'kundenrechnung',
      'rechnungsdatum':
          (rechnungsdatum ?? DateTime(2026, 9, 26)).toIso8601String(),
      'faelligkeitsdatum': DateTime(2026, 10, 26).toIso8601String(),
      'betrag_netto': 100,
      'mwst_betrag': 8.1,
      'betrag_brutto': 108.1,
      'zahlungsstatus': status,
      'versendet_am': versendetAm?.toIso8601String(),
      'uebergeben_am': uebergebenAm?.toIso8601String(),
      'zahlung_eingegangen_am': zahlungEingegangenAm?.toIso8601String(),
      'mahnung_stufe': mahnungStufe,
    });

ReinigungLocal _rein({
  double? grundtarif = 100,
  int eigen = 0,
  String? serviceTyp = 'konventionell',
  String? zahlungsart = 'rechnung_mail',
  bool kulanz = false,
  String notizen = '',
}) => ReinigungLocal()
  ..datum = DateTime(2026, 9, 26)
  ..preisGrundtarif = grundtarif
  ..anzahlHaehneEigen = eigen
  ..serviceTyp = serviceTyp
  ..zahlungsart = zahlungsart
  ..istKulanz = kulanz
  ..notizen = notizen;

void main() {
  final grenze = DateTime(2026, 1, 1);

  group('korrekturSperre', () {
    test('keine Rechnung -> keine Sperre', () {
      expect(
        korrekturSperre(rechnung: null, hatZahlungsbuchung: false,
            imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.keine,
      );
    });
    test('offen, unversendet, unbezahlt -> keine Sperre', () {
      expect(
        korrekturSperre(rechnung: _rg(), hatZahlungsbuchung: false,
            imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.keine,
      );
    });
    test('bezahlt schlaegt alles', () {
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'bezahlt', versendetAm: DateTime(2026, 9, 26)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
      expect(
        korrekturSperre(rechnung: _rg(), hatZahlungsbuchung: true,
            imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(zahlungEingegangenAm: DateTime(2026, 9, 27)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
      expect(
        korrekturSperre(rechnung: _rg(status: 'abgeschrieben'),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
    });
    test('Mahnfall vor gemahnt vor versendet', () {
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'mahnung_1', mahnungStufe: 2,
                versendetAm: DateTime(2026, 8, 1)),
            hatZahlungsbuchung: false, imMahnfall: true, nachbuchGrenze: grenze),
        KorrekturSperre.mahnfall,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'erinnert', mahnungStufe: 1,
                versendetAm: DateTime(2026, 8, 1)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.gemahnt,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'gesendet', versendetAm: DateTime(2026, 9, 26)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.versendet,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(uebergebenAm: DateTime(2026, 9, 26)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.versendet,
      );
    });
    test('abgeschlossenes Jahr', () {
      expect(
        korrekturSperre(
            rechnung: _rg(rechnungsdatum: DateTime(2025, 12, 15)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.abgeschlossenesJahr,
      );
    });
    test('sperrText nennt die Rechnungsnummer und den Ausweg', () {
      final t = sperrText(KorrekturSperre.versendet, '2026-09-26-0001');
      expect(t, contains('2026-09-26-0001'));
      expect(t, contains('Notiz'));
      expect(sperrText(KorrekturSperre.keine, null), '');
    });
  });

  group('preisrelevantGeaendert', () {
    test('nur Notiz -> false', () {
      expect(preisrelevantGeaendert(_rein(), _rein(notizen: 'Hahn tropft')), false);
    });
    test('Grundtarif, Haehne, Servicetyp, Zahlungsart, Kulanz, Datum -> true', () {
      expect(preisrelevantGeaendert(_rein(), _rein(grundtarif: 120)), true);
      expect(preisrelevantGeaendert(_rein(), _rein(eigen: 2)), true);
      expect(preisrelevantGeaendert(_rein(), _rein(serviceTyp: 'orion')), true);
      expect(preisrelevantGeaendert(_rein(), _rein(zahlungsart: 'barzahlung')), true);
      expect(preisrelevantGeaendert(_rein(), _rein(kulanz: true)), true);
      final anderesDatum = _rein()..datum = DateTime(2026, 9, 27);
      expect(preisrelevantGeaendert(_rein(), anderesDatum), true);
    });
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, erwartet FAIL** (`flutter test test/reinigung_korrektur_regel_test.dart` — «Target of URI doesn't exist»).

- [ ] **Schritt 3: Implementieren** (`lib/core/util/reinigung_korrektur_regel.dart`)

```dart
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Warum eine abgeschlossene Reinigung NICHT mehr preisrelevant geändert
/// werden darf. Bis v0.139.0 löschte jeder «Speichern»-Klick auf einer
/// abgeschlossenen Reinigung Rechnung und Buchungen und legte sie neu an —
/// ohne Blick auf bezahlt, gemahnt, Mahnfall oder abgeschlossenes Jahr
/// (Analyse 25.09.2026, R1). Reihenfolge = Schwere: bezahlt vor Mahnfall vor
/// gemahnt vor versendet vor Jahr.
enum KorrekturSperre {
  keine,
  bezahlt,
  mahnfall,
  gemahnt,
  versendet,
  abgeschlossenesJahr,
}

const _bezahltStatus = {'bezahlt', 'abgeschrieben'};
const _gemahntStatus = {'erinnert', 'mahnung_1', 'mahnung_2'};

KorrekturSperre korrekturSperre({
  required Rechnung? rechnung,
  required bool hatZahlungsbuchung,
  required bool imMahnfall,
  required DateTime nachbuchGrenze,
}) {
  if (rechnung == null) return KorrekturSperre.keine;
  if (_bezahltStatus.contains(rechnung.zahlungsstatus) ||
      rechnung.zahlungEingegangenAm != null ||
      hatZahlungsbuchung) {
    return KorrekturSperre.bezahlt;
  }
  if (imMahnfall) return KorrekturSperre.mahnfall;
  if (rechnung.mahnungStufe > 0 ||
      _gemahntStatus.contains(rechnung.zahlungsstatus)) {
    return KorrekturSperre.gemahnt;
  }
  if (rechnung.versendetAm != null || rechnung.uebergebenAm != null) {
    return KorrekturSperre.versendet;
  }
  if (rechnung.rechnungsdatum.isBefore(nachbuchGrenze)) {
    return KorrekturSperre.abgeschlossenesJahr;
  }
  return KorrekturSperre.keine;
}

/// Text für Band und Dialog. Leer bei [KorrekturSperre.keine].
String sperrText(KorrekturSperre sperre, String? rechnungsnummer) {
  final nr = rechnungsnummer == null ? 'Die Rechnung' : 'Rechnung $rechnungsnummer';
  const ausweg = ' Notiz, Foto und Zeiten lassen sich weiterhin speichern.';
  return switch (sperre) {
    KorrekturSperre.keine => '',
    KorrekturSperre.bezahlt =>
      '$nr ist bereits bezahlt — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.mahnfall =>
      '$nr steckt in einem Mahnfall — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.gemahnt =>
      '$nr wurde bereits gemahnt — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.versendet =>
      '$nr ist beim Kunden (versendet/übergeben) — eine Preisänderung braucht '
          'einen Storno mit neuer Rechnung (kommt mit Runde 3).$ausweg',
    KorrekturSperre.abgeschlossenesJahr =>
      '$nr liegt in einem abgeschlossenen Geschäftsjahr — Preis und Positionen '
          'sind gesperrt.$ausweg',
  };
}

/// Ob sich zwischen [alt] (geladener Stand) und [neu] (Formular) etwas
/// geändert hat, das Rechnung oder Buchung berührt. Alles, was
/// `RechnungService._buildPositionen` und `ReinigungBuchungService._calcNetto`
/// lesen, plus Datum (Rechnungsnummer/-datum) und Zahlungsart (Kasse vs.
/// Debitoren). Notizen, Zeiten, Foto, Service-Art zählen NICHT.
bool preisrelevantGeaendert(ReinigungLocal alt, ReinigungLocal neu) {
  DateTime tag(DateTime d) => DateTime(d.year, d.month, d.day);
  return tag(alt.datum) != tag(neu.datum) ||
      alt.zahlungsart != neu.zahlungsart ||
      alt.serviceTyp != neu.serviceTyp ||
      alt.istKulanz != neu.istKulanz ||
      alt.istHeinekenMonteur != neu.istHeinekenMonteur ||
      alt.istBergkunde != neu.istBergkunde ||
      alt.preisGrundtarif != neu.preisGrundtarif ||
      alt.preisZusatzHaehne != neu.preisZusatzHaehne ||
      alt.bergkundenZuschlag != neu.bergkundenZuschlag ||
      alt.preisNetto != neu.preisNetto ||
      alt.preisBrutto != neu.preisBrutto ||
      alt.anzahlHaehneEigen != neu.anzahlHaehneEigen ||
      alt.anzahlHaehneOrion != neu.anzahlHaehneOrion ||
      alt.anzahlHaehneWein != neu.anzahlHaehneWein ||
      alt.anzahlHaehneAndererStandort != neu.anzahlHaehneAndererStandort ||
      alt.anlageIdsJson != neu.anlageIdsJson;
}
```

  Prüfe vor dem Commit: Öffne `lib/services/rechnung/rechnung_service.dart` (`_buildPositionen`, ab Zeile ~244) und `lib/services/buchhaltung/reinigung_buchung_service.dart` (`_calcNetto`) und **ergänze in `preisrelevantGeaendert` jedes dort gelesene `reinigung.`-Feld, das oben fehlt** (z. B. Materialmengen). Feldnamen in `lib/data/local/web/reinigung_local_web.dart` nachschlagen; existiert `anzahlHaehneAndererStandort` dort nicht, die Zeile entfernen.

- [ ] **Schritt 4: Test laufen lassen, erwartet PASS.**
- [ ] **Schritt 5: Commit** `feat(reinigungen): Sperr-Regel und Preisvergleich fuer Korrekturen (R1, rein)`.

---

### Task 2: `ReinigungKorrekturService` — prüfen, stornieren statt löschen, sichtbar melden (R1)

**Files:**
- Modify: `sbs_projer_app/lib/services/rechnung/reinigung_korrektur_service.dart` (ganze Datei ersetzen)
- Modify: `sbs_projer_app/lib/services/buchhaltung/reinigung_buchung_service.dart:106-111` (Duplikat-Check ignoriert stornierte Zeilen)
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart:806-830` (Korrektur-Block) und `_loadReinigung` (Band)
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_detail_screen.dart:335-345` (Löschen)
- Test: `sbs_projer_app/test/reinigung_korrektur_waechter_test.dart`

- [ ] **Schritt 1: Wächter-Test schreiben** (`test/reinigung_korrektur_waechter_test.dart`)

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// R1 (Analyse 25.09.2026): Rechnung und Buchungen einer abgeschlossenen
/// Reinigung dürfen nie mehr ungeprüft gelöscht werden. Der Korrektur-
/// Service prüft die Sperre, storniert statt zu löschen und ruft
/// `deleteByBeleg` nicht mehr auf; die Screens gehen nur über ihn.
void main() {
  String lies(String p) => File(p).readAsStringSync();

  test('Korrektur-Service loescht keine Buchungen mehr hart', () {
    final s = lies('lib/services/rechnung/reinigung_korrektur_service.dart');
    expect(s.contains('deleteByBeleg'), isFalse);
    expect(s.contains('BuchungRepository.stornieren'), isTrue);
    expect(s.contains('korrekturSperre('), isTrue);
  });

  test('Formular und Detail pruefen die Sperre vor jeder Korrektur', () {
    final form = lies('lib/presentation/screens/reinigungen/reinigung_form_screen.dart');
    final detail = lies('lib/presentation/screens/reinigungen/reinigung_detail_screen.dart');
    expect(form.contains('ReinigungKorrekturService.sperrePruefen'), isTrue);
    expect(form.contains('preisrelevantGeaendert('), isTrue);
    expect(form.contains('cleanupBuchhaltung'), isFalse);
    expect(detail.contains('ReinigungKorrekturService.sperrePruefen'), isTrue);
  });

  test('Duplikat-Check der Ertragsbuchung zaehlt stornierte Zeilen nicht', () {
    final s = lies('lib/services/buchhaltung/reinigung_buchung_service.dart');
    expect(s.contains('zaehltFuerSaldo('), isTrue);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, erwartet FAIL.**

- [ ] **Schritt 3: Service neu schreiben** (`lib/services/rechnung/reinigung_korrektur_service.dart`)

```dart
import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/reinigung_korrektur_regel.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/buchung_nachhol_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

/// Stand der Buchhaltung zu einer Reinigung, wie ihn das Formular braucht.
class KorrekturStand {
  final Rechnung? rechnung;
  final KorrekturSperre sperre;
  const KorrekturStand({required this.rechnung, required this.sperre});
  String get text => sperrText(sperre, rechnung?.rechnungsnummer);
}

class KorrekturErgebnis {
  final bool buchungVerbucht;
  final String? buchungTypLabel;
  final Rechnung? rechnung;
  const KorrekturErgebnis({
    required this.buchungVerbucht,
    required this.buchungTypLabel,
    required this.rechnung,
  });
}

/// Korrektur einer abgeschlossenen Reinigung. Seit R1: erst prüfen, dann
/// stornieren (nie löschen), und jeder Fehler wandert zum Aufrufer.
class ReinigungKorrekturService {
  /// Rechnung zur Reinigung und die Sperre dazu. Zahlungsbuchungen tragen
  /// `beleg_id` = Rechnung; Ertragsbuchungen `beleg_id` = Reinigung.
  static Future<KorrekturStand> sperrePruefen(String reinigungServerId) async {
    final rechnungId = await RechnungsPositionRepository
        .getRechnungIdByServiceId(reinigungServerId);
    if (rechnungId == null) {
      return const KorrekturStand(rechnung: null, sperre: KorrekturSperre.keine);
    }
    final rechnung = await RechnungRepository.getById(rechnungId);
    final zahlungen = await BuchungRepository.getByBeleg(rechnungId);
    final hatZahlung = zahlungen.any(
      (b) => zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId),
    );
    final mahnfaelle = await MahnfallRepository.getByRechnung(rechnungId);
    final grenze = await BuchungNachholService.nachbuchGrenze();
    return KorrekturStand(
      rechnung: rechnung,
      sperre: korrekturSperre(
        rechnung: rechnung,
        hatZahlungsbuchung: hatZahlung,
        imMahnfall: mahnfaelle.isNotEmpty,
        nachbuchGrenze: grenze,
      ),
    );
  }

  /// Storniert die aktiven Ertragsbuchungen der Reinigung und entfernt die
  /// (unversendete, unbezahlte) Rechnung samt PDF. Wirft, wenn eine Sperre
  /// besteht — der Aufrufer MUSS vorher [sperrePruefen] gezeigt haben.
  static Future<void> zuruecknehmen(String reinigungServerId) async {
    final stand = await sperrePruefen(reinigungServerId);
    if (stand.sperre != KorrekturSperre.keine) {
      throw StateError(stand.text);
    }
    final buchungen = await BuchungRepository.getByBeleg(reinigungServerId);
    for (final b in buchungen) {
      if (!zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId)) {
        continue;
      }
      await BuchungRepository.stornieren(b.id);
    }
    final rechnung = stand.rechnung;
    if (rechnung != null) {
      await RechnungPdfStorage.deletePdf(rechnung.id);
      await RechnungRepository.delete(rechnung.id);
      debugPrint('[Korrektur] Rechnung ${rechnung.rechnungsnummer} entfernt');
    }
  }

  /// Zurücknehmen + neu erstellen (Rechnung, PDF, Ertragsbuchung). Kein
  /// Versand — die alte Rechnung war noch nicht beim Kunden.
  static Future<KorrekturErgebnis> korrigieren(
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    await zuruecknehmen(reinigung.serverId!);
    final rechnung = await RechnungService.createFromReinigung(reinigung, betrieb);
    final buchung = await ReinigungBuchungService.createFromReinigung(reinigung, betrieb);
    String? label;
    if (buchung != null) {
      final art = resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
      label = art == 'barzahlung' ? 'Barzahlung' : 'Rechnung';
    }
    return KorrekturErgebnis(
      buchungVerbucht: buchung != null,
      buchungTypLabel: label,
      rechnung: rechnung,
    );
  }
}
```

  `MahnfallRepository.getByRechnung(String)` existiert (`mahnfall_repository.dart:93`). `zaehltFuerSaldo` liegt in `lib/services/buchhaltung/storno_logik.dart:13`.

- [ ] **Schritt 4: Duplikat-Check in `ReinigungBuchungService.createFromReinigung`** (Zeile ~106) — stornierte Zeilen zählen nicht, sonst legt `korrigieren` nach einem Storno nie eine neue Buchung an:

```dart
    // Duplikat-Check via belegId — stornierte Zeilen und Storno-Gegenbuchungen
    // zählen nicht (Korrektur storniert seit R1 statt zu löschen).
    final existing = await BuchungRepository.getByBeleg(reinigung.serverId!);
    if (existing.any((b) =>
        zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId))) {
      debugPrint('ReinigungBuchung: Buchung existiert bereits für ${reinigung.serverId}');
      return null;
    }
```
  Import `package:sbs_projer_app/services/buchhaltung/storno_logik.dart` ergänzen. Prüfe, dass `BuchungNachholService.finde` dieselbe Bedeutung hat (es nutzt `belegIdsMitBuchung` — dort nachsehen, ob stornierte ausgeschlossen sind; wenn nicht, dort `.eq('ist_storniert', false)` ergänzen, sonst gilt eine stornierte Buchung als «vorhanden» und das Nachholen übersieht die Reinigung).

- [ ] **Schritt 5: Formular** (`reinigung_form_screen.dart`)

  a) State ergänzen (bei den anderen Feldern, ~Zeile 98):
```dart
  /// Sperre der Buchhaltung beim Bearbeiten einer abgeschlossenen Reinigung
  /// (R1). null = noch nicht geprüft oder keine Rechnung.
  KorrekturStand? _korrekturStand;
```
  b) In `_loadReinigung` nach dem `setState` (Ende der Methode), nur Web + abgeschlossen + serverId:
```dart
    if (kIsWeb && r.status == 'abgeschlossen' && r.serverId != null) {
      try {
        final stand = await ReinigungKorrekturService.sperrePruefen(r.serverId!);
        if (mounted) setState(() => _korrekturStand = stand);
      } catch (e) {
        debugPrint('[Korrektur] Sperre nicht pruefbar: $e');
      }
    }
```
  c) Band im `build` direkt unter dem ersten `_sectionTitle` (oberhalb der Zeiterfassung), wenn `_korrekturStand?.sperre != KorrekturSperre.keine && _korrekturStand != null`:
```dart
              if (_korrekturStand != null &&
                  _korrekturStand!.sperre != KorrekturSperre.keine) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_korrekturStand!.text)),
                    ],
                  ),
                ),
              ],
```
  d) Korrektur-Block (Zeilen 806–830) ersetzen. **Wichtig:** die Prüfung muss VOR `ReinigungRepository.save(r)` (Zeile 697) laufen, sonst ist die Reinigung schon geändert, wenn die Sperre greift. Also direkt nach dem Preis-Block (nach Zeile ~653, vor «Status ZUERST setzen») einfügen:
```dart
      // R1: Abgeschlossene Reinigung bearbeiten — Buchhaltung nur anfassen,
      // wenn sich etwas Preisrelevantes geändert hat, und nur ohne Sperre.
      final korrekturNoetig = _isEdit &&
          !abschliessen &&
          kIsWeb &&
          _existing?.status == 'abgeschlossen' &&
          r.serverId != null &&
          preisrelevantGeaendert(_existing!, r);
      if (korrekturNoetig) {
        final stand = await ReinigungKorrekturService.sperrePruefen(r.serverId!);
        if (stand.sperre != KorrekturSperre.keine) {
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Änderung nicht möglich'),
                content: Text(stand.text),
                actions: [
                  TapKnopf(text: 'Verstanden', onTap: () => Navigator.pop(ctx)),
                ],
              ),
            );
          }
          return; // nichts gespeichert — finally setzt _isLoading zurück
        }
      }
```
  und den alten Block (806–830) durch dies ersetzen (nach `ReinigungRepository.save(r)`, an derselben Stelle wie bisher):
```dart
      bool buchungKorrigiert = false;
      String? korrekturTypLabel;
      if (korrekturNoetig) {
        try {
          final betrieb = _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
          if (betrieb == null) throw StateError('Betrieb nicht geladen');
          final erg = await ReinigungKorrekturService.korrigieren(r, betrieb);
          buchungKorrigiert = erg.buchungVerbucht;
          korrekturTypLabel = erg.buchungTypLabel;
        } catch (e) {
          debugPrint('[Korrektur] Fehler: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(
                  'Reinigung gespeichert, aber Rechnung/Buchung NICHT korrigiert: '
                  '${kurzeFehlermeldung(e)}\nBitte im Rechnungsbereich prüfen.',
                  style: const TextStyle(color: Colors.white),
                ),
                duration: const Duration(seconds: 12),
              ),
            );
          }
        }
      }
```
  Guards `!_istKulanz && !_istHeinekenMonteur` entfallen: ein Wechsel auf Kulanz ist selbst preisrelevant, `korrigieren` storniert dann die alte Buchung und `createFromReinigung` legt bei Kulanz nichts Neues an — genau richtig. Imports: `reinigung_korrektur_regel.dart`, `tap_knopf.dart`.

- [ ] **Schritt 6: Detail-Screen Löschen** (`reinigung_detail_screen.dart:335-345`): vor dem `gefahrRueckfrage`/Dialog die Sperre holen; bei Sperre statt Löschen einen Hinweis zeigen:
```dart
    if (reinigung.serverId != null && reinigung.status == 'abgeschlossen') {
      final stand = await ReinigungKorrekturService.sperrePruefen(reinigung.serverId!);
      if (!context.mounted) return;
      if (stand.sperre != KorrekturSperre.keine) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Löschen nicht möglich. ${stand.text}',
                style: const TextStyle(color: Colors.white)),
            duration: const Duration(seconds: 10),
          ),
        );
        return;
      }
    }
```
  und im Lösch-Zweig `cleanupBuchhaltung(...)` durch `ReinigungKorrekturService.zuruecknehmen(reinigung.serverId!)` ersetzen.

- [ ] **Schritt 7:** `flutter test` (alle) und `flutter analyze`; erwartet grün / ≤ 56.
- [ ] **Schritt 8: Commit** `fix(reinigungen): Korrektur prueft Sperre, storniert statt zu loeschen, meldet Fehler (R1)`.

---

### Task 3: `ReinigungAbschlussService` — eine Kette für Formular und Detail

**Files:**
- Create: `sbs_projer_app/lib/services/rechnung/reinigung_abschluss_service.dart`
- Modify: `sbs_projer_app/lib/services/rechnung/reinigung_rechnung_versand.dart:177-250` (Mail-Fehler: Server fragen statt werfen)
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart` (`_save` Schritte 8–13 ersetzen; HeiGenie-Block entfernen)
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_detail_screen.dart:467-476`
- Test: `sbs_projer_app/test/reinigung_abschluss_test.dart`, `sbs_projer_app/test/abschlusskette_waechter_test.dart`

- [ ] **Schritt 1: Tests schreiben**

  `test/reinigung_abschluss_test.dart` (reine Meldungslogik):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_abschluss_service.dart';

void main() {
  group('abschlussSnackbarText', () {
    test('Buchung + Nachholen', () {
      final e = AbschlussErgebnis(
        rechnungErstellt: true,
        buchungVerbucht: true,
        buchungTypLabel: 'Rechnung',
        nachgeholt: 2,
        meldungen: const [],
      );
      expect(abschlussSnackbarText(e),
          'Reinigung abgeschlossen – Rechnung verbucht · 2 frühere Buchungen nachgeholt');
    });
    test('ohne Buchung', () {
      final e = AbschlussErgebnis(
        rechnungErstellt: false,
        buchungVerbucht: false,
        buchungTypLabel: null,
        nachgeholt: 0,
        meldungen: const [],
      );
      expect(abschlussSnackbarText(e), 'Reinigung abgeschlossen');
    });
    test('eine nachgeholte Buchung im Singular', () {
      final e = AbschlussErgebnis(
        rechnungErstellt: true,
        buchungVerbucht: true,
        buchungTypLabel: 'Barzahlung',
        nachgeholt: 1,
        meldungen: const [],
      );
      expect(abschlussSnackbarText(e), contains('1 frühere Buchung nachgeholt'));
    });
  });

  test('AbschlussMeldung: Stufe bestimmt Farbe/Dauer', () {
    const m = AbschlussMeldung('x', AbschlussStufe.fehler);
    expect(m.dauer.inSeconds, 12);
    expect(const AbschlussMeldung('y', AbschlussStufe.info).dauer.inSeconds, 4);
  });
}
```

  `test/abschlusskette_waechter_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// §3 Zeile 1 der Analyse 25.09.2026: Die Abschlusskette (Rechnung → Versand
/// → Buchung → Nachholen → Pauschale) existiert genau EINMAL —
/// im ReinigungAbschlussService. Screens rufen nur ihn.
void main() {
  String lies(String p) => File(p).readAsStringSync();
  const form = 'lib/presentation/screens/reinigungen/reinigung_form_screen.dart';
  const detail = 'lib/presentation/screens/reinigungen/reinigung_detail_screen.dart';

  test('Formular baut die Kette nicht mehr selbst', () {
    final s = lies(form);
    for (final verboten in [
      'RechnungService.createFromReinigung',
      "'send-rechnung-mail'",
      'ReinigungBuchungService.createFromReinigung',
      'BuchungNachholService.nachholen',
      'BergkundenpauschaleRepository.create',
      'ReinigungRechnungVersand.vermerkeVersand',
    ]) {
      expect(s.contains(verboten), isFalse, reason: '$verboten gehört in den Service');
    }
    expect(s.contains('ReinigungAbschlussService.abschliessen'), isTrue);
  });

  test('Detail-Screen nutzt dieselbe Kette', () {
    final s = lies(detail);
    expect(s.contains('ReinigungAbschlussService.abschliessen'), isTrue);
    expect(s.contains('ReinigungRechnungVersand.erstelleUndSende'), isFalse);
    expect(s.contains('ReinigungBuchungService.createFromReinigung'), isFalse);
  });

  test('T5: Pausen-Pruefung laeuft NACH der Kette', () {
    final s = lies(form);
    final kette = s.indexOf('ReinigungAbschlussService.abschliessen');
    final pause = s.indexOf('pausePruefenNachEreignis(');
    expect(kette, greaterThan(-1));
    expect(pause, greaterThan(kette));
  });

  test('Service enthaelt alle Glieder', () {
    final s = lies('lib/services/rechnung/reinigung_abschluss_service.dart');
    for (final glied in [
      'ReinigungRechnungVersand.erstelleUndSende',
      'ReinigungBuchungService.createFromReinigung',
      'BuchungNachholService.nachholen',
      'BergkundenpauschaleRepository.create',
    ]) {
      expect(s.contains(glied), isTrue, reason: glied);
    }
  });
}
```

- [ ] **Schritt 2: Tests laufen lassen, erwartet FAIL.**

- [ ] **Schritt 3: Mail-Fehler in `erstelleUndSende` nicht mehr werfen** (`reinigung_rechnung_versand.dart`, Zweig `rs == 'rechnung_mail'` ab Zeile ~177 und `rs == 'rechnung_post'` ab ~239). Das `invoke` je in `try/catch` legen; im `catch` den Server fragen — die Logik aus dem Formular (Zeilen 1058–1082):
```dart
      String? versandFehlerText;
      try {
        await SupabaseService.client.functions.invoke('send-rechnung-mail', body: { /* unverändert */ });
      } catch (e) {
        debugPrint('[ReinigungVersand] Mail-Fehler: $e');
        final m = versandMeldung(
          versandStandAus(await RechnungRepository.istVersandVermerkt(rechnung.id)),
          e,
        );
        if (m.istFehler) rethrow;
        versandFehlerText = m.text; // Server hat den Vermerk: Mail ist raus
      }
```
  Nach dem Block wie bisher `vermerkeVersand` (nur wenn scharf bzw. bei Post immer). Die Meldung des Ergebnisses: `versandFehlerText ?? <bisherige Meldung>`; Feld `keineKundenadresse` unverändert. Import `package:sbs_projer_app/core/util/versand_meldung.dart`.

- [ ] **Schritt 4: Service schreiben** (`lib/services/rechnung/reinigung_abschluss_service.dart`)

```dart
import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart'; // kurzeFehlermeldung
import 'package:sbs_projer_app/core/util/rechnung_nachhol_plan.dart';
import 'package:sbs_projer_app/core/util/versand_meldung.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/bergkundenpauschale_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/buchung_nachhol_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_rechnung_versand.dart';

enum AbschlussStufe { info, warnung, fehler }

/// Eine Meldung aus der Kette — der Screen zeigt sie als Snackbar.
class AbschlussMeldung {
  final String text;
  final AbschlussStufe stufe;
  const AbschlussMeldung(this.text, this.stufe);
  Duration get dauer => switch (stufe) {
        AbschlussStufe.info => const Duration(seconds: 4),
        AbschlussStufe.warnung => const Duration(seconds: 8),
        AbschlussStufe.fehler => const Duration(seconds: 12),
      };
}

class AbschlussErgebnis {
  final bool rechnungErstellt;
  final bool buchungVerbucht;
  final String? buchungTypLabel;
  final int nachgeholt;
  final List<AbschlussMeldung> meldungen;
  const AbschlussErgebnis({
    required this.rechnungErstellt,
    required this.buchungVerbucht,
    required this.buchungTypLabel,
    required this.nachgeholt,
    required this.meldungen,
  });
}

/// Text der Abschluss-Snackbar (rein, getestet).
String abschlussSnackbarText(AbschlussErgebnis e) {
  if (!e.buchungVerbucht) return 'Reinigung abgeschlossen';
  final nach = e.nachgeholt > 0
      ? ' · ${e.nachgeholt} frühere Buchung${e.nachgeholt == 1 ? '' : 'en'} nachgeholt'
      : '';
  return 'Reinigung abgeschlossen – ${e.buchungTypLabel} verbucht$nach';
}

/// DIE Abschlusskette einer Reinigung. Bis v0.139.0 lag sie zweimal vor:
/// 820 Zeilen im Formular und (nur fürs Nachholen) in
/// `ReinigungRechnungVersand.erstelleUndSende`; jeder Fix musste doppelt
/// gemacht werden, und die Kette riss am 03./04./07./11.09.2026 an je
/// anderer Stelle. Jetzt rufen Formular und Detail-Screen nur noch diese
/// Methode. Reihenfolge und Fehlerhaltung:
///   1. Rechnung + Versand (Mail/Post/Tresen) — Fehler → Meldung, weiter.
///   2. Ertragsbuchung — UNABHÄNGIG von 1 — Fehler → Meldung, weiter.
///   3. Nachholen früherer Abschlüsse (nur wenn 2 durchlief, 14 Tage, 20 s).
///   4. Bergkundenpauschale (wird Heineken verrechnet).
///   5. Kulanz-Merker am Betrieb löschen.
/// Kulanz / Heineken-Monteur: 1 und 2 liefern selbst «nichts zu tun».
class ReinigungAbschlussService {
  static Future<AbschlussErgebnis> abschliessen(
    ReinigungLocal r,
    BetriebLocal betrieb, {
    bool nachholen = true,
  }) async {
    final meldungen = <AbschlussMeldung>[];
    var rechnungErstellt = false;

    // 1. Rechnung + Versand
    try {
      final erg = await ReinigungRechnungVersand.erstelleUndSende(r, betrieb);
      rechnungErstellt = erg.rechnungErstellt;
      if (erg.rechnungErstellt || erg.mailGesendet) {
        meldungen.add(AbschlussMeldung(
          erg.meldung,
          erg.keineKundenadresse || erg.pdfFehlt
              ? AbschlussStufe.warnung
              : AbschlussStufe.info,
        ));
      }
    } catch (e) {
      debugPrint('[Abschluss] Rechnung/Versand: $e');
      meldungen.add(AbschlussMeldung(
        'Reinigung ist abgeschlossen. ${kettenFehlerMeldung(e)}',
        AbschlussStufe.fehler,
      ));
    }

    // 2. Ertragsbuchung
    var buchungVerbucht = false;
    String? buchungTypLabel;
    try {
      final buchung = await ReinigungBuchungService.createFromReinigung(r, betrieb);
      if (buchung != null) {
        buchungVerbucht = true;
        final art = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
        buchungTypLabel = art == 'barzahlung' ? 'Barzahlung' : 'Rechnung';
      }
    } catch (e) {
      debugPrint('[Abschluss] Buchung: $e');
      meldungen.add(AbschlussMeldung(buchungFehlerMeldung(e), AbschlussStufe.fehler));
    }

    // 3. Nachholen
    var nachgeholt = 0;
    if (nachholen && buchungVerbucht) {
      try {
        final erg = await BuchungNachholService.nachholen(
          ab: DateTime.now().subtract(const Duration(days: 14)),
        ).timeout(const Duration(seconds: 20));
        nachgeholt = erg.gebucht;
        if (erg.fehler.isNotEmpty) {
          debugPrint('[Nachbuchung] ${erg.fehler.join(' | ')}');
          meldungen.add(AbschlussMeldung(
            'NACHBUCHEN FEHLGESCHLAGEN (${erg.fehler.length}): '
            '${kurzeFehlermeldung(erg.fehler.first)}\n'
            'Über Buchhaltung → Forderungen erneut versuchen.',
            AbschlussStufe.fehler,
          ));
        }
      } catch (e) {
        debugPrint('[Nachbuchung] Fehler: $e');
        meldungen.add(AbschlussMeldung(
          'Nachbuchen älterer Reinigungen abgebrochen (${kurzeFehlermeldung(e)}).\n'
          'Die eigene Buchung ist gespeichert.',
          AbschlussStufe.warnung,
        ));
      }
    }

    // 4. Bergkundenpauschale
    if (r.istBergkunde && !r.istHeinekenMonteur && r.serverId != null) {
      try {
        final preis = await PreisRepository.getAktuell(datum: r.datum);
        await BergkundenpauschaleRepository.create({
          'betrieb_id': r.betriebId,
          'reinigung_id': r.serverId,
          'datum': r.datum.toIso8601String().split('T').first,
          'betrag': preis?.bergkundenZuschlag ?? 180.0,
        });
      } catch (e) {
        debugPrint('[Bergkundenpauschale] Fehler: $e');
        meldungen.add(AbschlussMeldung(
          'Bergkundenpauschale NICHT erfasst (${kurzeFehlermeldung(e)}) — '
          'unter Bergkundenpauschalen nachtragen.',
          AbschlussStufe.warnung,
        ));
      }
    }

    // 5. Kulanz-Merker (einmalig, siehe Chleina Pub)
    if (r.istKulanz && betrieb.naechsteReinigungKulanz) {
      try {
        betrieb.naechsteReinigungKulanz = false;
        await BetriebRepository.save(betrieb);
      } catch (e) {
        debugPrint('[Kulanz-Merker] Zuruecksetzen fehlgeschlagen: $e');
      }
    }

    return AbschlussErgebnis(
      rechnungErstellt: rechnungErstellt,
      buchungVerbucht: buchungVerbucht,
      buchungTypLabel: buchungTypLabel,
      nachgeholt: nachgeholt,
      meldungen: meldungen,
    );
  }
}
```
  Prüfen: `kurzeFehlermeldung` liegt in `lib/core/util/anfrage_bloecke.dart`; `PreisRepository.getAktuell(datum:)` gibt `Preis?` mit `bergkundenZuschlag` (`lib/data/models/preis.dart:9`); `BergkundenpauschaleRepository.create(Map)` wie bisher im Formular. Ist die Bergkundenpauschale bisher nur bei `kIsWeb` erstellt worden, bleibt das so, weil der Screen den Service nur auf Web ruft.

- [ ] **Schritt 5: Formular umbauen** (`reinigung_form_screen.dart`, `_save`). Neue Reihenfolge nach `ReinigungRepository.save(r)` (Zeile 697):
  1. Korrektur-Block aus Task 2 (unverändert an seiner Stelle).
  2. **Kette:** ersetzt HeiGenie-Block (833–900), Kulanz-Merker (911–920), Rechnung/Mail/Post/Tresen/Buchung/Nachholen (926–1303) und Bergkundenpauschale (1306–1327):
```dart
      AbschlussErgebnis? abschluss;
      if (abschliessen && kIsWeb) {
        final betrieb = _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
        if (betrieb == null) {
          debugPrint('[Rechnung] BETRIEB NULL — betriebId="${r.betriebId}"');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(
                  'BETRIEB NICHT GELADEN — KEINE RECHNUNG, KEINE BUCHUNG!\n'
                  'Reinigung ist gespeichert. Bitte Daniel melden.\n'
                  'betriebId="${r.betriebId}"',
                  style: const TextStyle(color: Colors.white),
                ),
                duration: const Duration(seconds: 30),
              ),
            );
          }
        } else {
          abschluss = await ReinigungAbschlussService.abschliessen(r, betrieb);
          if (abschluss.nachgeholt > 0) ref.invalidate(reinigungenOhneRechnungProvider);
          if (mounted) {
            for (final m in abschluss.meldungen) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: switch (m.stufe) {
                    AbschlussStufe.info => null,
                    AbschlussStufe.warnung => AppColors.warning,
                    AbschlussStufe.fehler => AppColors.error,
                  },
                  content: Text(
                    m.text,
                    style: m.stufe == AbschlussStufe.info
                        ? null
                        : const TextStyle(color: Colors.white),
                  ),
                  duration: m.dauer,
                ),
              );
            }
          }
        }
      }
```
  3. **Danach** (T5) der bisherige Block «Fahrzeit-Nachführung + Wegpunkt + Pausen-Prüfung» (Zeilen 706–804) — unverändert, nur verschoben. Ergebnis: die Kette wartet nie mehr auf das Pausen-Sheet.
  4. Abschluss-Snackbar (1329–1345): `abschliessen ? abschlussSnackbarText(abschluss ?? const AbschlussErgebnis(rechnungErstellt: false, buchungVerbucht: false, buchungTypLabel: null, nachgeholt: 0, meldungen: [])) : buchungKorrigiert ? … : …` — die drei bisherigen Nicht-Abschluss-Texte bleiben.
  5. Invalidierung (1346–1355) unverändert; `buchungVerbucht`/`nachgeholt`/`buchungTypLabel`-Locals entfernen.
  6. HeiGenie: Der Dropdown-Eintrag `'heigenie'` (Zeile ~2437) entfällt (T6, 0 Nutzungen; HeiGenie-Betriebe sind `ist_mein_kunde = false`, dort gibt es nur Störungen). `_serviceTypLabel`, Preis-Fallbacks und `_serviceTyp = 'heigenie'` aus der Anlagen-Erkennung (Zeile ~485) bleiben, damit Altdaten lesbar bleiben. `heigenieFehlerMeldung` in `versand_meldung.dart` bleibt (andere Aufrufer prüfen; ohne Aufrufer löschen samt Test).
  7. `_showAbschlussDialog` (Zeile 1377): Kulanz/Heineken-Zweig mit Guard:
```dart
    if (_istHeinekenMonteur || _istKulanz) {
      if (_isLoading) return;
      await _save(abschliessen: true);
      return;
    }
```
  Nicht mehr gebrauchte Imports entfernen (`KontaktRepository`, `RechnungService`, `RechnungPdfStorage`, `ReinigungBuchungService`, `BuchungNachholService`, `BergkundenpauschaleRepository`, `bergkundenpauschaleStreamProvider`-Invalidierung bleibt, falls noch benutzt), `_monatName` im Formular löschen, wenn kein Aufrufer bleibt.

- [ ] **Schritt 6: Detail-Screen** (`reinigung_detail_screen.dart:467-476`) ersetzen durch:
```dart
      final erg = await ReinigungAbschlussService.abschliessen(
        reinigung,
        betrieb,
        nachholen: false,
      );
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final meldungen = erg.meldungen.isEmpty
          ? [AbschlussMeldung(abschlussSnackbarText(erg), AbschlussStufe.info)]
          : erg.meldungen;
      for (final m in meldungen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: switch (m.stufe) {
              AbschlussStufe.info => null,
              AbschlussStufe.warnung => AppColors.warning,
              AbschlussStufe.fehler => AppColors.error,
            },
            content: Text(m.text,
                style: m.stufe == AbschlussStufe.info ? null : const TextStyle(color: Colors.white)),
            duration: m.dauer,
          ),
        );
      }
```
  Den bestehenden `try/catch` um den Aufruf beibehalten (Fortschrittsdialog schliessen, `kettenFehlerMeldung`).

- [ ] **Schritt 7:** `flutter test` + `flutter analyze` (grün / ≤ 56). Achte auf `versandvermerk_waechter_test.dart` und `versand_status_waechter_test.dart` — sie lesen das Formular; nach dem Umbau dürfen dort keine Treffer mehr nötig sein; passe die Dateilisten in den Tests an, falls sie das Formular fest erwarten.
- [ ] **Schritt 8: Commit** `refactor(reinigungen): eine Abschlusskette — ReinigungAbschlussService fuer Formular und Detail (T5)`.

---

### Task 4: Protokollfoto sofort hochladen, Fehler sichtbar, Aufgabe «ohne Protokoll» (T1)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart` (`_onPhotoTaken`, Foto-Block in `_save` Zeilen 674–695, Protokoll-Sektion ~1906)
- Modify: `sbs_projer_app/lib/core/util/aufgaben_regeln.dart` (neue Regel)
- Modify: `sbs_projer_app/lib/presentation/providers/aufgaben_detektoren_provider.dart` (neuer Detektor h)
- Test: `sbs_projer_app/test/aufgaben_regeln_test.dart` (ergänzen), `sbs_projer_app/test/protokollfoto_waechter_test.dart`

- [ ] **Schritt 1: Tests**

  In `test/aufgaben_regeln_test.dart` eine Gruppe ergänzen:
```dart
  group('protokollFehltAufgabe', () {
    test('0 -> null', () => expect(protokollFehltAufgabe(0), isNull));
    test('1 -> Singular, Vorrat, nicht dringend', () {
      final a = protokollFehltAufgabe(1)!;
      expect(a.key, 'protokoll_fehlt');
      expect(a.titel, '1 Reinigung ohne Protokollfoto');
      expect(a.istVorrat, isTrue);
      expect(a.dringend, isFalse);
      expect(a.route, '/reinigungen');
    });
    test('3 -> Plural', () {
      expect(protokollFehltAufgabe(3)!.titel, '3 Reinigungen ohne Protokollfoto');
    });
  });
```
  `test/protokollfoto_waechter_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// T1/R8: Ein gescheiterter Foto-Upload darf nie mehr nur im Debug-Protokoll
/// landen (~23 Abbrüche in 17 Tagen, Protokolle fehlten still).
void main() {
  test('Foto-Upload meldet Fehler sichtbar und laeuft sofort nach der Aufnahme', () {
    final s = File('lib/presentation/screens/reinigungen/reinigung_form_screen.dart')
        .readAsStringSync();
    expect(s.contains('_fotoHochladen('), isTrue);
    expect(s.contains('_fotoFehler'), isTrue);
    // Der alte stille Zweig:
    expect(s.contains("debugPrint('Foto-Upload fehlgeschlagen: \$e');"), isFalse);
  });
  test('Detektor fuer Reinigungen ohne Protokollfoto existiert', () {
    final s = File('lib/presentation/providers/aufgaben_detektoren_provider.dart')
        .readAsStringSync();
    expect(s.contains('protokollFehltAufgabe('), isTrue);
    expect(s.contains("isFilter('protokoll_foto_pfad', null)"), isTrue);
  });
}
```

- [ ] **Schritt 2: Tests laufen lassen, erwartet FAIL.**

- [ ] **Schritt 3: Regel** (`aufgaben_regeln.dart`, nach `fehlendeBuchungenAufgabe`):
```dart
/// Abgeschlossene Reinigungen ohne Protokollfoto (seit dem Stichtag, ab dem
/// das Foto sofort hochgeladen wird — Altbestand aus dem Excel-Import hat
/// seine Scans anderswo). Bis v0.139.0 scheiterte der Upload still, die
/// Reinigung galt als fertig, Mail und Beleg gingen ohne Protokoll raus.
Aufgabe? protokollFehltAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'protokoll_fehlt',
        titel: anzahl == 1
            ? '1 Reinigung ohne Protokollfoto'
            : '$anzahl Reinigungen ohne Protokollfoto',
        route: '/reinigungen',
        istVorrat: true,
      );

/// Ab diesem Tag gilt: jede abgeschlossene Reinigung hat ein Foto.
final protokollPflichtAb = DateTime(2026, 9, 26);
```

- [ ] **Schritt 4: Detektor** (`aufgaben_detektoren_provider.dart`, nach Block f, Muster e/f):
```dart
  // h) Reinigungen ohne Protokollfoto — nur ab dem Stichtag, ab dem der
  //    Upload sofort nach der Aufnahme läuft (T1). Heineken-Monteur-Einsätze
  //    haben kein Protokoll. Kein .neq() (NULL-Falle): ist_heineken_monteur
  //    ist NOT NULL DEFAULT false, deshalb .eq(false) sicher.
  try {
    final rows = await client
        .from('reinigungen')
        .select('id')
        .eq('status', 'abgeschlossen')
        .eq('ist_heineken_monteur', false)
        .isFilter('protokoll_foto_pfad', null)
        .gte('datum', protokollPflichtAb.toIso8601String().split('T').first)
        .limit(500);
    final a = protokollFehltAufgabe(rows.length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Protokollfoto-Detektor: $e');
  }
```
  Prüfe in `Datenbank/migrations/`, dass `reinigungen.ist_heineken_monteur` `NOT NULL DEFAULT false` ist (grep `ist_heineken_monteur`); ist die Spalte nullable, die Bedingung in Dart filtern (Zeilen laden mit `ist_heineken_monteur` und `where((r) => r['ist_heineken_monteur'] != true)`). Läuft `test/aufgaben_eine_quelle_waechter_test.dart` rot, dessen Regel lesen und den Detektor entsprechend anbinden (vermutlich: jede Aufgabe muss über den Aufgaben-Provider kommen — so wie e/f).

- [ ] **Schritt 5: Formular — sofortiger Upload.** State ergänzen:
```dart
  /// Auf Web vorab erzeugt, damit das Foto sofort nach der Aufnahme in den
  /// richtigen Ordner kann (T1). Bei Bearbeiten = serverId der Reinigung.
  late final String? _fotoReinigungId =
      kIsWeb ? (widget.reinigungId ?? const Uuid().v4()) : null;
  String? _hochgeladenerPfad;
  String? _fotoFehler;
```
  Vorsicht: `widget.reinigungId` ist beim Bearbeiten die Server-UUID (Web). Prüfe im Router/`_loadReinigung`, ob das stimmt; sonst `_existing?.serverId` nach dem Laden verwenden und `_fotoReinigungId` als normales Feld setzen.

  `_onPhotoTaken` ersetzen:
```dart
  void _onPhotoTaken(Uint8List bytes) {
    markiereGeaendert();
    setState(() {
      _fotoBytes = bytes;
      _existingFotoPfad = null;
      _hochgeladenerPfad = null;
      _fotoFehler = null;
    });
    if (kIsWeb) unawaited(_fotoHochladen());
  }

  /// Lädt das Foto sofort hoch (Web). Ein Fehler ist sichtbar (rotes Band
  /// mit «Erneut versuchen») und wird beim Speichern noch einmal probiert.
  Future<void> _fotoHochladen() async {
    final bytes = _fotoBytes;
    final id = _fotoReinigungId;
    if (bytes == null || id == null || _istHeinekenMonteur) return;
    setState(() { _fotoUploading = true; _fotoFehler = null; });
    try {
      final pfad = await ProtokollFotoStorage.uploadFoto(id, bytes);
      if (mounted) setState(() => _hochgeladenerPfad = pfad);
    } catch (e) {
      debugPrint('[Foto] Upload fehlgeschlagen: $e');
      if (mounted) setState(() => _fotoFehler = kurzeFehlermeldung(e));
    } finally {
      if (mounted) setState(() => _fotoUploading = false);
    }
  }
```
  Foto-Block in `_save` (674–695) ersetzen:
```dart
      if (kIsWeb && !_isEdit && r.serverId == null) {
        r.serverId = _fotoReinigungId; // dieselbe ID wie der Foto-Ordner
      }
      if (_fotoBytes != null && !_istHeinekenMonteur) {
        if (kIsWeb) {
          if (_hochgeladenerPfad == null) await _fotoHochladen(); // zweiter Versuch
          r.protokollFotoPfad = _hochgeladenerPfad;
        } else {
          setState(() => _fotoUploading = true);
          try {
            if (!_isEdit) await ReinigungRepository.save(r);
            r.protokollFotoPfad =
                await ProtokollFotoStorage.uploadFoto(r.serverId ?? r.routeId, _fotoBytes!);
          } catch (e) {
            debugPrint('[Foto] Upload fehlgeschlagen (nativ): $e');
            _fotoFehler = kurzeFehlermeldung(e);
          } finally {
            if (mounted) setState(() => _fotoUploading = false);
          }
        }
        if (r.protokollFotoPfad == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                'PROTOKOLLFOTO NICHT HOCHGELADEN (${_fotoFehler ?? 'unbekannt'}).\n'
                'Reinigung wird ohne Protokoll gespeichert — über «Bearbeiten» nachreichen.',
                style: const TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 12),
            ),
          );
        }
      } else if (_existingFotoPfad != null && !_istHeinekenMonteur) {
        r.protokollFotoPfad = _existingFotoPfad;
      }
```
  Protokoll-Sektion (unter `_sectionTitle(context, 'Protokoll')`): rotes Band bei `_fotoFehler != null`:
```dart
                if (_fotoFehler != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.error),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto nicht hochgeladen: $_fotoFehler',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TapKnopf(
                          text: 'Erneut versuchen',
                          laeuft: _fotoUploading,
                          onTap: _fotoUploading ? null : _fotoHochladen,
                        ),
                      ],
                    ),
                  ),
                if (_fotoUploading && _fotoFehler == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(),
                  ),
```
  Beim Verwerfen eines Fotos (bestehender «Foto entfernen»-Weg, falls vorhanden) `_hochgeladenerPfad = null; _fotoFehler = null;` mitsetzen.

- [ ] **Schritt 6:** `flutter test` + `flutter analyze`.
- [ ] **Schritt 7: Commit** `feat(reinigungen): Protokollfoto sofort hochladen, Fehler sichtbar, Aufgabe ohne Protokoll (T1)`.

---

### Task 5: Formular entrümpeln und CanvasKit-sicher (T6)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart` (Zeilen ~1845–1855 Ende, ~1892–1902 Checkbox, ~1596–1602 Dialog-Knopf, ~1975–2010 Knöpfe, ~1914–1935 Foto-Knöpfe)
- Test: `sbs_projer_app/test/reinigung_form_knoepfe_waechter_test.dart`

- [ ] **Schritt 1: Wächter-Test**
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// T6: Der häufigste Pfad der App (Reinigung abschliessen, 111× in 17 Tagen)
/// darf nicht an der CanvasKit-Falle hängen — alle Aktionsknöpfe sind
/// TapKnopf. Ballast weg: «Wasser gewechselt» (0 von 405), «Ende» beim Start.
void main() {
  final s = File('lib/presentation/screens/reinigungen/reinigung_form_screen.dart')
      .readAsStringSync();
  test('keine Material-Buttons fuer Aktionen', () {
    expect(s.contains('FilledButton'), isFalse);
    expect(s.contains('OutlinedButton'), isFalse);
  });
  test('Wasser-Checkbox und HeiGenie-Auswahl entfernt', () {
    expect(s.contains("'Wasser im Kühler gewechselt'"), isFalse);
    expect(s.contains("DropdownMenuItem(value: 'heigenie'"), isFalse);
  });
  test('Ende-Feld nur beim Bearbeiten', () {
    final i = s.indexOf("labelText: 'Ende'");
    expect(i, greaterThan(-1));
    expect(s.substring(i - 400, i).contains('if (_isEdit)'), isTrue);
  });
}
```
- [ ] **Schritt 2: FAIL bestätigen.**
- [ ] **Schritt 3: Umbauen**
  - Checkbox «Wasser im Kühler gewechselt» (Zeilen ~1892–1902) samt `SizedBox` davor entfernen. `_wasserKuehlerGewechselt` bleibt als Feld (wird geladen und zurückgeschrieben, damit Altdaten nicht kippen).
  - «Ende»-`TextFormField` (Zeilen ~1845–1855) in `if (_isEdit) ...[ const SizedBox(width: 8), Expanded(...) ]` hüllen; beim Start bleibt nur «Start». Beim Abschluss setzt `_save` das Ende ohnehin (`r.uhrzeitEnde ??= …`).
  - HeiGenie-Dropdown-Eintrag (Zeile ~2437) entfernen (falls in Task 3 noch nicht geschehen).
  - Knöpfe (Zeilen ~1975–2010) ersetzen:
```dart
              if (_isEdit) ...[
                TapKnopf(
                  text: 'Speichern',
                  icon: Icons.save,
                  laeuft: _isLoading,
                  onTap: _isLoading ? null : () => _save(),
                ),
                if (_status == 'offen') ...[
                  const SizedBox(height: 12),
                  TapKnopf(
                    text: 'Reinigung abschliessen',
                    icon: Icons.check_circle,
                    primaer: false,
                    onTap: _isLoading ? null : _showAbschlussDialog,
                  ),
                ],
              ] else
                TapKnopf(
                  text: _istHeinekenMonteur ? 'Heineken-Monteur erfassen' : 'Reinigung abschliessen',
                  icon: Icons.check_circle,
                  laeuft: _isLoading,
                  onTap: _isLoading ? null : _showAbschlussDialog,
                ),
```
  - Dialog-Aktionen (Zeilen ~1594–1602): `TextButton` → `TapKnopf(text: 'Abbrechen', primaer: false, onTap: () => Navigator.pop(ctx, false))`, `FilledButton.icon` → `TapKnopf(text: 'Abschliessen', icon: Icons.check_circle, onTap: () => Navigator.pop(ctx, true))`.
  - Foto-Knöpfe «Digitalisieren»/«Hochladen» (Zeilen ~1914–1935): `FilledButton.icon`/`OutlinedButton.icon` → `TapKnopf(text: 'Digitalisieren', icon: Icons.document_scanner, onTap: …)` und `TapKnopf(text: 'Hochladen', icon: Icons.upload_file, primaer: false, onTap: …)` in derselben `Row`/`Expanded`-Struktur.
  - `TapKnopf`-Signatur: `lib/presentation/widgets/tap_knopf.dart` (`text`, `onTap`, `primaer`, `icon`, `laeuft`, `gefahr`). Lässt `TapKnopf` keine `height: 56` zu, die `SizedBox` weglassen.
- [ ] **Schritt 4:** `flutter test` (auch `canvaskit_sichere_widgets_test.dart`, `gefahr_knopf_waechter_test.dart`) + `flutter analyze`.
- [ ] **Schritt 5: Commit** `refactor(reinigungen): Formular entruempelt, Knoepfe CanvasKit-sicher (T6)`.

---

### Task 6: Browser-Prüfung, Release v0.140.0

**Files:** `sbs_projer_app/pubspec.yaml:4`, `sbs_projer_app/lib/core/app_version.dart:12`, `docs/chronik.md`, `ToDo.md`, `Projekt.md`, `docs/app-analyse-2026-09-25.md` (§6 Runde 2 teilweise).

- [ ] **Schritt 1: Lokaler Build und Browser** (Controller mit Browser-Pane; Nutzer ist angemeldet): `flutter build web --base-href "/"` und lokal servieren wie am 25.09. (Port 8080). Prüfen:
  1. Reinigung → **neu** bei einem Testbetrieb (Kulanz an, damit keine Rechnung entsteht): Foto aus Datei «Hochladen» → Fortschrittsbalken, kein Fehlerband; Abschliessen-Knopf ist `TapKnopf`; Snackbar «Reinigung abgeschlossen».
  2. Dieselbe Reinigung **bearbeiten**: nur Notiz ändern → Speichern → keine Korrektur-Snackbar; Kulanz ausschalten (preisrelevant) → Speichern → Korrektur läuft ohne Sperre (Rechnung offen, unversendet).
  3. Eine **bezahlte** Reinigung von Juli bearbeiten: Band «ist bereits bezahlt» sichtbar; Grundtarif ändern → Speichern → Dialog «Änderung nicht möglich», nichts gespeichert.
  4. Reinigungsdetail einer bezahlten Reinigung → Löschen → rote Snackbar, nichts gelöscht.
  5. Testreinigung wieder löschen (Detail → Löschen, Sperre keine): Buchung storniert (Journal zeigt Storno-Paar), Rechnung weg.
  Screenshot je Fall ins Scratchpad; Befund kurz in ToDo.md.
- [ ] **Schritt 2: Version** `0.140.0+793` in `pubspec.yaml` Zeile 4 und `kAppVersion = '0.140.0'` in `app_version.dart` Zeile 12; `flutter test test/app_version_test.dart`.
- [ ] **Schritt 3: Doku:** Chronik-Eintrag «26.09.2026 — v0.140.0 Analyse-Runde 2 Teil 1: eine Abschlusskette (R1, T1, T5, T6)» mit Index-Zeile oben; ToDo.md Stand-Zeile + Klicktest v0.140.0 (Foto am Handy: Kamera → Fortschritt → Abschluss; bezahlte Reinigung bearbeiten → Band; Aufgaben-Screen zeigt «Reinigung ohne Protokollfoto», sobald eine ohne Foto abgeschlossen wurde); Projekt.md Stand-Zeile; Analyse §6 Zeile Runde 2 «Teil 1 (Kette) live v0.140.0».
- [ ] **Schritt 4: Commit + Push main, Deploy gh-pages** nach CLAUDE.md-Rezept (`--base-href "/sbs-projer-dev/" --pwa-strategy=none`, Cache-Bust, `flutter_service_worker.js` löschen, `404.html` mit), Live-`version.json` = 0.140.0 prüfen.

---

### Task 7: Betriebsferien aus `betrieb_ferien` pflegen und lesen (R7) — v0.141.0

**Files:**
- Create: `sbs_projer_app/lib/presentation/widgets/betrieb_ferien_liste.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart` (Zeilen 80–82, 180–204, 572–581, 1449–1514)
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart` (Zeilen 51, 251–274)
- Modify: `sbs_projer_app/lib/presentation/screens/heineken/heineken_raster_screen.dart:43` (Ferien aus der Tabelle)
- Test: `sbs_projer_app/test/ferien_quelle_waechter_test.dart`, `sbs_projer_app/test/betrieb_ferien_liste_test.dart`

- [ ] **Schritt 1: Tests**

  `test/ferien_quelle_waechter_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// R7 (Analyse 25.09.2026): Formular schrieb die 5 Altspalten, Tourenplan las
/// `betrieb_ferien` — drei Perioden fehlten in der Planung. Ab v0.141.0 ist
/// die Tabelle die einzige gepflegte Quelle; Formular, Detail und Raster
/// lesen und schreiben nur noch sie.
void main() {
  String lies(String p) => File(p).readAsStringSync();
  test('Formular schreibt keine Altspalten mehr', () {
    final s = lies('lib/presentation/screens/betriebe/betrieb_form_screen.dart');
    for (final alt in ['ferienStart =', 'ferien2Start', 'ferien3Start', 'ferien4Start', 'ferien5Start', '_ferienStarts']) {
      expect(s.contains(alt), isFalse, reason: alt);
    }
    expect(s.contains('BetriebFerienListe('), isTrue);
  });
  test('Detail und Raster lesen die Tabelle', () {
    expect(lies('lib/presentation/screens/betriebe/betrieb_detail_screen.dart').contains('BetriebFerienListe('), isTrue);
    expect(lies('lib/presentation/screens/heineken/heineken_raster_screen.dart').contains('ferienPeriodenProvider'), isTrue);
  });
}
```
  `test/betrieb_ferien_liste_test.dart` (reine Helfer des Widgets):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb_ferien_liste.dart';

void main() {
  test('quelleLabel', () {
    expect(quelleLabel('kunde'), 'Kunde');
    expect(quelleLabel('vor_ort'), 'vor Ort');
    expect(quelleLabel('website'), 'Website');
    expect(quelleLabel('google'), 'Google');
    expect(quelleLabel('import'), 'Altbestand');
    expect(quelleLabel('x'), 'x');
  });
  test('periodeText: gleiches Jahr kurz, sonst mit Jahr', () {
    expect(periodeText(DateTime(2026, 10, 11), DateTime(2026, 11, 4)), '11.10. – 04.11.2026');
    expect(periodeText(DateTime(2026, 12, 20), DateTime(2027, 1, 5)), '20.12.2026 – 05.01.2027');
  });
  test('periodenSortiert: kuenftige zuerst aufsteigend, vergangene danach absteigend', () {
    final heute = DateTime(2026, 9, 26);
    final p = [
      (von: DateTime(2026, 1, 1), bis: DateTime(2026, 1, 10)),
      (von: DateTime(2026, 12, 1), bis: DateTime(2026, 12, 26)),
      (von: DateTime(2026, 10, 11), bis: DateTime(2026, 11, 4)),
      (von: DateTime(2025, 12, 20), bis: DateTime(2026, 1, 5)),
    ];
    final s = periodenSortiert(p, heute: heute);
    expect(s.map((e) => e.von.month).toList(), [10, 12, 1, 12]);
  });
}
```

- [ ] **Schritt 2: FAIL bestätigen.**

- [ ] **Schritt 3: Widget** (`lib/presentation/widgets/betrieb_ferien_liste.dart`)
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_colors.dart';
import 'package:sbs_projer_app/core/util/war_geschlossen.dart'; // standardFerienfenster
import 'package:sbs_projer_app/data/local/betrieb_ferien_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/gefahr_rueckfrage.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

String quelleLabel(String q) => switch (q) {
      'kunde' => 'Kunde',
      'vor_ort' => 'vor Ort',
      'website' => 'Website',
      'google' => 'Google',
      'import' => 'Altbestand',
      _ => q,
    };

String _dd(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

String periodeText(DateTime von, DateTime bis) => von.year == bis.year
    ? '${_dd(von)} – ${_dd(bis)}${bis.year}'
    : '${_dd(von)}${von.year} – ${_dd(bis)}${bis.year}';

/// Künftige/laufende Perioden zuerst (aufsteigend), vergangene danach
/// (jüngste zuerst) — was als Nächstes kommt, steht oben.
List<T> periodenSortiert<T extends ({DateTime von, DateTime bis})>(
  List<T> perioden, {
  required DateTime heute,
}) {
  final tag = DateTime(heute.year, heute.month, heute.day);
  final kommend = perioden.where((p) => !p.bis.isBefore(tag)).toList()
    ..sort((a, b) => a.von.compareTo(b.von));
  final vorbei = perioden.where((p) => p.bis.isBefore(tag)).toList()
    ..sort((a, b) => b.von.compareTo(a.von));
  return [...kommend, ...vorbei];
}

/// Liste der Ferienperioden eines Betriebs aus `betrieb_ferien` mit
/// «+ Ferien» und Löschen. Formular und Detail nutzen dasselbe Widget.
class BetriebFerienListe extends ConsumerStatefulWidget {
  final String betriebId;
  final bool bearbeitbar;
  const BetriebFerienListe({super.key, required this.betriebId, this.bearbeitbar = true});

  @override
  ConsumerState<BetriebFerienListe> createState() => _BetriebFerienListeState();
}

class _BetriebFerienListeState extends ConsumerState<BetriebFerienListe> {
  List<BetriebFerienLocal> _perioden = const [];
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    try {
      final p = await BetriebFerienRepository.getFuerBetrieb(widget.betriebId);
      if (mounted) setState(() { _perioden = p; _laedt = false; });
    } catch (_) {
      if (mounted) setState(() => _laedt = false);
    }
  }

  void _invalidieren() {
    ref.invalidate(ferienPeriodenProvider);
    ref.invalidate(betriebeStreamProvider);
  }

  Future<void> _neu() async {
    final erg = await showDialog<({DateTime von, DateTime bis})>(
      context: context,
      builder: (_) => const _FerienDialog(),
    );
    if (erg == null) return;
    await BetriebFerienRepository.periodeErfassen(
      betriebId: widget.betriebId, von: erg.von, bis: erg.bis, quelle: 'kunde',
    );
    _invalidieren();
    await _laden();
  }

  Future<void> _loeschen(BetriebFerienLocal f) async {
    final ok = await gefahrRueckfrage(
      context,
      titel: 'Ferien löschen?',
      text: '${periodeText(f.von, f.bis)} wird entfernt. Der Tourenplan zeigt den Betrieb dann wieder als offen.',
      bestaetigen: 'Löschen',
    );
    if (!ok) return;
    await BetriebFerienRepository.loeschen(kIsWeb ? f.serverId! : f.id.toString());
    _invalidieren();
    await _laden();
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const LinearProgressIndicator();
    final sortiert = periodenSortiert(
      [for (final f in _perioden) (von: f.von, bis: f.bis, f: f)],
      heute: DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sortiert.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('Keine Ferien erfasst')),
        for (final e in sortiert)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(periodeText(e.von, e.bis), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(quelleLabel(e.f.quelle), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (widget.bearbeitbar)
                  InkWell(
                    onTap: () => _loeschen(e.f),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        if (widget.bearbeitbar)
          TapKnopf(text: '+ Ferien', primaer: false, onTap: _neu),
      ],
    );
  }
}

class _FerienDialog extends StatefulWidget {
  const _FerienDialog();
  @override
  State<_FerienDialog> createState() => _FerienDialogState();
}

class _FerienDialogState extends State<_FerienDialog> {
  late DateTime _von;
  late DateTime _bis;

  @override
  void initState() {
    super.initState();
    final f = standardFerienfenster();
    _von = f.von;
    _bis = f.bis;
  }

  Future<void> _waehlen({required bool istVon}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: istVon ? _von : _bis,
      firstDate: DateTime(2019),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null) return;
    setState(() {
      if (istVon) { _von = d; if (_bis.isBefore(_von)) _bis = _von; } else { _bis = d; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Betriebsferien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DatumZeile(label: 'Von', wert: _von, onTap: () => _waehlen(istVon: true)),
          const SizedBox(height: 8),
          _DatumZeile(label: 'Bis', wert: _bis, onTap: () => _waehlen(istVon: false)),
        ],
      ),
      actions: [
        TapKnopf(text: 'Abbrechen', primaer: false, onTap: () => Navigator.pop(context)),
        TapKnopf(
          text: 'Speichern',
          onTap: _bis.isBefore(_von) ? null : () => Navigator.pop(context, (von: _von, bis: _bis)),
        ),
      ],
    );
  }
}

class _DatumZeile extends StatelessWidget {
  final String label;
  final DateTime wert;
  final VoidCallback onTap;
  const _DatumZeile({required this.label, required this.wert, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true),
          child: Text('${_dd(wert)}${wert.year}'),
        ),
      );
}
```
  `standardFerienfenster()` — Datei per grep finden (`war_geschlossen_sheet.dart:65` importiert sie); Import anpassen. Das Record-mit-Feld `f` in `periodenSortiert` funktioniert, weil `T extends ({DateTime von, DateTime bis})` Records mit Zusatzfeldern zulässt; falls der Analyzer meckert, `periodenSortiert` auf `List<BetriebFerienLocal>` mit `von/bis`-Gettern umstellen und den Test anpassen.

- [ ] **Schritt 4: Formular** (`betrieb_form_screen.dart`): `_ferienStarts`, `_ferienEnden`, `_ferienZeilen` (Zeilen 80–82) löschen; Laden (180–204) auf `_keineBetriebsferien = betrieb.keineBetriebsferien;` reduzieren; Schreiben (572–581) löschen (nur `betrieb.keineBetriebsferien = _keineBetriebsferien;` bleibt); UI (1476–1514) ersetzen:
```dart
              if (!_keineBetriebsferien) ...[
                if (widget.betriebId != null && _betriebServerId != null)
                  BetriebFerienListe(betriebId: _betriebServerId!)
                else
                  const Text('Ferien lassen sich nach dem ersten Speichern erfassen.'),
              ],
```
  `_betriebServerId`: beim Laden aus `betrieb.serverId` setzen (Feld `String? _betriebServerId;`). Der Schalter «Keine Betriebsferien» bleibt; sein `onChanged` setzt nur noch `_keineBetriebsferien` (Perioden werden nicht gelöscht, nur ausgeblendet — `keineBetriebsferien` prüfen alle Leser separat). Prüfen, ob `_DatePickerField` noch andere Aufrufer hat; sonst löschen.

- [ ] **Schritt 5: Detail** (`betrieb_detail_screen.dart:251-274`): Bedingung `ferienStarts(betrieb).isNotEmpty` entfernen, Sektion immer zeigen, wenn Ruhetage oder `keineBetriebsferien` oder `betrieb.serverId != null`; Ferienzeilen ersetzen durch `if (!betrieb.keineBetriebsferien && betrieb.serverId != null) BetriebFerienListe(betriebId: betrieb.serverId!, bearbeitbar: false)`. Import `betrieb_ferien.dart` entfernen, wenn `ferienSlots`/`ferienStarts` dort nicht mehr gebraucht werden.

- [ ] **Schritt 6: Heineken-Raster** (`heineken_raster_screen.dart:43`): nach `BetriebRepository.getAll()` die Perioden setzen:
```dart
      final allBetriebe = await BetriebRepository.getAll();
      // Ferien aus der Tabelle — sonst liest ferienSlots die eingefrorenen
      // Altspalten (Analyse R7, Erkundung 26.09.2026).
      final ferienMap = await ref.read(ferienPeriodenProvider.future);
      for (final b in allBetriebe) {
        final id = b.serverId;
        if (id != null) b.ferienPerioden = ferienMap[id] ?? const [];
      }
```
  Import `betrieb_providers.dart`.

- [ ] **Schritt 7:** `flutter test` + `flutter analyze`; Tests `betrieb_ferien_test.dart`, `touren_saison_test.dart`, `ferien_vorjahr_test.dart` müssen unverändert grün bleiben.
- [ ] **Schritt 8: ToDo-Notiz** (kein Code): «Altspalten `ferien*_start/ende` entfernen (Model, Mapper, Local, Web-Stub, `build_runner`, Migration 208 `ALTER TABLE betriebe DROP COLUMN …`) — erst nachdem `getById`-Leser (`core/util/betrieb_reinigung.dart:57` Aufrufer) auf die Tabelle umgestellt sind; bis dahin frieren die Spalten auf dem Stand 31.07.2026 ein und der Fallback in `ferienSlots` zeigt für solche Leser veraltete Ferien.»
- [ ] **Schritt 9: Commit** `feat(betriebe): Ferien aus betrieb_ferien pflegen und lesen — Formular, Detail, Raster (R7)`.

---

### Task 8: Browser-Prüfung, Release v0.141.0

- [ ] **Schritt 1: Browser** (lokaler Build wie Task 6): Betrieb Surselva Disentis → Bearbeiten → Sektion Betriebsferien zeigt «11.10. – 04.11.2026 · Kunde/Altbestand»; «+ Ferien» → Dialog → Speichern → Zeile erscheint; Löschen → Rückfrage → weg; Detail zeigt dieselbe Liste; Heineken-Raster (Heineken → Serviceraster) für Oktober zeigt Disentis als Ferien. Screenshots ins Scratchpad.
- [ ] **Schritt 2: Version** `0.141.0+794` / `kAppVersion '0.141.0'`; `flutter test test/app_version_test.dart`.
- [ ] **Schritt 3: Doku:** Chronik «26.09.2026 — v0.141.0 Betriebsferien aus der Tabelle (R7)»; ToDo Stand + Klicktest (Ferien am Handy anlegen/löschen; Tourenplan zeigt Betrieb im Fenster als Ferien) + Notiz aus Task 7 Schritt 8; Projekt.md Stand; Analyse §6 Runde 2 «✅ erledigt 26.09.2026, live v0.141.0»; Memory `app_analyse_2026_09_25.md` + MEMORY.md-Zeile (Runde 2 erledigt, nächst Runde 3 ZahlungKern — Plan mit Fable).
- [ ] **Schritt 4: Commit + Push main, Deploy gh-pages, Live-Version 0.141.0 prüfen.**

---

## Selbstprüfung (Controller)

- **Abdeckung:** R1 → Task 1+2; Abschlusskette Screen→Service → Task 3; T1 → Task 4; T5 → Task 3 Schritt 5.3 + Wächter; T6 → Task 5 (+ HeiGenie in Task 3); R7 → Task 7. Releases → Task 6 + 8.
- **Namen konsistent:** `KorrekturSperre`, `korrekturSperre(...)`, `sperrText(...)`, `preisrelevantGeaendert(...)` (Task 1) ↔ Task 2; `KorrekturStand`, `sperrePruefen`, `zuruecknehmen`, `korrigieren` (Task 2) ↔ Formular/Detail; `ReinigungAbschlussService.abschliessen`, `AbschlussErgebnis`, `AbschlussMeldung`, `AbschlussStufe`, `abschlussSnackbarText` (Task 3) ↔ Wächter/Detail; `_fotoHochladen`, `_fotoFehler`, `_hochgeladenerPfad`, `_fotoReinigungId` (Task 4); `protokollFehltAufgabe`, `protokollPflichtAb` (Task 4); `BetriebFerienListe`, `quelleLabel`, `periodeText`, `periodenSortiert` (Task 7).
- **Risiken für den Implementer:** (a) `widget.reinigungId` ist auf Web die UUID — verifizieren (Task 4). (b) `belegIdsMitBuchung` und stornierte Zeilen (Task 2 Schritt 4). (c) Wächter-Tests mit festen Dateilisten (`versandvermerk_waechter_test.dart`, `canvaskit_sichere_widgets_test.dart`) nach dem Umbau prüfen. (d) `TapKnopf` kennt evtl. kein `icon`-Feld in Kombination mit `laeuft` — Signatur lesen.
