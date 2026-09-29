-- 216: Jahressperre nur über eine Abschlussbuchung PER 31.12. (29.09.2026)
--
-- WARUM: `geschaeftsjahr_abgeschlossen` (209, korrigiert als 209b) hält das
-- Vorjahr für abgeschlossen, sobald IRGENDEINE Buchung mit beleg_typ
-- 'abschluss' bis zum 31.12. dieses Jahres existiert — ohne Untergrenze.
-- Jede ältere Abschlussbuchung erfüllt das: Ab dem 01.01.2027 gälte 2026
-- schon durch JA2025_D (31.12.2025), JA2025_C2 (01.01.2026) und
-- JA2025_D_U1/U2 (April/Mai 2026) als abgeschlossen. `zahlung_erfassen`
-- (Jahressperre seit 209d/211) wiese dann jede Zahlung mit Geschäftsjahr 2026
-- ab — bevor der Abschluss 2026 überhaupt gemacht ist. Gefunden im Review
-- der App-Schritte Delkredere/Rückstellung (29.09.2026); zwingend vor dem
-- 01.01.2027.
--
-- NEU: Abgeschlossen ist das Vorjahr erst mit einer Abschlussbuchung GENAU
-- per 31.12. dieses Jahres. So bucht der Jahresabschluss: JA2025_D (und
-- künftig JA<jahr>_D/_E aus der App) tragen Datum 31.12.<jahr>. Rückbuchungen
-- im Folgejahr (JA2025_C2 am 01.01.) und Umbuchungen von Steuerzahlungen
-- (JA2025_D_U1/U2) liegen nie auf einem 31.12. und zählen damit nicht mehr.
--
-- App-seitig dieselbe Regel: `BuchungNachholService.nachbuchGrenze`
-- (`.eq('datum', '<vorjahr>-12-31')`). Wächter:
-- test/migration_216_geschaeftsjahr_abgeschlossen_test.dart.
--
-- Sonst unverändert gegenüber dem Stand in der Datenbank (pg_get_functiondef,
-- 29.09.2026): laufendes Jahr nie abgeschlossen, Jahre vor dem Vorjahr immer.
-- CREATE OR REPLACE behält die Rechte (EXECUTE wie bisher).
--
-- Stand 2025 nach dem Anwenden unverändert abgeschlossen (JA2025_D per
-- 31.12.2025). Kontrolle:
--   select geschaeftsjahr_abgeschlossen('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2025);  -- true
--
-- Rückweg: Funktion aus 209 (Fassung 209b) wieder einspielen.

CREATE OR REPLACE FUNCTION geschaeftsjahr_abgeschlossen(p_user UUID, p_jahr INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_jahr >= EXTRACT(YEAR FROM current_date)::int THEN false
    WHEN p_jahr < EXTRACT(YEAR FROM current_date)::int - 1 THEN true
    ELSE EXISTS (
      SELECT 1 FROM buchungen
      WHERE user_id = p_user AND beleg_typ = 'abschluss'
        AND datum = make_date(p_jahr, 12, 31)
    )
  END;
$$;
