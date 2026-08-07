# camt-Import — Gesamtprüfung & Verbesserungsplan (07.08.2026)

**Auftrag Daniel:** «Prüfe nochmal den camt-Import mit Prüfliste, Zahlername,
Regeln, Dateien usw. … lerne aus den bisherigen camt-Import-Tests und meinen
Anmerkungen, prüfe alles gründlich und plane die Verbesserung.»

**Methode:** Vollständige Code-Kartierung des Subsystems (Parser → Router →
Matching-Kette → Booker → Prüfliste/Regeln/Dateien-Tabs), Abgleich mit der
Historie (Tests 14./15.07., Anmerkungen Daniel, Memory), Datenbestand geprüft
(Prüfliste, Regeln, Aliase, Dateien) und die echte camt-Datei 12.03.–20.06.
analysiert (270 TX: 243 Gutschriften / 27 Belastungen).

---

## A. Sofort behoben (v0.72.9)

1. **Ausgabe-Booker löst Geschäftsfall-Vorlagen jetzt auf** (`kontenFuerCamt`
   via `GeschaeftsfallResolver`, Zahlungsweg fix 'bank'): Phase-0a-Vorlagen
   («Bussen» 6280, «Fahrbewilligung» 6275) tragen die Konten in `hauptkonto`
   und hatten Soll/Haben = NULL — der Booker crashte dort. Betroffen waren
   genau die zwei offenen Ausgabe-Einträge der Prüfliste (Gemeinde Flims
   40.00, Finanzdepartement Luzern 20.00). +3 Tests.
2. **Offene Prüflisten-Einträge blockieren den Re-Import nicht mehr**
   (`getBlockierendeTxKeys`): Sie werden beim nächsten Import mit aktuellem
   Datenstand neu bewertet — der Upsert verhindert Duplikate, und jede
   Buchung eines Vorschlags räumt einen evtl. offenen Prüflisten-Eintrag ab
   (`deleteByTxKey` in `bucheVorschlag`). Damit werden die **zwei
   Heineken-Gutschriften (7'104.98 / 5'794.81)**, die seit 20.06. in der
   Prüfliste feststecken, beim Nachhol-Import automatisch zu buchbaren
   Vorschlägen — die passenden Feb-/März-Monatsrechnungen existieren
   inzwischen. Erledigte/ignorierte Einträge blockieren weiterhin.
3. **Sammelzahler nie auto** (`sammelzahler.dart`, zentrale Liste): «Weisse
   Arena Hospitality AG» ist als Alias auf IKIGAI Laax gelernt — zahlt die
   Zentrale für ein Schwester-Objekt, hätte der Alias-Pfad automatisch falsch
   verbucht. Alias-/Exakt-Treffer von Sammelzahlern (Davos Klosters, Weisse
   Arena) sind jetzt nur noch **Vorschlag** in der manuellen Prüfung; die
   Liste ist mit der «Nicht gruppieren»-Liste der Vorschau zusammengelegt.
   +1 Test.
4. **Archiv-Kopie erst NACH erfolgreicher Verarbeitung:** Vorher wurde die
   Datei vor der Verarbeitung archiviert — scheiterte die Verarbeitung,
   blockierte die Duplikatprüfung jeden weiteren Versuch mit derselben Datei.
5. **Parser-Datumsfehler verständlich:** exotisches Datum liefert jetzt
   «camt-Datei: unlesbares Datum in <Feld>: …» statt eines rohen
   FormatException-Stacks.
6. **Dateien-Archiv bereinigt:** 11 Duplikat-Zeilen gelöscht (dieselbe Datei
   war bis 9× erfasst), 2 saubere Einträge bleiben (12.03–20.06 und
   12.03–14.07, je mit echtem Dateinamen).

## B. Fragen an Daniel (offen)

1. **Weisse Arena Hospitality AG** (11 Zahlungen): nur IKIGAI Laax, oder auch
   andere Objekte? → bestimmt, ob der Sammelzahler-Guard so bleibt.
2. **Goodfast Hotels AG** (6 Zahlungen): welcher Betrieb?
3. **Heineken-Franchise-Regel:** bucht heute an **Kreditor 2000/1020 ohne
   Vorsteuer** — das setzt eine gebuchte Eingangsrechnung voraus (für 2026
   nicht vorhanden, Befund B3) und verschenkt 282.69 VSt/Monat.
   **Empfehlung:** Vorlage auf direkten Aufwand **6301 + mwst_konto 1170,
   8.1 %** umstellen (dann bucht der Nachhol-Import die 3
   Franchise-Belastungen im Auszug gleich richtig; Nachbuchungen bleiben nur
   für Jan–Feb nötig). → Entscheid Daniel, hängt mit Fahrplan-Schritt 4
   zusammen.

## C. Geplant, noch nicht umgesetzt (priorisiert)

