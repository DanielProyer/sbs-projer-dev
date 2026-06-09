-- 091_gast_read_rls.sql
-- Read-only Gastzugang für Heineken (gast@sbsprojer.ch).
--
-- Kontext: Die App leitet für den Gast (SupabaseService.isGuest) die dataUserId
-- auf DANIEL_USER_ID (1e1ec2dd-7836-4d8e-8256-c5649d994ee2) um, sodass der Gast
-- Daniels Daten sieht. Die bestehenden RLS-Policies (*_user_isolation,
-- USING user_id = auth.uid()) blockieren das aber. Daher: pro Tabelle mit
-- user_id-Spalte eine zusätzliche SELECT-Policy, die dem Gast LESENDEN Zugriff
-- auf Daniels Zeilen gibt. Schreiben bleibt blockiert (die ALL-Policy verlangt
-- user_id = auth.uid(); der Gast hat eine andere uid → INSERT/UPDATE/DELETE auf
-- Daniels Zeilen scheitern).
--
-- Der Gast-Auth-User selbst wird NICHT hier angelegt (Auth-Daten, kein Schema):
-- erstellt via auth.users-Insert (E-Mail gast@sbsprojer.ch, bestätigt, mit
-- auth.identities-Eintrag). Passwort separat gesetzt/änderbar.

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema = 'public' AND c.column_name = 'user_id'
      AND t.table_type = 'BASE TABLE'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',
                   r.table_name || '_guest_read', r.table_name);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT USING (user_id = %L::uuid AND (auth.jwt() ->> %L) = %L)',
      r.table_name || '_guest_read', r.table_name,
      '1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 'email', 'gast@sbsprojer.ch'
    );
  END LOOP;
END $$;
