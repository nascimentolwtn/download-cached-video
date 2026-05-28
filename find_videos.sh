#!/bin/bash
# Find video files in Brave browser cache

source "$(dirname "$0")/config.sh"

log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    fi
}

error() {
    echo "[ERROR] $1" >&2
}

# Check if cache path exists
if [ ! -d "$BRAVE_CACHE_PATH" ]; then
    error "Brave cache path not found: $BRAVE_CACHE_PATH"
    exit 1
fi

log "Scanning Brave cache: $BRAVE_CACHE_PATH"
log "Looking for video files..."

# Create temporary directory
mkdir -p "$TEMP_DIR"
results_file="$TEMP_DIR/found_videos.txt"
> "$results_file"  # Clear previous results

video_count=0

# Search for video files
for ext in "${VIDEO_EXTENSIONS[@]}"; do
    log "Searching for .$ext files..."

    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi

        # Get file size in MB
        size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_mb=$((size_bytes / 1048576))

        # Check size constraints
        if [ "$MAX_FILE_SIZE" -gt 0 ] && [ "$size_mb" -gt "$MAX_FILE_SIZE" ]; then
            log "Skipping (too large): $file ($size_mb MB)"
            continue
        fi

        if [ "$size_mb" -lt "$MIN_FILE_SIZE" ]; then
            log "Skipping (too small): $file ($size_mb MB)"
            continue
        fi

        # Verify it's actually a video file using 'file' command
        file_type=$(file -b "$file" 2>/dev/null)
        if echo "$file_type" | grep -qi "video\|mp4\|mpeg\|quicktime"; then
            echo "$file" >> "$results_file"
            log "Found: $file ($size_mb MB)"
            ((video_count++))
        fi
    done < <(find "$BRAVE_CACHE_PATH" -type f -name "*.$ext" 2>/dev/null)
done

# Also search for files without extension that are actually videos
log "Searching for files without extension..."
while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi

    # Skip if already found
    if grep -q "^$file$" "$results_file" 2>/dev/null; then
        continue
    fi

    # Get file size
    size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    size_mb=$((size_bytes / 1048576))

    # Check size constraints
    if [ "$size_mb" -lt "$MIN_FILE_SIZE" ]; then
        continue
    fi

    # Check if it's a video file
    file_type=$(file -b "$file" 2>/dev/null)
    if echo "$file_type" | grep -qi "video\|mp4\|mpeg"; then
        echo "$file" >> "$results_file"
        log "Found: $file ($size_mb MB)"
        ((video_count++))
    fi
done < <(find "$BRAVE_CACHE_PATH" -type f ! -name "*.*" 2>/dev/null)

log "==============================================="
log "Found $video_count video file(s)"
log "Results saved to: $results_file"
log "==============================================="

if [ "$video_count" -gt 0 ]; then
    log "Files to be moved:"
    cat "$results_file" | nl
    exit 0
else
    log "No video files found"
    exit 1
fi
