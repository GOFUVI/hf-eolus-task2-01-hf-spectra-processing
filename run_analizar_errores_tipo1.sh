#!/usr/bin/env bash
set -euo pipefail

# run_analizar_errores_tipo1.sh - Wrapper script for analyzing Type 1 error CSV files.
#
# Description:
#   Sets up the Python environment and invokes the analizar_errores_tipo_1.py script
#   to search for Type 1 error CSVs, analyze error records, and generate a Markdown report.
#
# Usage:
#   ./run_analizar_errores_tipo1.sh [--root <root_dir>] [--output <output_file>]
#
# Options:
#   --root, -r    Root directory to search for error CSV and manifest files (default: current directory).
#   --output, -o  Path to the output Markdown report (default: type1_error_report.md).
#
# Requirements:
#   - Python 3.6+ with 'scipy' package installed.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Python interpreter selection: if a virtualenv is active, use venv/bin/python; otherwise use python3 from PATH
if [[ -n "${VIRTUAL_ENV:-}" && -x "${VIRTUAL_ENV}/bin/python" ]]; then
    PYTHON="${VIRTUAL_ENV}/bin/python"
else
    PYTHON=python3
fi

"$PYTHON" "$SCRIPT_DIR/analizar_errores_tipo_1.py" --root ./ "$@"