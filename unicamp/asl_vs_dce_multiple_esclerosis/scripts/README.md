# Scripts

This folder contains the initial working scaffold for the ASL vs DCE study.

Scope of this first implementation:
- T1
- Tex
- DCE raw input staging
- subject manifest generation
- QC-oriented dataset organization

Explicit exclusions for this stage:
- pCASL is intentionally excluded from this scaffold.

## Execution order

1. 00_build_subject_manifest.py
   - inventory subject folders and detect T1, Tex, and DCE presence
2. 01_prepare_t1_and_tex.py
   - standardize naming and stage T1/Tex files into processed folders
3. 02_prepare_dce_inputs.py
   - copy or extract DCE raw inputs into a processing-ready staging area

## Expected outputs

- data/raw/: original acquisition folders as received
- data/processed/: standardized copies for analysis
- data/processed/dce/: DCE staging and raw DICOM copies
- data/qc/: image-quality results and summary reports
- results/: plots and statistics from downstream analysis

## Notes

- DCE raw inputs are staged as-is and should remain available for later quantitative map generation.
- These scripts are intentionally simple and deterministic so the workflow can be expanded later without reworking the structure.
