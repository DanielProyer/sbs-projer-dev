-- Migration 065: Anlage-Status "demontiert" hinzufügen
-- Equipment wurde abgebaut (Demontage durch Techniker)

ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_status_check;
ALTER TABLE anlagen ADD CONSTRAINT anlagen_status_check
  CHECK (status IN ('aktiv', 'inaktiv', 'stillgelegt', 'demontiert'));
