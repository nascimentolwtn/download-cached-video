#!/bin/bash
# Download HLS video segments from HAR file captured by Kiwify extension

set -e

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

print_usage() {
    cat << EOF
Usage: $0 -f <har_file> [-o <output_file>]

Example:
  $0 -f kiwify_20260528123456.har
  $0 -f kiwify_20260528123456.har -o my_video.mp4

Parameters:
  -f  HAR file captured by extension (required)
  -o  Output filename (default: kiwify_video.mp4)
  -h  Show this help
EOF
}

# Defaults
OUTPUT_FILE="kiwify_video.mp4"
HAR_FILE=""

# Parse arguments
while getopts "f:o:h" opt; do
    case $opt in
        f) HAR_FILE="$OPTARG" ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

# Validate HAR file
if [ -z "$HAR_FILE" ] || [ ! -f "$HAR_FILE" ]; then
    error "HAR file not found or not specified. Use -h for help."
fi

log "==============================================="
log "Kiwify HLS Downloader from HAR"
log "==============================================="
log "HAR file: $HAR_FILE"
log ""

# Parse HAR to extract HLS segments
log "Parsing HAR file..."

# Use jq to extract .ts segment URLs
HLS_URLS=$(jq -r '.log.entries[].request.url | select(endswith(".ts"))' "$HAR_FILE" | sort -u)

if [ -z "$HLS_URLS" ]; then
    error "No HLS segments found in HAR file"
fi

log "Found HLS segments in HAR"
log ""

# Extract metadata from URLs
FIRST_URL=$(echo "$HLS_URLS" | head -1)
BASE_URL=$(echo "$FIRST_URL" | sed 's|/[^/]*\.ts$||')
SEGMENT_PREFIX=$(echo "$FIRST_URL" | sed 's|.*/\([^/]*\)-[0-9]*\.ts$|\1|')

log "Base URL: $BASE_URL"
log "Segment Prefix: $SEGMENT_PREFIX"
log ""

# Extract available resolutions
RESOLUTIONS=$(echo "$HLS_URLS" | sed "s|.*/${SEGMENT_PREFIX}-||" | sed 's|[0-9]*\.ts$||' | sort -u)

log "Available resolutions:"
COUNT=0
declare -a RES_ARRAY
declare -a RES_MAP
for res in $RESOLUTIONS; do
    ((COUNT++))
    RES_ARRAY[$COUNT]="$res"
    RES_MAP[$COUNT]="$res"
    echo "  [$COUNT] $res"
done
log ""

