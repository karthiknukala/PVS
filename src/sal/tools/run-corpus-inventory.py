#!/usr/bin/env python3
"""Inventory every native SAL example, without writing anywhere outside src/sal.

The manifest is deliberately exhaustive: parser failures and empty legacy XML
are recorded, not silently dropped or counted as successful frontend coverage.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET


BRIDGE = Path(__file__).resolve().parent.parent
SOURCE_SUFFIXES = {".sal", ".lsal", ".xml"}


def local_output(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if resolved != BRIDGE and BRIDGE not in resolved.parents:
        raise ValueError(f"Output must stay under {BRIDGE}: {resolved}")
    return resolved


def inventory_one(source: Path, root: Path, output: Path, environment: dict,
                  timeout: int) -> dict:
    relative = source.relative_to(root).as_posix()
    token = hashlib.sha256(relative.encode()).hexdigest()[:16]
    stdout_path = output / f"{token}.xml"
    stderr_path = output / f"{token}.stderr"
    result = {"source": relative, "format": source.suffix[1:],
              "bytes": source.stat().st_size,
              "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "native_status": "error", "context": None, "formals": [],
              "modules": [], "properties": [], "imports": [],
              "stdout": str(stdout_path.relative_to(BRIDGE)),
              "stderr": str(stderr_path.relative_to(BRIDGE))}
    command = [str(Path(environment["SAL_HOME"]) / "bin/salenv"),
               str(BRIDGE / "tools/run-corpus-inventory.scm"), str(source)]
    try:
        completed = subprocess.run(command, cwd=output, env=environment,
                                   text=True, capture_output=True, timeout=timeout)
        stdout, stderr, code = completed.stdout, completed.stderr, completed.returncode
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or b""
        stderr = exc.stderr or b""
        stdout = stdout.decode(errors="replace") if isinstance(stdout, bytes) else stdout
        stderr = stderr.decode(errors="replace") if isinstance(stderr, bytes) else stderr
        code = None
        result["native_status"] = "timeout"
    stdout_path.write_text(stdout)
    stderr_path.write_text(stderr)
    result["exit_status"] = code
    if code == 0:
        try:
            node = ET.fromstring(stdout)
            if node.tag != "SALCORPUS":
                raise ValueError(f"Unexpected inventory envelope: {node.tag}")
            result.update(native_status="accepted", context=node.attrib["CONTEXT"])
            result["formals"] = [dict(n.attrib) for n in node.findall("FORMALS/FORMAL")]
            result["modules"] = [
                {"name": n.attrib["NAME"], "formals": [dict(f.attrib) for f in n]}
                for n in node.findall("MODULE")]
            result["properties"] = [n.attrib["NAME"] for n in node.findall("PROPERTY")]
            result["imports"] = [n.attrib["NAME"] for n in node.findall("IMPORT")]
        except (ET.ParseError, ValueError, KeyError) as exc:
            result["native_status"] = "inventory-error"
            result["error"] = str(exc)
    if result["native_status"] != "accepted":
        result.setdefault("error", (stderr or stdout)[-4000:])
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.home() / "git/kn-sal/examples")
    parser.add_argument("--output", type=Path, default=BRIDGE / ".work/corpus/native")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--timeout", type=int, default=60)
    args = parser.parse_args()
    root = args.root.expanduser().resolve(strict=True)
    output = local_output(args.output)
    output.mkdir(parents=True, exist_ok=True)
    tmp = local_output(BRIDGE / ".work/corpus/tmp")
    tmp.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, TMPDIR=str(tmp))
    if "SAL_HOME" not in environment:
        parser.error("Set SAL_HOME to an existing SAL installation")
    files = sorted(p for p in root.rglob("*") if p.is_file())
    sources = [p for p in files if p.suffix.lower() in SOURCE_SUFFIXES]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        results = list(executor.map(
            lambda p: inventory_one(p, root, output, environment, args.timeout), sources))
    counts = {}
    for item in results:
        counts[item["native_status"]] = counts.get(item["native_status"], 0) + 1
    report = {"schema": 1, "root": str(root), "counts": counts,
              "source_count": len(sources), "sources": results,
              "other_files": [p.relative_to(root).as_posix() for p in files
                              if p.suffix.lower() not in SOURCE_SUFFIXES]}
    manifest = output / "manifest.json"
    manifest.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"manifest": str(manifest), "counts": counts,
                      "source_count": len(sources)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
