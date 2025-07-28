# Type 1 Error Report

## Methodology

- Searched error CSV files prefixed "errores_tipo_1" in the directory and subdirectories.
- Processed manifest.csv files to count referenced files by month.
- Extracted months from error record dates (ISO format) and file paths in manifests.
- Counted the total number of error records and processed files per month.
- Calculated error percentage per month as (error_records / processed_files) * 100.
- Applied an exact binomial test with null hypothesis p = category error rate at significance level α = 0.05.
- Generated separate tables for PRIO and VILA datasets.

## Results for PRIO

- Analyzed 2 error CSV files and 2 manifest files under `PRIO`.

### Analyzed Error Files

- ./PRIO/PRIO2/job-2e340eda-cbdc-4cd8-942c-3407e2297a2d/results/errores_tipo_1_No_valid_FOR_data_found_Please_run_seasonder_computeFORs_first.csv
- ./PRIO/PRIO1/job-5d87a439-8b17-4575-8bf9-5f9c50adc9d0/results/errores_tipo_1_No_valid_FOR_data_found_Please_run_seasonder_computeFORs_first.csv

| Month | Error Records | Processed Files | Error Percentage (%) | P-Value | Significant |
| ----- | -------------:| ---------------:| ---------------------:| -------:| ----------- |
| January | 0 | 10690 | 0.00% | 2.82e-68 | Yes |
| February | 125 | 9862 | 1.27% | 0.1296 | No |
| March | 696 | 10036 | 6.94% | 5.41e-243 | Yes |
| April | 157 | 8572 | 1.83% | 0.0044 | Yes |
| May | 3 | 9072 | 0.03% | 1.78e-52 | Yes |
| June | 2 | 8034 | 0.02% | 1.48e-47 | Yes |
| July | 422 | 9381 | 4.50% | 2.14e-87 | Yes |
| August | 211 | 9295 | 2.27% | 1.06e-09 | Yes |
| September | 0 | 10684 | 0.00% | 2.74e-68 | Yes |
| October | 17 | 10745 | 0.16% | 1.06e-45 | Yes |
| November | 0 | 7602 | 0.00% | 1.13e-48 | Yes |
| December | 0 | 8550 | 0.00% | 1.17e-54 | Yes |

## Results for VILA

- Analyzed 3 error CSV files and 4 manifest files under `VILA`.

### Analyzed Error Files

- ./VILA/VILA2/job-590adfae-11cf-4ec7-8ba0-6436f900b11d/results/errores_tipo_1_No_valid_FOR_data_found_Please_run_seasonder_computeFORs_first.csv
- ./VILA/VILA3/job-5417d26d-ac29-44cf-b29a-53c3afd69e1e/results/errores_tipo_1_No_valid_FOR_data_found_Please_run_seasonder_computeFORs_first.csv
- ./VILA/VILA1/job-64ad9141-02c6-443f-9724-dab65d4fdc95/results/errores_tipo_1_No_valid_FOR_data_found_Please_run_seasonder_computeFORs_first.csv

| Month | Error Records | Processed Files | Error Percentage (%) | P-Value | Significant |
| ----- | -------------:| ---------------:| ---------------------:| -------:| ----------- |
| January | 315 | 14407 | 2.19% | 8.24e-11 | Yes |
| February | 1 | 13040 | 0.01% | 5.35e-175 | Yes |
| March | 42 | 14373 | 0.29% | 3.40e-135 | Yes |
| April | 150 | 14157 | 1.06% | 1.07e-57 | Yes |
| May | 457 | 12794 | 3.57% | 0.0016 | Yes |
| June | 1054 | 12666 | 8.32% | 5.16e-177 | Yes |
| July | 1344 | 11797 | 11.39% | 0.00e+00 | Yes |
| August | 118 | 8482 | 1.39% | 1.22e-23 | Yes |
| September | 73 | 10067 | 0.73% | 6.06e-60 | Yes |
| October | 150 | 12712 | 1.18% | 3.69e-45 | Yes |
| November | 979 | 13574 | 7.21% | 9.53e-126 | Yes |
| December | 26 | 14823 | 0.18% | 6.71e-159 | Yes |

