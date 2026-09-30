#!/usr/bin/env python3
"""Stage raw DCE inputs into the processing workspace.

This stage is intentionally focused on ingestion and safe organization of raw DCE
DICOM data. Quantitative map generation will happen later once the DCE data is
available and processed externally.
"""

from __future__ import annotations

import argparse
import os
import shutil
import zipfile
from pathlib import Path


def default_data_root() -> Path:
    env_root = os.environ.get("ASL_DCE_DATA_ROOT")
    if env_root:
        return Path(env_root)
    return Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/data/EM")


def default_dce_output() -> Path:
    env_root = os.environ.get("ASL_DCE_ANALYSIS_ROOT")
    if env_root:
        return Path(env_root) / "dce"
    return Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/analysis/asl_vs_dce_multiple_sclerosis/dce")


def copy_or_extract_dce(raw_subject_dir: Path, output_dir: Path):
    dce_candidates = []
    for item in sorted(raw_subject_dir.iterdir()):
        name_lower = item.name.lower()
        if item.is_dir() and ("dce" in name_lower or "permeabilidade" in name_lower):
            dce_candidates.append(item)
        elif item.is_file() and item.suffix.lower() == ".zip":
            dce_candidates.append(item)

    if not dce_candidates:
        print(f"[WARN] {raw_subject_dir.name}: no DCE input found")
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    for item in dce_candidates:
        dest = output_dir / item.name
        if item.is_file() and item.suffix.lower() == ".zip":
            if dest.exists():
                print(f"Skipping existing zip: {dest}")
                continue
            shutil.copy2(item, dest)
            print(f"Staged zip: {item} -> {dest}")
            try:
                with zipfile.ZipFile(dest, "r") as zf:
                    extract_dir = output_dir / item.stem
                    zf.extractall(extract_dir)
                    print(f"Extracted zip to: {extract_dir}")
            except zipfile.BadZipFile:
                print(f"[WARN] {item} is not a valid zip archive")
        elif item.is_dir():
            target_dir = output_dir / item.name
            if target_dir.exists():
                print(f"Skipping existing DCE folder: {target_dir}")
                continue
            shutil.copytree(item, target_dir)
            print(f"Staged directory: {item} -> {target_dir}")


def main():
    parser = argparse.ArgumentParser(description="Stage raw DCE data for later quantitative processing.")
    parser.add_argument("--raw-root", type=Path, default=default_data_root())
    parser.add_argument("--dce-output", type=Path, default=default_dce_output())
    args = parser.parse_args()

    if not args.raw_root.exists():
        raise FileNotFoundError(f"Raw root not found: {args.raw_root}")

    args.dce_output.mkdir(parents=True, exist_ok=True)

    for subject_dir in sorted(args.raw_root.iterdir()):
        if not subject_dir.is_dir():
            continue
        subject_output = args.dce_output / subject_dir.name
        copy_or_extract_dce(subject_dir, subject_output)

    print("DCE staging complete.")


if __name__ == "__main__":
    main()
