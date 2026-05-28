# Kiwify Downloader - Architecture

## File Overview

### Core Files

| File | Purpose | Required |
|------|---------|----------|
| **download.sh** | Main entry point, parses HAR files, detects resolutions, orchestrates download | ✅ YES |
| **download_hls.sh** | Helper script called by download.sh, downloads segments and merges with ffmpeg | ✅ YES |
| **extract_headers_from_har.py** | Helper script called by download.sh, extracts auth headers from HAR | ✅ YES |

### Documentation

| File | Purpose |
|------|---------|
| **README.md** | Project overview and features |
| **KIWIFY_GUIDE.md** | User-friendly step-by-step guide |
| **ARCHITECTURE.md** | This file - technical overview |

---

## How It Works

### User Workflow

```
1. User captures HAR from Chrome DevTools
              ↓
2. User runs: ./download.sh --har file.har
              ↓
3. download.sh processes HAR:
   - Extracts m3u8 playlist URLs
   - Extracts auth headers via extract_headers_from_har.py
   - Parses master playlist for available resolutions
   - Shows user resolution options
              ↓
4. User selects resolution (1-5)
              ↓
5. download.sh calls download_hls.sh:
   - Base URL
   - Segment prefix
   - Segment range (first-last)
   - Auth headers
              ↓
6. download_hls.sh:
   - Downloads all segments
   - Creates ffmpeg concat file
   - Merges segments into MP4
              ↓
7. Output: video_854x480.mp4 (or selected resolution)
```

---

## Script Dependencies

```
download.sh
  ├── Calls: extract_headers_from_har.py
  │   └── Purpose: Extract auth headers from HAR
  │
  └── Calls: download_hls.sh
      ├── Uses: curl (downloads segments)
      ├── Uses: ffmpeg (merges segments)
      └── Uses: Python (header building)
```

---

## File Interaction Details

### 1. download.sh (Main Script)

**Responsibilities:**
- Parse command-line arguments (`--har`, `--html`, `--url`)
- Extract m3u8 playlist URLs from HAR
- Call Python to extract auth headers
- Fetch master playlist
- Parse resolutions from playlist
- Ask user to select resolution
- Call download_hls.sh with parameters

**Input:** HAR file from Chrome DevTools
**Output:** Calls download_hls.sh with download parameters

### 2. extract_headers_from_har.py (Auth Helper)

**Responsibilities:**
- Parse HAR JSON
- Find CloudFront requests
- Extract HTTP headers (User-Agent, Referer, etc.)
- Output as JSON for curl to use

**Input:** HAR file path, search term ("cloudfront")
**Output:** JSON file with auth headers

### 3. download_hls.sh (Download Helper)

**Responsibilities:**
- Receive parameters from download.sh:
  - Base URL
  - Segment prefix
  - Segment range
  - Optional auth headers
- Download all .ts segments using curl
- Create ffmpeg concat file
- Run ffmpeg to merge segments
- Output final MP4

**Input:** Parameters from download.sh
**Output:** video_[resolution].mp4

---

## Data Flow Example

### Input
```json
HAR File:
{
  "log": {
    "entries": [
      {
        "request": {
          "url": "https://d3p.../video-master.m3u8",
          "headers": [...]
        }
      },
      {
        "request": {
          "url": "https://d3p.../segment0.ts"
        }
      }
    ]
  }
}
```

### Processing

```
download.sh extracts:
├── m3u8 URL: https://d3p.../video-master.m3u8
└── headers.json: {User-Agent: "...", Referer: "..."}

Fetches master.m3u8:
#EXT-X-STREAM-INF:RESOLUTION=1920x1080,...
video-1080p.m3u8
#EXT-X-STREAM-INF:RESOLUTION=854x480,...
video-480p.m3u8

User selects 480p → download_hls.sh gets:
├── Base URL: https://d3p.../
├── Prefix: video-480p
├── Start: 0
├── End: 55
└── Headers: {...}
```

### Output

```
hls_download_12345/
├── video-480p0.ts ✓
├── video-480p1.ts ✓
├── ...
├── video-480p55.ts ✓
├── concat.txt (ffmpeg playlist)
└── ffmpeg merge → ../video_854x480.mp4
```

---

## Key Design Decisions

✅ **Modular Scripts**
- Separate concerns: parsing vs downloading
- Easy to debug each step
- Can be improved independently

✅ **HAR Over Manual URL Hunting**
- No manual work needed
- Automatic auth extraction
- All resolutions detected automatically

✅ **Helper Scripts Pattern**
- download.sh: orchestration only
- download_hls.sh: reusable for any HLS stream
- extract_headers_from_har.py: HAR-specific extraction

✅ **Temporary Working Directory**
- Segments downloaded to /tmp/
- Automatically cleaned up
- No clutter in project folder

---

## System Requirements

- **Bash** 4.0+ (array support)
- **curl** (segment download)
- **ffmpeg** (segment merge)
- **Python 3** (header extraction)
- **jq** (JSON parsing - optional, inline Python used as fallback)

---

## Troubleshooting by Component

### download.sh fails to find m3u8
- Check HAR file has actual video traffic
- Ensure video was playing during capture

### extract_headers_from_har.py fails
- Check HAR file is valid JSON
- Verify CloudFront requests exist in HAR

### download_hls.sh fails to download
- Check curl is installed
- Check internet connection
- Check auth headers are valid (HAR may be expired)

### download_hls.sh fails to merge
- Check ffmpeg is installed
- Check all segments downloaded successfully
- Check disk space is sufficient

---

## Future Improvements

- [ ] Resume partial downloads
- [ ] Parallel segment downloading
- [ ] Automatic retry on failed segments
- [ ] Support for other streaming protocols
- [ ] GUI wrapper for non-CLI users
