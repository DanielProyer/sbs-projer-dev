# App-Analyse 25.09.2026 — Vereinfachen, Doppelspurigkeiten, Risiken

Stand v0.138.0. Sechs Analyse-Agenten (Screens/Navigation, Datenschicht, Buchhaltung,
Tagesbetrieb, Qualität/Backend, Stammdaten) plus Nutzungsmessung 09.–25.09.2026.
Die sechs Einzelberichte mit allen Datei:Zeile-Belegen liegen in
`docs/analyse-2026-09-25/`. Die frühere Analyse vom 08.09. (`app-analyse-2026-09.md`,
A1–A9/B1–B7) ist umgesetzt und wird hier nicht wiederholt.

**Schon erledigt in derselben Nacht** (weil Sicherheits- oder Datenrisiko):
`send-pdf-mail` war ein offenes Mail-Relay → v15 mit JWT-Pflicht; drei künftige
Betriebsferien (Surselva Disentis, Posta Veglia, Edelweiss Vals), die der Tourenplan
nicht kannte, nachgetragen.

---

## 1. Gemessen

| Mass | Wert |
|---|---|
| Routen | 109 — **70 benutzt, 39 nie** in 17 Tagen (dazu 4 Aliase) |
| Handy-Spitze | `/reinigungen/neu` 111×, Heute 57×, Betriebsseite 51×, Tour 16×, Spesen 11× |
| PC-Spitze | Heute 104×, Tour 70×, Betriebe 53×, Rechnungen 29×, Buchhaltung 28× |
| Nie benutzt | alle Eingangsrechnungs-Seiten, Bilanz, Debitoren, Konten, Steuern, Buchungen neu/detail, Eigenaufträge, Pikett, Events (neu/bearbeiten), Biersorten, Preise, Bierleitungen, Google-Termine, Heineken-Raster |
| Code | 136'678 Zeilen `lib/` (ohne generiert) + 108'413 Zeilen Isar-`.g.dart`; 11 Dateien > 1500 Zeilen |
| Tests | 2'234 grün in 1:46 min; 20 Wächter |
| Daten | 5'278 Rechnungen, 8'695 Reinigungen, 16'879 Buchungen |
| Formular-Abbrüche | `/reinigungen/neu` 96× geöffnet, 73 Reinigungen entstanden → ~23 Öffnungen ohne Abschluss |

---

## 2. Die Befunde, die zuerst drankommen (Datenrisiko, je klein)

