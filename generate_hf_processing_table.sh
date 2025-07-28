#!/usr/bin/env bash
set -euo pipefail
# Default AWS profile
PROFILE="default"

# Parse command-line options
while getopts ":p:" opt; do
  case "$opt" in
    p) PROFILE="$OPTARG" ;; 
    \?) echo "Usage: $0 [-p profile]" >&2; exit 1 ;; 
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;; 
  esac
done
shift $((OPTIND -1))

# This script extracts HF processing metadata from VILA/* and PRIO/* configurations

declare -a site_dirs sites apm_date processing_start processing_end location antenna_bearing antenna_res tx_freq range_res range_cells doppler_cells

for dir in VILA/* PRIO/*; do
  if [[ -d "$dir" && -f "$dir/configure.env" ]]; then
    # Load environment variables
    source "$dir/configure.env"

    # Download antenna pattern file
    temp_pattern=$(mktemp)
    aws s3 cp --profile "$PROFILE" "$MEASSPATTERN_S3_PATH" "$temp_pattern"

    # Parse antenna pattern file
    ant_bearing=$(awk -F'!' '/Antenna Bearing/ {gsub(/[ \t]+$/,"",$1); print $1}' "$temp_pattern" | xargs)
    site_code=$(awk -F'!' '/Site Code/ {gsub(/[ \t]+$/,"",$1); print $1}' "$temp_pattern" | xargs)
    latlon=$(awk -F'!' '/Site Lat Lon/ {print $1}' "$temp_pattern" | xargs)
    degree_res=$(awk -F'!' '/Degree Resolution/ {gsub(/[ \t]+$/,"",$1); print $1}' "$temp_pattern" | xargs)
    apm_date_line=$(awk -F'!' '/Date Year/ {print $1}' "$temp_pattern" | xargs)

    rm "$temp_pattern"

    # Find .ruv file
    ruv_file=$(find "$dir" -maxdepth 1 -type f -name "*.ruv" | head -n 1)

    # Parse RUV metadata
    tx_freq_val=$(grep '^%TransmitCenterFreqMHz:' "$ruv_file" | awk -F':' '{print $2}' | xargs)
    range_res_val=$(grep '^%RangeResolutionKMeters:' "$ruv_file" | awk -F':' '{print $2}' | xargs)
    range_cells_val=$(grep '^%RangeCells:' "$ruv_file" | awk -F':' '{print $2}' | xargs)
    doppler_cells_val=$(grep '^%DopplerCells:' "$ruv_file" | awk -F':' '{print $2}' | xargs)

    # Store values using indexed arrays for compatibility with older Bash
    i=${#sites[@]}
    site_dirs[i]=$(basename "$dir")
    sites[i]="$site_code"
    apm_date[i]="$apm_date_line"
    processing_start[i]="$START_DATE"
    processing_end[i]="$END_DATE"
    location[i]="$latlon"
    antenna_bearing[i]="$ant_bearing"
    antenna_res[i]="$degree_res"
    tx_freq[i]="$tx_freq_val"
    range_res[i]="$range_res_val"
    range_cells[i]="$range_cells_val"
    doppler_cells[i]="$doppler_cells_val"
  fi
done

# Output markdown table
OUTPUT_FILE="sites_config.md"
# Initialize or clear the report file
: > "$OUTPUT_FILE"
# Redirect subsequent output to the report file
exec > "$OUTPUT_FILE"
OUTPUT_FILE="sites_config.md"
# Initialize or clear the report file
: > "$OUTPUT_FILE"
# Redirect subsequent output to the report file
exec > "$OUTPUT_FILE"
OUTPUT_FILE="sites_config.md"
# Initialize or clear the report file
: > "$OUTPUT_FILE"
# Redirect subsequent output to the report file
exec > "$OUTPUT_FILE"
OUTPUT_FILE="sites_config.md"
# Initialize or clear the report file
: > "$OUTPUT_FILE"
# Redirect subsequent output to the report file
exec > "$OUTPUT_FILE"
OUTPUT_FILE="sites_config.md"
# Initialize or clear the report file
: > "$OUTPUT_FILE"
# Redirect subsequent output to the report file
exec > "$OUTPUT_FILE"
OUTPUT_FILE="sites_config.md"
# Initialize or clear the report file
: > "$OUTPUT_FILE"
# Redirect subsequent output to the report file
exec > "$OUTPUT_FILE"
printf "| Parameter |"
for d in "${site_dirs[@]}"; do printf " %s |" "$d"; done
printf "\n"
printf '%s' "|---|"; for _ in "${sites[@]}"; do printf '%s' "---|"; done; printf '\n'
printf "| Site |"; for site in "${sites[@]}"; do printf " %s |" "$site"; done; printf "\n"
printf "| APM Date |"; for idx in "${!sites[@]}"; do printf " %s |" "${apm_date[idx]}"; done; printf "\n"
printf "| Processing period (start) |"; for idx in "${!sites[@]}"; do printf " %s |" "${processing_start[idx]}"; done; printf "\n"
printf "| Processing period (end) |"; for idx in "${!sites[@]}"; do printf " %s |" "${processing_end[idx]}"; done; printf "\n"
printf "| Site Location (Lat Lon) |"; for idx in "${!sites[@]}"; do printf " %s |" "${location[idx]}"; done; printf "\n"
printf "| Antenna Bearing (deg true N) |"; for idx in "${!sites[@]}"; do printf " %s |" "${antenna_bearing[idx]}"; done; printf "\n"
printf "| Antenna Pattern resolution (deg) |"; for idx in "${!sites[@]}"; do printf " %s |" "${antenna_res[idx]}"; done; printf "\n"
printf "| Transmit Freq (MHz) |"; for idx in "${!sites[@]}"; do printf " %s |" "${tx_freq[idx]}"; done; printf "\n"
printf "| Range cell resolution (km) |"; for idx in "${!sites[@]}"; do printf " %s |" "${range_res[idx]}"; done; printf "\n"
printf "| N Range cells |"; for idx in "${!sites[@]}"; do printf " %s |" "${range_cells[idx]}"; done; printf "\n"
printf "| N Doppler Cells after interpolation |"; for idx in "${!sites[@]}"; do printf " %s |" "${doppler_cells[idx]}"; done; printf "\n"# Include any SEASONDER_ variables from configure.env files
seasonder_vars=()
for dir in "${site_dirs[@]}"; do
  file="${dir}/configure.env"
  if [[ -f "$file" ]]; then
    while IFS='=' read -r name value; do
      if [[ $name == SEASONDER_* ]]; then
        if [[ ! " ${seasonder_vars[*]} " =~ " $name " ]]; then
          seasonder_vars+=("$name")
        fi
      fi
    done < "$file"
  fi
done

# Print rows for each SEASONDER_ variable
for var in "${seasonder_vars[@]}"; do
  printf "| %s |" "$var"
  for dir in "${site_dirs[@]}"; do
    file="$dir/configure.env"
    val=$(grep "^$var=" "$file" | cut -d= -f2-)
    printf " %s |" "${val:-}"
  done
  printf "\n"
done
