-- Rollback der Fahrzeit-Bereinigung vom 30.07.2026
--
-- Bereinigt wurden 652 beobachtete Fahrzeiten, die mehr als doppelt so hoch
-- lagen wie die tatsächliche Route (Störung/Pause/Terminwartezeit zwischen
-- zwei Reinigungen). Sie stehen jetzt auf `referenz_minuten + 5` mit
-- quelle='route', anzahl=0.
--
-- Die Originalwerte liegen vollständig in import.fahrzeiten_vor_bereinigung_2026_07_30.

update fahrzeiten f
   set minuten = s.minuten,
       quelle  = s.quelle,
       anzahl  = s.anzahl
  from import.fahrzeiten_vor_bereinigung_2026_07_30 s
 where f.user_id = s.user_id
   and f.von_betrieb_id = s.von_betrieb_id
   and f.nach_betrieb_id = s.nach_betrieb_id;

-- Kontrolle: muss wieder 652 beobachtete Werte über der Plausibilitätsgrenze
-- zeigen.
select count(*) as wiederhergestellt
  from fahrzeiten f
  join import.fahrzeiten_vor_bereinigung_2026_07_30 s
    on f.user_id = s.user_id
   and f.von_betrieb_id = s.von_betrieb_id
   and f.nach_betrieb_id = s.nach_betrieb_id
 where f.minuten = s.minuten;