**C1 — vor/mit dem Nachhol-Import (klein):**
- Regel-Politur: `heineken` → `heineken switzerland` (verhindert Fehltreffer
  auf andere Heineken-Texte); `abschluss` beobachten (breiter Substring);
  Lohn-Regel optional per IBAN präzisieren — Achtung: Name/IBAN sind
  ODER-verknüpft, IBAN ergänzt, verengt nicht.
- Prioritäts-Feld im Regel-Dialog (heute hartkodiert 10; die BVG-/Miete-Regeln
  mit Prio 20 wurden von Hand gesetzt).
- 11 alte camt-Vorlagen `ist_aktiv=true` (Phase-0a-Follow-up): Regeln auf
  neue Geschäftsfälle umhängen, Alt-Vorlagen deaktivieren.

**C2 — Robustheit (mittel):**
- `RechnungMatcher`-Grenzen sichtbar machen: `.take(20)` Kandidaten und max.
  4er-Kombination scheitern bei grossen Betrieben **stumm** — UI-Hinweis
  «zu viele offene Posten für Auto-Match» statt stillem Nichts.
- `refIndex`-Kollision (zwei Forderungen mit gleicher QR-Referenz) loggen
  statt still überschreiben (DB-Unique-Index macht es unwahrscheinlich).
- IBAN-Normalisierung vereinheitlichen (3 Varianten: RegelMatcher,
  KreditorenAbgleich, Parser) und die doppelten Bereichs-Schlüsselwörter
  (`camt_bereich_router` vs. `camt_klassifizierer`) auf EINE Quelle ziehen.
- Transaktionalität camt I2 (Netzfehler nach Buchung vor Rechnungs-Update).

**C3 — Aufräumen (klein, gefahrlos):**
- Toter Code raus: `camt_import_service.dart` (141 Z., alter Import-Pfad
  inkl. eigener, abweichender Buchungslogik!), `CamtAutoBooker.run()`
  (Vollautomatik-Pfad, seit Bestätigungs-Modus ungenutzt),
  `CamtBetriebMatcher.matchAll()`, tote Felder auf `CamtTransaction`
  (`selected`, `isDuplicate`, `matchedBetriebId/Name`, `selectedVorlageId`).
- `HeinekenMatcher.rappen` heisst irreführend (rundet auf 5 Rappen).
- `user_id`-Filter in Prüflisten-/Regel-Repository ergänzen (heute nur RLS;
  DateiRepository filtert explizit — uneinheitlich).

**C4 — Tests (mittel):**
- `HeinekenMatcher` hat KEINEN Test; `verbuche()`-IO (Doppelzahlungs-Schutz,
  Paarung) ungetestet; `AbgleichVorschau` (1'502 Zeilen Zuordnungs- und
  Lernlogik) ohne Widget-Test; `_doImport()`-Orchestrierung ungetestet.
  Mindestens HeinekenMatcher + verbuche()-Kernpfade nachrüsten.

**C5 — Nice-to-have:**
- Dateien-Tab: Löschen-Funktion (heute gibt es keinen Aufräum-Weg im UI).
- Stichtag aus `geschaeft_einstellungen` statt hartcodiert (erst relevant,
  falls je ein zweiter Mandant kommt — heute bewusst simpel).
- CanvasKit-Material-Button-Problem im Import-Tab einmal sauber diagnostizieren
  (GestureDetector-Workaround dokumentiert, Ursache unklar).

## D. Erkenntnisse für den Nachhol-Import (Erwartungen)

- **0 von 243 Gutschriften tragen eine SCOR-Referenz** — Stufe 1 greift im
  Nachholzeitraum noch nicht (Referenzen gibt es erst ab den Juli-Rechnungen).
  Der Abgleich läuft über Aliase (25 gelernt), exakte Namen, Vermerk-Parser
  (Davos Klosters!) und manuell. Das ist Stand heute richtig kalibriert:
  Auto nur bei sicheren Treffern.
- **Alle 27 Belastungen matchen namentlich auf eine Regel** (100 % Abdeckung):
  11× Lohn Daniel, 4× Swisscom, 3× Heineken-Franchise (→ Frage B3!), 3×
  Steuerverwaltung GR, 2× Ausgleichskasse, je 1× Abschluss/AXA
  BVG/Gemeinde Flims/ESTV. Die ESTV-Belastung 18.05. (1'735.04) ist die
  Q4/2025-Zahlung → bucht korrekt 2202/1020.
- **Blue Cinema:** Alias «blue entertainment ag» existiert, 4 Gutschriften im
  Auszug — der offene ToDo-Punkt löst sich voraussichtlich beim Import.
- Ablauf Nachhol-Import: (1) archivierte Datei 12.03–14.07 aus dem
  Dateien-Tab herunterladen und erneut importieren (offene Prüflisten-Fälle
  werden jetzt neu bewertet), (2) frische GKB-Datei 15.07–heute importieren
  (txKey-Dedup macht Überlappung unkritisch).
