#!/usr/bin/env python3
"""
Parse HLS m3u8 playlist and show available resolutions
"""

import sys
import re
import urllib.request
import json
from pathlib import Path

def parse_m3u8(url_or_file):
    """Parse m3u8 file from URL or local file"""
    try:
        if url_or_file.startswith('http'):
            # Fetch from URL
            headers = {'User-Agent': 'Mozilla/5.0'}
            req = urllib.request.Request(url_or_file, headers=headers)
            with urllib.request.urlopen(req, timeout=10) as response:
                content = response.read().decode('utf-8')
                base_url = '/'.join(url_or_file.rsplit('/', 1)[0] + '/')
        else:
            # Read from file
            with open(url_or_file, 'r') as f:
                content = f.read()
            base_url = Path(url_or_file).parent.as_posix() + '/'
    except Exception as e:
        print(f"Error reading m3u8: {e}")
        return None, None

    return content, base_url

def extract_variants(m3u8_content, base_url):
    """Extract available quality variants from master m3u8"""
    variants = []

    lines = m3u8_content.split('\n')
    for i, line in enumerate(lines):
        if 'EXT-X-STREAM-INF' in line:
            # Parse resolution and other info
            info = {}

            # Extract RESOLUTION
            res_match = re.search(r'RESOLUTION=(\d+x\d+)', line)
            if res_match:
                info['resolution'] = res_match.group(1)
                width, height = map(int, res_match.group(1).split('x'))
                info['height'] = height

            # Extract BANDWIDTH
            bw_match = re.search(r'BANDWIDTH=(\d+)', line)
            if bw_match:
                info['bandwidth'] = int(bw_match.group(1))

            # Next line should be the playlist URL
            if i + 1 < len(lines):
                playlist_url = lines[i + 1].strip()
                if playlist_url and not playlist_url.startswith('#'):
                    if not playlist_url.startswith('http'):
                        playlist_url = base_url + playlist_url
                    info['url'] = playlist_url
                    info['filename'] = lines[i + 1].strip().split('/')[-1].replace('.m3u8', '')
                    variants.append(info)

    return sorted(variants, key=lambda x: x.get('height', 0), reverse=True)

def print_variants(variants):
    """Pretty print available variants"""
    if not variants:
        print("No variants found in m3u8")
        return

    print("\n" + "="*60)
    print("Available Quality Variants:")
    print("="*60)

    for i, v in enumerate(variants, 1):
        res = v.get('resolution', 'Unknown')
        bw = v.get('bandwidth', 0)
        mbps = bw / 1_000_000
        filename = v.get('filename', 'unknown')

        print(f"\n{i}. {res} @ {mbps:.1f} Mbps")
        print(f"   Filename: {filename}")
        print(f"   URL: {v.get('url', 'N/A')[:80]}...")

def main():
    if len(sys.argv) < 2:
        print("Usage: get_resolutions.py <m3u8_url_or_file>")
        print("\nExamples:")
        print("  get_resolutions.py https://example.com/playlist.m3u8")
        print("  get_resolutions.py ./playlist.m3u8")
        sys.exit(1)

    m3u8_input = sys.argv[1]

    print(f"Parsing: {m3u8_input}")
    content, base_url = parse_m3u8(m3u8_input)

    if content is None:
        sys.exit(1)

    variants = extract_variants(content, base_url)
    print_variants(variants)

    # Also output as JSON for scripting
    if variants:
        json_file = "variants.json"
        with open(json_file, 'w') as f:
            json.dump(variants, f, indent=2)
        print(f"\n✓ Saved variant info to: {json_file}")

if __name__ == '__main__':
    main()
