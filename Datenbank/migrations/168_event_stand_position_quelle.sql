-- 168_event_stand_position_quelle.sql
-- Event-Stände: Woher stammt die Position?
--
-- Bisher gab es nur latitude/longitude, gesetzt ausschliesslich per «Standort
-- erfassen» (GPS) vor Ort. Neu lässt sich die Position auch am PC auf der
-- Karte setzen — als Planung vor dem Anlass. Damit im Feld nichts stillschweigend
-- überschrieben wird, merkt sich der Stand, woher seine Koordinaten kommen:
--
--   'karte' = am PC auf der Karte gesetzt (geplant)
--   'gps'   = im Feld gemessen und bestätigt (gilt als Realität)
--
-- Entscheid Daniel 11.08.2026: EIN Koordinatenpaar, keine zwei. Beim Erfassen
-- im Feld kommt eine Rückfrage mit Kartenanzeige und Distanz; nach der
-- Übernahme gilt der gemessene Standort. Er wird auch ins Folgejahr
-- übernommen — bei Standverschiebungen wird per Karte oder GPS neu erfasst.

alter table event_staende add column position_quelle text
  check (position_quelle in ('karte', 'gps'));
alter table event_staende add column position_erfasst_am timestamptz;

-- Bestandsdaten: Alle bisherigen Koordinaten stammen aus «Standort erfassen».
update event_staende
set position_quelle = 'gps',
    position_erfasst_am = coalesce(updated_at, created_at)
where latitude is not null and longitude is not null;

comment on column event_staende.position_quelle is
  '''karte'' = am PC geplant, ''gps'' = im Feld gemessen und bestaetigt. NULL = keine Position erfasst.';
comment on column event_staende.position_erfasst_am is
  'Wann die aktuelle Position gesetzt wurde (Karte oder GPS-Uebernahme).';
