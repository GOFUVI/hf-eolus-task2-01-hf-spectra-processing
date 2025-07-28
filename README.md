Project HF-EOLUS. Task 2. Step 01. Configuration of VILA and PRIO Spectra processing using SeaSondeR.

# HF Spectra Processing

The `01-HF_processing` directory implements a comprehensive, reproducible, and containerized pipeline for processing high-frequency radar (HF) spectral datasets. This section documents the end-to-end methodology, configuration parameters, AWS service integration, and auxiliary scripts required to execute the workflow without relying on external documentation.

## AWS Services Utilization

Processing leverages AWS to enable scalable, serverless execution:
- **Amazon S3**: Versioned storage for raw `.cs`/`.cs4` spectral files, antenna pattern files, manifests, and output results.
- **Amazon ECR**: Hosts Docker images built with campaign-specific dependencies, ensuring environment consistency.
- **AWS IAM**: Defines roles and policies for secure S3 and Lambda operations.
- **AWS Lambda**: Executes the containerized analysis per manifest entry for parallelized processing.
- **Amazon S3 Batch Operations**: Orchestrates large-scale Lambda invocations across manifest entries, tracking job status and error reports.
- **AWS STS**: Retrieves account identity for ARN construction and resource scoping.

## Configuration and Analysis Parameters

Each campaign directory contains a `configure.env` file that defines environment variables to customize analysis thresholds, S3 paths, IAM roles, and runtime options. Key parameters include:

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

## Detailed Workflow

The processing pipeline comprises nine key stages:

1. **Campaign Directory Organization**  
   - Raw data and configuration are organized under `01-HF_processing/PRIO/*` and `01-HF_processing/VILA/*`.  
   - Each campaign subdirectory hosts a `configure.env` file and may contain auxiliary setup scripts.

2. **Environment Setup and Containerization**  
   - `setup.sh` installs dependencies or builds the Docker image from the campaign-specific Dockerfile.  
   - Containerization guarantees reproducible execution regardless of host environment.

3. **Manifest Generation**  
   - A manifest script (invoked by `run_process_hf_pipeline.sh`) scans the campaign directory for raw spectral files, computing checksums and timestamps.  
   - Outputs a CSV and JSON manifest that define the input inventory for downstream jobs.

4. **Batch Job Orchestration**  
   - `run_hf_dataset.sh` sources `configure.env` and calls `run_process_hf_pipeline.sh`.  
   - Internally, this uses AWS S3 Batch Operations to invoke the Lambda function for each manifest entry in parallel.

5. **Runtime Data Processing**  
   - Lambda or local containers fetch input files and antenna patterns from S3, execute spectral analysis routines (SeaSondeR scripts), and write Radial Metrics and CS_Objects back to S3.

6. **Error Detection, Classification, and Reporting**  
   - The raw batch job report (CSV) is downloaded and parsed by `generate_report.py` (wrapper `generate_report.sh`).  
   - Common issues (e.g., missing segments, file mismatches) are classified into error-type CSV files and summarized in `processing_report.md`.


8. **Site Configuration Table Generation**  
   - `generate_hf_processing_table.sh` sources each campaign’s `configure.env`, downloads antenna patterns, extracts metadata (APM date, bearing, resolution, frequency, range cells), and compiles a markdown table in `sites_config.md`.

9. **Extensibility and Reproducibility**  
   - Adding new campaigns only requires a new subdirectory with raw data and a `configure.env` file.  
   - The manifest-driven, containerized architecture supports horizontal scaling and integration of new analysis modules.

## Site Configuration Table

The `sites_config.md` file presents a summary of antenna pattern metadata and processing parameters for each campaign. Example columns include:

| Site | APM Date | Processing Period | Antenna Bearing | Frequency (MHz) | Range Cell (km) | N Doppler Cells |
|------|----------|-------------------|-----------------|-----------------|-----------------|-----------------|
| VILA1 | 2011-10-07 12:40:09 | 2011-09-30 0730–2015-08-05 1330 | 19° | 4.860 | 5.100 | 2048 |
| …     | …        | …                 | …               | …               | …               | …               |

For full details, run:
```bash
bash generate_hf_processing_table.sh
```
