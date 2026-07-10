# Events-Modul — Phase E5: Abschluss-Mail (Design)

**Datum:** 2026-07-10
**Aufbauend auf:** E1 (Kontakte, v0.17.0), E2 (Stände/Anlagen/Dokumente, v0.18.1),
E3 (Inbetriebnahme/GPS-Karte/Einsätze, v0.19.0), E4 (Zeit-/Spesenerfassung + Auto-Montage, v0.20.x)
**Status:** Vom User abgenommen (10.07.2026)
**Letzte Phase des Events-Moduls.**

## Ziel & Kontext

Am Eventende wird ein **Abschlussbericht als PDF** an den Eventverantwortlichen und den RSL
(im Gebiet des Events) sowie wahlweise weitere Kontakte gemailt. Der Bericht fasst zusammen,
was gemacht wurde (Stände/Anlagen/Inbetriebnahme, erfasste Zeiten, Pikett-Einsätze). Die
**Abrechnung** läuft unverändert separat über Montage/Monatsrechnung — der Bericht enthält
daher **keine Geldbeträge**.

## Entscheidungen (mit User geklärt)

- **PDF ohne CHF:** nur Tätigkeiten/Zeiten/Einsätze, keine Geldbeträge (Abrechnung getrennt).
- **Mail-Text:** sinnvoller deutscher Standard (unten definiert), später leicht anpassbar.
- **Kein Versand-Vermerk / keine DB-Migration:** nach dem Senden nur Bestätigungs-Snackbar.
- **Empfänger:** Eventverantwortlicher + RSL automatisch aus den Event-Kontakten (nach Rolle)
  vorgeschlagen; im Sheet abhakbar + weiterer Kontakt / freie Mail-Adresse hinzufügbar.
- **Auslöser:** Menüpunkt „Abschluss-Mail senden" im 3-Punkte-Menü des Event-Detail.
- **Scharfstellung:** neuer `MailConfig`-Bereich `event`, Start `eventScharf = false` (Test →
  an `dani.proyer@gmail.com`), später manuell scharf.
- **Mehrfach-Empfänger:** ein Mailaufruf mit kommaseparierten Adressen (Gmail-tauglich; die
  Edge-Function `send-pdf-mail` setzt `to` direkt in den `To:`-Header). Keine Function-Änderung.

## Vorhandene Infrastruktur (wird genutzt)

- `BerichtMailService.send({to, subject, bodyText, filename, pdf})` →
  Supabase Edge-Function `send-pdf-mail` (Gmail API). `to` akzeptiert kommaseparierte Adressen.
- `MailConfig`: bereichsweise Scharfstellung (`empfaenger(echt, bereich:)`, `istScharf(bereich)`,
  `bereinige(email)`). Muss um `event` erweitert werden.
- `BerichtPdfCommon` (`services/pdf/bericht_pdf_common.dart`): `kopf(titel, periode)` mit
  SBS-Projer-Briefkopf (SBS Projer GmbH, Via Rezia 8, 7013 Domat/Ems). `pdf`-Paket
  (`pw` widgets).
- Provider: `eventEinsaetzeProvider`, `eventAufwaendeProvider`, `eventStaendeProvider`,
  `eventStandAnlagenProvider`, `eventKontakteProvider`. `kAufwandKategorien` (E4),
  `inbetriebnahmeFortschritt` (E3), `EventStand.anlagenText` (E2).

## Datenmodell

**Keine Änderung.** E5 liest bestehende Entities (events, event_kontakte, event_staende,
event_stand_anlagen, event_einsaetze, event_aufwand, kontakte). Keine Migration.

## Bausteine

### 1. MailConfig-Bereich `event`

- Neue Konstante `static const eventScharf = false;`.
- In `empfaenger(...)` ein `case 'event': if (!eventScharf) return bereinige(testEmpfaenger);`.
- In `istScharf(...)` ein `case 'event': return eventScharf;`.
- Verwendung für die Empfängerliste (siehe 4): im Test-/Unscharf-Fall gehen alle Mails an
  `testEmpfaenger`, sonst an die echten (bereinigten) Adressen.

### 2. PDF — `EventAbschlussPdfService`

`services/pdf/event_abschluss_pdf_service.dart`. Reine Datenklasse als Input (kein Provider-Zugriff
im Service → testbar/aufrufbar von überall):

