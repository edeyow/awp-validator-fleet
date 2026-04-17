#!/bin/bash
# Launch all validators defined in wallets.json.
#
# Usage:
#   OPENROUTER_TOKEN=sk-or-v1-... ./launch-all.sh [path/to/wallets.json]
#
# Requires: jq, launch-validator.sh, wallets.json (from generate-wallets.py)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLETS_FILE="${1:-$SCRIPT_DIR/wallets.json}"

if [ -z "${OPENROUTER_TOKEN:-}" ]; then
  echo "ERROR: OPENROUTER_TOKEN env var is required" >&2
  echo "Usage: OPENROUTER_TOKEN=sk-or-v1-... $0 [wallets.json]" >&2
  exit 1
fi

if [ ! -f "$WALLETS_FILE" ]; then
  echo "ERROR: wallets file not found: $WALLETS_FILE" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required. Install: sudo apt install jq" >&2
  exit 3
fi

COUNT=$(jq 'length' "$WALLETS_FILE")
echo "[launch-all] Launching $COUNT validators from $WALLETS_FILE"

for i in $(seq 0 $((COUNT - 1))); do
  ID=$(jq -r ".[$i].id" "$WALLETS_FILE")
  PK=$(jq -r ".[$i].private_key" "$WALLETS_FILE")
  echo "---"
  "$SCRIPT_DIR/launch-validator.sh" "$ID" "$PK" "$OPENROUTER_TOKEN"
  # Small delay to avoid thundering herd on platform auth endpoints
  sleep 3
done

echo "---"
echo "[launch-all] All $COUNT validators launched."
echo "Verify: ps aux | grep run-validator-worker | grep -v grep | wc -l  # should show $COUNT"
