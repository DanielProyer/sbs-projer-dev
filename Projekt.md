# SBS Projer App — Projekt-Übersicht

**Was:** Service-Management für den Zapfanlagen-Service der SBS Projer GmbH
(Heineken-Franchise, Graubünden) — Planung, Einsätze, Rechnungen und
Buchhaltung in einer App.
**Wer:** Daniel Projer, Einzelbetrieb; entwickelt mit Claude.
**Stand:** 26.09.2026 · **v0.145.0** live · 2559 Tests grün · Migrationen bis 209e.

> **Wo was steht**
> - **Diese Datei:** was die App heute kann und wie sie gebaut ist. Wird bei
>   neuen Modulen oder Architektur-Entscheiden nachgeführt, nicht pro Version.
> - **`ToDo.md`:** was offen ist, und zu jeder Version Begründung, Prüfung und
>   Rückweg. **Die gepflegte Arbeitsquelle.**
> - **`docs/chronik.md`:** was wann gebaut wurde (der frühere Kopf dieser
>   Datei, der ursprüngliche Projektplan und die Erledigt-Liste bis Juni).
> - **`CLAUDE.md`:** Build, Deploy und die verbindlichen Coding-Regeln.

---

## Betrieb

| | |
|---|---|
| **Live** | https://danielproyer.github.io/sbs-projer-dev/ (Branch `gh-pages`) |
| **Plattform** | Web-App, auf dem Handy (Pixel 9) und am PC im Browser genutzt |
| **Tech** | Flutter (CanvasKit-Web) · Supabase (Postgres, Auth, Storage, Edge Functions, pg_cron) · Riverpod · GoRouter |
| **Datenbank** | Supabase-Projekt `pltbaqqwpnmdajwgnhpd` (sbs-projer-prod) |
| **Umfang** | 101 Routen · 25 Screen-Bereiche · 17 Edge Functions |
| **Bestand** | 309 aktive Betriebe, davon 229 eigene Reinigungskunden (Stand 20.09.2026) |
| **Kosten** | Supabase Pro, rund 23 CHF im Monat |

**Nativer Pfad:** Der Isar/Offline-Sync-Zweig (Conditional Exports, siehe
`CLAUDE.md`) wird hier nicht benutzt, aber gepflegt — er ist die Vorlage für
die neue Android-App.

**Mail-Versand scharf** für Reinigung, Heineken, Montage, HeiGenie, Bestellung,
Event und Anlage; **Mahnwesen noch im Testmodus** (`lib/core/config/mail_config.dart`).

---

## Was die App kann

### Draussen: Tag, Tour, Einsatz

- **Startseite als Tagesansicht:** die offenen Stopps des heutigen Plans, je
  Zeile ein Start-Pfeil; Arbeitstag-Karte mit km-Stand und GPS; Diktier-Knopf
  (Einsatz per Sprache, Edge Function `parse-einsatz`).
- **Tourenplan** (`touren/`): Fälligkeit nach Rhythmus und Saison, Tagesplan auf
  einer Zeitachse mit gelernten Fahrzeiten und Besuchsdauern, Live-Modus mit
  gemessenen Zeiten; Warnungen für Ruhetage, Ferien, Servicezeiten und
  Saisonbetriebe, die aus dem Plan fallen.
- **Reinigungen** (`reinigungen/`): Service-Flow mit Protokoll-Foto,
  Unterschrift, Preis aus der Preisliste (Trigger), Zahlungsart pro Reinigung,
  Kulanz, Saisondaten direkt beim Abschluss; Rechnung und Mail laufen beim
  Abschliessen mit.
- **Weitere Einsätze:** Störungen, Montagen, Pikett, Eigenaufträge,
  Eröffnungs- und Endreinigungen, Bergkundenpauschale — zusammengeführt im
  **Einsätze-Screen** (`einsaetze/`) mit einer gemeinsamen Lage statt vier
  Status-Vokabularen.
- **Material** (`materialien/`): Bestand im Auto, Bestellliste, Bestellungen
  mit «Material abgeholt» und atomarer Bestandsbuchung; Heineken-SAP-Nummern.

### Stammdaten

