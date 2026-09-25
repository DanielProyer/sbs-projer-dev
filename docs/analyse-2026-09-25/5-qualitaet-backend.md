# Analyse 5 — Tests, Wächter, Codequalität, Backend-Hygiene

Stand 25.09.2026, `main` @ f2cc9a89 (v0.138.0). Nur gelesen; `flutter analyze` und `flutter test` liefen lokal.

## Kurzfazit

1. **Sicherheit, dringend:** `send-pdf-mail` hat dasselbe Loch wie `send-rechnung-mail` vor v24, nur grösser. Es gibt keine Auth-Prüfung, die Function ist mit `--no-verify-jwt` deployed, und `to`, `subject` und PDF kommen frei aus dem Body. Damit ist sie ein **offenes Mail-Relay über sbs.projer@gmail.com mit beliebigem PDF-Anhang** (Phishing im Firmennamen).
2. Sechs weitere Functions prüfen den Benutzer nicht selbst: `parse-protokoll`, `parse-oeffnungszeiten`, `betrieb-google-lookup`, `betrieb-google-abgleich`, `betriebsdaten-abgleich` und `anfahrt-google`. Folgen: Kosten auf Anthropic- und Google-Keys, dazu SSRF und DB-Schreibzugriffe mit dem Service-Role-Key.
   **Wichtig:** `verify_jwt = true` allein schützt nicht. Der öffentliche Anon-Key im Web-Bundle ist selbst ein gültiges JWT. Schutz bringt nur `auth.getUser()` im Code.
3. Die App ruft `send-raster-mail` auf (`heineken_raster_screen.dart:260`), dafür gibt es aber **keinen Quellcode** in `supabase/functions`. Die Function ist entweder nur auf dem Server vorhanden und ungeprüft, oder der Aufruf läuft ins Leere.
4. Tests: **2234 grün in 1:46 min**. Dazu kommen 20 Wächter-Dateien von guter Qualität. Die grossen Lücken sind Repositories, der Sync, die Heineken-Rechnung und die Preisberechnung in den Formular-Screens.
5. `flutter analyze` meldet 56 Befunde, keiner davon ist akut. 12 stammen aus generiertem Isar-Code und 18 sind `context` über async-Grenzen hinweg (meist harmlos). 42 der 56 lassen sich mit Kleinfixes beheben.

---

## 1. Tests

### Kennzahlen

| | Wert |
|---|---|
| Tests gesamt (Lauf) | **2234 bestanden**, 0 fehlgeschlagen |
| Laufzeit `flutter test` | 1 min 46 s (Wall) |
| Laufzeit `flutter analyze` | ca. 12 s |
| Testdateien | 231 Einträge in `test/` (inkl. Unterordner) |
| `test(` / `testWidgets(` | 2046 / 175 (Widget-Tests in 34 Dateien) |
| Wächter (lesen Quellcode/Dateien) | 20 Dateien |
| Mocks (mocktail/mockito) | faktisch keine (2 Dateien) → DB-Code ist kaum testbar |
| Deno-Tests Edge Functions | 2 von 17 (`google-contacts-sync/mapping_test.ts`, `send-rechnung-mail/pfad_pruefung_test.ts`) |

### Kategorien

| Kategorie | Anteil (grob) | Beispiele |
|---|---|---|
| Reine Regeln/Rechner | ca. 80 % | camt_*, mahn*, rechnung_matcher, rundung, swiss_qr, steuerjahr_rechner, saison_*, zeitplan |
| Widget-Tests | ca. 8 % | einsaetze_screen, mahnfall_screen, heute_liste, zeitplan_leiste, adresse_knopf_layout |
| Wächter/Ratschen (Quelltext-Scan) | 20 Dateien | siehe unten |
| DTO/Mapper | klein | betrieb_mapper, event_technik_mapper, rechnung_model |

### Wächter-Inventar

