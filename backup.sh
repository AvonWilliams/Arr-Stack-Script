#!/usr/bin/env bash
# Archive the ARR stack configuration (compose file, .env, and all per-app
# configs under CONFIG_ROOT). Media libraries are NOT archived — they are too
# large and live on their own storage; their paths are recorded in MANIFEST.txt
# inside the archive so a restore knows where they belong.
#
# Usage: ./backup.sh [destination-dir]   (default: ./backups)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"
[[ -f .env ]] || { echo "No .env here — run ./install.sh first." >&2; exit 1; }

# Load CONFIG_ROOT / MEDIA_ROOT / DOWNLOADS_ROOT from .env.
set -a; # shellcheck source=/dev/null
. ./.env; set +a

DEST=${1:-./backups}
STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE="$DEST/arr-config-$STAMP.tar.gz"
mkdir -p "$DEST"

# Stage everything under one temp dir so the archive has a clean, flat layout.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp docker-compose.yml .env "$STAGE/"
cp -a "$CONFIG_ROOT" "$STAGE/config"
cat > "$STAGE/MANIFEST.txt" <<EOF
ARR stack backup — $STAMP
CONFIG_ROOT=$CONFIG_ROOT        (restored from ./config in this archive)
MEDIA_ROOT=$MEDIA_ROOT          (NOT in this archive — back up separately)
DOWNLOADS_ROOT=$DOWNLOADS_ROOT  (NOT in this archive — back up separately)
EOF

echo "[*] Archiving configuration to $ARCHIVE ..."
tar -czf "$ARCHIVE" -C "$STAGE" .
echo "[+] Backup complete: $ARCHIVE"
echo "    Media at $MEDIA_ROOT must be backed up separately."
