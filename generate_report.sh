#!/usr/bin/env bash
set -euo pipefail
#
# generate_report.sh
#
# Bash wrapper to invoke the Python report generation script.
#
# Usage:
#   ./generate_report.sh /path/to/job-<id>/results [--manifest /path/to/manifest.csv] [-o output.md]
#
#
# Requirements:
#   - Python 3.6+ with required Python packages installed (e.g. scipy).
#   - generate_report.py must be located in the same directory.
#
# Options:
#   --manifest <path>   Path to manifest CSV file (optional).
#   -o, --output <path> Output Markdown file path (optional).
#
# This script enables strict error handling and locates the Python script directory automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") results_dir [--manifest manifest.csv] [-o output.md]" >&2
  exit 1
fi

# Invoke the Python report generation script
python3 "$SCRIPT_DIR/generate_report.py" "$@"