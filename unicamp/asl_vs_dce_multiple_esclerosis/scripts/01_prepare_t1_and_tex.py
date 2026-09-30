#!/usr/bin/env python3
"""Stage T1 and Tex inputs into the processed workspace.

This script standardizes the names of valid T1 and Tex files, copies them into
standardized processed folders, and leaves pCASL out of scope intentionally.
"""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path


def default_data_root() -> Path:
    env_root = os.environ.get("ASL_DCE_DATA_ROOT")
    if env_root:
        return Path(env_root)
    return Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/data/EM")


def default_processed_root() -> Path:
    env_root = os.environ.get("ASL_DCE_ANALYSIS_ROOT")
    if env_root:
        return Path(env_root)
    return Path("/home/antonio/Desktop/asl_vs_dce_multiple_sclerosis/analysis/asl_vs_dce_multiple_sclerosis")


def find_candidates(raw_root: Path, keyword: str):
    matches = []
    for subject_dir in sorted(raw_root.iterdir()):
        if not subject_dir.is_dir():
            continue
        for candidate in sorted(subject_dir.iterdir()):
            name_lower = candidate.name.lower()
            if candidate.is_file() and keyword in name_lower and candidate.suffix.lower() in {".nii", ".gz", ".img", ".mgz"}:
                matches.append(candidate)
    return matches


def stage_file(src: Path, target_dir: Path, new_name: str):
    target_dir.mkdir(parents=True, exist_ok=True)
    target_path = target_dir / new_name
    if target_path.exists():
        print(f"Skipping existing target: {target_path}")
        return target_path

    shutil.copy2(src, target_path)
    print(f"Copied: {src} -> {target_path}")
    return target_path


def main():
    parser = argparse.ArgumentParser(description="Stage T1 and Tex inputs into processed folders.")
    parser.add_argument("--raw-root", type=Path, default=default_data_root())
    parser.add_argument("--processed-root", type=Path, default=default_processed_root())
    args = parser.parse_args()

    if not args.raw_root.exists():
        raise FileNotFoundError(f"Raw root not found: {args.raw_root}")

    t1_dir = args.processed_root / "t1"
    tex_dir = args.processed_root / "tex"
    t1_dir.mkdir(parents=True, exist_ok=True)
    tex_dir.mkdir(parents=True, exist_ok=True)

    for subject_dir in sorted(args.raw_root.iterdir()):
        if not subject_dir.is_dir():
            continue

        t1_candidates = [p for p in subject_dir.iterdir() if p.is_file() and "t1" in p.name.lower()]
        tex_candidates = [p for p in subject_dir.iterdir() if p.is_file() and "tex" in p.name.lower()]

        if not t1_candidates:
            print(f"[WARN] {subject_dir.name}: no T1 file found")
        else:
            t1_src = t1_candidates[0]
            stage_file(t1_src, t1_dir, f"{subject_dir.name}_t1.nii.gz")

        if not tex_candidates:
            print(f"[WARN] {subject_dir.name}: no Tex file found")
        else:
            tex_src = tex_candidates[0]
            stage_file(tex_src, tex_dir, f"{subject_dir.name}_tex.nii.gz")

    print("T1/Tex staging complete.")


if __name__ == "__main__":
    main()