```dart
class EventAbschlussDaten {
  final String eventName;      // Betriebsname (Veranstaltung)
  final String zeitraum;       // z.B. "23.–26.07.2026" oder "2026"
  final List<({String name, String anlagenText, String inbetriebLabel})> staende;
  final int anlagenTotal;
  final int anlagenInBetrieb;
  final List<EventAufwandLocal> aufwaende;   // sortiert nach Datum
  final List<EventEinsatzLocal> einsaetze;   // chronologisch
  final Map<String,String> standNamen;       // serverId → Name (für Einsatz-Stand-Spalte)
}
```

`static Future<Uint8List> build(EventAbschlussDaten d)` erzeugt A4-PDF:
- Kopf: `BerichtPdfCommon.kopf('Abschlussbericht', '${d.eventName} · ${d.zeitraum}')`.
- **Zusammenfassung** (kleine Box/Liste): Anzahl Stände, Anlagen `d.anlagenInBetrieb`/`d.anlagenTotal`
  in Betrieb, Anzahl Einsätze `d.einsaetze.length`, Total Stunden = Summe `aufwaende.stunden`
  (2 Dezimalstellen).
- **Stände** (Liste): je Stand `name` — `anlagenText` — `inbetriebLabel`.
- **Zeit & Aufwand**: pro Kategorie (`kAufwandKategorien`-Reihenfolge) ein Unterabschnitt mit
  Zeilen `dd.MM. · notiz · x.xx h` und Kategorie-Summe; darunter Gesamt-Stunden. **Keine CHF.**
  Kategorien ohne Zeilen weglassen.
- **Einsätze**: Tabelle mit Spalten Zeitpunkt (`dd.MM. HH:mm`), Beschreibung, Material, Stand
  (`standNamen[standId]` oder „—"). Leerzustand-Zeile „Keine Einsätze erfasst." wenn leer.
- Fußzeile mit Erstelldatum optional (klein).

### 3. Empfänger-Auflösung (testbare Util)

`core/util/event_mail_empfaenger.dart`:
```dart
/// Ein Empfänger-Vorschlag fürs Abschluss-Sheet.
typedef EmpfaengerVorschlag = ({String name, String rolle, String? email});

/// Baut Vorschläge aus (name, rolle, email)-Tripeln: nur Rollen
/// 'eventverantwortlicher' und 'rsl', Reihenfolge Eventverantwortlicher zuerst.
List<EmpfaengerVorschlag> abschlussEmpfaenger(
    List<({String name, String rolle, String? email})> kontakte);
```
- Filtert auf die beiden Rollen, sortiert Eventverantwortlicher vor RSL.
- Einträge ohne/leere E-Mail bleiben in der Liste (email == null/leer) → im Sheet ausgegraut.
- Betreff/Dateiname-Helfer ebenfalls hier (testbar):
  `String abschlussBetreff(String eventName, int jahr)` → `'Abschlussbericht $eventName $jahr'`;
  `String abschlussDateiname(String eventName, int jahr)` → bereinigt (nur `[A-Za-z0-9_-]`,
  Leerzeichen→`_`) `'Abschlussbericht_${clean}_$jahr.pdf'`.

Hinweis: Die Rollen-Slugs entsprechen den bestehenden `event_kontakte.rolle`-Werten
(E1: `eventverantwortlicher`, `rsl`, …). Beim Bau die tatsächlichen Slugs verifizieren.

### 4. Empfänger-Sheet + Versand

`presentation/screens/events/event_abschluss_sheet.dart` (ConsumerStatefulWidget, als
`showModalBottomSheet` geöffnet). Zeigt:
- **Vorgeschlagene Empfänger** (aus 3): Checkbox je Eintrag; vorangehakt wenn E-Mail vorhanden.
  Ohne E-Mail: ausgegraut + Hinweis „keine E-Mail".
- **Weitere Event-Kontakte mit E-Mail**: optionale Checkbox-Liste.
- **Freies E-Mail-Feld** + „Hinzufügen" (einfache Format-Prüfung `enthält @`).
- **Testmodus-Hinweis** wenn `!MailConfig.istScharf('event')`: „Testmodus – Versand geht an
  dich (`dani.proyer@gmail.com`)".
- Button **„Senden"** (deaktiviert wenn keine Adresse gewählt und Testmodus aus; im Testmodus
  immer sendbar).

