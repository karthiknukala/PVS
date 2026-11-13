#!/usr/bin/env python3
"""Publish the PVS counterparts from a successful modular regression run."""
from pathlib import Path
import sys

bridge = Path(__file__).resolve().parents[1]
run = Path(sys.argv[1]).resolve()
run.relative_to(bridge / ".work" / "tests")
assert b"SAL-MODULAR-TESTS-PASSED" in (run / "tests.log").read_bytes()
assert b"SAL-MODULAR-REPLAY-PASSED" in (run / "replay.log").read_bytes()
destination = bridge / "examples" / "modular" / "pvs"
libraries = {path.name: path for path in (bridge / "theories").glob("*.pvs")}
files = {}
for case in ("counter-bounded", "open_component-latch", "open_component-connected",
             "open_component-interleaved", "nary-sync", "nary-async",
             "extra-nary_demo", "extra-quantified", "bad"):
    for source in (run / case).glob("*.pvs"):
        if source.name in libraries:
            continue
        text = source.read_text().replace(str(bridge) + "/", "src/sal/")
        if source.name in files:
            assert files[source.name] == text, f"Inconsistent shared theory: {source.name}"
        files[source.name] = text
destination.mkdir(parents=True, exist_ok=True)
for name, text in files.items():
    (destination / name).write_text(text)
for name in ("SAL_Module", "SAL_Module_Lift", "SAL_Indexed_Module",
             "SAL_Guarded_Action", "SAL_Transition_System", "SAL_Progress_Contract"):
    link = destination / f"{name}.pvs"
    if not link.is_symlink():
        link.symlink_to(f"../../../theories/{name}.pvs")
print(f"Published {len(files)} PVS counterparts in {destination}")
