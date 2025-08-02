# Project HF-EOLUS. Task 2. Obtaining Radial Metrics from INTECMAR's VILA and PRIO Stations' Spectra.

## Table of Contents
- [Summary](#summary)
- [Prerequisites](#prerequisites)
- [Processing Period Directory Organization](#processing-period-directory-organization)
- [Processing Periods Configuration](#processing-periods-configuration-table)
- [Analysis Parameters](#analysis-parameters)
- [Workflow and Methodology](#workflow-and-methodology)
- [Processing Statistics](#processing-statistics)
- [Acknowledgements](#acknowledgements)
- [Disclaimer](#disclaimer)
- [References](#references)


## Summary

This repository is part of the HF-EOLUS project and constitutes the first step towards its Task 2: obtaining wind fields from oceanic HF-radar data. Task 2 aims to use, evaluate, and develop the extraction of wind data from HF-radar data. In HF-EOLUS methodology, the first step in wind extraction is obtaining radial metrics from the spectra collected by HF-Radar stations. This repository applies a reproducible, containerized workflow to process high-frequency (HF) radar spectra from INTECMAR’s VILA and PRIO HF-Radar stations located on the Galician shelf (NW-Spain). The primary output is LLUV files containing radial metrics derived from CODAR SeaSonde spectral data.

The applied workflow features period-specific configurations, automatic manifest generation, and scalable AWS batch processing (Lambda & S3 Batch Operations) for each station, as detailed in [1](#ref1). The underlying analysis of the HF radar spectra is carried out by the SeaSondeR R package [2](#ref2). Finally, the processed LLUV datasets are publicly available on Zenodo (PRIO [3](#ref3); VILA [4](#ref4)).

Data processing is structured into six distinct periods corresponding to antenna pattern measurement intervals. These map to the period-specific directories under VILA/ and PRIO/ as follows:
- VILA1: 2011-09-30 → 2015-08-05
- VILA2: 2015-11-13 → 2018-06-21
- VILA3: 2018-06-21 → 2021-11-25
- VILA4: 2021-11-25 → 2023-05-10
- PRIO1: 2011-08-04 → 2015-04-10
- PRIO2: 2018-05-23 → 2023-11-23

See the Site Configuration Table below for full period details and additional parameters.

The `setup.sh` script at the repository root can be used to clone or update the SeaSondeRAWSLambdaDocker pipeline repository referenced in [1](#ref1), ensuring all pipeline artifacts are available locally.

Orchestrating the applied workflow for each station and processing period, the `run_hf_dataset.sh` script at the repository root serves as the primary entry point: it sources the period-specific `configure.env`, copies the necessary pipeline artifacts from the `SeaSondeRAWSLambdaDocker` repository into the processing directory and invokes `configure_seasonder.sh` to deploy the Lambda environment, then runs `prepare_manifest.sh` to generate the CSV/JSON manifest, and finally calls `run_batch_job.sh` to launch the AWS S3 Batch Operation that executes the Lambda function for each raw data entry.

## Prerequisites

Prerequisites for this workflow are described in [1](#ref1) and can also be accessed directly at:
https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker?tab=readme-ov-file#prerequisites

As noted in the prerequisites of [1](#ref1), you must configure an AWS SSO profile before running the workflow.

**Configure AWS CLI with SSO**  
AWS CLI allows you to interact with AWS services from the command line. To configure it for SSO (Single Sign-On), run:

```bash
aws configure sso
```

This command will prompt you to authenticate and select an AWS SSO profile.

As detailed in [1](#ref1) (see the Overview/Prerequisites section at
https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker?tab=readme-ov-file#11-overview--prerequisites), the key technologies used in this workflow are listed.

## Processing Period Directory Organization

Raw data and configuration for PRIO and VILA radar sites are organized under the repository root in `PRIO/` and `VILA/`. Each site directory contains subdirectories corresponding to processing periods, for example `PRIO1` or `VILA1`. Periods are defined by distinct antenna pattern measurements. When first created a period folder should contain a `configure.env` file with period-specific environment variables (analysis thresholds, S3 paths, IAM roles).

```
repo-root/
├── VILA/
│   ├── VILA1/
│   │   └── configure.env
│   ├── VILA2/
│   └── …
└── PRIO/
    ├── PRIO1/
    └── PRIO2/
```

In order to set up and run an analysis period, we start by running `setup.sh` at the repository root, which clones or updates the `SeaSondeRAWSLambdaDocker` pipeline repository into `SeaSondeRAWSLambdaDocker/`. Then the user creates a period subfolder and includes the `configure.env` file. Then the user runs `run_hf_dataset.sh` on the period folder. `run_hf_dataset.sh` bootstraps a period folder and runs the analysis by:

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
| APM Date | 2011-10-07 12:40:09Z | 2015-10-19 13:19:43Z | 2018-06-21 17:02:20Z | 2021-11-25 11:00:54Z | 2015-10-30 11:30:56Z | 2021-11-25 10:49:45Z |
| Processing period (start) | 2011-09-30 07:30Z | 2015-11-13 18:30Z | 2018-06-21 17:02Z | 2021-11-25 11:00Z | 2011-08-04 12:00Z | 2018-05-23 10:30Z |
| Processing period (end)   | 2015-08-05 13:30Z | 2018-06-21 17:01Z | 2021-11-25 10:59Z | 2023-05-10 07:30Z | 2015-04-10 09:30Z | 2023-11-23 07:30Z |
| Site Location (Lat Lon) | 43.1588833 -9.2108333 | 43.1588833 -9.2108333 | 43.1588833 -9.2108333 | 43.1588833 -9.2108333 | 43.5680000 -8.3140000 | 43.5680000 -8.3140000 |
| Antenna Bearing (deg true N) | 19.0 | 19.0 | 19.0 | 19.0 | 9.0 | 9.0 |
| Antenna Pattern resolution (deg) | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Transmit Freq (MHz) | 4.860000 | 4.463000 | 4.463000 | 4.463000 | 4.860000 | 4.463000 |
| Range cell resolution (km) | 5.100274 | 5.096745 | 5.096745 | 5.096745 | 5.100274 | 5.096745 |
| N Range cells | 44 | 63 | 49 | 49 | 63 | 49 |
| N Doppler Cells after interpolation | 2,048 | 2,048 | 2,048 | 2,048 | 2,048 | 2,048 |

### Analysis Parameters

The default spectra processing parameters are defined as environment variables in each processing period Dockerfile (copied from [1](#ref1)), and their default values match those in [1](#ref1); they can be overridden with `configure.env` files. Key parameters:

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
   If `UPDATE_CONFIG=true`, then optionally refresh the IAM role and policy (`REFRESH_ROLE_POLICY_LAMBDA=true`), and run 
   `configure_seasonder.sh` to build and push the Docker image to Amazon ECR, and create or update the container-based Lambda function
   with the period’s environment variables. For more details on this step, see [1](#ref1).

4. **Generate Manifest (optional)**  
   If `REFRESH_MANIFEST=true`, remove any existing manifest at the configured S3 key and invoke `prepare_manifest.sh`
   (with the site code filter and processing date range) to produce a CSV and JSON manifest enumerating raw spectral files. For more details on this step, see [1](#ref1).

5. **Submit Batch Processing Job (optional)**  
   If `RUN_JOBS=true`, execute `run_batch_job.sh` to launch an Amazon S3 Batch Operations (`LambdaInvoke`) job,
   which runs the containerized Lambda for each manifest entry. The script captures the batch job ID, manages confirmation,
   and configures report prefixes for tracking. For more details on this step, see [1](#ref1)

By encapsulating these steps, `run_hf_dataset.sh` provides a single-entry-point, manifest-driven workflow that automates
reproducible, period-specific deployments and scalable parallel execution of the SeaSonde HF spectral analysis.

## Processing Statistics

This report summarizes the processing statistics from each processing period.

| Subfolder | Files in manifest | Files processed successfully | Files with errors | Total files processed | Error % of manifest |
| --- | --- | --- | --- | --- | --- |
| PRIO1 | 47,655 | 47,019 | 636 | 47,655 | 1.33% |
| PRIO2 | 64,868 | 63,851 | 1,017 | 64,868 | 1.57% |
| VILA1 | 65,324 | 64,868 | 456 | 65,324 | 0.70% |
| VILA2 | 14,573 | 10,537 | 4,036 | 14,573 | 27.70% |
| VILA3 | 54,843 | 54,593 | 250 | 54,843 | 0.46% |
| VILA4 | 18,152 | 18,152 | 0 | 18,152 | 0.00% |
| **Total** | 265,415 | 259,020 | 6,395 | 265,415 | 2.41% |

### Errors by type per subfolder

Below is a breakdown of error types and their occurrence counts for each processing subfolder. All error files were examined, and in every case the issues were traced to data corruption or failures in the spectra acquisition system.

#### PRIO1

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 629 | 1.32% |
| 2 | Can't rename columns that don't exist | 7 | 0.01% |

#### PRIO2

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 1,004 | 1.55% |
| 2 | Can't rename columns that don't exist | 8 | 0.01% |
| seasonder_find_spectra_file_type | Spectra file type not recognized. | 5 | 0.00% |

#### VILA1

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 433 | 0.66% |
| 2 | File has size 0 | 17 | 0.03% |
| 3 | Invalid file size for nCsKind 2 (file size mismatch) | 5 | 0.01% |
| 4 | Can't rename columns that don't exist | 1 | 0.00% |

#### VILA2

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 4,026 | 27.63% |
| 2 | Can't rename columns that don't exist | 4 | 0.03% |
| 3 | 'vec' must be sorted non-decreasingly and not contain NAs | 4 | 0.03% |
| 4 | File has size 0 | 2 | 0.01% |

#### VILA3

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |
| 1 | No valid FOR data found. Please run seasonder_computeFORs first. | 250 | 0.46% |


## Acknowledgements

This work has been funded by the HF-EOLUS project (TED2021-129551B-I00), financed by MICIU/AEI /10.13039/501100011033 and by the European Union NextGenerationEU/PRTR - BDNS 598843 - Component 17 - Investment I3. Members of the Marine Research Centre (CIM) of the University of Vigo have participated in the development of this repository.

Spectra from INTECMAR's VILA and PRIO HF-Radar stations, between 2011-09-30 and 2023-11-23 have been transferred free of charge by the Observatorio
Costeiro da Xunta de Galicia (<https://www.observatoriocosteiro.gal>) for their use. This Observatory is not responsible for the use of these data nor is it linked to the conclusions drawn with them. The Costeiro da Xunta de Galicia Observatory is part of the RAIA Observatory (<http://www.marnaraia.org>). We want to thank Dr. Pedro Montero from the INTECMAR for his help providing the spectra.

## Disclaimer
This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, or in connection with the software or the use or other dealings in the software.

## References

<ol>
<li id="ref1">Herrera Cortijo, J. L., Fernández-Baladrón, A., Rosón, G., Gil Coto, M., Dubert, J., & Varela Benvenuto, R. (2025). Complete Batch Processing of SeaSonde HF-Radar Spectra Files on AWS with SeaSondeR R Package (v1.0.0). Zenodo. https://doi.org/10.5281/zenodo.16453046</li>
<li id="ref2">Herrera Cortijo, J. L., Fernández-Baladrón, A., Rosón, G., Gil Coto, M., Dubert, J., & Varela Benvenuto, R. (2025). SeaSondeR: Radial Metrics from SeaSonde HF-Radar Data (v0.2.9). Zenodo. https://doi.org/10.5281/zenodo.16455051</li>
<li id="ref3">Herrera Cortijo, J. L., Fernández-Baladrón, A., Rosón, G., Gil Coto, M., Dubert, J., Montero, P., & Varela Benvenuto, R. (2025). PRIO LLUV Radial Metrics Dataset Computed Using SeaSondeR R Package [Data set]. Zenodo. https://doi.org/10.5281/zenodo.16528653</li>
<li id="ref4">Herrera Cortijo, J. L., Fernández-Baladrón, A., Rosón, G., Gil Coto, M., Dubert, J., Montero, P., & Varela Benvenuto, R. (2025). VILA LLUV Radial Metrics Dataset Computed Using SeaSondeR R Package [Data set]. Zenodo. https://doi.org/10.5281/zenodo.16458694</li>
</ol>

---
<p align="center">
  <img src="logos/EN_Funded_by_the_European_Union_RGB_POS.png" alt="Funded by the European Union" height="80"/>
  <img src="logos/LOGO%20COLOR.png" alt="Logo Color" height="80"/>
  <img src="logos/logo_aei.png" alt="AEI Logo" height="80"/>
  <img src="logos/MCIU_header.svg" alt="MCIU Header" height="80"/>
  <img src ="logos/Logotipo_CIM_original.png" alt="CIM logo" height="80"/>
  <img src ="logos/logo_intecmar.jpg" alt="CIM logo" height="80"/>
  <img src ="logos/logo_raia_con_claim.svg" alt="CIM logo" height="80"/>
  <a href="https://cim.uvigo.gal"><img src ="logos/xunta_2021.svg" alt="CIM logo" height="80"/></a>

  
</p>
