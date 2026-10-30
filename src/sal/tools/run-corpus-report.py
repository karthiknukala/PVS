#!/usr/bin/env python3
"""Summarize coverage and fail if any inventoried frontend case is absent/failing."""

import argparse
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path)
args = parser.parse_args()
directory = args.directory.resolve()
bridge = Path(__file__).resolve().parent.parent
if bridge not in directory.parents:
    parser.error(f"Report writes must stay under {bridge}")
cases = json.loads((directory / "cases.json").read_text())
report_path = directory / "results.tsv"
results = list(csv.DictReader(report_path.open(), delimiter="\t")) if report_path.exists() else []
by_id = {row["case_id"]: row for row in results}
result_counts = Counter(row["case_id"] for row in results)
duplicate_results = sorted(key for key, count in result_counts.items() if count > 1)
case_ids = {case["id"] for case in cases["cases"]}
unexpected_results = sorted(set(by_id) - case_ids)
missing = [case for case in cases["cases"] if case["id"] not in by_id]
failed = [row for row in results if row["status"] != "typechecked"]
passed = [row for row in results if row["status"] == "typechecked"]
source_outcomes = {}
for case in cases["cases"]:
    family = (case["source"], "template" in case)
    source_outcomes.setdefault(family, []).append(by_id.get(case["id"], {}).get("status", "missing"))
baseline = json.loads((bridge / "tests/corpus-native-baseline.json").read_text())
known = {(entry["source"], entry["sha256"]): entry for entry in baseline["native_rejections"]}
unexpected_native = []
for entry in cases["native_rejections"]:
    expected_rejection = known.get((entry["source"], entry["sha256"]))
    if (expected_rejection is None
            or entry["native_status"] != expected_rejection["native_status"]
            or expected_rejection["error_contains"] not in entry.get("error", "")):
        unexpected_native.append(entry)
inventory_path = Path(cases.get("inventory_manifest", directory / "native/manifest.json"))
inventory = json.loads(inventory_path.read_text())
selection = cases.get("selection")
expected = {
    (source["source"], module["name"])
    for source in inventory["sources"]
    if source["native_status"] == "accepted" and (not selection or selection in source["source"])
    for module in source["modules"] or [{"name": "--context"}]
}
actual = {(case["source"], case["module"]) for case in cases["cases"] if "template" not in case}
coverage_errors = []
if expected != actual:
    coverage_errors.append({"missing_inventory_targets": sorted(expected - actual),
                            "unexpected_targets": sorted(actual - expected)})
if len(cases["cases"]) != cases["case_count"] or len(case_ids) != len(cases["cases"]):
    coverage_errors.append("Case manifest count mismatch or duplicate case IDs")
if cases["source_count"] != len(source_outcomes):
    coverage_errors.append("Source/template family count differs from the case manifest")
inventory_rejections = {(source["source"], source["sha256"], source["native_status"])
                        for source in inventory["sources"] if source["native_status"] != "accepted"}
case_rejections = {(source["source"], source["sha256"], source["native_status"])
                   for source in cases["native_rejections"]}
if inventory_rejections != case_rejections:
    coverage_errors.append("Native rejection list differs from the complete inventory")
for case in cases["cases"]:
    row = by_id.get(case["id"])
    if row and (row["source"], row["module"]) != (case["source"], case["module"]):
        coverage_errors.append({"result_target_mismatch": case["id"]})
if cases.get("inventory_sha256") and cases["inventory_sha256"] != hashlib.sha256(inventory_path.read_bytes()).hexdigest():
    coverage_errors.append("Native inventory changed after case generation")
source_root = Path(inventory["root"])
fresh_sources = {p.relative_to(source_root).as_posix() for p in source_root.rglob("*")
                 if p.is_file() and p.suffix.lower() in {".sal", ".lsal", ".xml"}}
inventoried_sources = {source["source"] for source in inventory["sources"]}
if fresh_sources != inventoried_sources or inventory["source_count"] != len(inventoried_sources):
    coverage_errors.append("Native inventory does not enumerate the current complete SAL source tree")
changed_sources = [source["source"] for source in inventory["sources"]
                   if not (source_root / source["source"]).is_file()
                   or hashlib.sha256((source_root / source["source"]).read_bytes()).hexdigest() != source["sha256"]]
if changed_sources:
    coverage_errors.append({"sources_changed_since_inventory": changed_sources})
template_recipes = json.loads((bridge / "tests/corpus-templates.json").read_text())["templates"]
expected_templates = {(recipe["source"], recipe["module"]) for recipe in template_recipes
                      if (source_root / recipe["source"]).is_file()
                      and (not selection or selection in recipe["source"])}
actual_templates = {(case["source"], case["module"]) for case in cases["cases"] if "template" in case}
if expected_templates != actual_templates:
    coverage_errors.append({"missing_documented_template_targets": sorted(expected_templates - actual_templates),
                            "unexpected_template_targets": sorted(actual_templates - expected_templates)})
for case in cases["cases"]:
    if "template" in case:
        metadata = case["template"]
        for label, path, digest in (
                ("source", source_root / case["source"], metadata["original_sha256"]),
                ("recipe", source_root / metadata["recipe"], metadata["recipe_sha256"]),
                ("generated instance", Path(case["input"]), metadata["generated_sha256"])):
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                coverage_errors.append({"changed_template_input": case["source"], "kind": label})
template_native_rejections = [case for case in cases["cases"] if "template" in case
                              and case["template"]["native_status"] != "accepted"]
summary = {
    "case_count": cases["case_count"], "typechecked_cases": len(passed),
    "failed_cases": len(failed), "missing_cases": len(missing),
    "sources_or_template_instances": cases["source_count"],
    "documented_template_instances": sum("template" in case for case in cases["cases"]),
    "fully_typechecked_sources": sum(not template and all(status == "typechecked" for status in outcomes)
                                     for (_, template), outcomes in source_outcomes.items()),
    "fully_typechecked_template_instances": sum(template and all(status == "typechecked" for status in outcomes)
                                                for (_, template), outcomes in source_outcomes.items()),
    "native_rejections": cases["native_rejections"],
    "unexpected_native_rejections": unexpected_native,
    "duplicate_results": duplicate_results, "unexpected_results": unexpected_results,
    "coverage_errors": coverage_errors, "template_native_rejections": template_native_rejections,
    "failures": failed, "missing": missing,
}
(directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps({key: value for key, value in summary.items()
                  if key not in {"native_rejections", "unexpected_native_rejections", "failures", "missing"}}, indent=2))
print(f"Native rejections retained: {len(cases['native_rejections'])}")
print(f"Unexpected native rejections: {len(unexpected_native)}")
print(f"Full report: {directory / 'summary.json'}")
raise SystemExit(1 if (failed or missing or unexpected_native or duplicate_results
                      or unexpected_results or coverage_errors or template_native_rejections
                      or len(by_id) != cases["case_count"]) else 0)
