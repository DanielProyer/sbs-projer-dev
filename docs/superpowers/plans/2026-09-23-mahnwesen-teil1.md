# Mahnwesen Teil 1 (Mahnlauf) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mahnlauf mit Sammelmahnung pro Betrieb (oder einzelner Rechnung), vier Sicherungen gegen das Mahnen bezahlter Rechnungen, Mahnschreiben mit QR je Rechnung, Beilagen, Mail oder Druck-PDF — alles im Testmodus. Auslieferung v0.134.0.

**Architecture:** Die Regeln (wer ins Mahnsystem gehört, welche Stufe fällig ist, welche Sperre greift) sind reine Funktionen in `lib/core/util/mahnregeln.dart`. Ein `MahnlaufService` erzeugt Schreiben (PDF), legt sie ab, setzt die Stufen, protokolliert in `mahnschreiben` und verschickt über `send-rechnung-mail` (neu mit Zusatz-Anhängen). Die Mahnlauf-Seite zeigt Vorschläge je Betrieb.

**Tech Stack:** Flutter (CanvasKit-Web), Riverpod, GoRouter, `pdf`-Paket via `pdfDokument()`, Supabase (Postgres, Storage `rechnung-pdfs`, Edge Function Deno).

**Spec:** `docs/superpowers/specs/2026-09-23-mahnwesen-design.md` (Abschnitte 1–4, 7, 9). **Recherche:** `docs/buchhaltung/mahnwesen-recherche-2026-09-23.md`.

---

## Vorab für den Ausführenden

- Flutter-Befehle in `sbs_projer_app/`, Git Bash: `export PATH="$PATH:/c/flutter/bin"`.
- `flutter analyze` steht bei **56** und muss gleich bleiben. Volle Suite vorher: **1918 grün**.
- **CanvasKit-Regel (CLAUDE.md):** keine `FilledButton/OutlinedButton/ElevatedButton/ListTile/ExpansionTile(dense)/TabBar` in neuen Widgets; Knöpfe über `TapKnopf`, Zeilen aus `InkWell`/`GestureDetector` + `Container` + `Row`.
- **PDF nur über `pdfDokument()`** (Wächter `pdf_schrift_test.dart`). Tests mit PDF brauchen `TestWidgetsFlutterBinding.ensureInitialized()`.
- **Zeitauswahl nur über `zeigeZeitauswahl`** (Wächter), Datumsdifferenzen in UTC-Tagen.
- **`MailConfig.mahnwesenScharf` bleibt `false`.** Nicht ändern.
- Keine null-aware Collection-Elemente (`?x` in Listen).
- Nie `git stash`; direkt auf `main` committen, nicht pushen. Commit-Nachrichten enden mit
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Migrationen und Edge-Function-Deploy macht der Controller**, nicht der Subagent: Datei schreiben, im Bericht melden.

## Abweichungen von der Spec (bewusst)

- **Druck-PDF ohne Rechnungskopien:** Die gespeicherten Rechnungs-PDFs lassen sich im Browser nicht in ein erzeugtes PDF einfügen. Das Druck-PDF enthält Mahnschreiben, QR-Zahlteil je Rechnung und (bei mehreren Rechnungen) den Kontoauszug. Die Mail hängt die Rechnungskopien weiterhin an.
- **`ForderungService` entfällt:** Die alte Regel (5/25/30 Tage) wird vollständig durch `mahnregeln.dart` ersetzt (Liste, Detektor).

## Dateien

| Datei | Aufgabe |
|---|---|
| `Datenbank/migrations/200_mahnwesen_mahnlauf.sql` | **neu**: `rechnungen.mahn_frist_bis`, Tabelle `mahnschreiben` |
| `lib/data/models/rechnung.dart` | ändern: Feld `mahnFristBis` |
| `lib/core/util/mahnregeln.dart` | **neu**: Regeln (rein) |
| `lib/services/pdf/kontoauszug_pdf_service.dart` | ändern: `seitenHinzufuegen` herauslösen |
| `lib/services/pdf/mahnschreiben_pdf_service.dart` | **neu**: Sammelschreiben |
| `supabase/functions/send-rechnung-mail/index.ts` | ändern: `zusatzPdfs` |
| `lib/data/models/mahnschreiben.dart`, `lib/data/repositories/mahnschreiben_repository.dart` | **neu** |
| `lib/services/rechnung/mahnlauf_service.dart` | **neu**: erstellen, versenden, zurücknehmen |
| `lib/presentation/providers/mahnlauf_provider.dart` | **neu** |
| `lib/presentation/screens/rechnungen/mahnlauf_screen.dart` | **neu** |
| `lib/presentation/screens/rechnungen/rechnungen_list_screen.dart`, `rechnung_detail_screen.dart`, `lib/presentation/providers/aufgaben_detektoren_provider.dart`, `lib/core/config/router.dart` | ändern |
| `lib/services/rechnung/forderung_service.dart`, `lib/services/rechnung/mahnwesen_service.dart` (nur `eskalieren`), `lib/services/pdf/mahnung_pdf_service.dart` | entfernen/ersetzen (Task 6) |

---

## Task 1: Migration und Modellfeld

**Files:**
- Create: `Datenbank/migrations/200_mahnwesen_mahnlauf.sql`
- Modify: `lib/data/models/rechnung.dart`

- [ ] **Step 1: Migration schreiben** (Controller spielt sie ein)

