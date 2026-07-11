# Buchhaltung-Auswertung (Phase 1) — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (empfohlen) oder executing-plans. Steps mit `- [ ]`-Checkboxen.

**Goal:** Neuer Screen `/buchhaltung/auswertung` — Umsatz & Arbeiten nach Jahr/Monat, 3 Ansichts-Modi, Charts (fl_chart), netto/brutto, professionelle Tabelle; rein live aus App-Daten.

**Architecture:** Reine, testbare Aggregation über normalisierte `ArbeitsPosten` (netto+brutto je Datensatz, Kunde/HK-Split bereits beim Mapping). Riverpod-Provider mappt die vorhandenen Local-Listen → Posten → Aggregat. Screen liest das Aggregat. Keine Migration, keine Historien-Tabelle.

**Tech Stack:** Flutter, Riverpod, fl_chart (neu), bestehende Provider (`reinigungenProvider` … `pikettDiensteProvider`, `betriebeProvider`), MwSt aus Preis-Historie.

**Referenz-Zahlen (Abnahme):** Excel `00_SBS_Projer_70` Blatt „Auswertung". Verifiziert: Total = Reinigung(Kunde) + RechnungHK; 2019 66'811+50'034=116'845; 2025 123'869+89'966=213'835; RechnungHK 2025 = 83'224 netto ×1.081. Volle App-Abnahme nur wo Daten vollständig (Reinigung alle Jahre; alle Kategorien Dez 2025).

---

### Task 1: Dependency fl_chart

**Files:** Modify `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1:** Unter `dependencies:` ergänzen: `fl_chart: ^0.69.0` (aktuelle stabile 0.69.x; falls Konflikt: nächste kompatible 0.6x/0.7x).
- [ ] **Step 2:** `flutter pub get` — Run, erwartet: erfolgreich, keine Versionskonflikte.
- [ ] **Step 3:** `flutter build web --pwa-strategy=none` (Smoke) — erwartet: baut (fl_chart web-kompatibel).
- [ ] **Step 4:** Commit `chore: fl_chart dependency`.

---

### Task 2: Datenmodell + reine Aggregation (TDD)

**Files:**
- Create `sbs_projer_app/lib/services/auswertung/auswertung_modell.dart`
- Create `sbs_projer_app/lib/services/auswertung/auswertung_aggregat.dart`
- Test `sbs_projer_app/test/services/auswertung_aggregat_test.dart`

**Modell (`auswertung_modell.dart`):**
```dart
enum AuswertungKategorie {
  reinigung,       // Kunde
  reinigungHk,     // Heineken-Betrieb
  stoerung, eigenauftrag, eroeffnung, montage, pikett, bkPauschale,
}

const heinekenKategorien = {
  AuswertungKategorie.reinigungHk, AuswertungKategorie.stoerung,
  AuswertungKategorie.eigenauftrag, AuswertungKategorie.eroeffnung,
  AuswertungKategorie.montage, AuswertungKategorie.pikett,
  AuswertungKategorie.bkPauschale,
};

/// Ein normalisierter Arbeitsposten (netto UND brutto schon aufbereitet).
class ArbeitsPosten {
  final AuswertungKategorie kategorie;
  final int jahr;
  final int monat; // 1..12
  final double netto;
  final double brutto;
  const ArbeitsPosten(this.kategorie, this.jahr, this.monat, this.netto, this.brutto);
}

class KategorieWert {
  final int anzahl; final double netto; final double brutto;
  const KategorieWert(this.anzahl, this.netto, this.brutto);
  KategorieWert plus(double n, double b) => KategorieWert(anzahl + 1, netto + n, brutto + b);
  static const leer = KategorieWert(0, 0, 0);
}

class MonatsWerte {
  final int jahr; final int monat;
  final Map<AuswertungKategorie, KategorieWert> kategorien;
  const MonatsWerte(this.jahr, this.monat, this.kategorien);

  KategorieWert kat(AuswertungKategorie k) => kategorien[k] ?? KategorieWert.leer;
  int get anzahlGesamt => kategorien.values.fold(0, (s, w) => s + w.anzahl);

  double reinigungKunde(bool brutto) => brutto ? kat(AuswertungKategorie.reinigung).brutto : kat(AuswertungKategorie.reinigung).netto;
  double rechnungHk(bool brutto) => heinekenKategorien.fold(0.0, (s, k) => s + (brutto ? kat(k).brutto : kat(k).netto));
  double total(bool brutto) => reinigungKunde(brutto) + rechnungHk(brutto);
}
```

**Aggregation (`auswertung_aggregat.dart`):**
```dart
import 'auswertung_modell.dart';

