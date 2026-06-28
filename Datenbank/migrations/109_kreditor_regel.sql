-- Migration 109: kreditor_regel — Lieferanten-Lernen (TP-3).
-- Pro Lieferant (ggf. mehrere Zeilen je Referenz-Praefix zur Multi-Konto-
-- Disambiguierung) die gelernte/geseedete Zuordnung:
--   Lieferant -> Aufwandskonto, Vorsteuer-Konto+Satz, Geschaeftsfall.
-- Matching-Reihenfolge (KreditorMatcher): IBAN exakt -> Referenz-Praefix -> Name.
CREATE TABLE IF NOT EXISTS kreditor_regel (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  lieferant_name_pattern text NOT NULL,   -- Substring, case-insensitive
  lieferant_iban text,                     -- exakt (ohne Leerzeichen), nullable
  referenz_praefix text,                   -- z.B. '98' / '1537129' (Multi-Konto)
  aufwandskonto int NOT NULL,
  geschaeftsfall_id text,
  vorsteuer_konto int,                     -- 1170 / 1171 / null
  mwst_satz_percent numeric,               -- z.B. 8.1; 0 bei hoheitlich/MWST-frei
  mwst_pflichtig bool NOT NULL DEFAULT true,
  prioritaet int NOT NULL DEFAULT 0,       -- hoehere gewinnt bei Name-Mehrfachtreffer
  ist_aktiv bool NOT NULL DEFAULT true,
  lernquelle text,                         -- 'seed' | 'scan'
  gelernt_am timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE kreditor_regel ENABLE ROW LEVEL SECURITY;

CREATE POLICY kreditor_regel_user_isolation ON kreditor_regel
  FOR ALL USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS kreditor_regel_aktiv_idx
  ON kreditor_regel (user_id, ist_aktiv);
CREATE INDEX IF NOT EXISTS kreditor_regel_iban_idx
  ON kreditor_regel (lieferant_iban) WHERE lieferant_iban IS NOT NULL;