```sql
-- 200: Mahnwesen Teil 1 — Frist je Rechnung und Protokoll je Mahnschreiben
--
-- ANLASS (Daniel, 23.09.2026): Das Mahnwesen wird neu aufgebaut
-- (docs/superpowers/specs/2026-09-23-mahnwesen-design.md). Bisher kannte
-- eine Rechnung ihre Mahnstufe und deren Datum, aber nicht die im Schreiben
-- gesetzte Frist — die nächste Stufe liess sich nicht verlässlich
-- bestimmen. Und es gab kein Protokoll, wer wann welches Schreiben bekam;
-- ohne das lässt sich eine (Test-)Mahnung nicht sauber zurücknehmen.

ALTER TABLE public.rechnungen
  ADD COLUMN IF NOT EXISTS mahn_frist_bis date;

COMMENT ON COLUMN public.rechnungen.mahn_frist_bis IS
  'Im letzten Mahnschreiben gesetzte Zahlungsfrist (Versanddatum + 10 Tage). '
  'Grundlage für die Fälligkeit der nächsten Stufe (+5 Tage).';

CREATE TABLE public.mahnschreiben (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id),
  betrieb_id        uuid NOT NULL REFERENCES public.betriebe(id) ON DELETE CASCADE,
  stufe             integer NOT NULL CHECK (stufe BETWEEN 0 AND 2),
  rechnung_ids      uuid[] NOT NULL,
  kanal             text NOT NULL CHECK (kanal IN ('mail', 'druck', 'mail_und_druck')),
  empfaenger        text,
  test              boolean NOT NULL DEFAULT true,
  frist_bis         date NOT NULL,
  pdf_pfad          text,
  -- Zustand der Rechnungen VOR dem Schreiben, je Rechnung:
  -- {"<id>": {"zahlungsstatus": …, "mahnung_stufe": …, "letzte_mahnung_am": …,
  --           "erinnerung_am": …, "mahnung_1_am": …, "mahnung_2_am": …,
  --           "mahn_frist_bis": …}}
  -- Grundlage für «Mahnung zurücknehmen».
  vorher            jsonb NOT NULL,
  erstellt_am       timestamptz NOT NULL DEFAULT now(),
  zurueckgenommen_am timestamptz
);

CREATE INDEX mahnschreiben_betrieb_idx ON public.mahnschreiben (betrieb_id, erstellt_am DESC);

ALTER TABLE public.mahnschreiben ENABLE ROW LEVEL SECURITY;
CREATE POLICY mahnschreiben_select ON public.mahnschreiben
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY mahnschreiben_insert ON public.mahnschreiben
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY mahnschreiben_update ON public.mahnschreiben
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY mahnschreiben_delete ON public.mahnschreiben
  FOR DELETE USING (user_id = auth.uid());
```

- [ ] **Step 2: Modellfeld**

In `lib/data/models/rechnung.dart` ein Feld `final DateTime? mahnFristBis;` ergänzen — im Konstruktor, in `fromJson` (`json['mahn_frist_bis'] != null ? DateTime.parse(json['mahn_frist_bis']) : null`, gleich wie die anderen Datumsfelder dort), in `toJson` (`'mahn_frist_bis'`, Datumsteil wie `erinnerung_am`) und in `copyWith`, falls vorhanden. Den bestehenden Stil der Datei genau übernehmen. Prüfen, ob es ein lokales Isar-Modell für Rechnungen gibt (`lib/data/local/*rechnung*`): laut Stand nur `betrieb_rechnungsadresse_local` — dann entfällt es.

- [ ] **Step 3: Test, Analyse, Commit**

`flutter test && flutter analyze` → grün, 56.

```bash
git add Datenbank/migrations/200_mahnwesen_mahnlauf.sql sbs_projer_app/lib/data/models/rechnung.dart
git commit -m "feat(mahnwesen): Migration 200 (mahn_frist_bis, mahnschreiben), Modellfeld

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 2: Mahnregeln (TDD, rein)

**Files:**
- Create: `lib/core/util/mahnregeln.dart`
- Test: `test/mahnregeln_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _r({
  String id = 'r1',
  String typ = 'kundenrechnung',
  required DateTime datum,
  DateTime? faellig,
  String status = 'offen',
  String? versandart = 'rechnung_mail',
  DateTime? versendet,
  DateTime? uebergeben,
  DateTime? erinnerung,
  DateTime? mahnung1,
  DateTime? mahnung2,
  DateTime? frist,
  double brutto = 94.05,
}) =>
    Rechnung.fromJson({
      'id': id,
      'user_id': 'u',
      'rechnungsnummer': 'NR-$id',
      'rechnungstyp': typ,
      'betrieb_id': 'b1',
      'rechnungsdatum': datum.toIso8601String().split('T').first,
      'faelligkeitsdatum': (faellig ?? datum.add(const Duration(days: 30)))
          .toIso8601String()
          .split('T')
          .first,
      'betrag_netto': brutto / 1.081,
      'mwst_betrag': brutto - brutto / 1.081,
      'betrag_brutto': brutto,
      'zahlungsstatus': status,
      'versandart': versandart,
      'versendet_am': versendet?.toIso8601String().split('T').first,
      'uebergeben_am': uebergeben?.toIso8601String().split('T').first,
      'erinnerung_am': erinnerung?.toIso8601String().split('T').first,
      'mahnung_1_am': mahnung1?.toIso8601String().split('T').first,
      'mahnung_2_am': mahnung2?.toIso8601String().split('T').first,
      'mahn_frist_bis': frist?.toIso8601String().split('T').first,
      'mahnung_stufe': 0,
    });

