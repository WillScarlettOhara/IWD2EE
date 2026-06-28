#!/usr/bin/env python3
"""Resolve live-game perf samples (raw iwd2.exe VAs) to RE function names.

Reads `perf script` output on stdin and ranks iwd2.exe functions two ways:
  * SELF  -- the leaf (topmost iwd2.exe frame) of each sample == where the CPU
             actually was. This is the bottleneck signal (fog-of-war = 47.7%).
  * INCL  -- any iwd2.exe frame anywhere on the sample's stack == time spent
             under that function (needs working call-graph unwind; may be shallow
             for a PE under wine, so trust SELF first).

Usage:  perf script -i perf.data | python3 resolve_perf.py
        perf script -i perf.data | python3 resolve_perf.py --top 40
"""
from __future__ import annotations

import argparse
import bisect
import collections
import json
import sys
from pathlib import Path

SYMS_PATH = Path(__file__).resolve().parent / "iwd2_symbols.json"


def load_syms(path: Path):
    syms = json.loads(path.read_text())
    addrs = [s[0] for s in syms]
    lo = addrs[0]
    hi = addrs[-1] + 0x4000  # slack past the last named fn
    return syms, addrs, lo, hi


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--syms", type=Path, default=SYMS_PATH)
    args = ap.parse_args()

    if not args.syms.exists():
        sys.exit(f"symbol map missing: {args.syms}\n  run: python3 gen_symbols.py")
    syms, addrs, LO, HI = load_syms(args.syms)

    def resolve(va: int) -> str:
        # aggregate by FUNCTION (name+file), not per-instruction offset -- the
        # offset just fragments a hot fn across many rows.
        i = bisect.bisect_right(addrs, va) - 1
        if i < 0:
            return f"?0x{va:x}"
        return f"{syms[i][1]} ({syms[i][2]})"

    self_counts: collections.Counter = collections.Counter()
    incl_counts: collections.Counter = collections.Counter()
    total = 0
    cur_leaf = None
    seen = set()
    saw_frame = False
    iwd2_samples = 0

    def flush():
        nonlocal cur_leaf, seen, saw_frame, total, iwd2_samples
        if not saw_frame:                # blank between samples / trailing EOF
            return
        if cur_leaf is not None:
            self_counts[cur_leaf] += 1
            iwd2_samples += 1
        for fn in seen:
            incl_counts[fn] += 1
        cur_leaf = None
        seen = set()
        saw_frame = False
        total += 1

    for line in sys.stdin:
        if not line.strip():            # blank line ends one sample's stack
            flush()
            continue
        parts = line.split()
        if not parts:
            continue
        try:
            va = int(parts[0], 16)
        except ValueError:
            continue                     # event header / comm line
        saw_frame = True                 # any frame (even non-iwd2) == real sample
        if LO <= va <= HI:
            fn = resolve(va)
            if cur_leaf is None:
                cur_leaf = fn            # topmost iwd2 frame == leaf
            seen.add(fn)
    flush()

    if total == 0:
        sys.exit("no samples parsed -- did you pipe `perf script` output?")
    cov = 100.0 * iwd2_samples / total
    print(f"=== samples: {total}   in-iwd2: {iwd2_samples} ({cov:.1f}%) ===")
    print(f"--- TOP {args.top} SELF (leaf iwd2.exe fn = the bottleneck) ---")
    for fn, c in self_counts.most_common(args.top):
        print(f"{100 * c / total:5.1f}%  {fn}")
    print(f"--- TOP {args.top} INCLUSIVE (iwd2.exe fn anywhere on stack) ---")
    for fn, c in incl_counts.most_common(args.top):
        print(f"{100 * c / total:5.1f}%  {fn}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
