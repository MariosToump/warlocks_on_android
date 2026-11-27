"""Run sim sandbox workers in parallel, then analyse.

    python -I tools/sim/run.py --mode ffa --rounds-per-worker 140 --workers 16

Each worker is a headless Godot running tools/sim/sandbox.gd with its own seed
(ffa: 1..N, duel: 1001.., scenario: 2001..); results go to tools/sim/out/<mode>/.
"""
import argparse, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
GODOT = "D:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
SEED_BASE = {"ffa": 0, "duel": 1000, "scenario": 2000}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="ffa", choices=list(SEED_BASE))
    ap.add_argument("--rounds-per-worker", type=int, default=20)
    ap.add_argument("--workers", type=int, default=16)
    ap.add_argument("--file", default="", help="scenario JSON (mode scenario)")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    out = a.out or os.path.join(HERE, "out", a.mode)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".jsonl"):
            os.remove(os.path.join(out, f))
    procs = []
    t0 = time.time()
    for i in range(1, a.workers + 1):
        seed = SEED_BASE[a.mode] + i
        args = [GODOT, "--headless", "--fixed-fps", "60", "--path", PROJECT, "-s", "tools/sim/sandbox.gd", "--",
                f"mode={a.mode}", f"rounds={a.rounds_per_worker}", f"seed={seed}",
                f"out={os.path.join(out, f'w{seed}.jsonl')}"]
        if a.file:
            args.append(f"file={a.file}")
        procs.append(subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    codes = [p.wait() for p in procs]
    print(f"{a.workers} workers x {a.rounds_per_worker} in {time.time() - t0:.0f} s, exit codes {sorted(set(codes))}")
    if a.mode != "scenario":
        sys.path.insert(0, HERE)
        import analyze
        analyze.main(out)


if __name__ == "__main__":
    main()
