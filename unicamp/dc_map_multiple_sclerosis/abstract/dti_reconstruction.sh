#!/bin/bash
# IMPORTANTE: Colocar a pasta lesions na mesma pasta que os arquivos DTI, para ter tudo na mesma estrutura de pastas (por sujeito)
# IMPORTANTE: Limpar a pasta dos arquivos que começam com '.', arquivos temporarios

# Reconstruct DTI maps

# Inputs:
# - root_folder: pasta com arquivos DTI (estrutura plana ou por sujeito)
# - dwi_file_suffix: sufixo para identificar volumes DWI (ex.: 256DTI_high_iso20_SENSE)

# Outputs (por sujeito, em <root_folder>/<subject_name>/):
# - dwi.nrrd, dwi_brain_mask.nrrd, dti.nrrd, dti_DC.nii.gz

ROOT_FOLDER=$1
DWI_FILE_SUFFIX=$2 # TIP: 256DTI_high_iso20_SENSE

SLICER_FOLDER="/home/antonio/Documents/Tools/Slicer-5.11.0-2026-05-11-linux-amd64/"
DC_FOLDER="/home/antonio/Projects/CSIM/DiffusionComplexityMapping/build"

if [ -z "$ROOT_FOLDER" ] || [ -z "$DWI_FILE_SUFFIX" ]; then
    echo "Usage: $0 <root_folder> <dwi_file_suffix>"
    echo "Example: $0 ~/Desktop/Unicamp_analysis/Ataxia/Controles 256DTI_high_iso20_SENSE"
    exit 1
fi

if [ ! -d "$ROOT_FOLDER" ]; then
    echo "Error: root folder not found: $ROOT_FOLDER"
    exit 1
fi

CURRENT_DIR=$(pwd)

# Process each DWI volume (flat folder: all subjects share ROOT_FOLDER)
while IFS= read -r -d '' DWI_FILE; do
    BASENAME=$(basename "$DWI_FILE")
    case "$BASENAME" in
        *_ADC.nii|*_ADC.nii.gz|*VBM*)
            continue
            ;;
    esac

    SUBJECT_DIR=$(dirname "$DWI_FILE")
    SUBJECT_PREFIX="${BASENAME%.nii.gz}"
    SUBJECT_PREFIX="${SUBJECT_PREFIX%.nii}"
    SUBJECT_NAME="${SUBJECT_PREFIX%%_256DTI*}"
    WORK_DIR="${SUBJECT_DIR}/${SUBJECT_NAME}"

    BVAL_FILE="${SUBJECT_DIR}/${SUBJECT_PREFIX}.bval"
    BVEC_FILE="${SUBJECT_DIR}/${SUBJECT_PREFIX}.bvec"

    if [ ! -f "$BVAL_FILE" ] || [ ! -f "$BVEC_FILE" ]; then
        echo "Skipping ${SUBJECT_PREFIX}: missing bval/bvec"
        echo "  expected: ${BVAL_FILE}"
        echo "  expected: ${BVEC_FILE}"
        echo ""
        continue
    fi

    mkdir -p "$WORK_DIR"

    echo "Subject name: $SUBJECT_NAME"
    echo "Work directory: $WORK_DIR"
    echo "DWI file: $DWI_FILE"
    echo "bval file: $BVAL_FILE"
    echo "bvec file: $BVEC_FILE"

    echo "Executing FSL data to NRRD conversion"
    cd "$SLICER_FOLDER"
    ./Slicer --launch DWIConvert --conversionMode FSLToNrrd \
        --outputVolume "${WORK_DIR}/dwi.nrrd" \
        --fslNIFTIFile "$DWI_FILE" \
        --inputBValues "$BVAL_FILE" \
        --inputBVectors "$BVEC_FILE" \
        --allowLossyConversion

    echo "Creating brain mask for $DWI_FILE"
    ./Slicer --launch DiffusionWeightedVolumeMasking --removeislands \
        "${WORK_DIR}/dwi.nrrd" \
        "${WORK_DIR}/dwi_baseline.nrrd" \
        "${WORK_DIR}/dwi_brain_mask.nrrd"
    # bet "$DWI_FILE" "${WORK_DIR}/dwi_brain" -m -n

    echo "Fitting diffusion tensor model for $DWI_FILE"
    ./Slicer --launch DWIToDTIEstimation \
        --mask "${WORK_DIR}/dwi_brain_mask.nrrd" \
        --enumeration LS \
        "${WORK_DIR}/dwi.nrrd" \
        "${WORK_DIR}/dti.nrrd" \
        "${WORK_DIR}/dwi_baseline.nrrd"

    echo "Calculate Diffusion Tensor Scalar Measurements"
    ./Slicer --launch DiffusionTensorScalarMeasurements --enumeration FractionalAnisotropy \
        "${WORK_DIR}/dti.nrrd" \
        "${WORK_DIR}/dti_FA.nrrd"
    ./Slicer --launch DiffusionTensorScalarMeasurements --enumeration MeanDiffusivity \
        "${WORK_DIR}/dti.nrrd" \
        "${WORK_DIR}/dti_MD.nrrd"

    echo "Calculate Diffusion Complexity (DC) maps"
    cd "$DC_FOLDER"
    ./DiffusionComplexityMapping \
        "${WORK_DIR}/dwi.nrrd" \
        "${WORK_DIR}/dwi_brain_mask.nrrd" \
        "${WORK_DIR}/dti_DC.nii.gz" \
        1.0


    cd "$CURRENT_DIR"

    echo "Done: $SUBJECT_NAME"
    echo ""
done < <(find "$ROOT_FOLDER" -type f \( -name "*.nii" -o -name "*.nii.gz" \) -name "*${DWI_FILE_SUFFIX}*" -print0)
