# Initial workflow

This project starts from a minimal, reproducible workflow for T1, Tex, and raw DCE input staging.

## Phase 1: inventory and structure

- list each subject folder
- confirm presence of T1, Tex, and DCE input
- identify missing or incomplete datasets

## Phase 2: T1 and Tex preparation

- standardize file names
- stage files into data/processed/t1 and data/processed/tex
- keep a clean separation between raw and processed data

## Phase 3: DCE raw staging

- copy raw DCE folders or zip archives into a processing-ready staging directory
- keep the original files available for later quantitative map extraction
- do not yet run downstream quantitative DCE modeling in this initial stage

## Phase 4: QC and downstream analysis

- inspect alignment and image quality
- check for missing or corrupted files
- prepare the data for the next phase of registration and quantitative analysis

## Scope note

The first version intentionally excludes pCASL and keeps the project focused on T1, Tex, and DCE preparation.