class AuswertungDaten {
  final Map<int, Map<int, MonatsWerte>> proJahrMonat; // jahr -> monat -> werte
  const AuswertungDaten(this.proJahrMonat);

  List<int> get jahre => (proJahrMonat.keys.toList()..sort());
  MonatsWerte? monat(int jahr, int monat) => proJahrMonat[jahr]?[monat];
  List<MonatsWerte> monateVon(int jahr) =>
      List.generate(12, (i) => proJahrMonat[jahr]?[i + 1] ?? MonatsWerte(jahr, i + 1, const {}));

  /// Jahres-Total (aggregiert alle Monate eines Jahres zu einer MonatsWerte mit monat=0).
  MonatsWerte jahresWerte(int jahr) {
    final acc = <AuswertungKategorie, KategorieWert>{};
    for (final m in proJahrMonat[jahr]?.values ?? const <MonatsWerte>[]) {
      m.kategorien.forEach((k, w) {
        final cur = acc[k] ?? KategorieWert.leer;
        acc[k] = KategorieWert(cur.anzahl + w.anzahl, cur.netto + w.netto, cur.brutto + w.brutto);
      });
    }
    return MonatsWerte(jahr, 0, acc);
  }

  /// Ein Monat über alle Jahre (z.B. Juni): jahr -> MonatsWerte.
  Map<int, MonatsWerte> monatsvergleich(int monat) => {
    for (final j in jahre) if (proJahrMonat[j]?[monat] != null) j: proJahrMonat[j]![monat]!,
  };
}

AuswertungDaten aggregiere(Iterable<ArbeitsPosten> posten) {
  final map = <int, Map<int, Map<AuswertungKategorie, KategorieWert>>>{};
  for (final p in posten) {
    final jm = (map[p.jahr] ??= {});
    final km = (jm[p.monat] ??= {});
    km[p.kategorie] = (km[p.kategorie] ?? KategorieWert.leer).plus(p.netto, p.brutto);
  }
  return AuswertungDaten({
    for (final j in map.entries)
      j.key: { for (final m in j.value.entries) m.key: MonatsWerte(j.key, m.key, m.value) }
  });
}
```

- [ ] **Step 1:** Test schreiben: 3 Posten (reinigung Kunde 100/108, montage 200/216, stoerung 50/54) im selben Monat → `monat(2025,6)`: anzahlGesamt=3, reinigungKunde(false)=100, rechnungHk(false)=250, total(false)=350; brutto analog. Leerer Monat → alle 0.
- [ ] **Step 2:** Test `jahresWerte` (2 Monate summiert) + `monatsvergleich` (Juni über 2 Jahre) + `monateVon` füllt fehlende Monate mit Leer.
- [ ] **Step 3:** Run Tests → FAIL (Klassen fehlen).
- [ ] **Step 4:** Modell + Aggregat implementieren (Code oben).
- [ ] **Step 5:** Run Tests → PASS.
- [ ] **Step 6:** Commit `feat(auswertung): reines Aggregat-Modell (TDD)`.

---

### Task 3: Mapping-Provider (Local-Listen → ArbeitsPosten → Aggregat)

**Files:**
- Create `sbs_projer_app/lib/presentation/providers/auswertung_providers.dart`
- Test `sbs_projer_app/test/services/auswertung_mapping_test.dart`

**Reine Mapping-Funktion** (testbar, ohne Riverpod) in `auswertung_aggregat.dart` oder eigenem `auswertung_mapping.dart`:
```dart
/// mwstFaktor(jahr,monat) z.B. 1.077 (bis 2023) / 1.081 (ab 2024).
/// heinekenBetriebIds = Betriebe mit rechnungsstellung=='heineken'.
List<ArbeitsPosten> mappePosten({
  required List<ReinigungLocal> reinigungen,
  required List<StoerungLocal> stoerungen,
  required List<MontageLocal> montagen,
  required List<EigenauftragLocal> eigenauftraege,
  required List<EroeffnungsreinigungLocal> eroeffnungen,
  required List<BergkundenpauschaleLocal> bergkunden,
  required List<PikettDienstLocal> pikett,
  required Set<String> heinekenBetriebIds,
  required double Function(int jahr, int monat) mwstFaktor,
}) { ... }
```
Regeln je Typ (Datum → jahr/monat; netto/brutto):
- Reinigung: `preisNetto`/`preisBrutto`; Kategorie = `heinekenBetriebIds.contains(betriebId) ? reinigungHk : reinigung`.
- Störung: `preisNetto`; brutto = `preisBrutto` (falls vorhanden) sonst netto×faktor.
- Montage `kostenArbeit`, Eigenauftrag `pauschale`, Eröffnung `preis`, BK `betrag`, Pikett `pauschaleGesamt ?? pauschale`: netto = Feld; brutto = netto × mwstFaktor(jahr,monat).
- Datum: Pikett `datumStart`, sonst `datum`. `null`-Preise → 0.

**Provider (`auswertung_providers.dart`):**
```dart
final heinekenBetriebIdsProvider = Provider<Set<String>>((ref) {
  final betriebe = ref.watch(betriebeProvider);
  return {for (final b in betriebe) if (b.serverId != null && b.rechnungsstellung == 'heineken') b.serverId!};
});

