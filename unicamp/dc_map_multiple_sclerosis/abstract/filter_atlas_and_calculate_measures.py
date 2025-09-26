#!/usr/bin/env python3
# filepath: /home/antonio/Documentos/acsenrafilho/research-analysis/unicamp/dc_map_multiple_sclerosis/abstract/filter_atlas_and_calculate_measures.py

import os
import sys
import numpy as np
import pandas as pd
import nibabel as nib
from glob import glob
from scipy import stats
import matplotlib.pyplot as plt
from datetime import datetime
import SimpleITK as sitk

def print_header(message):
    """Print formatted header message"""
    print("\n" + "="*80)
    print(" " + message)
    print("="*80)

def resample_to_reference(image_data, reference_data, image_file=None, reference_file=None):
    """Resample image data to match reference dimensions"""
    print(f"Shape mismatch detected! Image shape: {image_data.shape}, Reference shape: {reference_data.shape}")
    
    if image_file and reference_file:
        # Use SimpleITK for proper resampling with header information
        print(f"Resampling {os.path.basename(image_file)} to match {os.path.basename(reference_file)}")
        
        fixed_image = sitk.ReadImage(reference_file)
        moving_image = sitk.ReadImage(image_file)
        
        resample = sitk.ResampleImageFilter()
        resample.SetReferenceImage(fixed_image)
        resample.SetInterpolator(sitk.sitkLinear)
        resample.SetDefaultPixelValue(0)
        resample.SetTransform(sitk.Transform())
        
        resampled_image = resample.Execute(moving_image)
        resampled_data = sitk.GetArrayFromImage(resampled_image)
        
        # Adjust dimensions if needed (SimpleITK may swap dimensions)
        if len(resampled_data.shape) == 3 and len(reference_data.shape) == 3:
            if resampled_data.shape != reference_data.shape:
                print(f"Note: After resampling, shapes still don't match exactly. This might be due to axis ordering.")
                print(f"Resampled shape: {resampled_data.shape}, Reference shape: {reference_data.shape}")
        
        return resampled_data
    else:
        # Simple resize as fallback (less accurate)
        print("Warning: Using simple resize - results may be inaccurate. File paths not provided.")
        from scipy.ndimage import zoom
        
        factors = [float(r) / float(i) for i, r in zip(image_data.shape, reference_data.shape)]
        return zoom(image_data, factors)

def get_mean_in_mask(image_data, mask_data, min_voxels=10, image_file=None, mask_file=None):
    """Calculate mean value within mask, return NaN if too few voxels"""
    # Check if shapes match
    if image_data.shape != mask_data.shape:
        try:
            image_data = resample_to_reference(image_data, mask_data, image_file, mask_file)
        except Exception as e:
            print(f"Error resampling image: {e}")
            return np.nan
    
    if np.sum(mask_data) < min_voxels:
        return np.nan
    
    return np.mean(image_data[mask_data > 0])

def get_std_in_mask(image_data, mask_data, min_voxels=10, image_file=None, mask_file=None):
    """Calculate standard deviation within mask, return NaN if too few voxels"""
    # Check if shapes match
    if image_data.shape != mask_data.shape:
        try:
            image_data = resample_to_reference(image_data, mask_data, image_file, mask_file)
        except Exception as e:
            print(f"Error resampling image: {e}")
            return np.nan
    
    if np.sum(mask_data) < min_voxels:
        return np.nan
    
    return np.std(image_data[mask_data > 0])

