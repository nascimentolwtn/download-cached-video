#!/usr/bin/env python3
"""
Extract m3u8 playlist URLs from HAR file (exported from DevTools)
"""

import sys
import json
import re
from pathlib import Path

def extract_m3u8_urls(har_file):
    """Parse HAR file and find m3u8 requests"""
    try:
        with open(har_file, 'r') as f:
            har_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error parsing HAR file: {e}")
        return []

    m3u8_urls = []

    # Navigate through HAR structure
    try:
        entries = har_data.get('log', {}).get('entries', [])
    except:
        print("Invalid HAR file structure")
        return []

    for entry in entries:
        request = entry.get('request', {})
        response = entry.get('response', {})
        url = request.get('url', '')

        # Look for .m3u8 in URL
        if '.m3u8' in url:
            m3u8_urls.append({
                'url': url,
                'method': request.get('method', 'GET'),
                'type': 'url'
            })

        # Also check response content for m3u8 playlists
        response_content = response.get('content', {})
        text = response_content.get('text', '')

        if text and '#EXTM3U' in text:
            m3u8_urls.append({
                'url': url,
                'method': request.get('method', 'GET'),
                'type': 'response_body',
                'content_preview': text[:200]
            })

    return m3u8_urls

def print_results(m3u8_urls):
    """Pretty print found m3u8 URLs"""
    if not m3u8_urls:
        print("No m3u8 playlists found in HAR file")
        return

    print("\n" + "="*70)
    print("Found m3u8 Playlists:")
    print("="*70)

    for i, item in enumerate(m3u8_urls, 1):
        print(f"\n{i}. {item['type'].upper()}")
        print(f"   URL: {item['url']}")
        if item['type'] == 'response_body':
            print(f"   Content: {item.get('content_preview', '')[:100]}...")
        print()

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_m3u8_from_har.py <har_file>")
        print("\nHow to get HAR file:")
        print("1. Open DevTools (F12)")
        print("2. Go to Network tab")
        print("3. Right-click → Save as HAR with content")
        print("4. Run this script with the saved file")
        sys.exit(1)

    har_file = sys.argv[1]

    if not Path(har_file).exists():
        print(f"File not found: {har_file}")
        sys.exit(1)

    print(f"Parsing HAR file: {har_file}")
    m3u8_urls = extract_m3u8_urls(har_file)
    print_results(m3u8_urls)

    if m3u8_urls:
        # Save for easy copying
        urls_file = "m3u8_urls.txt"
        with open(urls_file, 'w') as f:
            for item in m3u8_urls:
                f.write(item['url'] + '\n')
        print(f"✓ URLs saved to: {urls_file}")

if __name__ == '__main__':
    main()
