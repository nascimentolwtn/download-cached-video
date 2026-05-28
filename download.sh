#!/bin/bash
# Unified Kiwify video downloader - supports HAR or HTML input

set -o pipefail

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

print_usage() {
    cat << EOF
Kiwify Video Downloader - Automatic Resolution Selection

USAGE:
  $0 --har <file.har>              Extract m3u8 from DevTools HAR export
  $0 --html '<video>...</video>'   Extract m3u8 from HTML video element
  $0 --url <m3u8_url>              Direct m3u8 playlist URL

EXAMPLES:
  # From HAR file
  $0 --har network.har

  # From HTML (copy from page source)
  $0 --html '<video src="blob:..." poster="..."></video>'

  # Direct URL
  $0 --url "https://example.com/playlist.m3u8"

HOW TO GET HAR FILE:
  1. Open DevTools (F12)
  2. Network tab
  3. Right-click → Save all as HAR with content
  4. Run: $0 --har <saved_file>

HOW TO GET HTML ELEMENT:
  1. Open DevTools (F12)
  2. Elements/Inspector tab
  3. Find <video> element with the player
  4. Right-click → Copy element
  5. Run: $0 --html '<paste_here>'
EOF
}

method_har() {
    local har_file="$1"

    if [ ! -f "$har_file" ]; then
        error "HAR file not found: $har_file"
    fi

    log "Extracting m3u8 from HAR file: $har_file"

    # Extract headers for authentication
    HEADERS_FILE="/tmp/har_headers_$$.json"
    python3 "$(dirname "$0")/extract_headers_from_har.py" "$har_file" "cloudfront" > "$HEADERS_FILE" 2>/dev/null

    if [ -s "$HEADERS_FILE" ]; then
        log "Extracted auth headers from HAR"
    fi

    # Use Python to extract m3u8 URLs
    m3u8_urls=$(python3 << PYTHON
import json
import sys

try:
    with open("$har_file", 'r') as f:
        har_data = json.load(f)
except:
    print("")
    sys.exit(1)

entries = har_data.get('log', {}).get('entries', [])

# Look for m3u8 requests (by URL or MIME type)
found_urls = set()
for entry in entries:
    url = entry.get('request', {}).get('url', '')
    mime_type = entry.get('response', {}).get('content', {}).get('mimeType', '')

    if '.m3u8' in url or 'application/vnd.apple.mpegurl' in mime_type:
        found_urls.add(url)

for url in sorted(found_urls):
    print(url)
PYTHON
    )

    if [ -z "$m3u8_urls" ]; then
        error "No m3u8 playlist found in HAR file"
    fi

    # Handle multiple m3u8 files
    mapfile -t m3u8_array <<< "$m3u8_urls"

    if [ ${#m3u8_array[@]} -eq 1 ]; then
        m3u8_url="${m3u8_array[0]}"
        log "Found m3u8: $m3u8_url"
    else
        echo ""
        echo "Found ${#m3u8_array[@]} playlist variants:"
        for i in "${!m3u8_array[@]}"; do
            echo "$((i+1)). ${m3u8_array[$i]##*/}"
        done
        echo ""

        # Look for master playlist (to show all resolutions)
        m3u8_url=""
        for url in "${m3u8_array[@]}"; do
            if [[ "$url" == *"master"* ]]; then
                m3u8_url="$url"
                log "Found master playlist: $m3u8_url"
                break
            fi
        done

        # If no master, ask user which variant to use
        if [ -z "$m3u8_url" ]; then
            echo ""
            echo "Multiple quality options available:"
            for i in "${!m3u8_array[@]}"; do
                # Extract resolution from URL
                res=$(echo "${m3u8_array[$i]}" | grep -oP '\d+p' || echo "unknown")
                echo "$((i+1)). ${m3u8_array[$i]##*/} ($res)"
            done
            echo ""
            read -p "Choose which quality to download (1-${#m3u8_array[@]}): " choice
            choice=$((choice - 1))
            if [ $choice -lt 0 ] || [ $choice -ge ${#m3u8_array[@]} ]; then
                error "Invalid choice"
            fi
            m3u8_url="${m3u8_array[$choice]}"
            log "Selected: $m3u8_url"
        fi
    fi

    download_with_resolution_selection "$m3u8_url" "auto" "$HEADERS_FILE"

    # Cleanup
    [ -f "$HEADERS_FILE" ] && rm -f "$HEADERS_FILE"
}

method_html() {
    local html_element="$1"

    log "Analyzing HTML video element..."

    # Extract blob URL from src attribute
    blob_url=$(echo "$html_element" | grep -oP 'src="\Kblob:[^"]+' || true)

    if [ -z "$blob_url" ]; then
        # Try data attributes
        blob_url=$(echo "$html_element" | grep -oP 'blob:[^\s"]+' | head -1 || true)
    fi

    if [ -z "$blob_url" ]; then
        error "Could not find blob URL in HTML element"
    fi

    log "Found blob URL: $blob_url"
    log "Note: Blob URLs are temporary. You may need to:"
    log "  1. Keep the video page open"
    log "  2. Or find the actual m3u8 URL in Network tab instead"
    log ""

    # Try to extract base URL from HTML (sometimes data-src or other attributes)
    echo "Would you like to:"
    echo "1. Continue with blob URL (browser needed)"
    echo "2. Provide the actual m3u8 URL instead"
    read -p "Choose (1-2): " choice

    if [ "$choice" = "2" ]; then
        read -p "Paste the m3u8 URL: " m3u8_url
        [ -n "$m3u8_url" ] && download_with_resolution_selection "$m3u8_url" || error "No URL provided"
    else
        log "For blob URLs, you need to:"
        log "1. Keep DevTools open with Network tab"
        log "2. Watch for .m3u8 requests as video loads"
        log "3. Copy the m3u8 URL from the request"
        error "Please provide the actual m3u8 URL instead"
    fi
}

method_url() {
    local m3u8_url="$1"

    log "Using m3u8 URL: $m3u8_url"
    download_with_resolution_selection "$m3u8_url"
}

download_with_resolution_selection() {
    local m3u8_url="$1"
    local auto_mode="${2:-}"  # 'auto' for HAR mode
    local headers_file="${3:-}"  # Optional headers JSON file

    # Create temp directory
    TEMP_DIR="/tmp/kiwify_$$"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    log "Fetching playlist..."
    m3u8_content=$(curl -s "$m3u8_url" 2>/dev/null || echo "")

    if [ -z "$m3u8_content" ]; then
        error "Failed to fetch m3u8 file. URL may be invalid or expired."
    fi

    # Check if it's a master playlist (multiple variants) or direct segment list
    if echo "$m3u8_content" | grep -q "EXT-X-STREAM-INF"; then
        log "Master playlist detected (multiple resolutions)"
        show_resolution_options "$m3u8_url" "$m3u8_content" "$auto_mode" "$headers_file"
    else
        log "Single-stream playlist detected"
        # Parse base URL and segment info
        download_direct "$m3u8_url" "$m3u8_content" "" "$headers_file"
    fi
}

show_resolution_options() {
    local master_url="$1"
    local master_content="$2"
    local auto_choice="${3:-}"  # Optional: auto-select resolution
    local headers_file="${4:-}"  # Optional: headers JSON file

    # Parse variants
    echo ""
    echo "Available Resolutions:"
    echo "====================="

    local -a resolutions
    local -a urls
    local count=0

    while IFS= read -r line; do
        if [[ $line =~ RESOLUTION=([0-9]+x[0-9]+) ]]; then
            res="${BASH_REMATCH[1]}"
            resolutions+=("$res")
            ((count++))
            echo "$count. $res"
        fi
    done <<< "$master_content"

    if [ $count -eq 0 ]; then
        error "Could not parse resolutions from playlist"
    fi

    # Always ask user to choose resolution
    read -p "Choose resolution (1-$count): " choice
    choice=$((choice - 1))

    if [ $choice -lt 0 ] || [ $choice -ge $count ]; then
        error "Invalid choice"
    fi

    variant_res="${resolutions[$choice]}"
    log "Downloading: $variant_res"

    # Extract variant playlist URL (next non-comment line after STREAM-INF)
    local in_stream_inf=0
    local variant_playlist=""

    while IFS= read -r line; do
        if [[ $line =~ RESOLUTION=$variant_res ]]; then
            in_stream_inf=1
        elif [ $in_stream_inf -eq 1 ] && [[ ! $line =~ ^# ]]; then
            variant_playlist="$line"
            break
        fi
    done <<< "$master_content"

    if [ -z "$variant_playlist" ]; then
        error "Could not find variant playlist URL"
    fi

    # Resolve relative URL
    if [[ ! "$variant_playlist" =~ ^http ]]; then
        base_url=$(echo "$master_url" | sed 's|/[^/]*$|/|')
        variant_playlist="${base_url}${variant_playlist}"
    fi

    log "Fetching variant playlist: $variant_playlist"
    variant_content=$(curl -s "$variant_playlist")

    download_direct "$variant_playlist" "$variant_content" "$variant_res" "$headers_file"
}

download_direct() {
    local playlist_url="$1"
    local playlist_content="$2"
    local resolution="${3:-1080p}"
    local headers_file="${4:-}"

    # Extract base URL
    base_url=$(echo "$playlist_url" | sed 's|/[^/]*$|/|')

    # Parse segment info
    local -a segments
    while IFS= read -r line; do
        if [[ $line =~ \.ts$ ]]; then
            segments+=("$line")
        fi
    done <<< "$playlist_content"

    if [ ${#segments[@]} -eq 0 ]; then
        error "No video segments found in playlist"
    fi

    log "Found ${#segments[@]} segments"

    # Extract segment naming pattern
    first_segment="${segments[0]}"
    last_segment="${segments[-1]}"

    # Extract numeric indices
    first_num=$(echo "$first_segment" | grep -oP '\d+(?=\.ts)' | tail -1)
    last_num=$(echo "$last_segment" | grep -oP '\d+(?=\.ts)' | tail -1)

    # Extract prefix (everything before the last number)
    prefix=$(echo "$first_segment" | sed "s/${first_num}\.ts//")

    log "Segment pattern: ${prefix}[${first_num}-${last_num}].ts"
    log ""

    # Now use the main download script
    cd - > /dev/null

    # Build command with optional headers
    local cmd="bash \"$(dirname "$0")/download_hls.sh\" -u \"$base_url\" -p \"$prefix\" -s \"$first_num\" -e \"$last_num\" -o \"video_${resolution}.mp4\""
    if [ -n "$headers_file" ] && [ -f "$headers_file" ]; then
        cmd="$cmd -H \"$headers_file\""
    fi
    eval "$cmd"

    # Cleanup temp directory
    rm -rf "$TEMP_DIR"
}

# Main
if [ $# -eq 0 ]; then
    print_usage
    exit 0
fi

case "$1" in
    --har)
        [ -z "$2" ] && error "HAR file not specified"
        method_har "$2"
        ;;
    --html)
        [ -z "$2" ] && error "HTML element not specified"
        method_html "$2"
        ;;
    --url)
        [ -z "$2" ] && error "URL not specified"
        method_url "$2"
        ;;
    --help|-h)
        print_usage
        ;;
    *)
        error "Unknown option: $1. Use --help for usage."
        ;;
esac
