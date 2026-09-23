-- 202: Mahnprotokoll erhält den Zustand NACH dem Schreiben
--
-- ANLASS (Review 23.09.2026): Migration 200 hielt in `vorher` fest, wie jede
-- betroffene Rechnung VOR dem Mahnschreiben stand — Grundlage für
-- «zurücknehmen». Ohne einen Vergleichswert für NACHHER kann «zurücknehmen»
-- aber nicht erkennen, ob sich die Rechnung SEITHER weiterbewegt hat (Kunde
-- hat inzwischen bezahlt, oder ein späterer Mahnlauf hat sie weitergestuft).
-- Ohne diese Prüfung würde «zurücknehmen» eine Zahlung oder eine neuere Stufe
-- stillschweigend überschreiben — genau das oberste Ziel des Mahnwesens
-- («nie eine bezahlte Rechnung mahnen») wäre unterlaufen.

ALTER TABLE public.mahnschreiben
  ADD COLUMN IF NOT EXISTS nachher jsonb;

COMMENT ON COLUMN public.mahnschreiben.nachher IS
  'Zustand je Rechnung NACH dem Schreiben (gleiche Form wie "vorher"): '
  '{"<rechnungId>": {zahlungsstatus, mahnung_stufe, letzte_mahnung_am, ...}}. '
  'Grundlage, um beim Zurücknehmen zu erkennen, ob sich die Rechnung seither '
  'geändert hat (z. B. bezahlt oder weiter gemahnt) — dann wird NICHT '
  'automatisch zurückgesetzt. Bei alten Zeilen (vor dieser Migration) ist '
  'die Spalte NULL; auch dann wird nicht automatisch zurückgesetzt.';
