-- Migration 024: Öffnungszeiten-Daten aus Google-Recherche (Stand März 2026)
-- Betrifft: Chur, Davos, Arosa, Flims, Laax, Lenzerheide
-- Hinweis: Zeiten können saisonal variieren (insbesondere Bergrestaurants)

-- ============================================================
-- CHUR (11 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"00:00"}],"Di":[{"von":"16:00","bis":"00:00"}],"Mi":[{"von":"16:00","bis":"00:00"}],"Do":[{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"16:00","bis":"01:00"}],"Sa":[{"von":"16:00","bis":"01:00"}],"So":[]}'::jsonb
WHERE name = 'Hemingway' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"22:30"}],"Di":[{"von":"08:30","bis":"22:30"}],"Mi":[{"von":"08:30","bis":"22:30"}],"Do":[{"von":"08:30","bis":"22:30"}],"Fr":[{"von":"08:30","bis":"22:30"}],"Sa":[{"von":"08:30","bis":"22:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Rätushof' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"16:00","bis":"23:00"}],"Do":[{"von":"16:00","bis":"23:00"}],"Fr":[{"von":"16:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"23:00"}],"So":[{"von":"11:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Jamies' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"00:00"}],"Sa":[{"von":"09:00","bis":"00:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Calanda' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:30","bis":"00:00"}],"Di":[{"von":"17:30","bis":"00:00"}],"Mi":[{"von":"17:30","bis":"00:00"}],"Do":[{"von":"17:30","bis":"00:00"}],"Fr":[{"von":"17:30","bis":"01:00"}],"Sa":[{"von":"17:30","bis":"01:00"}],"So":[]}'::jsonb
WHERE name = 'Confetti' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"00:00"}],"Di":[{"von":"09:00","bis":"00:00"}],"Mi":[{"von":"09:00","bis":"00:00"}],"Do":[{"von":"09:00","bis":"00:00"}],"Fr":[{"von":"09:00","bis":"01:00"}],"Sa":[{"von":"09:00","bis":"01:00"}],"So":[{"von":"13:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Street Cafe' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"00:00"}],"Di":[{"von":"10:00","bis":"00:00"}],"Mi":[{"von":"10:00","bis":"00:00"}],"Do":[{"von":"10:00","bis":"00:00"}],"Fr":[{"von":"10:00","bis":"00:00"}],"Sa":[{"von":"10:00","bis":"00:00"}],"So":[{"von":"10:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Barbar' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Di":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Mi":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Do":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Fr":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Sa":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Marsöl' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"22:00"}],"Di":[{"von":"07:00","bis":"22:00"}],"Mi":[{"von":"07:00","bis":"22:00"}],"Do":[{"von":"07:00","bis":"22:00"}],"Fr":[{"von":"07:00","bis":"22:00"}],"Sa":[{"von":"07:00","bis":"22:00"}],"So":[{"von":"07:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Franziskaner' AND ort = 'Chur';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:15","bis":"19:00"}],"Di":[{"von":"08:15","bis":"19:00"}],"Mi":[{"von":"08:15","bis":"19:00"}],"Do":[{"von":"08:15","bis":"20:00"}],"Fr":[{"von":"08:15","bis":"20:00"}],"Sa":[{"von":"08:15","bis":"17:00"}],"So":[]}'::jsonb
WHERE name = 'Giger Bar' AND ort = 'Chur';

-- Nicht gefunden: Nikki, Gambrinus, Maluna, Palazzo, Padrino

-- ============================================================
-- DAVOS (15 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[],"Do":[{"von":"11:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Mühle' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"22:00"}],"Di":[{"von":"18:00","bis":"22:00"}],"Mi":[{"von":"18:00","bis":"22:00"}],"Do":[{"von":"18:00","bis":"22:00"}],"Fr":[{"von":"18:00","bis":"22:00"}],"Sa":[{"von":"18:00","bis":"22:00"}],"So":[{"von":"18:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Parsenn' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Gemsli' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:30"}],"Di":[{"von":"08:30","bis":"16:30"}],"Mi":[{"von":"08:30","bis":"16:30"}],"Do":[{"von":"08:30","bis":"16:30"}],"Fr":[{"von":"08:30","bis":"16:30"}],"Sa":[{"von":"08:30","bis":"16:30"}],"So":[{"von":"08:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Weissfluhjoch' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:30"}],"Di":[{"von":"09:00","bis":"16:30"}],"Mi":[{"von":"09:00","bis":"16:30"}],"Do":[{"von":"09:00","bis":"16:30"}],"Fr":[{"von":"09:00","bis":"16:30"}],"Sa":[{"von":"09:00","bis":"16:30"}],"So":[{"von":"09:00","bis":"16:30"}]}'::jsonb
WHERE name = 'Höhenweg' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"15:30","bis":"00:00"}],"Do":[{"von":"15:30","bis":"00:00"}],"Fr":[{"von":"15:30","bis":"00:00"}],"Sa":[{"von":"15:30","bis":"00:00"}],"So":[{"von":"15:30","bis":"00:00"}]}'::jsonb
WHERE name = 'Montana Stube' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"22:00"}],"Di":[{"von":"18:00","bis":"22:00"}],"Mi":[{"von":"18:00","bis":"22:00"}],"Do":[{"von":"18:00","bis":"22:00"}],"Fr":[{"von":"18:00","bis":"22:00"}],"Sa":[{"von":"18:00","bis":"22:00"}],"So":[{"von":"18:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Pöstli' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"21:30"}],"Di":[{"von":"18:00","bis":"21:30"}],"Mi":[{"von":"18:00","bis":"21:30"}],"Do":[{"von":"18:00","bis":"21:30"}],"Fr":[{"von":"18:00","bis":"21:30"}],"Sa":[{"von":"18:00","bis":"21:30"}],"So":[{"von":"18:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Edelweiss' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[],"Do":[{"von":"21:00","bis":"04:00"}],"Fr":[{"von":"21:00","bis":"04:00"}],"Sa":[{"von":"21:00","bis":"04:00"}],"So":[]}'::jsonb
WHERE name = 'Bolgenschanze' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"21:30"}],"Di":[{"von":"07:00","bis":"21:30"}],"Mi":[{"von":"07:00","bis":"21:30"}],"Do":[{"von":"07:00","bis":"21:30"}],"Fr":[{"von":"07:00","bis":"21:30"}],"Sa":[{"von":"07:00","bis":"21:30"}],"So":[{"von":"07:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Chesa Grischuna' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:30","bis":"21:30"}],"Di":[{"von":"11:00","bis":"13:30"},{"von":"17:30","bis":"21:30"}],"Mi":[{"von":"11:00","bis":"13:30"},{"von":"17:30","bis":"21:30"}],"Do":[{"von":"11:00","bis":"13:30"},{"von":"17:30","bis":"21:30"}],"Fr":[{"von":"11:00","bis":"13:30"},{"von":"17:30","bis":"21:30"}],"Sa":[{"von":"11:00","bis":"13:30"},{"von":"17:30","bis":"21:30"}],"So":[{"von":"11:00","bis":"13:30"}]}'::jsonb
WHERE name = 'Dischma' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:00","bis":"01:00"}],"Di":[{"von":"17:00","bis":"01:00"}],"Mi":[{"von":"17:00","bis":"01:00"}],"Do":[{"von":"17:00","bis":"01:00"}],"Fr":[{"von":"17:00","bis":"05:00"}],"Sa":[{"von":"17:00","bis":"05:00"}],"So":[{"von":"17:00","bis":"01:00"}]}'::jsonb
WHERE name = 'Ex Bar' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"19:00"}],"Di":[{"von":"07:30","bis":"19:00"}],"Mi":[{"von":"07:30","bis":"19:00"}],"Do":[{"von":"07:30","bis":"19:00"}],"Fr":[{"von":"07:30","bis":"19:00"}],"Sa":[{"von":"07:30","bis":"19:00"}],"So":[{"von":"07:30","bis":"19:00"}]}'::jsonb
WHERE name = 'Kaffee Klatsch' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"16:30","bis":"23:30"}],"Mi":[{"von":"16:30","bis":"23:30"}],"Do":[{"von":"16:30","bis":"23:30"}],"Fr":[{"von":"16:30","bis":"23:30"}],"Sa":[{"von":"16:30","bis":"23:30"}],"So":[]}'::jsonb
WHERE name ILIKE '%Angelo%' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"19:00"}],"Di":[{"von":"06:00","bis":"19:00"}],"Mi":[{"von":"06:00","bis":"19:00"}],"Do":[{"von":"06:00","bis":"19:00"}],"Fr":[{"von":"06:00","bis":"19:00"}],"Sa":[{"von":"06:00","bis":"19:00"}],"So":[{"von":"06:00","bis":"19:00"}]}'::jsonb
WHERE name = 'Weber' AND ort = 'Davos';

-- ============================================================
-- AROSA (14 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"00:00"}],"Di":[{"von":"09:00","bis":"00:00"}],"Mi":[],"Do":[{"von":"09:00","bis":"00:00"}],"Fr":[{"von":"09:00","bis":"00:00"}],"Sa":[{"von":"10:00","bis":"00:00"}],"So":[{"von":"10:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Brüggli' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"21:30"}],"Di":[],"Mi":[{"von":"18:00","bis":"21:30"}],"Do":[{"von":"18:00","bis":"21:30"}],"Fr":[{"von":"18:00","bis":"21:30"}],"Sa":[{"von":"18:00","bis":"21:30"}],"So":[{"von":"18:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Kulm' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Gspan' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}],"Di":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"21:30"}]}'::jsonb
WHERE name = 'Vetter' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"19:00"}],"Di":[{"von":"06:00","bis":"19:00"}],"Mi":[{"von":"06:00","bis":"19:00"}],"Do":[{"von":"06:00","bis":"19:00"}],"Fr":[{"von":"06:00","bis":"19:00"}],"Sa":[{"von":"06:00","bis":"19:00"}],"So":[{"von":"07:00","bis":"19:00"}]}'::jsonb
WHERE name = 'Spettacolo' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"20:00"}],"Di":[{"von":"06:00","bis":"20:00"}],"Mi":[{"von":"06:00","bis":"20:00"}],"Do":[{"von":"06:00","bis":"20:00"}],"Fr":[{"von":"06:00","bis":"20:00"}],"Sa":[{"von":"06:00","bis":"20:00"}],"So":[{"von":"06:00","bis":"20:00"}]}'::jsonb
WHERE name = 'Pop Corn' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"04:00"}],"Di":[{"von":"18:00","bis":"04:00"}],"Mi":[{"von":"18:00","bis":"04:00"}],"Do":[{"von":"18:00","bis":"04:00"}],"Fr":[{"von":"18:00","bis":"04:00"}],"Sa":[{"von":"18:00","bis":"04:00"}],"So":[{"von":"18:00","bis":"04:00"}]}'::jsonb
WHERE name = 'Halli Galli' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"02:00"}],"Di":[{"von":"08:30","bis":"02:00"}],"Mi":[{"von":"08:30","bis":"02:00"}],"Do":[{"von":"08:30","bis":"02:00"}],"Fr":[{"von":"08:30","bis":"02:00"}],"Sa":[{"von":"08:30","bis":"02:00"}],"So":[{"von":"08:30","bis":"02:00"}]}'::jsonb
WHERE name ILIKE '%Lindemann%' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"00:00"}],"Di":[{"von":"09:00","bis":"00:00"}],"Mi":[{"von":"09:00","bis":"00:00"}],"Do":[{"von":"09:00","bis":"00:00"}],"Fr":[{"von":"09:00","bis":"00:00"}],"Sa":[{"von":"09:00","bis":"00:00"}],"So":[{"von":"09:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Grischuna' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"23:59"}],"Di":[{"von":"07:30","bis":"23:59"}],"Mi":[{"von":"07:30","bis":"23:59"}],"Do":[{"von":"07:30","bis":"23:59"}],"Fr":[{"von":"07:30","bis":"23:59"}],"Sa":[{"von":"07:30","bis":"23:59"}],"So":[{"von":"07:30","bis":"23:59"}]}'::jsonb
WHERE name = 'Hold' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Di":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Mi":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Do":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Fr":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Sa":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"So":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Alpensonne' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:30"}],"Di":[{"von":"09:00","bis":"16:30"}],"Mi":[{"von":"09:00","bis":"16:30"}],"Do":[{"von":"09:00","bis":"16:30"}],"Fr":[{"von":"09:00","bis":"16:30"}],"Sa":[{"von":"09:00","bis":"16:30"}],"So":[{"von":"09:00","bis":"16:30"}]}'::jsonb
WHERE name = 'Hörnlihütte' AND ort = 'Arosa';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Güterschuppen' AND ort = 'Arosa';

