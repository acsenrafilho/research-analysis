# Script to preprocess data for the DC_MAP_EPLEPSY project

# Steps:

1. Reconstruct DTI maps (FA, MD) and DC mapping - Script: dti_reconstruction.sh
2. Register DTI to MNI space and normalize AAL3 and HO atlases (asltk) - Script: register_dti_to_mni.sh
3. Apply the transformations to the DTI maps (FA, MD) and DC maps - Script: apply_transformations.sh
4. Execute the randomise tool for group comparison - Script: run_randomise.sh
5. Make a ROI analysis based on the significant clusters from randomise - Script: roi_analysis.sh