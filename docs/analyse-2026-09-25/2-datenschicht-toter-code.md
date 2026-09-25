# Analyse 2 — Datenschicht, Services, Provider, toter Code (Stand v0.138.0, 25.09.2026)

Nur gelesen, nichts geändert. Belege per Grep/Import-Graph über `lib/` + `test/` (Pfade relativ zu `sbs_projer_app/`).
Grössen: 694 handgeschriebene Dart-Dateien, **136'678 Zeilen** in `lib/` ohne `.g.dart`; dazu **108'413 Zeilen** Isar-`.g.dart` (3 MB).
DB-Mengen (prod, 25.09.): rechnungen **5'278**, reinigungen **8'695**, buchungen **16'879**, betriebe 449, anlagen 303.

---

## 1. Doppelspurigkeiten (Funktionen, die fast dasselbe tun)

| # | Gruppe | Fundstellen | Befund | Vorschlag |
|---|---|---|---|---|
| D1 | **Reinigungs-Rechnung erzeugen + mailen** | `presentation/screens/reinigungen/reinigung_form_screen.dart:569–~1390` (`_save`, ruft `RechnungService.createFromReinigung` :937, 3× `send-rechnung-mail` :869/:1000/:1102, setzt `gesendet` :1038/:1125) vs. `services/rechnung/reinigung_rechnung_versand.dart:82` (`erstelleUndSende`, gleiche Kette, 2× Mail :152/:212, `gesendet` :189/:235) | Die Abschlusskette existiert **zweimal**: einmal im Screen (Normalfall), einmal im Service (Nachholen aus `reinigung_detail_screen.dart:468`). Jeder Fix an der Kette (Vermerk-Flag, Guthaben, PDF-Stand) muss doppelt gemacht werden — die Kommentare bei :1026ff. zeigen, dass das schon passiert ist. | Screen ruft nur noch `ReinigungRechnungVersand.erstelleUndSende`; Screen-Code (~400 Z.) weg. **Höchster Nutzen im ganzen Bericht.** |
| D2 | **Mail-Versand** | `send-rechnung-mail` an **11 Stellen in 8 Dateien**, davon 6 in Screens (`heineken_rechnung_detail_screen.dart:167`, `material_bestellung_screen.dart:270`, `montage_form_screen.dart:819`, `rechnung_detail_screen.dart:818`, `reinigung_form_screen.dart` 3×) + `mahnfall_service.dart:285`, `mahnlauf_service.dart:302`, `reinigung_rechnung_versand.dart` 2×. `send-pdf-mail` nur `services/mail/bericht_mail_service.dart:17`. | Body-Aufbau (Empfänger, `bodyText`, `protokollFotoPfad`, Vermerk-Flag, Fehlerauswertung) 11× von Hand. `send-rechnung-mail` ist längst die generische Mail-Function (auch Materialbestellung/Montage). | Ein `MailService.sende({pfad, an, betreff, text, anhaenge, vermerkRechnungId})` in `services/mail/`; `bericht_mail_service` darin aufgehen lassen. Zwei Edge Functions können bleiben, der Dart-Zugang wird einer. |
| D3 | **«Alle Rechnungen» laden, dann filtern** | `heineken_providers.dart:10` (getAll → `heineken_monat`), `camt_import_tab.dart:474` (getAll → offene + Heineken), `kundenzahlung_zuordnen_dialog.dart:33` (getAll → offene), `rechnung_providers.dart:7` `rechnungenStreamProvider` | 4 Wege laden alle 5'278 Zeilen, obwohl es `RechnungRepository.getOffene()` (:130) und `getKundenrechnungenAb()` (:226) gibt. | `heinekenRechnungenProvider` → `.eq('rechnungstyp','heineken_monat')` (~60 Zeilen); camt/Dialog → `getOffene()`. |
| D4 | **Was heisst «offen»?** | Helfer existiert: `core/util/offene_pro_betrieb.dart:24–26` (`kErledigteStatus`, `istOffen`) — nur 2 Aufrufer. Inline-Kopien `!= bezahlt && != abgeschrieben` an **12 Stellen** (u. a. `rechnung_providers.dart:21`, `rechnungen_list_screen.dart:520`, `mahnfall_screen.dart:459`, `mahnfall_service.dart:404/:565`, `barzahlung_service.dart:85`, `guthaben.dart:80`, `jahrgang_abschreibung.dart:143`, `mahn_hinweis.dart:107`, `mahnfall_regeln.dart:44`, `rechnung_repository.dart:119/:139`). **Abweichend:** `camt_import_tab.dart:479` + `kundenzahlung_zuordnen_dialog.dart:39` = nur `offen`/`gesendet`; `heineken_matcher.dart:14` + `camt_import_tab.dart:495` = nur `!= bezahlt` (abgeschrieben zählt als offen). | Der camt-Abgleich übersieht Kundenrechnungen in `erinnert`/`mahnung_1`/`mahnung_2` sowie **alle Jahresrechnungen** als Zahlungskandidaten. Heute latent (DB: 0 solche offen), wird mit dem ersten Mahnlauf scharf: eine gemahnte Rechnung, die bezahlt wird, matcht nicht automatisch. | `istOffen()` nach `core/util/rechnung_status.dart`, alle 15 Stellen darauf; camt bewusst entscheiden (Empfehlung: `istOffen` + `rechnungstyp in (kundenrechnung, jahresrechnung)`). |
| D5 | **Rechnung auf «bezahlt» setzen** (Status + `zahlung_betrag` + `zahlung_eingegangen_am` + Buchung) | `camt_auto_booker.dart:90/:116/:277`, `forderungs_abgleich_service.dart:318` (+ Rücknahme :354), `barzahlung_service.dart:260/:336` (+ Rücknahme :317), `rechnung_service.dart:91` (Guthaben), Heineken-Screen `heineken_rechnung_detail_screen.dart:335`. Insgesamt **22 Schreibstellen** für `zahlungsstatus` in 11 Dateien, 4 davon in Screens (`rechnungen_list_screen.dart:963`, `heineken_rechnung_detail_screen.dart:186/:335`, `reinigung_form_screen.dart:1038/:1125`). | Doppelte Wahrheit Rechnung ↔ Buchungen wird an 7 Orten von Hand synchron gehalten; Rücknahme-Logik 2× eigenständig. | Ein `RechnungZahlungService.alsBezahlt(rechnung, betrag, datum, buchungIds)` / `.zuruecknehmen(...)`; Screens schreiben nie mehr direkt `zahlungsstatus`. |
| D6 | **MwSt-Satz — drei Quellen** | `MwstSatzService` (datumsgenau, Normal+Reduziert); `RechnungService._mwstFaktor` **statisch-veränderlich** (`rechnung_service.dart:23–32`, aus Preisliste); `ReinigungBuchungService._mwstFaktor` ebenso (`reinigung_buchung_service.dart:41/:82`); Hartwerte `8.1`/`0.081` u. a. `reinigung_form_screen.dart:630/:1735`, `heineken_buchung_service.dart:36`, `jahresrechnung_generate_screen.dart:148/:371`, `heineken_monats_daten.dart:61`. | Statischer Zustand zwischen Aufrufen (zwei Reinigungen mit unterschiedlichem Datum parallel → falscher Satz möglich). | Satz immer per Aufruf aus `MwstSatzService.satzFuerDatum` (oder Preisliste) holen, keine statischen Felder. |
| D7 | **5-Rappen-Rundung** | Zwei gleichnamige Helfer: `core/util/rundung.dart:15` `rundeAuf5Rappen` und `core/util/beleg_korrektur.dart:4` `runde5Rappen`; dazu 8 private Kopien (`reinigung_buchung_service.dart:44`, `montage_form_screen.dart:612`, `jahresrechnung_generate_screen.dart:32`, `reinigung_detail_screen.dart:240`, `reinigung_form_screen.dart:1697`, `rechnung_detail_screen.dart:584/:594`, `rechnungen_list_screen.dart:1242`). | Kosmetisch, aber jede Kopie ist eine Stelle, an der Rundungsregeln auseinanderlaufen. | Nur `rundeAuf5Rappen`; `runde5Rappen` löschen. |
| D8 | **Firmendaten hartcodiert** trotz `geschaeft_einstellungen` | IBAN `CH66 0077 …` 3×: `heineken_pdf_service.dart:25`, `kontoauszug_pdf_service.dart:50`, `qr_zahlteil.dart:22`; Adresse/Tel/MWST-Nr in `bericht_pdf_common.dart:8`, `bestellung_pdf_service.dart:17/:19`, `heineken_pdf_service.dart:17–21`, `kontoauszug_pdf_service.dart:444/:447/:475`, `mahnschreiben_pdf_service.dart:375/:393`, `rechnung_pdf_service.dart:152/:176`. | Die zentrale Quelle ist nur teilweise durchgesetzt (teils als Fallback, teils fix). Ändert sich Bank/Telefon, stimmen QR-Rechnung und PDF-Fuss nicht mehr. | Alle PDF-Services über `GeschaeftEinstellungen`-Getter; Fallback-Konstanten an **einer** Stelle. |
| D9 | **Kontensaldi — drei Rechenwege** | `BuchungService.getAllSaldi` (`services/rechnung/buchung_service.dart:56`, alle Buchungen, Vorzeichen-Flip Klasse 2/3/8/9), `BilanzService` (`bilanz_service.dart:90`), `ErfolgsrechnungService` (:74/:118); **Dashboard** dagegen aus DB-Views `view_erfolgsrechnung`/`view_mwst_abrechnung` (`buchhaltung_providers.dart:28/:39`, genutzt nur `buchhaltung_dashboard_screen.dart:20–21`). | Alle Dart-Wege teilen `SaldoExpansion` (gut). Aber «Umsatz Monat»/«MwSt Quartal» im Dashboard rechnet die DB, die Berichte rechnet Dart — zwei Wahrheiten, die nicht gegeneinander getestet sind. | Dashboard auf `erfolgsrechnungZeitraumProvider` umstellen, Views danach prüfen/entfernen. |
| D10 | **PDF anzeigen** | `Printing.sharePdf/layoutPdf` in 13 Screens (16 Aufrufe) vs. `oeffnePdfImNeuenTab` (`pdf_tab_oeffner_*`) in 3 Stellen | Zwei Verhaltensweisen für dasselbe (Web: Druckdialog vs. neuer Tab). | Ein Helfer `zeigePdf(bytes, name)`; Entscheid einmal treffen. Niedrige Priorität. |
| D11 | **Betriebe/Buchungen am Provider vorbei** | `BetriebRepository.getAll()` direkt: `abschreibung_providers.dart:61`, `jahresrechnung_providers.dart:10`, `heineken_raster_screen.dart:43`, `buchung_nachhol_service.dart:165`; `BuchungRepository.getAll()` direkt: `buchhaltung_providers.dart:291/:306/:318`, `camt_import_tab.dart:558` | Jeder Aufruf lädt 16'879 Buchungen neu (Bilanz, ER, ER-Konten = 3× beim Öffnen der Berichte). | Bilanz/ER/ER-Konten aus **einem** `buchungenStreamProvider.future` speisen. |

