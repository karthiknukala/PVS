#!/usr/bin/env python3
"""Exercise native normalization/serialization for every generated corpus case.

This is an independent diagnostic layer, not a substitute for PVS typechecking.
"""

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

bridge = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("cases", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--jobs", type=int, default=4)
parser.add_argument("--timeout", type=int, default=120)
args = parser.parse_args()
output = args.output.resolve()
if bridge not in output.parents:
    parser.error(f"Output must stay under {bridge}")
output.mkdir(parents=True, exist_ok=True)
tmp = bridge / ".work/corpus/tmp"
tmp.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, TMPDIR=str(tmp))
if "SAL_HOME" not in env:
    parser.error("Set SAL_HOME")
cases = json.loads(args.cases.read_text())["cases"]


def export(case):
    result = {key: case[key] for key in ("id", "source", "module")}
    try:
        completed = subprocess.run(
            [str(bridge / "tools/sal-view-export.sh"), case["input"], case["module"]],
            cwd=output, env=env, text=True, capture_output=True, timeout=args.timeout)
        stdout, stderr = completed.stdout, completed.stderr
        result["exit_status"] = completed.returncode
        result["status"] = "error"
        if completed.returncode == 0:
            try:
                document = ET.fromstring(stdout)
                if document.tag != "SALVIEW":
                    raise ValueError(f"Unexpected document {document.tag}")
                result["status"] = "exported"
                result["schema"] = document.attrib.get("VERSION")
                result["properties"] = len(document.findall("PROPERTIES/PROPERTY"))
            except (ET.ParseError, ValueError) as exc:
                result["error"] = str(exc)
    except subprocess.TimeoutExpired as exc:
        stdout, stderr = exc.stdout or b"", exc.stderr or b""
        stdout = stdout.decode(errors="replace") if isinstance(stdout, bytes) else stdout
        stderr = stderr.decode(errors="replace") if isinstance(stderr, bytes) else stderr
        result.update(status="timeout", exit_status=None)
    (output / (case["id"] + ".xml")).write_text(stdout)
    (output / (case["id"] + ".stderr")).write_text(stderr)
    if result["status"] != "exported":
        result.setdefault("error", (stderr or stdout)[-6000:])
    return result


with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
    results = list(executor.map(export, cases))
summary = {"case_count": len(cases), "exported": sum(r["status"] == "exported" for r in results),
           "results": results}
(output / "results.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps({key: value for key, value in summary.items() if key != "results"}, indent=2))
raise SystemExit(0 if summary["case_count"] == summary["exported"] else 1)