void main() {
  final d = DateTime.utc;

  group('imMahnbereich / zugestellt', () {
    test('Altlast vor 2026 nie', () {
      expect(imMahnbereich(_r(datum: d(2025, 12, 31), versendet: d(2026, 1, 1))), isFalse);
      expect(imMahnbereich(_r(datum: d(2026, 1, 1), versendet: d(2026, 1, 1))), isTrue);
    });
    test('Heineken-Monatsrechnung, bezahlt, abgeschrieben nie', () {
      expect(imMahnbereich(_r(typ: 'heineken_monat', datum: d(2026, 5, 1))), isFalse);
      expect(imMahnbereich(_r(status: 'bezahlt', datum: d(2026, 5, 1))), isFalse);
      expect(imMahnbereich(_r(status: 'abgeschrieben', datum: d(2026, 5, 1))), isFalse);
    });
    test('Jahresrechnung zaehlt', () {
      expect(imMahnbereich(_r(typ: 'jahresrechnung', datum: d(2026, 5, 1))), isTrue);
    });
    test('zugestellt: Mail, Uebergabe oder Versandart Tresen (Entscheid 23.09.)', () {
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versendet: d(2026, 5, 2))), isTrue);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_mail', uebergeben: d(2026, 5, 1))), isTrue);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_tresen')), isTrue);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_mail')), isFalse);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_post')), isFalse);
    });
    test('Zustelldatum: Mail, dann Uebergabe, dann Rechnungsdatum', () {
      expect(zustelldatum(_r(datum: d(2026, 5, 1), versendet: d(2026, 6, 9))), d(2026, 6, 9));
      expect(zustelldatum(_r(datum: d(2026, 5, 1), versandart: 'rechnung_tresen')), d(2026, 5, 1));
    });
  });

  group('massgebendeFaelligkeit', () {
    test('normal: Faelligkeitsdatum', () {
      final r = _r(datum: d(2026, 8, 1), versendet: d(2026, 8, 1));
      expect(massgebendeFaelligkeit(r), d(2026, 8, 31));
    });
    test('nachtraeglich zugestellt: Zustellung + 30 Tage', () {
      final r = _r(datum: d(2026, 5, 8), versendet: d(2026, 9, 23));
      expect(massgebendeFaelligkeit(r), d(2026, 10, 23));
    });
  });

  group('faelligeStufe (Stichtag = Bankauszug)', () {
    // Faellig 31.08.; Erinnerung faellig ab 10.09.; mit Puffer 3 Tage
    // braucht es einen Auszug bis mindestens 13.09.
    final r = _r(datum: d(2026, 8, 1), versendet: d(2026, 8, 1));

    test('Erinnerung erst, wenn Faelligkeit + 10 mindestens 3 Tage vor Stichtag', () {
      expect(faelligeStufe(r, stichtag: d(2026, 9, 12)), isNull);
      expect(faelligeStufe(r, stichtag: d(2026, 9, 13)), MahnStufe.erinnerung);
    });

    test('1. Mahnung: Frist der Erinnerung + 5, mit Puffer', () {
      final e = _r(
        datum: d(2026, 8, 1),
        versendet: d(2026, 8, 1),
        status: 'erinnert',
        erinnerung: d(2026, 9, 15),
        frist: d(2026, 9, 25),
      );
      expect(faelligeStufe(e, stichtag: d(2026, 10, 2)), isNull);
      expect(faelligeStufe(e, stichtag: d(2026, 10, 3)), MahnStufe.mahnung1);
    });

    test('ohne gespeicherte Frist: Stufendatum + 10', () {
      final e = _r(
        datum: d(2026, 8, 1),
        versendet: d(2026, 8, 1),
        status: 'mahnung_1',
        mahnung1: d(2026, 9, 1),
      );
      // Frist 11.09. + 5 = 16.09. + 3 Puffer = 19.09.
      expect(faelligeStufe(e, stichtag: d(2026, 9, 18)), isNull);
      expect(faelligeStufe(e, stichtag: d(2026, 9, 19)), MahnStufe.letzte);
    });

    test('nach letzter Mahnung: Teil 2 (Heineken) — hier keine Stufe', () {
      final e = _r(
        datum: d(2026, 5, 1),
        versendet: d(2026, 5, 1),
        status: 'mahnung_2',
        mahnung2: d(2026, 7, 1),
        frist: d(2026, 7, 11),
      );
      expect(faelligeStufe(e, stichtag: d(2026, 9, 20)), isNull);
    });

    test('nicht zugestellt oder Altlast: nie', () {
      expect(faelligeStufe(_r(datum: d(2026, 5, 1), versandart: 'rechnung_mail'), stichtag: d(2026, 9, 20)), isNull);
      expect(faelligeStufe(_r(datum: d(2025, 5, 1), versendet: d(2025, 5, 1)), stichtag: d(2026, 9, 20)), isNull);
    });
  });

  group('bankSperre', () {
    test('ohne Auszug gesperrt', () {
      expect(bankSperre(null, heute: d(2026, 9, 23)), isTrue);
    });
    test('hoechstens 2 Tage alt', () {
      expect(bankSperre(d(2026, 9, 21), heute: d(2026, 9, 23)), isFalse);
      expect(bankSperre(d(2026, 9, 20), heute: d(2026, 9, 23)), isTrue);
    });
  });

  group('gutschriftSperre', () {
    const g = (partei: 'BARBAR GMBH', betrag: 50.00);
    test('Zahlername passt (Alias oder Betriebsname)', () {
      expect(
        gutschriftSperre(
          betriebName: 'BarBar',
          aliase: const ['barbar gmbh'],
          offeneBetraege: const [94.05],
          gutschriften: const [g],
        ),
        isTrue,
      );
    });
    test('Betrag gleich einer Rechnung oder der Summe', () {
      const g2 = (partei: 'Unbekannt', betrag: 94.05);
      const g3 = (partei: 'Unbekannt', betrag: 188.10);
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05, 94.05], gutschriften: const [g2]),
        isTrue,
      );
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05, 94.05], gutschriften: const [g3]),
        isTrue,
      );
    });
    test('nichts passt: keine Sperre', () {
      const g4 = (partei: 'Fremd AG', betrag: 12.00);
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05], gutschriften: const [g4]),
        isFalse,
      );
    });
  });

  group('Schreiben', () {
    test('Titel = hoechste Stufe', () {
      expect(hoechsteStufe([MahnStufe.erinnerung, MahnStufe.letzte, MahnStufe.mahnung1]), MahnStufe.letzte);
    });
    test('Frist = Versand + 10 Tage', () {
      expect(mahnFrist(d(2026, 9, 23)), d(2026, 10, 3));
    });
    test('Stufen-Eigenschaften', () {
      expect(MahnStufe.erinnerung.wert, 0);
      expect(MahnStufe.letzte.status, 'mahnung_2');
      expect(MahnStufe.mahnung1.titel, '1. Mahnung');
      expect(MahnStufe.letzte.titel, 'Letzte Mahnung');
    });
  });
}
```

Run: `flutter test test/mahnregeln_test.dart` → FAIL (Datei fehlt).

- [ ] **Step 2: Implementieren**

`lib/core/util/mahnregeln.dart`:

```dart
/// Die Regeln des Mahnwesens (v0.134.0) — rein, ohne I/O.
///
/// WARUM rein: Hier entscheidet sich, ob ein Kunde gemahnt wird. Der Fehler,
/// den es um jeden Preis zu vermeiden gilt, ist eine Mahnung für Bezahltes
/// (Daniel 23.09.2026). Das muss ohne Datenbank und Widget prüfbar sein.
/// Spec: docs/superpowers/specs/2026-09-23-mahnwesen-design.md
library;

