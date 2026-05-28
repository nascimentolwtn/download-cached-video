#!/usr/bin/env python3
"""Parse DASH manifest and extract segment URLs."""

import xml.etree.ElementTree as ET
import sys

if len(sys.argv) < 4:
    print("Usage: parse_dash_manifest.py <mpd_file> <manifest_base> <selected_res>", file=sys.stderr)
    sys.exit(1)

mpd_file = sys.argv[1]
manifest_base = sys.argv[2]
selected_res = sys.argv[3]

try:
    with open(mpd_file) as f:
        mpd_content = f.read()
except Exception as e:
    print(f"ERROR: Cannot read MPD file: {e}", file=sys.stderr)
    sys.exit(1)

try:
    root = ET.fromstring(mpd_content)
except ET.ParseError as e:
    print(f"ERROR: Invalid XML: {e}", file=sys.stderr)
    sys.exit(1)

ns = {'dash': 'urn:mpeg:dash:schema:mpd:2011'}

video_segs = []
audio_segs = []

for adapt_set in root.findall('.//dash:AdaptationSet', ns):
    mime_type = adapt_set.get('mimeType', '')

    for rep in adapt_set.findall('dash:Representation', ns):
        width = rep.get('width')
        height = rep.get('height')
        rep_id = rep.get('id', '')

        # Video segments
        if width and height and f"{width}x{height}" == selected_res:
            seg_tmpl = rep.find('dash:SegmentTemplate', ns)
            if seg_tmpl is not None:
                init = seg_tmpl.get('initialization', '')
                media = seg_tmpl.get('media', '')

                if init:
                    url = init.replace('$RepresentationID$', rep_id)
                    video_segs.append(manifest_base + url)

                segs = rep.findall('dash:SegmentTimeline/dash:S', ns)
                for i in range(len(segs)):
                    url = media.replace('$Number$', str(i+1).zfill(9))
                    url = url.replace('$RepresentationID$', rep_id)
                    video_segs.append(manifest_base + url)

        # Audio segments (use first audio track)
        elif 'audio' in mime_type and not audio_segs:
            seg_tmpl = rep.find('dash:SegmentTemplate', ns)
            if seg_tmpl is not None:
                init = seg_tmpl.get('initialization', '')
                media = seg_tmpl.get('media', '')

                if init:
                    url = init.replace('$RepresentationID$', rep_id)
                    audio_segs.append(manifest_base + url)

                segs = rep.findall('dash:SegmentTimeline/dash:S', ns)
                for i in range(len(segs)):
                    url = media.replace('$Number$', str(i+1).zfill(9))
                    url = url.replace('$RepresentationID$', rep_id)
                    audio_segs.append(manifest_base + url)

# Output segments
for url in video_segs:
    print(f"V:{url}")
for url in audio_segs:
    print(f"A:{url}")
