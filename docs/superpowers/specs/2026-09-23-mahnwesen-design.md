# Mahnwesen — Design

**Datum:** 23.09.2026 · **Stand der App:** v0.133.3
**Grundlage:** Rechtslage und Praxis in
`docs/buchhaltung/mahnwesen-recherche-2026-09-23.md` (Quellen dort; keine
Rechtsberatung).

## Ziel

Überfällige Kundenrechnungen verlässlich mahnen — einzeln oder als
Sammelmahnung pro Betrieb, per Mail oder als PDF zum Ausdrucken — und den Weg
bis zur Betreibung führen, mit Heineken als Zwischenschritt. **Nie eine
bezahlte Rechnung mahnen.** Scharfgestellt wird erst nach ausgiebigem Test;
bis dahin geht jede Mail an Daniel.

## Ausgangslage (23.09.2026)

- Es gibt schon: Mahnstufen je Rechnung (`zahlungsstatus` erinnert /
  mahnung_1 / mahnung_2, Felder `erinnerung_am`, `mahnung_1_am`,
  `mahnung_2_am`, `mahnung_stufe`, `letzte_mahnung_am`), `MahnwesenService`
  (Einzel-PDF je Stufe, Upload, optional Mail), `ForderungService`
  (Fälligkeitsregel 5/25/30 Tage), Detektor «Mahnlauf» in der Glocke,
  `MailConfig.mahnwesenScharf = false`, `KontoauszugPdfService` (je Betrieb
  und Jahr, mit Zahlungen und QR, v0.127/128), Einzelabschreibung mit
  MWST-Rückholung (Ziff. 235).
- **Nie benutzt:** keine Rechnung hat je eine Mahnstufe.
- Offene Kundenrechnungen ab 01.01.2026 (ohne Heineken-Monatsrechnung):
  51 per Mail versendet, 67 am Tresen übergeben (mit Datum), 55 mit
  Versandart «Tresen» ohne Übergabedatum (Datum wird erst seit v0.71.0
  gespeichert), 4 ohne jeden Zustellnachweis.
- Letzter eingelesener Bankauszug: bis 31.08.2026.

## 1. Was ins Mahnsystem kommt

Eine Rechnung ist **im Mahnsystem**, wenn alles gilt:

1. `rechnungstyp` ist `kundenrechnung` oder `jahresrechnung` (nie
   `heineken_monat`).
2. `rechnungsdatum >= 2026-01-01`. Ältere Rechnungen sind **Altlast** und
   laufen über die jahrgangsweise Abschreibung (Entscheid 19.09.2026).
3. `zahlungsstatus` ist nicht `bezahlt` / `abgeschrieben`.
4. **Zugestellt:** `versendet_am` gesetzt **oder** `uebergeben_am` gesetzt
   **oder** `versandart = 'rechnung_tresen'` (dann gilt das Rechnungsdatum als
   Übergabedatum — Entscheid Daniel 23.09.2026).

Rechnungen, die 1–3 erfüllen, aber 4 nicht, erscheinen als **«erst
zustellen»** und werden nie gemahnt.

**Zustelldatum** (für die Fristberechnung): `versendet_am` ?? `uebergeben_am`
?? `rechnungsdatum`.

## 2. Stufen und Fristen (je Rechnung)

| Stufe | Wert | fällig, wenn … | neue Frist im Schreiben |
|---|---|---|---|
| Zahlungserinnerung | 0 → `erinnert` | Fälligkeit + 10 Tage vorbei | 10 Tage |
| 1. Mahnung | 1 → `mahnung_1` | Frist der Erinnerung + 5 Tage vorbei (≈ 15 Tage nach Erinnerung) | 10 Tage |
| Letzte Mahnung | 2 → `mahnung_2` | Frist der 1. Mahnung + 5 Tage vorbei | 10 Tage, Androhung Betreibung |
| Heineken einschalten | Fall (Abschnitt 5) | Frist der letzten Mahnung + 5 Tage vorbei | — |

- **Neues Feld** `rechnungen.mahn_frist_bis date` (Migration): gesetzt beim
  Versand einer Stufe (Versanddatum + 10 Tage).
- Fälligkeit der ersten Stufe richtet sich nach `faelligkeitsdatum`. Liegt
  das Zustelldatum **nach** dem Fälligkeitsdatum (nachträglich zugestellt),
  gilt Zustelldatum + 30 Tage als Fälligkeit.
- **Kein Verzugszins, keine Gebühren** in den Schreiben (ohne Vereinbarung
  unzulässig bzw. nicht sinnvoll). Die letzte Mahnung weist auf 5 % Zins ab
  Datum der Erinnerung im Fall einer Betreibung hin.
