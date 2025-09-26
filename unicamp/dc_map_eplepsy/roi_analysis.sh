#!/bin/bash
# filepath: /home/antonio/Documentos/acsenrafilho/research-analysis/unicamp/dc_map_eplepsy/roi_analysis.sh

# Script to perform ROI analysis on randomise outputs
# This script extracts statistics from ROIs defined in an atlas
# and compares values between epilepsy patients and healthy controls

# Check for required command-line arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <atlas_image> <p_value_threshold> <randomise_results_dir>"
  echo "Example: $0 /usr/local/fsl/data/atlases/HarvardOxford-cort-maxprob-thr25-2mm.nii.gz 0.05 ./results"
  exit 1
fi

ATLAS=$1
P_THRESHOLD=$2
RESULTS_DIR=$3

# Check if atlas file exists
if [ ! -f "$ATLAS" ]; then
  echo "Error: Atlas file not found: $ATLAS"
  exit 1
fi

# Check if randomise results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
  echo "Error: Randomise results directory not found: $RESULTS_DIR"
  exit 1
fi

# Set output directories
ROI_DIR="roi_analysis"
mkdir -p $ROI_DIR
mkdir -p $ROI_DIR/masks
mkdir -p $ROI_DIR/stats

echo "Starting ROI analysis with atlas: $(basename $ATLAS)"
echo "Using p-value threshold: $P_THRESHOLD"
echo "Using randomise results from: $RESULTS_DIR"

# Get atlas information
echo "Extracting ROI information from atlas..."
NUM_ROIS=$(fslstats $ATLAS -R | awk '{print $2}' | xargs printf "%.0f\n")
echo "Found $NUM_ROIS ROIs in the atlas"

# Process each ROI
echo "Processing individual ROIs..."
for ((roi=1; roi<=NUM_ROIS; roi++)); do
  echo "Creating mask for ROI $roi..."
  
  # Create binary mask for this ROI
  fslmaths $ATLAS -thr $roi -uthr $roi -bin $ROI_DIR/masks/roi_${roi}_mask
  
  # Apply slight erosion to reduce partial volume effects
  fslmaths $ROI_DIR/masks/roi_${roi}_mask -kernel sphere 1 -ero $ROI_DIR/masks/roi_${roi}_mask_eroded
done

# Python script to perform statistical analysis on ROIs
echo "Running statistical analysis on ROIs..."
cat > $ROI_DIR/analyze_rois.py << 'EOF'
#!/usr/bin/env python3

import os
import sys
import numpy as np
import pandas as pd
import SimpleITK as sitk
from glob import glob

# Command line arguments
atlas_file = sys.argv[1]
p_threshold = float(sys.argv[2])
roi_count = int(sys.argv[3])
results_dir = sys.argv[4]

# Map types to process
map_types = ['FA', 'MD', 'DC']

def get_roi_name(atlas_path, roi_index):
    # This function would ideally get ROI names from the atlas lookup table
    # For now, we'll just return a generic name
    return f"ROI_{roi_index}"

def load_subject_data(merged_file, roi_mask, index_range):
    """
    Extract data for subjects within a specific index range from a 4D file
    for a specific ROI mask
    """
    img = sitk.ReadImage(merged_file)
    mask = sitk.ReadImage(roi_mask)
    
    data = sitk.GetArrayFromImage(img)
    mask_arr = sitk.GetArrayFromImage(mask)
    
    # For each subject, calculate the mean value within the ROI
    roi_means = []
    
    # Extract just the desired volume indices
    for idx in range(index_range[0], index_range[1]):
        subject_vol = data[idx, :, :, :]
        # Calculate mean within ROI
        masked_values = subject_vol[mask_arr > 0]
        if len(masked_values) > 0:
            roi_means.append(np.mean(masked_values))
        else:
            roi_means.append(np.nan)
            
    return roi_means

# Get patient and control counts
with open("temp_data/patient_fa_list.txt", 'r') as f:
    patient_count = len(f.readlines())
with open("temp_data/control_fa_list.txt", 'r') as f:
    control_count = len(f.readlines())

print(f"Processing data for {patient_count} patients and {control_count} controls")

