-- 171_event_dokumente_bucket_bilder.sql
-- Storage-Bucket event-dokumente: Bild-MIME-Typen zulassen.
--
-- Der Bucket wurde fuer den Dokumente-Tab (nur PDFs) angelegt und wies den
-- Lageplan-Upload (v0.83.0) mit 415 invalid_mime_type ab -- gemeldet Daniel
-- 13.08.2026 beim ersten Gampel-Upload. Direkt per SQL angewendet (13.08.),
-- hier zur Nachvollziehbarkeit.

update storage.buckets
set allowed_mime_types = array[
  'application/pdf', 'image/jpeg', 'image/png', 'image/webp'
]
where id = 'event-dokumente';