---

## 2. Toter Code (belegt: kein Import bzw. kein Aufruf in `lib/`)

### 2a. Ganze Dateien — vom `main.dart`-Importgraph nicht erreichbar (17 Dateien, **2'521 Zeilen**)

| Datei | Zeilen | Bemerkung |
|---|---|---|
| `services/pdf/reinigung_pdf_service.dart` | 789 | bekannt tot (Protokoll = Foto) |
| `services/pdf/reinigung_pdf_storage.dart` | 38 | nur von obigem Umfeld, selbst nirgends importiert |
| `services/camt/camt_import_service.dart` | 141 | Vorgänger des Auto-Bookers |
| `services/pdf/bankbeleg_pdf_service.dart` | 199 | nur von `camt_import_service` importiert → mittot |
| `presentation/widgets/system_diagram/*` (4 Diagramme + `diagram_components.dart`) | 570 | kein Import |
| `presentation/screens/betriebe/betrieb_kontakt_form_screen.dart` | 312 | Route nutzt `KontaktFormScreen` (`router.dart:247–262`) |
| `presentation/screens/materialien/bestellliste_screen.dart` | 132 | kein Import, keine Route |
| `presentation/providers/auth_provider.dart` | 17 | alle 3 Provider ungenutzt |
| `data/models/formular.dart`, `data/models/user_profile.dart` | 180 | Klassen nirgends referenziert |
| `presentation/widgets/filter/app_filter_sheet.dart` | 70 | `showAppFilterSheet` ohne Aufrufer |
| `presentation/widgets/filter/app_active_filters.dart` | 34 | nur Test `test/widgets/app_filter_widgets_test.dart:4` |
| `presentation/providers/kachel_zaehler_providers.dart` | 39 | enthält nur noch `kommenderSonntag`; nur `test/kachel_zaehler_test.dart` |