- **Die App schlägt vor, Daniel löst jede Stufe selbst aus.** Kein
  automatischer Versand.
- `ForderungService.empfohleneAktion` wird durch die neue Regel ersetzt
  (eine Stelle, reine Funktion, getestet).

## 3. Vier Sicherungen gegen «bezahlt, trotzdem gemahnt»

1. **Harte Sperre:** Der Mahnlauf lässt sich nur starten, wenn der letzte
   Bankauszug (`camt_dateien.zeitraum_bis`, Maximum) **höchstens 2 Tage** alt
   ist. Sonst: «Zuerst Bankauszug einlesen» mit Direktweg zum Import.
2. **Stichtag = Auszug, nicht heute:** Eine Stufe ist nur fällig, wenn ihre
   Bedingung aus Abschnitt 2 **mindestens 3 Tage vor dem Auszug-Stichtag**
   erfüllt war (Zahlung am letzten Fristtag ist sicher im Auszug).
3. **Ungeklärte Gutschrift sperrt den Betrieb:** Gibt es in
   `camt_pruefliste` eine offene Gutschrift (`ist_gutschrift`, Status nicht
   erledigt), deren `partei_name` normalisiert einem `zahler_aliase` des
   Betriebs bzw. dessen Name entspricht **oder** deren Betrag einer
   mahnfälligen Rechnung des Betriebs oder deren Summe entspricht, wird der
   Betrieb gesperrt: «Zahlung ungeklärt — zuerst zuordnen». Gilt auch für
   Sammelzahler.
4. **Kontrolle vor dem Versand:** Vorschau je Betrieb mit allen Rechnungen und
   dem Datum der letzten Zahlung des Betriebs; Versand erst mit zweitem Klick.

Jedes Schreiben enthält: «Falls Sie die Zahlung inzwischen ausgelöst haben,
betrachten Sie dieses Schreiben als gegenstandslos.» Nicht erkennbar bleiben
nicht erfasste Barzahlungen — dafür ist Sicherung 4 da.

## 4. Mahnlauf und Schreiben

### Seite «Mahnlauf» (`/rechnungen/mahnlauf`)

Erreichbar über eine Karte oben in der Kunden-Rechnungsliste und über die
Aufgabe «Mahnlauf: N Betriebe fällig» (Detektor umgestellt auf Abschnitt 1–3).

- **Kopf:** Bankstatus («Auszug bis 22.09. ✓» oder Sperre).
- **Mahnfällig:** Karte je Betrieb (Name, Ort, Anzahl, Summe, höchste
  fällige Stufe, Kanal Mail/PDF, Sperre). Aufgeklappt: Rechnungen mit
  Häkchen (Standard: alle fälligen). → ganzer Betrieb oder einzelne Rechnung.
- **In Frist:** gemahnte Rechnungen mit laufender Frist.
- **Erst zustellen:** Rechnungen ohne Zustellnachweis.
- **Einzelmahnung aus der Rechnung:** «Jetzt mahnen» in der
  Rechnungs-Detailseite öffnet denselben Ablauf mit nur dieser Rechnung
  (Sicherungen 1–4 gelten).

### Mahnschreiben (PDF, eines pro Betrieb und Lauf)

- Briefkopf und Rechnungsadresse wie auf der Rechnung (Rechnungsadresse →
  Betriebsdaten als Rückfall, wie die Rechnung).
- **Titel = höchste Stufe** der enthaltenen Rechnungen; Text je Stufe.
- Tabelle: Rechnungsnummer, Rechnungsdatum, fällig seit, Betrag, Stufe dieser
  Rechnung. Total. **Neue Frist als Kalenderdatum.**
- **QR-Zahlteil je Rechnung** mit ihrer Original-QR-Referenz (zwei pro
  Seite) — kein Sammel-QR, damit der Bankabgleich eindeutig bleibt.
- Über `pdfDokument()` (Unicode-Schrift, Wächter).

**Texte (Entwurf):**
- *Erinnerung:* «Vermutlich ist Ihnen die folgende Rechnung entgangen. Wir
  bitten Sie, den offenen Betrag bis [Datum] zu überweisen.»
- *1. Mahnung:* «Trotz unserer Zahlungserinnerung vom [Datum] ist die Zahlung
  noch nicht bei uns eingegangen. Wir bitten Sie, den offenen Betrag bis
  [Datum] zu begleichen.»
