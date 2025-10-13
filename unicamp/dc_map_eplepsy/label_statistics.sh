#!/bin/bash
# filepath: /home/antonio/Documentos/acsenrafilho/research-analysis/unicamp/dc_map_eplepsy/label_statistics.sh

# 6. Extração de valores médios nas ROIs do hipocampo
#    - Utilizar fslstats para extrair os valores médios dos mapas DTI e DC nas ROIs segmentadas do hipocampo
#  - Comandos:

# Variáveis de entrada
MAP_FILE_SUFFIX=$1  # Pode ser: dti_FA_to_t1, dti_MD_to_t1, dti_DC_to_t1, etc
ROOT_FOLDER=$2
OUTPUT_CSV="${ROOT_FOLDER}/roi_statistics_${MAP_FILE_SUFFIX}.csv"

echo "Searching for files matching: *${MAP_FILE_SUFFIX}*"
echo "In folder: $ROOT_FOLDER"

# Debug: mostrar quais arquivos foram encontrados
FOUND_FILES=$(find "$ROOT_FOLDER" -type f -name "*${MAP_FILE_SUFFIX}*Warped.nii.gz")
echo "Files found:"
echo "$FOUND_FILES"
echo ""

if [ -z "$FOUND_FILES" ]; then
    echo "ERROR: No files found matching pattern *${MAP_FILE_SUFFIX}*Warped.nii.gz"
    echo "Please check:"
    echo "  1. The MAP_FILE_SUFFIX is correct: '$MAP_FILE_SUFFIX'"
    echo "  2. The ROOT_FOLDER path: '$ROOT_FOLDER'"
    echo "  3. The files exist and have the correct naming pattern"
    exit 1
fi

# Criar cabeçalho do CSV se não existir
if [ ! -f "$OUTPUT_CSV" ]; then
    echo "subject,roi_name,roi_value,mean,std,volume_voxels,volume_mm3" > "$OUTPUT_CSV"
    echo "Created CSV file: $OUTPUT_CSV"
fi

# Definir as estruturas do FSL FIRST e seus valores de label
declare -A ROI_NAMES=(
    [10]="Left-Thalamus"
    [11]="Left-Caudate"
    [12]="Left-Putamen"
    [13]="Left-Pallidum"
    [16]="Brain-Stem"
    [17]="Left-Hippocampus"
    [18]="Left-Amygdala"
    [26]="Left-Accumbens"
    [49]="Right-Thalamus"
    [50]="Right-Caudate"
    [51]="Right-Putamen"
    [52]="Right-Pallidum"
    [53]="Right-Hippocampus"
    [54]="Right-Amygdala"
    [58]="Right-Accumbens"
)

# Loop para processar cada sujeito
for MAP_FILE_FULL in `find "$ROOT_FOLDER" -type f -name "*${MAP_FILE_SUFFIX}*Warped.nii.gz"`; do
    SUBJECT_DIR=$(dirname "$MAP_FILE_FULL")
    SUBJECT_NAME=$(basename "$MAP_FILE_FULL")
    
    echo "Processing subject: ${SUBJECT_NAME}"
    echo "  Map file: $(basename $MAP_FILE_FULL)"
    
    # Encontrar o arquivo de segmentação FIRST correspondente
    FIRST_SEG=$(find "$SUBJECT_DIR" -name "*_t1_brain_all_fast_firstseg.nii.gz" | head -n 1)
    
    if [ -z "$FIRST_SEG" ] || [ ! -f "$FIRST_SEG" ]; then
        echo "  Warning: FIRST segmentation not found for ${SUBJECT_NAME}, skipping..."
        echo "  Looking for: ${SUBJECT_DIR}/*_t1_brain_all_fast_firstseg.nii.gz"
        continue
    fi
    
    echo "  Segmentation: $(basename $FIRST_SEG)"
    
    # Obter informações de voxel size para calcular volume em mm³
    VOXEL_INFO=$(fslinfo $MAP_FILE_FULL | grep pixdim)
    PIXDIM1=$(echo $VOXEL_INFO | awk '{print $2}')
    PIXDIM2=$(echo $VOXEL_INFO | awk '{print $4}')
    PIXDIM3=$(echo $VOXEL_INFO | awk '{print $6}')
    VOXEL_VOLUME=$(echo "$PIXDIM1 * $PIXDIM2 * $PIXDIM3" | bc -l)
    
    # Loop para cada ROI
    for ROI_VALUE in "${!ROI_NAMES[@]}"; do
        ROI_NAME="${ROI_NAMES[$ROI_VALUE]}"
        
        # Criar máscara binária para esta ROI
        TEMP_MASK="${SUBJECT_DIR}/temp_roi_${ROI_VALUE}_mask.nii.gz"
        fslmaths $FIRST_SEG -thr $ROI_VALUE -uthr $ROI_VALUE -bin $TEMP_MASK 2>/dev/null
        
        # Verificar se a ROI existe (tem voxels)
        NUM_VOXELS=$(fslstats $TEMP_MASK -V | awk '{print $1}')
        
        if [ "$NUM_VOXELS" -eq 0 ]; then
            echo "  ${ROI_NAME}: not found"
            rm -f $TEMP_MASK
            continue
        fi
        
        # Calcular estatísticas usando fslstats
        MEAN=$(fslstats $MAP_FILE_FULL -k $TEMP_MASK -M)
        STD=$(fslstats $MAP_FILE_FULL -k $TEMP_MASK -S)
        VOLUME_MM3=$(echo "$NUM_VOXELS * $VOXEL_VOLUME" | bc -l)
        
        # Adicionar ao CSV
        echo "${SUBJECT_NAME},${ROI_NAME},${ROI_VALUE},${MEAN},${STD},${NUM_VOXELS},${VOLUME_MM3}" >> "$OUTPUT_CSV"
        
        echo "  ${ROI_NAME}: mean=${MEAN}, std=${STD}, volume=${NUM_VOXELS} voxels (${VOLUME_MM3} mm³)"
        
        # Remover máscara temporária
        rm -f $TEMP_MASK
    done
    
    echo "  Subject ${SUBJECT_NAME} complete"
    echo "-----------------------------------"
done

echo ""
echo "All statistics saved to: $OUTPUT_CSV"
echo "Done!"