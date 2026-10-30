#!/usr/bin/env python3
"""Run small serial PVS batches, preserving results across crashes and resumes."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import signal
import subprocess

BRIDGE = Path(__file__).resolve().parent.parent
COLUMNS = ["case_id", "source", "module", "status", "main_tccs", "import_tccs", "generated_file", "error"]


def read_rows(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open() as stream:
        # A process may die mid-row. The flushed complete rows remain usable;
        # an incomplete final row is attributed to the interrupted target.
        return [row for row in csv.DictReader(stream, delimiter="\t")
                if all(row.get(column) is not None for column in COLUMNS)]


def lisp_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_results(path: Path, cases: list[dict], results: dict) -> None:
    temporary = path.with_suffix(".next.tsv")
    with temporary.open("w") as stream:
        writer = csv.DictWriter(stream, COLUMNS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(results[case["id"]] for case in cases if case["id"] in results)
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--batch-size", type=int, default=12)
    parser.add_argument("--timeout", type=int, default=600,
                        help="Wall-clock seconds allowed per PVS batch")
    parser.add_argument("--retry-errors", action="store_true",
                        help="Resume passed cases, but rerun earlier error/process-error rows")
    args = parser.parse_args()
    directory = args.directory.resolve(strict=True)
    if BRIDGE not in directory.parents:
        parser.error(f"All output must stay under {BRIDGE}")
    if args.batch_size < 1 or args.timeout < 1:
        parser.error("Batch size and timeout must be positive")
    manifest = json.loads((directory / "cases.json").read_text())
    cases = manifest["cases"]
    cases_by_id = {case["id"]: case for case in cases}
    if len(cases_by_id) != len(cases) or manifest["case_count"] != len(cases):
        raise ValueError("Case manifest has duplicate IDs or an inconsistent case count")
    report = directory / "results.tsv"
    prior_rows = read_rows(report)
    results = {}
    for row in prior_rows:
        identity = row["case_id"]
        if identity in results:
            raise ValueError(f"Duplicate prior result for {identity}; inspect {report} before resuming")
        case = cases_by_id.get(identity)
        if case is None or (row["source"], row["module"]) != (case["source"], case["module"]):
            raise ValueError(f"Prior result does not match the case manifest: {identity}")
        results[identity] = row
    if args.retry_errors:
        results = {key: row for key, row in results.items() if row["status"] == "typechecked"}
    queue = [case for case in cases if case["id"] not in results]
    pvs = os.environ.get("PVS_BIN", str(BRIDGE.parent.parent / "pvs"))
    environment = dict(os.environ, SAL_BRIDGE_DIR=str(BRIDGE), SAL_CORPUS_OUTPUT=str(directory) + "/",
                       SAL_CORPUS_ROOT=manifest["source_root"])
    session = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    session_dir = directory / "batches" / session
    session_dir.mkdir(parents=True)
    # Preserve the report being resumed before canonical consolidation.
    if report.exists():
        (session_dir / "prior-results.tsv").write_bytes(report.read_bytes())
    attempt = 0
    print(f"SAL-CORPUS-RESUME completed={len(results)} pending={len(queue)} output={directory}", flush=True)
    while queue:
        batch, queue = queue[:args.batch_size], queue[args.batch_size:]
        attempt += 1
        work = session_dir / f"{attempt:04d}"
        work.mkdir()
        input_file = work / "cases.lisp"
        input_file.write_text("(in-package :pvs)\n(defparameter *sal-corpus-cases* '(\n" +
                              "".join(" (" + " ".join(lisp_string(case[key]) for key in
                                           ("id", "source", "module", "input")) + ")\n" for case in batch) + "))\n")
        result_file = work / "results.tsv"
        log_file = work / "pvs.log"
        batch_environment = dict(environment, SAL_CORPUS_CASES_FILE=str(input_file),
                                 SAL_CORPUS_RESULTS_FILE=str(result_file))
        command = [pvs, "-raw", "-q", "-E",
                   '(load (merge-pathnames "tests/corpus.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))']
        timed_out = False
        with log_file.open("w") as log:
            process = subprocess.Popen(command, cwd=directory, env=batch_environment,
                                       stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                code, timed_out = None, True
                # PVS launchers may have child Lisp processes. Stop the entire
                # process group before starting another serial batch.
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
        rows = read_rows(result_file)
        batch_ids = {case["id"] for case in batch}
        batch_reported = set()
        for row in rows:
            if row["case_id"] not in batch_ids:
                raise ValueError(f"Unexpected case in batch report {result_file}: {row['case_id']}")
            if row["case_id"] in batch_reported:
                raise ValueError(f"Duplicate case in batch report {result_file}: {row['case_id']}")
            batch_reported.add(row["case_id"])
            case = cases_by_id[row["case_id"]]
            if (row["source"], row["module"]) != (case["source"], case["module"]):
                raise ValueError(f"Batch result target differs from case manifest: {row['case_id']}")
            results[row["case_id"]] = row
        log_text = log_file.read_text(errors="replace")
        began = re.findall(r"^SAL-CORPUS-BEGIN ([^ ]+)", log_text, re.MULTILINE)
        unresolved = [case for case in batch if case["id"] not in results]
        interrupted = [case for case in unresolved if began and case["id"] == began[-1]]
        if unresolved and not began:
            # A bootstrap error reached no target. Record the limitation instead
            # of pretending the omitted targets were checked or dropping them.
            interrupted = unresolved
        for case in interrupted:
            reason = f"PVS {'timeout' if timed_out else 'process exit ' + str(code)}; see {log_file}"
            if not began:
                reason += "; no target began (bootstrap failure)"
            results[case["id"]] = dict(zip(COLUMNS, [case["id"], case["source"], case["module"],
                                                    "process-error", "", "", "", reason]))
        # Cases following the crashed target were not executed. Retry them in a
        # fresh process before taking the next batch from the remaining queue.
        queue = [case for case in unresolved if case["id"] not in results] + queue
        write_results(report, cases, results)
        (work / "process.json").write_text(json.dumps({"exit_status": code, "timed_out": timed_out,
                                                       "attempted": [case["id"] for case in batch],
                                                       "began": began, "reported": len(rows),
                                                       "process_errors": [case["id"] for case in interrupted]}, indent=2) + "\n")
        print(f"SAL-CORPUS-BATCH {attempt} reported={len(rows)} process_errors={len(interrupted)} "
              f"completed={len(results)}/{len(cases)} pending={len(queue)} log={log_file}", flush=True)
    write_results(report, cases, results)
    return subprocess.run(["python3", str(BRIDGE / "tools/run-corpus-report.py"), str(directory)],
                          cwd=directory, env=environment).returncode


if __name__ == "__main__":
    raise SystemExit(main())
