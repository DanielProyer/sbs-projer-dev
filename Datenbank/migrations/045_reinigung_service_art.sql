-- Service-Art (Standardservice / Endreinigung / Eröffnungsservice) + Wasser im Kühler gewechselt
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS service_art TEXT DEFAULT 'standardservice';
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS wasser_kuehler_gewechselt BOOLEAN DEFAULT FALSE;
