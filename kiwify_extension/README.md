# Kiwify Video Downloader Extension

A Chrome extension that captures HLS video streams from Kiwify member pages and saves them as HAR (HTTP Archive) files for offline processing.

## Features

- **Auto-Detection**: Automatically starts capturing when a video plays on Kiwify
- **HAR Format**: Saves network traffic as standard HAR JSON files
- **Manual Control**: Stop capture and save HAR with extension popup buttons
- **Resolution Support**: Handles multiple video resolutions (240p, 1080p, etc.)
- **Header Preservation**: Captures all HTTP headers needed to download segments

## Installation

1. Open Chrome and go to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top-right)
3. Click "Load unpacked"
4. Select the `kiwify_extension` folder
5. Extension icon should appear in your toolbar

## Usage

### Step 1: Capture HAR File

1. Login to Kiwify and navigate to a video
2. Click the extension icon (blue play button in toolbar)
3. Click "Start Capture" or wait for video to auto-start capturing
4. Play the video for as long as needed
5. When done, click "Stop Capture"
6. Click "Save HAR" - choose where to save the file
7. File will be saved as `kiwify_YYYYMMDDHHMMSS.har`

### Step 2: Download Video

1. Open terminal and go to the extension folder:
   ```bash
   cd /path/to/kiwify_extension
   ```

2. Run the download script:
   ```bash
   ./download_from_har.sh -f kiwify_YYYYMMDDHHMMSS.har
   ```

3. Script will:
   - Parse the HAR file
   - Extract available resolutions (240p, 1080p, etc.)
   - Ask you to select a resolution
   - Download all segments
   - Merge into MP4 using ffmpeg
   - Ask if you want to delete temporary files

4. Your video will be saved as `kiwify_video.mp4` (or custom name with `-o` flag)

### Optional: Custom Output Name

```bash
./download_from_har.sh -f kiwify_20260528123456.har -o my_course_video.mp4
```

## Requirements

### Chrome Extension
- Google Chrome (or Chromium-based browser)
- Logged into Kiwify member account

### Download Script
- Bash shell
- `curl` (usually pre-installed)
- `jq` (JSON parser)
  ```bash
  # Install on Linux
  sudo apt-get install jq

  # Install on macOS
  brew install jq
  ```
- `ffmpeg` (video merger)
  ```bash
  # Install on Linux
  sudo apt-get install ffmpeg

  # Install on macOS
  brew install ffmpeg
  ```
- `python3` (for curl header building)

## How It Works

### Extension
1. Content script detects `<video>` element
2. Sends `startCapture` message to background when video plays
3. Background service worker captures all network requests
4. Requests are formatted as standard HAR format
5. User saves HAR file to disk via popup UI

### Download Script
1. Parses HAR file with `jq`
2. Extracts HLS segment URLs
3. Detects available video resolutions from URLs
4. Extracts HTTP headers from HAR (auth, cookies, etc.)
5. Downloads each segment using `curl` with HAR headers
6. Creates ffmpeg concat playlist
7. Merges all segments into single MP4 file

## Troubleshooting

### Extension doesn't auto-detect video
- Make sure you're on a Kiwify member page with a playable video
- Check browser console (F12) for any error messages
- Try manually clicking extension icon and "Start Capture"

### "No HLS segments found in HAR file"
- Make sure the HAR file contains a full video playback
- Play the video to the end before stopping capture
- Check if the video uses a different streaming format

### "ffmpeg not found" error
- Install ffmpeg: `sudo apt-get install ffmpeg` (Linux) or `brew install ffmpeg` (Mac)

### Segments fail to download
- Make sure HAR file is fresh (headers change over time)
- Re-capture a new HAR file if it's more than a few hours old
- Check your internet connection

## Files

- `manifest.json` - Extension configuration
- `content-script.js` - Detects video playback on Kiwify pages
- `background.js` - Captures network traffic and builds HAR
- `popup.html/js` - Extension UI for status and controls
- `download_from_har.sh` - Script to download and merge segments
- `icons/` - Extension toolbar icons

## Notes

- HAR files contain full HTTP headers with auth tokens
- Keep HAR files private - they can be used to access videos
- HAR files are only valid for a limited time (usually a few hours)
- Captured data is limited by browser memory - very long videos may need split capture sessions

## License

Personal use only. Respect content creator rights.