- **Betriebe und Anlagen** (`betriebe/`, `anlagen/`): Rechnungsadressen,
  Öffnungs- und Servicezeiten, Ferien, Saisonfenster mit Historie,
  `ist_mein_kunde`, Kulanz-Merker; Google- und Website-Abgleich der
  Betriebsdaten mit Prüfliste (täglicher Lauf).
- **Kontakte** (`kontakte/`, Reiter «Personen» der Betriebe): Sync ins
  Google-Adressbuch (Anrufer-Erkennung).
- **Google Kalender** (`google_kalender/`): Aufträge, Eröffnungs- und
  Endreinigungen, von Hand gesetzte Service-Termine und datierte Aufgaben —
  bewusst keine Tagestouren.
- **Events** (`events/`): Kontakte, Stände mit Lageplan und GPS, Anstiche,
  Pikett-Einsätze, Zeit/Spesen, Abschluss-Mail. *Gampel läuft seit 14.08.2026
  im eigenen Repo.*

### Büro: Rechnungen und Forderungen

- **Kundenrechnungen** (`rechnungen/`): PDF mit QR-Einzahlungsschein,
  Versand per Mail, Tresen-Übergabe, Abschreibung;
- **Mahnlauf** (seit v0.134.0): Erinnerung / 1. / 2. Mahnung ab Rechnungen
  2026, je Betrieb ein Schreiben mit QR je Rechnung und Kontoauszug, Mail oder
  Druck; Bank- und Gutschrift-Sperre, Protokoll mit Zurücknehmen. Seit
  v0.135.0 Mahnfall: Heineken einschalten, vier Ergebnisse, Betreibung mit
  EasyGov-Datenblatt und Fristen. Seit v0.136.0 Hinweis-Band beim Service
  mit «bar einkassieren» (Kasse 1000) und «QR zeigen».
  Jahresrechnungen für Betriebe mit jährlicher Abrechnung (`jahresrechnung/`).
- **Kundenguthaben** (seit v0.137.0): Überzahlungen auf Konto 2030 werden mit
  der nächsten Rechnung verrechnet (PDF/QR «zu zahlen», Bankabgleich 2030 an 1100).
- **Pro Betrieb:** offene und alle Rechnungen je Jahr mit Zustellweg,
  Kontoauszug-PDF mit QR-Schein, Reinigungsprotokolle als PDF (einzeln oder
  Jahresbündel).
- **Heineken-Monatsrechnung** (`heineken/`): acht Kategorien, kombiniertes PDF
  mit den Heineken-Formularen, Workflow `offen → gesendet → freigegeben →
  bezahlt`; vor der Freigabe prüft ein Wächter die Positionen gegen die
  Quelldaten.
- **Eingangsrechnungen** (`eingangsrechnungen/`): Scan mit KI/QR, Kreditoren-
  Buchung, GKB-Zahlungsfile (pain.001).

### Büro: Buchhaltung

- **Buchhaltung** (`buchhaltung/`): Kontenplan, Journal, Bilanz,
  Erfolgsrechnung, MWST-Abrechnung (Saldo nach vereinbarten Entgelten, inkl.
  Ziff. 235), Monatsabschluss als geführte Checkliste, Abschlussprüfung mit
  «Jahrgang abschreiben».
- **Bankauszug-Import:** camt.053 der GKB mit Zuordnung über QR-Referenz,
  Rechnungsnummer im Vermerk und gelernte Zahlernamen; Prüfliste für den Rest.
- **Spesen-Scanner** (`spesen/`): Beleg fotografieren → Positionen, Konten und
  Vorsteuer per KI.
- **Lohn** (in `buchhaltung/`): Lohnläufe mit Buchung, Lohnausweis
  (Formular 11).
- **Dokumente** (`dokumente/`): Ablage nach Absender (Pensionskasse, AHV/SVA,
  SUVA, Krankentaggeld, Haftpflicht, Steuern, Verträge …).
- **Aufgaben** (`aufgaben/`): eine Liste für Glocke, Startkarte und Kachel —
  Detektoren (Heineken-Rechnung, MWST, Mahnlauf, Saisondaten) plus eigene.
- **Auswertungen** (`/auswertungen`): Umsatz und Arbeiten, Arbeitstage,
  Nutzung der App.

---

