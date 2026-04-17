#!/bin/bash
# Launch a single AWP validator worker.
#
# Usage:
#   ./launch-validator.sh <validator_id> <private_key> <openrouter_token>
#
# The worker spawns as a detached background process (double-fork via run_tool.py).
# Logs: <REPO_ROOT>/output/<validator_id>/validator-<session>.log
# Status: python scripts/run_tool.py validator-status (from repo root, with same env)

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <validator_id> <private_key> <openrouter_token>" >&2
  echo "Example: $0 validator-1 0xabc... sk-or-v1-..." >&2
  exit 1
fi

VALIDATOR_ID="$1"
PRIVATE_KEY="$2"
OPENROUTER_TOKEN="$3"

# Resolve repo root (parent of vps-setup/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Sanity checks
if [ ! -d ".venv" ]; then
  echo "ERROR: .venv not found at $REPO_ROOT/.venv — run vps-setup/install.sh first" >&2
  exit 2
fi

# Activate venv (works on both Linux and macOS)
# shellcheck source=/dev/null
source .venv/bin/activate

# Export env vars
export VALIDATOR_PRIVATE_KEY="$PRIVATE_KEY"
export VALIDATOR_OUTPUT_ROOT="$REPO_ROOT/output/$VALIDATOR_ID"
export VALIDATOR_ID="$VALIDATOR_ID"
# Force gateway path — without this the worker auto-detects openclaw CLI and
# wedges on 120s/240s timeouts instead of using OpenRouter (PATCHES.md #3).
export MINE_LLM_MODE="gateway"
export MINE_GATEWAY_PROVIDER="openai_compatible"
export MINE_GATEWAY_TOKEN="$OPENROUTER_TOKEN"
export MINE_GATEWAY_BASE_URL="https://openrouter.ai/api/v1"
export MINE_ENRICH_MODEL="google/gemini-2.0-flash-001"
export MINE_GATEWAY_MODEL="google/gemini-2.0-flash-001"
export PYTHONIOENCODING="utf-8"
export MINE_AUTO_UPDATE="0"

mkdir -p "$VALIDATOR_OUTPUT_ROOT"

echo "[launch] Starting $VALIDATOR_ID (output: $VALIDATOR_OUTPUT_ROOT)"
python scripts/run_tool.py validator-start

echo "[launch] Worker spawned (detached). Tail log with:"
echo "  tail -f $VALIDATOR_OUTPUT_ROOT/validator-*.log"