| Wächter | Schützt | Reichweite |
|---|---|---|
| `app_version_test` | pubspec-Version == `kAppVersion` | fest (2 Dateien) |
| `web_404_weiche_test` | 404.html ↔ Versions-Redirect in index.html | fest |
| `pdf_schrift_test` | kein nacktes `pw.Document()`, Roboto im Bundle | **alle lib** |
| `pagination_stabil_test` | `.range()` nur mit `.order('id')` zuletzt | alle lib |
| `offenes_datumsfenster_test` | offene `gte('datum')` auf 5 Tabellen nur mit range/limit | alle lib, **5 Tabellen fest** |
| `null_filter_waechter_test` | kein `.neq()` auf nullbaren Spalten | alle lib, **Spaltenliste fest: nur `quelle`** |
| `in_filter_block_test` | Id-Blöcke nur mit `kInFilterBlock` (≤ 50) | alle lib |
| `canvaskit_sichere_widgets_test` | kein `ExpansionTile(dense: true)` | alle lib, **nur dieses eine Muster** |
| `gefahr_knopf_waechter_test` | kein Material-Button mit `AppColors.error` | alle lib |
| `zeitauswahl_waechter_test` | kein `showTimePicker` ausserhalb `zeit_auswahl.dart` | alle lib |
| `rohe_ausnahme_ratsche_test` | keine rohe Exception in einer SnackBar (harte 0) | alle lib + 3 Mailpfad-Dateien fest |
| `status_vergleiche_ratsche_test` | Einsatz-Statusvergleiche ≤ 20 (Ratsche) | alle lib, 3 Ausnahmen |
| `versandvermerk_waechter_test` | jeder `send-rechnung-mail` mit rechnungId sendet `markiereVersandt` | alle lib |
| `formular_schutz_waechter_test` | jedes `*_form_screen.dart` mit UngespeichertSchutz komplett | alle Screens (per Namensmuster) |
| `formular_ohne_navigation_waechter_test` | FormScreen-Routen ohne Nav-Leiste | router.dart |
| `erreichbarkeit_waechter_test` | jede Listen-Route erreichbar | router.dart |
| `menue_ziele_test` | literale Navigationsziele existieren | router.dart |
| `alte_listen_ablauf_test` | alte Listenrouten ab v0.106.0 weg | router.dart |
| `audit_service_entfernt_test` | kein Import von AuditService | alle lib |
| `mahnwesen_testmodus_waechter_test` | `mahnwesenScharf == false`, TEST im Betreff | **3 Dateien fest** |
| `aufgaben_eine_quelle_waechter_test` | 5 Oberflächen lesen nur die neuen Aufgaben-Provider | **5 Dateien fest** |
| `plan_ist_beginn_waechter_test` | Plan-/Ist-Beginn getrennt | **2 Dateien fest** |
| `diktat_reinigung_waechter_test` | Diktat speichert bei Reinigung nichts | **1 Datei fest** |
| `servicezeit_durchsicht_filter_test` | Durchsicht filtert `ist_mein_kunde` | 1 Datei fest |
| `kachel_text_test` (Teil) | Startseite = nur der Tag | home_screen fest |

**Wächter mit fester Dateiliste**, die neue Dateien nicht erfassen: aufgaben_eine_quelle, plan_ist_beginn, mahnwesen_testmodus, diktat_reinigung, servicezeit_durchsicht, dazu die Spalten- und Tabellenlisten in null_filter und offenes_datumsfenster. Der CanvasKit-Wächter geht zwar über alle Dateien, prüft aber **nur `ExpansionTile dense`**. Zwei der drei Vorfälle bleiben damit ungeschützt: `FilledButton` in AppBar-`actions` und unsichtbare Filled- oder Outlined-Buttons. Im Code stehen aktuell 161 Filled- und Outlined-Buttons.

### Vorschläge: Wächter über ALLE Screens und Functions

| Neuer Wächter | Prüft | Aufwand |
|---|---|---|
| **Edge-Auth-Wächter** (Dart-Test liest `supabase/functions/*/index.ts`) | Jede Function enthält `auth.getUser` oder `ermittleUserId` oder steht in einer Allowlist mit Cron-Secret-Prüfung | 1 h |
| **Invoke ↔ Function** | Jeder `functions.invoke('x')` in lib hat einen Ordner `supabase/functions/x` (hätte `send-raster-mail` gefunden) | 30 min |
| **config.toml-Vollständigkeit** | Jede Function hat einen `[functions.x]`-Block mit bewusst gesetztem `verify_jwt` | 30 min |
| **CanvasKit v2** | kein `FilledButton`/`OutlinedButton` innerhalb von `actions: [` einer AppBar; Ratsche auf die Gesamtzahl Filled/Outlined | 1–2 h |
| **zahlungsstatus ↔ CHECK** | liest den letzten `zahlungsstatus`-CHECK aus den Migrationen und vergleicht mit einer zentralen Dart-Konstante; verbietet Altwerte (`entwurf`, `versendet`, `teilbezahlt` …) im Rechnungskontext | 1–2 h (inkl. Konstante) |
| **Migrationsnummern** | keine doppelte Nummer ohne Buchstaben-Suffix, keine neue Lücke | 20 min |
| **Mail-Testmodus generisch** | statt 3 fester Dateien: jede Datei mit `'send-rechnung-mail'` oder `'send-pdf-mail'` bezieht den Empfänger über `MailConfig` | 1 h |

