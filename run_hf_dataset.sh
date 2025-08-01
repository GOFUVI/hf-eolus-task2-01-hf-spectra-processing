#!/usr/bin/env bash
set -euo pipefail

# run_hf_dataset.sh - Generic runner for HF dataset processing (VILA, PRIO, etc.)
#
# Description:
#   Generic runner script that loads environment variables from a configuration directory
#   and orchestrates AWS-based batch job operations for processing SeaSonde HF datasets.
#
# Usage:
#   ./run_hf_dataset.sh <config_dir>
#
# Arguments:
#   <config_dir>   Directory containing configure.env with required settings.
#
# Requirements:
#   - bash shell
#   - AWS CLI must be installed and configured if performing AWS operations.
#
# Environment Variables (loaded from <config_dir>/configure.env):
#   See configure.env for variable definitions (e.g. PROFILE, BUCKET_NAME, etc.)
#
# This script supports updating AWS Lambda configuration, refreshing manifests,
# and running batch jobs based on flags defined in configure.env.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <config_dir>"
  exit 1
fi

CONFIG_DIR="$1"
# Load configuration from configure.env
ENV_FILE="$CONFIG_DIR/configure.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: configure.env not found: $ENV_FILE"
  exit 1
fi

# Load configuration
set -o allexport
source "$ENV_FILE"
set +o allexport

# Determine script directory (location of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$SCRIPT_DIR" ]; then
  echo "Error: Script directory not found: $SCRIPT_DIR"
  exit 1
fi
# SeaSondeRAWSLambdaDocker located under process_HF
SS_DIR="$SCRIPT_DIR/SeaSondeRAWSLambdaDocker"
if [ ! -d "$SS_DIR" ]; then
  echo "Error: SeaSondeRAWSLambdaDocker not found at $SS_DIR"
  exit 1
fi

# Move into config directory
cd "$CONFIG_DIR"

# Common tasks
if [ "${UPDATE_CONFIG:-false}" = "true" ]; then
  if [ "${REFRESH_ROLE_POLICY_LAMBDA:-false}" = "true" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE")
    # Remove existing role and policy if present
    if aws iam get-role --role-name "$ROLE" --profile "$PROFILE" &>/dev/null; then
      aws iam detach-role-policy --role-name "$ROLE" \
        --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY \
        --profile "$PROFILE"
      aws iam delete-role --role-name "$ROLE" --profile "$PROFILE"
    fi
    if aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY --profile "$PROFILE" &>/dev/null; then
      aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY \
        --profile "$PROFILE"
    fi
    if aws lambda get-function --function-name "$LAMBDA_NAME" --profile "$PROFILE" &>/dev/null; then
      aws lambda delete-function --function-name "$LAMBDA_NAME" --profile "$PROFILE"
    fi
  fi

  # Prepare lambda package
  cp "$SS_DIR/Dockerfile" ./
  cp "$SS_DIR/configure_seasonder.sh" ./
  cp "$SS_DIR/runtime.R" ./
  rm -f response.json
  chmod +x configure_seasonder.sh
  ./configure_seasonder.sh \
    -A "$PROFILE" \
    -E "$ECR_REPO_NAME" \
    -L "$LAMBDA_NAME" \
    -T "$MEASSPATTERN_S3_PATH" \
    -R "$ROLE" \
    -P "$POLICY" \
    -S "$OUTPUT_S3_PATH" \
    -K "$TESTFILE_S3_PATH" \
    -g "$REGION" \
    -u "$S3_RESOURCE_ARN" \
    -o SEASONDER_REJECT_NOISE_IONOSPHERIC_THRESHOLD=$SEASONDER_REJECT_NOISE_IONOSPHERIC_THRESHOLD
fi

if [ "${REFRESH_MANIFEST:-false}" = "true" ]; then
  # Remove existing manifest
  if aws s3api head-object --bucket "$BUCKET_NAME" --key "$MANIFEST_S3_PATH" --profile "$PROFILE" &>/dev/null; then
    aws s3 rm "$MANIFEST_S3_PATH" --profile "$PROFILE"
  fi
  cp "$SS_DIR/prepare_manifest.sh" ./
  chmod +x prepare_manifest.sh

  JQ_FILTER="
      .Contents[]
      | select(.Key | test(\"CSS_${SITE_CODE}_\\\\d{2}_\\\\d{2}_\\\\d{2}_\\\\d{4}\\\\.cs\"))
      | select((.Key | capture(\"CSS_${SITE_CODE}_(?<year>\\\\d{2})_(?<month>\\\\d{2})_(?<day>\\\\d{2})_(?<time>\\\\d{4})\") | \"20\(.year)-\(.month)-\(.day) \(.time)\") as \$file_date
        | \$file_date >= \"$START_DATE\" and \$file_date <= \"$END_DATE\")
      | \"\(\$bucket),\(.Key)\""

  # Build arguments for prepare_manifest.sh
  args=( -b "$BUCKET_NAME" -p "$SPECTRA_PREFIX" -r "$PROFILE" )
  if [ -n "${JQ_FILTER:-}" ]; then
    args+=( -j "$JQ_FILTER" )
  fi
  args+=( -d "$MANIFEST_S3_PATH" )
  ./prepare_manifest.sh "${args[@]}"
fi

if [ "${RUN_JOBS:-false}" = "true" ]; then
  cp "$SS_DIR/run_batch_job.sh" ./
  chmod +x run_batch_job.sh
  ./run_batch_job.sh \
    -U "$MANIFEST_S3_PATH" \
    -g "$REGION" \
    -r "$BATH_ROLE" \
    -y "$BATH_POLICY" \
    -l "$LAMBDA_NAME" \
    -p "$PROFILE" \
    -c "$CONFIRM_JOB" \
    -P "$REPORT_PREFIX"
fi