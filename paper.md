---
title: "Reproducible, Containerized Workflow for SeaSonde Spectral Data Analysis"
authors:
  - name: "FirstName LastName"
    affiliation: "Institution Name"
date: 2025-04-25
---

## Summary

This paper describes a modular, reproducible workflow for analyzing SeaSonde high-frequency spectral datasets. The workflow is organized into campaign-specific subdirectories (e.g., PRIO/PRIO1, VILA/VILA1), each containing Docker-based environment configurations, AWS Lambda deployment scripts, S3 manifest generation, batch job orchestration, runtime analysis routines, and error reporting. The pipeline enables consistent execution across multiple campaigns, end-to-end traceability, and automated data-quality assessment.

## Statement of Need

SeaSonde spectral datasets—comprising calibrated complex spectral files (.cs4, .cs)—are widely used in coastal and ionospheric remote sensing to derive oceanographic and geophysical parameters. Their high volume and specialized format require a robust, automated processing pipeline. Traditional workflows rely on ad hoc scripts and manual steps, leading to inconsistent configurations, opaque execution, and limited reproducibility. This workflow addresses these challenges by providing:
- Containerized environments to eliminate dependency issues and ensure consistent execution.
- Standardized manifest generation to formalize input listings and maintain provenance.
- Automated batch job orchestration for high-throughput, parallel processing.
- Systematic error detection and reporting to guide data quality improvements.
- A clear separation between campaign-specific data and core processing logic.

This workflow is intended for researchers and practitioners seeking a scalable, transparent, and reproducible pipeline for SeaSonde spectral data analysis.

## AWS Services Utilization

This workflow leverages Amazon Web Services to achieve scalable, serverless processing:
- **Amazon S3**: Stores input spectral files, antenna pattern files, manifests, and output results and reports with versioning and lifecycle management.
- **Amazon Elastic Container Registry (ECR)**: Hosts Docker images built from campaign-specific Dockerfiles, encapsulating R and SeaSondeR dependencies.
- **AWS Identity and Access Management (IAM)**: Defines execution roles and policies granting S3 read/write access, Lambda invocation, and S3 Batch Operations permissions.
- **AWS Lambda**: Executes container-based SeaSondeR spectral analysis scripts per input file, scaling to thousands of concurrent tasks.
- **Amazon S3 Batch Operations (S3control)**: Orchestrates large-scale invocation of the Lambda function across all manifest entries, tracking job status and generating detailed reports.
- **AWS Security Token Service (STS)**: Retrieves account identity for constructing ARNs and ensuring proper resource scoping.

## Analysis Parameters

The core spectral analysis is driven by environment variables defined in each campaign Dockerfile. Default values:
```
SEASONDER_PATTERN_PATH         # S3 or local path to antenna pattern file
SEASONDER_NSM=2                # Number of spectral poins averaged during smoothing
SEASONDER_FDOWN=10             # Null Below Peak Power
SEASONDER_FLIM=100             # Peak Power Dropoff
SEASONDER_NOISEFACT=3.981072   # Noise factor for thresholding
SEASONDER_CURRMAX=2            # Maximum current
SEASONDER_REJECT_DISTANT_BRAGG=TRUE  # Exclude distant Bragg peaks
SEASONDER_REJECT_NOISE_IONOSPHERIC=TRUE  # Exclude ionospheric noise
SEASONDER_REJECT_NOISE_IONOSPHERIC_THRESHOLD=0  # Ion. noise threshold
SEASONDER_COMPUTE_FOR=TRUE     # Compute first-order region metrics
SEASONDER_DOPPLER_INTERPOLATION=2  # Doppler interpolation factor
SEASONDER_PPMIN=5              # Minimum power in dB threshold of response function peak
SEASONDER_PWMAX=50             # Maximum width of the peak in degress at 3dB bellow the response function peak
SEASONDER_SMOOTH_NOISE_LEVEL=TRUE  # Smooth background noise estimate
SEASONDER_MUSIC_PARAMETERS="40,20,2,20" # MUSIC parameters
SEASONDER_DISCARD_NO_SOLUTION=TRUE # Discard signals with no solution
SEASONDER_DISCARD_LOW_SNR=TRUE # Discard signals with low signal-to-noise ratio
SEASONDER_RDATA_OUTPUT=FALSE   # Disable generation of .RData objects
SEASONDER_S3_OUTPUT_PATH       # S3 URI for processed output storage
```

Overrides and campaign-specific parameters (e.g., start/end dates, S3 bucket, IAM roles) are set in `configure.env` files.

## Workflow and Methodology

The pipeline comprises eight key stages:

1. **Campaign Directory Organization**  
   Each campaign directory corresponds to a specific processing period during which a particular antenna pattern was applied to the data. This modular layout isolates campaign data, configuration scripts, and results by processing period, enabling independent testing and parallel execution.
   AWS Service(s): Amazon S3 stores and versions raw spectral files organized by campaign prefixes.

  
2. **Environment Configuration and Containerization**  
   Within each campaign directory, a Dockerfile and associated setup scripts define a self-contained runtime environment. These artifacts install and configure all necessary software dependencies, ensuring that analyses can be reproduced consistently across different host systems.
   AWS Service(s): Amazon ECR hosts the built Docker images; AWS IAM creates roles and policies for Lambda execution and S3 access.