## Wie sie gebaut ist

Die verbindlichen Regeln stehen in `CLAUDE.md`, hier nur die Landkarte:

- **Navigation** (seit v0.131.0): untere Leiste Heute · Einsätze · Betriebe ·
  Tour · Mehr. Was unter «Mehr» und in den Bereichsseiten steht, ist **Daten**
  in `lib/core/config/bereiche.dart`; umhängen heisst dort eine Zeile
  verschieben. Ein Wächter-Test prüft, dass jeder Listen-Screen erreichbar
  bleibt. Entwurf: `docs/superpowers/specs/2026-09-22-navigation-mehr-design.md`.
- **Suche** (seit v0.133.0): `/suche`, über die Lupe auf Heute und das Feld
  oben auf Mehr. Regeln als reines Dart in `lib/core/util/suche.dart`; die
  Listen (Betriebe, Personen, Rechnungen) suchen mit derselben Regel.
- **Schichten:** `data/models` (DTOs) → `data/repositories` (`kIsWeb`-Branching:
  Web direkt auf Supabase, nativ über Isar) → Riverpod-Provider →
  `presentation/screens`.
- **Geschäftsregeln in der Datenbank**, wo sie nicht umgangen werden dürfen:
  Preis-Trigger, Rechnungsnummer-Sequenz, CHECK-Constraints auf den Status.
- **Wächter-Tests** halten die Lehren aus Vorfällen fest: stabile Pagination
  (`.order('id')`), Unicode-PDF (`pdfDokument()`), CanvasKit-sichere Knöpfe,
  keine rohen Ausnahmen auf dem Bildschirm, Zeitauswahl nur 24 h, `kAppVersion` = `pubspec.yaml`.
- **Die Version steht in der App**, damit sich ein Feldbefund einer Fassung
  zuordnen lässt.

**Verwandte Projekte** (dort arbeiten, nicht hier doppeln):
- **Heineken-Plattform** (`D:\Projekte\Heineken`): Multi-Tenant-Nachfolger
  («v2»), dieselbe Datenbank. Diese App bleibt bis dahin führend.
- **Gampel 2026** (`D:\Projekte\gampel-2026`): Event-App mit eigener DB.

---

## Offen

Der vollständige, gepflegte Stand steht in **`ToDo.md`** unter «OFFEN». Die
grossen Linien:

- **Buchhaltung:** Steuererklärung 2025 (Frist 30.09.2026), MWST Q3/2026,
  Abschluss 2026 mit Jahrgangsabschreibung im Januar 2027.
- **Stammdaten:** Saisondaten für den Winter, fehlende Rechnungs-Mailadressen.
- **Klicktests am Handy** für die Versionen seit v0.109.
- **Später bauen:** Aufgaben mit Kalender/Tourenplan verknüpfen, echte
  Zeiterfassung für Störung/Montage, tote Zeitfelder aufräumen, fehlende lokale
  Migrationsdateien ablegen.
- **Mahnwesen scharfstellen** (Mail noch im Testmodus).

---

## Dokumente

| Bereich | Wo |
|---|---|
| Geschäft und Abläufe | `Prompts/02_Geschäftsbeschreibung.md`, `Prompts/03_Geschäftsabläufe.md`, Entscheidungsbäume Systeme/Störungen in `Prompts/` |
| Ausgangsanalysen (Excel, Preise, Heineken, Protokolle) | `../Datenanalyse_Referenz/` (ausserhalb des Repos) |
| Architektur (Februar 2026) | `Architektur/01_Tech_Stack_Analyse.md`, `02_Datenmodell.md`, `03_Roadmap.md` — historisch, das Datenmodell ist seither um fast 200 Migrationen gewachsen |
| Migrationen | `Datenbank/migrations/` |
| Specs und Pläne | `docs/superpowers/specs/`, `docs/superpowers/plans/` |
| Buchhaltung | `docs/buchhaltung/` (Voll-Übernahme, Jahresabschluss 2025, Abschreibungen) und die Prüfberichte in `docs/` |
| App-Analyse 09/2026 | `docs/app-analyse-2026-09.md` |
| Franchisevertrag | `docs/franchisevertrag-heineken-2019.md` |
| Chronik | `docs/chronik.md` |
