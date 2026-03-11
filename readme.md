# A joint alpha power-phase dynamic shapes visual sensitivity

The scripts stored in this repository are a key resource for:

Beale, Mattingley, & Harris (2026). A joint alpha power-phase dynamic shapes visual sensitivity. *bioRxiv*. https://www.biorxiv.org/content/10.64898/2026.02.19.706926v1.

**This code can be used to analyse data and generate figures presented in the paper.**
Empirical data can be downloaded from: https://osf.io/3rm8z/.

# Dependencies
The scripts in this repository were developed and tested using MATLAB R2025a (macOS; Macbook Air 2025) and python 3.13.7 (Linux; Ubuntu 24.04; AMD Ryzen 9 5950X, NVIDIA GeForce RTX 3070).

To run the python scripts, you will need PyMC v5.25.1, nutpie v0.15.2, arviz v0.22. GPU acceleration was used for Monte Carlo sampling with jax v0.5.3 and jaxlib v0.5.3. 
Sampling on GPU greatly speeds the total sampling time to around ~3-4 minutes per model.
An exported environment(.yml) file is included in the analysis folder.

# Instructions
Scripts for data analysis and figure generation are stored in the `analysis` folder.
Scripts controlling stimulus presentation and data collection are stored in the `stimulus` folder. 

Figures included in the manuscript are generated in the `code-for-figures.ipynb` notebook.
This notebook relies on outputs that must be created from other matlab and python scripts in the `analysis` folder (some statistical analyses are performed in the matlab scripts and replotted later in the notebook).

The detection and discrimination tasks were coded as 'contrDetectBadpt' and 'contrLocalBadpt', respectively, and can be switched in scripts that are multi-purpose. 

## Event-related potential analyses
See the file `analysis/preproc/contrast_erp.m` to generate data used for plotting the relationship between contrast and ERP.

See the MATLAB notebook `analysis/erp_analyses_{detection/discrimination}.mlx` containing descriptive plots and statistical GLM analyses of the ERP's relationship with alpha power and phase.

## Logistic regression analyses
See the notebooks `analysis/logistic_regression_analyses_{detection/discrimination}.mlx` for descriptive plots and statistical analyses of the relationship between alpha power/phase and behavioural performance.

## Power and phase binning analyses
Binning analyses and significance tests were conducted in `analysis/code-for-figures.ipynb`.

## Psychometric function modelling
See `model-fitting-1IFC.ipynb` for model fitting to the detection data and `model-fitting-2IFC.ipynb` for model fitting to the discrimination data.
Results from this are replotted in `code-for-figures.ipynb` for the final figure generation and statistical investigation.

## Additional info
Preprocessing scripts are provided in `analysis/preproc/` for filtering, epoching, and extracting alpha power and phase from the EEG data.
`analysis/preproc/eeg_pipeline_IC_FOOOF.m` can be run on the preprocessed data available in the above OSF link. This script was used to detect oscillation in the prestimulus period using the [specparam algorithm](https://github.com/fooof-tools/fooof) and the [matlab implementation](https://github.com/fooof-tools/fooof_mat).
`analysis/ecHT.m` was used to extract instantaneous power and phase from the EEG data using a custom implementation of the endpoint-corrected Hilbert transform in `analysis/bpht.m`.

Scripts for processing EEG data from raw are provided for reference (e.g. `analysis/eeg_pipeline_raw.m`). Please contact me if you would like access to the raw data.
Stimulus generation scripts are also provided for reference in the `stimulus` folder.