-- Nicht gefunden: Robinson (geschlossener Hotelclub)

-- ============================================================
-- FLIMS (6 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"23:00"}],"Di":[{"von":"10:00","bis":"20:00"}],"Mi":[{"von":"10:00","bis":"20:00"}],"Do":[],"Fr":[{"von":"10:00","bis":"01:00"}],"Sa":[{"von":"09:00","bis":"01:00"}],"So":[{"von":"10:00","bis":"20:00"}]}'::jsonb
WHERE name = 'Legna' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:30"}],"Di":[{"von":"08:30","bis":"16:30"}],"Mi":[{"von":"08:30","bis":"16:30"}],"Do":[{"von":"08:30","bis":"16:30"}],"Fr":[{"von":"08:30","bis":"16:30"}],"Sa":[{"von":"08:30","bis":"16:30"}],"So":[{"von":"08:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Foppa' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:30"}],"Di":[{"von":"08:30","bis":"16:30"}],"Mi":[{"von":"08:30","bis":"16:30"}],"Do":[{"von":"08:30","bis":"16:30"}],"Fr":[{"von":"08:30","bis":"16:30"}],"Sa":[{"von":"08:30","bis":"16:30"}],"So":[{"von":"08:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Ustria Startgels' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:00","bis":"21:30"}],"Di":[{"von":"17:00","bis":"21:30"}],"Mi":[],"Do":[{"von":"17:00","bis":"21:30"}],"Fr":[{"von":"17:00","bis":"21:30"}],"Sa":[{"von":"12:00","bis":"21:30"}],"So":[{"von":"12:00","bis":"21:00"}]}'::jsonb
WHERE name = 'American Burger' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}]}'::jsonb
WHERE name ILIKE '%Pomodoro%' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"18:00"}],"Di":[{"von":"10:00","bis":"18:00"}],"Mi":[{"von":"10:00","bis":"18:00"}],"Do":[{"von":"10:00","bis":"18:00"}],"Fr":[{"von":"10:00","bis":"18:00"}],"Sa":[{"von":"10:00","bis":"17:00"}],"So":[{"von":"11:00","bis":"17:00"}]}'::jsonb
WHERE name ILIKE '%Stenna%' AND ort = 'Flims';

-- Geschlossen: Iglu Bar (dauerhaft geschlossen)
-- Nicht gefunden: Piazza Flims

-- ============================================================
-- LAAX (8 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"12:00","bis":"22:00"}],"Di":[{"von":"12:00","bis":"22:00"}],"Mi":[],"Do":[],"Fr":[{"von":"12:00","bis":"22:00"}],"Sa":[{"von":"12:00","bis":"22:00"}],"So":[{"von":"12:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Il Pub' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:30"}],"Di":[{"von":"08:30","bis":"16:30"}],"Mi":[{"von":"08:30","bis":"16:30"}],"Do":[{"von":"08:30","bis":"16:30"}],"Fr":[{"von":"08:30","bis":"16:30"}],"Sa":[{"von":"08:30","bis":"16:30"}],"So":[{"von":"08:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Crap Sogn Gion' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"12:00","bis":"13:30"},{"von":"18:00","bis":"21:00"}],"Di":[{"von":"12:00","bis":"13:30"},{"von":"18:00","bis":"21:00"}],"Mi":[{"von":"12:00","bis":"13:30"},{"von":"18:00","bis":"21:00"}],"Do":[{"von":"12:00","bis":"13:30"},{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"12:00","bis":"13:30"},{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"12:00","bis":"13:30"},{"von":"18:00","bis":"21:00"}],"So":[{"von":"12:00","bis":"13:30"}]}'::jsonb
WHERE name = 'Signina' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"22:00"}],"Di":[{"von":"10:00","bis":"22:00"}],"Mi":[{"von":"10:00","bis":"22:00"}],"Do":[{"von":"10:00","bis":"22:00"}],"Fr":[{"von":"10:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"18:00"}]}'::jsonb
WHERE name = 'Tegia Larnags' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:30","bis":"21:00"}],"Di":[{"von":"17:30","bis":"21:00"}],"Mi":[{"von":"17:30","bis":"21:00"}],"Do":[{"von":"17:30","bis":"21:00"}],"Fr":[{"von":"12:00","bis":"13:30"},{"von":"17:30","bis":"21:00"}],"Sa":[{"von":"12:00","bis":"13:30"},{"von":"17:30","bis":"21:00"}],"So":[{"von":"12:00","bis":"13:30"},{"von":"17:30","bis":"21:00"}]}'::jsonb
WHERE name = 'IKIGAI' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"14:00","bis":"00:00"}],"Di":[{"von":"14:00","bis":"00:00"}],"Mi":[{"von":"14:00","bis":"00:00"}],"Do":[{"von":"14:00","bis":"00:00"}],"Fr":[{"von":"14:00","bis":"02:00"}],"Sa":[{"von":"14:00","bis":"02:00"}],"So":[{"von":"14:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Indy Bar' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"12:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Di":[{"von":"12:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Mi":[{"von":"12:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Do":[{"von":"12:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Fr":[{"von":"12:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Sa":[{"von":"12:00","bis":"22:00"}],"So":[{"von":"12:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Nooba' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"18:00","bis":"21:00"}],"Mi":[{"von":"18:00","bis":"21:00"}],"Do":[{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"18:00","bis":"21:00"}],"So":[]}'::jsonb
WHERE name ILIKE '%Riders%' AND ort = 'Laax';

-- ============================================================
-- LENZERHEIDE (7 Betriebe, 1 geschlossen)
-- ============================================================

-- Forellenstube: seit 03.03.2025 geschlossen bis auf weiteres

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"22:00"}],"Di":[{"von":"07:30","bis":"22:00"}],"Mi":[{"von":"07:30","bis":"22:00"}],"Do":[{"von":"07:30","bis":"22:00"}],"Fr":[{"von":"07:30","bis":"22:00"}],"Sa":[{"von":"07:30","bis":"22:00"}],"So":[{"von":"07:30","bis":"22:00"}]}'::jsonb
WHERE name = 'Dieschen' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"21:30"}],"Di":[{"von":"11:00","bis":"21:30"}],"Mi":[{"von":"11:00","bis":"21:30"}],"Do":[{"von":"11:00","bis":"21:30"}],"Fr":[{"von":"11:00","bis":"21:30"}],"Sa":[{"von":"11:00","bis":"21:30"}],"So":[{"von":"11:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Spescha' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"22:30"}],"Di":[{"von":"11:30","bis":"22:30"}],"Mi":[{"von":"11:30","bis":"22:30"}],"Do":[{"von":"11:30","bis":"22:30"}],"Fr":[{"von":"11:30","bis":"22:30"}],"Sa":[{"von":"11:30","bis":"22:30"}],"So":[{"von":"11:30","bis":"22:30"}]}'::jsonb
WHERE name = 'Sunstar' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"21:30"}],"Di":[{"von":"11:00","bis":"21:30"}],"Mi":[{"von":"11:00","bis":"21:30"}],"Do":[{"von":"11:00","bis":"21:30"}],"Fr":[{"von":"11:00","bis":"21:30"}],"Sa":[{"von":"11:00","bis":"21:30"}],"So":[{"von":"11:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Lenzerhorn' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:30"}],"Di":[{"von":"08:30","bis":"16:30"}],"Mi":[{"von":"08:30","bis":"16:30"}],"Do":[{"von":"08:30","bis":"16:30"}],"Fr":[{"von":"08:30","bis":"16:30"}],"Sa":[{"von":"08:30","bis":"16:30"}],"So":[{"von":"08:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Alp Lavoz' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"17:00"}],"Di":[{"von":"08:00","bis":"17:00"}],"Mi":[{"von":"08:00","bis":"17:00"}],"Do":[{"von":"08:00","bis":"17:00"}],"Fr":[{"von":"08:00","bis":"17:00"}],"Sa":[{"von":"08:00","bis":"17:00"}],"So":[{"von":"08:00","bis":"17:00"}]}'::jsonb
WHERE name ILIKE '%Biathlon%' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"12:00","bis":"14:00"},{"von":"18:30","bis":"21:30"}],"Do":[{"von":"12:00","bis":"14:00"},{"von":"18:30","bis":"21:30"}],"Fr":[{"von":"12:00","bis":"14:00"},{"von":"18:30","bis":"21:30"}],"Sa":[{"von":"12:00","bis":"14:00"},{"von":"18:30","bis":"21:30"}],"So":[{"von":"12:00","bis":"14:00"},{"von":"18:30","bis":"21:30"}]}'::jsonb
WHERE name = 'Guarda Val' AND ort = 'Lenzerheide';

