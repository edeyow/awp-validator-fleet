#!/usr/bin/env python3
"""Generate N fresh Ethereum wallets for AWP validator use.

Usage:
    python generate-wallets.py 12

Outputs wallets.json with format:
    [
      {"id": "validator-1", "address": "0x...", "private_key": "0x..."},
      ...
    ]

WARNING: wallets.json contains private keys. Keep it secret, keep it safe.
Move/chmod 600 it after generation. Do NOT commit it.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    from eth_account import Account
except ImportError:
    print("Missing eth_account. Run: pip install eth-account", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <count>", file=sys.stderr)
        sys.exit(2)

    try:
        count = int(sys.argv[1])
    except ValueError:
        print("count must be an integer", file=sys.stderr)
        sys.exit(2)

    if count < 1 or count > 100:
        print("count must be 1..100", file=sys.stderr)
        sys.exit(2)

    # Enable HD wallet features
    Account.enable_unaudited_hdwallet_features()

    wallets = []
    for i in range(1, count + 1):
        acct = Account.create()
        wallets.append({
            "id": f"validator-{i}",
            "address": acct.address,
            "private_key": acct.key.hex() if isinstance(acct.key, bytes) else str(acct.key),
        })

    out = Path("wallets.json")
    if out.exists():
        print(f"Refusing to overwrite existing {out}", file=sys.stderr)
        sys.exit(3)

    out.write_text(json.dumps(wallets, indent=2) + "\n", encoding="utf-8")
    try:
        # Unix perms — ignore failure on Windows
        out.chmod(0o600)
    except OSError:
        pass

    print(f"Generated {count} wallets → {out.resolve()}")
    print("\nAddresses (for funding / registration):")
    for w in wallets:
        print(f"  {w['id']}: {w['address']}")
    print("\nIMPORTANT: wallets.json contains private keys. Keep it secure.")


if __name__ == "__main__":
    main()
