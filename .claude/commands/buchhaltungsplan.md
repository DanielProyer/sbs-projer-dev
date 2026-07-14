---
description: Buchhaltungs-Reparaturplan (Voll-Übernahme) anzeigen und Schritt für Schritt durchgehen
---

Der User ruft den **Buchhaltungsplan** auf (Voll-Übernahme der Buchhaltung in die App).

Gehe so vor:

1. **Plan lesen:** Lies `docs/buchhaltung/buchhaltungsplan-voll-uebernahme.md` vollständig. Das ist die Quelle der Wahrheit (Phasen 0–6, Zahlen, Reihenfolge). Bei Bedarf für Details: Memory `buchhaltung_vollcheck_2026_07.md`.

2. **Aktuellen DB-Stand prüfen** (nur lesend), um zu erkennen, welche Schritte schon erledigt sind. Nützliche Checks via `mcp__89aefffc-1b8f-49f0-bba3-d12719c19ae5__execute_sql` (project_id `pltbaqqwpnmdajwgnhpd`):
   - Phase 1 erledigt? → `SELECT COUNT(*), SUM(betrag_brutto) FROM buchungen WHERE soll_konto=1020 AND datum BETWEEN '2025-12-01' AND '2026-03-11' AND NOT ist_storniert;` (Ziel: ~220 Zeilen / 55'191.70) sowie Bank-Saldo bis 11.03. (Soll: +3'322.26).
   - Phase 2 erledigt? → `SELECT COUNT(*) FROM buchungen WHERE camt_tx_key IS NOT NULL;` und `SELECT COUNT(*) FILTER (WHERE beleg_typ='zahlung') FROM buchungen;` (>0 = camt läuft) + `SELECT status, COUNT(*) FROM camt_pruefliste GROUP BY status;`
   - Phase 3? → `SELECT COUNT(*) FROM rechnungen WHERE rechnungsdatum >= '2025-12-01' AND zahlungsstatus IN ('offen','gesendet');`
   - Phase 0/Testdaten? → `SELECT COUNT(*) FROM camt_dateien;` (9 = Testdaten noch da).
   Passe die Queries an, wenn der Plan sich weiterentwickelt hat.

3. **Status-Tabelle zeigen:** Gib den Plan phasenweise wieder (Phase 0–6) mit ✅/🟡/⬜ je nachdem, was die DB-Checks ergeben. Kurz und übersichtlich, nicht die ganze Datei kopieren — die wichtigsten Schritte + Beträge + wo wir stehen.

4. **Nächsten Schritt vorschlagen:** Nenne den ersten nicht erledigten Schritt und frage Daniel, ob wir den jetzt angehen. Beachte die Vorbedingungen: Phase 1 startet erst, wenn Daniel den camt-Test gemacht + Testdaten gelöscht + den frischen Export 12.03.→heute gezogen hat (Phase 0).

**Wichtige Regeln:**
- **Keine schreibende Buchung / kein Löschen ohne ausdrückliche Freigabe.** Immer erst zeigen, was passieren würde (Zahlen, betroffene Zeilen), dann fragen, dann ausführen.
- Buchungen im Format des jeweiligen Live-Services (Bruttomethode; siehe `heineken_buchung_service.dart` / `reinigung_buchung_service.dart`), verknüpft und idempotent.
- Nach jedem ausgeführten Schritt: verifizieren (Salden/Anzahl) und den Haken in `docs/buchhaltung/buchhaltungsplan-voll-uebernahme.md` setzen (Datei aktualisieren) + „Aktueller Stand" oben anpassen.

$ARGUMENTS