### 2b. Tote Funktionen in Services (Auswahl mit Gewicht)

| Stelle | ~Zeilen | Beleg |
|---|---|---|
| `services/camt/camt_auto_booker.dart:32` `CamtAutoBooker.run` | ~140 | UI nutzt nur `plan`/`bucheVorschlag`/`zuPruefliste` (`camt_import_tab.dart:539/:546/:1089`) |
| `services/buchhaltung/zahlungsdifferenz_service.dart:177` `verbuchen` | ~95 | bekannt tot; genutzt werden `verbuchenSammel`/`verrechnungBuchen` |
| `presentation/providers/tour_providers.dart:995` `tourVorschlagErweitertProvider` | ~120 | kein `ref.watch` |
| `tour_providers.dart:344` `faelligeAnlagenCountProvider`, `:1846` `tagesplanLoeschen()` | ~25 | kein Aufrufer |
| `services/pdf/heineken_pdf_service.dart:40` `HeinekenPdfService.generate` | ~40 | nur `build*` werden von `heineken_rechnung_service.dart:201ff.` genutzt |
| `services/pdf/heineken_rapport_service.dart:724` `generateAnfahrtspauschale` | ~23 | kein Aufrufer |
| `services/camt/camt_betrieb_matcher.dart:9` `matchAll` | ~17 | kein Aufrufer |
| `services/rechnung/buchung_service.dart:110` `getKontoSaldo` | 4 | lädt alle Buchungen für 1 Konto — gut, dass tot |
| `services/rechnung/rechnung_service.dart:43` `brauchtRechnung` | 2 | Logik steckt inline in :118 |
| `services/buchhaltung/mwst_satz_service.dart:56` `reduzierterSatzFuerDatum` | – | kein Aufrufer |
| `services/pdf/rechnung_pdf_storage.dart:129` `getMahnfallSignedUrl`; `services/storage/protokoll_foto_storage.dart:79` `deleteFoto`; `services/pdf/pdf_schrift.dart:45` `zuruecksetzen`; `services/connectivity/connectivity_service.dart:34` `dispose` | – | kein Aufrufer |
| `services/rechnung/barzahlung_service.dart:100` `darfKassieren` | – | nur Test |

