-- 192b: Der Preis-Trigger hört auch auf ist_kulanz (16.09.2026)
--
-- WARUM: Migration 192 lehrte `calculate_reinigung_preis()`, bei Kulanz 0 zu
-- setzen — aber der Trigger feuerte nur bei `service_typ` und den
-- Hahn-Mengen. Ein Umschalten auf «Kulanz» rührte keine dieser Spalten an,
-- also rechnete nichts neu, und der alte Preis blieb stehen. Die Funktion war
-- richtig, sie wurde nur nie gerufen.
--
-- `ist_kulanz` kommt deshalb in die Spaltenliste des Triggers. Das
-- abschliessende UPDATE setzt bei den Altfällen `ist_kulanz` auf seinen
-- eigenen Wert — das genügt, damit der Trigger feuert und 0 schreibt.
--
-- NACHTRAG 17.09.2026: Diese Datei fehlte in der Ablage; sie war am 16.09.
-- direkt über `apply_migration` eingespielt worden. Der Inhalt hier ist der
-- Wortlaut aus `supabase_migrations.schema_migrations`
-- (version 20260916094547), gegengeprüft an `pg_get_triggerdef()`. Auf der
-- Datenbank ist sie bereits angewendet — erneutes Ausführen ist gefahrlos
-- (DROP IF EXISTS, und das UPDATE ist idempotent).

-- Der Preis-Trigger feuerte nur bei service_typ/Hahn-Mengen — ein Umschalten
-- auf Kulanz rechnete nie neu. ist_kulanz kommt in die Spaltenliste.
DROP TRIGGER IF EXISTS reinigung_preis_berechnung ON public.reinigungen;
CREATE TRIGGER reinigung_preis_berechnung
  BEFORE INSERT OR UPDATE OF service_typ, anzahl_haehne_eigen, anzahl_haehne_orion,
    anzahl_haehne_fremd, anzahl_haehne_wein, anzahl_haehne_anderer_standort, ist_kulanz
  ON public.reinigungen FOR EACH ROW EXECUTE FUNCTION calculate_reinigung_preis();

-- Altfälle neu rechnen (der Trigger sieht ist_kulanz und setzt 0):
UPDATE reinigungen SET ist_kulanz = true WHERE ist_kulanz AND preis_brutto > 0;
