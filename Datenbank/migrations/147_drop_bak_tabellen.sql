-- 147: Backup-Tabellen vom 14.-16.07.2026 entfernen (OK Daniel 21.07.2026)
-- Alle zugehoerigen Aktionen sind verifiziert und abgeschlossen:
--   _bak_rundung_*    -> 5-Rappen-Backfill Migration 143 (14.07.)
--   _bak_camt_*       -> camt-Test-Rollback auf Baseline (15.07.)
--   _bak_nachtrag_*   -> Nachtrag der 38 fehlenden Rechnungen (15.07.)
--   _bak_ezs_korrektur-> EZS-Umbuchung Sports Zugerland/Sartons (16.07.)

DROP TABLE IF EXISTS public._bak_rundung_reinigungen_20260714;
DROP TABLE IF EXISTS public._bak_rundung_stoerungen_20260714;
DROP TABLE IF EXISTS public._bak_rundung_rechnungen_20260714;
DROP TABLE IF EXISTS public._bak_camt_20260715_rechnungen;
DROP TABLE IF EXISTS public._bak_camt_20260715_dateien;
DROP TABLE IF EXISTS public._bak_camt_20260715_pruefliste;
DROP TABLE IF EXISTS public._bak_camt_20260715_regel;
DROP TABLE IF EXISTS public._bak_camt_20260715_eingangsrechnung;
DROP TABLE IF EXISTS public._bak_nachtrag_20260715_rechnungen;
DROP TABLE IF EXISTS public._bak_nachtrag_20260715_positionen;
DROP TABLE IF EXISTS public._bak_ezs_korrektur_20260716;
