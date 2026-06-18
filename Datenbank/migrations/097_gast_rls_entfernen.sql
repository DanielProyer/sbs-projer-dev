-- 097_gast_rls_entfernen.sql
-- Gast-Account (gast@sbsprojer.ch) wird vorerst deaktiviert: alle *_guest_read
-- RLS-Policies entfernen. Der Auth-User wird separat gelöscht. Der App-Code
-- (SupabaseService.isGuest / dataUserId-Umleitung / isGuest-UI-Gating) bleibt
-- bewusst erhalten (inert), damit der Gast bei Bedarf leicht reaktiviert werden
-- kann. Reaktivierung: diese Policies erneut anlegen + Auth-User neu erstellen.

DROP POLICY IF EXISTS anlagen_guest_read ON anlagen;
DROP POLICY IF EXISTS anlagen_fotos_guest_read ON anlagen_fotos;
DROP POLICY IF EXISTS anruf_logs_guest_read ON anruf_logs;
DROP POLICY IF EXISTS bergkundenpauschalen_guest_read ON bergkundenpauschalen;
DROP POLICY IF EXISTS betrieb_rechnungsadressen_guest_read ON betrieb_rechnungsadressen;
DROP POLICY IF EXISTS betriebe_guest_read ON betriebe;
DROP POLICY IF EXISTS bierleitungen_guest_read ON bierleitungen;
DROP POLICY IF EXISTS biersorten_guest_read ON biersorten;
DROP POLICY IF EXISTS eigenauftraege_guest_read ON eigenauftraege;
DROP POLICY IF EXISTS eroeffnungsreinigungen_guest_read ON eroeffnungsreinigungen;
DROP POLICY IF EXISTS formulare_guest_read ON formulare;
DROP POLICY IF EXISTS heineken_kontakt_zuweisungen_guest_read ON heineken_kontakt_zuweisungen;
DROP POLICY IF EXISTS kontakte_guest_read ON kontakte;
DROP POLICY IF EXISTS lager_guest_read ON lager;
DROP POLICY IF EXISTS material_guest_read ON material;
DROP POLICY IF EXISTS material_bestellungen_guest_read ON material_bestellungen;
DROP POLICY IF EXISTS material_kategorien_guest_read ON material_kategorien;
DROP POLICY IF EXISTS material_verbrauch_guest_read ON material_verbrauch;
DROP POLICY IF EXISTS montagen_guest_read ON montagen;
DROP POLICY IF EXISTS pikett_dienste_guest_read ON pikett_dienste;
DROP POLICY IF EXISTS preise_guest_read ON preise;
DROP POLICY IF EXISTS regionen_guest_read ON regionen;
DROP POLICY IF EXISTS reinigungen_guest_read ON reinigungen;
DROP POLICY IF EXISTS stoerungen_guest_read ON stoerungen;
DROP POLICY IF EXISTS tagesplaene_guest_read ON tagesplaene;
DROP POLICY IF EXISTS termine_guest_read ON termine;