| # | Befund | Beleg | Aufwand |
|---|---|---|---|
| **R1** | **Abgeschlossene Reinigung im Web bearbeiten (auch nur Notiz) löscht die Rechnung samt Buchungen und legt sie neu an** — ohne Prüfung auf bezahlt/gemahnt/Mahnfall/abgeschlossenes Jahr. Neue Nummer, Zahlungsbuchungen zeigen auf gelöschte Rechnung, neue Rechnung landet «offen» im Mahnlauf. | `reinigung_form_screen.dart:806-829` → `reinigung_korrektur_service.dart:15-35` | M (Rechnung aktualisieren statt löschen; Sperre wenn bezahlt/gemahnt) |
| **R2** | **Bankabgleich und Zuordnen-Dialog nehmen nur `offen`/`gesendet` und nur `kundenrechnung`.** Gemahnte Rechnungen und Jahresrechnungen werden nie per Bank bezahlbar → «unbekannte Gutschrift». Heute folgenlos (0 solche Rechnungen), mit dem ersten scharfen Mahnlauf akut. | `camt_import_tab.dart:475-480`, `kundenzahlung_zuordnen_dialog.dart:33-41` | S (zentrales `istZahlbar()` + Wächter) |
| **R3** | **Heineken-Monatsrechnung: Bankmatcher setzt eine erst `gesendet`e Rechnung direkt auf `bezahlt` → Freigabe und Ertragsbuchung 1100/3400 fehlen für immer.** Zudem setzt der Detail-Screen erst den Status, dann bucht er. | `monats_regeln.dart:213`, `heineken_rechnung_detail_screen.dart:334-395` | S (erst buchen, dann Status; Matcher nur `freigegeben`) |
| **R4** | **Versand-Rückfall setzt Status pauschal auf `gesendet`** (4 Stellen) — Neuversand aus dem Reinigungsdetail kann bezahlte/gemahnte Rechnung zurückdrehen. | `reinigung_rechnung_versand.dart`, `reinigung_form_screen.dart:1038/1125`, `rechnung_detail_screen.dart` | S (nur von `offen` aus) |
| **R5** | **Start-Pfeil bei geplanter Störung/Montage öffnet `/neu`** statt den geplanten Einsatz → Doppel-Datensatz, geplanter Stopp bleibt ewig offen. Fällt erst auf, sobald Störungen geplant werden (heute 0 von 36 geplant). | `heute_liste.dart:443-448`, `tourenplanung_screen.dart:1880-1907` | S — **Rückfrage: werden Störungen überhaupt vorausgeplant?** |
| **R6** | **Zwei rote Knöpfe ohne Rückfrage:** «Tagesplan leeren» (löscht + speichert sofort), «Google trennen». | `tourenplanung_screen.dart:1091`, `einstellungen_screen.dart:319` | Kleinfix |
| **R7** | **Betriebsferien: Formular schreibt Altspalten, Planung liest `betrieb_ferien`.** Detail zeigt Altspalten. 3 Perioden am 25.09. von Hand nachgetragen. | `betrieb_form_screen.dart:181-192, 572-581` vs. `betrieb_providers.dart:29-45` | M (½–1 Tag) |
| **R8** | **Foto-Upload scheitert still** — Reinigung wird trotzdem abgeschlossen, Rechnung + Mail raus, ohne Protokoll; keine Aufgabe merkt es. Formular lebt nur im Tab (kein Entwurf), Kamera schiebt Chrome in den Hintergrund → wahrscheinliche Ursache der ~23 Abbrüche. | `reinigung_form_screen.dart:686-690` | M (Foto sofort hochladen + rot melden; Entwurf sichern: 1 Tag) |
| **R9** | **Debitoren 1100 = 117'416.58, offene Rechnungen = 131'193.44 → −13'776.86 unerklärt.** Keine Regel meldet es; der Debitoren-Header bietet stattdessen eine «historische Sammel-Abschreibung» ohne Belegbezug, Datum 31.12.2024 vorbelegt, ohne Rückweg. | `debitoren_header.dart:91-175` | M (Prüfregel «1100 = offene Rechnungen − Guthaben», dann Differenz klären; Header entschärfen) |
| **R10** | **Mahnung nimmt andere Mailadresse als die Rechnung** (Mahnung fällt auf `betriebe.email` zurück, Rechnung nicht; 32 Betriebe weichen ab). Vor dem Scharfstellen entscheiden. | `mahnregeln.dart:329-340` vs. `reinigung_rechnung_versand.dart:289-305` | S — **Entscheid Daniel** |
| **R11** | **Sechs Edge Functions ohne eigene Benutzerprüfung** (`verify_jwt` allein schützt nicht, der Anon-Key ist ein gültiges JWT): `parse-oeffnungszeiten` (lädt jede URL: SSRF + Claude-Kosten), `betrieb-google-lookup`/`-abgleich` (Google-Kosten, schreibt `google_place_id`), `betriebsdaten-abgleich` (Kostenlawine, `limit` ohne Deckel, Cron ohne Secret), `anfahrt-google` (Voll-Lauf per `POST {}`), `parse-protokoll` (kein Aufrufer). `send-raster-mail` wird aufgerufen, hat aber keinen Quellcode im Repo. | `supabase/functions/*` | S–M (getUser + URL-Filter, Cron-Secret; 2–3 h gesamt) |

Reihenfolge: R2, R3, R4, R6 (je Minuten bis 1 h) → R1, R11 → R7, R8 → R9 → R5/R10 nach Rückfrage.

---

## 3. Doppelspurigkeiten (wo derselbe Vorgang mehrfach gebaut ist)

