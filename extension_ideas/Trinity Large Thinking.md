* Favicon for arcee-ai
Trinity Large Thinking (free)


I'll help you create a Chrome extension that detects and saves cached videos (excluding YouTube) to your Downloads folder. However, I need to clarify some important technical limitations first:

## **Important Technical Limitations:**

1. **Chrome does NOT allow direct access to cache files** for security and privacy reasons
2. **You cannot read raw cache files** through Chrome extensions
3. **The only way** to "save cached videos" is to **re-download them** using the same URLs

## **Solution Approach:**

We'll create an extension that:
1. Monitors network requests for video content
2. Identifies video URLs (excluding YouTube)
3. Automatically downloads them to your Downloads folder

Here's the complete implementation:

---

## **1. Manifest File (`manifest.json`)**

```json
{
  "manifest_version": 3,
  "name": "Cache Video Saver",
  "version": "1.0",
  "description": "Automatically download non-YouTube videos that your browser loads",
  "permissions": [
    "webRequest",
    "webRequestBlocking",
    "downloads",
    "storage",
    "<all_urls>"
  ],
  "host_permissions": [
    "<all_urls>"
  ],
  "background": {
    "service_worker": "background.js",
    "type": "module"
  },
  "action": {
    "default_popup": "popup.html",
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    }
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  },
  "content_security_policy": {
    "extension_specific": "script-src 'self'; object-src 'self'"
  }
}
```

---

## **2. Background Service Worker (`background.js`)**

```javascript
// List of video MIME types and extensions to detect
const VIDEO_MIME_TYPES = [
  'video/mp4', 'video/avi', 'video/mov', 'video/wmv', 
  'video/flv', 'video/mkv', 'video/webm', 'video/ogg'
];

const VIDEO_EXTENSIONS = [
  '.mp4', '.avi', '.mov', '.wmv', '.flv', '.mkv', '.webm', '.ogg'
];

// Set to track already downloaded URLs (prevents duplicates)
let downloadedUrls = new Set();

// Storage key for persistence
const STORAGE_KEY = 'video_saver_downloaded_urls';

// Initialize downloaded URLs from storage
async function loadDownloadedUrls() {
  const result = await chrome.storage.local.get([STORAGE_KEY]);
  if (result[STORAGE_KEY]) {
    downloadedUrls = new Set(result[STORAGE_KEY]);
  }
}

// Save downloaded URLs to storage
function saveDownloadedUrls() {
  chrome.storage.local.set({
    [STORAGE_KEY]: Array.from(downloadedUrls)
  });
}

// Check if URL is a video (by extension or content-type)
function isVideoUrl(url, mimeType) {
  // Check by extension
  const urlLower = url.toLowerCase();
  for (const ext of VIDEO_EXTENSIONS) {
    if (urlLower.endsWith(ext)) {
      return true;
    }
  }
  
  // Check by MIME type
  if (mimeType) {
    for (const videoMime of VIDEO_MIME_TYPES) {
      if (mimeType.includes(videoMime)) {
        return true;
      }
    }
  }
  
  return false;
}

// Check if URL is from YouTube (exclude)
function isYouTubeUrl(url) {
  return /^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)/.test(url);
}

// Main request listener
chrome.webRequest.onCompleted.addListener(
  async (details) => {
    try {
      // Skip if no response headers
      if (!details.responseHeaders) return;
      
      // Get Content-Type header
      const contentTypeHeader = details.responseHeaders.find(
        header => header.name.toLowerCase() === 'content-type'
      );
      
      const mimeType = contentTypeHeader ? contentTypeHeader.value : '';
      const url = details.url;
      
      // Skip YouTube and non-video content
      if (isYouTubeUrl(url) || !isVideoUrl(url, mimeType)) {
        return;
      }
      
      // Skip if already downloaded
      if (downloadedUrls.has(url)) {
        return;
      }
      
      // Add to downloaded set
      downloadedUrls.add(url);
      saveDownloadedUrls();
      
      // Trigger download
      chrome.downloads.download({
        url: url,
        filename: `video_${Date.now()}_${getFileNameFromUrl(url)}`,
        conflictAction: 'uniquify',
        saveAs: false
      }, (downloadId) => {
        if (chrome.runtime.lastError) {
          console.error('Download failed:', chrome.runtime.lastError);
        } else {
          console.log('Video download started:', url);
        }
      });
      
    } catch (error) {
      console.error('Error processing video request:', error);
    }
  },
  {
    urls: [
      "<all_urls>",
      // Optional: Add specific patterns if needed
      // "http://*/*", "https://*/*"
    ],
    types: ["main_frame", "sub_frame", "xmlhttprequest", "script"]
  },
  ["responseHeaders"]
);

// Helper to extract filename from URL
function getFileNameFromUrl(url) {
  try {
    const pathname = new URL(url).pathname;
    return pathname.split('/').pop() || 'video';
  } catch (e) {
    return 'video';
  }
}

// Initialize
loadDownloadedUrls().then(() => {
  console.log(`Cache Video Saver loaded. Tracking ${downloadedUrls.size} videos.`);
});
```