final auswertungProvider = Provider<AuswertungDaten>((ref) {
  final posten = mappePosten(
    reinigungen: ref.watch(reinigungenProvider),
    stoerungen: ref.watch(stoerungenProvider),
    montagen: ref.watch(montagenProvider),
    eigenauftraege: ref.watch(eigenauftraegeProvider),
    eroeffnungen: ref.watch(eroeffnungsreinigungenProvider),
    bergkunden: ref.watch(bergkundenpauschaleProvider),
    pikett: ref.watch(pikettDiensteProvider),
    heinekenBetriebIds: ref.watch(heinekenBetriebIdsProvider),
    mwstFaktor: ref.watch(mwstFaktorFnProvider),
  );
  return aggregiere(posten);
});
```
`mwstFaktorFnProvider`: liefert eine reine Funktion `(jahr,monat)→faktor` aus der Preis-/MwSt-Historie (bestehende MwSt-Logik nutzen; Fallback 1.081). Feld `betrieb.rechnungsstellung` + `serverId` in `BetriebLocal` prüfen (Grep) — falls anders benannt, anpassen.

- [ ] **Step 1:** Test `mappePosten` mit je 1 Datensatz pro Typ (fixe Werte) → korrekte Kategorie/Jahr/Monat/netto/brutto; Reinigung bei Heineken-Betrieb → `reinigungHk`; Pikett nutzt `datumStart`.
- [ ] **Step 2:** Run → FAIL. Implementieren. Run → PASS.
- [ ] **Step 3:** `flutter analyze` der neuen Dateien → sauber.
- [ ] **Step 4:** Commit `feat(auswertung): Mapping + Provider`.

---

### Task 4: Screen-Gerüst + Routing + Dashboard-Kachel

**Files:**
- Create `sbs_projer_app/lib/presentation/screens/buchhaltung/auswertung_screen.dart`
- Modify `sbs_projer_app/lib/core/config/router.dart` (neue GoRoute nach `/buchhaltung/berichte`)
- Modify `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` (neues `_NavTile`)

- [ ] **Step 1:** `AuswertungScreen` (ConsumerStatefulWidget) mit State: `_modus` (jahr/jahre/monatsvergleich), `_jahr` (Default aktuelles), `_monat` (Default aktueller), `_brutto` (bool). Scaffold + AppBar „Auswertung". Body vorerst Platzhalter `Text(daten.jahre.join(','))` aus `auswertungProvider`.
- [ ] **Step 2:** GoRoute `/buchhaltung/auswertung` → `AuswertungScreen` (Muster wie `/buchhaltung/berichte`).
- [ ] **Step 3:** `_NavTile` im Dashboard: Titel „Auswertung", Icon `Icons.insights`, `context.push('/buchhaltung/auswertung')` — direkt nach „Berichte".
- [ ] **Step 4:** `flutter analyze` → sauber. Commit `feat(auswertung): Screen-Gerüst + Route + Kachel`.

---

### Task 5: Kopf (KPI + netto/brutto + Modus-Umschalter) + Charts (fl_chart)

**Files:** Modify `auswertung_screen.dart`; Create `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/auswertung_charts.dart`

- [ ] **Step 1:** Kopf: netto/brutto-Umschalter (kleiner SegmentedButton/Switch), 3-Wege-Modus-Umschalter (SegmentedButton Jahr/Jahre/Monatsvergleich), Kontext-Dropdown (Jahr-Dropdown bzw. Monat-Dropdown je Modus, `AppFilterDropdown`).
- [ ] **Step 2:** KPI-Karten aus `auswertungProvider`: Total (gewähltes Jahr, `jahresWerte(jahr).total(_brutto)`), Δ% ggü. Vorjahr, Aufteilung Kunde/Heineken, Arbeiten gesamt. **Grün dezent** (Akzentrand, nicht vollflächig).
- [ ] **Step 3:** Chart-Widgets (fl_chart):
  - **Jahr:** `LineChart` 12 Monate `total(_brutto)` + zweite (gestrichelte) Linie Vorjahr; Achsen/Gitter dezent, grün als Linienfarbe.
  - **Jahre:** `BarChart` je Jahr `jahresWerte(j).total(_brutto)`, aktuelles Jahr hervorgehoben.
  - **Monatsvergleich:** `BarChart` aus `monatsvergleich(_monat)` je Jahr, aktuelles Jahr hervorgehoben.
- [ ] **Step 4:** Chart je nach `_modus` einblenden. `flutter analyze` sauber, Web-Build. Commit `feat(auswertung): KPI + Charts`.

---

### Task 6: Professionelle Detail-Tabelle + aufklappbarer Kategorien-Breakdown

**Files:** Modify `auswertung_screen.dart`; ggf. Create `widgets/auswertung_tabelle.dart`

- [ ] **Step 1:** Tabelle (nur Jahr-Modus sinnvoll, sonst Jahres-Tabelle): Kopfzeile Monat·Anzahl·Kunde·Heineken·Total; 12 Monatszeilen (`monateVon(jahr)`), Zebra, rechtsbündige Zahlen mit `'`-Tausender (`NumberFormat("#,##0","de_CH")` bzw. eigener Formatter mit `'`), fette **Total-Zeile** (`jahresWerte`).
- [ ] **Step 2:** Zeile antippen → `ExpansionTile`/`onTap` blendet Kategorien-Breakdown ein (alle `AuswertungKategorie` mit Anzahl + Betrag der `_brutto`-Basis; nur Kategorien mit anzahl>0).
- [ ] **Step 3:** Kein horizontales Seiten-Scrollen (5 Spalten passen; Zahlen kompakt). `flutter analyze` sauber. Commit `feat(auswertung): Detail-Tabelle + Breakdown`.

---

### Task 7: Verifikation + adversariale Review + Deploy

- [ ] **Step 1:** `flutter analyze` (ganzes Projekt) + `flutter test` — grün.
- [ ] **Step 2:** **Excel-Abnahme-Tests:** feste Testfälle aus dem Excel als `ArbeitsPosten`-Sätze (mind. Reinigung eines Altjahres + Dez 2025 alle Kategorien) → Aggregat muss die Excel-Netto/Brutto-/Total-Werte reproduzieren (Toleranz Rundung). Falls Abweichung: Feldwahl/Reinigung-HK-Bewertung nachjustieren.
- [ ] **Step 3:** Visueller Web-Check (Pixel-9-Breite): 3 Modi, netto/brutto, Charts rendern, Tabelle + Aufklappen, grün dezent.
- [ ] **Step 4:** Adversariale Review (Workflow, 3 Lenses: Aggregat-Korrektheit/MwSt, Chart-/Rendering-Robustheit leere Jahre, Smartphone-UX) → bestätigte Funde fixen.
- [ ] **Step 5:** Version-Bump (Minor, z.B. 0.45.0), Build, gh-pages-Deploy, main-Push. ToDo.md Phase 1 abhaken.

## Self-Review (writing-plans)
- Spec-Abdeckung: 3 Modi ✓ (T5/T6), netto/brutto ✓ (T2 brutto-Feld, T5 Toggle), Tabelle+Breakdown ✓ (T6), Charts fl_chart ✓ (T5), Live-Aggregation ✓ (T2/T3), Route+Kachel ✓ (T4), Excel-Abnahme ✓ (T7). Kein Historien-Import (Phase 2, out of scope).
- Typkonsistenz: `AuswertungKategorie`/`MonatsWerte`/`AuswertungDaten`/`ArbeitsPosten` durchgängig; Methoden `jahresWerte`/`monateVon`/`monatsvergleich` konsistent verwendet.
- Platzhalter: Feldnamen (`rechnungsstellung`, Local-Preisfelder) beim Mapping per Grep verifizieren — als Step notiert.
