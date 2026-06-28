#!/usr/bin/env python3
"""Build the persistent VA->function symbol map used by the perf resolver.

Source of truth = the RE project's recovered address map
(`iwd2-re/.ghidra-exports/address_map.json`), keyed by hex VA -> {full_name, file}.
The live shipped iwd2.exe loads at a fixed base 0x400000, so a sample's runtime
instruction pointer == VA directly -- no rebasing needed.

Output: `iwd2_symbols.json` next to this script, a list of [va, name, file]
sorted by va (binary-searchable by resolve_perf.py). Regenerate whenever the RE
source recovers new names:  python3 gen_symbols.py
"""
from __future__ import annotations

import json
from pathlib import Path

SRC = Path("/home/wills/iwd2-re/.ghidra-exports/address_map.json")
OUT = Path(__file__).resolve().parent / "iwd2_symbols.json"


def main() -> int:
    raw = json.loads(SRC.read_text())
    syms: list[tuple[int, str, str]] = []
    for k, v in raw.items():
        try:
            va = int(k, 16)
        except ValueError:
            continue
        name = v.get("full_name") or v.get("name") or f"sub_{va:08x}"
        syms.append((va, name, v.get("file", "")))
    # one symbol per address (first wins), sorted for bisect
    seen: dict[int, tuple[int, str, str]] = {}
    for s in syms:
        seen.setdefault(s[0], s)
    out = sorted(seen.values())
    OUT.write_text(json.dumps(out))
    print(f"wrote {OUT}  ({len(out)} symbols, 0x{out[0][0]:x}..0x{out[-1][0]:x})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
