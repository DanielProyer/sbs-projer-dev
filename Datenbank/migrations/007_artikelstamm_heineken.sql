-- Heineken Artikelstamm - Seed-Daten
-- Quelle: SBS_Projer_Hauptexcel.xlsm, Sheet 'Artikel Heineken'
-- 885 Artikel, Stand 12.02.2026
-- Ausfuehren NACH material_kategorien Seed

DO $$
DECLARE
  v_user_id UUID := '1e1ec2dd-7836-4d8e-8256-c5649d994ee2';
BEGIN

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.02', 'Rührwerk mit Pumpe 5.2m zu CR 4 - CR7', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.03', 'Pumpe Samec 11m zu V100E und H100E', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.04', 'Rührwerkmotor Gamko zu BKG 50/54', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.05', 'Papst-Lüfter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.06', 'Kombiregler TECG 2000', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.07', 'Raumthermostat zu Fasskühler', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.08', 'Anlaufkondensator', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.08', 'Anlaufkondensator', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.09', 'Anlaufkondensator Rührwerkmotor 2 MF', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.10', 'Anlaufkondensator Rührwerkmotor 7 MF', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.11', 'Thermostat Wasserbad zu FK-MU38 Python', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.12', 'Pumpe Gamko SPC44/23m inkl. Stecker', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.13', 'Pumpe Gamko SPC42/12m inkl. Stecker', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.14', 'Pumpe Gamko SPCS1/5m inkl. Stecker', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.15', 'Ventilatormotor zu Safari/Tapstar/FK-MU', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.16', 'Vent. Motor zu BKG 50/54 + FK-MU 38 Raum', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.17', 'Thermostat zu Gamko Kühlgeraten', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.18', 'Pumpe Gamko zu Safari UT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.19', 'Startrelais zu Tapstar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.20', 'Startrelais zu Safari', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.21', 'Startrelais zu BKG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.22', 'Rührwerkmotor zu Tapstar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.23', 'Kompressor zu Bierbar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.24', 'Ventilator Raumkühlung zu Bierbar 0.8 A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.25', 'Ventilatormotor zu Bierbar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.26', 'Thermostat zu Bierbar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.27', 'Rührwerkmotor zu HappyTap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.28', 'Startrelais zu Happy-Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.29', 'Rührwerkmotor zu LUX 152 OT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.30', 'Lüftermotor zu Happy-Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.31', 'Trockner zu Happy-Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.32', 'Anlasskondensator zu Gamko BKG 50/54', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.33', 'Platine zu Kühleinheit FK-MU 38 Python', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.36', 'Thermostat zu H60 / V100 GE / H100 GE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.38', 'Fühler zu Eliwell 961 (FKMU 25)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.39', 'Therm. Dixell zu FKMU 25 + Fühler Serrco', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.40', 'Startrelais zu S-38', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.41', 'Klixon zu S-38', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.42', 'Kondensator zu S-38', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.44', 'Temperaturfühler zu CR 4-8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.45', 'Ther. Ranco K50 H1122 Linus CR 4-7 + Lotus', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.46', 'Eisb.-Temp.Reg.CR 4-8 bis Baujahr 2009', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.48', 'Regl-Box Kompl. Kom-Schaltk. CR4-8-Bj.09', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.49', 'Ther. Elektr.Dix XR02CX FKMU25kompl.Gamko', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.50', 'Eisbankühler 3 Pin UK 1.2m', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.51', 'Temperaturfühler NTC zu H75 Glykol', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.52', '707047 - Ice bank probe Dinfer', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Kühlschlange
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.72', 'Kühlschlangensatz zu CR 4', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kühlschlange')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.73', 'Kühlschlangensatz zu CR 5 und 6', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kühlschlange')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1800.74', 'Kühlschlangensatz zu CR 7', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kühlschlange')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierkühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.03', 'Bierkühler HGOGE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.43', 'Startrelais zu OT Lux 152 Code 353007', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierkühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.44', 'LUX 152 OT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.45', '838 Bierkühler 2-leitig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.50', 'Kühleinheit FK-MU25 Alu-Zink', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.51', 'Kühleinheit FK-MU38 Python Alu-Zink', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Fasskühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.52', 'Fasskühler FK2 schwarz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.54', 'Fasskühler FK4 schwarz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.56', 'Fasskühler FK6 schwarz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.58', 'Fasskühler FK8 schwarz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.59', 'Steg zu FK 6 und 8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.60', 'Türdichtung zu FK 2 / PK 4', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.61', 'Türdichtung zu FK 6', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.62', 'Türdichtung zu PK 8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.63', 'Magnetverschluss zu Fasskühler', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierkühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.64', 'BKG 50/54L mit geschlossenem Wasserbad', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.65', 'Sat. Kühler 54L horizontal 4 Leitungen', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.66', 'Kühleinheit FK-MU 25 Sat.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Fasskühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.68', 'Fasskühler 1 Türig H870 / B602 /T565', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Fasskühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.70', 'Zusatzl. 20 S38 (Satz a 2 Bierleitungen)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.71', 'Zusatzl. H100E + V100E Set a 2 Leit. 10m', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierkühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.80', 'Beercooler V100GE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.81', 'Beercooler H100GE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.91', 'CR70 V2 1/2 PS UTK BUK', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '20.1900.99', 'OT Festkühler Berg TBD 602 2-Leitig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.01', 'Boosterkühler', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.02', 'F85G Extra Cold Gefrierschrank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.03', 'Fountain Säule Extra Cold kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.04', 'Plastikplakette HElNEKEN Extra Cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.07', 'Tablar 35/35 zu Boosterkühler', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.08', 'Alu-Konsole 300/350', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Gläserdusche/Tropfschale
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.09', 'Tropfschale Celli V2A 400/400 mit Ablauf', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.10', 'Tropf. Cel. V2A 400/400 + Abl.+Spr.Düse', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.11', 'Ablaufblindzapfen zu Tropfschale Celli', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.12', 'Verbinder 10/13mm Edelstahl gerade', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.13', 'Verbinder 10/6mm Edelstahl gerade', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.14', 'Umkehrbogen Edelstahl 12mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Gläserdusche/Tropfschale
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.15', 'Tropftasse Plexi zu HElNEKEN Extra Cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.16', 'Kondenswassertropfschale Gummi schwarz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.17', 'Lüftermotor zu GcoI-Kühler TE-25/10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.18', 'Therm. Eliwell zu Glycol-Kühler TE-25/10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.19', 'Kondensator 80mF zu TE-25/10 Glycol', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.20', 'Pumpe EBM 6.5m zu Glycol Kühler Celli', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.23', 'Holzböckli 40/40/10 zu Glycolkühler TE25', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.24', 'Bage Holder inkl. Kabel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.25', 'llluminatet Logo Served Extra Cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.26', 'Bierleitung zu Fountainsäule Extra cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.30', 'Instant Glass freezer HElNEKEN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierkühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.40', 'Glykolkühler V-100 EG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.41', 'H75E Glycol', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.45', 'Adapter zu Fauntain Extra cold 30 x 5/8''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.46', 'Temp. Anz. zu Fountain Extra cold Cel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.47', 'Bel. HE Served X cold zu Fountain-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.48', 'Sock.H4mm zu Foun.S.Xcold zu Aufl.Tr.Sch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.49', 'Abl Bl. K. St. verch. zu Fountain-S. Xcold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.50', 'Kon.Box 220V/30 Hz Fountain-Säule X cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.51', 'Transf. Kont.Box zu Fountain-SäuleX Cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.60', 'HighLight kmpl. zu Zapfhahn Celli', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.90', 'Glykol Kanister a 4 Liter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '22.1900.98', 'Cover zu Säule Extra Cold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.00', 'Abd.Schei.chromatisie. D144mm+B.Dmm2mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.01', 'U-Sch CR1.4301 D=144mm mit Boh D50mm2mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.02', 'Abd.Pl. 500x180mm Edelstahl o. Bohrungen', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.03', 'Abdeckplatte V2A 500x180 mit Bohr. 1x50', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.04', 'Abdeckplatte V24 500x180 mit Bohr. 2x50', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.05', 'Abdeckplatte V2A 500x180 mit Bohr. 3x50', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.06', 'Lochabdeckung V2A D 90 mm inkl. Befesti.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.08', 'Lochabdeckung 150 x 100 x 2 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.10', 'Bel. LED zu Falco 2-leitig+Cobra ab 2010', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.11', 'Beleuchtung zu Laser-Säule LED', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.12', 'Bel. Sockel Lasersäule LED+Trafo kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.13', 'Beleuchtung LED zu Cobra und Falco-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.14', 'Beleuchtung LED zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.15', 'Bel. LED ﬂexibel zu Cobra + Falco-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.16', 'Kabelsatz lang zu Cobra, Falco+Tubesäule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.17', 'Kabelsatz kurz zu Cobra-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.20', 'Pl.H. Chr. LED zu Cobra 1H. Bel. kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.21', 'Pl.H. Chr. LED zu Cobra 2H. Bel. kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.30', 'Trafo zu Cobra 1 leit. Tube + Falcosaule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.31', 'Trafo zu Cobra 2 und 3 leitig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.34', 'Rosette sohwarz gesattelt 47x45', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.35', 'Rosette schwarz gesattelt 57x45', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.36', 'U-Scheibe PVC f. Zapfhahn Rundsäule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.39', 'Werkzeug f. Halteelement (John Guest)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.40', 'Gerade -Verbinder JG 3/8'' 9.5mm-9.5mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.41', 'Ger.Red.Ver. JG 3/8''-5/16‘ 9.5mm-8.0mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.42', 'Gerader-Reduzier-Verbinder JG 12mm-8mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.43', 'Gerader-Verbinder JG (8mm-8mm)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.48', 'Sicherungsring rot JG 8mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.49', 'Sicherungsring rot JG 3/8''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.50', 'WinkeI-Red.Ver. JG 3/8''-5/16''9.5mm-8.0mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.51', 'Winkel-Reduzier-Verbinder JG 12mm-8mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.52', 'Winkel-Verb. JG 3/8''-3/8''9.5mm-9.5mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.53', 'Umkehrbogen JG 1/2'' (12.7mm)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.54', 'Winkelklemmleiste 9.5 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.55', 'Umkehrbogen JG 3/8'' (9.5mm)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.56', 'Winkel-Verbinder 1/2'' (12.7mm)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.57', 'Rohrsteckdorn 1/2'' - 3/8''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.58', 'Dreifachverteiler JG 1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.59', 'Verschluss-Stopfen JG 1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1800.60', 'Gerade Verbinder JG (12.7mm - 12.7mm)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.0A', '6-Loch Balken gold inkl. Abdeckungen', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.0C', '4-Loch Balken gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.0D', '3-Loch Balken V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.0E', '3-Loch Balken gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.01', 'HeiTube 1 way flat', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.02', 'HeiTube 1 way angular', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.03', 'Arrow 1 way', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.04', 'Europe 1 way', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.05', 'Europe 3 way', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.06', 'Europe 4 way', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.07', 'Europe 5 way', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.08', 'Lasersäule HEINEKEN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.11', 'Cobra Säule verchr. 1-leitig LED Bel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.15', 'Tube Säule V2A 1-leitig mit Beleuchtung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.16', 'Tube Säule matt 1—leitig mit Beleuchtung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.17', 'Lasersäule HALDENGUT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.18', 'Roversäule HEINEKEN mit Bel. kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.19', 'Cobra Säule verchr. 4-leitig ohne Bel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.21', 'Falco Säule verchr. 2-leitig mit Bel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.22', 'Fount. Säule verchr.1-leitig mit Bel. HE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.41', 'Mlsa Säule Eichhof 2-leitig mit Bel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.46', 'Balkensäule 450 mm verg. HALDENGUT 3 H-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.47', 'Balkensäule 450 mm verg. HALDENGLIT 4 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.48', 'Balkensäule 450 mm V2A HALDENGU" 3 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.49', 'Balkensäule 450 mm V2A HALDENGU 4 H-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.64', 'Keramiksäule verg. ''Amstel rot'' 1 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.65', 'Keramiksäule verg. ''Amstel rot'' 2 H', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.84', 'Keramiksäule verg. HEINEKEN grun1 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.85', 'Keramiksäule verg. HEINEKEN grtin 2 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.86', 'Balkens. 450 mm verg. HEINEKEN griin 3 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.87', 'Balkens. 450 mm verg. HEINEKEN grUn 4 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.88', 'Balkens. 450 mm V2A HEINEKEN grdn 3 H-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.89', 'Balkens. 450 mm V2A HEINEKEN grUn 4 H-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1900.90', 'Reinigungstank PVC mit Überdruckventil', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1901.72', 'Umrüst-Satz für Säulen V2A 1 H-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '25.1901.73', 'Umrüst-Satz für Säulen V2A 2 H-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.00', 'Plastikplakette CALANDA', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.01', 'Plastikplakette HEINEKEN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.02', 'Plastikplakette FOSTER''S', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.03', 'Plastikplakette ITTINGER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.04', 'Plastikplakette HALDENGUT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.05', 'Plastikplakette ERDINGER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.06', 'Plastikplakette Strongbow', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.07', 'Plastikplakette Murphy''s Stout', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.07A', 'Plastikplakette Murphy''s Red', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.08', 'Plastikplakette CALANDA lngredienti nur für Italien', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.09', 'Plastikplakette Uni weiss', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.10', 'Plakette CALANDA zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.11', 'Plakette HEINEKEN zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.12', 'Plakette AMSTEL zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.14', 'Plakette HALDENGUT zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.15', 'Plakette ERDINGER zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.16', 'Plakette CALANDA Mezza 2.5 zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.17', 'Plakette CALANDA Zwickel zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.18', 'Griff AFFLIGEM', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.19', 'Acryl Griff ZIEGELHOF', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.20', 'Acryl Griff CALANDA', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.21', 'Griff BIRRA MORETTI', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.22', 'Griff HEINEKEN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.23', 'Acryl Griff ITTINGER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.24', 'Acryl Griff HALDENGUT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.25', 'Acryl Griff ERDINGER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.26', 'Acryl Griff CALANDA Mezza 2.5', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.27', 'Acryl Griff CALANDA Zwickel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.28', 'Acryl Griff CALANDA ALC. 5.2% Vol.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.29', 'Acryl Griff schwarz ohne Logo', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.30', 'Linse HEINEKEN Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.31', 'Linse CALANDA Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.32', 'Linse HALDENGUT Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.33', 'Linse EICHHOF Braugold Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.34', 'Linse EICHHOF Lager Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.35', 'Linse ITTINGER Klosterbrau Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.36', 'Linse EICHHOF Kloster Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.37', 'Linse ERDINGER Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.38', 'Linse uni weiss Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.39', 'Linse ZIEGELHOF Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.40', 'Linse ZIEGELHOF Zwickel Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.41', 'Linse BIRRA MORETTI Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.42', 'Linse EICHHOF Hubertus Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.43', 'Linse CALANDA Alcool 5.2% Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.44', 'Linse MURPHY''S IRISH Stout Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.45', 'Linse MURPHY''S IRISH Red Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.46', 'Linse STRONGBOW Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.47', 'Linse FOSTER''S Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.48', 'Linse PAULANER Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.49', 'Linse GUINNESS Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.50', 'Linse DESPERADOS Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.51', 'Linse Beer of the Month Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.52', 'Linse NEWCASTLE Brown Ale Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.53', 'Linse AFFLIGEM Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.54', 'Linse CLAUSTHALER Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.55', 'Linse SAGRES Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.56', 'Lense Erdinger Urweisse', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.58', 'Linse Craft Beer Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.59', 'Linse CALANDA Lager Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.60', 'Linse CALANDA Braugold Illuminated', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.80', 'Acryl Griff CALANDA Lager', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.81', 'Acryl Griff CALANDA Edelbräu', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '26.1900.90', 'Lens holder d64 rear connection', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.03', 'Plastikplakette EICHHOF Kloster', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.05', 'Plastikplakette EICHHOF Hubertus', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.06', 'Plastikplakette EICHHOF Alkoholfrei', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.10', 'Plakette EICHHOF LAGER zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.12', 'Plakette EICHHOF BRAUGOLD zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.13', 'Plakette EICHHOF KLOSTER zu Tube-Säule', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.20', 'Acryl Griff EICHHOF Lager', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.22', 'Acryl Griff EICHHOF Braugold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.23', 'Acryl Griff EICHHOF Kloster', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.24', 'Acryl Griff EICHHOF Hubertus', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.30', 'Logoplatte EICHHOF zu Misa 2-Ieitig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.32', 'Logopl. EICHH. Braugold zu Misa 1-Ieitig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, 'E26.1900.33', 'Logopl. EICHH. Kloster zu Misa 1-Ieitig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.07', 'Ros. schw. 64 - 24 zu Balken Cel. kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.08', 'Rosette schwarz 64 - 32 zu Balken Celli', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.09', 'Dist.Hül. zu HS-Eurostar o.Bohr.verchr.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.10', 'Dist.Hül. zu HS-Eurostar o. Bohr. verg.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.11', 'Werbepanel zu Rundsäule Alu light HE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.12', 'Werbepanel zu Rundsäule Alu light AMSTEL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.15', 'Werbepanel zu Rundsäule Alu light ER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.25', 'Anschl.Nip. ger. 3mm TDS kompl. + Mutter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.26', 'Schlauchb. 90“ 3mm TDS kompl. mit Mutter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.27', 'Dichtungssatz CelIi-Hahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.28', 'AuslauftüIIe Plastic CeIIi-Hahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.29', 'Auslauftülle Inox CelIi-Hahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.31', 'Stutzen 5/8''x47x10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.32', 'Stutzen 5/8''x35x10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.33', 'Dichtungssatz zu Zapfhahn Corn. BT 2000', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.34', 'Kompensator zu Zapfhahn BT 2000', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.36', 'Plakette m.Halter HK Gold for 2 H. Cobra', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.37', 'Plakette m.Halter HK V2A for 2 H. Cobra', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.38', 'Schlauchb. 90‘” 6mm TDS kompl. mit Mutter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.39', 'AnschI-Nip. ger. 6mm TDS kompl. + Mutter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.40', 'Dichtung TDS Hytrel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.41', 'Distanzring V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.42', 'Distanzring Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.44', 'Plakettenhalter Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.59', 'Plakette mit Halter HALDENGUT Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.60', 'Plakette mit Halter HALDENGUT V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.61', 'Plakette mit Halter HEINEKEN Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.62', 'Plakette mit Halter HEINEKEN V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.63', 'Plakette mit Halter AMSTEL Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.64', 'Plakette mit Halter AMSTEL V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.78', 'Plakette mit Halter IT Kl. Bräu Gold - 2 H. Cob.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.79', 'Plakette mit Halter IT Kl. Bräu V2A - 2 H. Cob.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.80', 'Plakette mit Halter Mr. Lr. Red V2A - 2 H. Cob.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.81', 'Plakette mit Halter Mr. Lr. Red Gold - 2 H. Cob.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.82', 'Zwischenstück Plakettenhalter V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.83', 'Zwischenstück Plakettenhalter Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.86', 'Plakette mit Halter Hein. V2A - 2 H. Cob.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.89', 'Plakette mit Halter ERDINGER Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.93', 'S-Anschluss fUr Plakettenhalter V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.94', 'S-Anschluss f0r Plakettenhalter Gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.95', 'Plakette uni weiss', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.96', 'Federhalterschraube V2A zu Celli-Hahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1800.98', 'Kompensator zu Celli-Hahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.00', 'Bierhahn HS-Eurostar 40mm V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.01', 'Bierhahn HS-Eurostar 55mm V2A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.02', 'Bierhahn HS-Eurostar 40mm verg.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.03', 'Bierhahn HS-Eurostar 55mm verg.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.04', 'Bierhahn Celli verchr. 5/8''x55x10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.06', 'Bierhahn Celli verchr. 5/8''x35x10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.07', 'Bierhahn Celli verg. 5/8''x55x10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.09', 'Bierhahn Celli verg. 5/8''x35x10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.10', 'Bierhahn Celli 5/8''x35x10 Inox', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.13', 'Bierhahn Celli 5/8''x35x10 lnox verg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.15', 'Bierhahn. Celli Spark. mit Komp. 5/8‘x3', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '30.1900.20', 'Bierhahn Cornelius BT 2000 gold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Gläserdusche/Tropfschale
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1800.01', 'Spritzdüse lang kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1800.02', 'Spritzdüse kurz kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1800.04', 'Spülkreuz PVC', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.01', 'ETS 1 V2A m. Spülkreuz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.02', 'ETS 2 V2A mit Spülkreuz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.03', 'ETS 3 V2A mit Spülkreuz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.04', 'ETS 4 V2A mit Spülkreuz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.05', 'Tropfsch. Edel.+Gläserd.+Abﬂ. 60x40x4cm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.06', 'Tropf. V2A 800/400/40 +Abfl. +Glä.Dusche', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.13', 'Auflegetropfschale Celli V2A 300x180x30', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.14', 'Auflegetropfschale Celli V2A 500x220x30', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.15', 'Auflegetropfschale Celli V2A 800x220x30', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.24', 'Auﬂegetropfschale 200x200', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.25', 'Tropfsch. kom pl. mit Halterung OT Berg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.26', 'Einbau-Gläserspülsch. 170 mm m. SpüIkr.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.27', 'Tropfschale zu Tapstar inkl. Tropfblatt', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.28', 'Tropfschale zu Safari OT inkl. Tropfbl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '35.1900.29', 'Sockel m.AbI.Ver.Foun.-S zu Aufl.Tropfs', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Gläserdusche/Tropfschale')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.01', 'Kugelsicherung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.02', 'Kugelventil', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.04', 'Bierdichtung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.05', 'Gehäusedichtung O-Ring', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.06', 'Bieranschluss kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.07', 'Hauptdichtung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.08', 'CO2 Abschluss-Satz kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.09', 'Llppenventil', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.10', 'Mit Schlauchbogen V2A kl. Radius 4mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.11', 'Rändermutter 1/2'' zu Micro-Matic', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.13', 'Reinigungsadapter Bier Endstück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.18', 'Torpedo ''weiss''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.19', 'Reinigungsadapter Bier Durchgehend', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.20', 'Arbeitsman. 0 - 7 / 10 bar zu DRV M-M', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.21', 'Inhaltsman. 0 - 250 bar zu DRV M-M HD', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.22', 'CO 2 Filter zu DRV Micro-Matic', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.23', 'CO2 Filterhalter zu DRV Micro-Matic', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1800.24', 'Adapter M10x1 zu DRV Mioro-Matic', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.01', 'Zapfkopf Micro-Matic MF-S Niro', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.02', 'Zapfkopf Sagres DK 1/2" x 1/2"', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.05', 'Reinigungsadapter Wein', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.06', 'Micro-Matic ''Wein''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.07', 'Reinigungsadapter FISCHER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.08', 'M-M Fisch., Foster''s, Paul., + Strongb.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.09', 'Micro-Matic mit integriertem Fob-Stop', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.10', 'Zapfkopf Micro-Matic MF-L OVA', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.11', 'Zapfkopf Celli V2A Spez. für Fasskoppel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.12', 'Ergogriff F1', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.13', 'Stift zu Zapfkopf Micro-Matic', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.14', 'FOB STOP Kunststoff mit JG Kartusche', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.14', 'FOB STOP Kunststoﬁ mit JG Kartusche', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '40.1900.15', 'FOB STOP BFS 5/8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1800.01', 'HD-Schlauch 120 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1800.03', 'FI. Anschluss CO2 Handanzug', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1800.04', 'C02 O-Ring holder zu OT Berg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1800.07', 'CO2-Schlüssel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1800.08', 'Stickstoff-Schlüssel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.01', 'DRV Micro-Matic 1-er Wandm. kom pl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.02', 'DRV 1-er FLAnschluss kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.03', 'DRV Sato 2-er FLAnschluss m.Schutzb.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.05', 'DRV M-M Prem. Plus 2er Wandmo HD-Schl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.06', 'Zw.mind. Prem. Plus 1er W.o. HD-Schlauch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.07', 'DRV Sato 3-er Wandmm. HD-Schlauch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.08', 'DRV Sato 3-er Wandmo HD-Schlauch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.09', 'DRV Umrüstsatz zu Safari OT 0. HD Schl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.10', 'Verbindungsstück 1/2''-1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.11', 'Sicherheitskappen zu Premium Plus', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '45.1900.12', 'Mutter, Nippel und Dichtung zu DRV', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.00', 'Branding Kit CFT Tap Heineken', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.02', 'Branding Kit CFT Tap Calanda', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.04', 'Branding Kit CFT Tap Haldengut', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.06', 'Branding Kit CFT Tap Eichhof Lager', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.08', 'Brarding Kit CFT Tap Eichhof Braugold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.10', 'Brarding Kit CFT Tap lttinger', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.12', 'Brar ding Kit CFT Tap Eichhof Klosterbräu', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.14', 'Branding Kit CFT Tap Erdinger', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.16', 'Branding Kit CFT Tap Ziegelhof', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.18', 'Branding Kit CFT Tap Birra Moretti', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.20', 'Branding Kit CFT Tap Eichhof Hubertus', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.22', 'Branding Kit CFT Tap uni weiss', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.24', 'Branding Kit CFT Tap Forster''s', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.26', 'Branding Kit CFT Tap Paulaner', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.28', 'Branding Kit CFT Tap Beer of the Mont', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.30', 'Branding Kit CFT Tap Affligem', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.32', 'Branding Kit CFT Tap Sagres', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.34', 'Branding Kit CFT Tap Desperados', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.35', 'Branding Kit CFT Tap Craft Beer', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.36', 'Branding Kit CFT Tap ERDINGER DUNKEL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.37', 'Branding Kit CFT Murphy''s red', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.38', 'Branding Kit CFT Murphy''s stout', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.39', 'Brand''ng Kit CFT Tap ERDINGER URWEISSE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.40', 'Branding Kit CFT Tap Strongbow', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.41', 'Branding Kit CFT Tap Calanda Lager', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.42', 'Branding Kit CFT Tap Calanda Braugold', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1800.90', 'Ers. Griff V2A zu Zapfh. Heigen. o. Logo', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.00', 'Cooled lnstulation Tap (CIT) Compensator', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.05', 'Bone Column with HeiGenie interface', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.06', 'Fount. Col. 1-line with HeiGenie interf.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.07', 'Heitube Col.1-line Flat+HeiGenie interf.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.08', 'Heitube Col.1-line Ang.+Heigenie interf.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.09', 'Fountain Column extra cold HFEC_CFT_lNT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.13', 'T-bar 3 leitig chrome CFT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.15', 'T-bar 5 leitig chrome CFT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.21', 'Python 1 line beer HeiGenie flow and back', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.22', 'Python 2 line beer HeiGenie', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.23', 'Python 3 line beer HeiGenie', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.25', 'Python 1 line beer HeiGenie + 2 other', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.26', 'Python 2 line beer Heigenie + 2 other', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.27', 'Python 3 line beer HeiGenie + 2 other', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.28', 'Tube 6x9,5mm PE w. 2 red stripes gasline', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.30', 'Python clamp', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.40', '18mm x 1/2‘ x 3/8'' Coaxial Keg Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.41', 'Stem Elbow 1/2'' - 1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.42', '18mm x 3/8'' Coaxial Elbow Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.43', '18mm x 3/8'' Coaxial Straight Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.44', '18mm Equal Straight Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.45', 'Equal Elbow 1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.46', '1/2'' Straight Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.47', '18mm x 3/8'' Coaxial Cooler Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.48', '18mm Barbed Spigot Safety Clip', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.49', 'Tube to hose Stem 1/2'' - 1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.50', 'Plug 1/2''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.51', '1/2'' Equal 2-Way Divider', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.52', 'Reducing Elbow 3/8'' - 5/16''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.55', 'Steckverb. m.|nnengew. 3/8''x1/2'' zu DRV', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.70', 'V1OOGE CFT CH 50l-8/7(3x18+2x9m)SA-4x7m', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.71', 'H1OOGE CFT CH 50l—8/7(3x18+2x9m) SA-4x7m', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.72', 'H60GE CFT Heigenie', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.77', 'lsolierschlauch schwarz NBR 19/76', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.78', 'lsolierschlauch schwarz NBR 13/64', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.80', 'Dispense Head - S-Type HeiGenie specifi.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.81', 'Cooled Insulated Grip (CIG)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.82', 'Zapfkopf SAGRES DK 3/8JG-3/8x1/2 SST', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.90', '3/8'' Coaxial Collet Relase Tool', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.91', 'Tube in Tube Cutter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.92', 'Mini Stiro Folie 100mm breit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.93', 'Steuerkabel TT-Flex 2 x 0.5mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.94', 'lsolierband PVC Tesaﬂex 9e', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.95', 'Pump Samec 12.4m for H/V100GE HG coolers', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.96', 'Kabelbinder schwarz 500 x 12.5mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.97', 'Kabelb. Schw. 136x3.6mm Sack a 100 Stuck', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.98', 'Auslauftülle zu Cooled lnstulation Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.1900.99', 'Hände-Desinfektions-Gel 3M Nexcare 500ml', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.2000.00', 'Zapfkopf Gehäusedichtung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.2000.01', 'Bierabsperring / Korbzapfkopf', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.2000.02', 'O-Ring D. 18.72 x 2.62 SH 85A', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.2000.03', 'Käfig fur Auslaufsicherung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.2000.04', 'Kugel D. 12 ftir Auslaufsicherung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '55.2000.05', 'Auslauftülle Stout zu CIT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '65.1900.00', 'F.O.S. Fassumschaltsystem kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfkopf
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '65.1900.01', 'Zapfkopf HTK zu F.O.S.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfkopf')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- David
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.00', 'David Classic Green kompl. mit Branding', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.01', 'David Green Fridge 220V/50Hz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.02', 'Rollwagen David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.03', 'Tropfschale David Basis-Edelstahl', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.04', 'Zapfsäule Bone Brandable', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.05', 'Zapfhahn David 15”', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.06', 'Plastik Set für David Kühlschrank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.07', 'Zapfkopf David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.08', 'C02 Reduktionsventil David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.09', 'C02 Niederdruck-Schlauch David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.10', 'Kühlschrank David Twin Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.13', 'Tropfschale David Twin Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.14', 'Flaschenhalter David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.15', 'Co2-Schlauch zu David 60 Rolle a 50 M', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.16', 'Säule Extra cold zu David XL kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.19', 'David XL Green Fridge Single Tap freist.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.20', 'David XL Green Fridge Twin Tap freist.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.21', 'David XL Green Fridge Single Tap Einbau', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.22', 'David XL Green Fridge Twin Tap Einbau', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.29', 'Kabel 2-p Säule David lllu. Wiring 2 Wir', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.30', 'Thermostat Nr. 230 zu David 60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.31', 'Fan Motor Nr. 30 zu David 60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.32', 'Compact Fan (Säule)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.33', 'Compact Fan (Innenraum)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.34', 'Trafo UKU1400-10 zu David 60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.35', 'Plastik Set zu Kühlschr. David Twin Tap', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.36', 'David powercord Swiss', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.37', 'Thermostat David zu Mod. China', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.38', 'Verb. PVC Thermo.-Regulierknopf David 60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.39', 'Regulierknopf zu David 60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.40', 'Adapter 220V connection 5V (1 Spong)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.41', 'David XL Green Fridge 220V/50Hz', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.42', 'David XL Wheel card', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.43', 'Triptray David DXL Green Single', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.44', 'Triptray David DXL Green Twin', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.45', 'DC/EC/FT Illumination: wiring (2 wires)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.46', 'DXL Illumination Wire Connector', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.47', 'Adapter 220V connection 5V', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.68', 'Stickerset zu David XLG HEINEKEN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.69', 'Druckanzeiger David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.70', 'lnstallationskit David Counter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.71', 'Installationskit David (Werkzeug)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.72', 'Zentralrohr zu David Mobil 130mm kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.73', 'Zentralrohr zu David Einbau 250mm kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.74', 'Zentralrohr zu David Einbau 450mm kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.75', 'Back panel David DXL Green', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.76', 'Temp. Fühler GKPV 6520-11 zu David XLG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.77', 'DXLG Interface IP 2 fridge parts', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.78', 'DXLG FIügel zu Lüftermotor Kondenser', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.79', 'DXLG Flügel zu Lüftermotor Zirkulation', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.80', 'Lüfter Innenraum zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.81', 'Lüfter saule 20 David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.82', 'Lüfter Condenser zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.83', 'Anlassrelais (Starter kit) zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.84', 'Trafo AC-DC 240VAC - 12VDC zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.85', 'Lichtgehäuse Unterteil zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.86', 'Birne 15W 230V E14 zu David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.87', 'Türmagnet mit Halterung zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.88', 'Thermostat zu David CG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.89', 'Türk. Schalter Comus David Classic green', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.90', 'DXLG Türkontaktsohalter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.91', 'DXLG Türmagnet ohne Halterung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.92', 'DXLG Magnetvent. 230V for hot gas defr.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.93', 'DXLG Kondenserlüfter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.94', 'DXLG Anlaufrelais', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.95', 'DXLG Care! contr.kit ThermPlatine+Kabe|', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.96', 'DXLG Zirkulationslüfter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.97', 'DXLG Trafo 12VDC', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.98', 'DXLG Kühlteil kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '70.1900.99', 'Stickerset zu David Classic green HE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='David')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.01', 'Trookenpython 2 x 6.7mm mit Kabel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.02', 'Trockenpython 4 x 6.7mm mit Kabel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.03', 'C02 Dichtung (O-Ring) zu OT Berg JG 2015', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.04', 'Trockenpython 8 x 6.7mm mit Kabel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.05', 'Trockenpython 10 x 6.7mm mit Kabel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.06', 'Leuchtenklemme sohwarz 12P, 2.5mm2', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.07', 'Trockenpython 6 x 6.7mm mit Kabel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.17', 'Pythonklammer Stahl verz. 2-lappig', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.18', 'Rücklaufschlauch spez. 1O / 2.5mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.19', 'Flexlayer III 6.7x12mm rot', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.20', 'Etiketten ''Aligal 2'' Rolle a 500 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.21', 'Etiketten ''Aligal 13'' Rolle a 500 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.22', 'Raufilam 10/3 (Gtränkeschlauf)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.23', 'Super-Flexlayer 4x8mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.24', 'Flexlayer III 7.0 x12mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.25', 'Stauleitung 2,5 mm (Vinnylan)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.28', 'Silikon transparent', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.29', 'Steckdosenl. Schw. 4 x Typ 13 / 3 Meter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.30', 'Stufenl. Ohr Kl. 008.0-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.31', 'Stufenl. Ohr Kl. 008.7-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.32', 'Stufenl. Ohr Kl. 009.0-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.33', 'Stufenl. Ohr Kl. 010.0-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.34', 'Stufenl. Ohr Kl. 010.9-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.35', 'Stufenl. Ohr Kl. 013.3-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.36', 'Stufenl. Ohr Kl. 014.0-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.37', 'Stufenl. Ohr Kl. 014.5-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.38', 'Stufenl. Ohr Kl. 017.5-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.39', 'Stufenl. Ohr Kl. 019.2-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.40', 'Stufenl. Ohr Kl. 021.0-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.41', 'Stufenl. Ohr Kl. 022.6-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.42', 'Stufenl. Ohr Kl. 024.1-505R a 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.43', 'Briede 20/25mm zu Paguaschlauch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.44', 'Refraktometer', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.45', 'lsolierband schwarz 33 m l 19 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.46', 'Isolierband schwarz 25 m I 30 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.47', 'lsolierband schwarz 25 m l 50 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.48', 'Brunox (Turbo Spray)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.49', 'Klebeband Doppelseitig gelb B.50 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.50', 'Kabelbinder 298 x 4.8mm e 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.51', 'Kabelbinder 136 x 3.6mm e 100 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.52', 'Stecker Typ 12 schwarz 10A 250V', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.53', 'Kupplung Typ 13 schwarz 10A 250V', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.54', 'Paraliq GTE 703 25X6OQ', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.55', 'Reinigungsbürsten', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.56', 'Schlauchschere klein', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.57', 'Schlauchschere gross', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.58', 'HahnenschIüsseI', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.59', 'Lecksucher Plus 400ml', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.60', 'CO2 O-Ring Beutel a 50 Stk.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.61', 'CO2 Dichtung rot Beutel a 50 Stk.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.62', 'CO2 Dicht. Breit Ha.Anz Beut. A 50 Stk.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.63', 'CO2 Dicht. O-Ring EICHH Beut. A 50 Stk.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.64', 'EdelstahI-Bogen 180” 2x10 1x6 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.65', 'Bogen mit Abgang 180° 10 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.66', 'Industriecleaner 500ml', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.67', 'CO2 Dicht. (O-Ring) 3,53/9,12 zu OT Berg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.68', 'Thermometer Digital GTH 175/ PT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.69', 'Montagesock. kleb.+schraubb. 27x27 weiss', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.70', 'Verbinder 4 x 4 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.71', 'Verbinder 4 x 6 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.72', 'Verbinder 6 x 6 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.73', 'Verbinder 6 x 10 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.74', 'Verbinder 10 x10 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.75', 'T-Stück 6 x 6 x 6 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.76', 'T-Stück 4 x 4 x 4 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.77', 'Umkehrbogen 6 mm mit Abgang 6 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.78', 'Umkehrbogen 7mm x 7mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.79', 'Umkehrbogen 10mm x 10mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.80', 'O-RTing Eurostar DIO10', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.81', 'O-RTing Eurostar DIO11', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.82', 'O-RTing Eurostar DIO13', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.83', 'Gleitring zu Eurostar DIO14', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.84', 'Dichtring zu Eurostar DIO15', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.85', 'Stössel komplett BIHAZ018', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.86', 'Überwurfmutter Chrom BIHAZ019', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.87', 'Überwurfmutter Gold BlHAZ019-G', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.88', 'Distanzstück für Griff BIHAZ020', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.89', 'Kompensator BIHAZ022', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.90', 'Excenter komplett Chrom BIHA2023', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.91', 'Excenter komplett Gold BIHAZ023-G', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '75.1900.92', 'Feder lnox Nr. 17', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.01', 'TEROSTAT RB IX', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.02', 'Flaschenhalter 2-er', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.03', 'Alu-Konsole 400/450', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.04', 'Alu-Konsolen 350/400', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.05', 'Tablar 50/50', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.06', 'Tablar 90/50', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.07', 'Tablar 80/50', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.08', 'Tablar 65/45', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.09', 'Holzböckli 50/50/20', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.10', 'lsolierschlauch 12/6', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.11', 'Isolierschlauch 8/6', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.12', 'Isolierschlauch 42/9', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.13', 'Isolierschlauch 22/9', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.14', 'Armaflex Klebeband 15 m (50Mx3mm)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.15', 'lnstallationskanal 60/60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.16', 'lnstallationskanal 60/110', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.17', 'lnstallationskanal 40/60', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.18', 'lnstallationskanal 40/40', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.19', 'lsol.Schl. 13/18 20 X Cold Booster Cooler', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.20', 'Pythonklammer klein', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.22', 'lnstallationskanal 30/30', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.23', 'Isolierschlauch 6/15', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.24', 'Flaschenhalter 1-er', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.25', 'Holzböckli 57/45 zu H75E', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.26', 'Untergestell 80/110/55', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.27', 'Untergestell 120/110/55', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.28', 'Untergestell 160/110/55', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.29', 'Untergestell Ticino 110/85.5/55', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.30', 'Spezialbrett FZ-Platten pro m2 /118.20.-', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '80.1900.40', 'lsolierschlauch 28/13mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Säule
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '84.1900.01', 'Zapfsäule verg. HEINEKEN 1 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '84.1900.03', 'Zapfsäule V2A HEINEKEN 1 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Säule')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Branding
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '84.1900.05', 'Linse MURP. IRISH Red mit Trafo und Bel.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '84.1900.07', 'Linse MURPJRISH St mit Trafo+BeL Kompl', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Branding')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Zapfhahn
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '84.1900.08', 'Reparaturset zu Zapfhahn MURPHY‘S', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Zapfhahn')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.01', 'Plexiglasblende zu Glastürkühlschrank HE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.03', 'Zusatzplatten Holland-Buffet CALANDA', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.04', 'ZusatIatten Holland-Buffet HALDENGUT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.05', 'Zusatzplatten Holland-Buffet HEINEKEN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.06', 'Zusatlatten Holland-Buffet ERDINGER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.07', 'Zusatzplatten Holland-Buffet EICHHOF', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.11', 'Rührwerkmotor zu Holland-Buffet 1 H.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.12', 'O-ring C02 12.0 x 2.5mm zu H.-Buffet alt', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.13', 'CO2 Dichtungshalter zu H.-Buffet alt', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.14', 'CO2 Dichtung zu Holland-Buffet alt', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.15', 'Füsse (Kappe) zu Holland-Klapptheken', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.16', 'Thermostat zu Glastürkühlschrank C5', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.20', 'Füsse zu Safari OT und Tapstar OT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.21', 'Füsse zu Safari UT', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.22', 'Wasserablassh. zu Safari OT/Tapst.OT/838', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1800.30', 'Zusatzplatten Holland-Buffet lTTINGER', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.00', 'The Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.01', 'Holland—Buffet', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.04', 'Klapptheken', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.05', 'Aufsatz zu Klapptheke', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.06', 'Sonnenschirmhalter zu HK. bis Baujahr 00', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.07', 'Sonnenschirmhalter zu HK ab Baujahr 01', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.10', 'Wine4U', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.11', 'Hochdruckmanometer N2 zu Wine4U', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.12', 'Flaschenanschl. fUr Winevitriene Wine 4U', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.13', 'Getr. Schl. 3x6mm Wine4U Rol. a 50 Meter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.20', 'Thermostat zu Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierkühler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.21', 'Beer tap zu Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierkühler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.22', 'LED Trafo 15W 2 zu Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.23', 'LED Beleuchtung RGB zu Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.24', 'Fernbedienung zu Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.25', 'DTA Key zu Vault', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '85.1900.40', 'Unterlagsscheibe m. Hutmutter 21.1 HB', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.00', 'Ice Bank Reg. Dinfer zu V100E und H100E', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.01', 'Lüftermotor zu V100E und H100E', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.02', 'Pumpe Samec 6m zu H75 / V100E und H100E', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.03', 'Eisbankfühler zu V100E und H1OOE', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.10', 'Eisbankr. Eliwell zu Glykolkühler V100EG', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.11', 'Therm. Ranco H100E, V100E, H75, OT Lux', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '86.1900.12', 'Thermostat zu OT Berg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.08', 'lnstal. Mat. Tank 1+2 (1 Set pro Anlage)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.09', 'Stapelset (1 Set pro 2 Tank) alt', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.10', 'In-Mat-Tank extra 1 Set ab T3,2 Set abT4', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.17', 'Cleaningmodul 4 Tanks Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.21', 'Gerade Verbinder 16mm John Guest', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.22', '90° Elbow Connector 16mm J.G.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.23', 'T-Connector 16mm J.G.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.24', 'Elbow Connector 20mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.25', 'Reduzierverbinder 20/16mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.26', 'Sicherungsring 18 mm zu John Guest', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.33', 'Orion Data Kabel 30 Meter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.34', 'Display', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.35', 'Computer', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.36', 'Modem Orion KPN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.37', 'Simkarte Orion KPN', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.42', 'Steckverbinder m. lnnengewinde 3/8''x3/8''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.79', 'Orion Com Cable', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.80', 'Orion Air Drying Module', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1900.99', 'Sprühdes- Mittel TM 70 Sprühﬂ. a 1Liter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.00', 'Umkehrbogen 180° 12mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.01', 'T Verbinder zu Luftschlauch 6 x 4', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.02', 'T Verbinder zu Luftschlauch 10 x 8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.04', 'AnschIB. 90° Flare 3/6'' + Überwurfm.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.05', 'Dichtung konisch Nylon', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.06', 'Überwurfmutter 38/''', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.07', 'Schlauchklemme 15.0 - 17.5 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.08', 'Schlauchklemme 15.3 -18.5 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.09', 'Schlauchklemme 19-4 - 22.6 mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.10', 'Phenolphtalein Papier', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.11', 'Gummifüsse zu Kompressor (Rubber Base)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.12', 'Hakenschlüssel DN 20 - 40', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.13', 'Feder Abschirmung Cleaning Unit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.15', 'Pressure switch MDR2/11 4-ways', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.16', 'Bushing 1/4 x 1/8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.17', 'Gauge 0-16 bar 118 back', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.18', 'Rapid fitting elb 1/4 bu 6mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.19', 'Elboe 1/4', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.20', 'Safety valve 12 bar/ 177 psi', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.21', 'Plug 1/4'' w/M6 8t o-ring track', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.22', 'Intakeﬁlter OF300 Special', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.23', 'Capacitor 25uF/230V AC f/OF300', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.24', 'Rapid fitting elbow 1/8 x 6mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Elektronik
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.25', 'Autodrain 220-240V + Timer', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Elektronik')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.26', 'Double nippel 1/4 x 1/8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.27', 'Rapid fitting 6mm x 1/4'' elbow', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.28', 'Cross connector 1/4'' w/through', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.29', 'Swifel w/connecting piece 1/4', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.30', 'Non-retour valve', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.31', 'T-piece 1/8', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.32', 'Solenoid valve unload. 230V', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Thermostat/Regler
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.33', 'Temperaturfühler PT 1000', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.34', 'Temperaturfühler NTC zu 500l Orion-Tank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Thermostat/Regler')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.36', 'Antenne zu Clever', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.37', 'Halter. für Rein. Mit. zu Cleaning Modul', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Werkzeug
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.38', 'Gabelschlüssel 10mm .', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Werkzeug')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.39', 'PCB UniverContrPlatzu 500l Orion-Tank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.40', 'PneumTube PU6-4 blau Vent.250l Ori.Tank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.41', '3-weg Vent.+ E. Motor zu 500l Tank Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.42', 'Kabel+Stecker zu Biervent. Orion kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.43', 'Rohr (Measuring Tube 0000939) Clean. Un.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.44', 'Wasser DRV Solenoid Valve zu Measur.Tube', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.45', 'Pum.Rein.Mitteldos.inkl.Motor Clean Unit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.46', 'Flow Transm. zu Measur. Tube Clean. Unit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.47', 'Rückschlagvent. kompl. zu Measuring Tube', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.48', 'Luftanschl. 90° zu Komp. Unit+Überwurfm.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '88.1901.49', 'Luftkompressor ohne Füsse zu Komp. Unit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.01', 'Tank Orion 500 Liter inkl. Verpackung', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.02', 'Kl. HE zu Orion Set a 2 x gross +1 x kl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.03', 'Kl. CB zu Orion Set a 2 x gross +1 x kl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.04', 'Kleber EH zu Orion Set a 2 x gr.+1 x kl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.05', 'Folie Alu 1/2 Tank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.06', 'Dichtung schwarz DN 15', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.07', 'Dichtung sohwarz DN 32', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.08', 'Instal. Material (1 Set bis max. 2 Tank)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.09', 'Stapelset (1 Set pro 2 Tank) neu', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.10', 'lnstal. Mat. (1 Set pro Zusatztank)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.11', 'Pythonkühler 900 kcal vertikal', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.12', 'Pneu.-Dreha.90°K zu Nocado Klap. 5-8 bar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.13', 'Pythonpumpe Brinkmann KTF 52', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbinder / Briden
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.14', 'Bierschl. 8.5mm, 9 mtr. 1 Stück pro Hahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbinder / Briden')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.15', 'Air dry unit z.P.Kühler 900 Kc 1xPro DLK', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.16', 'Luftschlauch 6 x 4 schwarz (Rolle a 25m)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.17', 'Kompressorunit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Druck/Gas
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.18', 'Luftschlauch 10x8 (Rolle a 25m)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Druck/Gas')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.19', 'Cleaningmodul', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.20', 'TM Desana', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Bierleitung
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.21', 'PE Schlauch 12.7 x 16 (Rolle a 50m)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.22', 'Bierleitung 20x15mm neutral', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.23', 'Bierleitung Lupulus II 8.5 x 11.5mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.24', 'Python Orion 4er', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Bierleitung')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.25', 'Bieranschluss 1 weg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.26', 'Bieranschluss 2 weg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.27', 'Bieranschluss 3 weg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.28', 'Bieranschluss 4 weg', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.29', 'lsolierschlauch Armaﬂex 48x13 selbstkl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.30', 'Isolierschlauch Armaflex 22x19 selbstkl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.31', 'Communication cabel (30m)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.32', 'Verlängerung (Communication cabel 15m)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.33', 'Clever unit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.34', 'Ant.20-XS108CH-8+W.Bef.+Ansch.Kab.z Clev', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.35', 'Nippel geb. 6mm + Mutter+Dicht. zu Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.36', 'Nippel ger. 6mm + Mutter+Dicht. zu Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.37', 'Kugel-Abstellhahn RUckl. Wasser zu Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.38', 'Reinigungsschlauch zu Zapfhahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.39', 'Rolltape sohwarz 30mm', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.40', 'Isolierschlauch 13/18', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.41', 'lsolierschlauch 35/19 selbstklebend', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.42', 'Absauglüfter (Fan Beercooler 900 kcal)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Dichtungen
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.43', 'Dichtung rot zu Einstechhahn NW 55', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.44', 'Dichtung LK-Klappe NW 40', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.45', 'Dichtung LK-Klappe NW 25', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.46', 'Dichtung schwarz DN 40', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Dichtungen')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.47', 'Bedienungskasten zu Abfüllunit kompl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.48', 'Solenoid valve 20 Orion Tank 500 Liter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.49', 'Magnetventil zu Komoressorunit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.50', 'Safety Valve Brass Chrom zu Orion Tank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.51', 'Seal Ring 1610 1/4 zu Safety Valve Or. Tank', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.55', 'Einstechhahn zu 500l Orion-Tank.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Sonstiges
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.58', 'Bioprene 4.0 x 1.6mm Rolle a 10m', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.59', 'Bioprene 3.2 x 1.6mm Rolle a 5m', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Sonstiges')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.60', 'Absperrgriff zu Orton 250 und 500l', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.61', 'Anl. /SchneIlübersichtskarte D, F, I Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Montagematerial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.62', 'Alu-Konsole 125/150', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.63', 'Tablar 20/23', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Montagematerial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Pumpe/Motor/Lüfter
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.68', 'Pumpe zu Coldﬂowrnotor', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.69', 'Rep. Satz zu Coldﬂowpumpe', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.70', 'Bierpumpe cam 3° zu TBS', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.71', 'Motor zu Bierpumpe cam 3° TBS', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.72', 'Coldﬂowpumpe mit Motor', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.73', 'Kohlebürste kompl. Zu Coldflowp. + Motor', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Pumpe/Motor/Lüfter')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.74', 'Leermeldungssonde zu TBS', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.75', 'Pektron', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.76', 'Timer zu Lüftkompressor Jun-Air', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.77', 'Luftmotor zu Bierschlauchhaspel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.78', 'Red. mit Wasser Separ+Öl Absch. 0-10 Bar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.79', 'Reduzierer mit Wasser Separator 0-4 Bar', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.80', 'Ersatztasse zu Wasser Separator', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.81', 'Ersatztasse zu Öl Abscheider', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.82', 'Luftdämpfer Ablassventil (Festo blau)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.83', 'Lampe LED (Plafoniere)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.84', 'Kunststoffabdeckung weiss für Tank NW 40', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.85', 'Fernbedienung zu Container', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.86', 'ÖI fUr Luftkompressor Flasche a 5 Liter', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.87', 'Farbband Epson zu Auﬂieger 117', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Orion
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.88', 'Kugel blau zu Einstechhahn', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.89', 'Luftablassventil zu LKW Orion', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.93', 'Komp. LFX 2.0-10E 230V, Kolbenkompressor', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.94', 'Bremsplatte Teﬂon zu Bierhaspel LKW', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.95', 'DRV kompl. zu Jun-Air Kompressor', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.96', 'Luftkompressor Jun-Air', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.97', 'Einsteohhahn zu 500 + 1000 L Tanx FIB', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.98', 'Bierpumpe zu Abfüllunit inkl. Motor', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Orion')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '90.1900.99', 'Thermopapier 112 mm breit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.00', 'TM Desana Max CL Beutel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.01', 'Reinigungstank VZA klein 3x Bieranschl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.02', 'Reinigungstank V2A gross 3x Bieranschl.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.03', 'Reinigungsvlies', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.04', 'Tester gelb Karton a 25 Tester', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.06', 'Latexhandschuhe Grösse M', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.07', 'Latexhandschuhe Grösse L', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.08', 'Latexhandschuhe Grösse S', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.09', 'Reiniger für Eisenoxidablagerungen', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.10', 'Lieferscheine DBO Schachtel a 750 Stück', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Reinigungsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.11', 'TM Desana Max CL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.12', 'TM Desana Max FP Beutel', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Reinigungsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.13', 'Servicekontrollkarten deutsch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.14', 'Servicekontrollkarten italienisch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.15', 'Servicekontrollkarten französisch', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.16', 'Sichtmäppli (Ausweishüllen A5)', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Schrauben/Dübel
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.17', 'Spanplattenschrauben Torx PH 6x60 verzi.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.18', 'Spanplattensohrauben Torx PH 5x50 verzi.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.19', 'Spanplattenschrauben Torx PH 5x25 verzi.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.20', 'Spanplattensohrauben Torx PH 5x20 verzi.', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.21', 'Spanplattensohrauben Torx PH 5x60 David', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.25', 'Dübel Zebra Shark weiss MKR. 6x37', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9900.26', 'Dübel Zebra Shark weiss MKR. 8x52', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Schrauben/Dübel')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Verbrauchsmaterial
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.02', '2 Flow Kühlflüssigkeit', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Verbrauchsmaterial')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  -- Kleider
  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.10', 'Pullover DBO Grösse S', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.11', 'Pullover DBO Grösse M', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.12', 'Pullover DBO Grösse L', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.13', 'Pullover DBO Grösse XL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.14', 'Pullover DBO Grösse XXL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.15', 'Poloshirt DBO Grösse S', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.16', 'Poloshirt DBO Grösse M', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.17', 'Poloshirt DBO Grösse L', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.18', 'Poloshirt DBO Grösse XL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.19', 'Poloshirt DBO Grösse XXL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.20', 'T-Shirt DBO Grösse S', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.21', 'T-Shirt DBO Grösse M', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.22', 'T-Shirt DBO Grösse L', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.23', 'T-Shirt DBO Grösse XL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)
  SELECT v_user_id, '99.9999.24', 'T-Shirt DBO Grösse XXL', 'Stück',
    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='Kleider')
  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;

END $$;