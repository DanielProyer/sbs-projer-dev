-- 185: view_steuerjahr_zahlungen mit Invoker-Rechten (RLS greift)
-- Befund Gesamt-Review 02.09.2026: Die View aus Migration 184 war die einzige im
-- Schema ohne security_invoker und lief damit mit Owner-Rechten (postgres) an der
-- RLS von buchungen vorbei — mit dem anon-Key aus dem Web-Bundle ohne Login lesbar.
-- Alle anderen Views (z. B. view_offene_forderungen) setzen security_invoker = on.
ALTER VIEW public.view_steuerjahr_zahlungen SET (security_invoker = on);
