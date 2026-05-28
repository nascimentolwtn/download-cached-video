# Kiwify Video Download Guide

## The One True Method: HAR Export ✅

The simplest and most reliable way to download Kiwify videos.

## Quick Start (5 minutes)

### 1. Capture Video Traffic

Open any Kiwify video in Chrome and capture the network traffic:

```
1. Press F12 to open DevTools
2. Click "Network" tab
3. Click the circle (Record) button (if not already recording)
4. Play the video for 30+ seconds
5. Right-click in Network tab → "Save all as HAR with content"
6. Save as: video.har
```

### 2. Download the Video

```bash
./download.sh --har video.har
```

### 3. Choose Resolution

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

That's it! The script will:
- ✓ Download all segments
- ✓ Use authentication headers from HAR
- ✓ Merge into MP4 file
- ✓ Save as `video_854x480.mp4`

---

## Why HAR Method?

| Feature | Status |
|---------|--------|
| **Easiest** | ✅ 5 clicks, no manual work |
| **Most Reliable** | ✅ Captures all auth automatically |
| **Complete** | ✅ Gets all resolutions available |
| **Fast** | ✅ No hunting for URLs |

---

## Complete Walkthrough

### Step 1: Start Capture
```
Open Kiwify → Find video → Press F12 → Click Network tab
```

### Step 2: Record Traffic
```
Video plays → DevTools records all requests → 30+ seconds
```

### Step 3: Export HAR
```
Right-click Network → "Save all as HAR with content" → Save as network.har
```

### Step 4: Download
```bash
./download.sh --har network.har
```

### Step 5: Choose Resolution
```
[Script shows options] → Type 3 (for 480p) → Enter
[Script downloads and merges]
```

### Output
```
✓ video_854x480.mp4 ready!
```

---

## Resolution Guide

Choose based on your needs:

| Option | Resolution | Quality | File Size |
|--------|-----------|---------|-----------|
| 1 | 640×360 | Low | Small |
| 2 | 456×256 | Low-Mid | Small-Medium |
| 3 | 854×480 | **Recommended** | Medium |
| 4 | 1280×720 | High | Large |
| 5 | 1920×1080 | Best | Very Large |

**Recommendation:** 854×480 (option 3) is the best balance of quality and file size.

---

## Common Issues

### "No HLS segments found in HAR"
**Solution:** Make sure the video was actually playing when you captured the HAR. Try again:
1. Open video page
2. Start Network recording
3. Play video for 30+ seconds
4. Then export HAR

### "Failed to download segments"
**Solution:** HAR files expire quickly. Don't save them for later. Export a fresh HAR immediately before downloading.

### "Only 1 or 2 resolutions showing"
**Solution:** This is normal. Kiwify may not stream all resolutions. Download the best available option.

### ffmpeg not found
```bash
# Install ffmpeg
sudo apt-get install ffmpeg   # Ubuntu/Debian
brew install ffmpeg           # macOS
```

---

## Important Notes

⚠️ **HAR Files Contain Sensitive Data**
- HAR files include auth tokens and cookies
- Delete them after downloading (or they expire in hours)
- Don't share HAR files with others

⚠️ **Keep Video Page Open**
- During capture, keep the video page active
- Don't navigate away while recording

⚠️ **30+ Seconds Recommended**
- Short captures may miss all available resolutions
- Play video for half a minute to be safe

---

## Tips & Tricks

✅ **Fastest method:** HAR export (5 minutes start-to-finish)  
✅ **Always use fresh HAR:** Export immediately before downloading  
✅ **Check resolution options:** Different videos have different available qualities  
✅ **480p is usually best:** Good balance of quality and speed  

---

## File Output

Videos are automatically named by resolution:
```
video_640x360.mp4    → Low quality
video_854x480.mp4    → Recommended
video_1920x1080.mp4  → Best quality
```

Move to your videos folder:
```bash
mv video_*.mp4 /path/to/videos/
```

---

## That's It!

The HAR method handles everything automatically. No hunting for URLs, no manual configuration. Just capture, run, and select resolution.

Enjoy your Kiwify videos! 🎬
