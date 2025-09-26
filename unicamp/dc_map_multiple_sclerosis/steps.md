# Script to preprocess data for the DC_MAP_MULTIPLE_SCLEROSIS project

# Steps:

ISMRM abstract pipeline (abstract folder):

1. Reconstruct DTI maps (FA, MD) and DC mapping - Script: dti_reconstruction.sh
2. Register MNI and HO atlases to DTI space and normalize FLAIR and lesions maps to DTI space - Script: register_mni_to_dti.sh
3. Filter brain atlas GM + lesion and calculate quantitative measures (justacortical) - Script: filter_atlas_and_calculate_measures.sh

Full paper pipeline:

1. Reconstruct DTI maps (FA, MD) and DC mapping - Script: dti_reconstruction.sh
2. Register MNI space to DTI space and normalize AAL3 and HO atlases (asltk) - Script: register_mni_to_dti.sh
3. Segment T1 images using FSL-FAST and get WM, GM and CSF binary masks - Script: segment_t1.sh
4. Register T1 and FLAIR to DTI space and apply transformations on WM, GM, CSF and lesion masks - Script: anat_to_dti.sh
5. Filter brain atlas to WM and GM and calculate quantitative measures - Script: filter_atlas_and_calculate_measures.sh
6. Calculate quantitative measures for lesions masks (FA, MD and ADC) - Script: calculate_measures.sh