#!/usr/bin/env bash
# Pull the latest images for the stack and recreate the containers.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"
[[ -f docker-compose.yml ]] || { echo "No docker-compose.yml here — run ./install.sh first." >&2; exit 1; }

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Docker Compose not found." >&2; exit 1
fi

echo "[*] Pulling latest images..."
"${COMPOSE[@]}" pull
echo "[*] Recreating containers..."
"${COMPOSE[@]}" up -d
echo "[*] Removing dangling images..."
docker image prune -f
echo "[+] Update complete."
