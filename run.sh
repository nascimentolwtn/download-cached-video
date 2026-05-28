#!/bin/bash
# Main orchestration script to find and move cached videos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     Download Cached Video - Brave Browser Cache Extractor    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  find      - Find video files in Brave cache"
    echo "  move      - Move found videos to destination"
    echo "  all       - Run find and move (recommended)"
    echo "  clean     - Clean temporary files"
    echo "  config    - Show current configuration"
    echo "  help      - Show this help message"
    echo ""
}

print_config() {
    echo "Current Configuration:"
    echo "  Brave Cache:     $BRAVE_CACHE_PATH"
    echo "  Destination:     $DESTINATION_PATH"
    echo "  Video Types:     ${VIDEO_EXTENSIONS[@]}"
    echo "  Min File Size:   ${MIN_FILE_SIZE}MB"
    echo "  Max File Size:   ${MAX_FILE_SIZE}MB (0 = no limit)"
    echo "  Temp Directory:  $TEMP_DIR"
    echo ""
}

case "${1:-help}" in
    find)
        print_header
        echo "Step 1: Scanning for video files..."
        echo ""
        bash "$SCRIPT_DIR/find_videos.sh"
        ;;
    move)
        print_header
        echo "Step 2: Moving found videos..."
        echo ""
        bash "$SCRIPT_DIR/move_videos.sh"
        ;;
    all)
        print_header
        print_config
        echo "Running complete extraction..."
        echo ""
        bash "$SCRIPT_DIR/find_videos.sh" && bash "$SCRIPT_DIR/move_videos.sh"
        ;;
    clean)
        print_header
        echo "Cleaning temporary files..."
        rm -rf "$TEMP_DIR"
        echo "Done!"
        ;;
    config)
        print_header
        print_config
        ;;
    help|--help|-h)
        print_header
        print_usage
        ;;
    *)
        echo "Unknown command: $1"
        print_usage
        exit 1
        ;;
esac
