#!/usr/bin/env bash
# One-command live-game profiler. Answers two questions per run:
#   1. CPU-bound or GPU-bound?            (gpu_cpu_sample.py)
#   2. Which iwd2.exe fn eats the CPU?    (perf record -> resolve_perf.py)
# Writes a timestamped, diff-able report to ./runs/ so before/after deltas are real.
#
# Usage:
#   ./profile.sh [SECONDS]            # attach to the running iwd2.exe (default)
#   ./profile.sh [SECONDS] --pid N    # attach to an explicit pid
#
# Bench protocol (so runs compare): load the SAME save (MPSave/000000036-combat),
# let it settle, leave the camera still, THEN run this. See README.md.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

DUR=30
PID=""
WAIT=0       # max sec to poll-wait for the game to launch (pid changes each run)
SETTLE=0     # sec to wait after pid appears before sampling (get in-world)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pid) PID="$2"; shift 2 ;;
    --wait) WAIT="$2"; shift 2 ;;
    --settle) SETTLE="$2"; shift 2 ;;
    *[!0-9]*) echo "bad arg: $1" >&2; exit 2 ;;
    *) DUR="$1"; shift ;;
  esac
done

# --- locate the live iwd2.exe process (proton/wine); poll-wait if asked ---
# pid changes every launch and iwd2.exe spawns AFTER the IWD2EE.exe launcher,
# so a one-shot pgrep races the launch. --wait polls until it appears.
if [[ -z "$PID" ]]; then
  deadline=$(( $(date +%s) + WAIT ))
  while :; do
    # -i: real proc is comm "IWD2.exe" (uppercase under proton); the literal dot
    # excludes the IWD2EE.exe launcher (no "iwd2.exe" substring in "IWD2EE.exe").
    PID="$(pgrep -fi 'iwd2\.exe' | head -1 || true)"
    [[ -n "$PID" && -d "/proc/$PID" ]] && break
    (( $(date +%s) >= deadline )) && break
    sleep 2
  done
fi
if [[ -z "$PID" ]] || [[ ! -d "/proc/$PID" ]]; then
  echo "iwd2.exe not running. Launch the game (and load the bench save), then re-run." >&2
  echo "  hint: ./profile.sh 30 --wait 180 --settle 25   # waits for launch, then settles" >&2
  exit 1
fi
echo "pid=$PID found"
if (( SETTLE > 0 )); then
  echo "settle ${SETTLE}s (get in-world, start moving)..."
  sleep "$SETTLE"
  [[ -d "/proc/$PID" ]] || { echo "process $PID gone during settle" >&2; exit 1; }
fi
echo "profiling pid=$PID for ${DUR}s"

# --- ensure the symbol map exists ---
[[ -f iwd2_symbols.json ]] || python3 gen_symbols.py

mkdir -p runs
TS="$(date +%Y%m%d-%H%M%S)"
DATA="runs/$TS.data"
REPORT="runs/$TS.txt"

# --- (1) GPU/CPU bound sampler in parallel with (2) perf record ---
GPULOG="$(mktemp)"
python3 gpu_cpu_sample.py "$PID" "$DUR" >"$GPULOG" 2>&1 &
GPUJOB=$!

# default fp call-graph: leaf IP (SELF) is always valid even when unwind is shallow
perf record -g -o "$DATA" -p "$PID" -- sleep "$DUR" 2>/dev/null || {
  echo "perf record failed (perf_event_paranoid=$(cat /proc/sys/kernel/perf_event_paranoid))." >&2
  echo "try: sudo sysctl kernel.perf_event_paranoid=1" >&2
  kill $GPUJOB 2>/dev/null || true
  exit 1
}
wait $GPUJOB || true

# --- assemble the report ---
{
  echo "############ iwd2 perf report  $TS  (pid=$PID, ${DUR}s) ############"
  echo
  echo "===== BOUND-BY (read this first) ====="
  cat "$GPULOG"
  echo
  echo "===== CPU SELF/INCLUSIVE (iwd2.exe functions) ====="
  perf script -i "$DATA" 2>/dev/null | python3 resolve_perf.py
} | tee "$REPORT"
rm -f "$GPULOG"
echo
echo "saved: $REPORT   (raw: $DATA)"
