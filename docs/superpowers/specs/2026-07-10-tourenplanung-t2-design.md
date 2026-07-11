# Tourenplanung T2 — Fälligkeits-Logik & Auto-Termine (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026)
**Herkunft:** Paket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Abschnitt „Tourenplanung".
Zweites Teil-Paket nach [T1](2026-07-10-tourenplanung-t1-design.md).

## Ziel & Kontext

Zwei Dinge: (1) die Fälligkeitsberechnung für **Saisonalität, Eröffnung, Endreinigung, Betriebsferien**
robuster/korrekter machen; (2) **Eröffnung/Endreinigung-Termine automatisch im Tagesplan** anbieten.

**Ist-Zustand (verifiziert, `tour_providers.dart`):**
- `getFaelligkeit(anlage, datum, {betrieb, letzteServiceArt})` → `FaelligkeitsStatus`
  {ueberfaellig, faellig, baldFaellig, endreinigungFaellig, eroeffnungFaellig, nichtFaellig}.
- `_getSaisonFaelligkeit(anlage, datum, betrieb, letzteServiceArt)` nutzt `_naechsteSchliessung`
  (Saisonende ODER **jeder** Ferienstart), `_naechsteOeffnung`, `_wiederoeffnungNachEndreinigung`.
  Endreinigung/Eröffnung werden **nur** über `letzteServiceArt=='endreinigung'` erkannt.
- `isBetriebOffen(b, datum)` (mit Ruhetag) vs. `_isBetriebAktiv(b, datum)` (ohne Ruhetag) — zwei
  divergierende „offen"-Begriffe.
- Betrieb: `sommer/winterStartDatum`, `sommer/winterEndeDatum`, `sommer/winterSaisonAktiv`,
  `istSaisonbetrieb`, Ferien 1–5 (`betrieb_ferien.dart`: `ferienSlots/ferienStarts/ferienEnden/
  istInFerien`), `ruhetage` (volle Wochentagsnamen), `status`.
- Anlage: `naechsteReinigung`, `letzteReinigung`, `reinigungRhythmus`, `status`, `serverId`,
  `betriebId`, `typAnlage`, `anzahlHaehne`.
- Reinigung `serviceArt`-Werte: `'standardservice'`, `'endreinigung'`, `'eroeffnungsservice'`.
- Tagesplan-Tab zeigt `angezeigtTagesplan` (Reorder-Liste); `faelligeEintraegeProvider`/
  `tourVorschlagErweitertProvider` bauen `TourEintrag`s. T1: Plan startet leer, Auto-Speicherung,
  Inline-Filter, `TourEintrag` trägt `ruhetage`/`servicezeit`.

**Audit-Befund (Basis der Änderungen):**
1. Endreinigung wird vor **jeder** Ferienperiode ausgelöst (auch kurzen). → nur relevante Schliessungen.
2. „Geschlossen"-Status hängt allein an `letzteServiceArt` → Anlage kann „verschwinden". → aus
   Betrieb-Übergängen ableiten.
3. Zwei „offen"-Begriffe (Ruhetag ja/nein). → ein kanonischer Begriff.
4. Schwellen: am Soll-Termin nur `baldFaellig`. → **bleibt unverändert** (User-Entscheid).
5. `+28 Tage`-Adjustment fix. → bleibt (out of scope, YAGNI).

## Entscheidungen (mit User geklärt)

- **Auto-Termine:** erscheinen am berechneten Ziel-Tag als **markierte Auto-Vorschläge** im Tagesplan;
  User übernimmt/verschiebt/verwirft (Plan bleibt sonst manuell wie T1). Nicht auto-persistiert.
- **Endreinigung-Auslöser:** nur **Saisonende** und Betriebsferien **ab 21 Tagen**
  (`_langeSchliessungTage = 21`). Kurze Ferien → keine Endreinigung.
