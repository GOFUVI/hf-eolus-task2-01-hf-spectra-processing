
## Summary

This repository applies a reproducible, containerized workflow to process high-frequency (HF) radar spectra from INTECMAR’s VILA and PRIO stations. The primary output is LLUV files containing radial metrics derived from CODAR SeaSonde spectral data.

The applied workflow features period-specific configurations, automatic manifest generation, and scalable AWS batch processing (Lambda & S3 Batch Operations) for each station, as detailed in [1]. The underlying analysis of the HF radar spectra is carried out by the SeaSondeR R package [2]. Finally, the processed LLUV datasets are publicly available on Zenodo (PRIO [3]; VILA [4]).

Data processing is structured into six distinct periods corresponding to antenna pattern measurement intervals. These map to the period-specific directories under VILA/ and PRIO/ as follows:
- VILA1: 2011-09-30 → 2015-08-05
- VILA2: 2015-11-13 → 2018-06-21
- VILA3: 2018-06-21 → 2021-11-25
- VILA4: 2021-11-25 → 2023-05-10
- PRIO1: 2011-08-04 → 2015-04-10
- PRIO2: 2018-05-23 → 2023-11-23
See the Site Configuration Table below for full period details and additional parameters.

The setup.sh script at the repository root can be used to clone or update the SeaSondeRAWSLambdaDocker pipeline repository referenced in [1], ensuring all pipeline artifacts are available locally.

Orchestrating the applied workflow for each station and processing period, the `run_hf_dataset.sh` script at the repository root serves as the primary entry point: it sources the period-specific `configure.env`, copies the necessary pipeline artifacts from the `SeaSondeRAWSLambdaDocker` repository into the processing directory and invokes `configure_seasonder.sh` to deploy the Lambda environment, then runs `prepare_manifest.sh` to generate the CSV/JSON manifest, and finally calls `run_batch_job.sh` to launch the AWS S3 Batch Operation that executes the Lambda function for each raw data entry.

## Prerequisites

Prerequisites for this workflow are described in [1] and can also be accessed directly at:
https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker?tab=readme-ov-file#prerequisites

As noted in the prerequisites of [1], you must configure an AWS SSO profile before running the workflow.

**Configure AWS CLI with SSO**  
AWS CLI allows you to interact with AWS services from the command line. To configure it for SSO (Single Sign-On), run:

```bash
aws configure sso
```

This command will prompt you to authenticate and select an AWS SSO profile.

