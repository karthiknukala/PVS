"""Regression probes for native proof metadata and dynamically private caches."""
import os
from pathlib import Path
import subprocess

AGENT = Path(__file__).resolve().parents[1]
PVS = AGENT.parent / "pvs"


def test_native_proof_record_and_runtime_isolation(tmp_path):
    context = tmp_path / "context"
    context.mkdir()
    (context / "runtime_probe.pvs").write_text(
        "runtime_probe: THEORY\nBEGIN\n"
        "  support: LEMMA FORALL (x: int): x + 0 = x\n"
        "  target: THEOREM FORALL (x: int): x + 0 = x\n"
        "END runtime_probe\n"
    )
    env = os.environ.copy()
    env.update(
        PVS_LIBRARY_PATH="",
        PVS_LOG_DIR=str(tmp_path / "logs"),
        PVS_AGENT_TEST_CONTEXT=str(context),
        PVS_AGENT_TEST_ROOT=str(AGENT),
    )
    command = [str(PVS), "-raw", "-q", "-patchlevel", "none"]
    for source in (
        "support.lisp",
        "patches/proof-records.lisp",
        "patches/proof-runtime.lisp",
        "tests/proof-runtime-probe.lisp",
    ):
        command.extend(["-L", str(AGENT / source)])
    completed = subprocess.run(
        command, cwd=AGENT.parent, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45,
    )
    output = completed.stdout.decode("utf-8", errors="replace")
    assert completed.returncode == 0, output
    # The raw PVS entry point may exit zero after a caught Lisp assertion.
    # Require every explicit completion marker instead of trusting the status.
    for invariant in (
        "SERIAL-LEGACY-PASS",
        "RECORD-DEFAULT-SAVE-NESTING-PASS",
        "CACHE-NESTING-UNWIND-WORKSPACE-PASS",
        "CONCURRENT-CACHE-SENTINELS-PASS",
        "RELOAD-PASS",
    ):
        assert f"AGENT-TEST {invariant}" in output, output
    assert "Error executing" not in output, output
