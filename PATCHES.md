# Patches vs upstream `awp-worknet/mine-skill`

As of fork creation (2026-04-17). Merged from upstream `main@d8b6d59`.

## 1. `crawler/schema_runtime/model_config.py`

**Problem:** The config loader hardcodes `provider="openclaw"`. When OpenClaw
CLI isn't installed (typical VPS setup), LLM calls silently route to the wrong
handler and produce empty/garbage responses — surfacing as `score=0` on every
validator task.

**Fix:** Read `MINE_GATEWAY_PROVIDER` env var when set; fall back to the old
default otherwise.

## 2. `lib/platform_client.py`

**Problem:** Default HTTP timeout of 30 s is too tight for `api.minework.net`,
which occasionally takes 40–50 s to respond on `/evaluation-tasks/.../report`
under load. Causes spurious `read operation timed out` errors that mark valid
submissions as failed.

**Fix:** Bump `httpx.Client` timeout to 60 s.

## 3. `crawler/enrich/generative/llm_enrich.py` + `scripts/validator_runtime.py`

**Problem:** Default LLM eval timeout is 120 s. Under OpenRouter load (especially
google/gemini-2.0-flash-001 at peak hours) requests routinely take 90–150 s,
causing ~70% of validator reports to fall back to neutral `score=50` instead of
real evaluations. Platform accepts the report but treats neutrals as low-signal,
reducing reward weighting.

**Fix:** Bump default `timeout` in `enrich_with_llm`,
`_enrich_via_openclaw_cli`, `_enrich_via_model_config` from `120.0` → `240.0`,
and `cli_timeout` default in `ValidatorRuntime._read_config` /
`_write_default_config` from `120` → `240`.

## 4. `vps-setup/launch-validator.sh` (and equivalent local launchers)

**Problem:** `llm_enrich._requested_mode()` defaults to `"auto"` when neither
`MINE_LLM_MODE` nor `MINE_ENRICH_MODE` is set. In auto mode, priority is
`CLI > gateway > api`, so any host where `openclaw_cli_available()` returns
`True` (e.g. `openclaw_llm` pip dep installed) routes to OpenClaw CLI and hangs
on the eval timeout — even though `MINE_GATEWAY_PROVIDER=openai_compatible`
is set.

**Fix:** Force `MINE_LLM_MODE=gateway` in launchers so the gateway path is
always picked regardless of CLI availability.

---

Upstream PRs to watch — if any of these patches is accepted upstream, this
fork can drop them:

- model_config env var: (no PR filed yet — 2-line fix)
- platform timeout: (no PR filed yet — 1-line fix)
- eval timeout 120→240: (no PR filed yet — 5-line fix)
- MINE_LLM_MODE in launchers: launcher-only, no upstream change needed

## Merging upstream changes

```bash
git remote add upstream https://github.com/awp-worknet/mine-skill.git
git fetch upstream
git merge upstream/main
```

Both patched files have historically been untouched upstream, so merges are
clean. If upstream does touch them, resolve by taking upstream's version and
then re-applying the env-var read / timeout bump manually.
