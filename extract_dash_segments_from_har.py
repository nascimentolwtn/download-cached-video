#!/usr/bin/env python3
"""Extract DASH segment URLs directly from HAR file."""

import json
import sys

if len(sys.argv) < 2:
    print("Usage: extract_dash_segments_from_har.py <har_file> <selected_res>", file=sys.stderr)
    sys.exit(1)

har_file = sys.argv[1]
selected_res = sys.argv[2] if len(sys.argv) > 2 else None

try:
    with open(har_file) as f:
        har = json.load(f)
except Exception as e:
    print(f"ERROR: Cannot read HAR: {e}", file=sys.stderr)
    sys.exit(1)

# Extract video and audio segment URLs from HAR
video_urls = {}  # resolution -> list of URLs
audio_urls = []
headers = {}

for entry in har['log']['entries']:
    url = entry['request'].get('url', '')

    # Collect auth headers
    for h in entry['request'].get('headers', []):
        name = h['name'].lower()
        if name in ['user-agent', 'referer', 'authorization', 'cookie']:
            headers[h['name']] = h['value']

    # Look for MP4 segment URLs
    if '.mp4' in url.lower():
        # Identify resolution and stream type
        if 'qvbr' in url.lower() or '1920x1080' in url or '1280x720' in url or '640x360' in url or '456x256' in url:
            # Video segment
            res = None
            if '1920x1080' in url:
                res = '1920x1080'
            elif '1280x720' in url:
                res = '1280x720'
            elif '640x360' in url:
                res = '640x360'
            elif '456x256' in url:
                res = '456x256'

            if res:
                if res not in video_urls:
                    video_urls[res] = []
                video_urls[res].append(url)

        # Audio segments
        elif 'aac' in url.lower() or 'audio' in url.lower():
            if url not in audio_urls:
                audio_urls.append(url)

# Sort segments by number in filename
def sort_by_number(urls):
    def extract_num(url):
        import re
        match = re.search(r'(\d{9})', url)
        if match:
            return int(match.group(1))
        # Init segment comes first
        return 0
    return sorted(urls, key=extract_num)

# Sort all video URLs
for res in video_urls:
    video_urls[res] = sort_by_number(video_urls[res])

audio_urls = sort_by_number(audio_urls)

# Output selected resolution's segments
if selected_res and selected_res in video_urls:
    for url in video_urls[selected_res]:
        print(f"V:{url}")
    for url in audio_urls:
        print(f"A:{url}")
else:
    # If no resolution specified, output all found resolutions
    if selected_res:
        print(f"ERROR: Resolution {selected_res} not found in HAR", file=sys.stderr)
        print(f"Available: {', '.join(video_urls.keys())}", file=sys.stderr)
    sys.exit(1)
