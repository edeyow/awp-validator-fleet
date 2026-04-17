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

---

Upstream PRs to watch — if either of these patches is accepted upstream, this
fork can drop them:

- model_config env var: (no PR filed yet — 2-line fix)
- platform timeout: (no PR filed yet — 1-line fix)

## Merging upstream changes

```bash
git remote add upstream https://github.com/awp-worknet/mine-skill.git
git fetch upstream
git merge upstream/main
```

Both patched files have historically been untouched upstream, so merges are
clean. If upstream does touch them, resolve by taking upstream's version and
then re-applying the env-var read / timeout bump manually.