As detailed in [1] (see the Overview/Prerequisites section at
https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker?tab=readme-ov-file#11-overview--prerequisites), the key technologies used in this workflow are listed.

## Processing Period Directory Organization

Raw data and configuration for PRIO and VILA radar sites are organized under the repository root in `PRIO/` and `VILA/`. Each site directory contains subdirectories corresponding to processing periods, for example `PRIO1` or `VILA1`. Periods are defined by distinct antenna pattern measurements. When first created a period folder should contain a `configure.env` file with period-specific environment variables (analysis thresholds, S3 paths, IAM roles).

In order to setup and run an analysis period we start by running `setup.sh` at the repository root, which clones or updates the `SeaSondeRAWSLambdaDocker` pipeline repository into `SeaSondeRAWSLambdaDocker/`. Then the user creates a period subfolder and includes the `configure.env`file. Then the user runs `run_hf_dataset.sh` on the period folder. `run_hf_dataset.sh` bootstraps a period folder and runs the analysis by:

- Defining site- and period-specific variables using the `configure.env` file.
- Copying core pipeline artifacts (`Dockerfile`, `configure_seasonder.sh`, `runtime.R`, `prepare_manifest.sh`, `run_batch_job.sh`) into the period folder.
- Executing `configure_seasonder.sh` to create or update IAM roles, policies, ECR repository, and Lambda function (with the period’s environment variables).
- Running `prepare_manifest.sh` to build the CSV/JSON manifest for that period’s spectral files.
- Optionally invoking `run_batch_job.sh` to submit the AWS S3 Batch Operations job, which triggers the processing Lambda for each manifest entry.

### Processing Periods Configuration Table

The following table summarizes the configuration of each site during the processing periods used, based on the Antenna Pattern Measurements (APMs) conducted at each site.


  | Parameter | VILA1 | VILA2 | VILA3 | VILA4 | PRIO1 | PRIO2 |
|---|---|---|---|---|---|---|
| Site | VILA | VILA | VILA | VILA | PRIO | PRIO |
| APM Date | 2011 10 07 12 40 09 | 2015 10 19 13 19 43 | 2018 06 21 17 02 20 | 2021 11 25 11 00 54 | 2015 10 30 11 30 56 | 2021 11 25 10 49 45 |
| Processing period (start) | 2011-09-30 0730 | 2015-11-13 1830 | 2018-06-21 1702 | 2021-11-25 1100 | 2011-08-04 1200 | 2018-05-23 1030 |
| Processing period (end) | 2015-08-05 1330 | 2018-06-21 1701 | 2021-11-25 1059 | 2023-05-10 0730 | 2015-04-10 09:30 | 2023-11-23 0730 |
| Site Location (Lat Lon) | 43.1588833 -9.2108333 | 43.1588833 -9.2108333 | 43.1588833 -9.2108333 | 43.1588833 -9.2108333 | 43.5680000 -8.3140000 | 43.5680000 -8.3140000 |
| Antenna Bearing (deg true N) | 19.0 | 19.0 | 19.0 | 19.0 | 9.0 | 9.0 |
| Antenna Pattern resolution (deg) | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Transmit Freq (MHz) | 4.860000 | 4.463000 | 4.463000 | 4.463000 | 4.860000 | 4.463000 |
| Range cell resolution (km) | 5.100274 | 5.096745 | 5.096745 | 5.096745 | 5.100274 | 5.096745 |
| N Range cells | 44 | 63 | 49 | 49 | 63 | 49 |
| N Doppler Cells after interpolation | 2048 | 2048 | 2048 | 2048 | 2048 | 2048 |

### Analysis Parameters

The default spectra proccessing parameters are defined as environment variables in each processing period Dockerfile (copied from [1]), and their default values match those in [1]; they can be overridden with `configure.env` files. Key parameters:

- **SEASONDER_NSM** (Doppler smoothing): number of Doppler bins for moving-average smoothing of the first-order region. Default: 2.
- **SEASONDER_FDOWN** (Null Below Peak Power): descent level (in dB) below the Bragg peak maximum where null-search begins. Default: 10.
- **SEASONDER_NOISEFACT** (Noise factor): SNR threshold relative to background noise for retaining Doppler bins in the FOR detection. Default: 3.981072 (6 dB).
- **SEASONDER_FLIM** (Peak Power Dropoff): threshold (in dB) below the Bragg peak maximum for filtering weak bins. Default: 100 (20 dB).
- **SEASONDER_CURRMAX**: maximum allowable radial velocity (m/s); bins exceeding this are discarded. Default: 2.
- **SEASONDER_REJECT_DISTANT_BRAGG**: reject peaks whose distance from the Bragg frequency exceeds the peak width. Default: TRUE.
- **SEASONDER_REJECT_NOISE_IONOSPHERIC** & **SEASONDER_REJECT_NOISE_IONOSPHERIC_THRESHOLD**: reject ionospheric-noise-contaminated bins above the given dB threshold. Defaults: TRUE and 0 dB.
- **SEASONDER_COMPUTE_FOR**: enable computation of first-order region metrics. Default: TRUE.
- **SEASONDER_DOPPLER_INTERPOLATION**: Doppler-bin interpolation factor applied before MUSIC. Recommended ≤3×. Default: 2.
- **SEASONDER_DISCARD_LOW_SNR**: discard bins failing the three-antenna SNR test prior to MUSIC. Default: TRUE.
- **SEASONDER_SMOOTH_NOISE_LEVEL**: smooth background noise estimation before SNR filtering. Default: TRUE.
- **SEASONDER_PPMIN**: minimum power threshold (dB) on the MUSIC DOA function peak (QARTOD Test 103). Default: 5.
- **SEASONDER_PWMAX**: maximum width (degrees) of the MUSIC DOA function at 3 dB below peak (QARTOD Test 104). Default: 50.
- **SEASONDER_MUSIC_PARAMETERS**: four numeric thresholds for MUSIC solution validation:
  1. eigenvalue ratio threshold (default: 40)
  2. signal power ratio threshold (default: 20)
  3. off-diagonal power ratio threshold (default: 2)
  4. minimum separation angle between dual-solution bearings in degrees (default: 20)
- **SEASONDER_DISCARD_NO_SOLUTION**: discard bins with no MUSIC solution. Default: TRUE.

All processing periods override the default `SEASONDER_REJECT_NOISE_IONOSPHERIC_THRESHOLD` (0 dB) to 6 in their `configure.env` files.

## Workflow and Methodology

When invoked for a specific processing period, the `run_hf_dataset.sh` script implements the following sequence of steps to bootstrap
and execute the HF radar dataset processing pipeline:

1. **Load Period Configuration**  
   Source `<config_dir>/configure.env` to set all period-specific variables (AWS profile, S3 bucket and path, processing
   start/end dates, analysis thresholds, IAM role and policy names, Lambda function name, manifest and report locations).

2. **Bootstrap Pipeline Artifacts**  
   Copy core pipeline artifacts (`Dockerfile`, `configure_seasonder.sh`, `runtime.R`, `prepare_manifest.sh`,
   `run_batch_job.sh`) from the `SeaSondeRAWSLambdaDocker` repository into the period folder, ensuring a consistent
   container build context and helper scripts.

3. **Update AWS Lambda Environment (optional)**  
   If `UPDATE_CONFIG=true`, then optionally refresh the IAM role and policy (`REFRESH_ROLE_POLICY_LAMBDA=true`),
   build and push the Docker image to Amazon ECR, and create or update the container-based Lambda function
   with the period’s environment variables.

4. **Generate Manifest (optional)**  
   If `REFRESH_MANIFEST=true`, remove any existing manifest at the configured S3 key and invoke `prepare_manifest.sh`
   (with the site code filter and processing date range) to produce a CSV and JSON manifest enumerating raw spectral files.

5. **Submit Batch Processing Job (optional)**  
   If `RUN_JOBS=true`, execute `run_batch_job.sh` to launch an Amazon S3 Batch Operations (`LambdaInvoke`) job,
   which runs the containerized Lambda for each manifest entry. The script captures the batch job ID, manages confirmation,
   and configures report prefixes for tracking.

By encapsulating these steps, `run_hf_dataset.sh` provides a single-entry-point, manifest-driven workflow that automates
reproducible, period-specific deployments and scalable parallel execution of the SeaSonde HF spectral analysis.

## Processing Statistics

This report summarizes the processing statistics from each subfolder’s `processing_report.md` file.

| Subfolder | Files in manifest | Files processed successfully | Files with errors | Total files processed | Error % of manifest |
| --- | --- | --- | --- | --- | --- |
| PRIO1 | 47655 | 47019 | 636 | 47655 | 1.33% |
| PRIO2 | 64868 | 63851 | 1017 | 64868 | 1.57% |
| VILA1 | 65324 | 64868 | 456 | 65324 | 0.70% |
| VILA2 | 14573 | 10537 | 4036 | 14573 | 27.70% |
| VILA3 | 54843 | 54593 | 250 | 54843 | 0.46% |
| VILA4 | 18152 | 18152 | 0 | 18152 | 0.00% |

| **Total** | 265415 | 259020 | 6395 | 265415 | 2.41% |

## Errors by type per subfolder

### PRIO1

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 629 | 1.32% |
| 2 | Can't rename columns that don't exist | 7 | 0.01% |

### PRIO2

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 1004 | 1.55% |
| 2 | Can't rename columns that don't exist | 8 | 0.01% |
| seasonder_find_spectra_file_type | Spectra file type not recognized. | 5 | 0.00% |

### VILA1

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 433 | 0.66% |
| 2 | File has size 0 | 17 | 0.03% |
| 3 | Invalid file size for nCsKind 2 (file size mismatch) | 5 | 0.01% |
| 4 | Can't rename columns that don't exist | 1 | 0.00% |

### VILA2

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 4026 | 27.63% |
| 2 | Can't rename columns that don't exist | 4 | 0.03% |
| 3 | 'vec' must be sorted non-decreasingly and not contain NAs | 4 | 0.03% |
| 4 | File has size 0 | 2 | 0.01% |

### VILA3

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 250 | 0.46% |


## References

1. Herrera Cortijo, J. L., Fernández-Baladrón, A., & Varela Benvenuto, R. (2025). *Batch Processing of SeaSonde HF-Radar Spectra Files on AWS with SeaSondeR R Package* (v1.0.0). Zenodo. https://doi.org/10.5281/zenodo.16453046
2. Herrera Cortijo, J. L., Fernández-Baladrón, A., & Varela Benvenuto, R. (2025). *SeaSondeR: Radial Metrics from SeaSonde HF-Radar Data* (v0.2.9). Zenodo. https://doi.org/10.5281/zenodo.16455051
3. **PRIO LLUV dataset**: https://doi.org/10.5281/zenodo.16528653
4. **VILA LLUV dataset**: https://doi.org/10.5281/zenodo.16458694