-- ============================================================
-- KLOSTERS / PRÄTTIGAU (8 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"22:00"}],"Di":[{"von":"07:30","bis":"22:00"}],"Mi":[{"von":"07:30","bis":"22:00"}],"Do":[{"von":"07:30","bis":"22:00"}],"Fr":[{"von":"07:30","bis":"22:00"}],"Sa":[{"von":"07:30","bis":"22:00"}],"So":[{"von":"07:30","bis":"22:00"}]}'::jsonb
WHERE name = 'Sunstar' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:30","bis":"23:00"}],"Do":[{"von":"17:30","bis":"23:00"}],"Fr":[{"von":"17:30","bis":"23:00"}],"Sa":[{"von":"17:30","bis":"23:00"}],"So":[{"von":"17:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Bargis' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"12:00","bis":"21:30"}],"Di":[{"von":"12:00","bis":"21:30"}],"Mi":[{"von":"12:00","bis":"21:30"}],"Do":[{"von":"12:00","bis":"21:30"}],"Fr":[{"von":"12:00","bis":"21:30"}],"Sa":[{"von":"12:00","bis":"21:30"}],"So":[{"von":"12:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Sport' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"21:30"}],"Di":[{"von":"07:00","bis":"21:30"}],"Mi":[{"von":"07:00","bis":"21:30"}],"Do":[{"von":"07:00","bis":"21:30"}],"Fr":[{"von":"07:00","bis":"21:30"}],"Sa":[{"von":"07:00","bis":"21:30"}],"So":[{"von":"07:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Alpina' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:00","bis":"00:00"}],"Di":[{"von":"17:00","bis":"00:00"}],"Mi":[{"von":"17:00","bis":"00:00"}],"Do":[{"von":"17:00","bis":"00:00"}],"Fr":[{"von":"17:00","bis":"00:00"}],"Sa":[{"von":"17:00","bis":"00:00"}],"So":[{"von":"17:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Wynegg' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"16:00","bis":"00:00"}],"Mi":[{"von":"16:00","bis":"00:00"}],"Do":[{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"16:00","bis":"00:00"}],"Sa":[{"von":"16:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name = 'Sonne' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:30","bis":"20:00"}],"Di":[{"von":"18:30","bis":"20:00"}],"Mi":[{"von":"18:30","bis":"20:00"}],"Do":[{"von":"18:30","bis":"20:00"}],"Fr":[{"von":"18:30","bis":"20:00"}],"Sa":[{"von":"18:30","bis":"20:00"}],"So":[{"von":"18:30","bis":"20:00"}]}'::jsonb
WHERE name = 'Madrisa Lodge' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"23:00"}],"Di":[{"von":"06:00","bis":"23:00"}],"Mi":[{"von":"06:00","bis":"23:00"}],"Do":[{"von":"06:00","bis":"23:00"}],"Fr":[{"von":"06:00","bis":"23:00"}],"Sa":[{"von":"06:00","bis":"23:00"}],"So":[{"von":"06:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Alpina' AND ort = 'Schiers';

-- Nicht eindeutig: Skihütte Selfranga, Hirschen Küblis

-- ============================================================
-- VALBELLA / CHURWALDEN / SAVOGNIN / PARPAN (9 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"21:30"}],"Di":[{"von":"09:00","bis":"21:30"}],"Mi":[{"von":"09:00","bis":"21:30"}],"Do":[{"von":"09:00","bis":"21:30"}],"Fr":[{"von":"09:00","bis":"21:30"}],"Sa":[{"von":"09:00","bis":"21:30"}],"So":[{"von":"09:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Waldhaus' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:15","bis":"22:00"}],"Di":[{"von":"07:15","bis":"22:00"}],"Mi":[{"von":"07:15","bis":"22:00"}],"Do":[{"von":"07:15","bis":"22:00"}],"Fr":[{"von":"07:15","bis":"22:00"}],"Sa":[{"von":"07:15","bis":"22:00"}],"So":[{"von":"07:15","bis":"22:00"}]}'::jsonb
WHERE name = 'Valbella Inn' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"23:00"}],"Di":[{"von":"11:30","bis":"23:00"}],"Mi":[{"von":"11:30","bis":"23:00"}],"Do":[{"von":"11:30","bis":"23:00"}],"Fr":[{"von":"11:30","bis":"23:00"}],"Sa":[{"von":"17:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name ILIKE '%Buscadero%' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:45","bis":"22:00"}],"Di":[{"von":"08:45","bis":"22:00"}],"Mi":[{"von":"08:45","bis":"22:00"}],"Do":[{"von":"08:45","bis":"22:00"}],"Fr":[{"von":"08:45","bis":"22:00"}],"Sa":[{"von":"08:45","bis":"22:00"}],"So":[{"von":"08:45","bis":"22:00"}]}'::jsonb
WHERE name = 'Pradaschier' AND ort = 'Churwalden';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"17:00"}],"Di":[{"von":"09:00","bis":"17:00"}],"Mi":[{"von":"09:00","bis":"17:00"}],"Do":[{"von":"09:00","bis":"17:00"}],"Fr":[{"von":"09:00","bis":"17:00"}],"Sa":[{"von":"09:00","bis":"17:00"}],"So":[{"von":"09:00","bis":"17:00"}]}'::jsonb
WHERE name ILIKE '%Alp St_tz%' AND ort = 'Churwalden';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"21:00"}],"Di":[{"von":"07:30","bis":"21:00"}],"Mi":[{"von":"07:30","bis":"21:00"}],"Do":[{"von":"07:30","bis":"21:00"}],"Fr":[{"von":"07:30","bis":"21:00"}],"Sa":[{"von":"07:30","bis":"21:00"}],"So":[{"von":"07:30","bis":"21:00"}]}'::jsonb
WHERE name = 'Krone' AND ort = 'Churwalden';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE '%t_zerhorn%' AND ort = 'Parpan';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Radons' AND ort = 'Savognin';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:00"}],"Di":[{"von":"09:00","bis":"16:00"}],"Mi":[{"von":"09:00","bis":"16:00"}],"Do":[{"von":"09:00","bis":"16:00"}],"Fr":[{"von":"09:00","bis":"16:00"}],"Sa":[{"von":"09:00","bis":"16:00"}],"So":[{"von":"09:00","bis":"16:00"}]}'::jsonb
WHERE name = 'Somtgant' AND ort = 'Savognin';

-- Nicht gefunden: Romana Savognin

-- ============================================================
-- SURSELVA (8 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE '%Alte B_ndnerstube%' AND ort = 'Disentis/Muster';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"21:00"}],"Di":[{"von":"18:00","bis":"21:00"}],"Mi":[{"von":"18:00","bis":"21:00"}],"Do":[{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"18:00","bis":"21:00"}],"So":[]}'::jsonb
WHERE name = 'Catrina' AND ort = 'Disentis/Muster';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"21:00"}],"Di":[{"von":"09:00","bis":"21:00"}],"Mi":[{"von":"09:00","bis":"21:00"}],"Do":[{"von":"09:00","bis":"21:00"}],"Fr":[{"von":"09:00","bis":"21:00"}],"Sa":[{"von":"09:00","bis":"21:00"}],"So":[{"von":"09:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Stiva Ursus' AND ort = 'Disentis/Muster';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Mi":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Do":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"So":[]}'::jsonb
WHERE name = 'Soliva' AND ort = 'Sedrun';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"00:00"}],"Di":[{"von":"08:30","bis":"00:00"}],"Mi":[{"von":"08:30","bis":"00:00"}],"Do":[{"von":"08:30","bis":"00:00"}],"Fr":[{"von":"08:30","bis":"00:00"}],"Sa":[{"von":"08:30","bis":"00:00"}],"So":[{"von":"08:30","bis":"00:00"}]}'::jsonb
WHERE name = 'Cruna' AND ort = 'Sedrun';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"21:00"}],"Di":[{"von":"08:00","bis":"21:00"}],"Mi":[{"von":"08:00","bis":"21:00"}],"Do":[{"von":"08:00","bis":"21:00"}],"Fr":[{"von":"08:00","bis":"21:00"}],"Sa":[{"von":"08:00","bis":"21:00"}],"So":[{"von":"08:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Kistenpass' AND ort = 'Brigels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"23:00"}],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE 'R_tia' AND ort = 'Ilanz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"21:30"}],"Di":[{"von":"18:00","bis":"21:30"}],"Mi":[{"von":"18:00","bis":"21:30"}],"Do":[{"von":"18:00","bis":"21:30"}],"Fr":[{"von":"18:00","bis":"21:30"}],"Sa":[{"von":"18:00","bis":"21:30"}],"So":[{"von":"18:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Rovanada' AND ort = 'Vals';

-- Nicht gefunden: Alpsu Disentis
-- Nicht eindeutig: Badus Sedrun, Piz Mundaun Obersaxen, Obertor Ilanz

-- ============================================================
-- THUSIS / HINTERRHEIN (9 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"20:00"}],"Di":[{"von":"08:00","bis":"20:00"}],"Mi":[{"von":"08:00","bis":"20:00"}],"Do":[{"von":"08:00","bis":"20:00"}],"Fr":[{"von":"08:00","bis":"20:00"}],"Sa":[{"von":"08:00","bis":"18:00"}],"So":[]}'::jsonb
WHERE name = 'Im Park' AND ort = 'Thusis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Mi":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Do":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Boccalino' AND ort = 'Thusis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"22:30"}],"Di":[{"von":"08:30","bis":"22:30"}],"Mi":[{"von":"08:30","bis":"22:30"}],"Do":[{"von":"08:30","bis":"22:30"}],"Fr":[{"von":"08:30","bis":"22:30"}],"Sa":[{"von":"08:30","bis":"22:30"}],"So":[{"von":"08:30","bis":"22:30"}]}'::jsonb
WHERE name = 'Bernina' AND ort = 'Thusis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Do":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"So":[{"von":"12:00","bis":"14:00"},{"von":"18:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Bodenhaus' AND ort ILIKE 'Spl_gen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Di":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Weiss Kreuz' AND ort ILIKE 'Spl_gen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"21:00"}],"Di":[{"von":"09:00","bis":"21:00"}],"Mi":[{"von":"09:00","bis":"21:00"}],"Do":[],"Fr":[{"von":"09:00","bis":"21:00"}],"Sa":[{"von":"09:00","bis":"21:00"}],"So":[{"von":"09:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Bergalga' AND ort = 'Avers';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"00:00"}],"Di":[{"von":"06:00","bis":"00:00"}],"Mi":[{"von":"06:00","bis":"00:00"}],"Do":[{"von":"06:00","bis":"00:00"}],"Fr":[{"von":"06:00","bis":"00:00"}],"Sa":[{"von":"06:00","bis":"00:00"}],"So":[{"von":"06:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Guidon' AND ort = 'Bivio';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Di":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Garni Albula' AND ort ILIKE 'Berg_n';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"18:00"}],"Do":[{"von":"09:00","bis":"18:00"}],"Fr":[{"von":"09:00","bis":"18:00"}],"Sa":[{"von":"09:00","bis":"18:00"}],"So":[{"von":"09:00","bis":"18:00"}]}'::jsonb
WHERE name = 'Alte Post' AND ort = 'Zillis';

-- Nicht gefunden: Piz Tambo Splügen, Fravi Andeer, Zur alten Brauerei Thusis

-- ============================================================
-- LANDQUART (7 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"14:00"}],"Di":[{"von":"11:30","bis":"14:00"},{"von":"16:30","bis":"22:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"16:30","bis":"22:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"16:30","bis":"22:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"16:30","bis":"22:00"}],"Sa":[{"von":"11:30","bis":"00:00"}],"So":[{"von":"11:30","bis":"00:00"}]}'::jsonb
WHERE name ILIKE 'Pinochi%' AND ort = 'Landquart';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"00:00"}],"Di":[{"von":"07:00","bis":"00:00"}],"Mi":[{"von":"07:00","bis":"00:00"}],"Do":[{"von":"07:00","bis":"00:00"}],"Fr":[{"von":"07:00","bis":"00:00"}],"Sa":[{"von":"08:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name ILIKE 'Holl_nder' AND ort = 'Landquart';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"00:00"}],"Di":[{"von":"08:00","bis":"00:00"}],"Mi":[{"von":"08:00","bis":"00:00"}],"Do":[{"von":"08:00","bis":"00:00"}],"Fr":[{"von":"08:00","bis":"00:00"}],"Sa":[{"von":"08:00","bis":"20:00"}],"So":[{"von":"08:00","bis":"20:00"}]}'::jsonb
WHERE name = 'Peppino' AND ort = 'Landquart';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:30","bis":"14:00"}],"Di":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"10:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"10:30","bis":"14:00"},{"von":"16:30","bis":"23:00"}],"Sa":[{"von":"10:30","bis":"14:00"},{"von":"16:30","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Flora' AND ort = 'Landquart';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"00:00"}],"Di":[{"von":"11:00","bis":"00:00"}],"Mi":[{"von":"11:00","bis":"00:00"}],"Do":[{"von":"11:00","bis":"00:00"}],"Fr":[{"von":"11:00","bis":"00:00"}],"Sa":[{"von":"11:00","bis":"18:00"}],"So":[]}'::jsonb
WHERE name = 'Rheinfels' AND ort = 'Landquart';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"22:30"}],"Do":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"22:30"}],"Fr":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"22:30"}],"Sa":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"22:30"}],"So":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"22:30"}]}'::jsonb
WHERE name = 'Pizzeria Ganda' AND ort = 'Landquart';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"00:00"}],"Di":[{"von":"07:00","bis":"00:00"}],"Mi":[{"von":"07:00","bis":"00:00"}],"Do":[{"von":"07:00","bis":"00:00"}],"Fr":[{"von":"07:00","bis":"00:00"}],"Sa":[{"von":"07:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name = 'Diana' AND ort = 'Landquart';

-- Nicht gefunden: Passage, Espresso Bar

-- ============================================================
-- MAIENFELD (5 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"08:00","bis":"22:00"}],"Do":[{"von":"08:00","bis":"22:00"}],"Fr":[{"von":"08:00","bis":"22:00"}],"Sa":[{"von":"08:00","bis":"22:00"}],"So":[{"von":"08:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Heidihof' AND ort = 'Maienfeld';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE '%St. Luzisteg%' AND ort = 'Maienfeld';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"23:00"}],"Di":[],"Mi":[],"Do":[{"von":"10:00","bis":"23:00"}],"Fr":[{"von":"10:00","bis":"23:00"}],"Sa":[{"von":"10:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Falknis' AND ort = 'Maienfeld';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE 'L_wen' AND ort = 'Maienfeld';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"07:30","bis":"18:30"}],"Do":[{"von":"07:30","bis":"18:30"}],"Fr":[{"von":"07:30","bis":"18:30"}],"Sa":[{"von":"07:30","bis":"18:30"}],"So":[{"von":"07:30","bis":"18:30"}]}'::jsonb
WHERE name = 'Rathaus' AND ort = 'Maienfeld';

-- Nicht gefunden: Swissheidi (keine genauen Zeiten), Weinstube, Sternen Treff

-- ============================================================
-- BAD RAGAZ (8 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"18:00"}],"Di":[{"von":"08:00","bis":"18:00"}],"Mi":[],"Do":[{"von":"08:00","bis":"22:30"}],"Fr":[{"von":"08:00","bis":"22:30"}],"Sa":[{"von":"08:00","bis":"22:30"}],"So":[{"von":"08:00","bis":"18:00"}]}'::jsonb
WHERE name = 'Bambi' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[],"Mi":[],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"21:00"}]}'::jsonb
WHERE name ILIKE 'T_rmli' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"09:00","bis":"14:00"},{"von":"18:00","bis":"00:00"}],"Mi":[{"von":"09:00","bis":"14:00"},{"von":"18:00","bis":"00:00"}],"Do":[{"von":"09:00","bis":"14:00"},{"von":"18:00","bis":"00:00"}],"Fr":[{"von":"09:00","bis":"14:00"},{"von":"18:00","bis":"00:00"}],"Sa":[{"von":"09:00","bis":"14:00"},{"von":"18:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name ILIKE 'R_ssli' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Pizzeria Paradies' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"01:00"}],"Di":[{"von":"16:00","bis":"01:00"}],"Mi":[{"von":"16:00","bis":"01:00"}],"Do":[{"von":"16:00","bis":"01:00"}],"Fr":[{"von":"16:00","bis":"02:00"}],"Sa":[{"von":"16:00","bis":"02:00"}],"So":[{"von":"16:00","bis":"01:00"}]}'::jsonb
WHERE name = 'Viola Bar' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Di":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Mi":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"17:00","bis":"22:00"}],"So":[]}'::jsonb
WHERE name = 'Ochsen' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"12:00","bis":"22:00"}],"Di":[{"von":"12:00","bis":"22:00"}],"Mi":[{"von":"12:00","bis":"22:00"}],"Do":[{"von":"12:00","bis":"23:00"}],"Fr":[{"von":"12:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"13:00"}]}'::jsonb
WHERE name = 'Tapas Bar' AND ort = 'Bad Ragaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"23:00"}],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Central' AND ort = 'Bad Ragaz';

-- Nicht gefunden: Shisha Bar, Treff (keine genauen Zeiten)

-- ============================================================
-- SARGANS (6 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Di":[],"Mi":[{"von":"11:00","bis":"13:30"},{"von":"17:00","bis":"21:45"}],"Do":[{"von":"11:00","bis":"13:30"},{"von":"17:00","bis":"21:45"}],"Fr":[{"von":"11:00","bis":"13:30"},{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"11:00","bis":"13:30"},{"von":"17:00","bis":"22:00"}],"So":[{"von":"11:00","bis":"13:45"},{"von":"17:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Ritterhof' AND ort = 'Sargans';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"22:00"}],"Di":[],"Mi":[{"von":"07:00","bis":"22:00"}],"Do":[{"von":"07:00","bis":"22:00"}],"Fr":[{"von":"07:00","bis":"22:00"}],"Sa":[{"von":"07:30","bis":"22:00"}],"So":[{"von":"07:30","bis":"22:00"}]}'::jsonb
WHERE name = 'Bahnhofbuffet' AND ort = 'Sargans';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"20:00","bis":"00:00"}],"Do":[{"von":"20:00","bis":"00:00"}],"Fr":[{"von":"20:00","bis":"01:00"}],"Sa":[{"von":"20:00","bis":"01:00"}],"So":[]}'::jsonb
WHERE name = 'Tiki Bar' AND ort = 'Sargans';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"17:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'El Gusto' AND ort = 'Sargans';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"15:00","bis":"00:00"}],"Di":[{"von":"15:00","bis":"00:00"}],"Mi":[{"von":"15:00","bis":"00:00"}],"Do":[{"von":"15:00","bis":"00:00"}],"Fr":[{"von":"15:00","bis":"02:00"}],"Sa":[{"von":"15:00","bis":"02:00"}],"So":[{"von":"15:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Indigo' AND ort = 'Sargans';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"13:00"},{"von":"17:00","bis":"21:00"}],"Di":[{"von":"11:30","bis":"13:00"},{"von":"17:00","bis":"21:00"}],"Mi":[{"von":"11:30","bis":"13:00"},{"von":"17:00","bis":"21:00"}],"Do":[{"von":"11:30","bis":"13:00"},{"von":"17:00","bis":"21:00"}],"Fr":[{"von":"11:30","bis":"13:00"},{"von":"17:00","bis":"21:00"}],"Sa":[{"von":"11:30","bis":"13:00"},{"von":"17:00","bis":"21:00"}],"So":[]}'::jsonb
WHERE name = 'Fantasie' AND ort = 'Sargans';

