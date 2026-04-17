# AWP Validator Fleet — VPS Setup Guide

This repo is a fork of `awp-worknet/mine-skill` with two small patches that make
validator runs stable on a headless VPS. See [PATCHES.md](PATCHES.md) for the
full diff list.

Intended audience: **an LLM agent running on a fresh VPS** (Claude Code via SSH,
Openclaw, etc.) that needs to spin up N validators from scratch.

---

## TL;DR for the agent

```bash
# 1. Clone this repo
cd /opt
git clone https://github.com/<OWNER>/awp-validator-fleet.git
cd awp-validator-fleet

# 2. Install deps + create venv
bash vps-setup/install.sh

# 3. Generate N fresh wallets
cd vps-setup
python ../.venv/bin/python generate-wallets.py 12   # creates wallets.json

# 4. Print addresses, wait for user to fund + register them
cat wallets.json | jq -r '.[] | "\(.id): \(.address)"'
# → user funds each address with AWP, stakes, registers as validator
# → user confirms "all registered"

# 5. Launch all
OPENROUTER_TOKEN=sk-or-v1-... bash launch-all.sh

# 6. Verify
ps aux | grep run-validator-worker | grep -v grep | wc -l
tail -f ../output/validator-1/validator-*.log
```

---

## Prerequisites (VPS)

- Ubuntu 22.04+ / Debian 12+ (other Linux works too)
- Python 3.10 or newer
- `git`, `curl`, `jq` (`sudo apt install -y git curl jq python3-venv python3-pip`)
- Outbound HTTPS to `api.minework.net` and `openrouter.ai`
- RAM: ~100 MB per validator; 2 GB is enough for 12
- Disk: 2 GB for repo + venv + logs

## What's in this fork vs upstream

| File | Change |
|---|---|
| `crawler/schema_runtime/model_config.py` | Respect `MINE_GATEWAY_PROVIDER` env var instead of hardcoding `"openclaw"`. Required when using OpenRouter as the LLM backend. |
| `lib/platform_client.py` | HTTP timeout bumped from 30s to 60s. `api.minework.net` has slow endpoints; the shorter default caused spurious failures. |

Everything else is a vanilla mirror of upstream `awp-worknet/mine-skill` at the
time of the fork. Pull upstream changes with:

```bash
git remote add upstream https://github.com/awp-worknet/mine-skill.git
git fetch upstream
git merge upstream/main   # resolve trivially — patches are in non-contested files
```

---

## Detailed setup

### Step 1 — Clone and install

```bash
cd /opt
sudo mkdir -p awp-validator-fleet
sudo chown $USER:$USER awp-validator-fleet
git clone https://github.com/<OWNER>/awp-validator-fleet.git awp-validator-fleet
cd awp-validator-fleet
bash vps-setup/install.sh
```

`install.sh` creates `.venv/`, installs `requirements-core.txt`, adds
`eth-account`, and marks helper scripts executable. Idempotent.

### Step 2 — Generate wallets

```bash
cd vps-setup
../.venv/bin/python generate-wallets.py 12
```

Creates `wallets.json` with 12 fresh wallets (`validator-1` ... `validator-12`),
each with address + private key. **Chmod 600, do not commit.** (`.gitignore`
already excludes `wallets.json`.)

Print the addresses so the user can fund them:

```bash
jq -r '.[] | "\(.id): \(.address)"' wallets.json
```

### Step 3 — Fund and register (user action)

For each address:
1. Send AWP tokens to cover the stake (ask user for the current amount)
2. Register the wallet as a validator on the platform — either via the platform
   UI or CLI (see upstream `SKILL.md` → "Validator onboarding")
3. Confirm `status == registered` before proceeding

The agent can batch-register by iterating `wallets.json` and calling the
registration endpoint with each private key. Leave that to the user unless
they explicitly ask.

### Step 4 — Launch the fleet

```bash
export OPENROUTER_TOKEN="sk-or-v1-..."   # one token, shared across all validators
bash launch-all.sh
```

