# Script to preprocess data for the DC_MAP_MULTIPLE_SCLEROSIS project

# Steps:

1. Reconstruct DTI maps (FA, MD) and DC mapping - Script: dti_reconstruction.sh
2. Register MNI space to DTI space - Script: register_mni_to_dti.sh
3. Register T1 images to DTI space - Script: register_t1_to_dti.sh
4. Register lesion masks to DTI space - Script: register_lesion_to_dti.sh
5. Calculate quantitative measures - Script: calculate_measures.sh
6. Perform statistical analysis - Script: statistical_analysis.sh