3. **Manifest Generation**  
   A manifest preparation script scans the campaign directory to catalog input files along with their metadata (e.g., file paths, checksums, timestamps). The outcome is a standardized CSV manifest and a corresponding JSON manifest, which together serve as the definitive input inventory for downstream processing.
   AWS Service(s): AWS S3API (via AWS CLI) `list-objects-v2` lists files; `jq` formats `Bucket,Key` entries. The manifest CSV is optionally uploaded back to S3 for versioned inputs.

4. **Batch Job Orchestration**  
   A generic runner script (`run_hf_dataset.sh`) loads campaign-specific configuration from `configure.env` and invokes the batch submission script (`run_batch_job.sh`). The `run_batch_job.sh` script uses Amazon S3 Batch Operations (S3Control) to invoke the containerized Lambda function for each manifest entry, tracking job identifiers and logging execution details. This approach enables fault isolation, scalable parallel execution, and fine-grained performance monitoring.
   AWS Service(s): Amazon S3 Batch Operations (S3Control) submits a `LambdaInvoke` job; AWS STS retrieves account identity; AWS IAM defines batch roles/policies.

5. **Runtime Data Processing**  
   Inside each container, a scripted analysis routine performs data cleaning, spectral analysis, and the derivation of geophysical parameters. Execution parameters—such as analysis thresholds and output configurations—are supplied via environment variables and manifest entries, allowing flexible customization of processing behavior.
   AWS Service(s): AWS Lambda runs the container per manifest entry; AWS CLI within Lambda copies input files and antenna patterns from S3 and uploads processed outputs back to S3 (Radial_Metrics, CS_Objects).

6. **Error Detection and Classification**  
   After processing, outputs are validated to detect common issues (e.g., missing data segments, file size mismatches, column inconsistencies). Detected errors are categorized by type and per-job reports are generated by the local script `generate_informe.py` (wrapper `generate_informe.sh`), producing a Markdown report (`processing_report.md`) and CSV files (`error_type_<n>_<slug>.csv`). This facilitates rapid diagnosis and reprocessing decisions.
   AWS Service(s): The S3 Batch Operations job report (CSV) is stored in S3; local scripts download and parse this report for error classification.

7. **Summary Report Generation**  
   After all batch jobs complete, campaign-level error summaries and per-job processing reports can be consolidated. For example, a dedicated analysis script (`analizar_errores_tipo_1.py`) invoked via the wrapper `run_analizar_errores_tipo1.sh` scans all Type 1 error CSV files (`errores_tipo_1_*.csv`) and corresponding manifest entries across campaigns to produce a consolidated Markdown report (`type1_error_report.md`) summarizing monthly error rates and statistical significance. Processing reports (`processing_report.md`) and other error-type CSVs can likewise be aggregated or analyzed using custom scripts as needed.  
   AWS Service(s): Aggregation and statistical analysis are performed locally using Python (with SciPy); no additional AWS calls are required for summary generation.

8. **Scalability and Extensibility**  
   The manifest-driven, containerized design enables straightforward extension to new datasets. Adding a new campaign involves creating a new subdirectory with raw data and invoking the standard sequence of workflow scripts. This architecture supports horizontal scaling across multiple campaigns and facilitates the integration of additional analytical modules.
   AWS Service(s): Amazon S3, Amazon ECR, AWS Lambda, and Amazon S3 Batch Operations combine to enable horizontally scaled, reproducible workflows.

9. **Site Configuration Table Generation**  
   The script `generate_hf_processing_table.sh` iterates over the campaign directories under VILA/* and PRIO/*, sourcing each `configure.env`, downloading antenna pattern files via AWS CLI, parsing metadata from RUV files, and aggregating these values into a Markdown table. The output is saved to `sites_config.md` for inclusion in subsequent analyses and reporting.  
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


## Type 1 Error Statistical Analysis

We performed a detailed analysis of Type 1 errors (missing FOR data) across two campaigns (PRIO and VILA). Table 1 summarizes overall error rates:

| Campaign | Error Records | Processed Files | Overall Error Rate (%) |
| -------- | -------------:| ---------------:| ----------------------:|
| PRIO     | 1,633          | 112,523         | 1.45                   |
| VILA     | 4,709          | 152,892         | 3.08                   |

Monthly error rates varied, with PRIO exhibiting a peak in March (6.94%) and VILA in July (11.39%). Exact binomial tests (α = 0.05) indicated significant deviations from baseline error rates in most months (see `type1_error_report.md` for full details).

## Conclusion

The described workflow provides a comprehensive, end-to-end solution for SeaSonde spectral data analysis and quality assessment. By combining containerization, structured manifests, automated orchestration via AWS services, and systematic error reporting, the pipeline enhances reproducibility, scalability, and transparency in remote sensing research.

## Acknowledgements

The authors thank the SeaSonde user community for valuable feedback and contributions to pipeline development.

## References

- Journal of Open Source Software. https://joss.theoj.org
- SeaSonde spectral data format specification. (URL placeholder)