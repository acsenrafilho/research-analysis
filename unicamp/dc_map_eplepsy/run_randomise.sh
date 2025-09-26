#!/bin/bash
# filepath: /home/antonio/Documentos/acsenrafilho/research-analysis/unicamp/dc_map_eplepsy/run_randomise.sh

# Improved script to run FSL randomise for DTI maps (FA, MD, DC)
# Comparing epilepsy patients vs. healthy controls

# Check for required command-line arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <patients_directory> <controls_directory>"
  echo "Example: $0 ./data/patients ./data/controls"
  exit 1
fi

PATIENTS_DIR=$1
CONTROLS_DIR=$2

# Set number of permutations for randomise
NPERM=5000

# Create output directory structure
echo "Setting up output directory structure..."
mkdir -p results/FA
mkdir -p results/MD
mkdir -p results/DC
mkdir -p design
mkdir -p temp_data

# Find all subject maps
echo "Finding subject maps..."

# Find FA maps
echo "Finding FA maps..."
PATIENT_FA_FILES=$(find ${PATIENTS_DIR} -type f -name "*FA*.nii*" | sort)
CONTROL_FA_FILES=$(find ${CONTROLS_DIR} -type f -name "*FA*.nii*" | sort)
NUM_PATIENTS_FA=$(echo "$PATIENT_FA_FILES" | wc -l)
NUM_CONTROLS_FA=$(echo "$CONTROL_FA_FILES" | wc -l)
echo "Found $NUM_PATIENTS_FA FA maps for patients"
echo "Found $NUM_CONTROLS_FA FA maps for controls"

# Check if FA maps were found
if [ $NUM_PATIENTS_FA -eq 0 ] || [ $NUM_CONTROLS_FA -eq 0 ]; then
  echo "Error: No FA maps found for patients or controls. Exiting."
  exit 1
fi

# Find MD maps
echo "Finding MD maps..."
PATIENT_MD_FILES=$(find ${PATIENTS_DIR} -type f -name "*MD*.nii*" | sort)
CONTROL_MD_FILES=$(find ${CONTROLS_DIR} -type f -name "*MD*.nii*" | sort)
NUM_PATIENTS_MD=$(echo "$PATIENT_MD_FILES" | wc -l)
NUM_CONTROLS_MD=$(echo "$CONTROL_MD_FILES" | wc -l)
echo "Found $NUM_PATIENTS_MD MD maps for patients"
echo "Found $NUM_CONTROLS_MD MD maps for controls"

# Check if MD maps were found
if [ $NUM_PATIENTS_MD -eq 0 ] || [ $NUM_CONTROLS_MD -eq 0 ]; then
  echo "Error: No MD maps found for patients or controls. Exiting."
  exit 1
fi

# Find DC maps
echo "Finding DC maps..."
PATIENT_DC_FILES=$(find ${PATIENTS_DIR} -type f -name "*DC*.nii*" | sort)
CONTROL_DC_FILES=$(find ${CONTROLS_DIR} -type f -name "*DC*.nii*" | sort)
NUM_PATIENTS_DC=$(echo "$PATIENT_DC_FILES" | wc -l)
NUM_CONTROLS_DC=$(echo "$CONTROL_DC_FILES" | wc -l)
echo "Found $NUM_PATIENTS_DC DC maps for patients"
echo "Found $NUM_CONTROLS_DC DC maps for controls"

# Check if DC maps were found
if [ $NUM_PATIENTS_DC -eq 0 ] || [ $NUM_CONTROLS_DC -eq 0 ]; then
  echo "Error: No DC maps found for patients or controls. Exiting."
  exit 1
fi



# Create file lists for merging
echo "Creating file lists for merging..."
echo "$PATIENT_FA_FILES" > temp_data/patient_fa_list.txt
echo "$CONTROL_FA_FILES" > temp_data/control_fa_list.txt
echo "$PATIENT_MD_FILES" > temp_data/patient_md_list.txt
echo "$CONTROL_MD_FILES" > temp_data/control_md_list.txt
echo "$PATIENT_DC_FILES" > temp_data/patient_dc_list.txt
echo "$CONTROL_DC_FILES" > temp_data/control_dc_list.txt

# Merge files for FA
echo "Merging FA files..."
cat temp_data/patient_fa_list.txt temp_data/control_fa_list.txt > temp_data/all_fa_list.txt
fslmerge -t temp_data/all_subjects_FA.nii.gz $(cat temp_data/all_fa_list.txt)

# Merge files for MD
echo "Merging MD files..."
cat temp_data/patient_md_list.txt temp_data/control_md_list.txt > temp_data/all_md_list.txt
fslmerge -t temp_data/all_subjects_MD.nii.gz $(cat temp_data/all_md_list.txt)

