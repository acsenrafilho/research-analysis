#!/bin/bash

# Script to register MNI space to DTI space using ANTs
# OUTPUT_DIR=$(dirname "$1")
# file=$1
ROOT_DIR=$1
# DTI_BASELINE_SUFFIX=$2 #TIP: dwi.nii.gz

MNI_TEMPLATE="/home/antonio/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz"

# Perform registration from MNI to DTI space
for file in `find $ROOT_DIR -name "*.nii.gz"`; do
    OUTPUT_DIR=$(dirname "$file")

    bet $file ${OUTPUT_DIR}/brain -m -n

    echo "file: $file"
    echo "OUTPUT_DIR: $OUTPUT_DIR"
    echo "Registering $file to $MNI_TEMPLATE"
    echo "Short file: $(basename ${file%.*}_)"
    antsRegistrationSyN.sh -d 3 -f $MNI_TEMPLATE -m $file -o ${OUTPUT_DIR}/$(basename ${file%.*}_) -n 10

    echo "Done with $OUTPUT_DIR"
    echo "-----------------------------------"
    echo ""
    echo ""
done