### 2c. Tote Repository-Methoden (29) — Kurzliste
`count()` in Anlage/Bergkundenpauschale/Betrieb/Eigenauftrag/Eroeffnungsreinigung/Lager/Montage/Pikett/Rechnung/Region/Reinigung/Stoerung-Repository (12×, Relikte der alten Kachelzähler); `RechnungRepository.countOffene:110`; `BetriebRepository.getAktive:28/getByRegion:52`; `ReinigungRepository.getByServerId:201`; `KontaktRepository.watchByBetrieb:33/getEmailByKategorieRolle:84`; `KontoRepository.getByNummer:20`; `LagerRepository.countNiedrig:41/clearVorgemerkt:84`; `BuchungsVorlageRepository.cacheLeeren:24/getById:49/getByTrigger:59`; `AnrufLogRepository.getLetzteAnrufe:19/getByKontakt:30`; `BetriebFerienRepository.getFuerBetrieb:36/loeschen:90`; `BergkundenpauschaleRepository.save:83`; `TerminRepository.loeschen:91`; `MaterialArtikelRepository.getAll:9`; `MaterialBestellungRepository.getById:18`; `MahnschreibenRepository.getByBetrieb:18`; `ZahlungsfileRepository.getAll:20`; `GuthabenRepository.offenesGuthabenAlle:15`; `CamtPrueflisteRepository.getAlleTxKeys:15`; `AbschreibungLaufRepository.getPositionen:18`.