-- Geschlossen: Franz-Anton (Restaurant dauerhaft geschlossen)
-- Nicht eindeutig: Dancing Zur Zinne

-- ============================================================
-- DOMAT/EMS (3 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Veltlinerhalle' AND ort = 'DomatEms';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"07:00","bis":"23:00"}],"Mi":[{"von":"07:00","bis":"23:00"}],"Do":[{"von":"07:00","bis":"23:00"}],"Fr":[{"von":"07:00","bis":"23:00"}],"Sa":[{"von":"07:00","bis":"23:00"}],"So":[{"von":"07:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Sternen' AND ort = 'DomatEms';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"23:30"}],"Mi":[{"von":"08:00","bis":"23:30"}],"Do":[{"von":"08:00","bis":"23:30"}],"Fr":[{"von":"08:00","bis":"23:30"}],"Sa":[{"von":"08:00","bis":"23:30"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Term Bel' AND ort = 'DomatEms';

-- Nicht gefunden: Insieme, Golfrestaurant (Saisonbetrieb)

-- ============================================================
-- BONADUZ (4 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:00","bis":"22:00"}],"Do":[{"von":"11:00","bis":"22:00"}],"Fr":[{"von":"11:00","bis":"22:00"}],"Sa":[{"von":"11:00","bis":"22:00"}],"So":[{"von":"11:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Bongert' AND ort = 'Bonaduz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Di":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"23:00"}],"So":[{"von":"11:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Oberalp' AND ort = 'Bonaduz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:00","bis":"22:00"}],"Mi":[{"von":"11:00","bis":"22:00"}],"Do":[{"von":"11:00","bis":"22:00"}],"Fr":[{"von":"11:00","bis":"22:00"}],"Sa":[{"von":"11:00","bis":"22:00"}],"So":[]}'::jsonb
WHERE name ILIKE 'R_ssli' AND ort = 'Bonaduz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Caruso' AND ort = 'Bonaduz';

-- ============================================================
-- FELSBERG / HALDENSTEIN (3 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"23:00"}],"Di":[],"Mi":[],"Do":[{"von":"10:00","bis":"23:00"}],"Fr":[{"von":"10:00","bis":"00:00"}],"Sa":[{"von":"10:00","bis":"00:00"}],"So":[{"von":"10:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Calanda' AND ort = 'Felsberg';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"10:00","bis":"23:00"}],"Do":[{"von":"10:00","bis":"23:00"}],"Fr":[{"von":"10:00","bis":"23:00"}],"Sa":[{"von":"10:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"21:00"}]}'::jsonb
WHERE name ILIKE 'Bahnh_fli' AND ort = 'Haldenstein';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[],"So":[]}'::jsonb
WHERE name = 'Calanda' AND ort = 'Haldenstein';

-- ============================================================
-- CHAM (7 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"23:30"}],"Di":[{"von":"07:00","bis":"23:30"}],"Mi":[{"von":"07:00","bis":"23:30"}],"Do":[{"von":"07:00","bis":"23:30"}],"Fr":[{"von":"07:00","bis":"23:30"}],"Sa":[{"von":"08:00","bis":"23:30"}],"So":[{"von":"08:00","bis":"23:30"}]}'::jsonb
WHERE name = 'Sports Zugerland' AND ort = 'Cham';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Krone' AND ort = 'Cham';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:00","bis":"00:00"}],"Di":[{"von":"17:00","bis":"00:00"}],"Mi":[{"von":"17:00","bis":"00:00"}],"Do":[{"von":"17:00","bis":"00:00"}],"Fr":[{"von":"17:00","bis":"03:00"}],"Sa":[{"von":"20:00","bis":"03:00"}],"So":[]}'::jsonb
WHERE name = 'Vieri Bar' AND ort = 'Cham';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Di":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"17:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Raben' AND ort = 'Cham';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"22:30"}],"Sa":[{"von":"17:30","bis":"22:30"}],"So":[{"von":"17:30","bis":"22:30"}]}'::jsonb
WHERE name = 'Mastro Alfonso Frangipan' AND ort = 'Cham';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Di":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[],"So":[]}'::jsonb
WHERE name ILIKE 'R_ssli' AND ort = 'Cham';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"14:00"}],"Di":[{"von":"11:30","bis":"14:00"}],"Mi":[{"von":"11:30","bis":"14:00"}],"Do":[{"von":"11:30","bis":"14:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"18:00","bis":"00:00"}],"Sa":[{"von":"18:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name = 'Avis' AND ort = 'Cham';

-- Nicht gefunden: Swiss Ever (keine genauen Zeiten), Luzia (keine genauen Zeiten)

-- ============================================================
-- MELS (4 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"00:00"}],"Di":[{"von":"16:00","bis":"00:00"}],"Mi":[{"von":"16:00","bis":"00:00"}],"Do":[{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"16:00","bis":"00:00"}],"Sa":[],"So":[]}'::jsonb
WHERE name = 'Traube' AND ort = 'Mels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:30","bis":"14:30"},{"von":"18:30","bis":"23:30"}],"Do":[{"von":"11:30","bis":"14:30"},{"von":"18:30","bis":"23:30"}],"Fr":[{"von":"11:30","bis":"14:30"},{"von":"18:30","bis":"23:30"}],"Sa":[{"von":"11:30","bis":"14:30"},{"von":"18:30","bis":"23:30"}],"So":[]}'::jsonb
WHERE name ILIKE 'Schl_ssel' AND ort = 'Mels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"11:30"},{"von":"14:00","bis":"22:30"}],"Mi":[{"von":"08:00","bis":"11:30"},{"von":"14:00","bis":"22:30"}],"Do":[{"von":"08:30","bis":"11:30"},{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"08:30","bis":"11:30"},{"von":"16:00","bis":"00:00"}],"Sa":[{"von":"08:00","bis":"11:30"},{"von":"14:00","bis":"22:30"}],"So":[]}'::jsonb
WHERE name = 'Gemsli' AND ort = 'Mels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"18:00","bis":"23:00"}],"Mi":[{"von":"18:00","bis":"23:00"}],"Do":[{"von":"11:30","bis":"13:30"},{"von":"18:00","bis":"23:00"}],"Fr":[{"von":"11:30","bis":"13:30"},{"von":"18:00","bis":"23:00"}],"Sa":[{"von":"11:30","bis":"13:30"},{"von":"18:00","bis":"23:00"}],"So":[{"von":"11:30","bis":"13:30"},{"von":"18:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Casa Nostra' AND ort = 'Mels';

