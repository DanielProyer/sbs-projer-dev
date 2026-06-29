-- Migration 115 (DATEN-Bereinigung, TP-7 Datenhygiene): per execute_sql auf PROD
-- (pltbaqqwpnmdajwgnhpd) angewendet, hier zur Nachvollziehbarkeit dokumentiert.
-- Stand 29.06.2026.

-- 1) Buchungs-Vorlagen: 28 alte INAKTIVE Duplikate entfernt (alte Kasse/Bank/
--    Privat-Varianten + überholte Heineken/Franchise/Material-Vorlagen).
--    Streng gefiltert: nur ist_aktiv=false UND ohne camt-Regel UND ohne Buchung.
--    Aktive + verknüpfte Vorlagen bleiben unangetastet. (App filtert inaktive
--    Vorlagen ohnehin aus allen Dropdowns -> rein kosmetisch.)
DELETE FROM public.buchungs_vorlagen v
WHERE v.ist_aktiv = false
  AND NOT EXISTS (SELECT 1 FROM public.camt_regel r WHERE r.buchungs_vorlage_id = v.id)
  AND NOT EXISTS (SELECT 1 FROM public.buchungen b WHERE b.vorlage_id = v.id);

-- 2) Konten-Altlasten:
--    a) "FEHLER – sollte X (Phase 2)"-Platzhalter-Namen säubern. 9000/9100 werden
--       von Daniel bewusst genutzt (Gewinn -> 9000, Verlust -> 9100); kein 9010.
UPDATE public.konten SET bezeichnung = 'Gewinnübertrag (Abschluss)'  WHERE kontonummer = 9000;
UPDATE public.konten SET bezeichnung = 'Verlustübertrag (Abschluss)' WHERE kontonummer = 9100;

--    b) Eindeutige Duplikate/Platzhalter ohne jede Buchung + ohne Vorlagen-Verweis
--       löschen: 8090 (FEHLER, echtes 8900 existiert), 8500 (inaktives Dup von
--       8900), 2850 (Dup von 2980 'Jahresgewinn/-verlust', 13 Bkg).
DELETE FROM public.konten WHERE kontonummer IN (8090, 8500, 2850);
