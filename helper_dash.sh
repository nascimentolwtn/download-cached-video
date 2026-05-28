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
mpd_file=""
manifest_base=""
selected_res=""
headers_file=""
output_dir=""

while getopts "m:b:r:H:o:" opt; do
    case $opt in
        m) mpd_file="$OPTARG" ;;
        b) manifest_base="$OPTARG" ;;
        r) selected_res="$OPTARG" ;;
        H) headers_file="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        *) error "Unknown option: -$OPTARG" ;;
    esac
done

if [ -z "$mpd_file" ] || [ -z "$manifest_base" ] || [ -z "$selected_res" ]; then
    error "Missing required parameters"
fi

# Ensure output directory exists
if [ -n "$output_dir" ]; then
    mkdir -p "$output_dir"
else
    output_dir="."
fi

# Get script directory and original directory BEFORE changing directories
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
original_dir="$PWD"

if [ ! -f "$mpd_file" ]; then
    error "MPD manifest file not found: $mpd_file"
fi

# Create working directory
work_dir="/tmp/dash_download_$$"
mkdir -p "$work_dir"
cd "$work_dir"

log "Working directory: $work_dir"

# Extract segment URLs
log "Parsing DASH manifest..."
python3 "$script_dir/parse_dash_manifest.py" "$mpd_file" "$manifest_base" "$selected_res" > segments.txt

if [ ! -s segments.txt ]; then
    error "No segments found in manifest"
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
    ffmpeg -f concat -safe 0 -i concat_video.txt -f concat -safe 0 -i concat_audio.txt -c copy -map 0 -map 1 "video_${selected_res}.mp4" 2>/dev/null
else
    log "Concatenating video only..."
    ffmpeg -f concat -safe 0 -i concat_video.txt -c copy "video_${selected_res}.mp4" 2>/dev/null
fi

# Output file location
if [ -f "video_${selected_res}.mp4" ]; then
    log "✓ Video merged successfully"

    # Determine final output path
    if [[ "$output_dir" = /* ]]; then
        # Absolute path
        final_path="$output_dir/video_${selected_res}.mp4"
    else
        # Relative path - make it relative to original directory
        final_path="$original_dir/$output_dir/video_${selected_res}.mp4"
    fi

    # Move to output directory
    mkdir -p "$(dirname "$final_path")"
    if mv "video_${selected_res}.mp4" "$final_path" 2>/dev/null; then
        log "✓ Output saved: $output_dir/video_${selected_res}.mp4"
    else
        log "⚠ Output left in: $work_dir/video_${selected_res}.mp4"
    fi
else
    error "Failed to create output video"
fi

# Cleanup
cd "$original_dir"
log "Cleaning up temporary files..."
rm -rf "$work_dir"

log "✓ Download complete!"
