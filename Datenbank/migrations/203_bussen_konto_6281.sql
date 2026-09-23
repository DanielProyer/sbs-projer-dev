-- 203: Steuer-/MWST-Bussen auf eigenes Konto 6281 «Übrige Bussen» (23.09.2026)
--
-- Bisher liefen Steuerbussen (steuerart = 'busse') auf 8900 Direkte Steuern.
-- Direkte Steuern darf die GmbH vom Gewinn abziehen, Bussen nicht — auf 8900
-- wurden sie still als Steueraufwand abgezogen. Neu:
--   6280 Verkehrsbussen  (bisher «Bussen»)
--   6281 Übrige Bussen   (Steuer-, MWST-, Verwaltungsbussen)
-- Beide steuerlich nicht abzugsfähig. Die Steuer-Übersicht muss 6281 als
-- Zahlungskonto kennen, sonst fielen neue Steuerbussen aus der Summe.
-- Historische Bussen auf 8900 (2022, 2025) bleiben unverändert (Jahre
-- abgeschlossen) — sie sind in der jeweiligen Steuererklärung aufzurechnen.
--
-- Konten-Anpassung (bereits per SQL ausgeführt, hier dokumentiert):
--   update konten set bezeichnung='Verkehrsbussen', beschreibung='Geschwindigkeits-, Park- und Vignettenbussen (steuerlich nicht abzugsfähig)' where kontonummer=6280;
--   insert into konten (user_id, kontonummer, bezeichnung, beschreibung, kategorie, ist_aktiv) ... 6281 'Übrige Bussen' ...

create or replace view view_steuerjahr_zahlungen with (security_invoker = on) as
select user_id,
       steuerjahr,
       steuerart,
       round(sum(
         case
           when soll_konto = any (array[8900, 2208, 2202, 6281]) and haben_konto = any (array[1000, 1020]) then betrag_brutto
           when soll_konto = any (array[1000, 1020]) and haben_konto = any (array[8900, 2208, 2202, 6281]) then - betrag_brutto
           else 0::numeric
         end), 2) as bezahlt,
       count(*) as anzahl
  from buchungen
 where not ist_storniert and storno_von_id is null and steuerjahr is not null
 group by user_id, steuerjahr, steuerart;
