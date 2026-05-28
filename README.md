# Kiwify Video Downloader

Download HLS video streams from Kiwify using HAR files captured from Chrome DevTools.

## Overview

This tool allows you to:
- 📹 Capture Kiwify video network traffic using Chrome DevTools
- 💾 Save complete HAR (HTTP Archive) files with authentication headers
- 🎬 Download all video segments at your preferred resolution
- 🔗 Automatically merge segments into a single MP4 file

## Quick Start

### 1. Capture Video in Chrome DevTools

```bash
# On Kiwify member page:
1. Open DevTools (F12)
2. Go to Network tab
3. Play the video (30+ seconds recommended)
4. Right-click in Network tab → Save all as HAR
5. Save file as: video.har
```

### 2. Download Video

```bash
./download.sh --har /path/to/video.har
```

Select your preferred resolution:
```
Available Resolutions:
=====================
1. 640x360
2. 456x256
3. 854x480
4. 1280x720
5. 1920x1080

Select resolution [1-5]: 3
```

Script will:
- ✓ Download all segments
- ✓ Extract authentication from HAR
- ✓ Merge into MP4 file
- ✓ Show video information

### 3. Output

Video saved as: `video_854x480.mp4` (or your selected resolution)

## Requirements

- **Chrome/Brave/Edge** (for DevTools HAR capture)
- **curl** (for downloading segments)
- **ffmpeg** (for merging segments)
- **Python 3** (for header parsing)
- **jq** (for JSON processing)

### Install Dependencies

**Linux:**
```bash
sudo apt-get install curl ffmpeg python3 jq
```

**macOS:**
```bash
brew install curl ffmpeg python3 jq
```

## How It Works

1. **HAR Capture** - Chrome DevTools saves all network traffic including:
   - Video segment URLs
   - Authentication headers
   - Cookie information
   
2. **Parsing** - Script extracts:
   - Master playlist from HAR
   - Available resolutions
   - Segment URLs and ranges

3. **Downloading** - Downloads all segments using:
   - Original auth headers from HAR
   - Cookies for authenticated access
   
4. **Merging** - Uses ffmpeg to combine segments:
   - Preserves video quality
   - Creates standard MP4 file

## File Structure

```
.
├── download.sh              # Main download script
├── README.md               # This file
└── hls_download_*/         # Temporary segment directories
    ├── [segments].ts       # Video segment files
    └── concat.txt          # ffmpeg concat playlist
```

## Features

✅ **Complete HAR Support** - Works with full Chrome DevTools HAR files  
✅ **Multiple Resolutions** - Download at quality you prefer  
✅ **Authentication** - Automatically uses headers from HAR  
✅ **Quality Verification** - Shows final video information  
✅ **Cleanup Options** - Automatic removal of temp files  
✅ **Error Handling** - Robust segment validation  

## Troubleshooting

### "No HLS segments found"
- Ensure video actually played in DevTools during capture
- Play video for at least 30 seconds before capturing HAR

### "Failed to download segments"
- HAR file may be too old (auth tokens expire)
- Capture a fresh HAR file
- Check internet connection

### "ffmpeg not found"
```bash
# Install ffmpeg
sudo apt-get install ffmpeg  # Linux
brew install ffmpeg          # macOS
```

### "jq not found"
```bash
# Install jq
sudo apt-get install jq      # Linux
brew install jq              # macOS
```

## Limitations

- ⚠️ Kiwify member account required
- ⚠️ HAR files expire (re-capture if download fails)
- ⚠️ Only HLS video streams supported
- ⚠️ Video resolution depends on what's streamed

## Usage Examples

### Download 480p (854x480) resolution
```bash
./download.sh --har video.har
# Select option 3
```

### Download highest quality (1920x1080)
```bash
./download.sh --har video.har
# Select option 5
```

### Download to custom filename
The script auto-names based on resolution, e.g:
- `video_456x256.mp4` (456x256)
- `video_854x480.mp4` (854x480)  
- `video_1920x1080.mp4` (1920x1080)

## Legal Notice

This tool is for personal use only. Respect:
- Content creator rights
- Kiwify terms of service
- Local copyright laws

## Support

For issues:
1. Verify Chrome DevTools HAR capture worked
2. Check that ffmpeg/curl are installed
3. Try capturing a fresh HAR file
4. Verify internet connection

## License

Personal use only
