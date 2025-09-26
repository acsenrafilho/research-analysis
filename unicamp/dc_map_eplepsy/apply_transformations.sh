#!/bin/bash
# filepath: /home/antonio/Documentos/acsenrafilho/research-analysis/unicamp/dc_map_eplepsy/apply_transformations.sh

# Script to apply ANTs transformations to DTI maps
# This script applies existing native-to-MNI transformations to multiple DTI maps

# Check for required command-line argument
if [ $# -lt 1 ]; then
  echo "Usage: $0 <root_folder>"
  echo "Example: $0 /path/to/data"
  exit 1
fi

ROOT_DIR=$1

# Check if the root directory exists
if [ ! -d "$ROOT_DIR" ]; then
  echo "Error: Root directory not found: $ROOT_DIR"
  exit 1
fi

echo "Starting DTI map transformations from folder: $ROOT_DIR"

# Find all affine transformation files to identify subjects
echo "Finding subject transformation files..."
AFFINE_FILES=$(find $ROOT_DIR -name "*0GenericAffine.mat" | sort)

if [ -z "$AFFINE_FILES" ]; then
  echo "Error: No transformation files found. Please check the root directory."
  exit 1
fi

# Process each subject
for AFFINE_FILE in $AFFINE_FILES; do
  # Get the directory and subject ID
  DIR=$(dirname "$AFFINE_FILE")
  BASE_NAME=$(basename "$AFFINE_FILE" | sed 's/0GenericAffine.mat//')
  SUBJECT_ID=$(echo $BASE_NAME | cut -d '_' -f 1)
  
  echo "Processing subject: $SUBJECT_ID"
  
  # Find the corresponding warp file
  WARP_FILE=$(find $DIR -name "${BASE_NAME}1Warp.nii.gz" | head -n 1)
  
  if [ ! -f "$WARP_FILE" ]; then
    echo "  Warning: No warp file found for $SUBJECT_ID, skipping..."
    continue
  fi
  
  echo "  Found transformation files:"
  echo "    Affine: $(basename "$AFFINE_FILE")"
  echo "    Warp: $(basename "$WARP_FILE")"
  
  # Find DTI maps for this subject
  for MAP_TYPE in "dc_q10.nrrd" "md.nrrd" "fa.nrrd"; do
    echo "  Processing $MAP_TYPE map..."
    
    # Find the map file
    MAP_FILE=$(find $DIR -name "*$MAP_TYPE" | head -n 1)
    
    if [ ! -f "$MAP_FILE" ]; then
      echo "    Warning: No $MAP_TYPE map found for $SUBJECT_ID, skipping..."
      continue
    fi
    
    # Define output filename
    MAP_BASENAME=$(basename "$MAP_FILE")
    OUTPUT_FILE="$DIR/${MAP_BASENAME/.nrrd/_MNI.nrrd}"
    
    echo "    Transforming: $MAP_BASENAME"
    echo "    Output: $(basename "$OUTPUT_FILE")"
    
    # Apply transformation using ANTs
    antsApplyTransforms \
      -d 3 \
      -i "$MAP_FILE" \
      -o "$OUTPUT_FILE" \
      -r $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz \
      -t "$WARP_FILE" \
      -t "$AFFINE_FILE" \
      -n Linear
      
    if [ $? -eq 0 ]; then
      echo "    Transformation successful"
    else
      echo "    Error: Transformation failed"
    fi
  done
  
  echo "  Subject $SUBJECT_ID processing complete"
  echo "-------------------------------------"
done

echo "All transformations complete!"
echo "MNI-transformed DTI maps are saved with '_MNI' suffix"