-- 090_geschaeftsfaelle_seed.sql – Neue Geschäftsfälle (Phase 0a)
-- Ersetzt die flachen manuellen Ausgaben-Vorlagen durch die neue, schlanke
-- Geschäftsfall+Zahlungsweg-Struktur.
--
-- WICHTIG (Daniel-Entscheid 10.06.2026): NICHT löschen, sondern DEAKTIVIEREN.
--   - Geschäftsfall '1' (Reinigung Barzahlung) bleibt aktiv  → funktionale Vorlage
--     (ReinigungBuchungService, 420 Buchungen hängen daran).
--   - Alle von camt_regel referenzierten Vorlagen bleiben aktiv → produktive
--     camt-Automatik (FK RESTRICT; sonst Bruch). Umhängen auf neue GF später.
--   - auto_trigger-Vorlagen (Reinigung/Heineken/MWST) werden ohnehin nicht angefasst.

DO $$
DECLARE u RECORD;
BEGIN
FOR u IN (SELECT DISTINCT user_id FROM konten) LOOP
  -- superseded flache Ausgaben-Vorlagen deaktivieren (statt löschen)
  UPDATE buchungs_vorlagen
     SET ist_aktiv = false
   WHERE user_id = u.user_id
     AND auto_trigger IS NULL
     AND geschaeftsfall_id <> '1'
     AND id NOT IN (
       SELECT buchungs_vorlage_id FROM camt_regel
        WHERE buchungs_vorlage_id IS NOT NULL
     );

  INSERT INTO buchungs_vorlagen
    (id, user_id, geschaeftsfall_id, bezeichnung, art, hauptkonto, mwst_pflichtig, mwst_konto, erlaubte_zahlungswege, soll_konto, haben_konto, belegordner)
  VALUES
  -- AUSGABEN (Zahlungswege kasse/bank/privat/kreditor; mwst_konto Vorsteuer)
  (gen_random_uuid(), u.user_id, 'A-spesen','Spesen (Essen/Getränke)','ausgabe',5820,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'030_Spesen'),
  (gen_random_uuid(), u.user_id, 'A-tanken','Tanken Geschäftsauto','ausgabe',6200,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'040_Tanken'),
  (gen_random_uuid(), u.user_id, 'A-park','Parkgebühren','ausgabe',6270,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'050_Parkgebuehren'),
  (gen_random_uuid(), u.user_id, 'A-busse','Bussen','ausgabe',6280,false,NULL,'{kasse,bank,privat,kreditor}',NULL,NULL,'060_Bussen'),
  (gen_random_uuid(), u.user_id, 'A-fahrbew','Fahrbewilligung','ausgabe',6275,false,NULL,'{kasse,bank,privat,kreditor}',NULL,NULL,'070_Fahrbewilligung'),
  (gen_random_uuid(), u.user_id, 'A-autorep','Autoreparatur/Selbstbehalt','ausgabe',6250,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'080_Autoreperaturen'),
  (gen_random_uuid(), u.user_id, 'A-buero','Büromaterial','ausgabe',6500,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'090_Bueromaterial'),
  (gen_random_uuid(), u.user_id, 'A-material','Werkzeug/Material','ausgabe',4004,true,1170,'{kasse,bank,privat,kreditor}',NULL,NULL,'100_Werkzeug_Material'),
  (gen_random_uuid(), u.user_id, 'A-kleider','Berufskleider','ausgabe',5850,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'110_Berufskleider'),
  (gen_random_uuid(), u.user_id, 'A-kaffee','Kaffee','ausgabe',5880,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'120_Kaffee'),
  (gen_random_uuid(), u.user_id, 'A-entsorg','Entsorgung/Kehricht','ausgabe',6460,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'130_Kehricht'),
  (gen_random_uuid(), u.user_id, 'A-porto','Briefmarken/Porto','ausgabe',6510,false,NULL,'{kasse,bank,privat,kreditor}',NULL,NULL,'140_Briefmarken'),
  (gen_random_uuid(), u.user_id, 'A-telekom','Internet/Mobile (Telekom)','ausgabe',6510,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'150_Internet'),
  (gen_random_uuid(), u.user_id, 'A-software','Software','ausgabe',6560,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'170_Software'),
  (gen_random_uuid(), u.user_id, 'A-miete','Büromiete','ausgabe',6000,false,NULL,'{bank,kreditor}',NULL,NULL,'180_Bueromiete'),
  (gen_random_uuid(), u.user_id, 'A-buchf','Buchführung/Beratung','ausgabe',6530,true,1171,'{bank,kreditor}',NULL,NULL,'210_Buchfuehrung'),
  (gen_random_uuid(), u.user_id, 'A-sachvers','Sachversicherung/Haftpflicht','ausgabe',6300,false,NULL,'{bank,kreditor}',NULL,NULL,'240_Versicherung'),
  (gen_random_uuid(), u.user_id, 'A-sozvers','Sozialversicherung (AHV/BVG/SUVA)','ausgabe',5700,false,NULL,'{bank,kreditor}',NULL,NULL,'230_Sozialversicherungen'),
  -- FIXE Geschäftsfälle (explizit Soll/Haben)
  (gen_random_uuid(), u.user_id, 'F-fran-rg','Franchise Rechnung (Heineken)','fix',6301,true,1170,'{}',6301,2000,'190_Franchisegebuehr'),
  (gen_random_uuid(), u.user_id, 'F-fran-zg','Franchise Zahlung','fix',NULL,false,NULL,'{}',2000,1020,'190_Franchisegebuehr'),
  (gen_random_uuid(), u.user_id, 'F-bankgeb','Bankgebühren','fix',NULL,false,NULL,'{}',6940,1020,'200_Bankgebuehren'),
  (gen_random_uuid(), u.user_id, 'F-steuer-rst','Steuer-Rückstellung (Jahresende)','fix',NULL,false,NULL,'{}',8900,2208,'300_Steuern'),
  (gen_random_uuid(), u.user_id, 'F-steuer-zg','Steuer-Zahlung','fix',NULL,false,NULL,'{}',2208,1020,'300_Steuern'),
  (gen_random_uuid(), u.user_id, 'F-steuer-rk','Steuer-Rückerstattung','fix',NULL,false,NULL,'{}',1020,2208,'300_Steuern'),
  (gen_random_uuid(), u.user_id, 'F-debverlust','Debitorenverlust (netto)','fix',NULL,false,NULL,'{}',3805,1100,'019_Abschreibungen'),
  (gen_random_uuid(), u.user_id, 'F-debverlust-mwst','Debitorenverlust MWST-Rückholung','fix',NULL,false,NULL,'{}',2200,1100,'019_Abschreibungen'),
  (gen_random_uuid(), u.user_id, 'F-delkredere','Delkredere bilden','fix',NULL,false,NULL,'{}',3805,1109,'019_Abschreibungen'),
  (gen_random_uuid(), u.user_id, 'F-corona-kredit','Corona-Kredit Bezug','fix',NULL,false,NULL,'{}',1020,2500,'610_Coronakredit'),
  (gen_random_uuid(), u.user_id, 'F-corona-tilg','Corona-Kredit Rückzahlung','fix',NULL,false,NULL,'{}',2500,1020,'610_Coronakredit'),
  (gen_random_uuid(), u.user_id, 'F-kae','Kurzarbeit/EO-Eingang','fix',NULL,false,NULL,'{}',1020,2276,'600_KAE_Corona'),
  (gen_random_uuid(), u.user_id, 'F-haertefall','Härtefallgelder','fix',NULL,false,NULL,'{}',1020,8510,'620_Haertefall'),
  (gen_random_uuid(), u.user_id, 'F-gruend-kapital','Gründung Stammkapital','fix',NULL,false,NULL,'{}',1020,2800,'990_Firmengruendung'),
  (gen_random_uuid(), u.user_id, 'F-gruend-kosten','Gründungskosten','fix',6550,true,1170,'{}',6550,1020,'990_Firmengruendung');
END LOOP;
END $$;
