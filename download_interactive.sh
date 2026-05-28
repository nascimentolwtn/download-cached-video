#!/bin/bash
# Interactive Kiwify video downloader with resolution selection

set -o pipefail

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        Kiwify Video Downloader - Interactive Mode             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_methods() {
    echo "How would you like to provide the video information?"
    echo ""
    echo "1. I have the m3u8 playlist URL (easiest)"
    echo "2. I exported Network tab as HAR file"
    echo "3. I have the base CloudFront URL and segment info (manual)"
    echo ""
    read -p "Choose method (1-3): " method

    case $method in
        1) method_m3u8_url ;;
        2) method_har_file ;;
        3) method_manual ;;
        *) error "Invalid choice" ;;
    esac
}

method_m3u8_url() {
    echo ""
    read -p "Paste the m3u8 URL: " m3u8_url

    if [ -z "$m3u8_url" ]; then
        error "No URL provided"
    fi

    log "Analyzing m3u8 file..."
    python3 "$(dirname "$0")/get_resolutions.py" "$m3u8_url"

    if [ ! -f "variants.json" ]; then
        error "Failed to parse m3u8"
    fi

    # Let user choose resolution
    choose_resolution
}

method_har_file() {
    echo ""
    read -p "Path to HAR file: " har_file

    if [ ! -f "$har_file" ]; then
        error "File not found: $har_file"
    fi

    log "Extracting m3u8 from HAR..."
    python3 "$(dirname "$0")/extract_m3u8_from_har.py" "$har_file"

    if [ ! -f "m3u8_urls.txt" ]; then
        error "No m3u8 found in HAR"
    fi

    # Show URLs and let user pick
    echo ""
    mapfile -t urls < m3u8_urls.txt
    if [ ${#urls[@]} -eq 1 ]; then
        m3u8_url="${urls[0]}"
        log "Found m3u8: $m3u8_url"
    else
        echo "Found ${#urls[@]} playlists:"
        for i in "${!urls[@]}"; do
            echo "$((i+1)). ${urls[i]}"
        done
        read -p "Choose which one (1-${#urls[@]}): " choice
        m3u8_url="${urls[$((choice-1))]}"
    fi

    log "Analyzing: $m3u8_url"
    python3 "$(dirname "$0")/get_resolutions.py" "$m3u8_url"
    choose_resolution
}

method_manual() {
    echo ""
    read -p "CloudFront base URL: " base_url
    read -p "Segment prefix (e.g., video_id-1080p): " prefix
    read -p "Start segment (usually 0): " start
    read -p "End segment (highest number): " end

    log "Configuration:"
    echo "  Base URL: $base_url"
    echo "  Prefix: $prefix"
    echo "  Range: $start-$end"
    echo ""

    download_segments "$base_url" "$prefix" "$start" "$end"
}

choose_resolution() {
    echo ""
    read -p "Enter resolution to download (e.g., 1920x1080, 1280x720): " resolution

    # Parse variants.json to get the selected resolution
    base_url=$(python3 -c "
import json
import sys

with open('variants.json') as f:
    variants = json.load(f)

for v in variants:
    if v.get('resolution') == '$resolution':
        print(v.get('url', ''))
        break
")

    if [ -z "$base_url" ]; then
        error "Resolution not found. Check variants.json"
    fi

    # Extract components from variant playlist URL
    log "Fetching variant playlist: $base_url"
    variant_content=$(curl -s "$base_url")

    # Parse for segment info
    segment_file=$(echo "$variant_content" | grep "\.ts" | head -1)
    if [ -z "$segment_file" ]; then
        error "Could not find segments in playlist"
    fi

    # Count total segments
    segment_count=$(echo "$variant_content" | grep -c "\.ts" || echo "unknown")
    log "Found $segment_count segments"

    # Extract base and prefix from segment filename
    segment_base="${segment_file%.*}"
    segment_prefix="${segment_base%[0-9]*}"

    # Find first and last segment numbers
    first_segment=$(echo "$variant_content" | grep "\.ts" | head -1 | sed 's/.*\([0-9]\+\)\.ts/\1/')
    last_segment=$(echo "$variant_content" | grep "\.ts" | tail -1 | sed 's/.*\([0-9]\+\)\.ts/\1/')

    # Extract base CloudFront URL
    cf_base=$(echo "$base_url" | sed 's/\/[^/]*\.m3u8$//')

    log "Segment info:"
    echo "  Base: $cf_base"
    echo "  Prefix: $segment_prefix"
    echo "  Range: $first_segment-$last_segment"
    echo ""

    download_segments "$cf_base" "$segment_prefix" "$first_segment" "$last_segment" "$resolution"
}

download_segments() {
    local base_url="$1"
    local prefix="$2"
    local start="$3"
    local end="$4"
    local resolution="${5:-1080p}"

    bash "$(dirname "$0")/download_hls.sh" \
        -u "$base_url" \
        -p "$prefix" \
        -s "$start" \
        -e "$end" \
        -o "video_${resolution}.mp4"
}

main() {
    print_header
    show_methods
}

main
