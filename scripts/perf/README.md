# iwd2 perf measurement system

Stop guessing at bottlenecks. Every run answers, in order:

1. **CPU-bound or GPU-bound?** — `gpu_cpu_sample.py` (GPU util vs busiest thread).
   perf only sees CPU; this stops you profiling the wrong half.
2. **Which iwd2.exe function eats the CPU?** — `perf record` → `resolve_perf.py`,
   ranked by SELF time. This is how the fog-of-war wall was found (47.7% self).
3. *(Phase 2)* **Objective per-frame ms** and **which GL ops dominate** — from
   in-engine hooks, GPU-inclusive (perf can't see GPU).

Reports land in `runs/<timestamp>.txt`, diff-able for before/after deltas.

## Phase 1 — host profiler (built, no game rebuild)

```
gen_symbols.py     iwd2-re/.ghidra-exports/address_map.json -> iwd2_symbols.json
                   (7259 VAs; live iwd2.exe loads @0x400000 so runtime IP == VA)
resolve_perf.py    `perf script` stdin -> ranked SELF + INCLUSIVE fn tables
gpu_cpu_sample.py  <pid> <sec> -> GPU/CPU sample + CPU-vs-GPU-bound verdict
profile.sh [SEC]   orchestrator: find pid, run both, write runs/<ts>.txt
```

Run it:

```bash
./profile.sh 30            # attach to running iwd2.exe, 30s
./profile.sh 30 --pid 1234 # explicit pid
python3 gen_symbols.py     # refresh symbol map after RE recovers new names
```

Reading the SELF table: the leaf == where the CPU actually was. Trust SELF over
INCLUSIVE (PE-under-wine call-graph unwind is shallow, so INCLUSIVE may be thin).

## Bench protocol (so runs are comparable)

Deltas are only real if the scene is identical. Until the auto-load tool is
revived (see below), do it by hand:

1. Launch the game (Heroic).
2. Load the **same** save every time. Designated benches:
   - `MPSave/000000036-combat` — worst-case combat (fog + sprites + spell FX).
   - `MPSave/000000038-newOpenGL` — outdoor/background-heavy.
3. Let it settle ~5s. **Leave the camera still** (scroll changes the cost).
4. `./profile.sh 30`.

Same save + same camera + same duration == trustworthy before/after numbers.

> Hands-free auto-load (`[IEex Options] AutoLoadSlot=N`) exists but is currently
> BROKEN/disabled (opened a stray window, froze manual load). Reviving it =
> Phase 2.5; until then load manually.

## Notes / gotchas

- `perf_event_paranoid=2` is fine — profiling your own process is allowed. If
  `perf record` ever fails: `sudo sysctl kernel.perf_event_paranoid=1`.
- **Do not benchmark on win11vm** — virtio-gpu, not passthrough; GL perf is
  meaningless there. Profile the live game on this host only.
- Movement looking "not fluid" is the IE 30Hz sprite sim, *not* a perf problem —
  don't chase it with this tool.

## Phase 2 — in-engine instrumentation (needs IEexHelper rebuild)

Gated by ini `[IEex Options] Perf Log=1`. Writes CSV to `runs/`.

**(B) frametime logger** — hook the frame-present boundary (reuse the existing
front-buffer present hook; or `CGameArea::Render` GL flush @0x47785b). Each
present: `QueryPerformanceCounter` delta → append `frame,ms,fps` to
`runs/frametime.csv`. Objective, GPU-inclusive ground-truth for A/B deltas.

**(C) GL call stats** — wrap the `gl*` fn-pointer statics (NOT graph edges → Read
the GL call-chain in IEexHelper) to count per frame: `glBegin/glEnd`,
`glDrawArrays/Elements`, `glTexSubImage2D` (+bytes), `glEnable/glBlendFunc`,
`glBindTexture`. Snapshot+reset at present → `runs/glstats.csv`. Makes
state-thrash bugs (fog = 13 GL calls/cell × thousands) jump out numerically.

**(2.5) revive AutoLoadSlot** — debug the broken auto-load so `profile.sh --scene
combat` can land in the bench scene hands-free. See memlite `793a6d605e96`.
