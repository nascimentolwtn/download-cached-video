* Nemotron 3 Super (free)

I need to clarify an important technical limitation upfront: **Chrome extensions cannot directly scan arbitrary local folders (like your browser cache) on your PC due to strict security sandboxing.** This is a fundamental design choice in Chrome to prevent malicious extensions from accessing your personal files without explicit permission.

### Why a Pure Chrome Extension Won't Work
- Chrome extensions run in a restricted environment with no direct access to your local file system (`C:\`, `/Users/`, etc.).
- The `chrome.fileSystem` API only allows access to *specific files/folders the user explicitly selects* via a file picker – it cannot recursively scan cache directories.
- Cache locations vary by OS, browser profile, and are often hidden/system-protected (e.g., `~/Library/Caches/Google/Chrome` on macOS, `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache` on Windows).

### Practical Alternatives (Ranked by Feasibility)
Here are realistic solutions to achieve your goal, **not** as a Chrome extension but as more appropriate tools:

#### ✅ Option 1: Standalone Desktop Script (Recommended)
A simple Python script is the most reliable way to scan cache folders and extract video files. It runs with your user permissions and avoids browser security restrictions.

**How it works:**
1.  Script scans known Chrome cache directories for your OS.
2.  Identifies files with video-like signatures (magic numbers: `mp4`, `webm`, `ogg`, etc.).
3.  Copies matching files to your `Downloads` folder with sensible names.

**Save this as `extract_cache_videos.py`:**
```python
import os
import shutil
import sys
from pathlib import Path

def get_chrome_cache_dirs():
    """Return list of possible Chrome cache directories based on OS."""
    home = Path.home()
    if sys.platform == "win32":
        base = home / "AppData" / "Local" / "Google" / "Chrome" / "User Data"
    elif sys.platform == "darwin":  # macOS
        base = home / "Library" / "Caches" / "Google" / "Chrome"
    else:  # Linux
        base = home / ".cache" / "google-chrome"
    
    # Common cache subdirs to check
    cache_dirs = [
        base / "Default" / "Cache",
        base / "Profile 1" / "Cache",  # Add more profiles if needed
        base / "Default" / "Code Cache" / "js",
        base / "Default" / "Code Cache" / "wasm",
    ]
    # Filter to existing dirs
    return [d for d in cache_dirs if d.exists() and d.is_dir()]

def is_video_file(filepath):
    """Check if file has video magic numbers (simplified)."""
    try:
        with open(filepath, 'rb') as f:
            header = f.read(12)
        # MP4: starts with ISO BMFF (e.g., 'ftypmp42')
        if b'ftyp' in header[:8]:
            return True
        # WebM: EBML header (0x1A 0x45 0xDF 0xA3)
        if header.startswith(b'\x1a\x45\xdf\xa3'):
            return True
        # Ogg: "OggS" signature
        if header.startswith(b'OggS'):
            return True
        # Add more as needed (MOV, AVI, etc.)
        return False
    except (IOError, OSError):
        return False

def main():
    cache_dirs = get_chrome_cache_dirs()
    if not cache_dirs:
        print("Error: No Chrome cache directories found. Check paths or close Chrome first.")
        return 1

    downloads_dir = Path.home() / "Downloads"
    downloads_dir.mkdir(exist_ok=True)
    
    print(f"Scanning {len(cache_dirs)} cache directory(ies) for videos...")
    print(f"Saving to: {downloads_dir}")
    
    copied_count = 0
    for cache_dir in cache_dirs:
        for root, _, files in os.walk(cache_dir):
            for filename in files:
                filepath = Path(root) / filename
                if is_video_file(filepath):
                    try:
                        # Generate a safe filename (avoid overwrites)
                        stem = filepath.stem
                        suffix = filepath.suffix
                        counter = 1
                        new_name = downloads_dir / f"{stem}{suffix}"
                        while new_name.exists():
                            new_name = downloads_dir / f"{stem}_{counter}{suffix}"
                            counter += 1
                        
                        shutil.copy2(filepath, new_name)
                        print(f"  Copied: {filepath.name} -> {new_name.name}")
                        copied_count += 1
                    except (IOError, OSError, shutil.Error) as e:
                        print(f"  Warning: Could not copy {filepath.name}: {e}")
    
    print(f"\nDone! Copied {copied_count} video file(s) to {downloads_dir}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

**To use it:**
1.  Install Python (if not already installed): [python.org](https://python.org)
2.  Save the script above as `extract_cache_videos.py`.
3.  **Close Chrome completely** (critical – cache files are locked while running).
4.  Run from terminal/command prompt:
    ```bash
    python extract_cache_videos.py
    ```
5.  Found videos will appear in your `Downloads` folder.

#### ✅ Option 2: Manual Cache Inspection (For Tech-Savvy Users)
If you prefer not to run scripts:
1.  Close Chrome.
2.  Navigate to your Chrome cache folder (use paths from `get_chrome_cache_dirs()` above).
3.  Sort files by "Size" (largest first – videos are usually big).
4.  Look for files without extensions or with odd names. Try renaming promising ones to `.mp4`, `.webm`, etc., and test playback.
5.  Copy/paste wanted files to `Downloads`.

#### ⚠️ Option 3: Browser Bookmarklet (Limited Use)
*Only works for videos currently playing in a tab* (does **not** access cache):
```javascript
javascript:(function() {
    var videos = document.getElementsByTagName('video');
    if (videos.length === 0) {
        alert('No <video> elements found on this page.');
        return;
    }
    for (var i = 0; i < videos.length; i++) {
        var video = videos[i];
        if (video.currentSrc) {
            var a = document.createElement('a');
            a.href = video.currentSrc;
            a.download = 'video_' + i + '.mp4'; // Adjust extension as needed
            a.click();
        }
    }
})();
```
- **How to use:** Create a new bookmark, paste the above as the URL (remove line breaks), click it on a page with embedded video.
- **Limitation:** Only grabs the *current source* of visible `<video>` tags. Won't get videos from cache, blob URLs, or encrypted streams (like Netflix).

### Important Notes & Warnings
- **Cache is Ephemeral:** Chrome regularly clears cache. Videos may be gone if too much time has passed.
- **Security First:** Never run scripts or grant file access to untrusted sources. This script only reads cache and writes to Downloads – inspect it yourself!
- **Fake Extensions:** Be wary of Chrome Web Store extensions claiming to "save cache videos" – they often require excessive permissions, contain malware, or simply don't work as advertised (due to the sandbox limitation explained above).
- **Alternative Tools:** Dedicated cache viewers like [ChromeCacheView](https://www.nirsoft.net/utils/chrome_cache_view.html) (Windows) or `about:cache` in Firefox can help manually locate files, but saving still requires user action per file.

### Recommendation
**Use the standalone Python script (Option 1).** It's the only method that reliably scans your cache for video files and saves them to Downloads without browser security barriers. It respects your privacy (runs locally, no data leaves your machine) and gives you full control.

If you're uncomfortable with scripts, Option 2 (manual inspection) is the next best approach, though more tedious. A pure Chrome extension for this specific task **is not feasible** due to Chrome's security architecture. Let me know if you'd like help adapting the script for your OS or troubleshooting!