Each validator spawns a **detached** Python process (`run-validator-worker`).
The launch script's shell can exit, workers keep running. They do NOT tie to a
TTY, so `nohup` / `screen` / `tmux` are unnecessary.

### Step 5 — Verify

```bash
# Count running workers
pgrep -f run-validator-worker | wc -l
# Should match the number of wallets

# Live log tail for validator-1
tail -f /opt/awp-validator-fleet/output/validator-1/validator-*.log

# Status for all
for i in $(seq 1 12); do
  echo "=== validator-$i ==="
  tail -3 /opt/awp-validator-fleet/output/validator-$i/validator-*.log 2>/dev/null | tail -1
done
```

Healthy output looks like:

```
2026-04-17T07:17:10 INFO  validator.runtime Task claimed: task=evt_... assignment=asg_... dataset=ds_wikipedia
2026-04-17T07:17:10 INFO  validator.runtime Evaluation reported to platform: match score=95 task=evt_...
```

Non-zero scores = LLM path working. If you see `score=0` repeatedly, the fork's
patches probably aren't applied — verify `crawler/schema_runtime/model_config.py`
contains the `MINE_GATEWAY_PROVIDER` env read.

---

## Operations

### Stop everything

```bash
bash vps-setup/stop-all.sh
```

### Restart a single validator

```bash
pkill -f "run-validator-worker validator-3"  # or whatever session ID
bash vps-setup/launch-validator.sh validator-3 <PK> $OPENROUTER_TOKEN
```

### Systemd units (recommended for 24/7)

The `vps-setup/awp-validator@.service` template lets you manage each validator
as a systemd service — auto-restart on crash, starts on boot:

```bash
sudo cp vps-setup/awp-validator@.service /etc/systemd/system/
sudo mkdir -p /etc/awp-validator /var/log/awp-validator
sudo chown $USER /var/log/awp-validator

# Per-validator env file
for i in $(seq 1 12); do
  PK=$(jq -r ".[$((i-1))].private_key" vps-setup/wallets.json)
  sudo tee /etc/awp-validator/validator-$i.env >/dev/null <<EOF
VALIDATOR_PRIVATE_KEY=$PK
OPENROUTER_TOKEN=$OPENROUTER_TOKEN
EOF
  sudo chmod 600 /etc/awp-validator/validator-$i.env
done

sudo systemctl daemon-reload
for i in $(seq 1 12); do
  sudo systemctl enable --now awp-validator@validator-$i.service
done

# Check
sudo systemctl status 'awp-validator@*' --no-pager
```

---

## Troubleshooting

**All validators report `score=0`:**
The patch in `crawler/schema_runtime/model_config.py` is missing. Verify:

```bash
grep MINE_GATEWAY_PROVIDER crawler/schema_runtime/model_config.py
# Should find a match
```

**`HTTP 403 Forbidden` on submission fetches:**
Platform-side permission issue, not a code bug. Validator will keep trying next
tasks. Expect ~10-20% of tasks to hit this.

**`WebSocket disconnected` spam:**
Normal. Platform WS is flaky. Validators auto-reconnect.

**`Read operation timed out`:**
Platform API sluggishness. The 60s timeout patch mitigates this; occasional
timeouts are still expected.

**Rate-limited / IP banned:**
If all 12 validators from the same VPS IP get throttled, you may need
residential proxies. Contact AWP support first — many platforms tolerate
multi-wallet-per-IP.

---

## Files reference

| Path | Purpose |
|---|---|
| `vps-setup/install.sh` | One-shot install (venv + deps) |
| `vps-setup/generate-wallets.py` | Generate N fresh wallets → `wallets.json` |
| `vps-setup/launch-validator.sh` | Launch a single validator |
| `vps-setup/launch-all.sh` | Launch everything from `wallets.json` |
| `vps-setup/stop-all.sh` | Kill all running validators |
| `vps-setup/awp-validator@.service` | systemd unit template |
| `SKILL.md` | Upstream full documentation |
| `PATCHES.md` | What we changed vs upstream |