- **Ziel-Tag:** Endreinigung = **letzter offener Tag vor** Schliessung; Eröffnung = **erster offener
  Tag ab** Wiedereröffnung. **Ruhetage + Ferientage werden übersprungen**.
- **Vorlauf:** Endreinigung/Eröffnung werden **7 Tage** vor dem Übergang fällig — bestehende Konstante
  `_saisonVorlaufTage` wird von 14 auf **7** gesenkt.
- **Schwellen:** unverändert.
- Keine DB-Migration. Deploy **v0.30.0**.

## Baustein A — Übergangs-Modell (reine Funktionen, TDD)

Neue Datei `lib/core/util/touren_saison.dart` (nur `BetriebLocal`-Abhängigkeit, testbar):

- `const int langeSchliessungTage = 21;`
- `bool istOffenerTag(BetriebLocal b, DateTime tag)` — Betrieb `status=='aktiv'`, **nicht** in Ferien
  (`istInFerien`), in aktiver Saison (falls `istSaisonbetrieb`), **kein** Ruhetag. (Kanonischer
  „offen"-Begriff; ersetzt inhaltlich `isBetriebOffen`.)
- `DateTime? naechsterOffenerTag(BetriebLocal b, DateTime ab, {bool rueckwaerts = false})` — erster
  Tag ab `ab` (vorwärts oder rückwärts), der `istOffenerTag` erfüllt; Suchfenster max. 60 Tage
  (sonst `null`).
- `({DateTime datum, bool istSaisonende})? qualifizierteSchliessung(BetriebLocal b, DateTime ab)` —
  nächste **relevante** Schliessung ab `ab`:
  - Saisonende (`sommerEndeDatum`/`winterEndeDatum`, wenn aktuell in dieser Saison), `istSaisonende=true`;
  - Ferienperiode mit Dauer `(ende - start).inDays + 1 >= langeSchliessungTage`, `istSaisonende=false`;
  - liefert die zeitlich nächste; `null` wenn keine.
- `DateTime? oeffnungNach(BetriebLocal b, DateTime schliessung)` — Wiedereröffnung nach einer
  Schliessung: Saisonstart nach `schliessung` bzw. `ferienEnde+1`; `null` wenn keine.

## Baustein B — Endreinigung-/Eröffnungs-Fälligkeit aus Übergängen

`_getSaisonFaelligkeit` (bzw. Ersatz) nutzt Baustein A statt `letzteServiceArt`-Heuristik:

- **Endreinigung fällig**, wenn `qualifizierteSchliessung(betrieb, datum)` existiert und ihr
  Vorlauf `schliessung.datum.difference(datum).inDays <= _saisonVorlaufTage` (**neu: 7 Tage**),
  **und** noch nicht erledigt: keine Reinigung dieser Anlage mit `serviceArt=='endreinigung'` seit
  Beginn der aktuellen Offen-Periode (via `anlage.letzteReinigung` + `letzteServiceArt`).
- **Eröffnung fällig**, wenn der Betrieb an/nach einer solchen Schliessung wieder öffnet
  (`oeffnungNach`) und die Öffnung ≤7 Tage bevorsteht **oder** bereits war, **und** noch kein
  Eröffnungsservice/Standardservice seit der Wiedereröffnung erfasst ist.
- `letzteServiceArt` bleibt als **Bestätigung „erledigt"**, ist aber nicht mehr alleiniger Auslöser.
- Reguläre Rhythmus-Logik + Schwellen unverändert. Saison-Fälligkeit behält Vorrang.

## Baustein C — Auto-Termin-Berechnung

- `TourEintrag` bekommt `final bool istAutoTermin` (Default `false`) + `final DateTime? zielDatum`
  (reines UI-Objekt; **nicht** in den Tagesplan-JSON aufgenommen — Auto-Termine werden nie als solche
  persistiert, nur ihre übernommene Reinigungs-Version wandert normal in den Plan).
- Neuer `autoTermineProvider = Provider.family<List<TourEintrag>, DateTime>` liefert die Auto-Termine,
  deren **Ziel-Tag == `datum`** ist:
  - Für jeden Betrieb mit qualifizierter Schliessung/Öffnung im relevanten Zeitraum, je aktiver Anlage:
    - **Endreinigung**: `ziel = naechsterOffenerTag(b, schliessung.datum, rueckwaerts:true)`
      (letzter offener Tag ≤ Schliessung). Nur wenn noch nicht erledigt (Baustein B).
    - **Eröffnung**: `ziel = naechsterOffenerTag(b, oeffnung, rueckwaerts:false)`
      (erster offener Tag ≥ Wiedereröffnung). Nur wenn noch nicht erledigt.
  - Ergibt `TourEintrag(typ: reinigung, faelligkeit: endreinigung/eroeffnung, istAutoTermin: true,
    zielDatum: ziel, id: 'auto_<art>_<anlageRouteId>')`.
  - Nur Einträge mit `ziel == datum` (auf den Tag normalisiert) werden zurückgegeben.
- Dedupe gegen den gespeicherten/aktuellen Tagesplan (gleiche `anlageId`+Endreinigung/Eröffnung nicht
  doppelt vorschlagen, wenn schon im Plan).

## Baustein D — UI: Auto-Sektion im Tagesplan-Tab

- Über der Plan-Liste (im Tagesplan-Tab) eine Sektion **„Automatische Termine"**, nur sichtbar wenn
  `autoTermineProvider(_selectedDate)` nicht leer ist:
  - Kopfzeile mit Icon (z.B. `Icons.auto_awesome`) + „Automatische Termine (N)" + Button
    **„Alle übernehmen"**.
  - Je Auto-Termin eine kompakte Karte (Betrieb, Anlage, Badge Endreinigung/Eröffnung via
    `faelligkeitFarbe`) mit **„+ übernehmen"**; Tap öffnet das Anlagen-Detail (wie sonst).
  - „übernehmen" ruft `tagesplanProvider.notifier.hinzufuegen(eintrag ohne istAutoTermin)` → wandert in
    den (auto-gespeicherten) Plan; danach verschwindet der Vorschlag (dedupe).
- Kein Auto-Eintrag landet ungefragt im gespeicherten Plan.

## Abgrenzung

- **Kein** Umbau des Termine-Kalender-Moduls (`termine/`) — separates Paket.
- Keine Änderung an Schwellen (überfällig/fällig/baldFällig) und am `+28`-Adjustment.
- Keine DB-Migration; Tagesplan-Persistenz-Schema unverändert.

## Tests & Verifikation

- **Unit-Tests** (`touren_saison_test.dart`):
  - `istOffenerTag`: Ruhetag / Ferientag / ausserhalb Saison / aktiv → korrekt.
  - `naechsterOffenerTag`: überspringt Ruhetag + Ferien, vorwärts/rückwärts, `null` nach 60 Tagen.
  - `qualifizierteSchliessung`: Saisonende erkannt; Ferien ≥21 Tage erkannt, <21 ignoriert; nächste gewinnt.
  - `oeffnungNach`: Saisonstart / Ferienende+1.
- **Fälligkeit-Tests** (Erweiterung bestehender Touren-Tests, falls vorhanden, sonst neu): Endreinigung
  nur bei qualifizierter Schliessung; Eröffnung aus Übergang; „erledigt"-Unterdrückung.
- `flutter analyze` ohne neue Findings; Tests grün.
- **Visueller Browser-Test** (Pflicht, live): Saisonbetrieb kurz vor Saisonende → Endreinigung-
  Auto-Termin am letzten offenen Tag; nach Saisonstart → Eröffnung-Auto-Termin; „übernehmen" schiebt
  ihn in den Plan (Auto-Save); kurze Betriebsferien lösen **keine** Endreinigung aus; Ruhetag wird beim
  Ziel-Tag übersprungen.

## Deploy

Ein Paket **v0.30.0** nach Deploy-Workflow (CLAUDE.md). Keine Migration.
