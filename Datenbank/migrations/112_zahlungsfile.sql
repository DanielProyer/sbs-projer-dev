-- Migration 112: zahlungsfile — Batch-Tracking fuer GKB-pain.001-Exporte (TP-4).
-- Eine Zeile je generiertem Zahlungsfile; die exportierten eingangsrechnungen
-- verweisen via eingangsrechnung.zahlungsfile_id (Spalte existiert seit Migr. 106).
CREATE TABLE IF NOT EXISTS zahlungsfile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  msg_id text NOT NULL,
  format text NOT NULL DEFAULT 'pain.001.001.09',
  anzahl_tx int NOT NULL,
  ctrl_sum numeric NOT NULL,
  status text NOT NULL DEFAULT 'erstellt',   -- 'erstellt' | 'hochgeladen'
  erstellt_am timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE zahlungsfile ENABLE ROW LEVEL SECURITY;
CREATE POLICY zahlungsfile_user_isolation ON zahlungsfile
  FOR ALL USING (user_id = auth.uid());
CREATE INDEX IF NOT EXISTS zahlungsfile_user_idx ON zahlungsfile (user_id, erstellt_am DESC);