### Kritische Bereiche ohne Test (von keinem Test importiert)

| Datei | Zeilen | Heraustrennbare reine Logik |
|---|---|---|
| `services/sync/sync_service.dart` | 1424 | Konfliktentscheid Last-Write-Wins `(local, remote) → push/pull/skip`, Reihenfolge der FK-Abhängigkeiten |
| `services/rechnung/heineken_rechnung_service.dart` | 1083 | Positions- und Summenbildung, MWST, Monatsabgrenzung |
| `services/pdf/heineken_rapport_service.dart` | 1530 | Aggregation vor dem PDF (Zahlen, nicht Layout) |
| `services/buchhaltung/abschluss_regeln.dart` | 668 | nur indirekt über `abschluss_pruef_service` berührt; die Regeln sind schon fast rein, Einzeltests je Regel fehlen |
| `services/buchhaltung/zahlungsdifferenz_service.dart` | 272 | Differenz- und Toleranzentscheid |
| `services/buchhaltung/buchung_nachhol_service.dart` | 256 | Auswahl «welche Reinigung braucht eine Buchung» (Vorfall 10.09.!) |
| `services/rechnung/reinigungen_ohne_rechnung.dart` | 171 | dieselbe Auswahl-Logik für Rechnungen |
| `services/rechnung/jahresrechnung_service.dart` | 261 | Periodenbildung und Summen |
| `services/rechnung/reinigung_rechnung_versand.dart` | 328 | Zustandsfolge Versand → Vermerk (Doppelversand-Risiko) |
| `services/pdf/qr_zahlteil.dart` | 306 | Referenz- und Betragsformatierung (QR-Bill selbst ist getestet) |
| `stoerung_form_screen.dart:378 _calculatePreis()` | im Screen | **Preisformel** (Bereich × Bergkunde, km-Grenze 80, Pauschale 60, km-Satz 0.72) → `stoerungPreis(preisliste, eingabe)` |
| `montage_form_screen._save` (155 Z.), `reinigung_form_screen._save` (180 Z.) | im Screen | Statusübergang, Preis und Rechnungsanlage vermischt mit UI |
| 63 Repositories | alle | Query-Bau ist Web/Isar-gebunden; testbar nur die Row→Model-Filter (z. B. «excel_import überspringen») |

---

## 2. `flutter analyze`: 56 Befunde

| Regel | Anzahl | Wo | Risiko | Kleinfix |
|---|---|---|---|---|
| `experimental_member_use` | 12 | `data/local/sync_meta_local.g.dart` (Isar-generiert) | keins | `analyzer: exclude: ["**/*.g.dart"]` in `analysis_options.yaml` → 12 weg |
| `use_build_context_synchronously` | 18 | stoerung_detail (5), montage_detail (5), eigenauftrag_detail (5), bergkundenpauschale_detail (2), app.dart:57 | niedrig bis mittel: meist `mounted` statt `context.mounted` bzw. Dialog-Kontext vs. Screen-Kontext nach Lösch- oder PDF-Dialog. Echter Absturz möglich, wenn der Screen während des Löschens verlassen wird | ja, einheitlich `if (!context.mounted) return;` mit dem **gleichen** Kontext (30 min) |
| `deprecated_member_use` (`value` → `initialValue`) | 6 | buchung_form (3), heineken_zuweisungen, kontakt_form, pikett_dienst_form | mittel **beim Umstellen**: `initialValue` wird nicht mehr neu übernommen, wenn sich der State ändert. Blind ersetzen kann Dropdowns «einfrieren» | nur mit Sichtprüfung |
| `deprecated_member_use` + `avoid_web_libraries_in_flutter` (`dart:html`) | 4 + 4 | file_download_web, file_picker_web (camt), browser_redirect_web (Google OAuth), pdf_tab_oeffner_web | mittel langfristig (Entfernung in einer künftigen Flutter-Version) | Umstieg auf `package:web`, ca. 2 h |
| `curly_braces_in_flow_control_structures` | 9 | reinigung_form (4), montage_form (2), stoerung_form (2), event_detail | keins | `dart fix --apply` |
| `unintended_html_in_doc_comment` / `dangling_library_doc_comments` | 3 | zahlungsart, zahlername, google_fehler | keins | Backticks setzen |

