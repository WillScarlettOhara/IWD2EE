#!/usr/bin/env python3
"""Sample GPU util + per-thread CPU of the live game -> CPU-bound vs GPU-bound.

perf record only sees CPU. It cannot tell you whether the frame is limited by
the GPU or by the CPU. This sampler answers that FIRST so you don't profile the
wrong half:

  * GPU util       -- nvidia-smi utilization.gpu (whole card; close enough, the
                      game is the only heavy GPU client during a bench).
  * proc CPU       -- sum of all threads, in cores (e.g. 1.6 = 1.6 cores busy).
  * busiest thread -- the single hottest thread as % of ONE core. The IE engine
                      renders on one thread, so this saturating at ~100% while
                      the GPU idles == CPU/single-thread-bound (the usual wall).

Usage:  python3 gpu_cpu_sample.py <pid> <seconds>
"""
from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

CLK = 100  # SC_CLK_TCK (jiffies/sec); fixed on this kernel


def thread_jiffies(pid: int) -> dict[int, int]:
    """tid -> utime+stime jiffies, for every thread of pid."""
    out = {}
    task = Path(f"/proc/{pid}/task")
    try:
        tids = [int(p.name) for p in task.iterdir()]
    except FileNotFoundError:
        return out
    for tid in tids:
        try:
            fields = (task / str(tid) / "stat").read_text().rsplit(") ", 1)[1].split()
        except (FileNotFoundError, IndexError):
            continue
        # after "comm) ": state=0 ... utime=11 stime=12 (0-indexed from here)
        out[tid] = int(fields[11]) + int(fields[12])
    return out


def gpu_util() -> int:
    try:
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2)
        return int(r.stdout.strip().splitlines()[0])
    except Exception:
        return -1


def main() -> int:
    if len(sys.argv) < 3:
        sys.exit("usage: gpu_cpu_sample.py <pid> <seconds>")
    pid = int(sys.argv[1])
    dur = float(sys.argv[2])

    gpu_samples, proc_samples, thread_samples = [], [], []
    prev = thread_jiffies(pid)
    t0 = time.time()
    n = 0
    while time.time() - t0 < dur:
        time.sleep(1.0)
        n += 1
        cur = thread_jiffies(pid)
        if not cur:
            print(f"t{n:02d} process {pid} gone")
            break
        per_thread = {tid: cur[tid] - prev.get(tid, cur[tid]) for tid in cur}
        prev = cur
        proc_cores = sum(per_thread.values()) / CLK          # cores busy
        busiest = (max(per_thread.values()) / CLK) * 100      # % of one core
        g = gpu_util()
        gpu_samples.append(g)
        proc_samples.append(proc_cores)
        thread_samples.append(busiest)
        print(f"t{n:02d} gpu={g}%  proc={proc_cores:.2f}cores  busiest_thread={busiest:.0f}%")

    if not gpu_samples:
        return 1
    avg = lambda xs: sum(xs) / len(xs)
    g, p, b = avg(gpu_samples), avg(proc_samples), avg(thread_samples)
    print("-" * 48)
    print(f"AVG  gpu={g:.0f}%  proc={p:.2f}cores  busiest_thread={b:.0f}%")
    if b >= 85 and g < 70:
        verdict = "CPU-bound (single thread saturated, GPU idle) -> perf record is the right tool"
    elif g >= 85:
        verdict = "GPU-bound -> perf won't show it; look at GL state/fill/upload (glstats)"
    elif g < 60 and b < 85:
        verdict = "neither saturated -> CPU-side GL SUBMISSION overhead (wine call cost) likely"
    else:
        verdict = "mixed -> inspect raw numbers + perf SELF table"
    print(f"VERDICT: {verdict}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