| Was | Wie oft | Folge | Vorschlag | Aufwand |
|---|---|---|---|---|
| **Reinigungs-Abschlusskette** (Rechnung → Mail → Status → Buchung) | 2× — Screen (`_save`, 820 Zeilen) und `ReinigungRechnungVersand.erstelleUndSende` (nur fürs Nachholen) | Jeder Fix doppelt; die Kette riss 03./04./07./11.09. | Screen ruft den Service | 1–1½ Tage + Browser-Test |
| **Rechnung «bezahlt» setzen** | 7 Schreibwege, 22 Stellen schreiben `zahlungsstatus`, 4 direkt aus Screens; nur die Barzahlung (v0.136) prüft sauber gegen den DB-Stand | `zahlung_betrag` heisst je nach Weg Brutto / zu zahlen / 0 / nichts; Rückgängig beim Bankweg lässt `mahnung_stufe` stehen, darf im abgeschlossenen Jahr löschen, nimmt Sammelzahlungen nur teilweise zurück | **Ein `ZahlungKern.erfassen/zuruecknehmen`** (Sperrprüfung, `differenzPlan`, geschützter Status, Zahlungsgruppe, Vorher-Stand, Jahressperre) — am besten als DB-Funktion in einer Transaktion | 2 Tage, Plan nötig |
| **«Offen» definiert** | 3 Varianten; `istOffen` existiert, hat 2 Aufrufer, 12× von Hand | R2 | zentrales `istZahlbar()` | ½ Tag |
| **Mail-Versand `send-rechnung-mail`** | 11 Aufrufe in 8 Dateien, 6 in Screens; Rechnungs-Mailtext 2× kopiert | — | ein `RechnungMailService` | im Zug der Abschlusskette |
| **Formular-Bausteine** | Betriebsfeld 5× (~85 Z.), Arbeitszeit-Block 2×, Material-Slots 3×, Foto-Sektion 2×, `_SectionCard` 11×, `_InfoRow` 13×, 29 einzelne Datumswähler, 10 handgebaute Ladedialoge | ~1'000 Zeilen doppelt; Verhalten driftet (Tourenplan-«erledigt» ≠ Heute-«erledigt») | `BetriebFeld`, `ArbeitszeitBlock`, `MaterialSlots`, `DetailKarte/InfoZeile`, `zeigeDatumsauswahl()` mit Wächter | 2–3 Tage, mechanisch (Sonnet) |
| **Firmendaten/IBAN/MwSt/Rundung** | IBAN 3× fest im Code (inkl. QR), Telefon/Mail in 5 PDF-Services, MwSt-Satz aus 3 Quellen (2 statische Felder, feste 8.1), 5-Rappen-Rundung 2 Helfer + 8 Kopien | `geschaeft_einstellungen` wird gepflegt, aber nicht gelesen | eine Quelle je Wert | 1 Tag |
| **Kontakte** | 2 Modelle (`Kontakt`, `BetriebKontakt`) für dieselbe Tabelle, je Repository + Formular; Betriebs-Mail vs. Hauptkontakt vs. Rechnungsadresse | R10 | ein Modell; `betriebe.email` als Info beschriften | ½ Tag |
| **Prüfungen** | «Reinigung ohne Buchung» 3×, camt-Kette 3×, 1020-gegen-Bank 2×, Verjährung 2× (verschiedene Stichtage) | widersprüchliche Ampeln möglich | je eine Regel in `abschluss_regeln.dart` | ½ Tag |
| **Buchhaltungs-Screens** | Debitoren-Header, Prüflisten-Dialog + Abgleich-Vorschau (5 Aufrufstellen), Monatsabschluss + Audit, Offen-pro-Betrieb, Dashboard-Kennzahlen (DB-Views) vs. Berichte (Dart) | zwei Wahrheiten nicht gegeneinander getestet | Header auflösen (Kennzahl → Audit-Regel), ein Zuordnen-Widget, eine Prüfseite Monat/Jahr, Offen-pro-Betrieb als Gruppierung der Rechnungsliste | M |
| **Toter Code** | 17 Dateien / 2'521 Zeilen, ~450 Zeilen tote Service-Funktionen (`CamtAutoBooker.run`, `ZahlungsdifferenzService.verbuchen`, `HeinekenPdfService.generate`, …), 45 Provider, 29 Repo-Methoden, 2 ungenutzte pubspec-Pakete, kaputte Gast-Redirects, HeiGenie-Pfad in der Reinigung (0× benutzt) | — | löschen | ½ Tag, Sonnet |

---

## 4. Vereinfachen im Tagesbetrieb