→ **Kleinfix für 42 von 56** (exclude, dart fix, context.mounted, Doc-Kommentare). Offen bleiben 6 × initialValue und 8 × dart:html.

### Grosse Dateien (> 1500 Zeilen, ohne .g.dart); insgesamt 23 Dateien > 1000

| Datei | Zeilen | Viele Verantwortungen |
|---|---|---|
| `screens/events/event_detail_screen.dart` | 2863 | Detail, Dialoge, Technik, Karte |
| `screens/reinigungen/reinigung_form_screen.dart` | 2818 | `_save` (180 Z.): Preis, Status, Rechnung, Buchung, Mailversand (3 × `send-rechnung-mail`), Abschluss-Dialog-Flow |
| `screens/touren/tourenplanung_screen.dart` | 2813 | Planung, Routing (haversine), Zeitplan, UI |
| `screens/montagen/montage_form_screen.dart` | 2180 | `_save` 155 Z. + Mailversand |
| `screens/betriebe/betrieb_form_screen.dart` | 2082 | `_save` 108 Z. + Saison-Archiv |
| `providers/tour_providers.dart` | 2061 | TourEintrag-Bau (ca. 220 Z. an einem Stück), `tagesplanSpeichern` (177 Z.) |
| `screens/betriebe/betrieb_detail_screen.dart` | 2023 | |
| `screens/buchhaltung/widgets/abgleich_vorschau.dart` | 1911 | |
| `screens/events/event_technik_tab.dart` | 1531 | |
| `services/pdf/heineken_rapport_service.dart` | 1530 | ungetestet |
| `screens/stoerungen/stoerung_form_screen.dart` | 1519 | Preisformel im Screen |

Muster: Der Mailversand an Kunden steckt direkt in drei Formular-Screens. Ein `RechnungVersandService` wie `reinigung_rechnung_versand.dart` sollte das für alle drei übernehmen.

---

## 3. Edge Functions

Es gibt zwei Auth-Ebenen: `verify_jwt` am Gateway und eine eigene Prüfung im Code. **`verify_jwt = true` lässt den öffentlichen Anon-Key durch** (er ist ein gültiges JWT). Nur `auth.getUser()` im Code weist anonyme Aufrufer ab.

