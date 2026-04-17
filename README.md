# awp-validator-fleet

Fork of [`awp-worknet/mine-skill`](https://github.com/awp-worknet/mine-skill)
with two small patches that make validator runs stable on a headless VPS, plus
helper scripts for spinning up a fleet of validators.

- **[README-VPS.md](README-VPS.md)** — setup guide for deploying N validators on a VPS
- **[PATCHES.md](PATCHES.md)** — what we changed vs upstream and why
- **[SKILL.md](SKILL.md)** — full upstream documentation (mining, validating, schemas, etc.)

Everything else in this repo mirrors upstream. Pull upstream changes with:

```bash
git remote add upstream https://github.com/awp-worknet/mine-skill.git
git fetch upstream && git merge upstream/main
```
