# camt-Abgleich: Bucket „Nicht zugeordnet" + manuelle Zuordnung — Design

**Datum:** 2026-06-20
**Kontext:** Folge-Enhancement zum camt-Forderungsabgleich (TP2, live v0.10.139). Bisher verwirft die forderungs-getriebene Engine jede Gutschrift, die keiner offenen Forderung zugeordnet werden kann — eingegangenes Geld wird damit unsichtbar. Dieses Design macht solche Gutschriften sichtbar und manuell zuordenbar.

## Ziel

Eine Gutschrift (Zahlungseingang) mit erkennbarem Zahler, die im Abgleich keiner offenen Forderung zugeordnet wurde, erscheint in einem neuen Bucket „Nicht zugeordnet" und kann von dort manuell einer beliebigen offenen Forderung zugeordnet (und verbucht) werden.

## Nicht im Scope

- `verbuche`-Atomarität bleibt unverändert (zeilenweise + Idempotenz-Guard wie im restlichen Code, z.B. `camt_auto_booker`). Bewusst so belassen.
- Namenlose Gutschriften (Saldovortrag, Gebühren, Zins — `effektiverZahlername == null`) werden **nicht** angezeigt.

## Engine — `lib/services/camt/forderungs_abgleich_service.dart`

`AbgleichErgebnis` erhält ein viertes Feld:

```dart
final List<CamtTransaction> unbekannteGutschriften;
```

**Befüllung:** alle Gutschriften mit `isCredit == true` und brauchbarem `effektiverZahlername(...)`, die nach dem Matching **weder** in einem `AutoTreffer` (`auto`) **noch** in einem `ManuellFall` (`manuell`) enthalten sind. Vergleich über Objekt-Identität (dieselbe `CamtTransaction`-Instanz fliesst durch).

Das deckt genau die drei bisher verworfenen Fälle ab:
1. benannte Gutschrift ohne Betrieb-Match,
2. Gutschrift zu einem Betrieb ohne offene Forderung,
3. Rest-Gutschrift, nachdem alle Forderungen des Betriebs auto-gematcht wurden (offen leer).

Namenlose Gutschriften bleiben aussen vor (kein Eintrag in `unbekannteGutschriften`).

**Tests** (`test/forderungs_abgleich_service_test.dart`, bestehende 9 bleiben grün):
- benannte Gutschrift ohne Betrieb-Match → in `unbekannteGutschriften`, `keineZahlung` enthält weiter die offene Forderung.
- Betrieb ohne offene Forderung, Gutschrift vorhanden → in `unbekannteGutschriften`.
- nach Auto-Match (Forderungen leer), Rest-Gutschrift → in `unbekannteGutschriften`.
- namenlose Gutschrift (z.B. „Saldovortrag") → **nicht** in `unbekannteGutschriften`.
- bereits zugeordnete (auto/manuell) Gutschriften → **nicht** doppelt in `unbekannteGutschriften`.

## Screen — `lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart`

**Zusätzlicher State** (beim Upload in `_waehleDatei` befüllt):
- `List<Rechnung> _alleOffenen` — alle offenen Kundenrechnungen (Auswahlpool).
- `Map<String,String> _betriebName` — id→Name (Anzeige im Auswahl-Dialog).

**4. Ergebnis-Gruppe** „⚪ Nicht zugeordnet (N)": pro Gutschrift ein `ListTile` mit `Betrag · Datum · Zahlername` (`effektiverZahlername`), `trailing: chevron`, `onTap` → Zuordnungs-Dialog.

**Zuordnungs-Dialog** (`StatefulBuilder`):
- Such-`TextField`: filtert die offenen Forderungen nach Rechnungsnummer **oder** Betrieb-Name (wichtig bei ~1000 offenen).
- Scrollbare Mehrfachauswahl (`CheckboxListTile`) der gefilterten offenen Forderungen (Label: `Rechnungsnummer · Betrieb · Betrag`).
- Live-Summen + 5-Rappen-Differenz mit Hinweis 3805 (Unterzahlung) / 8000 (Mehrzahlung) — identische Logik/Wortlaut wie der bestehende 🟡-Dialog (`_oeffneManuell`).
- „Verbuchen" aktiv ab ≥1 gewählter Forderung → `ForderungsAbgleichService.verbuche(zahlbetrag: g.amount, datum: g.bookingDate, forderungen: gewählte)`.
- Nach Erfolg: Gutschrift aus `_ergebnis.unbekannteGutschriften` entfernen; gebuchte Forderungen aus `_alleOffenen` und aus der 🔴-Liste (`keineZahlung`) entfernen; `rechnungenStreamProvider` + `buchungenStreamProvider` invalidieren; Erfolgs-SnackBar. `mounted`/`ctx.mounted`-Guards + try/catch mit Fehler-SnackBar wie in den bestehenden Dialogen.

**Konsistenz-Bonus:** Im bestehenden 🟡-Dialog (`_oeffneManuell`) wandert eine nach dem Verbuchen übrig gebliebene Gutschrift eines vollständig abgearbeiteten Falls künftig in `_ergebnis.unbekannteGutschriften` (statt unsichtbar zu verschwinden).

## Risiken / Hinweise

- Auswahlpool `_alleOffenen` ist ein Snapshot vom Upload-Zeitpunkt; bereits in dieser Sitzung verbuchte Forderungen werden lokal aus dem Pool entfernt, damit sie nicht doppelt gewählt werden. Der bestehende Idempotenz-Guard in `verbuchenSammel` schützt zusätzlich gegen Doppelbuchung.
- Reine Engine-Änderung ist additiv (viertes Feld) — bestehende Aufrufer/Tests bleiben kompatibel.
