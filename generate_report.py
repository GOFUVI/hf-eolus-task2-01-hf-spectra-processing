#!/usr/bin/env python3
"""
generate_report.py

Generate a Markdown report summarizing processing statistics and errors for a job.

This script reads CSV files in a job's results directory (success and failure),
counts processed files, parses error messages, and produces:

- A Markdown report with total files in the manifest, number of successes, failures,
  and detailed error breakdown.
- CSV files per error type listing affected files and timestamps (ISO format).

Usage:
  python3 generate_report.py /path/to/job-<id>/results [--manifest /path/to/manifest.csv] [--output /path/to/output.md]
"""
import os
import sys
import argparse
import csv
import json
import re
import datetime

def find_manifest(start_dir):
    """Recursively search for manifest.csv in parent directories starting from start_dir."""
    current = os.path.abspath(start_dir)
    while True:
        candidate = os.path.join(current, "manifest.csv")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return None

def main():
    parser = argparse.ArgumentParser(description="Generate a Markdown report for a job's processing results")
    parser.add_argument("results_dir", help="Directory containing result CSV files")
    parser.add_argument("--manifest", help="Path to manifest.csv file (optional)")
    parser.add_argument("--output", "-o", help="Output Markdown file path (optional)")
    args = parser.parse_args()

    # Determine the job directory based on the results directory
    results_dir = args.results_dir
    if not os.path.isdir(results_dir):
        sys.exit(f"ERROR: Results directory does not exist: '{results_dir}'")
    base = os.path.abspath(results_dir)
    if os.path.basename(base) == "results":
        job_dir = os.path.dirname(base)
    else:
        job_dir = base

    # Find manifest.csv file (specified or by searching upwards)
    manifest_path = args.manifest or find_manifest(job_dir)
    if not manifest_path or not os.path.isfile(manifest_path):
        sys.exit("ERROR: manifest.csv not found in directory tree")
    # Count non-empty lines in manifest.csv
    try:
        with open(manifest_path, 'r', encoding='utf-8') as f:
            total_manifest = sum(1 for line in f if line.strip())
    except Exception as e:
        sys.exit(f"ERROR reading manifest.csv: {e}")

    # Discover all CSV files in the results directory
    csv_files = [os.path.join(results_dir, f)
                 for f in os.listdir(results_dir)
                 if f.lower().endswith('.csv')]
    if not csv_files:
        sys.exit(f"ERROR: No CSV files found in '{results_dir}'")

    success_csvs, fail_csvs = [], []
    # Classify each CSV by status in column 4 ('succeeded' vs 'failed')
    for csv_path in csv_files:
        has_failed = False
        has_succeeded = False
        try:
            with open(csv_path, newline='', encoding='utf-8') as cf:
                reader = csv.reader(cf)
                for i, row in enumerate(reader):
                    if len(row) > 3:
                        st = row[3].strip().lower()
                        if st == 'failed':
                            has_failed = True
                        elif st == 'succeeded':
                            has_succeeded = True
                    if i >= 100 or (has_failed and has_succeeded):
                        break
        except Exception as e:
            sys.exit(f"ERROR reading '{csv_path}': {e}")

        # Assign file paths to success or failure groups
        if has_failed and not has_succeeded:
            fail_csvs.append(csv_path)
        elif has_succeeded and not has_failed:
            success_csvs.append(csv_path)

    # Select the success and failure CSV files (largest if multiple)
    def pick_largest(files):
        return max(files, key=lambda p: sum(1 for _ in open(p, encoding='utf-8')))

    if not success_csvs and not fail_csvs:
        sys.exit("ERROR: Could not determine success or failure CSVs (check file contents)")

    if success_csvs:
        if len(success_csvs) > 1:
            success_csv = pick_largest(success_csvs)
        else:
            success_csv = success_csvs[0]
    else:
        success_csv = None

    if fail_csvs:
        if len(fail_csvs) > 1:
            fail_csv = pick_largest(fail_csvs)
        else:
            fail_csv = fail_csvs[0]
    else:
        fail_csv = None

    # Count successful entries and process error entries
    if success_csv:
        successes_count = sum(1 for _ in open(success_csv, encoding='utf-8'))
    else:
        successes_count = 0
    total_errors = 0
    type_counts = {}
    type_files = {}
    if fail_csv:
        with open(fail_csv, newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            for row in reader:
                total_errors += 1
                msg = row[6] if len(row) > 6 else ""
                err_text = msg
                if ": " in msg:
                    try:
                        part = msg.split(": ", 1)[1]
                        d = json.loads(part)
                        err_text = d.get("error", err_text)
                    except Exception:
                        pass
                if "No valid FOR data" in err_text:
                    label = "No valid FOR data found. Please run seasonder_computeFORs first."
                elif "has size 0." in err_text:
                    label = "File has size 0"
                elif "Invalid file size for nCsKind" in err_text:
                    label = "Invalid file size for nCsKind 2 (file size mismatch)"
                elif "Can't rename columns" in err_text:
                    label = "Can't rename columns that don't exist"
                else:
                    label = err_text.strip()
                type_counts[label] = type_counts.get(label, 0) + 1
                file_path = row[1] if len(row) > 1 else ""
                type_files.setdefault(label, []).append(file_path)

    total_processed = successes_count + total_errors
    job_id = os.path.basename(job_dir)

    # Build the Markdown report content
    md_lines = []
    md_lines.append(f"# Job Processing Report – Job {job_id}")
    md_lines.append("")
    md_lines.append(f"**Files in manifest**: {total_manifest}  ")
    md_lines.append(f"**Files processed successfully**: {successes_count}  ")
    md_lines.append(f"**Files with errors**: {total_errors}  ")
    md_lines.append(f"**Total files processed**: {total_processed}  ")
    md_lines.append("")
    md_lines.append("## Errors by type")
    md_lines.append("")
    md_lines.append("| Type | Description | Count | % of total processed |")
    md_lines.append("| :--: | ----------- | -----: | ---------------------: |")
    sorted_labels = sorted(type_counts.items(), key=lambda x: x[1], reverse=True)
    for idx, (label, cnt) in enumerate(sorted_labels, 1):
        pct = (cnt / total_processed * 100) if total_processed else 0.0
        md_lines.append(f"| {idx} | {label} | {cnt} | {pct:.2f}% |")
    md_lines.append("")
    if type_files:
        md_lines.append("## Files by error type")
        md_lines.append("")
        for idx, (label, cnt) in enumerate(sorted_labels, 1):
            files = type_files.get(label, [])
            if not files:
                continue
            md_lines.append(f"### Type {idx}: {label} ({cnt} files)")
            md_lines.append("")
            for p in files[:10]:
                md_lines.append(f"- {p}")
            if len(files) > 10:
                remaining = len(files) - 10
                md_lines.append(f"- ... and {remaining} more files")
            md_lines.append("")

    # Generate a CSV file for each error type with columns: file, date (ISO)
    try:
        for idx, (label, _) in enumerate(sorted_labels, 1):
            files = type_files.get(label, [])
            if not files:
                continue
            # Sort files by date extracted from filename (yy_mm_dd_HHMM)
            def _parse_date(p):
                base = os.path.basename(p)
                m = re.search(r'(\d{2}_\d{2}_\d{2}_\d{4})', base)
                if m:
                    try:
                        return datetime.datetime.strptime(m.group(1), '%y_%m_%d_%H%M')
                    except ValueError:
                        pass
                return datetime.datetime.min
            files.sort(key=_parse_date)
            # Create a safe filename for the error CSV
            slug = re.sub(r'[^0-9a-zA-Z]+', '_', label).strip('_')
            csv_name = f"error_type_{idx}_{slug}.csv"
            csv_path = os.path.join(results_dir, csv_name)
            with open(csv_path, 'w', newline='', encoding='utf-8') as csvf:
                writer = csv.writer(csvf)
                writer.writerow(['file', 'date'])
                for p in files:
                    base = os.path.basename(p)
                    m = re.search(r'(\d{2}_\d{2}_\d{2}_\d{4})', base)
                    if m:
                        date_part = m.group(1)
                        try:
                            dt = datetime.datetime.strptime(date_part, '%y_%m_%d_%H%M')
                            iso_date = dt.isoformat()
                        except ValueError:
                            iso_date = ''
                    else:
                        iso_date = ''
                    writer.writerow([p, iso_date])
            print(f"Generated CSV for error type {idx}: {csv_path}")
    except Exception as e:
        print(f"WARNING: error generating error CSVs: {e}", file=sys.stderr)

    # Determine output report file path
    output_path = args.output or os.path.join(results_dir, "processing_report.md")
    try:
        with open(output_path, 'w', encoding='utf-8') as out:
            out.write("\n".join(md_lines))
        print(f"Report generated at {output_path}")
    except Exception as e:
        sys.exit(f"ERROR writing report: {e}")

if __name__ == "__main__":
    main()