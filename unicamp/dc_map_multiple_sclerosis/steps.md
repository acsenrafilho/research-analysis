# Script to preprocess data for the DC_MAP_MULTIPLE_SCLEROSIS project

# Steps:

1. Reconstruct DTI maps (FA, MD) and DC mapping - Script: dti_reconstruction.sh
2. Register MNI space to DTI space and normalize AAL3 and HO atlases (asltk) - Script: register_mni_to_dti.sh
3. Segment WM, GM and CSF from T1 images and place (T1 and FLAIR) to DTI space - Script: segment_t1_to_dti.sh
4. Filter brain atlas to WM and GM and calculate quantitative measures - Script: filter_atlas_and_calculate_measures.sh
5. Register lesion masks to DTI space (getting FLAIR transformations to DTI space) - Script: register_lesion_to_dti.sh
6. Calculate quantitative measures for lesions masks (FA, MD and ADC) - Script: calculate_measures.sh