- *Letzte Mahnung:* «Leider ist der offene Betrag trotz Erinnerung vom
  [Datum] und Mahnung vom [Datum] noch nicht eingegangen. Ohne
  Zahlungseingang bis [Datum] leiten wir ohne weitere Ankündigung die
  Betreibung ein; dabei wird ein Verzugszins von 5 % seit [Datum Erinnerung]
  geltend gemacht. Bei Zahlungsschwierigkeiten melden Sie sich bitte — wir
  finden gerne eine Lösung.»
- Bei allen: Gegenstandslos-Satz (Abschnitt 3).

### Beilagen

- **Rechnungskopien** der gemahnten Rechnungen (gespeicherte PDFs).
- **Bei mehr als einer offenen Rechnung** des Betriebs im Mahnsystem:
  **Kontoauszug des laufenden Jahres** (`KontoauszugPdfService`, alle
  Rechnungen und Zahlungen des Jahres, laufender Saldo).

### Kanal

- **Mail**, wenn die Rechnungsadresse (bzw. Rückfall Betrieb) eine
  Mailadresse hat: Mahnschreiben + Beilagen als Anhänge über
  `send-rechnung-mail` (Mehrfach-Anhang prüfen/ergänzen).
- **PDF zum Ausdrucken** ohne Mailadresse: ein zusammengefügtes PDF
  (Schreiben, Kopien, Auszug).
- **Letzte Mahnung:** immer PDF zum **Einschreiben**, zusätzlich Mail, falls
  Adresse vorhanden.
- **Testmodus** (`mahnwesenScharf = false`): Mail an Daniel, Betreff beginnt
  mit «TEST an: <echte Adresse> —»; PDFs mit diagonalem Aufdruck **«MUSTER»**.

### Nach dem Versand

Je Rechnung: Stufe, Datum, `mahn_frist_bis`; Schreiben abgelegt
(`mahnungen/<betrieb>/<datum>_<stufe>.pdf`) und in der Rechnungs-Detailseite
als Mahnverlauf sichtbar. **«Mahnung zurücknehmen»** (je Lauf): setzt die
Stufen der enthaltenen Rechnungen auf den Stand davor und markiert das
Schreiben als zurückgenommen (nicht löschen). Im Testmodus unverzichtbar, weil
Stufen auch beim Testen gesetzt werden.

Protokoll je Lauf: neue Tabelle **`mahnschreiben`** (id, betrieb_id, stufe,
rechnung_ids, kanal, empfaenger, test, pdf_pfad, erstellt_am,
zurueckgenommen_am).

## 5. Eskalation: Heineken und Betreibung

Neue Tabelle **`mahnfaelle`** — ein Fall je Betrieb und Eskalation:

- `betrieb_id`, `rechnung_ids`, `eroeffnet_am`, `status`
  (`heineken` / `heineken_frist` / `betreibung` / `erledigt`)
- Heineken: `heineken_kontakt_am`, `heineken_ergebnis`
  (`vermittelt` / `uebernommen` / `konkurs` / `betreibung`), `heineken_frist_bis`
- Betreibung: `schuldner_name`, `schuldner_adresse`, `rechtsform`,
  `betreibungsamt`, `eingereicht_am`, `zahlungsbefehl_am`, `rechtsvorschlag`
  (bool), `fortsetzung_am`, `kosten_vorschuss`, `erledigt_am`,
  `erledigung` (`bezahlt` / `abgeschrieben` / `zurueckgezogen`), `notiz`

### Heineken einschalten

- Vorgeschlagen, wenn die Frist der letzten Mahnung + 5 Tage vorbei ist.
- Mail an den Heineken-Kontakt der neuen Zuweisung **«Mahnwesen»**
  (`heineken_kontakt_zuweisungen.funktion = 'mahnwesen'`): Betrieb mit Ort,
  offene Rechnungen, Mahnverlauf, Bitte um Unterstützung; Beilage
  Kontoauszug. Testmodus: an Daniel.
- Nach 20 Tagen ohne Ergebnis: Aufgabe in der Glocke.

### Ergebnisse

| Ergebnis | Wirkung |
|---|---|
| **Vermittelt, Kunde zahlt** | `heineken_frist_bis` (Standard +20 Tage); Zahlung über Bankabgleich; ohne Eingang wieder offen für Betreibung. |
| **Heineken übernimmt** | Rechnungen gelten als beglichen «durch Heineken übernommen» (zusätzlicher Vermerk, Status `bezahlt`); nächste Heineken-Monatsrechnung erhält die Position «Übernahme offener Kundenrechnungen» (Betrieb, Rechnungsnummern, **ohne MWST** — Zahlung durch Dritte, keine neue Leistung). Buchung: Umbuchung Debitor Kunde → Debitor Heineken. **Beim ersten echten Fall gemeinsam prüfen** (Entscheid Daniel 23.09.2026). |
| **Kunde Konkurs** | bestehende Einzelabschreibung je Rechnung (Ziff. 235 im laufenden Quartal); Hinweis «Forderung beim Konkursamt anmelden möglich». |
| **Betreibung auslösen** | weiter unten. |