---

## **3. Popup HTML (`popup.html`)**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      width: 300px;
      padding: 15px;
      font-family: Arial, sans-serif;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 15px;
    }
    .status {
      font-size: 12px;
      color: #666;
      margin-top: 5px;
    }
    .stats {
      background: #f5f5f5;
      padding: 10px;
      border-radius: 4px;
      margin: 10px 0;
    }
    button {
      width: 100%;
      padding: 8px;
      margin: 5px 0;
      background: #4285F4;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    button:hover {
      background: #3367D6;
    }
    button:active {
      background: #2a5bc3;
    }
    .warning {
      color: #d32f2f;
      font-size: 12px;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h3>🎥 Cache Video Saver</h3>
    <img src="icons/icon16.png" width="16" height="16">
  </div>
  
  <div class="stats">
    <div>📊 Tracking: <span id="trackedCount">0</span> videos</div>
    <div>📁 Downloads: <span id="downloadedCount">0</span> videos</div>
  </div>
  
  <button id="clearBtn">Clear History</button>
  <button id="exportBtn">Export List</button>
  <button id="optionsBtn">Settings</button>
  
  <div class="warning">
    ⚠️ Note: This re-downloads videos from their source. 
    Cannot access browser cache files directly.
  </div>
  
  <script src="popup.js"></script>
</body>
</html>
```

---

## **4. Popup JavaScript (`popup.js`)**

```javascript
document.addEventListener('DOMContentLoaded', async () => {
  const trackedCountEl = document.getElementById('trackedCount');
  const downloadedCountEl = document.getElementById('downloadedCount');
  
  // Update counts
  const tracked = await getTrackedCount();
  const downloaded = await getDownloadedCount();
  
  trackedCountEl.textContent = tracked;
  downloadedCountEl.textContent = downloaded;
  
  // Clear history button
  document.getElementById('clearBtn').addEventListener('click', async () => {
    if (confirm('Clear all tracked video history?')) {
      await chrome.storage.local.remove(['video_saver_downloaded_urls']);
      location.reload();
    }
  });
  
  // Export list button
  document.getElementById('exportBtn').addEventListener('click', async () => {
    const result = await chrome.storage.local.get(['video_saver_downloaded_urls']);
    const urls = result['video_saver_downloaded_urls'] || [];
    
    if (urls.length === 0) {
      alert('No videos tracked yet');
      return;
    }
    
    const csv = 'URL,Timestamp\n' + 
                urls.map(url => `${url},${new Date().toISOString()}`).join('\n');
    
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    
    chrome.downloads.download({
      url: url,
      filename: `video_history_${Date.now()}.csv`,
      saveAs: true
    });
  });
  
  // Settings button (placeholder)
  document.getElementById('optionsBtn').addEventListener('click', () => {
    alert('Settings would go here.\n\nCurrent settings:\n- All video types enabled\n- YouTube excluded');
  });
});

async function getTrackedCount() {
  const result = await chrome.storage.local.get(['video_saver_downloaded_urls']);
  return (result['video_saver_downloaded_urls'] || []).length;
}

async function getDownloadedCount() {
  // This would require tracking actual downloads
  // For now, same as tracked count
  return await getTrackedCount();
}
```

---

## **5. Optional: Icon Files**

Create a folder named `icons` and add these PNG files (you can use any 16x16, 48x48, 128x128 icons):

- `icon16.png`
- `icon48.png`
- `icon128.png`

---

## **6. Installation & Usage:**

1. **Create a new folder** for your extension
2. **Save all files** in that folder with the exact names above
3. **Open Chrome** and go to `chrome://extensions/`
4. **Enable "Developer mode"** (toggle in top right)
5. **Click "Load unpacked"**
6. **Select your extension folder**
7. The extension will appear in your toolbar

## **How It Works:**

1. When you load a page with a video, Chrome makes a network request
2. The extension intercepts the request when it completes
3. If it's a video (MP4, WebM, etc.) and NOT from YouTube:
   - Checks if already downloaded
   - If new, triggers a download to your Downloads folder
4. The popup shows statistics and lets you manage history

## **Limitations & Notes:**

⚠️ **Important:** This **RE-DOWNLOADS** videos from their source, it does **NOT** read from your cache. This is a browser security restriction.

### **To Improve/Modify:**

1. **Add specific site exclusions** in `manifest.json`:
```json
"permissions": [
  "webRequest",
  "webRequestBlocking",
  "downloads",
  "storage",
  "http://*/*", "https://*/*"
]
```

2. **Add more video formats** by extending the `VIDEO_MIME_TYPES` and `VIDEO_EXTENSIONS` arrays

3. **Add a whitelist/blacklist** system in the popup for specific sites

4. **Add download confirmation** if you want user approval before each download

Would you like me to add any specific features like:
- Site whitelisting/blacklisting?
- Download quality selection?
- Batch downloading?
- Integration with specific video platforms?