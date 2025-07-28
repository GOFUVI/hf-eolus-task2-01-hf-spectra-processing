#!/usr/bin/env python3
"""
Script to analyze Type 1 error CSV files and generate an English Markdown report.

This script searches recursively for CSV files prefixed with 'errores_tipo_1'
and counts the number of error records per month based on the 'date' field.
It also processes 'manifest.csv' files to count the number of processed files
per month by extracting dates from file paths in the manifest.

A global error rate is computed, and an exact binomial test is performed for
each month to determine if its error rate significantly differs from the global rate.

Requirements:
  - Python 3.6+
  - scipy (for exact binomial test)

Usage:
  python analizar_errores_tipo_1.py --root <root_directory> --output <report.md>
"""

import os
import csv
import argparse
from datetime import datetime
from collections import Counter
import re
import sys
# Import binomtest for exact binomial test if available
try:
    from scipy.stats import binomtest
    _HAS_SCIPY = True
except ImportError:
    _HAS_SCIPY = False
_ALPHA = 0.05

def analizar_errores(root_dir):
    """
    Search for Type 1 error CSV files and count error records per month.

    Args:
        root_dir (str): Root directory to search for CSV files.

    Returns:
        counts (Counter): Number of error records per month.
        num_files (int): Number of CSV files analyzed.
        file_list (list): List of file paths processed.
    """
    counts = Counter()
    archivos_encontrados = 0
    lista_archivos = []

    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.startswith('errores_tipo_1') and filename.endswith('.csv'):
                archivos_encontrados += 1
                filepath = os.path.join(dirpath, filename)
                lista_archivos.append(filepath)
                with open(filepath, newline='', encoding='utf-8') as f:
                    reader = csv.DictReader(f)
                    if 'date' not in reader.fieldnames:
                        print(f"Warning: 'date' field not found in columns of {filepath}. Skipping.")
                        continue
                    for row in reader:
                        date_str = row['date']
                        try:
                            dt = datetime.fromisoformat(date_str)
                            counts[dt.month] += 1
                        except Exception as e:
                            print(f"Error parsing date '{date_str}' in {filepath}: {e}")
    return counts, archivos_encontrados, lista_archivos
 