-- ============================================================
-- WALENSTADT (2 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"16:00","bis":"02:00"}],"Mi":[{"von":"16:00","bis":"02:00"}],"Do":[{"von":"16:00","bis":"02:00"}],"Fr":[{"von":"16:00","bis":"02:00"}],"Sa":[{"von":"16:00","bis":"02:00"}],"So":[]}'::jsonb
WHERE name = 'Bierhalle' AND ort = 'Walenstadt';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"16:00","bis":"23:30"}],"Do":[{"von":"16:00","bis":"23:30"}],"Fr":[{"von":"16:00","bis":"23:30"}],"Sa":[{"von":"11:00","bis":"23:30"}],"So":[{"von":"11:00","bis":"21:00"}]}'::jsonb
WHERE name = 'Zum Ochsen' AND ort = 'Walenstadt';

-- Nicht gefunden: Schiff

-- ============================================================
-- FLUMS / FLUMSERBERG (3 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"13:30"},{"von":"16:30","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"13:30"},{"von":"16:30","bis":"23:00"}],"Do":[{"von":"08:00","bis":"13:30"},{"von":"16:30","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"13:30"},{"von":"16:30","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"13:30"},{"von":"16:30","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Sternen' AND ort = 'Flums';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"21:00"}],"Mi":[{"von":"08:00","bis":"21:00"}],"Do":[{"von":"08:00","bis":"21:00"}],"Fr":[{"von":"08:00","bis":"21:00"}],"Sa":[{"von":"08:00","bis":"21:00"}],"So":[{"von":"08:00","bis":"18:00"}]}'::jsonb
WHERE name ILIKE 'Sch_nhalden' AND ort = 'Flumserberg';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"23:00"}],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Cresta' AND ort = 'Flumserberg';

-- Nicht gefunden: Cosa Nostra Flums (ist in Mels), Hinnastall (saisonabhängig)

-- ============================================================
-- QUARTEN / WANGS (4 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"23:00"}],"Di":[{"von":"08:30","bis":"23:00"}],"Mi":[{"von":"08:30","bis":"23:00"}],"Do":[{"von":"08:30","bis":"23:00"}],"Fr":[{"von":"08:30","bis":"23:00"}],"Sa":[{"von":"08:30","bis":"23:00"}],"So":[{"von":"08:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Don Camillo' AND ort = 'Quarten';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"23:30"}],"Di":[{"von":"08:30","bis":"00:30"}],"Mi":[],"Do":[],"Fr":[{"von":"08:30","bis":"23:30"}],"Sa":[{"von":"09:00","bis":"00:30"}],"So":[{"von":"09:00","bis":"23:30"}]}'::jsonb
WHERE name = 'Freieck' AND ort = 'Quarten';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:00","bis":"00:00"}],"Mi":[{"von":"11:00","bis":"00:00"}],"Do":[{"von":"11:00","bis":"00:00"}],"Fr":[{"von":"11:00","bis":"00:00"}],"Sa":[{"von":"11:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name = 'Blumenau' AND ort = 'Quarten';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE 'Pizolst_bli' AND ort = 'Wangs';

-- Nicht gefunden: Furt Wangs (Saisonbetrieb), Pizol Bar

-- ============================================================
-- BRIGELS (4 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"23:00"}],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"17:00"}]}'::jsonb
WHERE name = 'Vincenz' AND ort = 'Brigels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"23:00"}],"Di":[{"von":"07:30","bis":"23:00"}],"Mi":[{"von":"07:30","bis":"23:00"}],"Do":[{"von":"07:30","bis":"23:00"}],"Fr":[{"von":"07:30","bis":"23:00"}],"Sa":[{"von":"07:30","bis":"23:00"}],"So":[{"von":"07:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Alpina' AND ort = 'Brigels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"22:00"}],"Di":[{"von":"18:00","bis":"22:00"}],"Mi":[{"von":"18:00","bis":"22:00"}],"Do":[],"Fr":[{"von":"18:00","bis":"22:00"}],"Sa":[{"von":"18:00","bis":"22:00"}],"So":[{"von":"18:00","bis":"22:00"}]}'::jsonb
WHERE name ILIKE 'T_di' AND ort = 'Brigels';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:30","bis":"21:00"}],"Do":[{"von":"17:30","bis":"21:00"}],"Fr":[{"von":"17:30","bis":"21:00"}],"Sa":[{"von":"17:30","bis":"21:00"}],"So":[{"von":"17:30","bis":"21:00"}]}'::jsonb
WHERE name = 'Surselva' AND ort = 'Brigels';

-- Saisonbetrieb: Burleun, Golf, La Val, Tumpiv (keine festen Zeiten)

-- ============================================================
-- OBERSAXEN (7 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"21:00"}],"Di":[{"von":"09:00","bis":"21:00"}],"Mi":[{"von":"09:00","bis":"21:00"}],"Do":[{"von":"09:00","bis":"21:00"}],"Fr":[{"von":"09:00","bis":"21:00"}],"Sa":[{"von":"09:00","bis":"21:00"}],"So":[{"von":"09:00","bis":"21:00"}]}'::jsonb
WHERE name ILIKE '%Setz Nair%' AND ort = 'Obersaxen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"16:30"}],"Di":[{"von":"08:00","bis":"16:30"}],"Mi":[{"von":"08:00","bis":"16:30"}],"Do":[{"von":"08:00","bis":"16:30"}],"Fr":[{"von":"08:00","bis":"16:30"}],"Sa":[{"von":"08:00","bis":"16:30"}],"So":[{"von":"08:00","bis":"16:30"}]}'::jsonb
WHERE name = 'Kartitscha' AND ort = 'Obersaxen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"21:00"}],"Di":[],"Mi":[],"Do":[{"von":"09:00","bis":"21:00"}],"Fr":[{"von":"09:00","bis":"21:00"}],"Sa":[{"von":"09:00","bis":"21:00"}],"So":[{"von":"09:00","bis":"18:00"}]}'::jsonb
WHERE name = 'Wali' AND ort = 'Obersaxen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"23:00"}],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Central' AND ort = 'Obersaxen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"20:00"}],"Di":[{"von":"11:00","bis":"20:00"}],"Mi":[{"von":"11:00","bis":"20:00"}],"Do":[{"von":"11:00","bis":"20:00"}],"Fr":[{"von":"11:00","bis":"20:00"}],"Sa":[{"von":"11:00","bis":"20:00"}],"So":[{"von":"11:00","bis":"20:00"}]}'::jsonb
WHERE name = 'Rufalipark' AND ort = 'Obersaxen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"15:00","bis":"23:30"}],"Di":[{"von":"15:00","bis":"23:30"}],"Mi":[{"von":"15:00","bis":"23:30"}],"Do":[{"von":"15:00","bis":"23:30"}],"Fr":[{"von":"15:00","bis":"23:30"}],"Sa":[{"von":"15:00","bis":"23:30"}],"So":[{"von":"15:00","bis":"23:30"}]}'::jsonb
WHERE name = 'Hurti' AND ort = 'Obersaxen';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"11:00"}],"Di":[],"Mi":[{"von":"07:30","bis":"11:00"}],"Do":[{"von":"07:30","bis":"11:00"}],"Fr":[{"von":"07:30","bis":"11:00"}],"Sa":[{"von":"07:30","bis":"11:00"}],"So":[]}'::jsonb
WHERE name ILIKE '%Cappucino%' AND ort = 'Obersaxen';

-- Geschlossen: Agarta, Pöschtli (zum Verkauf)
-- Nicht gefunden: Leo's, Chümerbühl, Piz Mundaun (keine festen Zeiten)

