"""Benchmark a built PVS in disposable contexts. See README.md for commands."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from selectors import DefaultSelector, EVENT_READ

CASES = {
    "cheri": ("top64", [], ""),
    "cheri-restore": ("top64", [], ""),
    "cheri-xref": ("top64", ["top64"], ""),
    "cheri-proof": ("cheri_reg_properties_64", ["cheri_reg_properties_64"],
                    "cheri_reg_properties_64"),
    "smt": ("hashcons_term_manager", ["ics_types", "ics_semantic_nodes"], ""),
    "inference": ("grs", ["models", "grs", "certified", "strategies", "development", "generalized"], "grs_relations"),
    "ints": ("gcd", [], ""),
    "ints-proof": ("gcd", ["gcd"], "gcd"),
    "orders": ("top", [], ""),
    "startup": ("", [], ""),
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("pvs", type=Path)
parser.add_argument("workload", choices=CASES)
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--repeats", type=int, default=3)
parser.add_argument("--binary-cache", type=Path,
                    help="Reuse .pvscontext and pvsbin/ from a matching CHERI source tree")
args = parser.parse_args()
if args.repeats < 1:
    parser.error("--repeats must be positive")
program = args.pvs.resolve()
source = args.source.resolve()
driver = Path(__file__).with_name("bench.lisp").resolve()
target, prepare, proof = CASES[args.workload]
cached = args.workload in {"cheri-restore", "cheri-xref", "cheri-proof"}
if args.binary_cache and not cached:
    parser.error("--binary-cache requires a cached CHERI workload")


def time_startup(command, work, env):
    marker = '(progn (format t "~&READY~%") (finish-output) (sb-ext:exit))'
    start = time.perf_counter()
    with subprocess.Popen(command + ["-E", marker], cwd=work, env=env,
                          stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT) as process, DefaultSelector() as selector:
        selector.register(process.stdout, EVENT_READ)
        output = bytearray()
        try:
            while b"READY" not in output.splitlines():
                if not selector.select(max(0, start + 60 - time.perf_counter())):
                    raise TimeoutError("PVS did not reach its startup marker")
                chunk = os.read(process.stdout.fileno(), 4096)
                if not chunk:
                    raise RuntimeError(output.decode(errors="replace"))
                output.extend(chunk)
            seconds = time.perf_counter() - start
            if process.wait(timeout=30):
                raise RuntimeError("PVS failed at startup")
            return seconds
        finally:
            if process.poll() is None:
                process.kill()


rows = []
for trial in range(args.repeats):
    with tempfile.TemporaryDirectory(prefix="pvs-bench-") as tmp:
        root = Path(tmp)
        nasalib = args.workload in {"ints", "ints-proof", "orders"}
        work = root / args.workload.split("-")[0] if nasalib else root
        inputs = (() if args.workload == "startup" else
                  source.glob("*/*") if nasalib else source.glob("*"))
        for p in inputs:
            if p.is_file() and p.suffix in {".pvs", ".prf"}:
                dest = root / p.relative_to(source)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, dest)
        if target and not (work / f"{target}.pvs").is_file():
            parser.error(f"{target}.pvs not found under {source}")
        env = dict(os.environ, PVS_LIBRARY_PATH=tmp if nasalib else "", PVS_LOG_DIR=tmp,
                   BENCH_TARGET=target, BENCH_PREPARE=" ".join(prepare), BENCH_PROOF=proof,
                   BENCH_RESTORE="1" if args.workload == "cheri-restore" else "",
                   BENCH_XREF="1" if args.workload == "cheri-xref" else "")
        command = [str(program), "-q", "-raw", "-patchlevel", "none"]
        if args.workload == "startup":
            row = dict(workload=args.workload, trial=trial, seconds=time_startup(command, work, env))
            print(row, flush=True)
            rows.append(row)
            continue
        if cached:
            if args.binary_cache:
                shutil.copytree(args.binary_cache / "pvsbin", root / "pvsbin")
                shutil.copy2(args.binary_cache / ".pvscontext", root / ".pvscontext")
            else:
                save = ('(progn (assert (pvs::typecheck-file "top64")) '
                        '(pvs::save-context nil t) (sb-ext:exit))')
                subprocess.run(command + ["-E", save], cwd=work, env=env, check=True,
                               stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=600)
        run = subprocess.run(command + ["-L", str(driver)],
                             cwd=work, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=600)
        log = run.stdout.decode(errors="replace")
        m = re.search(r"^BENCH (\S+) (\d+) (\d+)", log, re.M)
        if run.returncode or not m or not re.search("^CHECKED$", log, re.M):
            raise RuntimeError(log[-4000:])
        if cached and not re.search("^Restored theory from ", log, re.M):
            raise RuntimeError("No theory restored from the binary cache")
        if args.workload == "cheri-restore" and log.count("Restored theory from ") != 39:
            raise RuntimeError("Expected 39 restored CHERI theories")
        if proof:
            count = {"cheri-proof": 5, "ints-proof": 60, "inference": 7}[args.workload]
            if not re.search(fr"\b{count} formulas, {count} attempted, {count} succeeded", log):
                raise RuntimeError(f"Did not replay all {count} proofs\n{log[-3000:]}")
        row = dict(workload=args.workload, trial=trial, seconds=float(m[1]), bytes=int(m[2]),
                   peak_rss_bytes=int(m[3]) * (1 if sys.platform == "darwin" else 1024),
                   signature=hashlib.sha256((work / "signature.txt").read_bytes()).hexdigest())
        print(row, flush=True)
        rows.append(row)
args.output.write_text(json.dumps(rows, indent=2) + "\n")
