# Processing statistics

This report summarizes the processing statistics from each subfolder's processing_report.md file.

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

### VILA4

| Type | Description | Count | % of total processed |
| :--: | ----------- | -------: | ---------------------: |