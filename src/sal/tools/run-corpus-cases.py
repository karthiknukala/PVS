#!/usr/bin/env python3
"""Generate exhaustive Lisp cases from a fresh native SAL inventory manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

BRIDGE = Path(__file__).resolve().parent.parent


def lisp_string(text: str) -> str:
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def template_cases(root: Path, selection: str | None) -> list[dict]:
    """Use documented substitutions only; never execute the legacy run.sh files."""
    recipes = json.loads((BRIDGE / "tests/corpus-templates.json").read_text())["templates"]
    results = []
    for recipe in recipes:
        if selection and selection not in recipe["source"]:
            continue
        source = root / recipe["source"]
        if not source.exists():
            continue
        original = source.read_text()
        text = original
        for name, value in recipe["representative"].items():
            text = text.replace("@par_" + name, value)
        if re.search(r"@par_\w+", text):
            raise ValueError(f"Unsubstituted parameter in documented template {source}")
        directory = BRIDGE / ".work/corpus/templates" / recipe["directory"]
        directory.mkdir(parents=True, exist_ok=True)
        target = directory / (recipe["representative"]["filename"] + ".sal")
        target.write_text(text)
        metadata = dict(recipe, original_sha256=hashlib.sha256(original.encode()).hexdigest(),
                        recipe_sha256=hashlib.sha256((root / recipe["recipe"]).read_bytes()).hexdigest(),
                        generated_sha256=hashlib.sha256(text.encode()).hexdigest(),
                        generated_source=str(target))
        environment = dict(os.environ, TMPDIR=str(BRIDGE / ".work/corpus/tmp"))
        completed = subprocess.run(
            [str(Path(environment["SAL_HOME"]) / "bin/salenv"),
             str(BRIDGE / "tools/run-corpus-inventory.scm"), str(target)],
            cwd=directory, env=environment, text=True, capture_output=True, timeout=60)
        (directory / "native.xml").write_text(completed.stdout)
        (directory / "native.stderr").write_text(completed.stderr)
        try:
            node = ET.fromstring(completed.stdout)
            metadata["native_status"] = "accepted" if completed.returncode == 0 and node.tag == "SALCORPUS" else "error"
        except ET.ParseError:
            metadata["native_status"] = "error"
        (directory / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
        identity = recipe["source"] + "::documented-instance::" + recipe["module"]
        results.append({"source": recipe["source"], "module": recipe["module"],
                        "input": str(target), "id": hashlib.sha256(identity.encode()).hexdigest()[:20],
                        "context_formals": [], "module_formals": [], "template": metadata})
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--select", help="Optional substring selection for a diagnostic rerun")
    args = parser.parse_args()
    output = args.output.resolve()
    if BRIDGE not in output.parents:
        parser.error(f"Output must stay under {BRIDGE}")
    inventory = json.loads(args.manifest.read_text())
    cases = []
    root = Path(inventory["root"])
    for source in inventory["sources"]:
        if source["native_status"] != "accepted":
            continue
        if args.select and args.select not in source["source"]:
            continue
        for module in source["modules"] or [{"name": "--context", "formals": []}]:
            identity = source["source"] + "::" + module["name"]
            cases.append({"source": source["source"], "module": module["name"],
                          "input": str(root / source["source"]),
                          "source_sha256": source["sha256"],
                          "id": hashlib.sha256(identity.encode()).hexdigest()[:20],
                          "context_formals": source["formals"],
                          "module_formals": module["formals"]})
    cases.extend(template_cases(root, args.select))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        ";;; Generated from the native manifest; do not hand-curate away failures.\n"
        "(in-package :pvs)\n(defparameter *sal-corpus-cases* '(\n" +
        "".join("  (" + " ".join(lisp_string(case[key]) for key in ("id", "source", "module", "input")) + ")\n"
                for case in cases) + "))\n")
    output.with_suffix(".json").write_text(json.dumps({
        "source_root": inventory["root"], "selection": args.select,
        "inventory_manifest": str(args.manifest.resolve()),
        "inventory_sha256": hashlib.sha256(args.manifest.read_bytes()).hexdigest(),
        "case_count": len(cases), "source_count": len({(c["source"], "template" in c) for c in cases}),
        "native_rejections": [s for s in inventory["sources"] if s["native_status"] != "accepted"],
        "cases": cases}, indent=2) + "\n")
    print(f"Generated {len(cases)} cases from {len({(c['source'], 'template' in c) for c in cases})} native sources/template instances")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
