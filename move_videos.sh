#!/bin/bash
# Move found videos to destination folder

source "$(dirname "$0")/config.sh"

log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    fi
}

error() {
    echo "[ERROR] $1" >&2
}

results_file="$TEMP_DIR/found_videos.txt"

# Check if results file exists
if [ ! -f "$results_file" ]; then
    error "No results file found. Run find_videos.sh first"
    exit 1
fi

# Check if destination exists
if [ ! -d "$DESTINATION_PATH" ]; then
    log "Creating destination directory: $DESTINATION_PATH"
    mkdir -p "$DESTINATION_PATH" || {
        error "Failed to create destination directory"
        exit 1
    }
fi

log "Moving videos to: $DESTINATION_PATH"
log "==============================================="

moved_count=0
skipped_count=0
failed_count=0

while IFS= read -r source_file; do
    if [ -z "$source_file" ]; then
        continue
    fi

    if [ ! -f "$source_file" ]; then
        error "Source file not found: $source_file"
        ((failed_count++))
        continue
    fi

    # Generate destination filename
    # Use hash of source path to create unique name (in case of duplicates)
    file_hash=$(echo -n "$source_file" | md5sum | cut -d' ' -f1 | head -c 8)
    dest_filename="video_${file_hash}_$(date +%s).mp4"
    dest_file="$DESTINATION_PATH/$dest_filename"

    # Check if file already exists at destination
    if [ -f "$dest_file" ]; then
        log "Skipping (already exists): $source_file"
        ((skipped_count++))
        continue
    fi

    log "Moving: $source_file"
    log "     to: $dest_file"

    if cp "$source_file" "$dest_file" 2>/dev/null; then
        log "Successfully copied to $dest_file"
        ((moved_count++))
    else
        error "Failed to copy: $source_file"
        ((failed_count++))
    fi
done < "$results_file"

log "==============================================="
log "Move Summary:"
log "  Moved:   $moved_count files"
log "  Skipped: $skipped_count files (already exist)"
log "  Failed:  $failed_count files"
log "==============================================="

if [ "$moved_count" -gt 0 ]; then
    log "Videos saved to: $DESTINATION_PATH"
    ls -lh "$DESTINATION_PATH" | tail -n "$moved_count"
fi
