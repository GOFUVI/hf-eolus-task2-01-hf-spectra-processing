#!/usr/bin/env bash
set -euo pipefail
# setup.sh - Download and set up SeaSondeRAWSLambdaDocker subdirectory
#
# Description:
#   Clones the SeaSondeRAWSLambdaDocker repository and copies its contents
#   into the local SeaSondeRAWSLambdaDocker directory within the current project.
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Requirements:
#   - git must be installed and available in PATH
#
# Variables:
#   DEST_FOLDER: Destination directory to store SeaSondeRAWSLambdaDocker (default: ./SeaSondeRAWSLambdaDocker)
#
# This script removes the existing destination folder before cloning.
#
# Define the destination folder
DEST_FOLDER="./SeaSondeRAWSLambdaDocker"

[ -d "$DEST_FOLDER" ] && rm -rf "$DEST_FOLDER"

# Clone the repository temporarily
TEMP_FOLDER=$(mktemp -d)
git clone --depth 1 https://github.com/GOFUVI/SeaSondeRAWSLambdaDocker.git "$TEMP_FOLDER"

# Create the destination folder if it doesn't exist
mkdir -p "$DEST_FOLDER"

# Copy the files from the repository to the destination
cp -r "$TEMP_FOLDER"/* "$DEST_FOLDER"

# Remove the temporary folder
rm -rf "$TEMP_FOLDER"

echo "Files copied to $DEST_FOLDER"
