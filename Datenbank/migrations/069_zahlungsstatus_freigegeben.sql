-- Migration 069: Status 'freigegeben' für Heineken-Workflow
-- Erweitert den CHECK Constraint um den neuen Status 'freigegeben'
-- (zwischen 'versendet' und 'bezahlt' im Heineken-Rechnungsworkflow)

ALTER TABLE rechnungen DROP CONSTRAINT IF EXISTS rechnungen_zahlungsstatus_check;
ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_zahlungsstatus_check
  CHECK (zahlungsstatus IN (
    'entwurf', 'offen', 'versendet', 'freigegeben',
    'teilbezahlt', 'bezahlt', 'ueberfaellig', 'storniert'
  ));
