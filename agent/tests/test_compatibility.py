"""The loader must refuse a stale replacement before patching the engine."""
import os
from pathlib import Path
import shutil
import subprocess

AGENT = Path(__file__).resolve().parents[1]


def test_loader_rejects_stale_source_and_requires_restart(tmp_path):
    copied = tmp_path / "extension"
    shutil.copytree(AGENT, copied, ignore=shutil.ignore_patterns(
        ".venv", ".cache", "__pycache__", "*.egg-info", "skills"))
    manifest = copied / "compatibility.lisp"
    manifest.write_text('(in-package :pvs)\n'
                        '(defparameter *agent-source-manifest* '
                        '\'(("src/pvs.lisp" . "DELIBERATE-MISMATCH")))\n')
    probe = tmp_path / "probe.lisp"
    probe.write_text(f'''(in-package :pvs)
(let ((caught nil))
  (handler-case (load "{copied / 'load.lisp'}")
    (error (condition)
      (assert (search "do not match" (princ-to-string condition)))
      (setf caught t)))
  (assert caught)
  (assert (eq *agent-loaded* :failed))
  (assert (zerop (hash-table-count *agent-original-functions*))))
(let ((caught nil))
  (handler-case (load "{copied / 'load.lisp'}")
    (error (condition)
      (assert (search "restart" (princ-to-string condition)))
      (setf caught t)))
  (assert caught))
(format t "~&AGENT-COMPATIBILITY-PASS~%")
(uiop:quit 0)
''')
    env = dict(os.environ, PVS_LIBRARY_PATH="", PVS_LOG_DIR=str(tmp_path / "logs"))
    completed = subprocess.run(
        [str(AGENT.parent / "pvs"), "-raw", "-q", "-patchlevel", "none",
         "-L", str(probe)], cwd=AGENT.parent, env=env,
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=20,
    )
    output = completed.stdout.decode(errors="replace")
    assert completed.returncode == 0, output
    assert "AGENT-COMPATIBILITY-PASS" in output, output
    assert "Error executing" not in output, output
