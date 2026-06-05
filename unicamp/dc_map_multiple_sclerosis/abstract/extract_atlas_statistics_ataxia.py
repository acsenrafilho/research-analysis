#!/usr/bin/env python3
"""Extract per-ROI descriptive statistics from warped atlases for the Ataxia pipeline."""

import argparse
import csv
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

try:
    import nibabel as nib
    import numpy as np

    HAS_NIBABEL = True
except ImportError:
    HAS_NIBABEL = False

FSL_ATLAS_DIR = "/home/antonio/fsl/data/atlases"
ATLAS_XML = {
    "HarvardOxford-Cortical": os.path.join(FSL_ATLAS_DIR, "HarvardOxford-Cortical.xml"),
    "Cerebellum-MNIfnirt": os.path.join(FSL_ATLAS_DIR, "Cerebellum_MNIfnirt.xml"),
}
ATLAS_IMAGES = {
    "HarvardOxford-Cortical": "HO_atlas_in_t1.nii.gz",
    "Cerebellum-MNIfnirt": "Cerebellum_atlas_in_t1.nii.gz",
}
METRICS = {
    "FA": {
        "in_t1": "dti_FA_in_t1.nii.gz",
        "native": ["dti_FA.nii.gz", "dti_FA.nrrd"],
    },
    "MD": {
        "in_t1": "dti_MD_in_t1.nii.gz",
        "native": ["dti_MD.nii.gz", "dti_MD.nrrd"],
    },
    "DC": {
        "in_t1": "dti_DC_in_t1.nii.gz",
        "native": ["dti_DC.nii.gz"],
    },
}
B0_TO_T1_AFFINE = "b0_to_t1_0GenericAffine.mat"
B0_TO_T1_WARP = "b0_to_t1_1Warp.nii.gz"
MIN_VOXELS = 10
CSV_COLUMNS = [
    "subject",
    "group",
    "atlas",
    "roi_index",
    "roi_name",
    "metric",
    "mean",
    "std",
    "min",
    "max",
    "n_voxels",
]


def parse_atlas_xml(xml_path):
    """Parse FSL atlas XML; return dict mapping atlas label (1-based) to ROI name."""
    tree = ET.parse(xml_path)
    labels = {}
    for label_elem in tree.findall(".//label"):
        index = int(label_elem.get("index"))
        name = (label_elem.text or "").strip()
        labels[index + 1] = name
    return labels


def run_command(cmd, check=True):
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if check and result.returncode != 0:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(cmd)}\n{result.stderr.strip()}"
        )
    return result


def file_exists(path):
    return path and os.path.isfile(path)


def find_first_existing(work_dir, filenames):
    for filename in filenames:
        path = os.path.join(work_dir, filename)
        if os.path.isfile(path):
            return path
    return None


def convert_nrrd_to_nifti(input_nrrd, output_nii):
    if file_exists(output_nii):
        return output_nii

    if os.path.isfile(input_nrrd):
        result = run_command(["ConvertImage", "3", input_nrrd, output_nii], check=False)
        if result.returncode == 0:
            return output_nii

    return None


def ensure_b0_nifti(work_dir):
    b0_nii = os.path.join(work_dir, "dwi_baseline.nii.gz")
    if file_exists(b0_nii):
        return b0_nii

    b0_nrrd = os.path.join(work_dir, "dwi_baseline.nrrd")
    converted = convert_nrrd_to_nifti(b0_nrrd, b0_nii)
    if not converted:
        raise FileNotFoundError("missing dwi_baseline.nii.gz and dwi_baseline.nrrd")
    return converted


def ensure_b0_brain(work_dir):
    b0_brain = os.path.join(work_dir, "dwi_baseline_brain.nii.gz")
    if file_exists(b0_brain):
        return b0_brain

    b0_nii = ensure_b0_nifti(work_dir)
    b0_mask = os.path.join(work_dir, "dwi_baseline_brain_mask.nii.gz")

    if file_exists(b0_mask):
        print("  Creating dwi_baseline_brain.nii.gz from existing brain mask...")
        run_command(["fslmaths", b0_nii, "-mas", b0_mask, b0_brain])
        return b0_brain

    print("  Running BET on dwi_baseline...")
    run_command(
        ["bet", b0_nii, os.path.join(work_dir, "dwi_baseline_brain"), "-m", "-f", "0.3", "-g", "0"]
    )
    if not file_exists(b0_brain):
        raise FileNotFoundError("BET did not produce dwi_baseline_brain.nii.gz")
    return b0_brain