### 2d. Tote Provider (45) — nie gewatcht/gelesen
Alle `*CountProvider`/`*CountAktuellesJahrProvider` (anlage, bergkundenpauschale ×2, betrieb, buchungen, eigenauftrag ×2, eroeffnungsreinigung ×2, heinekenRechnung, konten, material, vorgemerkt, montage ×2, pikettDienst, rechnung, reinigung ×2, stoerung ×2, spesenBelegeAktuellesJahr); alle `*ByBetriebProvider`/`*ByAnlageProvider` (anlagen, bergkundenpauschale, eigenauftraege, eroeffnungsreinigungen, kontakte, montagen ×2, rechnungen, reinigungen ×2, stoerungen ×2); `buchungenByPeriodeProvider`, `buchungenByKontoProvider`, `buchungenCountByPeriodeProvider` (`buchung_providers.dart:18–33`); `biersorteKategorieMapProvider`, `heinekenMonatsDatenProvider`, `offeneJahresreinigungenProvider`, `lohnJahresTotaleProvider`, `isAuthenticatedProvider`, `currentUserProvider`, `faelligeAnlagenCountProvider`, `tourVorschlagErweitertProvider`.
→ Nach B1/B2 (Kacheln und Einzellisten weg) ist fast die ganze «Count/ByX»-Schicht verwaist.

### 2e. Sonstiges
- **Ungenutzte Abhängigkeiten:** `riverpod_annotation` + `riverpod_generator` (`pubspec.yaml:18/:82`) — kein `@riverpod` in `lib/`.
- **Routen** ohne Navigationsaufruf sind nur Weiterleitungen alter Links (`/buchhaltung/bilanz`, `camt-regeln`, `camt-dateien`, `router.dart:576/:647/:651`) — bewusst, bleiben.
- **Modellfelder, die ausserhalb des Modells nie gelesen werden: 49** (u. a. `camt_transaction.dart` 8 Adressfelder `partyStreet…partyAddressLines:40–45`, `statementId:3`, `isBatchChild:61`; `material_artikel.dart` `istAuslaufartikel/auslaufDatum/nachfolgerId:12–14`; `termin.dart` `uhrzeitBis:15/datumBis:19`; `lohn_abrechnung.dart` `istGebucht/istAusbezahlt:23–24` (wird nur geschrieben, `lohn_repository.dart:89`); `zahlungsfile.dart` `msgId/anzahlTx/ctrlSum`; `mahnfall.dart` `heinekenErgebnisAm/aktualisiertAm`; `pikett_dienst.dart` `kalenderSyncFehler/kalenderSyncAt`; `preis.dart` `mwstSatzReduziert:7` (Reduziert-Satz kommt aus `MwstSatzService`); `eingangsrechnung.dart` `gebuchtAm/zahlungsfileId`). Sie kosten nur Parsing; bei geteilter DB mit v2 **nicht** aus der DB entfernen, nur aus dem DTO, wenn überhaupt.

---

## 3. Provider-Landschaft

**Zahlen:** 108 Future/Stream-Provider, nur **15** `autoDispose`. **49 `.family`-Provider ohne `autoDispose`** — jeder je Schlüssel (Betrieb, Jahr, Datum, Zeitraum) gecachte Wert bleibt bis zum Neuladen der Seite.

