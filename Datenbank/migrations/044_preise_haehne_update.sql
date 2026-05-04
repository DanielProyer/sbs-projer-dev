-- Migration 044: Hahn-Preise korrigieren (waren alle auf 23.00, korrekt: Eigen/Orion 18.00)
UPDATE preise SET
  zusatz_hahn_eigen = 18.00,
  zusatz_hahn_orion = 18.00,
  zusatz_hahn_anderer_standort = 30.00
WHERE zusatz_hahn_eigen = 23.00;
