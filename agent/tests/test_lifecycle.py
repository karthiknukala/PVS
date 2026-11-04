"""Native session lifecycle regressions with forced queue/admission races."""
import os
from pathlib import Path
import subprocess

AGENT = Path(__file__).resolve().parents[1]


def test_native_session_lifecycle(tmp_path):
    context = tmp_path / "context"
    context.mkdir()
    (context / "lifecycle_probe.pvs").write_text(
        "lifecycle_probe: THEORY\nBEGIN\n"
        "  target: LEMMA FORALL (n: int): n + 1 > n\n"
        "END lifecycle_probe\n"
    )
    env = os.environ.copy()
    env.update(
        PVS_LIBRARY_PATH="",
        PVS_LOG_DIR=str(tmp_path / "logs"),
        PVS_AGENT_TEST_CONTEXT=str(context),
    )
    command = [str(AGENT.parent / "pvs"), "-raw", "-q", "-patchlevel", "none"]
    for source in ("load.lisp", "tests/session-lifecycle-probe.lisp"):
        command.extend(["-L", str(AGENT / source)])
    completed = subprocess.run(
        command, cwd=AGENT.parent, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=35,
    )
    output = completed.stdout.decode("utf-8", errors="replace")
    assert completed.returncode == 0, output
    # Raw PVS can return zero after a trapped assertion, so require every marker.
    for invariant in (
        "TYPED-STARTUP-OWNING-THREAD-PASS",
        "QUEUED-REPLY-CORRELATION-PASS",
        "ABANDONED-CALLER-ADMISSION-RECOVERY-PASS",
        "RECOVERY-QED-TERMINAL-STATUS-PASS",
        "STARTUP-FAILURE-WAKE-TIMER-CLEANUP-PASS",
        "UNDRAINED-TERMINAL-PASS",
        "PROOF-ONLY-SHUTDOWN-DEAD-ID-PASS",
    ):
        assert f"AGENT-TEST {invariant}" in output, output
    assert "Error executing" not in output, output