| Tabelle | App-weite Voll-Liste (kein autoDispose) | Wer hängt dran | Befund |
|---|---|---|---|
| **rechnungen** (5'278) | `rechnungenStreamProvider` (`rechnung_providers.dart:7`) + `rechnungenProvider` | `rechnungen_list_screen.dart:455`, `offen_pro_betrieb_screen.dart:116`, `suche_provider.dart:17`, `buchhaltung_dashboard_screen.dart:22` (nur für `offeneRechnungenCountProvider`) | Dashboard lädt 5'278 Zeilen für **eine Zahl** (`countOffene()` existiert, tot). Suche braucht nur Nr./Betrieb/Betrag (schmale Spaltenliste reicht). Offen-pro-Betrieb braucht offene + Jahresübersicht → `getOffene()` + gezielt pro Betrieb. Die Liste selbst ist der einzige legitime Voll-Nutzer (Filter «Alle Jahre»); dort Jahr-Filter serverseitig wie bei Reinigungen (`getByJahr`). 20 `invalidate(rechnungenStreamProvider)` bleiben gültig. |
| **buchungen** (16'879) | `buchungenStreamProvider` (`buchung_providers.dart:6`) | Direkt: `buchungen_list_screen.dart:36`, `buchhaltung_dashboard_screen.dart:19` (nur Monatszahl), `steuern_providers.dart:43/:103`, `abschlussPruefungProvider` (`buchhaltung_providers.dart:173`). **Als reines Invalidierungssignal** `ref.watch(buchungenStreamProvider)`: `kontoSaldiProvider:38`, `spesenBelegeCount…:45`, `bankWaechterProvider:128`, `steuern_providers.dart:122/:129`, drei tote By-Periode-Provider | Das Muster «watch als Signal» **lädt das ganze Journal**, nur damit ein anderer Provider neu rechnet. Zusätzlich laden Bilanz/ER/ER-Konten je selbst `getAll()` (D11). Beim Öffnen von Berichten → bis 4× 16'879 Zeilen. | Signal-Provider: eigener `buchungenVersionProvider = StateProvider<int>` hochzählen statt Voll-Liste watchen; Dashboard-Monat per `getByPeriode`. |
| **reinigungen** (8'695, ohne `hahn_temperaturen`) | `reinigungenStreamProvider` | `heute_providers.dart:36` (Startseite!), `tagesuebersicht_provider.dart` 4×, `tour_providers.dart` 9×, `auswertung_providers.dart:39`, `tages_karte_screen.dart:90`, `tourenplanung_screen.dart:1408`, `reinigung_form_screen.dart:720` | Beim App-Start lädt die Heute-Seite alle 8'695 Reinigungen, um «letzte Reinigung je Anlage» und Tageszahlen zu bestimmen. Liste nutzt schon `reinigungenByJahrProvider`. | Mittelfristig: DB-View/RPC «letzte Reinigung je Anlage/Betrieb» (~300 Zeilen) für Touren/Heute; Voll-Liste nur für Auswertung. |
| **betriebe** (449) | `betriebeStreamProvider` | überall | Unkritisch; nur die 4 Direkt-`getAll()` (D11) sind überflüssig. |

**Nicht-autoDispose-Families mit grossen Werten (Kandidaten für `autoDispose`):** `reinigungenByJahrProvider` (`reinigung_providers.dart:27`, ~1'000 Zeilen je Jahr), `bilanzStichtagProvider`/`erfolgsrechnungZeitraumProvider`/`erKontenAufstellungProvider` (`buchhaltung_providers.dart:290/:305/:317`, je Stichtag/Zeitraum), `einsaetzeProvider` (`einsatz_providers.dart:33`), `dokumenteProvider` (`dokument_providers.dart:7`), `wegpunkte/Tagesplan` je Datum (`tour_providers.dart:1200/:1515`).

---

## 4. Modelle: doppelte Wahrheiten (soweit nicht in `einsatz_lage.dart` gelöst)

| Wahrheit | Orte | Risiko |
|---|---|---|
| Rechnung bezahlt? | `rechnungen.zahlungsstatus` + `zahlung_betrag` + `zahlung_eingegangen_am` **und** Buchungen mit `beleg_id` | 7 Schreibwege (D5); Mahnlauf/Glocke erkennen «Zahlung gebucht, Status hinkt nach» schon selbst (`buchung_repository.dart:37ff.`) — das ist die Reparatur einer Doppelwahrheit, nicht ihre Beseitigung. |
| Rechnung versendet? | `zahlungsstatus='gesendet'` **und** `versendet_am` (+ Vermerk durch Edge Function) | Setzen an 4 Stellen (Screen 2×, Versand-Service 2×), Rücknahme leitet Status aus `versendet_am` ab (`forderungs_abgleich_service.dart:354`). |
| «offen» | siehe D4 — drei verschiedene Definitionen | camt-Matching lückenhaft. |
| MwSt-Satz | Preisliste `mwst_satz`/`mwstSatzReduziert` vs. `MwstSatzService` vs. Hartwerte | D6. |
| `abgerechnet` vs. Ertragsbuchung | bereits in `core/util/einsatz_lage.dart:53` zusammengeführt | erledigt, nicht wiederholt. |

---

## 5. Der native Isar-Zweig

**Umfang, der nur für Native existiert:**

| Teil | Zeilen |
|---|---|
| `data/local/*_local.dart` (28 Isar-Modelle, ohne `.g`) | 1'176 |
| `data/local/*.g.dart` (generiert) | 108'413 |
| `data/local/web/*` (25 Web-Stubs) + 25 `*_export.dart` | 842 + 25 |
| `services/storage/isar_service.dart` (+ Web-Stub 235) | 707 (+235) |
| `services/sync/sync_service.dart` (+ Stub 24) | 1'424 (+24) |
| **Summe handgeschrieben** | **≈ 4'400** (+ ~50 % der Branch-Zeilen in 25 Repositories) |

Mapper (1'604 Z.) werden auch im Web gebraucht (`fromDto`), zählen nicht dazu.

**Abdeckung:** Nur **25 von 63 Repositories** haben überhaupt einen `kIsWeb`-Zweig. Die übrigen 38 — **die gesamte Buchhaltung, Rechnungen, Mahnwesen, Kreditoren, Lohn, Dokumente, Material** — sind reine Supabase-Zugriffe. Eine native App wäre nur für Stammdaten + Einsätze offline-fähig.

**Stichprobe 5 Repositories** (Methoden mit beiden Zweigen / öffentlich):
Anlage 9/9, Reinigung 14/14, Stoerung 13/13, Montage 13/13, Betrieb 9/12 — auf Methodenebene gepflegt. Feldlisten Isar ↔ Web-Stub sind in allen 25 Paaren identisch (Script-Vergleich). **Aber semantische Drift:**

1. **ID-Semantik:** Web `getById(serverId)`, Native `getById(int.parse(id))` (53× `int.parse(id)` in Repositories). Aufrufer, die eine Server-UUID übergeben, **crashen nativ**: `mahnfall_service.dart:196/:583` (`BetriebRepository.getById(fall.betriebId)`), Routen `'/betriebe/${p.betriebId}'` in `bergkundenpauschale_detail_screen.dart:164`, `core/util/aufgabe.dart:283/:307`. `routeId` ist uneinheitlich (`bergkundenpauschale_local.dart:9` ohne `kIsWeb`-Weiche).
2. **Sync-Lücken:** `KontaktLocal` und `BergkundenpauschaleLocal` haben Isar-Collection + native Repository-Zweige, aber **keinen `_sync…`** in `sync_service.dart` (25 Sync-Funktionen, :138–236) → nativ nie befüllt.
3. **Nur-Supabase-Methoden in Branch-Repositories:** `BergkundenpauschaleRepository.create`, `BetriebRepository.loeschHindernisse`, `KontaktRepository.*HeinekenZuweisung*` (3).
4. Pflegeaufwand real: seit 01.08. 14 Commits nur an `data/local`/`isar_service`/`sync_service` (Events-Vertikale, Eissäule, Kulanz, Herbstpause) — jede neue Spalte kostet Isar-Feld + `build_runner` + Stub + Mapper + Sync.
5. Isar 3.1 (`pubspec.yaml:24`) ist upstream nicht mehr gepflegt.

**Empfehlung: einfrieren, nicht weiter mitpflegen — und die Vorlage als Adapter-Schnitt dokumentieren.**
- Der Zweig ist schon heute keine lauffähige Vorlage (Crash-Pfade, Sync-Lücken, 60 % der Domäne fehlen). Ihn mitzuziehen kostet bei jeder Migration Zeit, ohne dass ihn je etwas testet.
- Die v2/Android-App entsteht im Heineken-Projekt mit eigenem Modell (ADRs dort) — sie übernimmt Konzepte (Push/Pull, LWW, Tier-Reihenfolge), nicht diese Dateien.
- Konkret: Stand in `docs/` festhalten («Isar-Zweig eingefroren ab v0.13x, letzte vollständige Entität X»), neue Spalten nur noch im DTO/Web-Stub, `sync_service.dart` als Referenz stehen lassen. Später (eigener Schritt, nach Rücksprache mit der Heineken-Session) ganz entfernen: −108k generierte Zeilen, −~4'400 Handzeilen, `kIsWeb`-Zweige in 25 Repositories halbieren.

---

## 6. Priorisierte Aufräum-Vorschläge

| Prio | Massnahme | Nutzen | Aufwand |
|---|---|---|---|
| **1** | **D1** Reinigungs-Abschluss im Screen durch `ReinigungRechnungVersand.erstelleUndSende` ersetzen | Kette (Rechnung→PDF→Mail→Vermerk) nur noch einmal; genau die Stelle, an der 38 stille Ausfälle und die «Kette bricht ab»-Fälle lagen | 1–1,5 Tage + Browser-Test |
| **2** | **D4** `istOffen` zentral + camt-Kandidaten auf Mahnstufen/Jahresrechnungen erweitern | Verhindert, dass bezahlte gemahnte Rechnungen nicht matchen (scharf ab erstem Mahnlauf) | ½ Tag + Test |
| **3** | Toten Code löschen: 17 Dateien (2'521 Z.) + ~450 Z. tote Funktionen + 45 Provider + 29 Repo-Methoden + 2 Dev-Dependencies | Weniger Grep-Rauschen, weniger Irrläufer bei Analysen (z. B. `reinigung_pdf_service`) | ½ Tag (rein mechanisch → Sonnet-Subagent) |
| **4** | Buchungen-Ladeverhalten: «watch als Signal» durch Versionszähler ersetzen; Bilanz/ER/ER-Konten aus einem Load (D11); Dashboard-Zahl per `countOffene`/`getByPeriode` | Berichte-/Dashboard-Ladezeit: bis 4× 16'879 Zeilen → 1× | 1 Tag |
| **5** | **D5** `RechnungZahlungService` (bezahlt/zurücknehmen) + **D2** `MailService` | Doppelwahrheit an einer Stelle; Screens schreiben keinen Status mehr | 2 Tage |
| **6** | **D3** gezielte Rechnungs-Queries (Heineken, camt, Dialog, Suche schmal) | −5'000 Zeilen je Aufruf | ½ Tag |
| **7** | **D6/D7/D8** MwSt ohne statischen Zustand, eine Rundung, Firmendaten aus `geschaeft_einstellungen` | Weniger Stellen bei Satz-/Bankwechsel; QR-IBAN nur an einem Ort | 1 Tag |
| **8** | Isar-Zweig einfrieren (Doku), später entfernen | Jede künftige Migration ~30 % billiger | Einfrieren: 1 h; Entfernen: 1–2 Tage (nach Absprache Heineken) |
| 9 | `autoDispose` für grosse Families; Reinigungs-«letzte je Anlage» als View | Speicher/Startzeit Heute-Seite | 1–2 Tage |
| 10 | D9 Dashboard auf Dart-ER, D10 ein PDF-Anzeige-Helfer | Konsistenz | je ½ Tag |

Methodik-Hinweis: Tote Funktionen/Provider wurden per Namens-Grep ermittelt (Definition ohne Referenz ausserhalb der eigenen Datei, bzw. `Klasse.methode` ohne Aufrufer in `lib/`). Gleichnamige Methoden in anderen Klassen können Treffer verdecken — die Liste ist eine **Untergrenze**, jeder Eintrag ist aber einzeln belegt.
