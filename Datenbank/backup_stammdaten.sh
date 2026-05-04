#!/bin/bash
# ─── SBS Projer: Stammdaten-Backup ───
# Exportiert alle geschützten Stammdaten als JSON nach Datenbank/backups/
# Aufruf: bash Datenbank/backup_stammdaten.sh
# Automatisch via Windows Task Scheduler täglich ausführen

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATE=$(date +%Y-%m-%d_%H%M)
TARGET="$BACKUP_DIR/$DATE"

mkdir -p "$TARGET"

cd "$SCRIPT_DIR/.."

TABLES=(
  "betriebe"
  "anlagen"
  "bierleitungen"
  "betrieb_kontakte"
  "betrieb_rechnungsadressen"
  "regionen"
  "preise"
  "konten"
  "buchungs_vorlagen"
  "pikett_dienste"
  "bergkundenpauschalen"
  "termine"
)

echo "=== SBS Projer Stammdaten-Backup ==="
echo "Datum: $DATE"
echo "Ziel:  $TARGET"
echo ""

for TABLE in "${TABLES[@]}"; do
  echo -n "  $TABLE ... "
  RESULT=$(npx supabase db query --linked "SELECT json_agg(t) FROM $TABLE t;" 2>/dev/null)
  # Extrahiere das JSON-Array aus der Supabase-Antwort
  echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
rows = data.get('rows', [])
if rows and rows[0].get('json_agg'):
    print(json.dumps(rows[0]['json_agg'], indent=2, ensure_ascii=False))
else:
    print('[]')
" > "$TARGET/$TABLE.json" 2>/dev/null || echo "[]" > "$TARGET/$TABLE.json"
  COUNT=$(python3 -c "import json; d=json.load(open('$TARGET/$TABLE.json')); print(len(d))" 2>/dev/null || echo "?")
  echo "$COUNT Einträge"
done

# Alte Backups aufräumen (älter als 30 Tage behalten, Rest löschen)
echo ""
echo "Aufräumen: Backups älter als 30 Tage..."
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +30 -not -name "backups" -exec rm -rf {} \; 2>/dev/null || true

echo ""
echo "=== Backup abgeschlossen: $TARGET ==="
