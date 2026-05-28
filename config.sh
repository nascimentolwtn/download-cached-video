#!/bin/bash
# Configuration for Download Cached Video

# Brave browser cache directory (Windows mounted in WSL)
BRAVE_CACHE_PATH="/mnt/c/Users/lw_na/AppData/Local/BraveSoftware/Brave-Browser/User Data/Default"

# Destination folder for recovered videos
DESTINATION_PATH="/mnt/e/temp/_08_Videos"

# Video extensions to look for
VIDEO_EXTENSIONS=("mp4" "webm" "m4s" "ts" "mkv")

# Temporary working directory for processing
TEMP_DIR="/tmp/brave_video_cache"

# Enable verbose output (true/false)
VERBOSE=true

# Max file size to consider (in MB, 0 = no limit)
MAX_FILE_SIZE=0

# Min file size to consider (in MB, helps filter out junk)
MIN_FILE_SIZE=1