| Function | Zweck | verify_jwt config.toml | Deployed laut Kommentar | Eigene Auth | Secrets | Tests | Befund |
|---|---|---|---|---|---|---|---|
| **send-pdf-mail** | Bericht-PDF per Gmail | – (fehlt) | `--no-verify-jwt` | **keine** | GMAIL_* | nein | 🔴 **offenes Mail-Relay**: `to`, `subject`, `filename`, `pdfBase64` frei, dazu Header-Injection (CRLF in `to`/`filename` unescaped) |
| send-rechnung-mail | Rechnung, Protokoll und Zusatz-PDFs per Gmail | true | true (v24) | ✅ `ermittleUserId` | GMAIL_*, SERVICE_ROLE | ✅ pfad_pruefung_test | behoben; Rest: `to` nicht auf CRLF geprüft (nur für angemeldete Nutzer ausnutzbar) |
| **send-raster-mail** | Monatsraster per Mail | – | ? | ? | ? | – | 🟠 **kein Quellcode im Repo**, App ruft sie auf |
| **parse-protokoll** | Protokollfoto → Positionen (Sonnet) | – | `--no-verify-jwt` | **keine** | ANTHROPIC | nein | 🟠 frei nutzbarer Claude-Proxy auf Daniels Key; **kein Aufrufer in der App** (tot?) |
| **parse-oeffnungszeiten** | Website → Öffnungszeiten (Claude) | – | `--no-verify-jwt` | **keine** | ANTHROPIC | nein | 🟠 **SSRF**: `url` aus dem Body wird ohne Host-Prüfung geladen (auch Unterseiten), dazu Claude-Kosten |
| **betrieb-google-lookup** | Places-Suche | – | `--no-verify-jwt` | **keine** | GOOGLE_PLACES_KEY | nein | 🟡 Places-Kosten |
| **betrieb-google-abgleich** | Places-Details eines Betriebs | – | `--no-verify-jwt` | **keine** | PLACES, SERVICE_ROLE | nein | 🟠 `betriebId` aus dem Body → Service-Role-Lesezugriff auf `betriebe` (Name und Adresse gehen in der Antwort zurück) und **UPDATE `google_place_id`**; `placeId` ungeprüft in der Google-URL |
| **betriebsdaten-abgleich** | Nacht-Orchestrator (pg_cron 162) | – | `--no-verify-jwt` | **keine** | SERVICE_ROLE (+ indirekt PLACES/ANTHROPIC) | nein | 🟠 öffentlich auslösbar; **`limit` ohne Obergrenze** → Kostenlawine; `betriebIds` frei; schreibt `betrieb_vorschlaege`. Cron (Migration 162) sendet gar keinen Auth-Header → braucht ein Cron-Secret |
| **anfahrt-google** | Routes-Matrix Startorte → Betriebe | – | kein Hinweis (Default true) | **keine** | PLACES, SERVICE_ROLE | nein | 🟠 mit Anon-Key aufrufbar; `POST {}` = Voll-Lauf über alle Betriebe (Google-Kosten) und Upsert in `anfahrtszeiten`; `user_id` wird aus «irgendeiner Zeile» geraten |
| fahrzeit-route | Fahrzeit zwischen zwei Betrieben | – | ? | ✅ getUser + `user_id`-Filter | SERVICE_ROLE | nein | ok |
| parse-beleg | Spesenbeleg (Haiku) | true | true | ✅ | ANTHROPIC | nein | ok |
| parse-rechnung | Eingangsrechnung (Claude) | true | true | ✅ | ANTHROPIC | nein | ok |
| typenschild-lesen | Typenschild-Foto | true | true | ✅ | ANTHROPIC | nein | ok |
| parse-einsatz | Diktat → Einsatz | **fehlt** | Kommentar behauptet «true via config.toml» | ✅ | ANTHROPIC | nein | 🟡 Drift Kommentar ↔ config |
| google-oauth-exchange | Code → Tokens | – | ? | ✅ | OAUTH_CLIENT_*, SERVICE_ROLE | nein | ok (`redirect_uri` prüft Google) |
| google-calendar-sync | Push/Reconcile Kalender | – | ? | ✅ | OAUTH_*, SERVICE_ROLE | nein | 🟡 `entity_id` aus dem Body: `loadEntity` liest per Service-Role **ohne `user_id`-Filter** (heute Einzelnutzer, relevant bei Multi-Tenant) |
| google-calendar-disconnect | Token widerrufen | – | ? | ✅ | SERVICE_ROLE | nein | ok |
| google-contacts-sync | Kontakte-Reconcile | – | ? | ✅ | OAUTH_*, SERVICE_ROLE | ✅ mapping_test | ok |

**Muster wie send-rechnung-mail v24** (Body → Storage-Pfad/DB-Filter ohne Prüfung):
- `send-pdf-mail`: Body → Empfänger und MIME-Header (schlimmer: ohne Login).
- `betrieb-google-abgleich`: `betriebId` → Service-Role-SELECT und UPDATE; `placeId` → Google-URL-Pfad.
- `betriebsdaten-abgleich`: `limit`/`betriebIds` → Service-Role-Query und Folgeaufrufe.
- `anfahrt-google`: `betriebId` → Service-Role-Query und Upsert.
- `google-calendar-sync`: `entity_id` → Service-Role-SELECT beliebiger Zeilen aus 6 Tabellen.
- `parse-oeffnungszeiten`: `url` → Server-seitiger Fetch.

---

## 4. Migrationen