### Betreibung

- **Datenblatt** zum Abtippen in EasyGov: Schuldner (Name, Rechtsform,
  Adresse — bei Einzelfirma Wohnsitz des Inhabers, einmal zu erfassen),
  Forderung je Rechnung, «nebst Zins zu 5 % seit [Datum Erinnerung]»,
  Hinweis auf das zuständige Betreibungsamt (Region), Link zu EasyGov.
- **Schritte mit Datum:** eingereicht → Zahlungsbefehl zugestellt →
  Rechtsvorschlag ja/nein → Fortsetzungsbegehren (Glocke: ab +20 Tagen
  möglich, Warnung vor Ablauf 1 Jahr) → erledigt.
- **Rechtsvorschlag:** Anzeige der vorhandenen Belege (unterschriebene
  Reinigungsprotokolle je Rechnung) mit Hinweis auf die Unsicherheit
  (Recherche Abschnitt 7).
- Kostenvorschuss erfassen (7 / 20 / 40 CHF je nach Betrag).

## 6. Hinweis beim Service

- Beim Öffnen einer neuen Reinigung, Störung oder Montage für einen Betrieb
  mit Rechnungen **ab 1. Mahnung**: oranges Band «N Rechnungen gemahnt,
  X CHF offen (1. Mahnung vom …)». Ab offenem Mahnfall: rot, plus «nur gegen
  Barzahlung» (OR 82).
- Antippen: Liste der Rechnungen + **«Offene Rechnungen einkassieren»**
  (Bar/TWINT, bestehende Zahlungserfassung, Kasse).
- Nur Hinweis, keine Sperre. CanvasKit-sicher (GestureDetector/Container).

## 7. Testphase und Scharfstellen

- `mahnwesenScharf` bleibt `false`, bis Daniel ausdrücklich scharfstellt.
- Test-Kennzeichnung: Betreff «TEST an: …», PDF «MUSTER».
- Stufen werden auch im Test gesetzt (sonst lässt sich der Ablauf nicht
  durchspielen); «Mahnung zurücknehmen» je Lauf.
- Scharfstellen: eigener Commit + Deploy, erst nach ausgiebigem Test.

## 8. Teile und Auslieferung

| Teil | Version | Inhalt |
|---|---|---|
| **1 Mahnlauf** | v0.134.0 | Regeln (Abschnitt 1–3) als reine Funktionen, Migration `mahn_frist_bis` + `mahnschreiben`, Mahnlauf-Seite, Sammelschreiben mit QR je Rechnung, Beilagen, Mail/PDF im Testmodus, Einzelmahnung aus der Rechnung, Zurücknehmen, Detektor umgestellt |
| **2 Eskalation** | v0.135.0 | `mahnfaelle`, Heineken-Schritt (Zuweisung, Mail, vier Ergebnisse), Position auf der Heineken-Monatsrechnung, Betreibungs-Datenblatt und Schritte, Fristen in der Glocke |
| **3 Vor Ort** | v0.136.0 | Band beim Service, «Offene Rechnungen einkassieren» |

**Vor dem ersten echten Mahnlauf:** aktuellen Bankauszug einlesen.

## 9. Absicherung

- Reine Funktionen mit Tests: Mahnsystem-Zugehörigkeit (Datum, Typ, Status,
  Zustellung, Tresen-Regel), Stufen-Fälligkeit relativ zum Auszug-Stichtag,
  Sperre durch ungeklärte Gutschrift (Alias, Name, Einzel- und
  Summenbetrag), Titel/höchste Stufe, Fristdatum, Zurücknehmen.
- PDF-Tests: Titel, Tabelle, QR je Rechnung, «MUSTER» im Testmodus.
- Wächter: Testmodus — solange `mahnwesenScharf == false`, geht keine Mail an
  eine andere Adresse als den Testempfänger (MailConfig).
- Sichtprüfung im Browser bei 360 px vor jedem Deploy.

## Nicht in diesem Vorhaben

- Mahngebühren, Verzugszins im Schreiben.
- AGB-Klausel (für Leistungen ab 2027) — eigener Punkt in `ToDo.md`, mit
  Prüfung durch eine Fachperson.
- Automatischer Versand ohne Klick.
- Mahnung von Rechnungen vor 01.01.2026.
