-- Migration 143: Rechnungssummen auf 5 Rappen runden (Kundenrechnungen)
--
-- BEFUND 15.07.2026 — der Rechnungsbetrag wird NICHT von der App gesetzt:
-- update_rechnung_summen() summiert ihn bei jedem Positions-Insert aus
-- rechnungs_positionen. Jede App-seitige Rundung wurde deshalb Sekunden-
-- bruchteile spaeter ueberschrieben (App schrieb 138.35, Trigger 138.37).
-- Deshalb blieben Migration 139 (Reinigungs-Trigger) und der Dart-Fix in
-- rechnung_service wirkungslos: beide sassen auf der falschen Ebene.
--
-- Regel (Daniel): Kundenrechnungen IMMER auf 5 Rappen gerundet.
-- Einzige Ausnahme: heineken_monat bleibt ungerundet.
--
-- MwSt wird aus dem gerundeten Brutto abgeleitet -> Netto + MwSt = Brutto exakt.
--
-- Hinweis: Die Dart-seitige Rundung in rechnung_service bleibt noetig — das
-- PDF wird aus dem Rechnungs-Objekt VOR dem Trigger erzeugt. Beide Seiten
-- runden jetzt gleich, damit PDF und Datenbank uebereinstimmen.

CREATE OR REPLACE FUNCTION public.update_rechnung_summen()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_rechnung_id UUID;
  v_typ    TEXT;
  v_netto  NUMERIC;
  v_mwst   NUMERIC;
  v_brutto NUMERIC;
BEGIN
  v_rechnung_id := COALESCE(NEW.rechnung_id, OLD.rechnung_id);

  SELECT rechnungstyp INTO v_typ FROM rechnungen WHERE id = v_rechnung_id;

  SELECT COALESCE(SUM(betrag_netto), 0),
         COALESCE(SUM(mwst_betrag), 0),
         COALESCE(SUM(betrag_brutto), 0)
    INTO v_netto, v_mwst, v_brutto
    FROM rechnungs_positionen
   WHERE rechnung_id = v_rechnung_id;

  IF v_typ IS DISTINCT FROM 'heineken_monat' THEN
    v_brutto := ROUND(v_brutto * 20) / 20;
    v_mwst   := v_brutto - v_netto;
  END IF;

  UPDATE rechnungen SET
    betrag_netto  = v_netto,
    mwst_betrag   = v_mwst,
    betrag_brutto = v_brutto,
    updated_at    = NOW()
  WHERE id = v_rechnung_id;

  RETURN COALESCE(NEW, OLD);
END;
$function$;