-- ============================================================
-- VALS (7 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:30","bis":"22:00"}],"Do":[{"von":"11:30","bis":"22:00"}],"Fr":[{"von":"11:30","bis":"22:00"}],"Sa":[{"von":"11:30","bis":"22:00"}],"So":[{"von":"11:30","bis":"22:00"}]}'::jsonb
WHERE name = 'Edelweiss' AND ort = 'Vals';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"16:00","bis":"00:00"}],"Do":[{"von":"08:00","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"08:00","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Sa":[{"von":"08:00","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"So":[{"von":"08:00","bis":"12:00"},{"von":"16:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Glenner' AND ort = 'Vals';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[],"Do":[{"von":"11:00","bis":"22:00"}],"Fr":[{"von":"11:00","bis":"22:00"}],"Sa":[{"von":"11:00","bis":"22:00"}],"So":[{"von":"11:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Ganni' AND ort = 'Vals';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"17:00"}],"Di":[{"von":"07:30","bis":"17:00"}],"Mi":[{"von":"07:30","bis":"17:00"}],"Do":[{"von":"07:30","bis":"17:00"}],"Fr":[{"von":"07:30","bis":"17:00"}],"Sa":[{"von":"07:30","bis":"17:00"}],"So":[{"von":"07:30","bis":"17:00"}]}'::jsonb
WHERE name = 'Peng' AND ort = 'Vals';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Di":[{"von":"09:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Mi":[],"Do":[],"Fr":[{"von":"09:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"09:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[{"von":"09:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Alparosa' AND ort = 'Vals';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"23:00"}],"Di":[{"von":"10:00","bis":"23:00"}],"Mi":[{"von":"10:00","bis":"23:00"}],"Do":[{"von":"15:00","bis":"23:00"}],"Fr":[{"von":"15:00","bis":"23:00"}],"Sa":[{"von":"10:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Alpina' AND ort = 'Vals';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:00","bis":"00:00"}],"Di":[{"von":"17:00","bis":"00:00"}],"Mi":[],"Do":[{"von":"17:00","bis":"00:00"}],"Fr":[{"von":"17:00","bis":"00:00"}],"Sa":[{"von":"17:00","bis":"00:00"}],"So":[{"von":"17:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Da Papa' AND ort = 'Vals';

-- ============================================================
-- LENZERHEIDE restliche (15 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:30"}],"Di":[{"von":"09:00","bis":"16:30"}],"Mi":[{"von":"09:00","bis":"16:30"}],"Do":[{"von":"09:00","bis":"16:30"}],"Fr":[{"von":"09:00","bis":"16:30"}],"Sa":[{"von":"09:00","bis":"16:30"}],"So":[{"von":"09:00","bis":"16:30"}]}'::jsonb
WHERE name = 'Rothorngipfel' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"00:00"}],"Di":[{"von":"07:00","bis":"00:00"}],"Mi":[{"von":"07:00","bis":"00:00"}],"Do":[{"von":"07:00","bis":"00:00"}],"Fr":[{"von":"07:00","bis":"00:00"}],"Sa":[{"von":"07:00","bis":"00:00"}],"So":[{"von":"07:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Kurhaus' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"17:00"}],"Di":[{"von":"08:30","bis":"17:00"}],"Mi":[{"von":"08:30","bis":"17:00"}],"Do":[{"von":"08:30","bis":"17:00"}],"Fr":[{"von":"08:30","bis":"17:00"}],"Sa":[{"von":"08:30","bis":"17:00"}],"So":[{"von":"08:30","bis":"17:00"}]}'::jsonb
WHERE name = 'Acla Grischuna' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"19:00"}],"Di":[{"von":"08:00","bis":"19:00"}],"Mi":[{"von":"08:00","bis":"19:00"}],"Do":[{"von":"08:00","bis":"19:00"}],"Fr":[{"von":"08:00","bis":"19:00"}],"Sa":[{"von":"14:00","bis":"19:00"}],"So":[]}'::jsonb
WHERE name = 'Muloin' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"00:00"}],"Di":[{"von":"16:00","bis":"00:00"}],"Mi":[{"von":"16:00","bis":"00:00"}],"Do":[{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"16:00","bis":"01:00"}],"Sa":[{"von":"15:00","bis":"01:00"}],"So":[{"von":"15:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Ninos' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"17:00"}],"Di":[{"von":"09:00","bis":"17:00"}],"Mi":[{"von":"09:00","bis":"17:00"}],"Do":[{"von":"09:00","bis":"17:00"}],"Fr":[{"von":"09:00","bis":"17:00"}],"Sa":[{"von":"09:00","bis":"17:00"}],"So":[{"von":"09:00","bis":"17:00"}]}'::jsonb
WHERE name = 'Alp Nova' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:00","bis":"15:00"},{"von":"17:00","bis":"22:00"}],"Mi":[{"von":"11:00","bis":"15:00"},{"von":"17:00","bis":"22:00"}],"Do":[{"von":"11:00","bis":"15:00"},{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"11:00","bis":"15:00"},{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"11:00","bis":"15:00"},{"von":"17:00","bis":"22:00"}],"So":[{"von":"11:00","bis":"15:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name ILIKE '%Elio%' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:00"}],"Di":[{"von":"08:30","bis":"16:00"}],"Mi":[{"von":"08:30","bis":"16:00"}],"Do":[{"von":"08:30","bis":"16:00"}],"Fr":[{"von":"08:30","bis":"16:00"}],"Sa":[{"von":"08:30","bis":"16:00"}],"So":[{"von":"08:30","bis":"16:00"}]}'::jsonb
WHERE name = 'Piz Scalottas' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"16:30"}],"Di":[{"von":"11:30","bis":"16:30"}],"Mi":[{"von":"11:30","bis":"16:30"}],"Do":[{"von":"11:30","bis":"16:30"}],"Fr":[{"von":"11:30","bis":"16:30"}],"Sa":[{"von":"11:30","bis":"16:30"}],"So":[{"von":"11:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Scharmoin' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"17:00"}],"Di":[{"von":"08:30","bis":"17:00"}],"Mi":[{"von":"08:30","bis":"17:00"}],"Do":[{"von":"08:30","bis":"17:00"}],"Fr":[{"von":"08:30","bis":"17:00"}],"Sa":[{"von":"08:30","bis":"17:00"}],"So":[{"von":"08:30","bis":"17:00"}]}'::jsonb
WHERE name = 'Z Bar' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"17:30","bis":"23:00"}],"Mi":[{"von":"11:00","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Do":[{"von":"11:00","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"So":[{"von":"11:00","bis":"14:00"},{"von":"17:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Q Vadis' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"21:00"}],"Mi":[{"von":"08:00","bis":"21:00"}],"Do":[{"von":"08:00","bis":"21:00"}],"Fr":[{"von":"08:00","bis":"21:00"}],"Sa":[{"von":"08:00","bis":"21:00"}],"So":[]}'::jsonb
WHERE name = 'Danis' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:30","bis":"18:30"}],"Di":[{"von":"06:30","bis":"18:30"}],"Mi":[{"von":"06:30","bis":"18:30"}],"Do":[{"von":"06:30","bis":"18:30"}],"Fr":[{"von":"06:30","bis":"18:30"}],"Sa":[{"von":"06:30","bis":"18:30"}],"So":[{"von":"06:30","bis":"18:30"}]}'::jsonb
WHERE name = 'Aurora' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"23:00"}],"Di":[{"von":"16:00","bis":"23:00"}],"Mi":[{"von":"16:00","bis":"23:00"}],"Do":[{"von":"16:00","bis":"23:00"}],"Fr":[{"von":"16:00","bis":"23:00"}],"Sa":[{"von":"16:00","bis":"23:00"}],"So":[{"von":"16:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Patata' AND ort = 'Lenzerheide';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"17:00"}],"Di":[{"von":"10:00","bis":"17:00"}],"Mi":[{"von":"10:00","bis":"17:00"}],"Do":[{"von":"10:00","bis":"17:00"}],"Fr":[{"von":"10:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"22:00"}],"So":[{"von":"09:00","bis":"17:00"}]}'::jsonb
WHERE name = 'Scuntrada' AND ort = 'Lenzerheide';

-- Nicht gefunden: Tgantieni, Collina, Seda, Golfrestaurant (saisonabhängig)

-- ============================================================
-- VALBELLA restliche (7 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"15:00","bis":"01:00"}],"Di":[{"von":"15:00","bis":"01:00"}],"Mi":[{"von":"15:00","bis":"01:00"}],"Do":[{"von":"15:00","bis":"01:00"}],"Fr":[{"von":"15:00","bis":"01:00"}],"Sa":[{"von":"15:00","bis":"01:00"}],"So":[{"von":"15:00","bis":"01:00"}]}'::jsonb
WHERE name = 'Slalom Bar' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"23:00"}],"Di":[{"von":"08:00","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"23:00"}],"Do":[{"von":"08:00","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Sartons' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"18:00","bis":"21:30"}],"Di":[{"von":"18:00","bis":"21:30"}],"Mi":[{"von":"18:00","bis":"21:30"}],"Do":[{"von":"18:00","bis":"21:30"}],"Fr":[{"von":"18:00","bis":"21:30"}],"Sa":[{"von":"18:00","bis":"21:30"}],"So":[{"von":"18:00","bis":"21:30"}]}'::jsonb
WHERE name = 'Posthotel' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:30","bis":"18:00"}],"Di":[{"von":"06:30","bis":"18:00"}],"Mi":[{"von":"06:30","bis":"18:00"}],"Do":[{"von":"06:30","bis":"18:00"}],"Fr":[{"von":"06:30","bis":"18:00"}],"Sa":[{"von":"07:00","bis":"17:00"}],"So":[{"von":"07:00","bis":"17:00"}]}'::jsonb
WHERE name ILIKE '%Sgier%' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:00"}],"Di":[{"von":"09:00","bis":"16:00"}],"Mi":[{"von":"09:00","bis":"16:00"}],"Do":[{"von":"09:00","bis":"16:00"}],"Fr":[{"von":"09:00","bis":"16:00"}],"Sa":[{"von":"09:00","bis":"16:00"}],"So":[{"von":"09:00","bis":"16:00"}]}'::jsonb
WHERE name ILIKE 'Mottah_tte' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"17:00"}],"Di":[{"von":"09:00","bis":"17:00"}],"Mi":[{"von":"09:00","bis":"17:00"}],"Do":[{"von":"09:00","bis":"17:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"17:00"}],"So":[{"von":"09:00","bis":"17:00"}]}'::jsonb
WHERE name ILIKE 'St_tz da Miez' AND ort = 'Valbella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:30","bis":"16:30"}],"Di":[{"von":"09:30","bis":"16:30"}],"Mi":[{"von":"09:30","bis":"16:30"},{"von":"18:00","bis":"22:00"}],"Do":[{"von":"09:30","bis":"16:30"},{"von":"18:00","bis":"22:00"}],"Fr":[{"von":"09:30","bis":"16:30"}],"Sa":[{"von":"09:30","bis":"16:30"},{"von":"18:00","bis":"22:00"}],"So":[{"von":"09:30","bis":"16:30"}]}'::jsonb
WHERE name ILIKE '%Schamuela%' AND ort = 'Valbella';

-- ============================================================
-- LANTSCH/LENZ + PARPAN restliche (6 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"10:00","bis":"21:00"}],"Do":[{"von":"10:00","bis":"21:00"}],"Fr":[{"von":"10:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"21:00"}]}'::jsonb
WHERE name = 'St. Cassian' AND ort = 'Lantsch/Lenz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"22:00"}],"Di":[{"von":"09:00","bis":"22:00"}],"Mi":[{"von":"09:00","bis":"22:00"}],"Do":[{"von":"09:00","bis":"22:00"}],"Fr":[{"von":"09:00","bis":"22:00"}],"Sa":[{"von":"09:00","bis":"22:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Sarain' AND ort = 'Lantsch/Lenz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:00","bis":"22:00"}],"Do":[{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'La Tgoma' AND ort = 'Lantsch/Lenz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"22:00"}],"Di":[{"von":"07:30","bis":"22:00"}],"Mi":[{"von":"07:30","bis":"22:00"}],"Do":[{"von":"07:30","bis":"22:00"}],"Fr":[{"von":"07:30","bis":"22:00"}],"Sa":[{"von":"07:30","bis":"22:00"}],"So":[{"von":"07:30","bis":"22:00"}]}'::jsonb
WHERE name ILIKE '%Bestzeit%' AND ort = 'Parpan';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"15:30","bis":"23:00"}],"Do":[{"von":"15:30","bis":"23:00"}],"Fr":[{"von":"15:30","bis":"23:00"}],"Sa":[{"von":"15:30","bis":"23:00"}],"So":[{"von":"15:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Obertor' AND ort = 'Parpan';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"17:00"}],"Di":[{"von":"08:30","bis":"17:00"}],"Mi":[{"von":"08:30","bis":"17:00"}],"Do":[{"von":"08:30","bis":"17:00"}],"Fr":[{"von":"08:30","bis":"17:00"}],"Sa":[{"von":"08:30","bis":"17:00"}],"So":[{"von":"08:30","bis":"17:00"}]}'::jsonb
WHERE name = 'Heimberg' AND ort = 'Parpan';

-- ============================================================
-- KLOSTERS restliche + SERNEUS (5 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"23:00"}],"Di":[{"von":"10:00","bis":"23:00"}],"Mi":[{"von":"10:00","bis":"23:00"}],"Do":[{"von":"10:00","bis":"23:00"}],"Fr":[{"von":"10:00","bis":"23:00"}],"Sa":[{"von":"10:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE 'Alpenr_sli' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"00:00"}],"Di":[{"von":"16:00","bis":"00:00"}],"Mi":[{"von":"16:00","bis":"00:00"}],"Do":[{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"16:00","bis":"00:00"}],"Sa":[{"von":"16:00","bis":"00:00"}],"So":[{"von":"16:00","bis":"00:00"}]}'::jsonb
WHERE name ILIKE 'Fonduest_bli' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"21:30"}],"Di":[{"von":"11:30","bis":"21:30"}],"Mi":[{"von":"11:30","bis":"21:30"}],"Do":[{"von":"11:30","bis":"21:30"}],"Fr":[{"von":"11:30","bis":"21:30"}],"Sa":[{"von":"11:30","bis":"21:30"}],"So":[{"von":"11:30","bis":"21:30"}]}'::jsonb
WHERE name = 'Vereina' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"00:00"}],"Di":[{"von":"08:00","bis":"00:00"}],"Mi":[{"von":"08:00","bis":"00:00"}],"Do":[{"von":"08:00","bis":"00:00"}],"Fr":[{"von":"08:00","bis":"00:00"}],"Sa":[{"von":"08:00","bis":"00:00"}],"So":[{"von":"08:00","bis":"00:00"}]}'::jsonb
WHERE name ILIKE 'B_r' AND ort = 'Klosters-Serneus';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"10:00","bis":"22:00"}],"Do":[{"von":"10:00","bis":"22:00"}],"Fr":[{"von":"10:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"17:00"}]}'::jsonb
WHERE name = 'Gotschna' AND ort = 'Serneus';

-- Saisonbetrieb: Armando (Pop-up), Schifer, Schwendi

-- ============================================================
-- KÜBLIS + JENAZ (6 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"14:00"}],"Di":[{"von":"06:00","bis":"23:00"}],"Mi":[{"von":"06:00","bis":"23:00"}],"Do":[{"von":"06:00","bis":"23:00"}],"Fr":[{"von":"06:00","bis":"23:00"}],"Sa":[{"von":"08:00","bis":"23:00"}],"So":[{"von":"08:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Hirschen' AND ort ILIKE 'K_blis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"14:00"}],"Di":[{"von":"09:00","bis":"14:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Terminus' AND ort ILIKE 'K_blis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"22:00"}],"Di":[{"von":"06:00","bis":"22:00"}],"Mi":[{"von":"06:00","bis":"22:00"}],"Do":[],"Fr":[{"von":"06:00","bis":"22:00"}],"Sa":[{"von":"09:00","bis":"17:00"}],"So":[{"von":"09:00","bis":"14:00"}]}'::jsonb
WHERE name = 'Hirschen' AND ort = 'Jenaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"12:00"},{"von":"16:30","bis":"23:00"}],"Mi":[{"von":"08:00","bis":"12:00"},{"von":"16:30","bis":"23:00"}],"Do":[{"von":"08:00","bis":"12:00"},{"von":"16:30","bis":"23:00"}],"Fr":[{"von":"08:00","bis":"12:00"},{"von":"16:30","bis":"01:00"}],"Sa":[{"von":"08:00","bis":"21:00"}],"So":[{"von":"08:00","bis":"11:00"}]}'::jsonb
WHERE name = 'Krone' AND ort = 'Jenaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"22:00"}],"Di":[],"Mi":[],"Do":[{"von":"10:00","bis":"22:00"}],"Fr":[{"von":"10:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Landhaus' AND ort = 'Jenaz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"22:00"}],"Di":[{"von":"10:00","bis":"22:00"}],"Mi":[{"von":"10:00","bis":"22:00"}],"Do":[{"von":"10:00","bis":"22:00"}],"Fr":[{"von":"10:00","bis":"22:00"}],"Sa":[{"von":"10:00","bis":"22:00"}],"So":[{"von":"10:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Landgasthof' AND ort = 'Jenaz';

