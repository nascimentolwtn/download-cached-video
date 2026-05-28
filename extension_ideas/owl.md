# OWL: Chrome Extension for Local Video Cache File Manager

I'll create a Chrome extension that helps you find video files in your PC's cache and move them to your Downloads folder. Note that Chrome extensions have limited direct filesystem access, so this extension will work with a native messaging host.

## Extension Structure

### manifest.json
```json
{
  "manifest_version": 3,
  "name": "Video Cache Finder",
  "version": "1.0",
  "description": "Find video files in cache and save to Downloads folder",
  "permissions": [
    "nativeMessaging",
    "downloads",
    "activeTab"
  ],
  "background": {
    "service_worker": "background.js"
  },
  "action": {
    "default_popup": "popup.html"
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icon48.png",
    "128": "icons/icon128.png"
  }
}
```

### popup.html
```html
<!DOCTYPE html>
<html>
<head>
  <title>Video Cache Finder</title>
  <style>
    body {
      width: 300px;
      padding: 10px;
      font-family: Arial, sans-serif;
    }
    button {
      width: 100%;
      padding: 8px;
      margin: 5px 0;
      background-color: #4CAF50;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    button:hover {
      background-color: #45a049;
    }
    #status {
      margin-top: 10px;
      padding: 5px;
      border: 1px solid #ddd;
      border-radius: 4px;
    }
  </style>
</head>
<body>
  <h3>Video Cache Finder</h3>
  <button id="findVideos">Find Videos in Cache</button>
  <button id="saveToDownloads">Save to Downloads</button>
  <div id="status"></div>
  <script src="popup.js"></script>
</body>
</html>
```

### popup.js
```javascript
document.getElementById('findVideos').addEventListener('click', () => {
  chrome.runtime.sendMessage({action: 'findVideos'}, (response) => {
    document.getElementById('status').textContent = response.status;
  });
});

document.getElementById('saveToDownloads').addEventListener('click() => {
  chrome.runtime.sendMessage({action: 'saveToDownloads'}, (response) => {
    document.getElementById('status').textContent = response.status;
  });
});
```

### background.js
```javascript
let foundVideos = [];

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'findVideos') {
    findVideosInCache().then(videos => {
      foundVideos = videos;
      sendResponse({status: `Found ${videos.length} videos`});
    });
  } else if (request.action === 'saveToDownloads') {
    saveToDownloads(foundVideos).then(() => {
      sendResponse({status: 'Videos saved to Downloads folder'});
    });
  }
});

async function findVideosInCache() {
  // This would use native messaging to access local files
  // For security, Chrome extensions can't directly access local files
  // We'll use the Native Messaging API with a host application
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(
      'com.zoo.video_cache_finder',
      {action: 'find_videos'},
      (response) => {
        resolve(response.videos || []);
      }
    );
  });
}

async function saveToDownloads(videos) {
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(
      'com.zoo.video_cache_finder',
      {action: 'save_to_downloads', videos: videos},
      (response) => {
        resolve(response.status);
      }
    );
  });
}
```

### Native Messaging Host (Python - video_cache_finder.py)
```python
import os
import json
import struct
import sys
import winreg
import shutil
from pathlib import Path

# Chrome Native Messaging Host
def find_videos_in_cache():
    # Common cache locations
    cache_locations = [
        os.path.join(os.environ['LOCALAPPDATA'], 'Google', 'Chrome', 'User Data', 'Default', 'Cache'),
        os.path.join(os.environ['LOCALAPPDATA'], 'Google', 'Chrome', 'User Data', 'Default', 'Code Cache'),
        os.path.join(os.environ['LOCALAPPDATA'], 'Google', 'Chrome', 'User Data', 'Default', 'Service Worker', 'Cache Storage'),
        # Add other browsers if needed
    ]
    
    video_extensions = ['.mp4', '.webm', '.avi', '.mov', '.mkv', '.flv', '.wmv']
    found_videos = []
    
    for location in cache_locations:
        if os.path.exists(location):
            for root, dirs, files in os.walk(location):
                for file in files:
                    if file.endswith(tuple(video_extensions)):
                        found_videos.append(os.path.join(root, file))
    
    return found_videos

def save_to_downloads(videos):
    downloads_folder = os.path.join(os.environ['USERPROFILE'], 'Downloads')
    
    for video in videos:
        try:
            shutil.copy2(video, downloads_folder)
            return "Videos saved successfully"
        except Exception as e:
            return f"Error: {e}"

def main():
    # Chrome Native Messaging protocol
    while True:
        # Read message length
        text_length_bytes = sys.stdin.buffer.read(4)
        if not text_length_bytes:
            break
        
        text_length = struct.unpack('@I', text_length_bytes)[0]
        
        # Read message
        message = sys.stdin.buffer.read(text_length).decode('utf-8')
        message = json.loads(message)
        
        if message['action'] == 'find_videos':
            videos = find_videos_in_cache()
            response = {'videos': videos}
        elif message['action'] == 'save_to_downloads':
            response = {'status': save_to_downloads(message['videos'])}
        
        # Send response
        response_json = json.dumps(response).encode('utf-8')
        sys.stdout.buffer.write(struct.pack('@I', len(response_json)))
        sys.stdout.buffer.write(response_json)
        sys.stdout.buffer.flush()

if __name__ == '__main__':
    main()
```

### Native Messaging Manifest (video_cache_finder.json)
```json
{
  "name": "com.zoo.video_cache_finder",
  "description": "Video Cache Finder Native Host",
  "path": "video_cache_finder.py",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://YOUR_EXTENSION_ID/"
  ]
}
```

## Important Notes:

1. **Security Limitations**: Chrome extensions cannot directly access the local filesystem for security reasons. This solution uses Native Messaging to communicate with a Python script.

2. **Setup Required**:
   - Install the Python script and manifest in a known location
   - Update the extension ID in the native messaging manifest
   - The Python script needs appropriate permissions

3. **Video Detection**: The script looks for common video extensions in Chrome cache directories.

4. **Downloads Folder**: Videos are copied to the user's Downloads folder.

5. **Limitations**:
   - Only works on Windows (paths are Windows-specific)
   - Requires Python installed
   - Needs proper error handling for production use
   - May need admin privileges for some cache locations

Would you like me to explain any part in more detail or modify the extension for specific needs?