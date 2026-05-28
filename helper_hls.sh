#!/bin/bash
# Generic HLS video downloader and merger for CloudFront/Kiwify videos

set -e

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Function to build curl with optional headers from JSON file
build_curl_command() {
    local output_path="$1"
    local segment_url="$2"
    local headers_file="$3"

    if [ -z "$headers_file" ] || [ ! -f "$headers_file" ]; then
        # Default curl without extra headers
        echo "curl -s -L --max-time 30 -o \"$output_path\" \"$segment_url\""
    else
        # Build curl with headers from JSON
        python3 << PYTHON
import json
import sys

try:
    with open("$headers_file") as f:
        headers = json.load(f)

    cmd = ["curl", "-s", "-L", "--max-time", "30", "-o", "$output_path"]
    for name, value in headers.items():
        cmd.extend(["-H", f"{name}: {value}"])
    cmd.append("$segment_url")

    print(" ".join(f'"{c}"' if " " in c else c for c in cmd))
except:
    print("curl -s -L --max-time 30 -o \"$output_path\" \"$segment_url\"")
PYTHON
    fi
}

print_usage() {
    cat << EOF
Usage: $0 -u <base_url> -p <segment_prefix> -s <start> -e <end> [-o <output_file>] [-H <headers_json>]

Example:
  $0 -u "https://d3pjuhbfoxhm7c.cloudfront.net/path/to/video" \\
     -p "video_id-1080p" -s 0 -e 55 -o myclass.mp4

Parameters:
  -u  Base URL (CloudFront path without segment number)
  -p  Segment prefix (e.g., "video_id-1080p")
  -s  Start segment number (usually 0)
  -e  End segment number (highest segment index)
  -o  Output filename (default: output.mp4)
  -H  HTTP headers as JSON file (for auth/cookies from HAR)
  -h  Show this help
EOF
}

# Defaults
OUTPUT_FILE="output.mp4"
SEGMENT_START=0
HEADERS_FILE=""

# Parse arguments
while getopts "u:p:s:e:o:H:h" opt; do
    case $opt in
        u) BASE_URL="$OPTARG" ;;
        p) SEGMENT_PREFIX="$OPTARG" ;;
        s) SEGMENT_START="$OPTARG" ;;
        e) SEGMENT_END="$OPTARG" ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        H) HEADERS_FILE="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

# Validate required parameters
if [ -z "$BASE_URL" ] || [ -z "$SEGMENT_PREFIX" ] || [ -z "$SEGMENT_END" ]; then
    error "Missing required parameters. Use -h for help."
fi

# Create working directory
WORK_DIR="./hls_download_$$"
mkdir -p "$WORK_DIR"

log "==============================================="
log "HLS Video Downloader"
log "==============================================="
log "Base URL: $BASE_URL"
log "Segment Prefix: $SEGMENT_PREFIX"
log "Segments: $SEGMENT_START to $SEGMENT_END (total: $((SEGMENT_END - SEGMENT_START + 1)))"
log "Output: $OUTPUT_FILE"
log "Working directory: $WORK_DIR"
log ""

# Download all segments
log "Downloading segments..."
segment_count=0
failed_segments=""

for i in $(seq $SEGMENT_START $SEGMENT_END); do
    segment_file="${SEGMENT_PREFIX}${i}.ts"
    segment_url="$BASE_URL/$segment_file"
    output_path="$WORK_DIR/$segment_file"

    # Skip if already downloaded
    if [ -f "$output_path" ]; then
        log "[$((i - SEGMENT_START + 1))/$((SEGMENT_END - SEGMENT_START + 1))] ✓ Already exists: $segment_file"
        ((segment_count++))
        continue
    fi

    printf "[$((i - SEGMENT_START + 1))/$((SEGMENT_END - SEGMENT_START + 1))] Downloading: $segment_file"

    # Build and execute curl command with optional headers
    CURL_CMD=$(build_curl_command "$output_path" "$segment_url" "$HEADERS_FILE")

    if eval "$CURL_CMD 2>/dev/null"; then
        if [ -f "$output_path" ] && [ -s "$output_path" ]; then
            echo " ✓"
            ((segment_count++))
        else
            echo " ✗ FAILED (empty)"
            failed_segments="$failed_segments $i"
        fi
    else
        echo " ✗ FAILED"
        failed_segments="$failed_segments $i"
    fi
done

log ""
log "Download complete: $segment_count/$((SEGMENT_END - SEGMENT_START + 1)) segments"

if [ -n "$failed_segments" ]; then
    log "⚠ Failed segments:$failed_segments"
fi

# Create concat file for ffmpeg
log ""
log "Creating concat playlist..."
concat_file="$WORK_DIR/concat.txt"
> "$concat_file"

for i in $(seq $SEGMENT_START $SEGMENT_END); do
    segment_file="${SEGMENT_PREFIX}${i}.ts"
    echo "file '$WORK_DIR/$segment_file'" >> "$concat_file"
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

if ffmpeg -f concat -safe 0 -i "$concat_file" -c copy -y "$OUTPUT_FILE" 2>&1 | \
    grep -E "^(frame=|Duration:|size=|bitrate=)" | tail -5; then

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
        log "Done! Your video is ready: $OUTPUT_FILE"
    else
        log "Temporary files saved in: $WORK_DIR"
    fi
else
    error "Failed to merge segments with ffmpeg"
fi
