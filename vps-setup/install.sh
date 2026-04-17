#!/bin/bash
# One-shot VPS installer for AWP validator fleet.
# Creates .venv, installs deps, sets up directory structure.
#
# Usage:  ./install.sh
# Prereqs: python3.11+ (python3.10 works too), git, curl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "[install] Repo root: $REPO_ROOT"

# 1. Python check
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found. Install Python 3.11+ first." >&2
  exit 1
fi
PY_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
echo "[install] Python: $PY_VERSION"

# 2. Create venv
if [ ! -d ".venv" ]; then
  echo "[install] Creating venv..."
  python3 -m venv .venv
else
  echo "[install] venv exists, reusing"
fi

# shellcheck source=/dev/null
source .venv/bin/activate

# 3. Upgrade pip
pip install --upgrade pip --quiet

# 4. Install deps
echo "[install] Installing core requirements..."
pip install -r requirements-core.txt --quiet

echo "[install] Installing eth-account (for wallet generation + signing)..."
pip install eth-account --quiet

# 5. Quick sanity check
echo "[install] Verifying imports..."
python -c "import eth_account, websockets, httpx; print('  OK')"

# 6. Make scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

echo ""
echo "[install] Done. Next steps:"
echo "  1. cd $SCRIPT_DIR"
echo "  2. python generate-wallets.py 12        # create wallets.json"
echo "  3. Fund each address with AWP tokens + register on platform"
echo "  4. OPENROUTER_TOKEN=sk-or-v1-... ./launch-all.sh"