| # | Vorschlag | Warum | Aufwand |
|---|---|---|---|
| T1 | Foto sofort beim Aufnehmen hochladen, Fehler rot; Aufgabe «Reinigung ohne Protokollfoto» | R8 | ½–1 Tag |
| T2 | Laufende Reinigung als Entwurf lokal sichern, beim Öffnen «fortsetzen?» | ~23 Abbrüche/17 Tage | 1 Tag |
| T3 | Zahlungsart vorbelegt ins Formular, Dialog nur bei Abweichung (82 % stimmen mit der Betriebsvorgabe überein) | spart je Reinigung 1 Tap + 2 Anfragen | ½–1 Tag |
| T4 | Service-Art aus dem Plan mitgeben (Eröffnung/Endreinigung: 36× von Hand umgestellt) | — | ¼ Tag |
| T5 | Pausen-Prüfung (GPS + Dialog) ans Ende der Abschlusskette | verkürzt das Fenster, in dem Wegstecken die Buchung kostet | ¼ Tag |
| T6 | Formular entrümpeln: «Wasser gewechselt» (0 von 405), «Ende»-Eingabe (App setzt es selbst), HeiGenie-Pfad; Hauptknopf «Abschliessen» auf `TapKnopf` (heute `FilledButton` — CanvasKit-Falle im häufigsten Pfad) | — | ½ Tag |
| T7 | Heute-Karte nur mit Aufgaben für draussen; Büro-Fristen (MWST, Heineken, Mahnlauf, Saison-Zähler) nur in Glocke/Büro | Saison meldet sich heute 4× | ½ Tag |
| T8 | Glocke ergänzen: Reinigung ohne Foto, angefangene Reinigung, laufende Arbeit von gestern, Arbeitstag ohne Ende/km, Diktat-Warteschlange, RSL-Mail ohne Vermerk | — | 1 Tag |
| T9 | Diktat-Text wirklich als Notiz mitgeben (heute 6 s Snackbar) | Kommentar verspricht es | ¼ Tag |
| T10 | Betriebsseite als «Akte»: Geld-Block (offener Saldo, Mahnstufe, Guthaben, offene Rechnungen), eine Einsätze-Sektion mit Montagen (fehlen heute ganz), Saison-Verlauf | Betriebsseite ist mit 100 Aufrufen die Nr. 3 | ½ Tag (Geld) / 1½ Tage (ganz) |
| T11 | Umwege schliessen: Änderungsvorschläge (nur via Aufgabe erreichbar), Servicezeiten/Saisondaten (kein Menüeintrag), Lohn-Einstellungen doppelt, Bergkundenpauschalen nicht in der Suche | — | ½ Tag |
| T12 | Events aus «Mehr» ausblenden (Kachel in der ersten Gruppe; 3 Events, 2 Aufrufe/17 Tage; Tabellen bleiben wegen Gampel-Export) | — | 15 min — **Rückfrage** |

---

## 5. Qualität und Absicherung