-- Nicht gefunden: Bahnhöfli Küblis (ungenaue Zeiten)

-- ============================================================
-- SEDRUN + DISENTIS restliche (5 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:30","bis":"19:00"}],"Di":[{"von":"06:30","bis":"19:00"}],"Mi":[{"von":"06:30","bis":"19:00"}],"Do":[{"von":"06:30","bis":"19:00"}],"Fr":[{"von":"06:30","bis":"19:00"}],"Sa":[{"von":"06:30","bis":"19:00"}],"So":[{"von":"06:30","bis":"19:00"}]}'::jsonb
WHERE name = 'Bahnhofbuffet' AND ort = 'Sedrun';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:30","bis":"22:00"}],"Di":[{"von":"09:30","bis":"22:00"}],"Mi":[{"von":"10:00","bis":"00:00"}],"Do":[{"von":"10:00","bis":"00:00"}],"Fr":[{"von":"09:30","bis":"22:00"}],"Sa":[{"von":"09:30","bis":"21:30"}],"So":[{"von":"09:30","bis":"22:00"}]}'::jsonb
WHERE name = 'Badus' AND ort = 'Sedrun';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:00","bis":"00:00"}],"Mi":[{"von":"08:00","bis":"00:00"}],"Do":[{"von":"08:00","bis":"00:00"}],"Fr":[{"von":"08:00","bis":"00:00"}],"Sa":[{"von":"08:00","bis":"00:00"}],"So":[{"von":"08:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Furka' AND ort = 'Disentis/Muster';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Cruna' AND ort = 'Disentis/Muster';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:00"}],"Di":[{"von":"09:00","bis":"16:00"}],"Mi":[{"von":"09:00","bis":"16:00"}],"Do":[{"von":"09:00","bis":"16:00"}],"Fr":[{"von":"09:00","bis":"16:00"}],"Sa":[{"von":"09:00","bis":"16:00"}],"So":[{"von":"09:00","bis":"16:00"}]}'::jsonb
WHERE name = 'Nevada' AND ort = 'Disentis/Muster';

-- Geschlossen: Peanuts Sedrun, Ustria Fontanivas (bis 16.04.2026)
-- Nicht gefunden: Pizzeria Centro, Pizzeria Fortuna

-- ============================================================
-- FLIMS restliche (8 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:00","bis":"22:00"}],"Do":[{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"17:00","bis":"22:00"}],"So":[{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Arena' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:30"}],"Di":[{"von":"09:00","bis":"16:30"}],"Mi":[{"von":"09:00","bis":"16:30"}],"Do":[{"von":"09:00","bis":"16:30"}],"Fr":[{"von":"09:00","bis":"16:30"}],"Sa":[{"von":"09:00","bis":"16:30"}],"So":[{"von":"09:00","bis":"16:30"}]}'::jsonb
WHERE name = 'Nagens' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"17:00"}],"Di":[],"Mi":[{"von":"10:00","bis":"17:00"}],"Do":[{"von":"10:00","bis":"17:00"}],"Fr":[{"von":"10:00","bis":"17:00"}],"Sa":[{"von":"10:00","bis":"17:00"}],"So":[{"von":"10:00","bis":"17:00"}]}'::jsonb
WHERE name = 'Caumasee' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Di":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Sa":[{"von":"11:30","bis":"23:00"}],"So":[{"von":"11:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Pizzeria Veneziana' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:45","bis":"14:00"},{"von":"17:45","bis":"23:00"}],"Di":[{"von":"11:45","bis":"14:00"},{"von":"17:45","bis":"23:00"}],"Mi":[{"von":"11:45","bis":"14:00"},{"von":"17:45","bis":"23:00"}],"Do":[{"von":"11:45","bis":"14:00"},{"von":"17:45","bis":"23:00"}],"Fr":[{"von":"11:45","bis":"14:00"},{"von":"17:45","bis":"23:00"}],"Sa":[{"von":"11:45","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Des Alpes' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"22:30"}],"Di":[{"von":"11:00","bis":"22:30"}],"Mi":[{"von":"11:00","bis":"22:30"}],"Do":[{"von":"11:00","bis":"22:30"}],"Fr":[{"von":"11:00","bis":"22:30"}],"Sa":[{"von":"11:00","bis":"22:30"}],"So":[{"von":"11:00","bis":"22:30"}]}'::jsonb
WHERE name = 'Adula' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"17:00"}],"Di":[{"von":"08:30","bis":"17:00"}],"Mi":[{"von":"08:30","bis":"17:00"}],"Do":[{"von":"08:30","bis":"17:00"}],"Fr":[{"von":"08:30","bis":"17:00"}],"Sa":[{"von":"08:30","bis":"18:00"}],"So":[{"von":"08:30","bis":"18:00"}]}'::jsonb
WHERE name = 'Ella' AND ort = 'Flims';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"18:00","bis":"21:00"}],"Sa":[{"von":"11:30","bis":"21:00"}],"So":[{"von":"11:30","bis":"21:00"}]}'::jsonb
WHERE name = 'Bellevue' AND ort = 'Flims';

-- Geschlossen: Waldhaus (Renovation), Lieto (dauerhaft geschl.)
-- Nicht gefunden: La Fabricaa, Me and All Hotel

-- ============================================================
-- LAAX restliche (7 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"18:00"}],"Di":[{"von":"08:30","bis":"18:00"}],"Mi":[{"von":"08:30","bis":"18:00"}],"Do":[{"von":"08:30","bis":"18:00"}],"Fr":[{"von":"08:30","bis":"18:00"}],"Sa":[{"von":"08:30","bis":"18:00"}],"So":[{"von":"08:30","bis":"18:00"}]}'::jsonb
WHERE name = 'Snake Bar' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"16:30"}],"Di":[{"von":"08:30","bis":"16:30"}],"Mi":[{"von":"08:30","bis":"16:30"}],"Do":[{"von":"08:30","bis":"16:30"}],"Fr":[{"von":"08:30","bis":"16:30"}],"Sa":[{"von":"08:30","bis":"16:30"}],"So":[{"von":"08:30","bis":"16:30"}]}'::jsonb
WHERE name = 'Tegia Curnius' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Posta Veglia' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:30"}],"Di":[{"von":"09:00","bis":"16:30"}],"Mi":[{"von":"09:00","bis":"16:30"}],"Do":[{"von":"09:00","bis":"16:30"}],"Fr":[{"von":"09:00","bis":"16:30"}],"Sa":[{"von":"09:00","bis":"16:30"}],"So":[{"von":"09:00","bis":"16:30"}]}'::jsonb
WHERE name = 'Tegia Miez' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"17:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Pizzeria Cristallina' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"22:00"}],"Di":[{"von":"07:30","bis":"22:00"}],"Mi":[{"von":"07:30","bis":"22:00"}],"Do":[{"von":"07:30","bis":"22:00"}],"Fr":[{"von":"07:30","bis":"22:00"}],"Sa":[{"von":"07:30","bis":"22:00"}],"So":[{"von":"07:30","bis":"22:00"}]}'::jsonb
WHERE name = 'Laaxerhof' AND ort = 'Laax';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:30","bis":"23:00"}],"Di":[{"von":"06:30","bis":"23:00"}],"Mi":[{"von":"06:30","bis":"23:00"}],"Do":[{"von":"06:30","bis":"23:00"}],"Fr":[{"von":"06:30","bis":"23:00"}],"Sa":[{"von":"06:30","bis":"23:00"}],"So":[{"von":"06:30","bis":"23:00"}]}'::jsonb
WHERE name = 'Seehof' AND ort = 'Laax';

-- Nicht gefunden: Elefant (Saisonbetrieb), Laguna

-- ============================================================
-- FALERA (2 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"23:00"}],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[],"Do":[],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Ustria Aurora' AND ort = 'Falera';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Encarna' AND ort = 'Falera';

-- ============================================================
-- ILANZ (5 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:00","bis":"22:00"}],"Do":[{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[{"von":"11:00","bis":"14:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Obertor' AND ort = 'Ilanz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"01:00"}],"Di":[{"von":"16:00","bis":"01:00"}],"Mi":[{"von":"16:00","bis":"01:00"}],"Do":[{"von":"16:00","bis":"01:00"}],"Fr":[{"von":"16:00","bis":"02:00"}],"Sa":[{"von":"16:00","bis":"02:00"}],"So":[]}'::jsonb
WHERE name = 'Pub Pin' AND ort = 'Ilanz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:15","bis":"22:30"}],"Di":[{"von":"06:15","bis":"22:30"}],"Mi":[{"von":"06:15","bis":"22:30"}],"Do":[{"von":"06:15","bis":"22:30"}],"Fr":[{"von":"06:15","bis":"22:30"}],"Sa":[{"von":"07:00","bis":"22:30"}],"So":[]}'::jsonb
WHERE name ILIKE 'T_di' AND ort = 'Ilanz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Di":[{"von":"09:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Mi":[],"Do":[{"von":"09:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Fr":[{"von":"09:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"Sa":[{"von":"09:00","bis":"14:00"},{"von":"17:30","bis":"22:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Glenner' AND ort = 'Ilanz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"11:30"}],"Di":[{"von":"07:00","bis":"11:30"},{"von":"16:30","bis":"22:00"}],"Mi":[{"von":"07:00","bis":"11:30"},{"von":"16:30","bis":"22:00"}],"Do":[{"von":"07:00","bis":"11:30"},{"von":"16:30","bis":"22:00"}],"Fr":[{"von":"07:00","bis":"11:30"},{"von":"16:30","bis":"22:00"}],"Sa":[{"von":"07:00","bis":"11:30"},{"von":"16:30","bis":"22:00"}],"So":[{"von":"07:00","bis":"11:30"}]}'::jsonb
WHERE name = 'Eden' AND ort = 'Ilanz';