def analyze_subject(subject_dir):
    """Analyze a single subject's DTI metrics"""
    print_header(f"Processing subject: {os.path.basename(subject_dir)}")
    
    # Check for required files
    required_files = {
        'lesions': 'lesions_in_dwi.nii.gz',
        'dc': 'dti_DC_fsl.nii.gz',
        'fa': 'dti_FA.nii.gz',
        'md': 'dti_MD.nii.gz',
        'atlas': 'HO_atlas_in_dwi.nii.gz'
    }
    
    # Try to find FLAIR image (might have variable name)
    flair_file = glob(os.path.join(subject_dir, "*flair_to_dwi_Warped.nii.gz"))
    if flair_file:
        required_files['flair'] = os.path.basename(flair_file[0])
    
    # Verify all files exist
    missing_files = []
    file_paths = {}
    for key, filename in required_files.items():
        file_path = os.path.join(subject_dir, filename)
        if not os.path.exists(file_path):
            missing_files.append(filename)
        else:
            file_paths[key] = file_path
    
    if missing_files:
        print(f"Warning: Missing required files for {subject_dir}: {', '.join(missing_files)}")
        return None
    
    # Load images
    images = {}
    image_objects = {}  # Store actual nibabel objects
    
    for key, file_path in file_paths.items():
        print(f"Loading {key}: {os.path.basename(file_path)}")
        img = nib.load(file_path)
        image_objects[key] = img
        images[key] = img.get_fdata()
        print(f"  Shape: {images[key].shape}")
    
    # Create results dictionary
    results = {
        'subject': os.path.basename(subject_dir),
        'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        'lesion_metrics': {},
        'atlas_metrics': {}
    }
    
    # Calculate lesion volume
    lesion_volume_voxels = np.sum(images['lesions'] > 0)
    voxel_dims = image_objects['lesions'].header.get_zooms()
    voxel_volume_mm3 = np.prod(voxel_dims)
    lesion_volume_mm3 = lesion_volume_voxels * voxel_volume_mm3
    
    # Store lesion volume metrics
    results['lesion_metrics']['volume_voxels'] = float(lesion_volume_voxels)
    results['lesion_metrics']['volume_mm3'] = float(lesion_volume_mm3)
    
    # Analysis 1: Calculate mean values in lesion areas for all metrics
    print("Calculating metrics in lesion areas...")
    for metric in ['dc', 'fa', 'md']:
        if metric in images:
            mean_value = get_mean_in_mask(images[metric], images['lesions'] > 0, 
                                         image_file=file_paths[metric], 
                                         mask_file=file_paths['lesions'])
            std_value = get_std_in_mask(images[metric], images['lesions'] > 0,
                                       image_file=file_paths[metric], 
                                       mask_file=file_paths['lesions'])
            results['lesion_metrics'][f'{metric}_mean'] = float(mean_value)
            results['lesion_metrics'][f'{metric}_std'] = float(std_value)
    
    if 'flair' in images:
        mean_value = get_mean_in_mask(images['flair'], images['lesions'] > 0,
                                     image_file=file_paths['flair'], 
                                     mask_file=file_paths['lesions'])
        std_value = get_std_in_mask(images['flair'], images['lesions'] > 0,
                                   image_file=file_paths['flair'], 
                                   mask_file=file_paths['lesions'])
        results['lesion_metrics']['flair_mean'] = float(mean_value)
        results['lesion_metrics']['flair_std'] = float(std_value)
    
    # Analysis 2: Calculate mean values in each ROI from Harvard-Oxford atlas
    print("Calculating metrics in atlas ROIs...")
    atlas_values = np.unique(images['atlas'][images['atlas'] > 0])
    
    # For each ROI in atlas
    for roi in atlas_values:
        roi_mask = images['atlas'] == roi
        roi_name = f'ROI_{int(roi)}'
        
        # For each metric
        roi_metrics = {}
        for metric in ['dc', 'fa', 'md']:
            if metric in images:
                mean_value = get_mean_in_mask(images[metric], roi_mask,
                                             image_file=file_paths[metric], 
                                             mask_file=file_paths['atlas'])
                std_value = get_std_in_mask(images[metric], roi_mask,
                                           image_file=file_paths[metric], 
                                           mask_file=file_paths['atlas'])
                roi_metrics[f'{metric}_mean'] = float(mean_value)
                roi_metrics[f'{metric}_std'] = float(std_value)
        
        if 'flair' in images:
            mean_value = get_mean_in_mask(images['flair'], roi_mask,
                                         image_file=file_paths['flair'], 
                                         mask_file=file_paths['atlas'])
            std_value = get_std_in_mask(images['flair'], roi_mask,
                                       image_file=file_paths['flair'], 
                                       mask_file=file_paths['atlas'])
            roi_metrics['flair_mean'] = float(mean_value)
            roi_metrics['flair_std'] = float(std_value)
        
        # Calculate lesion overlap with this ROI
        # First check if shapes match
        if roi_mask.shape != images['lesions'].shape:
            try:
                lesion_resampled = resample_to_reference(
                    images['lesions'], roi_mask, 
                    file_paths['lesions'], file_paths['atlas'])
                lesion_overlap = np.sum(np.logical_and(roi_mask, lesion_resampled > 0))
            except Exception as e:
                print(f"Error calculating lesion overlap: {e}")
                lesion_overlap = 0
        else:
            lesion_overlap = np.sum(np.logical_and(roi_mask, images['lesions'] > 0))
            
        roi_metrics['lesion_overlap_voxels'] = float(lesion_overlap)
        roi_metrics['lesion_overlap_mm3'] = float(lesion_overlap * voxel_volume_mm3)
        
        # Store ROI metrics
        results['atlas_metrics'][roi_name] = roi_metrics
    
    # Additional Analysis: Contrast-to-noise ratio (CNR) between lesions and normal tissue
    # For each metric, calculate CNR = |S_lesion - S_normal| / σ_normal
    print("Calculating contrast-to-noise ratios...")
    
    # Create normal tissue mask (not lesion and in brain)
    brain_mask = np.zeros_like(images['fa'])
    for metric in ['fa', 'md', 'dc']:
        if metric in images:
            brain_mask = np.logical_or(brain_mask, ~np.isnan(images[metric]))
    
    normal_tissue_mask = np.logical_and(brain_mask, images['lesions'] == 0)
    
    # Calculate CNR for each metric
    results['cnr_metrics'] = {}
    for metric in ['dc', 'fa', 'md']:
        if metric in images:
            lesion_mean = get_mean_in_mask(images[metric], images['lesions'] > 0,
                                          image_file=file_paths[metric], 
                                          mask_file=file_paths['lesions'])
            normal_mean = get_mean_in_mask(images[metric], normal_tissue_mask)
            normal_std = get_std_in_mask(images[metric], normal_tissue_mask)
            
            if not np.isnan(lesion_mean) and not np.isnan(normal_mean) and normal_std > 0:
                cnr = abs(lesion_mean - normal_mean) / normal_std
                results['cnr_metrics'][f'{metric}_cnr'] = float(cnr)
    
    if 'flair' in images:
        lesion_mean = get_mean_in_mask(images['flair'], images['lesions'] > 0,
                                      image_file=file_paths['flair'], 
                                      mask_file=file_paths['lesions'])
        normal_mean = get_mean_in_mask(images['flair'], normal_tissue_mask,
                                      image_file=file_paths['flair'])
        normal_std = get_std_in_mask(images['flair'], normal_tissue_mask,
                                    image_file=file_paths['flair'])
        
        if not np.isnan(lesion_mean) and not np.isnan(normal_mean) and normal_std > 0:
            cnr = abs(lesion_mean - normal_mean) / normal_std
            results['cnr_metrics']['flair_cnr'] = float(cnr)
    
    # Save results
    return results

