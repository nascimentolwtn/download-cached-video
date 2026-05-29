#!/bin/bash
# DASH video downloader and merger

set -e

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Parse arguments
har_file=""
selected_res=""
headers_file=""
output_dir=""
output_filename=""

while getopts "h:r:H:o:n:" opt; do
    case $opt in
        h) har_file="$OPTARG" ;;
        r) selected_res="$OPTARG" ;;
        H) headers_file="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        n) output_filename="$OPTARG" ;;
        *) error "Unknown option: -$OPTARG" ;;
    esac
done

if [ -z "$har_file" ] || [ -z "$selected_res" ]; then
    error "Missing required parameters (-h HAR file, -r resolution)"
fi

if [ ! -f "$har_file" ]; then
    error "HAR file not found: $har_file"
fi

# Convert HAR file path to absolute
har_file="$(cd "$(dirname "$har_file")" && pwd)/$(basename "$har_file")"

# Ensure output directory exists
if [ -n "$output_dir" ]; then
    mkdir -p "$output_dir"
else
    output_dir="."
fi

# Get script directory and original directory BEFORE changing directories
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
original_dir="$PWD"

# Create working directory
work_dir="/tmp/dash_download_$$"
mkdir -p "$work_dir"
cd "$work_dir"

log "Working directory: $work_dir"

# Extract segment URLs directly from HAR file
log "Extracting segments from HAR file..."
python3 "$script_dir/extract_dash_segments_from_har.py" "$har_file" "$selected_res" > segments.txt

if [ ! -s segments.txt ]; then
    error "No segments found in HAR for resolution $selected_res"
fi

# Parse segment list
video_urls=()
audio_urls=()

while IFS= read -r line; do
    if [[ "$line" == V:* ]]; then
        video_urls+=("${line:2}")
    elif [[ "$line" == A:* ]]; then
        audio_urls+=("${line:2}")
    fi
done < segments.txt

log "Found ${#video_urls[@]} video segments, ${#audio_urls[@]} audio segments"

# Download video segments
log "Downloading video segments..."
mkdir -p video

for i in "${!video_urls[@]}"; do
    url="${video_urls[$i]}"
    idx=$((i + 1))
    output_file="video/seg_${idx}.mp4"

    echo -n "."

    if [ -f "$headers_file" ]; then
        # Download with headers
        python3 << PYCURL
import json
import subprocess

with open('$headers_file') as f:
    headers = json.load(f)

cmd = ['curl', '-s', '-L', '-m', '30', '--compressed']
for k, v in headers.items():
    cmd.extend(['-H', f'{k}: {v}'])
cmd.extend(['-o', '$output_file', '$url'])

subprocess.run(cmd, check=False)
PYCURL
    else
        curl -s -L -m 30 --compressed -o "$output_file" "$url" 2>/dev/null || true
    fi
done
echo ""

# Check what was actually downloaded
video_total=$(find video -name "seg_*.mp4" -type f -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1} END {print s}')
if [ -z "$video_total" ]; then
    video_total=$(find video -name "seg_*.mp4" -type f -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1} END {print s}')
fi
log "Video segments total size: ${video_total:-0} bytes"

# Download audio segments if present
if [ ${#audio_urls[@]} -gt 0 ]; then
    log "Downloading audio segments..."
    mkdir -p audio

    for i in "${!audio_urls[@]}"; do
        url="${audio_urls[$i]}"
        idx=$((i + 1))
        output_file="audio/seg_${idx}.mp4"

        echo -n "."

        if [ -f "$headers_file" ]; then
            python3 << PYCURL
import json
import subprocess

with open('$headers_file') as f:
    headers = json.load(f)

cmd = ['curl', '-s', '-L', '-m', '30', '--compressed']
for k, v in headers.items():
    cmd.extend(['-H', f'{k}: {v}'])
cmd.extend(['-o', '$output_file', '$url'])

subprocess.run(cmd, check=False)
PYCURL
        else
            curl -s -L -m 30 --compressed -o "$output_file" "$url" 2>/dev/null || true
        fi
    done
    echo ""
fi

# Merge with ffmpeg
log "Merging segments with ffmpeg..."

# Create concat file for video
find video -name "seg_*.mp4" -type f | sort -V | while read f; do
    echo "file '$work_dir/$f'"
done > concat_video.txt

if [ -d audio ] && [ -f audio/seg_1.mp4 ]; then
    # Create concat file for audio
    find audio -name "seg_*.mp4" -type f | sort -V | while read f; do
        echo "file '$work_dir/$f'"
    done > concat_audio.txt

    log "Remuxing video and audio..."
    # DASH MP4 segments are fragmented - concatenate init + media segments properly
    log "⚠ Note: Fixing audio/video sync for fragmented MP4..."
    find video -name "seg_*.mp4" -type f | sort -V | xargs cat > merged_video.m4v
    find audio -name "seg_*.mp4" -type f | sort -V | xargs cat > merged_audio.m4a
    # Use ffmpeg with timing corrections for fragmented MP4 segments
    local output_name="${output_filename}.mp4"
    [ -z "$output_filename" ] && output_name="video_${selected_res}.mp4"
    ffmpeg -fflags +igndts -i merged_video.m4v -fflags +igndts -i merged_audio.m4a -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 "$output_name" -y 2>&1 | grep -v "frame=" | head -5
else
    log "Concatenating video only..."
    # Concatenate DASH MP4 segments with timing correction
    local output_name="${output_filename}.mp4"
    [ -z "$output_filename" ] && output_name="video_${selected_res}.mp4"
    find video -name "seg_*.mp4" -type f | sort -V | xargs cat > "$output_name"
fi

# Output file location
local output_name="${output_filename}.mp4"
[ -z "$output_filename" ] && output_name="video_${selected_res}.mp4"
if [ -f "$output_name" ]; then
    log "✓ Video merged successfully"

    # Determine final output path
    if [[ "$output_dir" = /* ]]; then
        # Absolute path
        final_path="$output_dir/$output_name"
    else
        # Relative path - make it relative to original directory
        final_path="$original_dir/$output_dir/$output_name"
    fi

    # Move to output directory
    mkdir -p "$(dirname "$final_path")"
    if mv "$output_name" "$final_path" 2>/dev/null; then
        log "✓ Output saved: $output_dir/$output_name"
    else
        log "⚠ Output left in: $work_dir/$output_name"
    fi
else
    error "Failed to create output video"
fi

# Cleanup
cd "$original_dir"
log "Cleaning up temporary files..."
rm -rf "$work_dir"

log "✓ Download complete!"
