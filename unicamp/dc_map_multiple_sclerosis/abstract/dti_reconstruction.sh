#!/bin/bash
# IMPORTANTE: Colocar a pasta lesions na mesma pasta que os arquivos DTI, para ter tudo na mesma estrutura de pastas (por sujeito)
# IMPORTANTE: Limpar a pasta dos arquivos que começam com '.', arquivos temporarios

# Reconstruct DTI maps 

# Inputs:
# - DWI images suffix to find the image in the root folder
# - bvec and bval files

# Outputs:
# - DC maps

ROOT_FOLDER=$1
DWI_FILE_SUFFIX=$2 #TIP: dwi.nii.gz

SLICER_FOLDER="/home/antonio/Documentos/Slicer-5.9.0-2025-09-18-linux-amd64"
DC_FOLDER="/home/antonio/Documentos/csim/ITK-build/DiffusionComplexityMapping"

if [ -z "$ROOT_FOLDER" ] || [ -z "$DWI_FILE_SUFFIX" ]; then
    echo "Usage: $0 <root_folder> <dwi_file_suffix>"
    exit 1
fi

CURRENT_DIR=$(pwd)

# Step 2: Process each DWI file
for DWI_FILE in `find "$ROOT_FOLDER" -type f -name "*${DWI_FILE_SUFFIX}"`; do
    SUBJECT_DIR=$(dirname "$DWI_FILE")
    SUBJECT_ID=$(basename "$SUBJECT_DIR")
    echo "Processing subject: $SUBJECT_ID"
    
    echo "Executing FSL data to NRRD conversion"
    cd "$SLICER_FOLDER"
    ./Slicer --launch DWIConvert --conversionMode FSLToNrrd \
    --outputVolume ${SUBJECT_DIR}/dwi.nrrd  \
    --fslNIFTIFile ${DWI_FILE} \
    --inputBValues ${SUBJECT_DIR}/`ls ${SUBJECT_DIR} | grep .bval` \
    --inputBVectors ${SUBJECT_DIR}/`ls ${SUBJECT_DIR} | grep .bvec` \
    --allowLossyConversion

    echo "Creating brain mask for $DWI_FILE"
    ./Slicer --launch DiffusionWeightedVolumeMasking --removeislands \
    ${SUBJECT_DIR}/dwi.nrrd \
    ${SUBJECT_DIR}/dwi_baseline.nrrd \
    ${SUBJECT_DIR}/dwi_brain_mask.nrrd
    # bet "$DWI_FILE" "${SUBJECT_DIR}/dwi_brain" -m -n

    echo "Fitting diffusion tensor model for $DWI_FILE"
    ./Slicer --launch DWIToDTIEstimation \
    --mask ${SUBJECT_DIR}/dwi_brain_mask.nrrd \
    --enumeration LS \
    ${SUBJECT_DIR}/dwi.nrrd \
    ${SUBJECT_DIR}/dti.nrrd \
    ${SUBJECT_DIR}/dwi_baseline.nrrd

    echo "Calculate Diffusion Complexity (DC) maps"
    cd "$DC_FOLDER"
    ./DiffusionComplexityMapping \
    ${SUBJECT_DIR}/dwi.nrrd \
    ${SUBJECT_DIR}/dwi_brain_mask.nrrd \
    ${SUBJECT_DIR}/dti_DC.nii.gz \
    1.0


    cd "$CURRENT_DIR"

    echo "Done..."
    echo ""
    echo ""
done