Versand-Logik (im Sheet oder aufrufender Handler):
```dart
final gewaehlt = <String>{...ausgewaehlteEmails, ...manuelleEmails}
    .map(MailConfig.bereinige).where((e) => e.contains('@')).toList();
final to = MailConfig.istScharf('event')
    ? gewaehlt.join(', ')
    : MailConfig.testEmpfaenger;
await BerichtMailService.send(
  to: to,
  subject: abschlussBetreff(eventName, jahr),
  bodyText: _mailText(eventName),
  filename: abschlussDateiname(eventName, jahr),
  pdf: pdfBytes,
);
```
`_mailText`:
```
Guten Tag

Im Anhang der Abschlussbericht zum Event «$eventName».

Freundliche Grüsse
SBS Projer GmbH
```
Nach Erfolg: Sheet schliessen + Snackbar „Abschlussbericht gesendet" (im Testmodus:
„… (Testmodus → an dich)"). Fehler → Snackbar „Fehler beim Senden: …".

### 5. Auslöser im Event-Detail

Im bestehenden 3-Punkte-`PopupMenuButton` (AppBar `event_detail_screen.dart`) neuer Eintrag
**„Abschluss-Mail senden"**. Handler:
1. Daten laden: `eventStaendeProvider`, je Stand `EventStandAnlageRepository.getByStand`,
   `eventEinsaetzeProvider`, `eventAufwaendeProvider`, `eventKontakteProvider` (+ Kontakt-E-Mails).
2. `EventAbschlussDaten` zusammenbauen (Zusammenfassung aus `inbetriebnahmeFortschritt`
   aggregiert; `EventStand.anlagenText`).
3. `pdf = await EventAbschlussPdfService.build(daten)`.
4. `showModalBottomSheet` mit `EventAbschlussSheet` (Vorschläge + Versand).

Während des Ladens ein kurzer Ladeindikator (der Bau ist schnell, aber Anlagen-Fetch pro Stand
kann mehrere Queries sein).

## Abgrenzung E5

Keine DB-Migration, kein Versand-Verlauf/-Vermerk, keine weiteren Anhänge (E2-Dokumente werden
NICHT mitgeschickt), keine Änderung an Abrechnung/Montage, keine Änderung der Edge-Function.
Kontakt-E-Mails werden nur gelesen (nicht im Sheet dauerhaft an den Kontakt gespeichert — eine
frei eingegebene Adresse gilt nur für diesen Versand).

## Technik-Risiken (verifizieren)

- **Kontakt-E-Mail-Beschaffung:** `event_kontakte` referenziert globale `kontakte` (E-Mail dort,
  oft leer). Beim Bau sicherstellen, dass die E-Mail des zugeordneten Kontakts erreichbar ist
  (ggf. über den bestehenden Kontakt-Provider/-Repository). Rollen-Slugs gegen E1 verifizieren.
- **Gmail Mehrfach-`To`:** kommaseparierte Liste im `To:`-Header ist gültig; im Testmodus wird
  ohnehin nur `testEmpfaenger` verwendet.
- **PDF-Bytes:** `build` liefert nicht-leere `Uint8List`; Umlaute im Standard-PDF-Font (Helvetica)
  ok für Text (bestehende Berichte nutzen dieselbe Basis).

## Tests & Verifikation

- Unit-Tests: `abschlussEmpfaenger` (Rollenfilter, Sortierung, fehlende E-Mail bleibt gelistet),
  `abschlussBetreff`/`abschlussDateiname` (Format, Sonderzeichen-Bereinigung), PDF-Kennzahlen
  (Total-Stunden-Summe, Anlagen-in-Betrieb-Aggregation als reine Funktion), PDF-Bau-Smoke-Test
  (Bytes.isNotEmpty).
- `flutter analyze` ohne neue Findings; alle Tests grün.
- Visueller Browser-Test (Pflicht): Menü „Abschluss-Mail senden" → Sheet zeigt Vorschläge
  (Eventverantwortlicher/RSL), Testmodus-Hinweis; Testversand → Bestätigung; empfangene Mail
  mit PDF-Anhang inhaltlich geprüft (Zusammenfassung, Stände, Zeiten, Einsätze, keine CHF).

## Deploy

Als ein Paket **v0.21.0**. Deploy-Workflow wie E1–E4 (pubspec bump, Merge nach main, gh-pages,
Cache-Bust). Danach ist das Events-Modul (E1–E5) vollständig. Scharfstellung (`eventScharf = true`)
erfolgt separat nach erfolgreichem Testversand durch den User.