# Ask user for resolution
while true; do
    read -p "Select resolution [1-$COUNT]: " CHOICE
    if [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$COUNT" ]; then
        SELECTED_RES="${RES_ARRAY[$CHOICE]}"
        break
    fi
    echo "Invalid choice. Please select 1-$COUNT"
done

log ""
log "Selected resolution: $SELECTED_RES"
log ""

# Find all segments for selected resolution
SEGMENT_URLS=$(echo "$HLS_URLS" | grep "/${SEGMENT_PREFIX}-${SELECTED_RES}[0-9]*\.ts")
SEGMENT_COUNT=$(echo "$SEGMENT_URLS" | wc -l)

log "Total segments to download: $SEGMENT_COUNT"
log ""

# Extract segment numbers for sequence
SEGMENT_START=$(echo "$SEGMENT_URLS" | head -1 | sed "s|.*${SELECTED_RES}||" | sed 's|\.ts$||')
SEGMENT_END=$(echo "$SEGMENT_URLS" | tail -1 | sed "s|.*${SELECTED_RES}||" | sed 's|\.ts$||')

log "Segment range: $SEGMENT_START to $SEGMENT_END"
log ""

# Extract headers from HAR (cookies, referer, user-agent)
log "Extracting headers from HAR..."
HEADERS_JSON="/tmp/kiwify_headers_$$.json"

jq '.log.entries[0].request.headers | map({(.name): .value}) | add' "$HAR_FILE" > "$HEADERS_JSON" 2>/dev/null || {
    error "Failed to extract headers from HAR"
}

# Create working directory
WORK_DIR="./kiwify_download_$$"
mkdir -p "$WORK_DIR"

log "Working directory: $WORK_DIR"
log ""

# Function to build curl with headers from JSON file
build_curl_command() {
    local output_path="$1"
    local segment_url="$2"
    local headers_file="$3"

    python3 << PYTHON
import json
import sys

try:
    with open("$headers_file") as f:
        headers = json.load(f)

    cmd = ["curl", "-s", "-L", "--max-time", "30", "-o", "$output_path"]
    for name, value in headers.items():
        if name.lower() not in [':authority', ':method', ':path', ':scheme']:
            cmd.extend(["-H", f"{name}: {value}"])
    cmd.append("$segment_url")

    print(" ".join(f'"{c}"' if " " in c else c for c in cmd))
except:
    print("curl -s -L --max-time 30 -o \"$output_path\" \"$segment_url\"")
PYTHON
}

# Download segments
log "Downloading segments..."
segment_count=0
failed_count=0

for i in $(seq $SEGMENT_START $SEGMENT_END); do
    segment_file="${SEGMENT_PREFIX}-${SELECTED_RES}${i}.ts"
    segment_url="$BASE_URL/$segment_file"
    output_path="$WORK_DIR/$segment_file"

    # Skip if already downloaded
    if [ -f "$output_path" ]; then
        log "[$((i - SEGMENT_START + 1))/$((SEGMENT_END - SEGMENT_START + 1))] ✓ Already exists: $segment_file"
        ((segment_count++))
        continue
    fi

    printf "[$((i - SEGMENT_START + 1))/$((SEGMENT_END - SEGMENT_START + 1))] Downloading: $segment_file"

    # Build and execute curl command with headers from HAR
    CURL_CMD=$(build_curl_command "$output_path" "$segment_url" "$HEADERS_JSON")

    if eval "$CURL_CMD 2>/dev/null"; then
        if [ -f "$output_path" ] && [ -s "$output_path" ]; then
            echo " ✓"
            ((segment_count++))
        else
            echo " ✗ FAILED (empty)"
            ((failed_count++))
        fi
    else
        echo " ✗ FAILED"
        ((failed_count++))
    fi
done

log ""
log "Download complete: $segment_count/$((SEGMENT_END - SEGMENT_START + 1)) segments"

if [ "$failed_count" -gt 0 ]; then
    echo "⚠ Warning: $failed_count segments failed to download"
fi

# Create concat file for ffmpeg
log ""
log "Creating ffmpeg concat playlist..."
concat_file="$WORK_DIR/concat.txt"
> "$concat_file"

for i in $(seq $SEGMENT_START $SEGMENT_END); do
    segment_file="${SEGMENT_PREFIX}-${SELECTED_RES}${i}.ts"
    echo "file '$segment_file'" >> "$concat_file"
done

# Check ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    error "ffmpeg not found. Install it: sudo apt-get install ffmpeg"
fi

# Merge segments with ffmpeg
log ""
log "Merging segments into MP4..."
log "This may take a minute or two..."
log ""

cd "$WORK_DIR"
if ffmpeg -f concat -safe 0 -i concat.txt -c copy -y "../$OUTPUT_FILE" 2>&1 | \
    grep -E "^(frame=|Duration:|size=|bitrate=)" | tail -5; then

    cd ..
    log ""
    log "✓ Successfully created: $OUTPUT_FILE"

    # Show file info
    if command -v ffprobe &> /dev/null; then
        log ""
        log "Video information:"
        ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height,r_frame_rate,duration \
            -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null | \
            awk '{print "  " $0}' || true

        file_size=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        log "  File size: $file_size"
    fi

    # Cleanup
    log ""
    read -p "Delete temporary files? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Cleaning up..."
        rm -rf "$WORK_DIR"
        rm -f "$HEADERS_JSON"
        log "Done! Your video is ready: $OUTPUT_FILE"
    else
        log "Temporary files saved in: $WORK_DIR"
        log "Headers saved in: $HEADERS_JSON"
    fi
else
    cd ..
    error "Failed to merge segments with ffmpeg"
fi
