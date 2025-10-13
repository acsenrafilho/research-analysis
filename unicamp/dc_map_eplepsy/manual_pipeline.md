# Pipeline manual para executar os passos sem depender de ajuste de script shell

## Estudo: DC-MAP Epilepsy (hipocampal sclerosis)
No caso, o foco é entender a ROI do hipocampo, que é a estrutura afetada pela esclerose hipocampal em pacientes com epilepsia temporal. Pode ser feito um estudo de caso-controle, comparando pacientes com epilepsia temporal e controles saudáveis, ou mesmo ipsi-lateral vs contra-lateral no mesmo paciente.

### Passo 1: Preparação do ambiente
Softwares necessários:
- FSL (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation)
- TORTOISE (https://tortoise.nibib.nih.gov/tortoise/)
- 3D Slicer (https://www.slicer.org/)
- Diffusion Complexity (ITK)

### Pipeline:

DICA: Importante fazer o loop for com as variáveis que estão nos comandos abaixo. 

1. Pré-processamento DWI com TORTOISE
   - Correção de Gibbs, movimento inter-volume e correntes de Eddy
 - Executar para todos os arquivos DWI (.nii) na pasta raiz do estudo

Trecho do script para referência:

```bash
TORTOISEProcess --up_data ${DWI_FILE} --denoising for_final --denoising_kernel_size 5
```

1. Reconstrução dos mapas DTI e DC
   - Criação de máscara cerebral com FSL BET
   - Aplicar FDTfit FSL para calcular os mapas DTI (FA e MD)
   - Converter DWI para NRRD com 3D Slicer
   - Aplicar mapa DC com Diffusion Complexity ITK
 - Comandos:

```bash
SUBJECT_DIR=$(dirname "$DWI_FILE")
SUBJECT_NAME=$(basename "${DWI_FILE%.*}")
bet "$DWI_FILE" "${SUBJECT_DIR}/${SUBJECT_NAME}_dwi_brain" -m -n

dtifit --data=${DWI_FILE} \
    --out=${SUBJECT_DIR}/${SUBJECT_NAME}_dti \
    --mask=${SUBJECT_DIR}/${SUBJECT_NAME}_dwi_brain_mask.nii.gz \
    --bvecs=${SUBJECT_DIR}/`ls ${SUBJECT_DIR} | grep ${SUBJECT_NAME} | grep .bvec` \
    --bvals=${SUBJECT_DIR}/`ls ${SUBJECT_DIR} | grep ${SUBJECT_NAME} | grep .bval`
```

3. Reconstrução do mapa DC
   - Aplicar o executável DiffusionComplexity
   - Pegar a listagem de DWI_FILE que seja o arquivo corrigido pelo TORTOISE (ex: com TORTOISE no nome)
```bash
CURRENT_DIR=$(pwd)
SUBJECT_DIR=$(dirname "$DWI_FILE")
SUBJECT_NAME=$(basename "${DWI_FILE%.*}")
SLICER_FOLDER="/home/antonio/Documentos/Slicer-5.9.0-2025-09-18-linux-amd64"
DC_FOLDER="/home/antonio/Documentos/csim/ITK-build/DiffusionComplexityMapping"

# Garante que SUBJECT_DIR seja caminho absoluto
SUBJECT_DIR=$(realpath "$SUBJECT_DIR")

cd "$SLICER_FOLDER"
./Slicer --launch DWIConvert --conversionMode FSLToNrrd \
--outputVolume ${SUBJECT_DIR}/${SUBJECT_NAME}_dwi.nrrd  \
--fslNIFTIFile ${SUBJECT_DIR}/${DWI_FILE} \
--inputBValues ${SUBJECT_DIR}/`ls ${SUBJECT_DIR} | grep ${SUBJECT_NAME} | grep TORTOISE | grep .bval` \
--inputBVectors ${SUBJECT_DIR}/`ls ${SUBJECT_DIR} | grep ${SUBJECT_NAME} | grep TORTOISE | grep .bvec` \
--allowLossyConversion

cd "$CURRENT_DIR"

cd "$SLICER_FOLDER"
./Slicer --launch DiffusionWeightedVolumeMasking --removeislands \
${SUBJECT_DIR}/${SUBJECT_NAME}_dwi.nrrd \
${SUBJECT_DIR}/${SUBJECT_NAME}_dwi_baseline.nrrd \
${SUBJECT_DIR}/${SUBJECT_NAME}_dwi_brain_mask.nrrd

cd "$CURRENT_DIR"

echo "Calculate Diffusion Complexity (DC) maps"
cd "$DC_FOLDER"
./DiffusionComplexityMapping \
${SUBJECT_DIR}/${SUBJECT_NAME}_dwi.nrrd \
${SUBJECT_DIR}/${SUBJECT_NAME}_dwi_brain_mask.nrrd \
${SUBJECT_DIR}/${SUBJECT_NAME}_dti_DC.nrrd \
1.0

cd "$CURRENT_DIR"
````


4. Segmentação T1
   - Utilizar FSL para fazer brain_mask em T1
   - Fazer segmentação com FAST
- Fazer for loop para imagens T1_FILE (.nii) na pasta raiz do estudo

```bash
SUBJECT_DIR=$(dirname "$T1_FILE")
SUBJECT_NAME=$(basename "${T1_FILE%.*}")
echo "Brain extraction for ${T1_FILE}"
bet ${T1_FILE} ${SUBJECT_DIR}/${SUBJECT_NAME}_t1_brain -m

echo "Tissue segmentation for ${T1_FILE}"
run_first_all -i ${SUBJECT_DIR}/${SUBJECT_NAME}_t1_brain.nii.gz -o ${SUBJECT_DIR}/${SUBJECT_NAME}_t1_brain -b
```

5. Registro dos mapas DTI e DC para T1
   - Utilizar FLIRT para registro linear (intra-subject)
 - DICA: Fazer for loop para os arquivos MAP_FILE (FA, MD, DC) na pasta raiz do estudo

```bash
SUBJECT_DIR=$(dirname "$MAP_FILE")
SUBJECT_NAME=$(basename "${MAP_FILE%.*}")

echo "Registering ${MAP_FILE} to T1"
antsRegistrationSyNQuick.sh \
  -d 3 \
  -m ${SUBJECT_DIR}/${MAP_FILE} \
  -f ${SUBJECT_DIR}/${MAP_FILE:0:15}*_t1_brain.nii.gz \
  -o ${SUBJECT_DIR}/${SUBJECT_NAME}_to_t1_ \
  -t s \
  -n 8
```

1. Extração de valores médios nas ROIs do hipocampo
   - Utilizar fslstats para extrair os valores médios dos mapas DTI e DC nas ROIs segmentadas do hipocampo
 - Nesta etapa será executado o arquivo: `label_statistics.sh`