def save_csv_results(results, output_dir):
    """Save analysis results to CSV files"""
    if not results:
        return
    
    subject = results['subject']
    
    # Save lesion metrics
    lesion_df = pd.DataFrame([results['lesion_metrics']])
    lesion_csv = os.path.join(output_dir, f"{subject}_lesion_metrics.csv")
    lesion_df.to_csv(lesion_csv, index=False)
    print(f"Saved lesion metrics to: {lesion_csv}")
    
    # Save CNR metrics
    cnr_df = pd.DataFrame([results['cnr_metrics']])
    cnr_csv = os.path.join(output_dir, f"{subject}_cnr_metrics.csv")
    cnr_df.to_csv(cnr_csv, index=False)
    print(f"Saved CNR metrics to: {cnr_csv}")
    
    # Save atlas metrics (reshape into table)
    atlas_data = []
    for roi_name, roi_metrics in results['atlas_metrics'].items():
        row = {'roi': roi_name}
        row.update(roi_metrics)
        atlas_data.append(row)
    
    atlas_df = pd.DataFrame(atlas_data)
    atlas_csv = os.path.join(output_dir, f"{subject}_atlas_metrics.csv")
    atlas_df.to_csv(atlas_csv, index=False)
    print(f"Saved atlas metrics to: {atlas_csv}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python filter_atlas_and_calculate_measures.py <root_folder>")
        sys.exit(1)
    
    root_dir = sys.argv[1]
    print(f"Starting analysis for data in: {root_dir}")
    
    # Find all subjects (folders containing DTI files)
    subject_dirs = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        if 'dti_DC_fsl.nii.gz' in filenames:
            subject_dirs.append(dirpath)
    
    print(f"Found {len(subject_dirs)} subject directories")
    
    # Process each subject
    for subject_dir in subject_dirs:
        results = analyze_subject(subject_dir)
        if results:
            save_csv_results(results, subject_dir)

if __name__ == "__main__":
    main()