| # | Vorschlag | Aufwand |
|---|---|---|
| Q1 | **Gefahr-Wächter schärfen** (`X.icon(`, `Colors.red`, ungefärbte Lösch-Buttons) und die 17 verbleibenden unumkehrbaren Bestätigungen auf `TapKnopf(gefahr: true)` — heikelste: «Zahlung rückgängig» im Rechnungsdetail | ½ Tag |
| Q2 | **CanvasKit-Wächter über alle Screens** statt Dateiliste (die tägliche Reinigung, Betriebsauswahl, Tourenplan, Spesen fehlen darin) | ½ Tag |
| Q3 | **Edge-Function-Wächter:** jede Function prüft `getUser`; jeder `invoke`-Name hat einen Ordner; config.toml vollständig | 1½ h |
| Q4 | `zahlungsstatus`-Konstante gegen den DB-CHECK (Werte stehen 74×/71× als Literal) | 2 h |
| Q5 | Neue Prüfregeln: 1100 = offene Rechnungen − Guthaben; Rechnung bezahlt/abgeschrieben mit Restsaldo; Heineken `freigegeben` ohne Buchung; verwaiste Belegbezüge; Status ↔ Mahnstufe widersprüchlich; 2030 ohne Betrieb; Kasse gegen Belege | 1 Tag |
| Q6 | **Ladeverhalten:** Dashboard lädt 5'278 Rechnungen für eine Zahl (`countOffene()` existiert); Journal (16'879) wird bis 4× geladen, weil `buchungenStreamProvider` als Neurechnen-Signal dient; Heute lädt alle 8'695 Reinigungen; nur 15 von 108 Providern `autoDispose` | 1–2 Tage |
| Q7 | `flutter analyze` 56 → 14 mit Kleinfixes (`dart fix`, `analyzer: exclude` für `.g.dart`, `context.mounted`) | ¾ Tag |
| Q8 | Geld-Logik als reine Funktionen: Störungs-Preisformel, Heineken-Summen, Nachhol-Auswahl, Sync-Konflikt; `_save` der Formulare | je 1–3 h |
| Q9 | Isar-Zweig **einfrieren** (4'400 handgeschriebene + 108k generierte Zeilen; nur 25/63 Repositories haben ihn; Buchhaltung/Rechnungen/Mahnwesen laufen nur Web; `getById` erwartet nativ Zahl-IDs — Mahnfall/Aufgaben würden nativ abstürzen; Isar 3.1 unmaintained) — in `docs/` festhalten, nicht mehr mitpflegen; Entfernen später mit der Heineken-Session | 1 h — **Rückfrage** |
| Q10 | Migrationen: Lücken 008/009, Doppelnummern 083/091/092; eine `SECURITY DEFINER`-Funktion ohne `search_path` | 1 h |

---

## 6. Reihenfolge, wenn alles gilt

| Runde | Inhalt | Aufwand |
|---|---|---|
| **1 — Sicherheit der Zahlen** (v0.139) | ✅ **erledigt 25.09.2026, live v0.139.0** — R2, R3, R4, R6, R11, Q1, Q3, Q5 (Regel 1100 + 2030), R9 geklärt (Heineken Juli nachgebucht, Rest −3'674.70 Excel-Altbestand) | 1 Tag |
| **2 — Eine Kette** (v0.140–0.141) | ✅ **erledigt 26.09.2026, live v0.140.0 + v0.141.0:** R1, Abschlusskette Screen → Service (§3 Zeile 1), T1/T5/T6, R7 Ferien (+ Kalender-Schlüssel nach Datum) | 1 Tag |
| **3 — ZahlungKern** (v0.142) | ein Zahlungsweg, Rückgängig repariert, `istZahlbar`, Debitoren-Header weg, Wahl 8000/2030 und 3805-MWST | 3 Tage, Plan mit Fable |
| **4 — Bausteine & Aufräumen** (v0.143) | Formular-Bausteine, `zeigeDatumsauswahl`, Detail-Gerüst, toter Code, Firmendaten/MwSt/Rundung zentral, Q2/Q4/Q7, Isar einfrieren | 4–5 Tage, grösstenteils Sonnet |
| **5 — Tagesbetrieb** (v0.144) | T2, T3, T4, T7–T11, Q6 | 4–5 Tage |

Nicht vorgeschlagen: ein einziges Einsatz-Formular für alle sechs Typen (Speicherlogik zu verschieden — Anforderung für die v2), Aufteilen der grossen Dateien ohne anderen Anlass, Löschen der Event-Tabellen.

---

## 7. Fragen an Daniel

1. **Störungen/Montagen:** Werden sie vorausgeplant oder immer sofort erledigt? (0 von 36 Störungen hatten ein Plandatum.) Wenn sofort: «Erst geplant»-Schalter und Beginn-Block einklappen statt den Start-Pfeil umzubauen.
2. **Mahnung-Mailadresse:** Nur Rechnungsadresse (wie die Rechnung) oder Rückfall auf Betriebs-Mail? Betrifft 32 Betriebe.
3. **Events:** In dieser App noch gebraucht, oder aus «Mehr» ausblenden?
4. **Isar/nativer Pfad:** einfrieren?
5. **−13'776.86 auf 1100:** klären wir gemeinsam nach der neuen Prüfregel — oder weisst du, was es ist (Historik-Rest aus dem Excel-Import)?
6. **`send-raster-mail`:** Heineken-Raster-Mail — noch in Gebrauch? Es gibt keinen Quellcode im Repo.

## 8. Prüfung

Alle Zahlen stammen aus Code (Grep, Import-Verfolgung), aus `route_nutzung` und lesenden DB-Abfragen. Die beiden schwersten Befunde (R1, R2) habe ich selbst im Code nachgeprüft. Nicht geprüft: Verhalten auf dem Handy, Server-Migrationen ohne lokale Datei.
