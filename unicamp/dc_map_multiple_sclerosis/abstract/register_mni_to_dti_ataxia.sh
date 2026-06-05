#!/bin/bash

# Register B0 and DTI maps to T1 space, then warp MNI atlases to T1.
# Designed for the Ataxia flat-folder layout (subject subfolders + T1 VBM at root).
#
# Inputs:
#   root_folder - e.g. ~/Desktop/Unicamp_analysis/Ataxia/Controles
#
# Prerequisites per subject (from dti_reconstruction.sh):
#   <root>/<subject>/dwi_baseline.nrrd, dti_FA.nrrd, dti_MD.nrrd, dti_DC.nii.gz
#   <root>/<subject>*VBM*.nii  (T1 structural)

set -uo pipefail

ROOT_DIR=$1

MNI_TEMPLATE="/home/antonio/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz"
ATLAS_HO="/home/antonio/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz"
ATLAS_CEREBELLUM="/home/antonio/fsl/data/atlases/Cerebellum/Cerebellum-MNIfnirt-maxprob-thr25-1mm.nii.gz"
SLICER_FOLDER="/home/antonio/Documents/Tools/Slicer-5.11.0-2026-05-11-linux-amd64/"

if [ -z "$ROOT_DIR" ]; then
    echo "Usage: $0 <root_folder>"
    echo "Example: $0 ~/Desktop/Unicamp_analysis/Ataxia/Controles"
    exit 1
fi

if [ ! -d "$ROOT_DIR" ]; then
    echo "Error: root folder not found: $ROOT_DIR"
    exit 1
fi

convert_nrrd_to_nifti() {
    local input_nrrd=$1
    local output_nii=$2

    if [ -f "$output_nii" ]; then
        return 0
    fi

    if command -v ConvertImage &>/dev/null; then
        ConvertImage 3 "$input_nrrd" "$output_nii"
        return $?
    fi

    if [ -x "${SLICER_FOLDER}/Slicer" ]; then
        "${SLICER_FOLDER}/Slicer" --launch DWIConvert \
            --conversionMode NrrdToFSL \
            --inputVolume "$input_nrrd" \
            --outputVolume "$output_nii" \
            --allowLossyConversion
        return $?
    fi

    echo "Error: cannot convert $input_nrrd (ConvertImage or Slicer required)"
    return 1
}

apply_map_to_t1() {
    local input_map=$1
    local output_map=$2
    local work_dir=$3

    antsApplyTransforms -d 3 \
        -i "$input_map" \
        -r "${work_dir}/t1_brain.nii.gz" \
        -o "$output_map" \
        -t "${work_dir}/b0_to_t1_1Warp.nii.gz" \
        -t "${work_dir}/b0_to_t1_0GenericAffine.mat" \
        -n Linear
}

apply_atlas_to_t1() {
    local atlas=$1
    local output_atlas=$2
    local work_dir=$3

    antsApplyTransforms -d 3 \
        -i "$atlas" \
        -r "${work_dir}/t1_brain.nii.gz" \
        -o "$output_atlas" \
        -t "${work_dir}/mni_to_t1_1Warp.nii.gz" \
        -t "${work_dir}/mni_to_t1_0GenericAffine.mat" \
        -n NearestNeighbor
}