def analizar_manifests(root_dir):
    """
    Search for 'manifest.csv' files and count referenced files per month.

    Args:
        root_dir (str): Root directory to search for manifest files.

    Returns:
        counts_files (Counter): Number of files referenced per month.
        num_manifests (int): Number of manifest.csv files processed.
    """
    counts_files = Counter()
    manifests_encontrados = 0
    pattern = re.compile(r'(\d{2})_(\d{2})_(\d{2})_(\d{4})')
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename == 'manifest.csv':
                manifests_encontrados += 1
                filepath = os.path.join(dirpath, filename)
                with open(filepath, newline='', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if not line:
                            continue
                        parts = line.split(',', 1)
                        if len(parts) < 2:
                            continue
                        ruta = parts[1]
                        m = pattern.search(ruta)
                        if m:
                            yy = int(m.group(1))
                            mm = int(m.group(2))
                            counts_files[mm] += 1
                        else:
                            print(f"Warning: no date found in path {ruta} in {filepath}")
    return counts_files, manifests_encontrados

def generar_informe(root_dir, output_file):
    """
    Generate a Markdown report with methodology and separate tables for PRIO and VILA datasets.

    Args:
        root_dir (str): Root directory containing PRIO and VILA subdirectories.
        output_file (str): Path to the output Markdown report.
    """
    month_names = {
        1: 'January', 2: 'February', 3: 'March', 4: 'April',
        5: 'May', 6: 'June', 7: 'July', 8: 'August',
        9: 'September', 10: 'October', 11: 'November', 12: 'December'
    }
    categories = ['PRIO', 'VILA']
    with open(output_file, 'w', encoding='utf-8') as out:
        out.write('# Type 1 Error Report\n\n')
        out.write('## Methodology\n\n')
        out.write(f'- Searched {archivos} CSV files with prefix "errores_tipo_1" in the directory and subdirectories.\n')
        out.write('- Processed manifest.csv files in the directory and subdirectories. Each manifest has no header, with two columns: S3 bucket and file path.\n')
        out.write('- Extracted the date from file paths in manifest.csv (format yy_mm_dd_HHMM) to determine the processing month.\n')
        out.write('- Read the "date" column (ISO format) from error CSVs to extract the error month.\n')
        out.write('- Counted the total number of error records per month and the total number of referenced files per month.\n')
        out.write('- Calculated the error percentage per month as (error_records / processed_files) * 100.\n')
        out.write(f'- Applied an exact binomial test with null hypothesis p = {p0:.4f} (global error rate) at significance level α = {_ALPHA}.\n')
        out.write(f'- Determined significance if p-value < {_ALPHA} (Yes/No).\n\n')
        out.write('## Analyzed Error Files\n\n')
        for fpath in lista_archivos:
            out.write(f'- {fpath}\n')
        out.write('\n')
        out.write('## Results\n\n')
        out.write('| Month | Error Records | Processed Files | Error Percentage (%) | P-Value | Significant |\n')
        out.write('| ----- | -------------:| ---------------:| ---------------------:| -------:| ----------- |\n')
        for month in range(1, 13):
            err_c = counts_errors.get(month, 0)
            file_c = counts_files.get(month, 0)
            pct = (err_c / file_c * 100) if file_c else 0.0
            # Statistical test: exact binomial test with null hypothesis p = p0
            if file_c > 0:
                result = binomtest(err_c, file_c, p=p0, alternative='two-sided')
                pval = result.pvalue
                sig = 'Yes' if pval < _ALPHA else 'No'
                # Format p-value: scientific notation if very small
                if pval < 1e-4:
                    pval_str = f"{pval:.2e}"
                else:
                    pval_str = f"{pval:.4f}"
            else:
                pval_str = 'N/A'
                sig = 'No'
            out.write(f'| {month_names[month]} | {err_c} | {file_c} | {pct:.2f}% | {pval_str} | {sig} |\n')
    print(f'Report generated: {output_file}')

def main():
    parser = argparse.ArgumentParser(
        description='Analyze Type 1 error CSV files and generate an English Markdown report.'
    )
    parser.add_argument(
        '--root', '-r',
        default='.',
        help='Root directory to search for error CSV and manifest files.'
    )
    parser.add_argument(
        '--output', '-o',
        default='type1_error_report.md',
        help='Output Markdown report file.'
    )
    args = parser.parse_args()
    # Require SciPy for statistical tests
    if not _HAS_SCIPY:
        print(
            "Error: this script requires the 'scipy' package. Install with: pip install scipy",
            file=sys.stderr
        )
        sys.exit(1)

    # Generate report with separate tables for PRIO and VILA datasets
    root = args.root
    output = args.output
    # Write report
    month_names = {
        1: 'January', 2: 'February', 3: 'March', 4: 'April',
        5: 'May', 6: 'June', 7: 'July', 8: 'August',
        9: 'September', 10: 'October', 11: 'November', 12: 'December'
    }
    categories = ['PRIO', 'VILA']
    with open(output, 'w', encoding='utf-8') as out:
        out.write('# Type 1 Error Report\n\n')
        out.write('## Methodology\n\n')
        out.write('- Searched error CSV files prefixed "errores_tipo_1" in the directory and subdirectories.\n')
        out.write('- Processed manifest.csv files to count referenced files by month.\n')
        out.write('- Extracted months from error record dates (ISO format) and file paths in manifests.\n')
        out.write('- Counted the total number of error records and processed files per month.\n')
        out.write('- Calculated error percentage per month as (error_records / processed_files) * 100.\n')
        out.write(f'- Applied an exact binomial test with null hypothesis p = category error rate at significance level α = {_ALPHA}.\n')
        out.write('- Generated separate tables for PRIO and VILA datasets.\n\n')
        for cat in categories:
            cat_path = os.path.join(root, cat)
            if not os.path.isdir(cat_path):
                continue
            counts_err, num_err_files, list_err_files = analizar_errores(cat_path)
            counts_files_cat, num_manifests = analizar_manifests(cat_path)
            total_errors = sum(counts_err.values())
            total_files = sum(counts_files_cat.values())
            p0 = (total_errors / total_files) if total_files else 0.0
            out.write(f'## Results for {cat}\n\n')
            out.write(f'- Analyzed {num_err_files} error CSV files and {num_manifests} manifest files under `{cat}`.\n\n')
            out.write('### Analyzed Error Files\n\n')
            for fpath in list_err_files:
                out.write(f'- {fpath}\n')
            out.write('\n')
            out.write('| Month | Error Records | Processed Files | Error Percentage (%) | P-Value | Significant |\n')
            out.write('| ----- | -------------:| ---------------:| ---------------------:| -------:| ----------- |\n')
            for month in range(1, 13):
                err_c = counts_err.get(month, 0)
                file_c = counts_files_cat.get(month, 0)
                pct = (err_c / file_c * 100) if file_c else 0.0
                if file_c > 0:
                    result = binomtest(err_c, file_c, p=p0, alternative='two-sided')
                    pval = result.pvalue
                    sig = 'Yes' if pval < _ALPHA else 'No'
                    if pval < 1e-4:
                        pval_str = f"{pval:.2e}"
                    else:
                        pval_str = f"{pval:.4f}"
                else:
                    pval_str = 'N/A'
                    sig = 'No'
                out.write(f'| {month_names[month]} | {err_c} | {file_c} | {pct:.2f}% | {pval_str} | {sig} |\n')
            out.write('\n')
    print(f'Report generated: {output}')

if __name__ == '__main__':
    main()