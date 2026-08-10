-- 167_rechnungsadresse_felder.sql
-- Rechnungsadresse: mehrzeilige Empfaengeradressen (Fall SV (Schweiz) AG / Spiga).
--
-- Ausgangslage: Die Spalte `nachname` trug in allen 63 Datensaetzen den
-- BETRIEBSNAMEN, nicht einen Personennamen -- das Formular schrieb sie stumm
-- und nicht editierbar (`adresse.nachname = _betriebName`). `vorname` war
-- durchgehend NULL. Grosskunden wie SV verlangen zusaetzliche Adresszeilen
-- (Objektbezeichnung, Kostenstelle, Eingangskanal, Postfach), die bisher in
-- `strasse` und `notizen` gequetscht wurden.
--
-- Geprueft vor der Migration: keine View und keine RLS-Policy referenziert
-- `nachname`/`vorname`; `rechnungen.rechnungsadresse` (JSONB-Snapshot) ist in
-- allen Zeilen NULL. Der Dart-Code liest den Snapshot-Key `nachname`
-- trotzdem weiterhin als Fallback (siehe BetriebRechnungsadresse.fromAdressSnapshot).

alter table betrieb_rechnungsadressen rename column nachname to objekt;
alter table betrieb_rechnungsadressen drop column vorname;

alter table betrieb_rechnungsadressen add column kostenstelle text;
alter table betrieb_rechnungsadressen add column zusatz text;
alter table betrieb_rechnungsadressen add column postfach text;

-- Postfach ersetzt die Strasse -> Strasse darf leer sein.
alter table betrieb_rechnungsadressen alter column strasse drop not null;

comment on column betrieb_rechnungsadressen.objekt is
  'Objekt-/Betriebsbezeichnung in der Empfaengeradresse. Bei Sammelzahlern (Firma gesetzt) Pflicht, damit der Betrieb auf der Rechnung ersichtlich ist.';
comment on column betrieb_rechnungsadressen.kostenstelle is
  'Kostenstelle/Referenz des Empfaengers, eigene Adresszeile (z. B. "KST 28616406").';
comment on column betrieb_rechnungsadressen.zusatz is
  'Freie Zusatzzeile: Abteilung oder Eingangskanal (z. B. "Scanning Center").';
comment on column betrieb_rechnungsadressen.postfach is
  'Postfach; ersetzt im Druck die Strassenzeile (z. B. "Postfach 440").';
