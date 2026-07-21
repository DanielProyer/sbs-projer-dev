-- 146: Alle Views auf security_invoker umstellen (21.07.2026)
-- Supabase-Advisor ERROR "security_definer_view": Views liefen bisher mit den
-- Rechten des Erstellers (postgres) und umgingen damit RLS der Basistabellen —
-- anon konnte z.B. view_offene_rechnungen komplett lesen. Mit security_invoker
-- gilt RLS des abfragenden Users: eingeloggt unveraendert (Einzel-Tenant,
-- verifiziert: alle 8 Views liefern Daten), anon = 0 Zeilen (verifiziert).
-- Zudem sauber fuer den kuenftigen Franchise-/Multi-Tenant-Ausbau.

ALTER VIEW public.view_anlagen_service_status SET (security_invoker = on);
ALTER VIEW public.view_mwst_abrechnung SET (security_invoker = on);
ALTER VIEW public.view_erfolgsrechnung SET (security_invoker = on);
ALTER VIEW public.view_offene_formulare SET (security_invoker = on);
ALTER VIEW public.view_pikett_kalender_sync SET (security_invoker = on);
ALTER VIEW public.view_offene_rechnungen SET (security_invoker = on);
ALTER VIEW public.view_bestellliste SET (security_invoker = on);
ALTER VIEW public.view_mahnwesen_dashboard SET (security_invoker = on);