import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Rechnungen davor sind Altlast (jahrgangsweise Abschreibung, Entscheid
/// 19.09.2026) und kommen nie ins Mahnsystem.
final kMahnStart = DateTime.utc(2026, 1, 1);

/// Zahlungserinnerung frühestens so viele Tage nach Fälligkeit.
const kErinnerungNachTagen = 10;

/// Nächste Stufe frühestens so viele Tage nach Ablauf der gesetzten Frist.
const kNaechsteStufeNachFrist = 5;

/// Frist im Mahnschreiben.
const kMahnFristTage = 10;

/// Der Mahnlauf ist gesperrt, wenn der letzte Bankauszug älter ist.
const kAuszugHoechstensAltTage = 2;

/// Eine Stufe ist erst fällig, wenn ihre Bedingung so viele Tage VOR dem
/// Auszug-Stichtag erfüllt war — eine Zahlung vom letzten Fristtag steht
/// sicher im Auszug.
const kPufferVorStichtagTage = 3;

enum MahnStufe { erinnerung, mahnung1, letzte }

extension MahnStufeX on MahnStufe {
  int get wert => index;

  /// Wert von `rechnungen.zahlungsstatus` nach dieser Stufe.
  String get status => switch (this) {
        MahnStufe.erinnerung => 'erinnert',
        MahnStufe.mahnung1 => 'mahnung_1',
        MahnStufe.letzte => 'mahnung_2',
      };

  String get titel => switch (this) {
        MahnStufe.erinnerung => 'Zahlungserinnerung',
        MahnStufe.mahnung1 => '1. Mahnung',
        MahnStufe.letzte => 'Letzte Mahnung',
      };
}

DateTime _tag(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _plus(DateTime d, int tage) => _tag(d).add(Duration(days: tage));

bool imMahnbereich(Rechnung r) =>
    (r.rechnungstyp == 'kundenrechnung' || r.rechnungstyp == 'jahresrechnung') &&
    !_tag(r.rechnungsdatum).isBefore(kMahnStart) &&
    r.zahlungsstatus != 'bezahlt' &&
    r.zahlungsstatus != 'abgeschrieben';

/// Nachweislich beim Kunden: per Mail, am Tresen übergeben (mit Datum) oder
/// Versandart Tresen — das Übergabedatum wird erst seit v0.71.0 gespeichert,
/// davor gilt das Rechnungsdatum (Entscheid Daniel 23.09.2026).
bool istZugestellt(Rechnung r) =>
    r.versendetAm != null ||
    r.uebergebenAm != null ||
    r.versandart == 'rechnung_tresen';

DateTime zustelldatum(Rechnung r) =>
    _tag(r.versendetAm ?? r.uebergebenAm ?? r.rechnungsdatum);

/// Ist die Rechnung erst nach ihrem Fälligkeitsdatum zugestellt worden
/// (z. B. «erneut senden»), laufen die 30 Tage ab der Zustellung — sonst
/// würde eine eben zugestellte Rechnung sofort gemahnt.
DateTime massgebendeFaelligkeit(Rechnung r) {
  final z = zustelldatum(r);
  final f = _tag(r.faelligkeitsdatum);
  return z.isAfter(f) ? _plus(z, 30) : f;
}

/// Stufe, die jetzt fällig ist — oder null. [stichtag] ist das Ende des
/// letzten eingelesenen Bankauszugs, NICHT heute.
MahnStufe? faelligeStufe(Rechnung r, {required DateTime stichtag}) {
  if (!imMahnbereich(r) || !istZugestellt(r)) return null;
  final grenze = _plus(stichtag, -kPufferVorStichtagTage);
  bool erreicht(DateTime ab) => !ab.isAfter(grenze);

  switch (r.zahlungsstatus) {
    case 'erinnert':
      final frist = r.mahnFristBis ??
          (r.erinnerungAm != null ? _plus(r.erinnerungAm!, kMahnFristTage) : null);
      if (frist == null) return null;
      return erreicht(_plus(frist, kNaechsteStufeNachFrist)) ? MahnStufe.mahnung1 : null;
    case 'mahnung_1':
      final frist = r.mahnFristBis ??
          (r.mahnung1Am != null ? _plus(r.mahnung1Am!, kMahnFristTage) : null);
      if (frist == null) return null;
      return erreicht(_plus(frist, kNaechsteStufeNachFrist)) ? MahnStufe.letzte : null;
    case 'mahnung_2':
      return null; // weiter mit Heineken (Teil 2)
    default:
      return erreicht(_plus(massgebendeFaelligkeit(r), kErinnerungNachTagen))
          ? MahnStufe.erinnerung
          : null;
  }
}

bool bankSperre(DateTime? letzterAuszug, {required DateTime heute}) {
  if (letzterAuszug == null) return true;
  return _tag(heute).difference(_tag(letzterAuszug)).inDays > kAuszugHoechstensAltTage;
}

typedef OffeneGutschrift = ({String? partei, double betrag});

bool _gleich(double a, double b) => (a - b).abs() < 0.005;

/// Gibt es eine noch nicht zugeordnete Bankgutschrift, die zu diesem
/// Betrieb gehören könnte? Dann wird er nicht gemahnt.
///
/// Bewusst grosszügig: Ein Betrag, der zu irgendeiner offenen Rechnung
/// passt, sperrt — auch bei gängigen Preisen wie 94.05. Lieber ein Betrieb
/// zu viel zurückgehalten als eine Mahnung für Bezahltes.
bool gutschriftSperre({
  required String betriebName,
  required List<String> aliase,
  required List<double> offeneBetraege,
  required List<OffeneGutschrift> gutschriften,
}) {
  final namen = {
    zahlernameNorm(betriebName),
    for (final a in aliase) zahlernameNorm(a),
  }..remove('');
  final summe = offeneBetraege.fold<double>(0, (s, b) => s + b);
  for (final g in gutschriften) {
    final p = zahlernameNorm(g.partei ?? '');
    if (p.isNotEmpty && namen.contains(p)) return true;
    if (offeneBetraege.any((b) => _gleich(b, g.betrag))) return true;
    if (offeneBetraege.length > 1 && _gleich(summe, g.betrag)) return true;
  }
  return false;
}

MahnStufe hoechsteStufe(Iterable<MahnStufe> stufen) =>
    stufen.reduce((a, b) => a.index >= b.index ? a : b);

DateTime mahnFrist(DateTime versand) => _plus(versand, kMahnFristTage);
```

Hinweis: `zahlernameNorm` liegt in `lib/services/camt/zahlername.dart`; vorher prüfen, dass die Datei kein Flutter/Supabase importiert (sonst die Funktion nicht importieren, sondern die Normierung dort in eine reine Datei verschieben und re-exportieren). Der Test «Zahlername passt» erwartet, dass `zahlernameNorm('BARBAR GMBH') == zahlernameNorm('barbar gmbh')` — mit der echten Funktion prüfen und die Testdaten anpassen, falls die Normierung Rechtsformen entfernt (dann trifft auch `BarBar`).

- [ ] **Step 3: Tests**

Run: `flutter test test/mahnregeln_test.dart` → PASS.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/core/util/mahnregeln.dart sbs_projer_app/test/mahnregeln_test.dart
git commit -m "feat(mahnwesen): Mahnregeln als reine Funktionen mit Sicherungen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: Kontoauszug teilbar, Mahnschreiben-PDF

**Files:**
- Modify: `lib/services/pdf/kontoauszug_pdf_service.dart`
- Create: `lib/services/pdf/mahnschreiben_pdf_service.dart`
- Test: `test/mahnschreiben_pdf_test.dart`

- [ ] **Step 1: Kontoauszug-Seiten herauslösen**

In `KontoauszugPdfService` die Seiten-Erzeugung aus `generate` in eine öffentliche Methode ziehen, ohne Verhalten zu ändern:

```dart
  /// Hängt die Seiten des Kontoauszugs an [pdf] an — für das Druck-PDF des
  /// Mahnschreibens (v0.134.0), das Schreiben und Auszug in EINEM Dokument
  /// braucht. [generate] ruft das mit einem eigenen Dokument auf.
  static Future<void> seitenHinzufuegen(
    pw.Document pdf, {
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    BetriebRechnungsadresse? rechnungsadresse,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
    int? jahr,
  }) async { /* bisheriger Inhalt von generate ab `final dateFormat` bis vor `return pdf.save();` */ }

  static Future<Uint8List> generate({ /* gleiche Parameter */ }) async {
    final pdf = await pdfDokument();
    await seitenHinzufuegen(pdf, betrieb: betrieb, rechnungen: rechnungen,
        rechnungsadresse: rechnungsadresse, firmaName: firmaName,
        firmaStrasse: firmaStrasse, firmaPlzOrt: firmaPlzOrt,
        firmaMwst: firmaMwst, jahr: jahr);
    return pdf.save();
  }
```

Bestehende Tests des Kontoauszugs müssen unverändert grün bleiben.

- [ ] **Step 2: Failing test für das Mahnschreiben**

`test/mahnschreiben_pdf_test.dart` — prüft über die **reine** Textfunktion und darüber, dass `generate` ohne Fehler ein PDF liefert:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mahnText', () {
    final frist = DateTime.utc(2026, 10, 3);
    test('Erinnerung freundlich, mit Frist', () {
      final t = MahnschreibenPdfService.mahnText(MahnStufe.erinnerung, frist: frist, ersteErinnerung: null);
      expect(t, contains('entgangen'));
      expect(t, contains('03.10.2026'));
    });
    test('Letzte Mahnung droht Betreibung und nennt Zins seit Erinnerung', () {
      final t = MahnschreibenPdfService.mahnText(MahnStufe.letzte,
          frist: frist, ersteErinnerung: DateTime.utc(2026, 9, 1));
      expect(t, contains('Betreibung'));
      expect(t, contains('5 %'));
      expect(t, contains('01.09.2026'));
    });
    test('jede Stufe mit Gegenstandslos-Satz', () {
      for (final s in MahnStufe.values) {
        expect(
          MahnschreibenPdfService.mahnText(s, frist: frist, ersteErinnerung: DateTime.utc(2026, 9, 1)),
          contains('gegenstandslos'),
          reason: s.name,
        );
      }
    });
  });
}
```

(Ein Render-Test des ganzen PDFs braucht Betrieb/Rechnungen aus den lokalen Modellen; er wird in Task 5 über den Service abgedeckt. Hier genügt die Textregel.)

Run → FAIL.

- [ ] **Step 3: Mahnschreiben-Service**

`lib/services/pdf/mahnschreiben_pdf_service.dart`:

- `static String mahnText(MahnStufe stufe, {required DateTime frist, DateTime? ersteErinnerung})` — Texte aus Spec Abschnitt 4 (Erinnerung / 1. Mahnung / letzte Mahnung), Datum `dd.MM.yyyy`, immer mit Schlusssatz «Falls Sie die Zahlung inzwischen ausgelöst haben, betrachten Sie dieses Schreiben als gegenstandslos.» Die 1. Mahnung nennt kein Datum der Erinnerung (bei einer Sammelmahnung können es mehrere sein); die letzte Mahnung nennt «Verzugszins von 5 % seit [ersteErinnerung]» (früheste Erinnerung der enthaltenen Rechnungen; fehlt sie, den Satz ohne Datum).
- `static Future<Uint8List> generate({required BetriebLocal betrieb, BetriebRechnungsadresse? rechnungsadresse, required List<({Rechnung rechnung, MahnStufe stufe})> posten, required DateTime datum, required DateTime frist, required bool muster, List<Rechnung>? kontoauszugRechnungen, int? kontoauszugJahr, String? firmaName, String? firmaStrasse, String? firmaPlzOrt, String? firmaMwst})`:
  - `final pdf = await pdfDokument();`
  - **Seite 1 (MultiPage):** Kopf wie `MahnungPdfService._buildHeader` (Firma, Adresse), Empfänger über `adressZeilen(...)` aus `lib/core/util/rechnungsadresse_zeilen.dart` (gleich wie die Rechnung), Ort/Datum, Titel = `hoechsteStufe(posten.map((p) => p.stufe)).titel`, Betreff «Offene Rechnungen» bzw. «Rechnung <Nr>» bei einem Posten, `mahnText(...)`, Tabelle (Rechnungsnr., Rechnungsdatum, fällig seit, Betrag, Stufe dieser Rechnung — Spalte Stufe = `p.stufe.titel`), Total, «Zahlbar bis <frist>», Grussformel.
  - **QR-Seiten:** je Rechnung `QrZahlteil.bauen(r.betragBrutto, qrEmpfaenger(betriebName: betrieb.name, betriebStrasse: …, ra: rechnungsadresse), mitteilung: 'Rechnung ${r.rechnungsnummer}', referenz: r.qrReferenz)`, zwei pro A4-Seite (oben und unten, je 105 mm hoch), mit einer Zeile «Rechnung <Nr> vom <Datum>» darüber.
  - **Kontoauszug:** wenn `kontoauszugRechnungen != null` → `KontoauszugPdfService.seitenHinzufuegen(pdf, …, jahr: kontoauszugJahr)`.
  - **Muster:** wenn `muster`, auf jeder Seite über `pageTheme.buildForeground` ein diagonales «MUSTER» (grau, Deckkraft ~0.25, gross). Für die MultiPage- und die QR-Seiten dasselbe `pw.PageTheme` verwenden. Kontoauszug-Seiten: Parameter `muster` an `seitenHinzufuegen` weiterreichen (optionaler Parameter `bool muster = false`, gleiche Überlagerung).
  - `return pdf.save();`
- Firmenangaben und Stil (Farben, Schriftgrössen) aus `mahnung_pdf_service.dart` übernehmen, das in Task 6 entfernt wird.

- [ ] **Step 4: Tests, Analyse, Commit**

`flutter test && flutter analyze` → grün, 56 (Wächter `pdf_schrift_test` bleibt grün).

```bash
git add sbs_projer_app/lib/services/pdf/ sbs_projer_app/test/mahnschreiben_pdf_test.dart
git commit -m "feat(mahnwesen): Sammel-Mahnschreiben mit QR je Rechnung, Kontoauszug als Beilage

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 4: Edge Function — Zusatz-Anhänge

**Files:**
- Modify: `supabase/functions/send-rechnung-mail/index.ts`

- [ ] **Step 1: Parameter `zusatzPdfs`**

Im `req.json()`-Destructuring `zusatzPdfs` ergänzen. Nach Abschnitt «2. Protokoll-Foto laden» einfügen:

```ts
    // 3. Zusätzliche PDFs aus dem Bucket rechnung-pdfs (Mahnwesen, v0.134.0):
    //    Mahnschreiben, Kontoauszug, Rechnungskopien. Nur Pfade des eigenen
    //    Benutzers — sonst liesse sich jedes PDF im Bucket anhängen.
    if (Array.isArray(zusatzPdfs)) {
      for (const z of zusatzPdfs) {
        const pfad = typeof z?.pfad === "string" ? z.pfad : "";
        const name = typeof z?.dateiname === "string" && z.dateiname ? z.dateiname : "Dokument.pdf";
        if (!pfad.startsWith(`${userId}/`) || pfad.includes("..")) {
          console.warn(`Zusatz-PDF abgelehnt (fremder Pfad): ${pfad}`);
          continue;
        }
        const daten = await downloadFromStorage("rechnung-pdfs", pfad);
        if (daten) {
          attachments.push({ filename: name, contentType: "application/pdf", data: daten });
        } else {
          console.warn(`Zusatz-PDF nicht gefunden: ${pfad}`);
        }
      }
    }
```

Fehlt ein Zusatz-PDF, wird es übersprungen (Rechnungskopien existieren nicht für jede Alt-Rechnung) — kein 404.

- [ ] **Step 2: Commit** (Deploy macht der Controller als v23)

```bash
git add supabase/functions/send-rechnung-mail/index.ts
git commit -m "feat(mail): send-rechnung-mail nimmt Zusatz-PDFs (Mahnwesen)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 5: Protokoll und Mahnlauf-Service

**Files:**
- Create: `lib/data/models/mahnschreiben.dart`, `lib/data/repositories/mahnschreiben_repository.dart`, `lib/services/rechnung/mahnlauf_service.dart`
- Test: `test/mahnlauf_service_test.dart` (reine Teile)

- [ ] **Step 1: Modell und Repository**

`Mahnschreiben` (DTO, fromJson/toJson) mit den Spalten der Migration. Repository (Web-Pfad über `SupabaseService.client`, wie `CamtPrueflisteRepository`): `insert(Map)`, `getByBetrieb(String betriebId)` (neueste zuerst, `.order('erstellt_am', ascending: false).order('id')`), `getByRechnung(String rechnungId)` (`.contains('rechnung_ids', [id])`), `markiereZurueckgenommen(String id)`.

- [ ] **Step 2: Reine Hilfen mit Test (TDD)**

In `mahnlauf_service.dart` zwei statische, reine Funktionen — Test zuerst:

```dart
  /// Felder einer Rechnung vor dem Schreiben — für «zurücknehmen».
  static Map<String, dynamic> vorherStand(Rechnung r);

  /// Update-Felder für eine Rechnung, die [stufe] am [datum] bekommt.
  static Map<String, dynamic> updateFuerStufe(MahnStufe stufe, DateTime datum);
```

Test `test/mahnlauf_service_test.dart`:
- `updateFuerStufe(MahnStufe.mahnung1, 23.09.2026)` → `zahlungsstatus: 'mahnung_1'`, `mahnung_stufe: 1`, `letzte_mahnung_am` und `mahnung_1_am: '2026-09-23'`, `mahn_frist_bis: '2026-10-03'`; keine anderen Datumsfelder.
- `vorherStand(r)` enthält genau die sieben Felder (`zahlungsstatus`, `mahnung_stufe`, `letzte_mahnung_am`, `erinnerung_am`, `mahnung_1_am`, `mahnung_2_am`, `mahn_frist_bis`) im DB-Format (Datum `yyyy-MM-dd` oder null).

- [ ] **Step 3: Service**

```dart
class MahnlaufErgebnis {
  final String mahnschreibenId;
  final String? mailAn;       // tatsächliche Empfängeradresse (Test: Daniel)
  final Uint8List? druckPdf;  // gesetzt bei Kanal druck / letzte Mahnung
}

class MahnlaufService {
  static Future<MahnlaufErgebnis> erstellen({
    required BetriebLocal betrieb,
    required List<({Rechnung rechnung, MahnStufe stufe})> posten,
    required List<Rechnung> offeneDesBetriebs, // für die Beilage-Entscheidung und den Kontoauszug
    DateTime? heute,
  });

  static Future<void> zuruecknehmen(Mahnschreiben m);
}
```

Ablauf `erstellen`:
1. `datum = heute ?? DateTime.now()`, `frist = mahnFrist(datum)`, `stufe = hoechsteStufe(...)`, `muster = !MailConfig.istScharf('mahnwesen')`.
2. Rechnungsadresse laden wie `MahnwesenService.eskalieren` (Repository + Mapper). Mailadresse: `ra?.email` → sonst `betrieb.email` (gleiche Rückfallkette wie die Rechnung — vorher in `rechnungsadresse_resolver.dart` nachsehen und dieselbe Funktion nutzen).
3. `ersteErinnerung` = früheste `erinnerungAm` der Posten (oder `datum`, wenn die Posten erst jetzt erinnert werden).
4. Kontoauszug beilegen, wenn `offeneDesBetriebs.length > 1`: alle Rechnungen des Betriebs im laufenden Jahr (`rechnungenProvider`-Liste gefiltert ist Sache des Aufrufers; hier Parameter `kontoauszugRechnungen`).
5. **Mail-Variante** (wenn Mailadresse vorhanden):
   - Mahnschreiben-PDF (ohne Kontoauszug-Seiten) und Kontoauszug-PDF (falls beizulegen, `KontoauszugPdfService.generate(..., jahr: datum.year)`) erzeugen und hochladen nach `rechnung-pdfs/<userId>/mahnungen/<mahnschreibenId>/mahnschreiben.pdf` bzw. `…/kontoauszug.pdf` (`RechnungPdfStorage` um eine Methode `uploadMahnlaufPdf(String mahnschreibenId, String datei, Uint8List bytes)` ergänzen; `mahnschreibenId` vorher per `Uuid().v4()` bzw. dem im Projekt üblichen Weg erzeugen).
   - `send-rechnung-mail` aufrufen: `to: MailConfig.empfaenger(adresse, bereich: 'mahnwesen')`, `subject:` «<Titel> — <Betrieb>» und im Testmodus davor `'TEST an: $adresse — '`, `bodyText:` kurzer Text je Stufe (Verweis auf das angehängte Schreiben), `userId: SupabaseService.dataUserId`, **kein** `rechnungId`, `zusatzPdfs:` Mahnschreiben, ggf. Kontoauszug, und je Posten `'$userId/${r.id}/rechnung.pdf'` als `Rechnung_<Nr>.pdf`.
6. **Druck-Variante** (keine Mailadresse **oder** Stufe `letzte`): ein PDF mit Schreiben + QR + ggf. Kontoauszug-Seiten (`generate(..., kontoauszugRechnungen: …)`), hochladen als `…/druck.pdf`, Bytes im Ergebnis zurückgeben.
7. Protokoll: `mahnschreiben`-Zeile (id, betrieb_id, stufe, rechnung_ids, kanal `mail`/`druck`/`mail_und_druck`, empfaenger = tatsächliche Kunden-Adresse oder null, `test: muster`, `frist_bis`, `pdf_pfad` (Hauptdatei), `vorher` = `{id: vorherStand(r)}`) **vor** dem Mailversand schreiben.
8. Je Posten `RechnungRepository.update(r.id, updateFuerStufe(p.stufe, datum))`.
9. Mail zuletzt senden; schlägt sie fehl, Fehler weiterreichen (die Stufen stehen dann schon — der Screen meldet es und bietet «zurücknehmen» an).

`zuruecknehmen(m)`: je Rechnung-ID `RechnungRepository.update(id, m.vorher[id])`, dann `markiereZurueckgenommen(m.id)`. PDFs bleiben liegen.

- [ ] **Step 4: Tests, Analyse, Commit**

```bash
git add sbs_projer_app/lib/data sbs_projer_app/lib/services sbs_projer_app/test/mahnlauf_service_test.dart
git commit -m "feat(mahnwesen): Mahnlauf-Service mit Protokoll und Zuruecknehmen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 6: Mahnlauf-Seite, Einstiege, Aufräumen

**Files:**
- Create: `lib/presentation/providers/mahnlauf_provider.dart`, `lib/presentation/screens/rechnungen/mahnlauf_screen.dart`
- Modify: `lib/core/config/router.dart`, `rechnungen_list_screen.dart`, `rechnung_detail_screen.dart`, `aufgaben_detektoren_provider.dart`
- Delete: `lib/services/rechnung/forderung_service.dart`, `test/forderung_service_test.dart`, `lib/services/pdf/mahnung_pdf_service.dart`; aus `mahnwesen_service.dart` die Methode `eskalieren` (+ ungenutzte Imports) entfernen, `abschreiben` bleibt.
- Test: `test/mahnlauf_provider_test.dart` (reine Gruppierung), Wächter-Anpassungen

- [ ] **Step 1: Daten für die Seite (rein + Provider)**

In `mahnlauf_provider.dart` eine reine Funktion (Test zuerst):

```dart
class MahnBetrieb {
  final String betriebId;
  final String anzeige;               // betriebMitOrt
  final List<({Rechnung rechnung, MahnStufe stufe})> faellig;
  final List<Rechnung> inFrist;       // gemahnt, Frist läuft
  final bool gesperrt;                // gutschriftSperre
  final double summeFaellig;
}

class MahnlaufDaten {
  final DateTime? letzterAuszug;
  final bool bankGesperrt;
  final List<MahnBetrieb> betriebe;   // mit Fälligem, sortiert: höchste Stufe, dann ältestes Rechnungsdatum
  final List<Rechnung> erstZustellen; // imMahnbereich && !istZugestellt
}

MahnlaufDaten baueMahnlauf({
  required List<Rechnung> rechnungen,
  required Map<String, ({String name, String? ort, List<String> aliase})> betriebe,
  required List<OffeneGutschrift> gutschriften,
  required DateTime? letzterAuszug,
  required DateTime heute,
});
```

- Stichtag = `letzterAuszug`; ist er null oder `bankSperre`, ist nichts fällig (`faellig` leer), aber `inFrist`/`erstZustellen` werden trotzdem gezeigt.
- Tests: Betrieb mit zwei fälligen Rechnungen landet als eine Karte; gesperrt bei passender Gutschrift; Bank gesperrt → keine Fälligen; Altlast/Heineken erscheinen nirgends; nicht Zugestellte in `erstZustellen`.
- `mahnlaufProvider` (FutureProvider): `rechnungenProvider`, `betriebeProvider` (Name, Ort, `zahlerAliase`), `camtPrueflisteProvider` (nur `istGutschrift`, Status `offen`), `letzteCamtPeriodeProvider` → `baueMahnlauf(...)`.

- [ ] **Step 2: Seite `/rechnungen/mahnlauf`**

`MahnlaufScreen` (ConsumerStatefulWidget), CanvasKit-sicher:
- **Kopf:** Bankstatus-Karte. Gesperrt: rote Karte «Bankauszug bis <Datum> — zuerst den aktuellen Auszug einlesen» + `TapKnopf('Bankauszug einlesen', onTap: push('/buchhaltung/camt-import'))`. Sonst grüne Zeile «Auszug bis <Datum> ✓». Im Testmodus zusätzlich gelbe Zeile «Testmodus: Mails gehen an dani.proyer@gmail.com, PDFs mit MUSTER».
- **Mahnfällig:** Karte je `MahnBetrieb` (Anzeige, Anzahl, Summe, höchste Stufe; gesperrt: rot «Zahlung ungeklärt — zuerst in der Bankauszug-Prüfliste zuordnen», keine Auswahl möglich). Antippen klappt die Rechnungen mit Häkchen auf (Standard alle angehakt; Häkchen aus `GestureDetector` + Icon). Knopf «Vorschau» je Karte.
- **Vorschau** (Bottom-Sheet oder eigener Schritt): Empfänger (Mail oder «Druck — keine Mailadresse»), Stufe, Frist, Liste der Rechnungen, «letzte Zahlung des Betriebs: <Datum/Betrag>» (aus den bezahlten Rechnungen des Betriebs: jüngstes `zahlungEingegangenAm`), Knopf `TapKnopf(text: 'Mahnung erstellen', primaer: true)`. Erst dieser zweite Klick ruft `MahnlaufService.erstellen`.
- **Nach dem Erstellen:** SnackBar mit Ergebnis; bei Druck-PDF sofort `oeffnePdfImNeuenTab(bytes, 'Mahnung_<Betrieb>.pdf')` (`lib/services/pdf/pdf_tab_oeffner_export.dart`); `ref.invalidate(rechnungenStreamProvider)` und `mahnlaufProvider`.
- **In Frist:** kompakte Liste (Betrieb, Rechnung, Stufe, Frist bis). Je Zeile «Mahnverlauf» → Rechnungsdetail.
- **Erst zustellen:** kompakte Liste; Zeile → Rechnungsdetail (dort «Rechnung erneut senden»).
- **Zurücknehmen:** Im Rechnungsdetail (Step 4) je Mahnschreiben.

- [ ] **Step 3: Einstiege**

- `router.dart`: `/rechnungen/mahnlauf` **vor** `/rechnungen/:id` (sonst wird «mahnlauf» als ID gelesen — gleicher Kommentar wie bei `pro-betrieb`). Query `?rechnung=<id>` → Einzelmahnung: die Seite zeigt dann nur den Betrieb dieser Rechnung mit nur dieser Rechnung angehakt.
- `rechnungen_list_screen.dart` (Kunden): oben eine Karte «Mahnlauf» mit Anzahl fälliger Betriebe (aus `mahnlaufProvider`) → `/rechnungen/mahnlauf`. Den bisherigen Dialog zur Einzel-Eskalation (`_showStatusDialog` → `MahnwesenService.eskalieren`) durch «Im Mahnlauf mahnen» → `/rechnungen/mahnlauf?rechnung=<id>` ersetzen; «Abschreiben» bleibt. Filter/Labels «Mahnfällig» auf `faelligeStufe(r, stichtag: heute) != null` umstellen (Anzeige, keine Sicherung nötig — der Versand passiert nur im Mahnlauf).
- `rechnung_detail_screen.dart`: Knopf «Jetzt mahnen» (`_tapButton`, im Abschnitt Rechnungsadresse neben «Rechnung erneut senden», nur wenn `imMahnbereich && istZugestellt`) → `/rechnungen/mahnlauf?rechnung=<id>`. **Mahnverlauf:** die bestehenden `_MahnungPdfRow` ersetzen durch eine Liste aus `MahnschreibenRepository.getByRechnung`: Datum, Stufe, Kanal, «TEST» falls test, «zurückgenommen» falls gesetzt; antippen öffnet das PDF (Signed URL); `TapKnopf(text: 'Zurücknehmen', gefahr: true)` mit Bestätigung → `MahnlaufService.zuruecknehmen`.
- `aufgaben_detektoren_provider.dart`: Mahnlauf-Detektor auf `faelligeStufe(r, stichtag: letzterAuszug ?? heute)` umstellen, Anzahl = **Betriebe** mit Fälligem; `mahnlaufAufgabe` Titel «Mahnlauf: N Betriebe fällig», Route `/rechnungen/mahnlauf`. Ist die Bank gesperrt und gäbe es Fälliges, Titel «Mahnlauf: zuerst Bankauszug einlesen».

- [ ] **Step 4: Aufräumen und Wächter**

- `forderung_service.dart` + Test löschen (grep: keine Nutzer mehr), `mahnung_pdf_service.dart` löschen, `MahnwesenService.eskalieren` entfernen.
- `test/erreichbarkeit_waechter_test.dart`: `'/rechnungen/mahnlauf'` in `unterseiten` mit `rechnungen_list_screen.dart`.
- `test/canvaskit_sichere_widgets_test.dart`: `mahnlauf_screen.dart` in die Dateiliste.
- **Neuer Wächter** `test/mahnwesen_testmodus_waechter_test.dart`: liest `mail_config.dart` und erwartet `mahnwesenScharf = false`; liest `mahnlauf_service.dart` und erwartet, dass der Empfänger über `MailConfig.empfaenger(` mit `bereich: 'mahnwesen'` bestimmt wird und `'TEST an: '` im Betreff steht. Grund im Kopf: Scharfstellen ist ein bewusster Schritt Daniels nach ausgiebigem Test (23.09.2026) — wer `mahnwesenScharf` ändert, muss diesen Test bewusst anpassen.

- [ ] **Step 5: Tests, Analyse, Commit**

`flutter test && flutter analyze` → grün, 56.

```bash
git add -A sbs_projer_app/lib sbs_projer_app/test
git commit -m "feat(mahnwesen): Mahnlauf-Seite, Einzelmahnung, Mahnverlauf, alte Eskalation entfernt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 7: Auslieferung v0.134.0 (Controller)

- [ ] Migration 200 per `apply_migration` einspielen; Spalten und Policies prüfen.
- [ ] Edge Function `send-rechnung-mail` deployen (v23); mit einem Testaufruf ohne `zusatzPdfs` prüfen, dass der bestehende Rechnungsversand weiter geht (Logs).
- [ ] Version `0.134.0+786`, `kAppVersion`.
- [ ] `flutter test && flutter analyze`.
- [ ] Sichtprüfung 360 px (angemeldet): Mahnlauf-Seite, Bank-Sperre (Auszug alt → rot), Karte je Betrieb, Vorschau, ein Test-Mahnschreiben an einen echten Betrieb erzeugen → Mail kommt bei Daniel an mit «TEST an: …», PDFs mit MUSTER, Rechnungskopien und Kontoauszug angehängt; Druck-Variante öffnet sich; Rechnungsdetail zeigt Mahnverlauf; «Zurücknehmen» stellt den Stand wieder her (DB prüfen).
- [ ] Doku: `docs/chronik.md`, `ToDo.md` (Klicktests; Hinweis «vor dem ersten echten Mahnlauf Bankauszug einlesen»; Punkt AGB-Klausel ab 2027 mit Fachperson), `Projekt.md` (Abschnitt Büro: Mahnwesen).
- [ ] Commit, Push, Deploy nach CLAUDE.md, Live-Version prüfen.
