-- 12 Anlagen für aktive Kunden ohne erfasste Anlage (05.08.2026)
-- Ausgeführt am 05.08.2026 via Supabase MCP (Auftrag Daniel).
--
-- Befund: 12 aktive «mein Kunde»-Betriebe hatten keine einzige Anlage —
-- damit erschienen sie NIE in der Tourenplan-Fälligkeit (die Uhr hängt an
-- der Anlage; gleicher Effekt wie beim Golden Dragon am 05.08.).
-- Dazu 26 geschlossene Betriebe ohne Anlage (bewusst unangetastet).
--
-- Ableitung: Rhythmus aus dem Median der Reinigungsabstände (volle
-- Historie), Hähne aus dem Maximum, Typ = Warmanstich als Standard —
-- alles im Formular korrigierbar (steht so in den Notizen).
--
-- Sonderfälle (Ansage Daniel 05.08.2026):
--   Gspan Arosa (0006):        Buffetanstich + HeiGenie, wird vom Heineken-
--                              Monteur beim HeiGenie-Service mitgereinigt
--                              -> Rhythmus 'Selbstreiniger' (keine SBS-Uhr)
--   Blue Sushi Garden (0727):  Reinigung auf Abruf -> 'auf-Abruf'
--   Protos Oberkirch (0719):   demontiert -> Anlage status 'demontiert'
--
-- Zuordnung über heineken_nr, abgesichert auf ist_mein_kunde + operativ +
-- «hat noch keine Anlage» (exakt die 12 aus dem Befund).
-- Rückgängig: DELETE der 12 Anlagen über die Notiz-Signatur, z.B.
--   DELETE FROM anlagen WHERE notizen LIKE 'Angelegt 05.08.2026%'
--      OR notizen LIKE '%(Daniel 05.08.2026)%';

INSERT INTO anlagen (user_id, betrieb_id, typ_anlage, anzahl_haehne,
                     reinigung_rhythmus, letzte_reinigung, status, notizen)
SELECT '1e1ec2dd-7836-4d8e-8256-c5649d994ee2', b.id, v.typ, v.haehne,
       v.rhythmus, v.letzte::date, v.status, v.notiz
FROM (VALUES
  ('0245','Warmanstich',2,'Jährlich','2025-12-10','aktiv','…'),          -- Arflina, Fideris
  ('0727','Warmanstich',1,'auf-Abruf','2025-05-23','aktiv','…'),         -- Blue Sushi Garden, Gettnau
  ('0492','Warmanstich',1,'6-Monate','2026-01-07','aktiv','…'),          -- Clubhaus FC Landquart
  ('0660','Warmanstich',1,'3-Monate','2026-01-16','aktiv','…'),          -- Da Noi, Buchs
  ('0759','Warmanstich',1,'3-Monate','2026-03-27','aktiv','…'),          -- FC Meggen Clubhaus
  ('0372','Warmanstich',1,'3-Monate','2025-11-17','aktiv','…'),          -- Giodavin, Davos Platz
  ('0006','Buffetanstich',2,'Selbstreiniger','2021-08-19','aktiv','…'),  -- Gspan, Arosa
  ('0122','Warmanstich',2,'Jährlich','2025-12-10','aktiv','…'),          -- Heuberg, Fideris
  ('0712','Warmanstich',2,'6-Wochen','2026-01-12','aktiv','…'),          -- Pizzeria Tennishalle, Vaduz
  ('0385','Warmanstich',1,'6-Monate','2025-11-17','aktiv','…'),          -- Pot au Feu, Davos Platz
  ('0719','Warmanstich',1,'auf-Abruf','2026-01-08','demontiert','…'),    -- Protos, Oberkirch
  ('0774','Warmanstich',2,'6-Wochen','2026-03-02','aktiv','…')           -- Triel, Vella
) AS v(hnr, typ, haehne, rhythmus, letzte, status, notiz)
JOIN betriebe b ON b.heineken_nr = v.hnr
WHERE b.ist_mein_kunde = true AND b.status IN ('aktiv','saisonpause')
  AND NOT EXISTS (SELECT 1 FROM anlagen a WHERE a.betrieb_id = b.id);
-- (Notizen-Texte im Original-Lauf ausführlicher, siehe DB.)

-- Kontrolle danach: 0 aktive Kunden ohne Anlage
SELECT count(*) FROM betriebe b
WHERE b.ist_mein_kunde = true AND b.status IN ('aktiv','saisonpause')
  AND NOT EXISTS (SELECT 1 FROM anlagen a WHERE a.betrieb_id = b.id);
