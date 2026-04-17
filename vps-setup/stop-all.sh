#!/bin/bash
# Stop all running validator workers on this machine.
# Safe — only kills processes matching `run-validator-worker`.

set -euo pipefail

PIDS=$(pgrep -f "run_tool.py run-validator-worker" || true)

if [ -z "$PIDS" ]; then
  echo "[stop-all] No validator workers running."
  exit 0
fi

COUNT=$(echo "$PIDS" | wc -l)
echo "[stop-all] Stopping $COUNT validator workers: $PIDS"

# SIGTERM first
kill $PIDS 2>/dev/null || true
sleep 3

# SIGKILL stragglers
REMAINING=$(pgrep -f "run_tool.py run-validator-worker" || true)
if [ -n "$REMAINING" ]; then
  echo "[stop-all] Force-killing stragglers: $REMAINING"
  kill -9 $REMAINING 2>/dev/null || true
fi

echo "[stop-all] Done."