def ensure_b0_to_t1_transforms(work_dir):
    affine = os.path.join(work_dir, B0_TO_T1_AFFINE)
    warp = os.path.join(work_dir, B0_TO_T1_WARP)
    if file_exists(affine) and file_exists(warp):
        return affine, warp

    t1_brain = os.path.join(work_dir, "t1_brain.nii.gz")
    if not file_exists(t1_brain):
        raise FileNotFoundError(f"missing {t1_brain}")

    b0_brain = ensure_b0_brain(work_dir)

    print("  Registering B0 to T1 (missing b0_to_t1 transforms)...")
    run_command(
        [
            "antsRegistrationSyNQuick.sh",
            "-d",
            "3",
            "-f",
            t1_brain,
            "-m",
            b0_brain,
            "-o",
            os.path.join(work_dir, "b0_to_t1_"),
            "-n",
            "10",
        ]
    )
    return affine, warp


def warp_metric_to_t1(work_dir, native_metric, output_metric, transforms=None):
    if file_exists(output_metric):
        return output_metric

    t1_brain = os.path.join(work_dir, "t1_brain.nii.gz")
    if transforms is None:
        affine, warp = ensure_b0_to_t1_transforms(work_dir)
    else:
        affine, warp = transforms

    print(f"  Warping {os.path.basename(native_metric)} to T1 space...")
    run_command(
        [
            "antsApplyTransforms",
            "-d",
            "3",
            "-i",
            native_metric,
            "-r",
            t1_brain,
            "-o",
            output_metric,
            "-t",
            warp,
            "-t",
            affine,
            "-n",
            "Linear",
        ]
    )
    return output_metric


def resolve_native_metric(work_dir, metric_name):
    metric_info = METRICS[metric_name]
    native_path = find_first_existing(work_dir, metric_info["native"])
    if native_path:
        if native_path.endswith(".nrrd"):
            nii_path = native_path.replace(".nrrd", ".nii.gz")
            converted = convert_nrrd_to_nifti(native_path, nii_path)
            if converted:
                return converted
        return native_path
    return None


def resolve_metrics_in_t1(work_dir):
    """Return dict metric -> path in T1 space, creating warped files if needed."""
    resolved = {}
    pending = {}

    for metric_name, metric_info in METRICS.items():
        in_t1_path = os.path.join(work_dir, metric_info["in_t1"])
        if file_exists(in_t1_path):
            resolved[metric_name] = in_t1_path
            continue

        native_path = resolve_native_metric(work_dir, metric_name)
        if native_path:
            pending[metric_name] = (native_path, in_t1_path)

    if not pending:
        return resolved

    try:
        transforms = ensure_b0_to_t1_transforms(work_dir)
    except (RuntimeError, FileNotFoundError) as exc:
        print(f"  Warning: could not prepare B0-to-T1 transforms: {exc}")
        return resolved

    for metric_name, (native_path, in_t1_path) in pending.items():
        try:
            resolved[metric_name] = warp_metric_to_t1(
                work_dir, native_path, in_t1_path, transforms=transforms
            )
        except (RuntimeError, FileNotFoundError) as exc:
            print(f"  Warning: could not warp {metric_name} to T1 space: {exc}")

    missing = [name for name in METRICS if name not in resolved]
    if missing:
        print("  Warning: unavailable metrics in T1 space: " + ", ".join(missing))

    return resolved


def load_image_data(image_path):
    if not HAS_NIBABEL:
        raise RuntimeError(
            "nibabel is required for ROI statistics. "
            "Install dependencies with: pip install -r requirements.txt"
        )
    return np.asanyarray(nib.load(image_path).dataobj, dtype=np.float64)


def get_roi_stats_from_arrays(metric_data, atlas_data, roi_index):
    roi_mask = atlas_data == roi_index
    n_voxels = int(np.count_nonzero(roi_mask))
    if n_voxels < MIN_VOXELS:
        return None

    values = metric_data[roi_mask]
    values = values[np.isfinite(values)]
    if values.size < MIN_VOXELS:
        return None

    return {
        "mean": float(np.mean(values)),
        "std": float(np.std(values)),
        "min": float(np.min(values)),
        "max": float(np.max(values)),
        "n_voxels": n_voxels,
    }


def create_roi_mask(atlas_file, label_value, mask_file):
    run_command(
        [
            "fslmaths",
            atlas_file,
            "-thr",
            str(label_value),
            "-uthr",
            str(label_value),
            "-bin",
            mask_file,
        ]
    )


def get_roi_stats_fsl(metric_file, mask_file):
    n_voxels = int(run_command(["fslstats", mask_file, "-V"]).stdout.strip().split()[0])
    if n_voxels < MIN_VOXELS:
        return None

    mean_val = float(run_command(["fslstats", metric_file, "-k", mask_file, "-M"]).stdout.strip())
    std_val = float(run_command(["fslstats", metric_file, "-k", mask_file, "-S"]).stdout.strip())
    min_val, max_val = run_command(
        ["fslstats", metric_file, "-k", mask_file, "-r"]
    ).stdout.strip().split()

    return {
        "mean": mean_val,
        "std": std_val,
        "min": float(min_val),
        "max": float(max_val),
        "n_voxels": n_voxels,
    }


