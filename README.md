# Download Cached Video

A utility to recover and preserve videos you've already watched from your browser's cache, saving them to your file system for permanent storage.

## Goal

When you watch videos online through a web browser, the video files are typically cached locally on your computer for smooth playback. However, these cached files are usually temporary and can be deleted by the browser at any time. This project aims to:

- **Locate** video files stored in your browser's cache directory
- **Extract** these cached videos to prevent them from being lost
- **Organize** and move them to a permanent location (e.g., Downloads folder)

## Why?

- **Preserve content** you want to keep but may lose if the cache is cleared
- **Save bandwidth** by using existing cached files instead of re-downloading
- **Backup videos** from sources that may have restrictions on downloads
- **Organize media** in your file system for easy access

## Use Cases

- Save educational videos you've watched and want to reference later
- Create backups of video content before cache cleanup

## Architecture

The project uses a modular approach combining **Bash** and **Python**:

- **`config.sh`** - Centralized configuration (paths, file types, constraints)
- **`find_videos.sh`** - Scans Brave cache for video files using magic byte detection
- **`move_videos.sh`** - Safely moves videos with deduplication
- **`detect_video.py`** - Python utility for intelligent file type detection
- **`run.sh`** - Main orchestration script

## Installation

### Requirements
- WSL2 with Ubuntu
- Bash 4+
- Basic utilities: `find`, `file`, `stat`
- Python 3.6+ (optional, for enhanced detection)

### Setup

1. Clone or download this repository:
```bash
cd ~/git/download-cached-video
```

2. Make scripts executable:
```bash
chmod +x run.sh find_videos.sh move_videos.sh
chmod +x detect_video.py
```

3. Edit `config.sh` if your paths differ:
```bash
nano config.sh
```

## Usage

### Quick Start (Recommended)
```bash
./run.sh all
```
This finds and moves all videos in one command.

### Step-by-Step

**1. Find videos:**
```bash
./run.sh find
```
This scans the Brave cache and lists all found video files.

**2. Review results:**
Results are saved in `/tmp/brave_video_cache/found_videos.txt`. Review before moving.

**3. Move videos:**
```bash
./run.sh move
```
Copies found videos to `/mnt/e/temp/_08_Videos`

### Other Commands
```bash
./run.sh config    # Show current configuration
./run.sh clean     # Clean temporary files
./run.sh help      # Show help
```

## How It Works

1. **Finding:** Searches Brave cache directory for files with video extensions (.mp4, .webm, .m4s, .ts, .mkv)
2. **Detection:** Verifies files are actually videos using:
   - Magic byte analysis (file signatures)
   - `file` command for additional verification
   - Optional ffprobe for detailed inspection
3. **Moving:** Safely copies videos with:
   - Unique naming to avoid duplicates
   - Size validation (skip files too small or too large)
   - Error handling and logging

## Configuration

Edit `config.sh` to customize:

```bash
# Brave cache path (Windows mounted in WSL)
BRAVE_CACHE_PATH="/mnt/c/Users/lw_na/AppData/Local/BraveSoftware/Brave-Browser/User Data/Default"

# Where to save recovered videos
DESTINATION_PATH="/mnt/e/temp/_08_Videos"

# Minimum file size to consider (MB)
MIN_FILE_SIZE=1

# Maximum file size (0 = no limit)
MAX_FILE_SIZE=0

# Enable verbose logging
VERBOSE=true
```

## Security & Safety

- ✅ Read-only scanning (doesn't modify cache)
- ✅ Copies files instead of moving (preserves cache)
- ✅ Deduplication (won't re-save the same file)
- ✅ Size validation (filters corrupted files)
- ✅ Comprehensive error handling and logging

## Troubleshooting

**"Brave cache path not found"**
- Verify the path in `config.sh` exists on your Windows system
- Check that Brave has cached data there

**"No video files found"**
- Ensure you've watched videos in Brave (they need to be cached)
- Increase `MIN_FILE_SIZE` or check cache manually

**"Permission denied"**
- Ensure destination directory is writable
- May need to run with appropriate permissions for NTFS mounts

## Supported Browsers

Currently supports:
- **Brave** (primary)
- Can be adapted for Chrome (same cache structure)

## Future Enhancements

- GUI interface for easier operation
- Video metadata preservation (title, timestamp)
- Integration with video organization tools
- Batch scheduling for automatic extraction
- Support for other browsers (Firefox, Edge, Safari)