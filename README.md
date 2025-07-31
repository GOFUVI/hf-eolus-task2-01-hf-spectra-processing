
## Summary

This repository implements a reproducible, containerized workflow to process high-frequency (HF) radar spectra from INTECMAR’s VILA and PRIO stations. The primary output is LLUV files containing radial metrics derived from SeaSonde spectral data. The pipeline supports processing period-specific configurations, automatic manifest generation, and scalable AWS batch processing (Lambda & S3 Batch Operations), ensuring consistent, traceable analyses with integrated error detection and reporting.

Processed LLUV datasets are publicly available on Zenodo (PRIO [1]; VILA [2]). The underlying analysis is carried out by the SeaSondeR R package [3], and the AWS-based batch workflow applied to each station is detailed in [4].

## Prerequisites

Prerequisites for this workflow are described in [4] and can also be accessed directly at:
https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker?tab=readme-ov-file#prerequisites

As noted in the prerequisites of [4], you must configure an AWS SSO profile before running the workflow.

**Configure AWS CLI with SSO**  
AWS CLI allows you to interact with AWS services from the command line. To configure it for SSO (Single Sign-On), run:

```bash
aws configure sso
```

This command will prompt you to authenticate and select an AWS SSO profile.

As detailed in [4] (see the Overview/Prerequisites section at
https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker?tab=readme-ov-file#11-overview--prerequisites), the key technologies used in this workflow are listed.

## Analysis Parameters

The core spectral analysis is driven by environment variables defined in each processing period Dockerfile. Key parameters:

- **SEASONDER_PATTERN_PATH**: S3 URI or local path to the antenna pattern file. Default: "" (must be set in `configure.env`).
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
- **SEASONDER_RDATA_OUTPUT**: enable or disable saving intermediate .RData objects. Default: FALSE.
- **SEASONDER_S3_OUTPUT_PATH**: S3 URI for storing processed LLUV outputs. Default: "" (must be set in `configure.env`).

Overrides and processing period-specific parameters (e.g., start/end dates, S3 bucket, IAM roles) are set in `configure.env` files.

## Workflow and Methodology

The pipeline comprises eight key stages:

1. **Processing Period Directory Organization**  
   Each processing period directory corresponds to a specific processing period during which a particular antenna pattern was applied to the data. This modular layout isolates processing period data, configuration scripts, and results by processing period, enabling independent testing and parallel execution.
   AWS Service(s): Amazon S3 stores and versions raw spectral files organized by processing period prefixes.

  
2. **Environment Configuration and Containerization**  
   Within each processing period directory, a Dockerfile and associated setup scripts define a self-contained runtime environment. These artifacts install and configure all necessary software dependencies, ensuring that analyses can be reproduced consistently across different host systems.
   AWS Service(s): Amazon ECR hosts the built Docker images; AWS IAM creates roles and policies for Lambda execution and S3 access.

2. **Manifest Generation**
   A manifest preparation script scans the processing period directory to catalog input files along with their metadata (e.g., file paths, checksums, timestamps). The outcome is a standardized CSV manifest and a corresponding JSON manifest, which together serve as the definitive input inventory for downstream processing.
   AWS Service(s): AWS S3API (via AWS CLI) `list-objects-v2` lists files; `jq` formats `Bucket,Key` entries. The manifest CSV is optionally uploaded back to S3 for versioned inputs.

3. **Batch Job Orchestration**
   A generic runner script (`run_hf_dataset.sh`) loads processing period-specific configuration from `configure.env` and invokes the batch submission script (`run_batch_job.sh`). The `run_batch_job.sh` script uses Amazon S3 Batch Operations (S3Control) to invoke the containerized Lambda function for each manifest entry, tracking job identifiers and logging execution details. This approach enables fault isolation, scalable parallel execution, and fine-grained performance monitoring.
   AWS Service(s): Amazon S3 Batch Operations (S3Control) submits a `LambdaInvoke` job; AWS STS retrieves account identity; AWS IAM defines batch roles/policies.

4. **Runtime Data Processing**
   Inside each container, a scripted analysis routine performs data cleaning, spectral analysis, and the derivation of geophysical parameters. Execution parameters—such as analysis thresholds and output configurations—are supplied via environment variables and manifest entries, allowing flexible customization of processing behavior.
   AWS Service(s): AWS Lambda runs the container per manifest entry; AWS CLI within Lambda copies input files and antenna patterns from S3 and uploads processed outputs back to S3 (Radial_Metrics, CS_Objects).

6. **Error Detection and Classification**  
   After processing, outputs are validated to detect common issues (e.g., missing data segments, file size mismatches, column inconsistencies). Detected errors are categorized by type and per-job reports are generated by the local script `generate_report.py` (wrapper `generate_report.sh`), producing a Markdown report (`processing_report.md`) and CSV files (`error_type_<n>_<slug>.csv`). This facilitates rapid diagnosis and reprocessing decisions.
   AWS Service(s): The S3 Batch Operations job report (CSV) is stored in S3; local scripts download and parse this report for error classification.

7. **Summary Report Generation**  
   After all batch jobs complete, processing period-level error summaries and per-job processing reports can be consolidated. For example, a dedicated analysis script scans all Type 1 error CSV files (`error_type_1_*.csv`) and corresponding manifest entries across processing periods to produce a consolidated Markdown report (`type1_error_report.md`) summarizing monthly error rates and statistical significance. Processing reports (`processing_report.md`) and other error-type CSVs can likewise be aggregated or analyzed using custom scripts as needed.
   AWS Service(s): Aggregation and statistical analysis are performed locally using Python (with SciPy); no additional AWS calls are required for summary generation.

8. **Scalability and Extensibility**  
   The manifest-driven, containerized design enables straightforward extension to new datasets. Adding a new processing period involves creating a new subdirectory with raw data and invoking the standard sequence of workflow scripts. This architecture supports horizontal scaling across multiple processing periods and facilitates the integration of additional analytical modules.
   AWS Service(s): Amazon S3, Amazon ECR, AWS Lambda, and Amazon S3 Batch Operations combine to enable horizontally scaled, reproducible workflows.

9. **Site Configuration Table Generation**  
   The script `generate_hf_processing_table.sh` iterates over the processing period directories under VILA/* and PRIO/*, sourcing each `configure.env`, downloading antenna pattern files via AWS CLI, parsing metadata from RUV files, and aggregating these values into a Markdown table. The output is saved to `sites_config.md` for inclusion in subsequent analyses and reporting.
   AWS Service(s): AWS CLI for S3 object retrieval.

## Site Configuration Table

The following table summarizes the configuration of each site during the processing periods used, based on the Antenna Pattern Measurements (APMs) conducted at each site. It is automatically generated by the script `generate_hf_processing_table.sh` and saved to `sites_config.md`.


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


---

Project HF-EOLUS. Task 2. Step 01. Configuration of VILA and PRIO Spectra processing using SeaSondeR.

# HF Spectra Processing

The `01-HF_processing` directory implements a comprehensive, reproducible, and containerized pipeline for processing high-frequency radar (HF) spectral datasets. This section documents the end-to-end methodology, configuration parameters, AWS service integration, and auxiliary scripts required to execute the workflow without relying on external documentation.

## AWS Services Utilization

Processing leverages AWS to enable scalable, serverless execution:
- **Amazon S3**: Versioned storage for raw `.cs`/`.cs4` spectral files, antenna pattern files, manifests, and output results.
- **Amazon ECR**: Hosts Docker images built with processing period-specific dependencies, ensuring environment consistency.
- **AWS IAM**: Defines roles and policies for secure S3 and Lambda operations.
- **AWS Lambda**: Executes the containerized analysis per manifest entry for parallelized processing.
- **Amazon S3 Batch Operations**: Orchestrates large-scale Lambda invocations across manifest entries, tracking job status and error reports.
- **AWS STS**: Retrieves account identity for ARN construction and resource scoping.

## Configuration and Analysis Parameters

Each processing period directory contains a `configure.env` file that defines environment variables to customize analysis thresholds, S3 paths, IAM roles, and runtime options. Key parameters include:

```bash
SEASONDER_PATTERN_PATH             # S3 URI or local path to antenna pattern file
SEASONDER_NSM=2                     # Number of spectral points averaged during smoothing
SEASONDER_FDOWN=10                  # Null Below Peak Power threshold
SEASONDER_FLIM=100                  # Peak Power Dropoff threshold (dB)
SEASONDER_NOISEFACT=3.981072        # Noise factor for thresholding
SEASONDER_CURRMAX=2                 # Maximum allowable current
SEASONDER_REJECT_DISTANT_BRAGG=TRUE # Exclude distant Bragg peaks
SEASONDER_REJECT_NOISE_IONOSPHERIC=TRUE
SEASONDER_REJECT_NOISE_IONOSPHERIC_THRESHOLD=0
SEASONDER_COMPUTE_FOR=TRUE          # Compute first-order region metrics
SEASONDER_DOPPLER_INTERPOLATION=2    # Doppler interpolation factor
SEASONDER_PPMIN=5                   # Minimum peak power (dB) threshold
SEASONDER_PWMAX=50                  # Peak width at 3 dB below peak
SEASONDER_SMOOTH_NOISE_LEVEL=TRUE
SEASONDER_MUSIC_PARAMETERS="40,20,2,20"
SEASONDER_DISCARD_NO_SOLUTION=TRUE
SEASONDER_DISCARD_LOW_SNR=TRUE
SEASONDER_RDATA_OUTPUT=FALSE        # Disable .RData output
SEASONDER_S3_OUTPUT_PATH            # S3 URI for processed output
```

## Processing Period Directory Organization

Raw data and configuration for PRIO and VILA radar sites are organized under the repository root in `PRIO/` and `VILA/`. Each site directory contains subdirectories corresponding to processing periods (distinct antenna pattern measurement processing periods), for example `PRIO1` or `VILA1`. Each period folder contains:

- `configure.env`: Period-specific environment variables (analysis thresholds, S3 paths, IAM roles).
- `Dockerfile`: Defines the container image with SeaSondeR and period-specific parameters.
`run_process_hf_pipeline.sh`: Generates the manifest and submits AWS batch jobs.
Raw `.cs`/`.cs4` spectral files and (optionally) local antenna pattern files.
Auxiliary scripts (e.g., `generate_report.sh`, `generate_hf_processing_table.sh`) for reporting and table generation.


At the repository root, `setup.sh` clones or updates the `SeaSondeRAWSLambdaDocker` pipeline repository into `SeaSondeRAWSLambdaDocker/`. Each site-period runner (e.g., `run_vila1.sh`, `run_prio1.sh`) then copies necessary pipeline artifacts from that folder into its period directory.
Each site-period runner script (e.g. `run_vila1.sh`, `run_prio1.sh`) bootstraps its period folder by:

- Defining site- and period-specific variables (AWS profile, bucket name, S3 paths, date range, IAM role/policy names, Lambda and ECR identifiers).
- Copying core pipeline artifacts (`Dockerfile`, `configure_seasonder.sh`, `runtime.R`, `prepare_manifest.sh`, `run_batch_job.sh`) into the period folder.
- Executing `configure_seasonder.sh` to create or update IAM roles, policies, ECR repository, and Lambda function (with the period’s environment variables).
- Running `prepare_manifest.sh` to build the CSV/JSON manifest for that period’s spectral files.
- Optionally invoking `run_batch_job.sh` to submit the AWS S3 Batch Operations job, which triggers the processing Lambda for each manifest entry.

## Detailed Workflow

The processing pipeline comprises seven key stages:


1. **Environment Setup and Containerization**
   - `setup.sh` clones the SeaSondeRAWSLambdaDocker repository into the local `SeaSondeRAWSLambdaDocker` directory.
   - See `SeaSondeRAWSLambdaDocker/README.md` for instructions to build and push the Docker image for Lambda deployment.
   - Containerization guarantees reproducible execution regardless of the host environment.

2. **Manifest Generation**
- A manifest script (invoked by `run_process_hf_pipeline.sh`) scans the processing period directory for raw spectral files, computing checksums and timestamps.  
   - Outputs a CSV and JSON manifest that define the input inventory for downstream jobs.

3. **Batch Job Orchestration**  
   - `run_hf_dataset.sh` sources `configure.env` and calls `run_process_hf_pipeline.sh`.  
   - Internally, this uses AWS S3 Batch Operations to invoke the Lambda function for each manifest entry in parallel.

4. **Runtime Data Processing**  
   - Lambda or local containers fetch input files and antenna patterns from S3, execute spectral analysis routines (SeaSondeR scripts), and write Radial Metrics and CS_Objects back to S3.

5. **Error Detection and Reporting**
   - The raw batch job report (CSV) is downloaded and parsed by `generate_report.py` (wrapper `generate_report.sh`).  
   - Common issues (e.g., missing segments, file mismatches) are classified into error-type CSV files and summarized in `processing_report.md`.


6. **Site Configuration Table Generation**
   - `generate_hf_processing_table.sh` sources each processing period’s `configure.env`, downloads antenna patterns, extracts metadata (APM date, bearing, resolution, frequency, range cells), and compiles a markdown table in `sites_config.md`.

7. **Extensibility and Reproducibility**
   - Adding new processing periods only requires a new subdirectory with raw data and a `configure.env` file.  
   - The manifest-driven, containerized architecture supports horizontal scaling and integration of new analysis modules.

## Site Configuration Table

The `sites_config.md` file presents a summary of antenna pattern metadata and processing parameters for each processing period. Example columns include:

| Site | APM Date | Processing Period | Antenna Bearing | Frequency (MHz) | Range Cell (km) | N Doppler Cells |
|------|----------|-------------------|-----------------|-----------------|-----------------|-----------------|
| VILA1 | 2011-10-07 12:40:09 | 2011-09-30 0730–2015-08-05 1330 | 19° | 4.860 | 5.100 | 2048 |
| …     | …        | …                 | …               | …               | …               | …               |


For full details, run:
```bash
bash generate_hf_processing_table.sh
```

## References

1. **PRIO LLUV dataset**: https://doi.org/10.5281/zenodo.16528653
2. **VILA LLUV dataset**: https://doi.org/10.5281/zenodo.16458694
3. Herrera Cortijo, J. L., Fernández-Baladrón, A., & Varela Benvenuto, R. (2025). *SeaSondeR: Radial Metrics from SeaSonde HF-Radar Data* (v0.2.9). Zenodo. https://doi.org/10.5281/zenodo.16455051
4. Herrera Cortijo, J. L., Fernández-Baladrón, A., & Varela Benvenuto, R. (2025). *Batch Processing of SeaSonde HF-Radar Spectra Files on AWS with SeaSondeR R Package* (v1.0.0). Zenodo. https://doi.org/10.5281/zenodo.16453046
