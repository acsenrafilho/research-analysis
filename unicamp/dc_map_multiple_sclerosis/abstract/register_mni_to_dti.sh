#!/bin/bash

# Script to register MNI space to DTI space using ANTs
ROOT_DIR=$1
DTI_BASELINE_SUFFIX=$2 #TIP: dwi.nii.gz

MNI_TEMPLATE="/home/antonio/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz"
ATLAS="/home/antonio/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz"

# Perform registration from MNI to DTI space
for file in `find $ROOT_DIR -name "*$DTI_BASELINE_SUFFIX"`; do
    OUTPUT_DIR=$(dirname "$file")

    bet $file ${OUTPUT_DIR}/brain -m -n
    dtifit -k $file -o ${OUTPUT_DIR}/dti -m ${OUTPUT_DIR}/brain_mask.nii.gz -r ${OUTPUT_DIR}/`ls ${OUTPUT_DIR}/ | grep .bvec` -b ${OUTPUT_DIR}/`ls ${OUTPUT_DIR}/ | grep .bval` --verbose
    baseline=`ls ${OUTPUT_DIR}/ | grep dti_S0.nii.gz`

    echo "Registering $MNI_TEMPLATE to $baseline"
    antsRegistrationSyNQuick.sh -d 3 -f ${OUTPUT_DIR}/$baseline -m $MNI_TEMPLATE -o ${OUTPUT_DIR}/mni_to_dwi_ -n 10

    echo "Transforming the MNI brain atlases to DTI space"
    antsApplyTransforms -d 3 -i $ATLAS -r ${OUTPUT_DIR}/$baseline -o ${OUTPUT_DIR}/HO_atlas_in_dwi.nii.gz -t ${OUTPUT_DIR}/mni_to_dwi_1Warp.nii.gz -t ${OUTPUT_DIR}/mni_to_dwi_0GenericAffine.mat -n NearestNeighbor

    echo "Normalizing DC map space to FSL generated space"
    flirt -ref ${OUTPUT_DIR}/dti_FA.nii.gz -in ${OUTPUT_DIR}/dti_DC.nii.gz -out ${OUTPUT_DIR}/dti_DC_fsl.nii.gz

    echo "Normalizing FLAIR to DTI space"
    lesion_dir=$(dirname "$OUTPUT_DIR")
    flair=$(find "$lesion_dir" -type f -name 'rm*')
    antsRegistrationSyNQuick.sh -d 3 -f ${OUTPUT_DIR}/$baseline -m $flair -o ${OUTPUT_DIR}/flair_to_dwi_ -n 10

    echo "Transforming the FLAIR lesions to DTI space"
    lesions=`ls $lesion_dir | grep corrected_mask_binary`
    antsApplyTransforms -d 3 -i $lesion_dir/$lesions -r ${OUTPUT_DIR}/$baseline -o ${OUTPUT_DIR}/lesions_in_dwi.nii.gz -t ${OUTPUT_DIR}/flair_to_dwi_1Warp.nii.gz -t ${OUTPUT_DIR}/flair_to_dwi_0GenericAffine.mat -n NearestNeighbor

    echo "Done with $OUTPUT_DIR"
    echo "-----------------------------------"
    echo ""
    echo ""
done