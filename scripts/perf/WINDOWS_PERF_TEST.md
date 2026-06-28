# Windows perf test — handoff brief (for a fresh Claude Code session)

You are a Claude Code session running on **Windows** (dual-boot). The matching
Linux/proton session did a full 4K render-perf investigation of **IWD2EE** (an
Icewind Dale 2 mod with a re-enabled native OpenGL renderer). This file is the
self-contained handoff — read it fully before acting. There is no shared memory
across the boot; everything you need is here.

## Why you exist: ONE decision to inform
Linux/proton perf is mapped and the cheap levers are spent. The single open
question is: **is a tile texture atlas worth building?** Windows answers it,
because Windows removes the wine/proton translation layer and (with a GL tracer)
exposes the real GL call mix. You are a **measurement** run — you will not fix
anything, you bring two numbers back.

## What the Linux session already established (the baseline)
- Engine renders the world with the **native OpenGL renderer** (CVideo3d),
  re-enabled by the IEexHelper patch. It is **immediate-mode GL 1.x** (glBegin/
  glEnd, per-tile glBindTexture + textured quad).
- The big win was already taken: fog-of-war was 47.7% of the frame → rewritten
  to a single texture → **+67% (55→92fps)**. That is committed.
- **Post-fog, under proton (proton-cachyos / proton-experimental):**
  - Render-bound at **~90-100fps @ 3840x2160**, fluctuates with on-screen actor
    count (NOT vsync-capped).
  - **CPU/GL-driver-bound, GPU idle (~37%).** Limiter = the single main render
    thread (~50-60% busy, blocks the rest of the frame on GL/present).
  - Scene-INVARIANT: idle == heavy combat. **Tiles dominate**, not sprites
    (`CVidTile::RenderTexture` ~9% vs `CVidCell::RenderTexture` ~1%).
  - Frame CPU split (Linux `perf` DSO self-time): **nvidia GL driver ~30-35%**,
    iwd2.exe game code ~25-30%, **wine/wow64 layer ~15-20%** (32→64 thunks +
    opengl32 translation + ntdll sync), audio (dsound) ~3-10%.
  - Proven NON-levers (measured ~0): removing the per-GL-call debug check
    `CVidMode::CheckResults3d`; removing the redundant per-tile `glTexParameterf`.
    → the ~30% driver cost is **per-tile `glBindTexture` + the quad draw itself**,
    which only a **texture atlas** (one bind for many tiles) could cut.
  - proton-cachyos → proton-experimental gave only **+5-10fps** (it trimmed the
    wine sync layer, not the bottleneck).

Key engine address for reference: `CVidTile::RenderTexture` @ **0x7C64F0** (the
per-tile draw); upload path `CVidTile::ReadyTexture` @ 0x7C5F60 / 0x7C61D0.
iwd2.exe image base 0x400000 (runtime VA == file VA).

## The two numbers to bring back

### TIER 1 — wine-tax (easy, do this first)
Native-Windows fps vs the ~90-100 proton number, same kind of scene.
1. Make sure **IWD2EE is installed** on the Windows GOG copy of IWD2 (same mod —
   it must run the GL renderer; `IEexHelper.dll` present, `[Program Options]
   3D Acceleration=1`). If only stock IWD2 is installed, say so — install IWD2EE
   via its WeiDU setup first, or tell the user.
2. In `icewind2.ini` set `[IEex Options] Show FPS=1`, `Vsync=0`, resolution
   3840x2160 (match the Linux test). Launch.
3. Load any **tile-heavy** scene (outdoor/town), keep the camera still, read the
   FPS overlay. Note the area + fps.

Interpretation you should report:
- Windows ≈ 100 (similar to proton) → bottleneck is the **game's GL design**,
  present on both OSes → **a tile atlas helps everywhere → worth building.**
- Windows ≫ (e.g. 150+) → most of the Linux cost is **wine-tax** (unfixable
  without leaving wine) → **atlas is lower value, likely skip.**

### TIER 2 — GL call census (the real prize, if tooling cooperates)
Count the GL calls per frame so the bind-vs-draw split is known directly.
- **Preferred tool: apitrace** (https://apitrace.github.io) — it supports legacy
  immediate-mode GL, which RenderDoc/Nsight handle poorly. Method: drop apitrace's
  wrapper `opengl32.dll` into the game folder next to `iwd2.exe` (DLL-injection
  mode — works regardless of the IWD2EE.exe launcher), run the game a few seconds
  in a tile-heavy scene, then `apitrace dump-stats <trace>` (or dump + count).
- Report, per frame: total draw calls, **`glBindTexture` count**, glBegin/
  glDrawArrays count, glTexImage/glTexSubImage count (uploads), and which call
  type dominates GPU/CPU time if the tool shows it.
- If apitrace won't attach (launcher/anti-debug/x86 issues), fall back to
  RenderDoc (may not capture glBegin/glEnd — note if so), or just deliver Tier 1.

Interpretation:
- `glBindTexture` count ≈ visible-tile count and dominates → **atlas is the lever**
  (atlas collapses thousands of binds to a handful).
- Draws/fill dominate with few binds → atlas won't help much; it is raster/upload
  bound → different problem.

## How to report back
Write findings to **`scripts/perf/WINDOWS_RESULTS.md`** in this repo and commit on
a branch (e.g. `perf/windows-findings`), or just paste the numbers to the user to
relay to the Linux session. Include: Windows fps + scene, proton comparison, and
(if you got Tier 2) the per-frame GL call counts. Keep it short and factual.

## Boundaries
- Measurement only — do **not** modify engine code or the renderer here.
- IEexHelper C++ is confidential; do not publish it.
- If IWD2EE isn't installed on Windows or the GL renderer won't start, stop and
  report that — don't improvise a different game/config.