| Prüfpunkt | Befund |
|---|---|
| Dateien | 211 (205 Nummern + Suffixe + `setup_user_seed.sql`) |
| Lücken | **008, 009** |
| Doppelte Nummern ohne Suffix | **083** (buchungen_constraints_erweitern / heineken_zahlungsstatus), **091** (gast_read_rls / kontenplan_ergaenzung), **092** (gast_kein_buchhaltung / konten_fehlend_historie) |
| Suffix-Nummern (bewusst) | 165b, 166a, 166b, 192b |
| Server-only-Migrationen | nicht geprüft (laut Memory ca. 12) → mit `list_migrations` abgleichen |
| CHECK-Constraints mit Wertelisten | `status` 15×, `durchlaufkuehler` 6, `zahlungsstatus` 5, `rolle` 5, `kategorie` 5, `zahlungsweg` 4, `service_typ`/`montage_typ`/`beleg_typ`/`typ` je 4 … |
| Duplikat im Code | **keine zentrale Dart-Konstante für `zahlungsstatus`**. Literale: `'offen'` 74×, `'bezahlt'` 71×, `'abgeschrieben'` 44×, `'gesendet'` 26×, `'mahnung_1/2'` je ca. 25×, `'erinnert'` 24×, `'freigegeben'` 15×. Einsatz-Status: Ratsche steht bei 20 |
| RLS-Muster | 142 `CREATE POLICY`: 57 × `FOR ALL` (Altbestand 002, `USING (user_id = auth.uid())`; ohne `WITH CHECK` gilt USING auch für neue Zeilen → korrekt) und je ca. 20 × SELECT/INSERT/UPDATE/DELETE (neuere Tabellen). Beide Muster sind sicher, aber uneinheitlich. Neue Migrationen sollten eine Vorlage bekommen |
| Storage-Policies | konsistent: erstes Pfadsegment = `auth.uid()` (reinigung-pdfs, rechnung-pdfs, camt-dateien, dokumente, event-dokumente, material-manuals, buchungs-belege) ✅ |
| `SECURITY DEFINER` | 3 Migrationen, nur 2 davon mit `SET search_path` → die dritte prüfen |

---

## 5. Priorisierte Vorschläge (Sicherheit zuerst)

| # | Vorschlag | Warum | Aufwand |
|---|---|---|---|
| 1 | **`send-pdf-mail` absichern**: `ermittleUserId` aus send-rechnung-mail übernehmen, `verify_jwt = true` in config.toml, CRLF-Prüfung für `to`/`filename`, neu deployen | offenes Mail-Relay auf der Firmenadresse | 30–45 min |
| 2 | **`send-raster-mail` klären**: `list_edge_functions` → Quelle holen und prüfen oder den Aufruf entfernen | unbekannter Code mit Gmail-Zugang | 20 min |
| 3 | **`parse-protokoll` löschen** (kein Aufrufer) oder mit getUser absichern | Gratis-Claude-Proxy | 10 min |
| 4 | **getUser-Prüfung** in `parse-oeffnungszeiten`, `betrieb-google-lookup`, `betrieb-google-abgleich`, `anfahrt-google`; bei `parse-oeffnungszeiten` zusätzlich nur http(s), keine IP-Literale oder localhost | Kosten, SSRF, Service-Role-Schreibzugriff | 1–1.5 h |
| 5 | **Cron-Secret** für `betriebsdaten-abgleich` (Header `x-cron-secret` aus Vault in Migration 162 und die Function prüft ihn); `limit` auf 50 deckeln; interne Aufrufe an 2 Functions über dasselbe Secret | öffentlich auslösbarer Kostenlauf | 1 h + Migration |
| 6 | **Edge-Wächter-Tests** (Auth vorhanden, Invoke ↔ Ordner, config.toml vollständig) | verhindert Rückfall wie send-pdf-mail | 1.5 h |
| 7 | `google-calendar-sync.loadEntity`: `.eq('user_id', userId)` ergänzen; `parse-einsatz` in config.toml eintragen | Multi-Tenant-Vorbereitung, Drift | 20 min |
| 8 | Analyze-Kleinfixes: `.g.dart` ausschliessen, `dart fix`, `context.mounted` vereinheitlichen | 42 Befunde weg, sauberer Warnkanal | 45 min |
| 9 | Zentrale `Zahlungsstatus`-Konstante und Wächter gegen den CHECK der Migration | Altwert-Rückfall → PostgrestException | 2 h |
| 10 | Reine Funktionen herauslösen und testen: `stoerungPreis()`, Sync-Konfliktentscheid, Heineken-Rechnungssummen, Nachhol-Auswahl | Geld-Logik ohne Test | je 1–3 h |
| 11 | CanvasKit-Wächter v2 (AppBar-Filled-Buttons, Ratsche auf Filled/Outlined) | 2 von 3 Vorfällen ungeschützt | 1–2 h |
| 12 | Migrationsnummern: Duplikate 083/091/092 dokumentieren (nicht umbenennen, falls sie auf dem Server so geführt werden), Wächter gegen neue Doppelnummern; Server-only-Migrationen lokal nachziehen | Nachvollziehbarkeit | 30 min + Abgleich |
| 13 | `dart:html` → `package:web` (4 Dateien), `initialValue` mit Sichtprüfung | künftige Flutter-Versionen | 2–3 h |
| 14 | Mailversand aus den 3 Formular-Screens in einen Service ziehen; `_save` aufteilen | Grösste Dateien, Doppelversand-Risiko | 0.5–1 Tag |
