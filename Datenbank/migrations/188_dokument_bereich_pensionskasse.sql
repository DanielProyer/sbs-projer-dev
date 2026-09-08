-- Migration 188: Bereich «pensionskasse» im Dokumente-Modul.
--
-- Entscheid Daniel 08.09.2026: Die berufliche Vorsorge bekommt eine eigene
-- Ebene statt einer Kategorie unter «Versicherungen». 40 Dokumente über sieben
-- Jahre (Beitragsrechnungen, Mahnungen, Kontoauszüge, Ausweise, Vorsorgepläne,
-- der PKG-Freizügigkeitsübertrag) sind genug für einen eigenen Bereich — und
-- man sucht sie dort zuerst.
--
-- Die CHECK-Constraint zählt die Bereiche auf und muss deshalb mitwachsen;
-- ohne diese Migration schlägt jedes Update auf bereich='pensionskasse' fehl.
-- Gegenstück im Code: dokumentBereiche in lib/services/steuern/dokument_pfad.dart.

alter table public.dokumente drop constraint if exists dokumente_bereich_check;

alter table public.dokumente add constraint dokumente_bereich_check
  check (bereich = any (array[
    'steuern', 'versicherungen', 'pensionskasse',
    'vertraege', 'behoerden', 'bank', 'sonstiges'
  ]));