# Merge files for DC
echo "Merging DC files..."
cat temp_data/patient_dc_list.txt temp_data/control_dc_list.txt > temp_data/all_dc_list.txt
fslmerge -t temp_data/all_subjects_DC.nii.gz $(cat temp_data/all_dc_list.txt)

# Calculate total subjects for each map type
TOTAL_FA=$((NUM_PATIENTS_FA + NUM_CONTROLS_FA))
TOTAL_MD=$((NUM_PATIENTS_MD + NUM_CONTROLS_MD))
TOTAL_DC=$((NUM_PATIENTS_DC + NUM_CONTROLS_DC))

echo "Creating design matrices based on discovered data..."

# Function to create design matrices
create_design_matrix() {
    local num_patients=$1
    local num_controls=$2
    local output_file=$3
    local total=$((num_patients + num_controls))
    
    echo "/NumWaves 2" > $output_file
    echo "/NumPoints $total" >> $output_file
    echo "/PPheights 1 1" >> $output_file
    echo "" >> $output_file
    echo "/Matrix" >> $output_file
    
    # Add patients (group 1)
    for ((i=1; i<=num_patients; i++)); do
        echo "1 0" >> $output_file
    done
    
    # Add controls (group 2)
    for ((i=1; i<=num_controls; i++)); do
        echo "0 1" >> $output_file
    done
}

# Create design matrices for each map type
create_design_matrix $NUM_PATIENTS_FA $NUM_CONTROLS_FA design/design_FA.mat
create_design_matrix $NUM_PATIENTS_MD $NUM_CONTROLS_MD design/design_MD.mat
create_design_matrix $NUM_PATIENTS_DC $NUM_CONTROLS_DC design/design_DC.mat

# Create common contrast file
echo "Creating contrast file..."
cat > design/design.con << EOF
/ContrastName1 patients>controls
/ContrastName2 controls>patients
/NumWaves 2
/NumContrasts 2
/PPheights 1 1
/RequiredEffect 1 1

/Matrix
1 -1
-1 1
EOF

# Create checkpoint to let user review everything before running the analyses
echo -e "\n===== PRE-ANALYSIS CHECKPOINT ====="
echo "Please review the following information before proceeding:"
echo "----------------------------------------"
echo "FA analysis:"
echo "  - Number of patients: $NUM_PATIENTS_FA"
echo "  - Number of controls: $NUM_CONTROLS_FA"
echo "  - Total subjects: $TOTAL_FA"
echo "  - Design matrix: design/design_FA.mat"

echo -e "\nMD analysis:"
echo "  - Number of patients: $NUM_PATIENTS_MD"
echo "  - Number of controls: $NUM_CONTROLS_MD"
echo "  - Total subjects: $TOTAL_MD"
echo "  - Design matrix: design/design_MD.mat"

echo -e "\nDC analysis:"
echo "  - Number of patients: $NUM_PATIENTS_DC"
echo "  - Number of controls: $NUM_CONTROLS_DC"
echo "  - Total subjects: $TOTAL_DC"
echo "  - Design matrix: design/design_DC.mat"

echo -e "\nContrast file: design/design.con"
echo "Contrast 1: patients > controls"
echo "Contrast 2: controls > patients"
echo "Number of permutations: $NPERM"
echo "----------------------------------------"

# Ask for confirmation
read -p "Does everything look correct? Proceed with the analyses? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Analysis aborted by user."
    exit 0
fi

echo -e "\nProceeding with randomise analyses...\n"

# Run randomise for each map type
echo "Running randomise for FA maps..."
randomise -i temp_data/all_subjects_FA.nii.gz \
          -o results/FA/fa_patients_vs_controls \
          -d design/design_FA.mat \
          -t design/design.con \
          -n $NPERM \
          -T \
          -V

echo "Running randomise for MD maps..."
randomise -i temp_data/all_subjects_MD.nii.gz \
          -o results/MD/md_patients_vs_controls \
          -d design/design_MD.mat \
          -t design/design.con \
          -n $NPERM \
          -T \
          -V

echo "Running randomise for DC maps..."
randomise -i temp_data/all_subjects_DC.nii.gz \
          -o results/DC/dc_patients_vs_controls \
          -d design/design_DC.mat \
          -t design/design.con \
          -n $NPERM \
          -T \
          -V

echo "All randomise analyses completed!"
echo "Results are organized in the results directory:"
echo "  - FA results: results/FA/"
echo "  - MD results: results/MD/"
echo "  - DC results: results/DC/"