# Process each map type
for map_type in map_types:
    print(f"Processing {map_type} maps...")
    
    # Create dataframes to store results
    patients_df = pd.DataFrame()
    controls_df = pd.DataFrame()
    
    # Process each ROI
    for roi in range(1, roi_count + 1):
        roi_name = get_roi_name(atlas_file, roi)
        eroded_mask = f"roi_analysis/masks/roi_{roi}_mask_eroded.nii.gz"
        
        if not os.path.exists(eroded_mask):
            print(f"Warning: Mask {eroded_mask} not found, skipping ROI {roi}")
            continue
        
        merged_file = f"temp_data/all_subjects_{map_type}.nii.gz"
        
        # Extract patient data (first in the merged file)
        patient_data = load_subject_data(merged_file, eroded_mask, (0, patient_count))
        patients_df[roi_name] = patient_data
        
        # Extract control data (after patient data in the merged file)
        control_data = load_subject_data(merged_file, eroded_mask, (patient_count, patient_count + control_count))
        controls_df[roi_name] = control_data
    
    # Save to CSV
    patients_df.to_csv(f"roi_analysis/stats/{map_type}_patients_roi_values.csv", index_label="Subject")
    controls_df.to_csv(f"roi_analysis/stats/{map_type}_controls_roi_values.csv", index_label="Subject")
    
    # Generate summary statistics
    summary_df = pd.DataFrame()
    for roi_name in patients_df.columns:
        summary_df.loc["Patient_Mean", roi_name] = patients_df[roi_name].mean()
        summary_df.loc["Patient_Std", roi_name] = patients_df[roi_name].std()
        summary_df.loc["Control_Mean", roi_name] = controls_df[roi_name].mean()
        summary_df.loc["Control_Std", roi_name] = controls_df[roi_name].std()
    
    summary_df.to_csv(f"roi_analysis/stats/{map_type}_summary_stats.csv")
    
print("ROI analysis complete!")
EOF

# Make Python script executable
chmod +x $ROI_DIR/analyze_rois.py

# Run the Python script
echo "Extracting statistics from ROIs..."
python $ROI_DIR/analyze_rois.py "$ATLAS" "$P_THRESHOLD" "$NUM_ROIS" "$RESULTS_DIR"

# Generate final report
echo "Creating final report..."
cat > $ROI_DIR/generate_report.py << 'EOF'
#!/usr/bin/env python3

import os
import sys
import pandas as pd
import numpy as np

p_threshold = float(sys.argv[1])
results_dir = sys.argv[2]
map_types = ['FA', 'MD', 'DC']

for map_type in map_types:
    # Load randomise results for significant clusters
    tfce_file = f"{results_dir}/{map_type}/{map_type.lower()}_patients_vs_controls_tfce_corrp_tstat1.nii.gz"
    
    # Check if the file exists
    if not os.path.exists(tfce_file):
        print(f"Warning: {tfce_file} not found, skipping analysis for {map_type}")
        continue
        
    print(f"Analyzing significant clusters for {map_type}...")
    
    # Load ROI summary stats
    stats_file = f"roi_analysis/stats/{map_type}_summary_stats.csv"
    if not os.path.exists(stats_file):
        print(f"Warning: {stats_file} not found, skipping analysis for {map_type}")
        continue
        
    summary_stats = pd.read_csv(stats_file, index_col=0)
    
    # Create final report dataframe
    report_df = pd.DataFrame(columns=['ROI', 'Patient_Mean', 'Patient_Std', 'Control_Mean', 'Control_Std', 'Difference', 'Percent_Difference'])
    
    for roi in summary_stats.columns:
        patient_mean = summary_stats.loc['Patient_Mean', roi]
        patient_std = summary_stats.loc['Patient_Std', roi]
        control_mean = summary_stats.loc['Control_Mean', roi]
        control_std = summary_stats.loc['Control_Std', roi]
        
        difference = patient_mean - control_mean
        percent_diff = (difference / control_mean) * 100 if control_mean != 0 else np.nan
        
        new_row = {
            'ROI': roi,
            'Patient_Mean': patient_mean,
            'Patient_Std': patient_std,
            'Control_Mean': control_mean,
            'Control_Std': control_std,
            'Difference': difference,
            'Percent_Difference': percent_diff
        }
        
        report_df = pd.concat([report_df, pd.DataFrame([new_row])], ignore_index=True)
    
    # Save the report
    report_df.to_csv(f"roi_analysis/{map_type}_final_report.csv", index=False)
    print(f"Final report for {map_type} saved to roi_analysis/{map_type}_final_report.csv")

print("Analysis complete!")
EOF

# Make Python script executable
chmod +x $ROI_DIR/generate_report.py

# Run the Python script for final report
echo "Generating final reports..."
python $ROI_DIR/generate_report.py "$P_THRESHOLD" "$RESULTS_DIR"

echo "ROI analysis complete!"
echo "Results are available in the roi_analysis directory:"
echo "  - Individual ROI masks: roi_analysis/masks/"
echo "  - ROI statistics: roi_analysis/stats/"
echo "  - Final reports: roi_analysis/*.csv"