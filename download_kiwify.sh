#!/bin/bash
# Download Kiwify HLS video segments and merge into MP4

set -o pipefail

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Configuration
BASE_URL="https://d3pjuhbfoxhm7c.cloudfront.net/4yxxwWrGN5h30Ed/2026/04/15/8c71eaf3-ce15-4032-a55e-f4c7ccf6b0d2"
SEGMENT_BASE="8c71eaf3-ce15-4032-a55e-f4c7ccf6b0d2-1080p"
SEGMENT_START=0
SEGMENT_END=55
OUTPUT_FILE="kiwify_video.mp4"

# Create working directory
WORK_DIR="./kiwify_download"
mkdir -p "$WORK_DIR"

log "==============================================="
log "Kiwify Video Downloader"
log "==============================================="
log "Base URL: $BASE_URL"
log "Segments: $SEGMENT_START to $SEGMENT_END (total: $((SEGMENT_END - SEGMENT_START + 1)))"
log "Working directory: $WORK_DIR"
log ""

# Download all segments
log "Downloading segments..."
segment_count=0
failed_count=0

for i in $(seq $SEGMENT_START $SEGMENT_END); do
    segment_file="$SEGMENT_BASE$i.ts"
    segment_url="$BASE_URL/$segment_file"
    output_path="$WORK_DIR/$segment_file"

    # Skip if already downloaded
    if [ -f "$output_path" ]; then
        log "[$((i - SEGMENT_START + 1))/$((SEGMENT_END - SEGMENT_START + 1))] Already exists: $segment_file"
        ((segment_count++))
        continue
    fi

    log "[$((i - SEGMENT_START + 1))/$((SEGMENT_END - SEGMENT_START + 1))] Downloading: $segment_file"

    if curl -s -L --max-time 30 -o "$output_path" \
        -H "referer: https://members.kiwify.com/" \
        -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "$segment_url" 2>/dev/null; then
        if [ -f "$output_path" ] && [ -s "$output_path" ]; then
            ((segment_count++))
        else
            echo "  ⚠ Empty file for segment $i"
            rm -f "$output_path"
            ((failed_count++))
        fi
    else
        echo "  ⚠ Failed to download segment $i"
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
log "Creating ffmpeg concat file..."
concat_file="$WORK_DIR/concat.txt"
> "$concat_file"

for i in $(seq $SEGMENT_START $SEGMENT_END); do
    segment_file="$SEGMENT_BASE$i.ts"
    echo "file '$segment_file'" >> "$concat_file"
done

# Merge segments with ffmpeg
log "Merging segments into MP4..."
log "This may take a minute or two..."
log ""

# Run ffmpeg from the work directory for correct relative paths
(cd "$WORK_DIR" && ffmpeg -f concat -safe 0 -i concat.txt -c copy -y "../$OUTPUT_FILE" 2>&1) | grep -E "^(frame=|Duration:|size=|output)" || true

    log ""
    log "✓ Successfully created: $OUTPUT_FILE"

    # Show file info
    if command -v ffprobe &> /dev/null; then
        log ""
        log "Video information:"
        ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height,r_frame_rate,duration \
            -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null | awk '{print "  " $0}' || true

        size=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        log "  File size: $size"
    fi

    # Cleanup
    log ""
    read -p "Delete temporary files? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Cleaning up..."
        rm -rf "$WORK_DIR"
        log "Done! Video is ready: $OUTPUT_FILE"
    else
        log "Temporary files saved in: $WORK_DIR"
    fi
else
    error "Failed to create video file"
fi
