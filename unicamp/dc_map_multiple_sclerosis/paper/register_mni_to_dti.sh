#!/bin/bash

# Register MNI space to DTI space and normalize AAL3 and HO atlases (asltk) 

# Inputs:
# - Root directory containing subject folders with DTI data
# - DWI images suffix to find the image in the root folder

# Outputs:
# - Normalized AAL3 and HO atlases in native space

ROOT_FOLDER=$1
DWI_FILE_SUFFIX=$2

if [ -z "$ROOT_FOLDER" ] || [ -z "$DWI_FILE_SUFFIX" ]; then
    echo "Usage: $0 <root_folder> <dwi_file_suffix>"
    exit 1
fi

CURRENT_DIR=$(pwd)

for DWI_FILE in `find "$ROOT_FOLDER" -type f -name "*${DWI_FILE_SUFFIX}"`; do
    SUBJECT_DIR=$(dirname "$DWI_FILE")
    SUBJECT_ID=$(basename "$SUBJECT_DIR")
    echo "Processing subject: $SUBJECT_ID"
    
    echo "Registering MNI space to DTI space for $DWI_FILE"
    ants

    echo "Normalizing AAL3 and HO atlases to DTI space for $DWI_FILE"
    bash normalize_atlases_to_dti.sh "$SUBJECT_DIR" "dti.nrrd"
done