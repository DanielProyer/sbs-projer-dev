-- 193: Merker «Nächste Reinigung auf Kulanz» am Betrieb (17.09.2026)
--
-- WARUM ein eigenes Feld und nicht der Freitext `service_hinweis`:
-- Der Service-Hinweis ist generisch («Hintereingang benutzen» wäre ein
-- ebenso gültiger Inhalt). Aus ihm auf Kulanz zu schliessen hiesse raten.
--
-- ANLASS: Chleina Pub. Die Kundin hatte im April doppelt bezahlt, dafür war
-- eine Gratis-Reinigung versprochen. Der Hinweis stand ab 07.08. am Betrieb
-- und wurde beim Abschluss auch angezeigt — am 27.08. wurde trotzdem regulär
-- verrechnet (Rechnung 2026-08-1386), weil ein Hinweis nur erinnert, aber
-- nichts einstellt. Erledigt wurde der Fall am 17.09. durch Verrechnung.
--
-- Mit diesem Merker steht der Kulanz-Schalter im Reinigungs-Formular von
-- Anfang an richtig; man muss aktiv widersprechen statt aktiv daran denken.
-- Er ist EINMALIG: Schliesst eine Kulanz-Reinigung ab, setzt die App ihn
-- zurück. Genau das fehlte beim Hinweis, der 40 Tage stehen blieb.
--
-- Ein Dauer-Gratiskunde wird NICHT hierüber abgebildet, sondern über
-- Preisliste bzw. Zahlungsart.

ALTER TABLE betriebe
  ADD COLUMN IF NOT EXISTS naechste_reinigung_kulanz boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN betriebe.naechste_reinigung_kulanz IS
  'Einmaliger Merker: waehlt den Kulanz-Schalter im Reinigungs-Formular vor. Die App setzt ihn nach einer abgeschlossenen Kulanz-Reinigung zurueck.';