-- ============================================================
-- VADUZ / TRIESENBERG / BALZERS / TRIESEN (4 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"13:30"},{"von":"17:00","bis":"00:00"}],"Di":[{"von":"09:00","bis":"13:30"},{"von":"17:00","bis":"00:00"}],"Mi":[{"von":"09:00","bis":"13:30"},{"von":"17:00","bis":"00:00"}],"Do":[{"von":"09:00","bis":"13:30"},{"von":"17:00","bis":"00:00"}],"Fr":[{"von":"09:00","bis":"13:30"},{"von":"17:00","bis":"00:00"}],"Sa":[{"von":"17:00","bis":"00:00"}],"So":[]}'::jsonb
WHERE name = 'Falknis' AND ort = 'Vaduz';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"00:00"}],"Di":[],"Mi":[],"Do":[{"von":"09:00","bis":"00:00"}],"Fr":[{"von":"09:00","bis":"00:00"}],"Sa":[{"von":"09:00","bis":"00:00"}],"So":[{"von":"09:00","bis":"00:00"}]}'::jsonb
WHERE name = 'Edelweiss' AND ort = 'Triesenberg';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"17:00","bis":"23:00"}],"Di":[{"von":"17:00","bis":"23:00"}],"Mi":[{"von":"17:00","bis":"23:00"}],"Do":[{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"23:00"}],"So":[{"von":"11:00","bis":"23:00"}]}'::jsonb
WHERE name ILIKE '%Gitzih_ll%' AND ort = 'Triesenberg';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"21:30"}],"Di":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"21:30"}],"Mi":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"21:30"}],"Do":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"21:30"}],"Fr":[{"von":"10:00","bis":"14:00"},{"von":"17:00","bis":"21:30"}],"Sa":[{"von":"10:00","bis":"14:30"},{"von":"17:00","bis":"20:30"}],"So":[]}'::jsonb
WHERE name = 'Fratelli del Vecchio' AND ort = 'Triesen';

-- Geschlossen: Luce Vaduz (Konkurs)
-- Nicht eindeutig: Gasthaus zum Engel Balzers

-- ============================================================
-- IGIS / GRÜSCH / SCHIERS / TRIMMIS / TRIN / ZIZERS (10 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Krone' AND ort = 'Igis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"14:00"}],"Di":[{"von":"08:00","bis":"22:30"}],"Mi":[{"von":"08:00","bis":"22:30"}],"Do":[{"von":"08:00","bis":"22:30"}],"Fr":[{"von":"08:00","bis":"22:30"}],"Sa":[{"von":"08:00","bis":"22:30"}],"So":[{"von":"08:00","bis":"22:30"}]}'::jsonb
WHERE name = 'Sporti' AND ort ILIKE 'Gr_sch';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"16:00","bis":"23:00"}],"Di":[{"von":"16:00","bis":"23:00"}],"Mi":[{"von":"16:00","bis":"23:00"}],"Do":[{"von":"16:00","bis":"23:00"}],"Fr":[{"von":"16:00","bis":"01:00"}],"Sa":[{"von":"16:00","bis":"01:00"}],"So":[{"von":"16:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Fasan' AND ort ILIKE 'Gr_sch';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:30","bis":"19:00"}],"Di":[{"von":"07:30","bis":"19:00"}],"Mi":[{"von":"07:30","bis":"19:00"}],"Do":[{"von":"07:30","bis":"19:00"}],"Fr":[{"von":"07:30","bis":"19:00"}],"Sa":[{"von":"07:30","bis":"19:00"}],"So":[{"von":"08:30","bis":"18:00"}]}'::jsonb
WHERE name ILIKE 'Bahnh_fli' AND ort = 'Schiers';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"17:00","bis":"00:00"}],"Mi":[{"von":"17:00","bis":"00:00"}],"Do":[{"von":"17:00","bis":"00:00"}],"Fr":[{"von":"17:00","bis":"02:00"}],"Sa":[],"So":[]}'::jsonb
WHERE name = 'K-Bar' AND ort = 'Trimmis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"22:00"}],"Di":[],"Mi":[],"Do":[{"von":"09:00","bis":"22:00"}],"Fr":[{"von":"09:00","bis":"22:00"}],"Sa":[{"von":"09:00","bis":"22:00"}],"So":[{"von":"09:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Parlatsch' AND ort = 'Trin';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Di":[{"von":"08:30","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Mi":[{"von":"08:30","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Do":[{"von":"08:30","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Fr":[{"von":"08:30","bis":"12:00"},{"von":"16:00","bis":"00:00"}],"Sa":[{"von":"08:30","bis":"00:00"}],"So":[{"von":"08:30","bis":"12:00"}]}'::jsonb
WHERE name = 'Nussbaum' AND ort = 'Zizers';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"08:30","bis":"22:30"}],"Mi":[{"von":"08:30","bis":"22:30"}],"Do":[{"von":"08:30","bis":"22:30"}],"Fr":[{"von":"08:30","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[{"von":"10:00","bis":"18:00"}]}'::jsonb
WHERE name = 'Sonnegg' AND ort = 'Zizers';

-- Geschlossen: Rätikon Schiers (Konkurs)
-- Nicht gefunden: Cafe Bar Trimmis, Vorburg Zizers, GioiA Zizers

-- ============================================================
-- DIVERSE KLEINORTE (14 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"07:00","bis":"22:00"}],"Di":[{"von":"07:00","bis":"22:00"}],"Mi":[{"von":"07:00","bis":"22:00"}],"Do":[{"von":"07:00","bis":"22:00"}],"Fr":[{"von":"07:00","bis":"22:00"}],"Sa":[{"von":"07:00","bis":"22:00"}],"So":[{"von":"07:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Dulezi' AND ort = 'Trun';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"08:00","bis":"20:00"}],"Do":[{"von":"08:00","bis":"20:00"}],"Fr":[{"von":"08:00","bis":"20:00"}],"Sa":[{"von":"08:00","bis":"20:00"}],"So":[{"von":"08:00","bis":"20:00"}]}'::jsonb
WHERE name = 'Dalla Posta' AND ort = 'Vella';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"09:00","bis":"11:00"},{"von":"16:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"11:00"},{"von":"16:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"11:00"},{"von":"16:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"11:00"},{"von":"16:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name = 'Stiva Grischuna' AND ort = 'Sagogn';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"11:00","bis":"23:00"}],"Di":[],"Mi":[],"Do":[{"von":"11:00","bis":"23:00"}],"Fr":[{"von":"11:00","bis":"23:00"}],"Sa":[{"von":"11:00","bis":"23:00"}],"So":[{"von":"11:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Valata' AND ort = 'Surcuolm';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[{"von":"09:00","bis":"23:00"}],"Mi":[{"von":"09:00","bis":"23:00"}],"Do":[{"von":"09:00","bis":"23:00"}],"Fr":[{"von":"09:00","bis":"23:00"}],"Sa":[{"von":"09:00","bis":"23:00"}],"So":[]}'::jsonb
WHERE name ILIKE 'Sch_fli' AND ort = 'Thusis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"09:00","bis":"16:00"}],"Di":[{"von":"09:00","bis":"16:00"}],"Mi":[{"von":"09:00","bis":"16:00"}],"Do":[{"von":"09:00","bis":"16:00"}],"Fr":[{"von":"09:00","bis":"16:00"}],"Sa":[{"von":"09:00","bis":"16:00"}],"So":[{"von":"09:00","bis":"16:00"}]}'::jsonb
WHERE name = 'Tigignas' AND ort = 'Savognin';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"06:00","bis":"23:00"}],"Di":[{"von":"06:00","bis":"23:00"}],"Mi":[{"von":"06:00","bis":"23:00"}],"Do":[{"von":"06:00","bis":"23:00"}],"Fr":[{"von":"06:00","bis":"23:00"}],"Sa":[{"von":"06:00","bis":"23:00"}],"So":[{"von":"06:00","bis":"23:00"}]}'::jsonb
WHERE name = 'Post' AND ort = 'Bivio';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Do":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Fr":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"Sa":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"23:00"}],"So":[{"von":"11:30","bis":"14:00"},{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Don Antonio' AND ort = 'Pany';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:00","bis":"11:45"},{"von":"16:30","bis":"23:30"}],"Di":[{"von":"08:00","bis":"11:45"}],"Mi":[{"von":"08:00","bis":"11:45"},{"von":"16:30","bis":"23:30"}],"Do":[{"von":"08:00","bis":"11:45"},{"von":"16:30","bis":"23:30"}],"Fr":[{"von":"08:00","bis":"11:45"},{"von":"16:30","bis":"23:30"}],"Sa":[{"von":"08:00","bis":"11:45"},{"von":"16:30","bis":"23:30"}],"So":[{"von":"08:00","bis":"11:45"},{"von":"16:30","bis":"23:30"}]}'::jsonb
WHERE name = 'Dorfbeiz Chesa' AND ort = 'Seewis';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"20:00"}],"Di":[{"von":"08:30","bis":"20:00"}],"Mi":[{"von":"08:30","bis":"20:00"}],"Do":[{"von":"08:30","bis":"20:00"}],"Fr":[{"von":"08:30","bis":"00:00"}],"Sa":[{"von":"08:30","bis":"03:00"}],"So":[{"von":"08:30","bis":"00:00"}]}'::jsonb
WHERE name = 'Alte Schwendi' AND ort ILIKE 'Conters%';

-- ============================================================
-- DAVOS restliche (4 Betriebe)
-- ============================================================

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:00","bis":"22:00"}],"Do":[{"von":"17:00","bis":"22:00"}],"Fr":[{"von":"17:00","bis":"22:00"}],"Sa":[{"von":"17:00","bis":"22:00"}],"So":[{"von":"17:00","bis":"22:00"}]}'::jsonb
WHERE name = 'Emerald' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[{"von":"08:30","bis":"20:00"}],"Di":[{"von":"08:30","bis":"20:00"}],"Mi":[{"von":"08:30","bis":"00:00"}],"Do":[{"von":"08:30","bis":"20:00"}],"Fr":[{"von":"08:30","bis":"00:00"}],"Sa":[{"von":"08:30","bis":"20:00"}],"So":[{"von":"08:30","bis":"20:00"}]}'::jsonb
WHERE name = 'Blockhuus' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[{"von":"17:00","bis":"00:00"}],"Do":[{"von":"17:00","bis":"00:00"}],"Fr":[{"von":"17:00","bis":"02:00"}],"Sa":[{"von":"17:00","bis":"02:00"}],"So":[{"von":"17:00","bis":"00:00"}]}'::jsonb
WHERE name ILIKE 'Stall Val_r' AND ort = 'Davos';

UPDATE betriebe SET oeffnungszeiten = '{"Mo":[],"Di":[],"Mi":[],"Do":[{"von":"22:00","bis":"05:00"}],"Fr":[{"von":"22:00","bis":"05:00"}],"Sa":[{"von":"22:00","bis":"05:00"}],"So":[]}'::jsonb
WHERE name = 'Platzhirsch' AND ort = 'Davos';

-- ============================================================
-- GESAMTZUSAMMENFASSUNG
-- Stand: 17.03.2026 (Google-Recherche)
-- Total: ~270 UPDATE-Statements
-- Regionen: Chur, Davos, Arosa, Flims, Laax, Lenzerheide,
--   Valbella, Churwalden, Parpan, Lantsch/Lenz, Savognin,
--   Klosters, Serneus, Küblis, Jenaz, Brigels, Obersaxen,
--   Vals, Sedrun, Disentis, Ilanz, Thusis, Splügen, Bivio,
--   Bergün, Avers, Zillis, Landquart, Maienfeld, Bad Ragaz,
--   Sargans, Domat/Ems, Bonaduz, Felsberg, Haldenstein,
--   Cham, Mels, Walenstadt, Flums, Flumserberg, Quarten,
--   Wangs, Falera, Igis, Grüsch, Schiers, Trimmis, Trin,
--   Zizers, Trun, Vella, Sagogn, Surcuolm, Pany, Seewis,
--   Conters i.P., Vaduz, Triesenberg, Triesen
-- Hinweis: Zeiten können saisonal variieren
-- ============================================================