def collect_roi_rows(subject, group_name, atlas_name, roi_names, atlas_file, metric_name, metric_file):
    rows = []

    if HAS_NIBABEL:
        atlas_data = load_image_data(atlas_file)
        metric_data = load_image_data(metric_file)
        if metric_data.shape != atlas_data.shape:
            print(
                f"  Warning: shape mismatch for {metric_name} "
                f"({metric_data.shape}) vs {os.path.basename(atlas_file)} "
                f"({atlas_data.shape}), skipping"
            )
            return rows

        for roi_index, roi_name in sorted(roi_names.items()):
            stats = get_roi_stats_from_arrays(metric_data, atlas_data, roi_index)
            if stats is None:
                continue
            rows.append(
                {
                    "subject": subject,
                    "group": group_name,
                    "atlas": atlas_name,
                    "roi_index": roi_index,
                    "roi_name": roi_name,
                    "metric": metric_name,
                    **stats,
                }
            )
        return rows

    for roi_index, roi_name in sorted(roi_names.items()):
        with tempfile.NamedTemporaryFile(suffix="_roi_mask.nii.gz", delete=False) as tmp:
            mask_file = tmp.name
        try:
            create_roi_mask(atlas_file, roi_index, mask_file)
            stats = get_roi_stats_fsl(metric_file, mask_file)
            if stats is None:
                continue
            rows.append(
                {
                    "subject": subject,
                    "group": group_name,
                    "atlas": atlas_name,
                    "roi_index": roi_index,
                    "roi_name": roi_name,
                    "metric": metric_name,
                    **stats,
                }
            )
        finally:
            if os.path.exists(mask_file):
                os.remove(mask_file)

    return rows


def find_subject_dirs(root_dir):
    subject_dirs = []
    for entry in sorted(os.listdir(root_dir)):
        work_dir = os.path.join(root_dir, entry)
        if not os.path.isdir(work_dir):
            continue
        if os.path.isfile(os.path.join(work_dir, ATLAS_IMAGES["HarvardOxford-Cortical"])):
            subject_dirs.append(work_dir)
    return subject_dirs


def analyze_subject(work_dir, group_name, atlas_labels):
    subject = os.path.basename(work_dir)
    rows = []

    metric_files = resolve_metrics_in_t1(work_dir)
    if not metric_files:
        return rows

    for atlas_name, atlas_filename in ATLAS_IMAGES.items():
        atlas_file = os.path.join(work_dir, atlas_filename)
        if not os.path.isfile(atlas_file):
            print(f"  Warning: missing atlas {atlas_filename}, skipping atlas")
            continue

        roi_names = atlas_labels[atlas_name]

        for metric_name, metric_file in metric_files.items():
            rows.extend(
                collect_roi_rows(
                    subject,
                    group_name,
                    atlas_name,
                    roi_names,
                    atlas_file,
                    metric_name,
                    metric_file,
                )
            )

    return rows


def write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(
        description="Extract atlas ROI statistics for the Ataxia T1-space pipeline."
    )
    parser.add_argument("root_folder", help="Root folder with subject subdirectories")
    parser.add_argument(
        "--group",
        default="Controles",
        help="Group label written to CSV (default: Controles)",
    )
    args = parser.parse_args()

    root_dir = os.path.abspath(args.root_folder)
    if not os.path.isdir(root_dir):
        print(f"Error: root folder not found: {root_dir}", file=sys.stderr)
        sys.exit(1)

    atlas_labels = {name: parse_atlas_xml(path) for name, path in ATLAS_XML.items()}
    subject_dirs = find_subject_dirs(root_dir)

    if not subject_dirs:
        print(f"No subject directories with warped atlases found in {root_dir}")
        sys.exit(1)

    print(f"Found {len(subject_dirs)} subjects in {root_dir}")

    all_rows = []
    for work_dir in subject_dirs:
        subject = os.path.basename(work_dir)
        print(f"Processing {subject}...")
        rows = analyze_subject(work_dir, args.group, atlas_labels)
        all_rows.extend(rows)

        subject_csv = os.path.join(work_dir, "atlas_statistics.csv")
        write_csv(subject_csv, rows)
        print(f"  Wrote {len(rows)} rows to {subject_csv}")

    combined_csv = os.path.join(root_dir, "atlas_statistics_all.csv")
    write_csv(combined_csv, all_rows)
    print(f"\nCombined output: {combined_csv} ({len(all_rows)} rows)")


if __name__ == "__main__":
    main()
