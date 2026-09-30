#!/usr/bin/env python3
"""Build a manifest for the T1/Tex/DCE study scope.

This script inventories raw subject folders and reports which modalities are
present for each subject. It intentionally ignores pCASL and is meant to be the
first step in a workflow focused on T1, Tex, and DCE.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
from typing import Any


def default_data_root() -> Path:
    env_root = os.environ.get("ASL_DCE_DATA_ROOT")
    if env_root:
        return Path(env_root)
    return Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/data/EM")


def find_subject_dirs(raw_root: Path):
    if not raw_root.exists():
        raise FileNotFoundError(f"Raw data root not found: {raw_root}")

    return sorted([p for p in raw_root.iterdir() if p.is_dir()])


def detect_modalities(subject_dir: Path) -> dict[str, Any]:
    info: dict[str, Any] = {
        "subject": subject_dir.name,
        "t1": [],
        "tex": [],
        "dce": [],
        "dcm": [],
        "notes": [],
    }

    for candidate in sorted(subject_dir.iterdir()):
        name_lower = candidate.name.lower()

        if candidate.is_file():
            if "t1" in name_lower and candidate.suffix.lower() in {".nii", ".gz", ".mgz", ".img"}:
                info["t1"].append(candidate.name)
            elif "tex" in name_lower and candidate.suffix.lower() in {".nii", ".gz", ".mgz", ".img"}:
                info["tex"].append(candidate.name)
            elif candidate.suffix.lower() == ".dcm":
                info["dcm"].append(candidate.name)
            continue

        if candidate.is_dir():
            if "dce" in name_lower:
                info["dce"].append(candidate.name)
            elif "dicom" in name_lower or "dcm" in name_lower:
                info["dcm"].append(candidate.name)

    if not info["t1"]:
        info["notes"].append("Missing T1 file")
    if not info["tex"]:
        info["notes"].append("Missing Tex file")
    if not info["dce"] and not info["dcm"]:
        info["notes"].append("Missing DCE input")

    return info


def write_csv(rows: list[dict[str, Any]], output_path: Path):
    fieldnames = ["subject", "t1", "tex", "dce", "dcm", "notes"]
    with output_path.open("w", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "subject": row.get("subject", ""),
                "t1": "; ".join(row.get("t1", [])),
                "tex": "; ".join(row.get("tex", [])),
                "dce": "; ".join(row.get("dce", [])),
                "dcm": "; ".join(row.get("dcm", [])),
                "notes": "; ".join(row.get("notes", [])),
            })


def main():
    parser = argparse.ArgumentParser(description="Build a study manifest for T1/Tex/DCE data.")
    parser.add_argument("--raw-root", type=Path, default=default_data_root())
    parser.add_argument(
        "--output-json",
        type=Path,
        default=Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/analysis/asl_vs_dce_multiple_sclerosis/subject_manifest.json"),
    )
    parser.add_argument(
        "--output-csv",
        type=Path,
        default=Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/analysis/asl_vs_dce_multiple_sclerosis/subject_manifest.csv"),
    )
    args = parser.parse_args()

    subjects = [detect_modalities(subject_dir) for subject_dir in find_subject_dirs(args.raw_root)]

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_csv.parent.mkdir(parents=True, exist_ok=True)

    args.output_json.write_text(json.dumps(subjects, indent=2))
    write_csv(subjects, args.output_csv)

    print(f"Manifest written to: {args.output_json}")
    print(f"CSV written to: {args.output_csv}")
    print(f"Subjects found: {len(subjects)}")


if __name__ == "__main__":
    main()
