#!/usr/bin/env python3
"""Exercise the corpus process runner without requiring or starting PVS/SAL."""

import csv
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

BRIDGE = Path(__file__).resolve().parent.parent
temporary_root = BRIDGE / ".work/corpus/driver-tests"
temporary_root.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(dir=temporary_root) as temporary:
    work = Path(temporary)
    sources = work / "sources"
    sources.mkdir()
    native = work / "native"
    native.mkdir()
    entries, cases = [], []
    for index in range(1, 9):
        name = f"fixture{index}.sal"
        source = sources / name
        source.write_text(f"fixture{index}: CONTEXT = BEGIN END\n")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        entries.append({"source": name, "native_status": "accepted",
                        "modules": [{"name": "system"}], "sha256": digest})
        cases.append({"source": name, "module": "system", "input": str(source),
                      "id": f"fake{index:02}", "source_sha256": digest})
    manifest = native / "manifest.json"
    manifest.write_text(json.dumps({"root": str(sources), "source_count": 8, "sources": entries}))
    (work / "cases.json").write_text(json.dumps({
        "source_root": str(sources), "selection": None, "case_count": 8, "source_count": 8,
        "native_rejections": [], "cases": cases, "inventory_manifest": str(manifest),
        "inventory_sha256": hashlib.sha256(manifest.read_bytes()).hexdigest()}))
    fake = work / "fake-pvs.py"
    fake.write_text('''#!/usr/bin/env python3
import csv, os, re, sys
from pathlib import Path
text = Path(os.environ["SAL_CORPUS_CASES_FILE"]).read_text()
with open(os.environ["SAL_CORPUS_RESULTS_FILE"], "w") as stream:
    writer = csv.writer(stream, delimiter="\\t", lineterminator="\\n")
    writer.writerow(["case_id", "source", "module", "status", "main_tccs", "import_tccs", "generated_file", "error"])
    stream.flush()
    for line in text.splitlines():
        fields = re.findall(r'"([^"\\n]*)"', line)
        if len(fields) != 4:
            continue
        identity, source, module, path = fields
        print("SAL-CORPUS-BEGIN", identity, source, module, flush=True)
        if identity == "fake02":
            sys.exit(9)
        writer.writerow([identity, source, module, "typechecked", "0", "0", "", ""])
        stream.flush()
    print("SAL-CORPUS-COMPLETE", flush=True)
''')
    fake.chmod(0o755)
    environment = dict(os.environ, PVS_BIN=str(fake))
    command = ["python3", str(BRIDGE / "tools/run-corpus-driver.py"), str(work)]
    first = subprocess.run(command + ["--batch-size", "4"], env=environment, capture_output=True, text=True)
    assert first.returncode == 1, first.stdout + first.stderr
    with (work / "results.tsv").open() as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    assert len(rows) == 8, rows
    assert sum(row["status"] == "typechecked" for row in rows) == 7, rows
    assert next(row for row in rows if row["case_id"] == "fake02")["status"] == "process-error"
    summary = json.loads((work / "summary.json").read_text())
    assert not summary["missing"] and not summary["coverage_errors"], summary
    assert "pending=6" in first.stdout, first.stdout
    resumed = subprocess.run(command, env=environment, capture_output=True, text=True)
    assert resumed.returncode == 1 and "pending=0" in resumed.stdout, resumed.stdout
    retry = subprocess.run(command + ["--retry-errors", "--batch-size", "1"],
                           env=environment, capture_output=True, text=True)
    assert retry.returncode == 1 and "completed=7 pending=1" in retry.stdout, retry.stdout
    with (work / "results.tsv").open() as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    assert len(rows) == 8, rows
    # A duplicate result cannot mask missing or failed coverage.
    with (work / "results.tsv").open("a") as stream:
        csv.DictWriter(stream, list(rows[0]), delimiter="\t").writerow(rows[0])
    duplicate = subprocess.run(["python3", str(BRIDGE / "tools/run-corpus-report.py"), str(work)],
                               capture_output=True, text=True)
    assert duplicate.returncode == 1
    assert json.loads((work / "summary.json").read_text())["duplicate_results"] == ["fake01"]
    before_resume = (work / "results.tsv").read_bytes()
    duplicate_resume = subprocess.run(command, env=environment, capture_output=True, text=True)
    assert duplicate_resume.returncode != 0 and "Duplicate prior result" in duplicate_resume.stderr
    assert (work / "results.tsv").read_bytes() == before_resume
    # An omitted accepted source must be reported, even if case_count is edited.
    case_file = work / "cases.json"
    truncated = json.loads(case_file.read_text())
    truncated["cases"] = truncated["cases"][:-1]
    truncated["case_count"] -= 1
    case_file.write_text(json.dumps(truncated))
    omitted = subprocess.run(["python3", str(BRIDGE / "tools/run-corpus-report.py"), str(work)],
                             capture_output=True, text=True)
    assert omitted.returncode == 1
    assert json.loads((work / "summary.json").read_text())["coverage_errors"]

    # Rejections and documented templates must not disappear merely by
    # deleting entries from cases.json while retaining the native inventory.
    rejected_source = sources / "rejected.xml"
    rejected_source.write_text("")
    rejected = {"source": "rejected.xml", "native_status": "error", "modules": [],
                "sha256": hashlib.sha256(b"").hexdigest()}
    native_document = json.loads(manifest.read_text())
    native_document["sources"].append(rejected)
    native_document["source_count"] += 1
    manifest.write_text(json.dumps(native_document))
    truncated["inventory_sha256"] = hashlib.sha256(manifest.read_bytes()).hexdigest()
    case_file.write_text(json.dumps(truncated))
    subprocess.run(["python3", str(BRIDGE / "tools/run-corpus-report.py"), str(work)],
                   capture_output=True, text=True, check=False)
    errors = json.loads((work / "summary.json").read_text())["coverage_errors"]
    assert "Native rejection list differs from the complete inventory" in errors, errors
    template_source = sources / "tta-startup/faulty-hub/startup-faulty-guardian.sal"
    template_source.parent.mkdir(parents=True)
    template_source.write_text("template with @par_filename marker\n")
    subprocess.run(["python3", str(BRIDGE / "tools/run-corpus-report.py"), str(work)],
                   capture_output=True, text=True, check=False)
    errors = json.loads((work / "summary.json").read_text())["coverage_errors"]
    assert any(isinstance(error, dict) and error.get("missing_documented_template_targets")
               for error in errors), errors

    # A Python fake cannot reproduce Common Lisp's abort cleanup of an open
    # :SUPERSEDE stream. Exercise the actual SAL-RUN-CORPUS result-writing path
    # in a plain SBCL process with frontend stubs, without loading PVS.
    sbcl = shutil.which("sbcl")
    if sbcl:
        lisp_work = work / "lisp-abort"
        lisp_work.mkdir()
        (lisp_work / "cases.lisp").write_text(
            '(in-package :pvs)\n(defparameter *sal-corpus-cases* \'('
            '("first" "fixture.sal" "system" "fixture.sal") '
            '("later" "fixture.sal" "later" "fixture.sal")))\n')
        script = lisp_work / "abort.lisp"
        script.write_text('''(require :asdf)
(defpackage :pvs (:use :cl))
(with-open-file (input (merge-pathnames "tests/corpus.lisp"
                        (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))
  (loop repeat 4 do (eval (read input))))
(in-package :pvs)
(defun sal-bridge-output-path (path) path)
(defun sal-open (source module &rest options)
  (declare (ignore source options))
  (when (string= module "later")
    (format t "~&SAL-CORPUS-ABORT-READY~%")
    (finish-output)
    (sleep 120))
  :view)
(defun sal-transition-view-theory-name (view) (declare (ignore view)) "fake")
(defun sal-transition-view-pvs-file (view) (declare (ignore view)) "fake.pvs")
(defun get-typechecked-theory (name) (declare (ignore name)) :theory)
(defun all-importings (theory) (declare (ignore theory)) nil)
(defun collect-tccs (theory) (declare (ignore theory)) nil)
(defun from-prelude? (theory) (declare (ignore theory)) nil)
(sal-run-corpus)
''')
        lisp_environment = dict(os.environ, SAL_BRIDGE_DIR=str(BRIDGE),
                                SAL_CORPUS_ROOT=str(lisp_work), SAL_CORPUS_OUTPUT=str(lisp_work),
                                TMPDIR=str(lisp_work))
        lisp_environment.pop("SAL_CORPUS_CASES_FILE", None)
        lisp_environment.pop("SAL_CORPUS_RESULTS_FILE", None)
        process = subprocess.Popen([sbcl, "--noinform", "--script", str(script)], cwd=lisp_work,
                                   env=lisp_environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        try:
            output, _ = process.communicate(timeout=2)
            raise AssertionError("Lisp stub unexpectedly exited before abort: " + output)
        except subprocess.TimeoutExpired:
            process.terminate()
            output, _ = process.communicate(timeout=5)
        assert "SAL-CORPUS-ABORT-READY" in output, output
        with (lisp_work / "results.tsv").open() as stream:
            retained = list(csv.DictReader(stream, delimiter="\t"))
        assert len(retained) == 1 and retained[0]["case_id"] == "first", retained
        print("SAL-CORPUS-LISP-ABORT-PERSISTENCE-PASSED (plain SBCL; no PVS loaded)")
    else:
        print("SAL-CORPUS-LISP-ABORT-PERSISTENCE-SKIPPED (SBCL unavailable)")

print("SAL-CORPUS-DRIVER-TESTS-PASSED")
