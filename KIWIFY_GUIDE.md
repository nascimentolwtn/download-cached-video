# Kiwify Video Download Guide

## Quick Start

Choose the easiest method for you:

### **Method 1: HAR File Export (Recommended - Easiest)**

No manual URL hunting. DevTools captures everything.

**Steps:**
1. Open DevTools (`F12`)
2. Go to **Network** tab
3. **Clear the Network tab** (⊘ icon)
4. **Play the video** (let it buffer for a few seconds while recording)
5. Right-click in Network tab → **"Save all as HAR with content"**
6. Save as `network.har`

**⚠️ Important:** HAR file captures auth tokens that expire quickly. Use the HAR file immediately after exporting.

**Download:**
```bash
./download.sh --har network.har
```

The script will:
- ✓ Find the m3u8 playlist automatically
- ✓ Show available resolutions
- ✓ Let you choose quality
- ✓ Download all segments
- ✓ Merge into MP4

---

### **Method 2: HTML Video Element (Medium)**

Copy the video element from page source.

**Steps:**
1. Open DevTools (`F12`)
2. Go to **Elements/Inspector** tab
3. Find `<video class="plyr">` element
4. Right-click → **"Copy element"** (or parent div)
5. Run command:

```bash
./download.sh --html '<paste_your_html_here>'
```

**Note:** If blob URL doesn't work, you'll need to manually get the m3u8 URL from Network tab instead.

---

## Workflow Comparison

| Method | Effort | Reliability | Steps |
|--------|--------|-------------|-------|
| HAR Export | Minimal | Excellent | 5 clicks |
| HTML Element | Low | Medium | 4 clicks + m3u8 hunt |
| Direct URL | Very Low | Excellent | Copy/paste URL |

---

## Video Resolution Selection

After running any method, you'll see available resolutions:

```
Available Resolutions:
=====================
1. 1920x1080
2. 1280x720
3. 854x480

Choose resolution (1-3): 2
```

Pick your desired quality and the script handles everything else.

---

## Complete Examples

### Download 720p from HAR
```bash
./download.sh --har network.har
# Choose: 2 (for 720p)
```

### Download 480p from HTML
```bash
./download.sh --html '<video src="blob:..." class="plyr"></video>'
# Choose: 3 (for 480p)
```

### Download with direct URL
```bash
./download.sh --url "https://d3p.../playlist.m3u8"
```

---

## Troubleshooting

**"No m3u8 playlist found in HAR file"**
- Make sure video was actually playing during capture
- Try capturing again while video is loading

**"Failed to fetch m3u8 file"**
- HAR file may be too old (blob URLs expire)
- Export a fresh HAR while video is playing

**"Only getting 1080p, want lower resolution"**
- Use HAR method to auto-detect all available qualities
- Script will let you choose

---

## Output

Videos are saved with resolution in filename:
```
video_1920x1080.mp4  (or)
video_1280x720.mp4   (or)
video_854x480.mp4
```

Move to permanent storage:
```bash
mv video_*.mp4 /mnt/e/temp/_08_Videos/
```

---

## Tips

1. **Fastest method:** HAR export (automatic everything)
2. **Most reliable:** When in doubt, use HAR method
3. **Keep video page open:** If using HTML method
4. **Fresh exports:** Don't use old HAR/HTML files (URLs expire)

---

## Advanced: Manual URL Entry

If none of the above work, you can manually find the m3u8:

1. Open DevTools → Network tab
2. Filter by `.m3u8`
3. Play video and watch for requests
4. Copy the m3u8 request URL
5. Run: `./download.sh --url "<url>"`