for WORK_DIR in "$ROOT_DIR"/*/; do
    [ -d "$WORK_DIR" ] || continue
    SUBJECT_NAME=$(basename "$WORK_DIR")

    if [ ! -f "${WORK_DIR}/dwi_baseline.nrrd" ]; then
        continue
    fi

    echo "========================================"
    echo "Subject: $SUBJECT_NAME"
    echo "Work directory: $WORK_DIR"
    echo "========================================"

    T1_FILE=$(find "$ROOT_DIR" -maxdepth 1 -type f \( \
        -name "${SUBJECT_NAME}*VBM*.nii" -o \
        -name "${SUBJECT_NAME}*VBM*.nii.gz" \
        \) | head -n 1)

    if [ -z "$T1_FILE" ] || [ ! -f "$T1_FILE" ]; then
        echo "Skipping ${SUBJECT_NAME}: T1 VBM not found in ${ROOT_DIR}"
        echo ""
        continue
    fi

    for required in dti_FA.nrrd dti_MD.nrrd dti_DC.nii.gz; do
        if [ ! -f "${WORK_DIR}/${required}" ]; then
            echo "Skipping ${SUBJECT_NAME}: missing ${required}"
            echo ""
            continue 2
        fi
    done

    echo "T1 file: $T1_FILE"

    # --- Step 1: T1 preprocessing (N4, denoise, BET) ---
    echo "T1 bias correction (N4)..."
    N4BiasFieldCorrection -d 3 -i "$T1_FILE" -o "${WORK_DIR}/t1_n4.nii.gz"

    echo "T1 denoising..."
    DenoiseImage -d 3 -i "${WORK_DIR}/t1_n4.nii.gz" -o "${WORK_DIR}/t1_denoised.nii.gz"

    echo "T1 brain extraction (BET)..."
    bet "${WORK_DIR}/t1_denoised.nii.gz" "${WORK_DIR}/t1_brain" -m -R -f 0.5 -g 0

    # --- Step 1: B0 preprocessing ---
    echo "Converting dwi_baseline.nrrd to NIfTI..."
    if ! convert_nrrd_to_nifti "${WORK_DIR}/dwi_baseline.nrrd" "${WORK_DIR}/dwi_baseline.nii.gz"; then
        echo "Skipping ${SUBJECT_NAME}: B0 conversion failed"
        echo ""
        continue
    fi

    echo "B0 brain extraction (BET)..."
    bet "${WORK_DIR}/dwi_baseline.nii.gz" "${WORK_DIR}/dwi_baseline_brain" -m -f 0.3 -g 0
    if [ ! -f "${WORK_DIR}/dwi_baseline_brain.nii.gz" ] && [ -f "${WORK_DIR}/dwi_baseline_brain_mask.nii.gz" ]; then
        fslmaths "${WORK_DIR}/dwi_baseline.nii.gz" -mas "${WORK_DIR}/dwi_baseline_brain_mask.nii.gz" \
            "${WORK_DIR}/dwi_baseline_brain.nii.gz"
    fi

    # --- Step 2: B0 -> T1 registration ---
    echo "Registering B0 to T1..."
    antsRegistrationSyNQuick.sh -d 3 \
        -f "${WORK_DIR}/t1_brain.nii.gz" \
        -m "${WORK_DIR}/dwi_baseline_brain.nii.gz" \
        -o "${WORK_DIR}/b0_to_t1_" \
        -n 10

    # --- Step 2: Transform DTI maps to T1 ---
    echo "Converting DTI maps to NIfTI..."
    convert_nrrd_to_nifti "${WORK_DIR}/dti_FA.nrrd" "${WORK_DIR}/dti_FA.nii.gz"
    convert_nrrd_to_nifti "${WORK_DIR}/dti_MD.nrrd" "${WORK_DIR}/dti_MD.nii.gz"

    echo "Transforming FA, MD and DC to T1 space..."
    apply_map_to_t1 "${WORK_DIR}/dti_FA.nii.gz" "${WORK_DIR}/dti_FA_in_t1.nii.gz" "$WORK_DIR"
    apply_map_to_t1 "${WORK_DIR}/dti_MD.nii.gz" "${WORK_DIR}/dti_MD_in_t1.nii.gz" "$WORK_DIR"
    apply_map_to_t1 "${WORK_DIR}/dti_DC.nii.gz" "${WORK_DIR}/dti_DC_in_t1.nii.gz" "$WORK_DIR"

    # --- Step 3: MNI -> T1 registration ---
    echo "Registering MNI template to T1..."
    antsRegistrationSyNQuick.sh -d 3 \
        -f "${WORK_DIR}/t1_brain.nii.gz" \
        -m "$MNI_TEMPLATE" \
        -o "${WORK_DIR}/mni_to_t1_" \
        -n 10

    # --- Step 4: Transform atlases to T1 ---
    echo "Transforming Harvard-Oxford atlas to T1 space..."
    apply_atlas_to_t1 "$ATLAS_HO" "${WORK_DIR}/HO_atlas_in_t1.nii.gz" "$WORK_DIR"

    echo "Transforming Cerebellum atlas to T1 space..."
    apply_atlas_to_t1 "$ATLAS_CEREBELLUM" "${WORK_DIR}/Cerebellum_atlas_in_t1.nii.gz" "$WORK_DIR"

    echo "Done: $SUBJECT_NAME"
    echo ""
done

echo "All subjects processed."
