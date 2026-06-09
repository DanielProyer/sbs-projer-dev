-- 092_gast_kein_buchhaltung.sql
-- Der read-only Gast (gast@sbsprojer.ch) soll KEINEN Zugriff auf die Buchhaltung
-- haben. Entfernt die in 091 angelegten *_guest_read SELECT-Policies wieder auf
-- allen Finanz-/Buchhaltungs-Tabellen. Operatives (Betriebe, Anlagen, Reinigungen,
-- Störungen, Montagen, Material, Pikett, Kontakte ...) bleibt für den Gast lesbar.
--
-- UI-seitig zusätzlich: Router-Redirect /buchhaltung* -> / und Dashboard-Kachel
-- ausgeblendet, wenn SupabaseService.isGuest (router.dart / home_screen.dart).

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'konten','buchungen','buchungs_vorlagen','buchungs_belege',
    'camt_pruefliste','camt_regel','lohn_abrechnungen','lohn_einstellungen',
    'rechnungen','rechnungs_positionen'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_guest_read', t);
  END LOOP;
END $$;
