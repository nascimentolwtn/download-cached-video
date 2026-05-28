#!/bin/bash
# DASH video downloader and merger

set -e

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Parse command line arguments
mpd_content=""
manifest_base=""
selected_res=""
headers_file=""

while getopts "m:b:r:H:" opt; do
    case $opt in
        m) mpd_content="$OPTARG" ;;
        b) manifest_base="$OPTARG" ;;
        r) selected_res="$OPTARG" ;;
        H) headers_file="$OPTARG" ;;
        *) error "Unknown option: -$OPTARG" ;;
    esac
done

if [ -z "$mpd_content" ] || [ -z "$manifest_base" ] || [ -z "$selected_res" ]; then
    error "Missing required parameters"
fi

# Create working directory
work_dir="/tmp/dash_download_$$"
mkdir -p "$work_dir"
cd "$work_dir"

log "Working directory: $work_dir"

# Parse DASH manifest and extract segment URLs
segment_info=$(python3 << 'PYTHON'
import xml.etree.ElementTree as ET
import json
import sys

mpd_content = sys.argv[1]
manifest_base = sys.argv[2]
selected_res = sys.argv[3]

try:
    root = ET.fromstring(mpd_content)
except ET.ParseError as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(1)

ns = {'dash': 'urn:mpeg:dash:schema:mpd:2011'}

# Extract video and audio segments for selected resolution
video_segments = []
audio_segments = []

for adapt_set in root.findall('.//dash:AdaptationSet', ns):
    mime_type = adapt_set.get('mimeType', '')

    for rep in adapt_set.findall('dash:Representation', ns):
        width = rep.get('width')
        height = rep.get('height')
        rep_id = rep.get('id', '')

        # Video representation matching selected resolution
        if width and height:
            res_key = f"{width}x{height}"
            if res_key == selected_res:
                seg_template = rep.find('dash:SegmentTemplate', ns)
                if seg_template is not None:
                    media_pattern = seg_template.get('media', '')
                    init_pattern = seg_template.get('initialization', '')

                    # Add init segment
                    if init_pattern:
                        init_url = init_pattern.replace('$RepresentationID$', rep_id)
                        video_segments.append(manifest_base + init_url)

                    # Add numbered segments
                    segs = rep.findall('dash:SegmentTimeline/dash:S', ns)
                    for i in range(len(segs)):
                        seg_url = media_pattern.replace('$Number$', str(i+1))
                        seg_url = seg_url.replace('$RepresentationID$', rep_id)
                        video_segments.append(manifest_base + seg_url)

        # Audio representation
        elif 'audio' in mime_type:
            seg_template = rep.find('dash:SegmentTemplate', ns)
            if seg_template is not None:
                media_pattern = seg_template.get('media', '')
                init_pattern = seg_template.get('initialization', '')

                # Add init segment
                if init_pattern:
                    init_url = init_pattern.replace('$RepresentationID$', rep_id)
                    audio_segments.append(manifest_base + init_url)

                # Add numbered segments
                segs = rep.findall('dash:SegmentTimeline/dash:S', ns)
                for i in range(len(segs)):
                    seg_url = media_pattern.replace('$Number$', str(i+1))
                    seg_url = seg_url.replace('$RepresentationID$', rep_id)
                    audio_segments.append(manifest_base + seg_url)

output = {
    'video': video_segments,
    'audio': audio_segments,
}

print(json.dumps(output))
PYTHON
$(cat <<'ENDARGS'
$mpd_content
$manifest_base
$selected_res
ENDARGS
)
)

# Check for errors
if echo "$segment_info" | grep -q '"error"'; then
    error "Failed to parse DASH manifest"
fi

# Extract segment lists
video_segments=$(echo "$segment_info" | python3 -c "import sys, json; d=json.load(sys.stdin); print('\\n'.join(d.get('video', [])))")
audio_segments=$(echo "$segment_info" | python3 -c "import sys, json; d=json.load(sys.stdin); print('\\n'.join(d.get('audio', [])))")

if [ -z "$video_segments" ]; then
    error "No video segments found in manifest"
fi

log "Found video segments to download"
[ -n "$audio_segments" ] && log "Found audio segments to download"

# Download video segments
log "Downloading video segments..."
mkdir -p video
video_count=0
while IFS= read -r url; do
    [ -z "$url" ] && continue
    video_count=$((video_count + 1))
    output_file="video/seg_${video_count}.mp4"

    echo -n "."

    # Build curl command with headers
    if [ -f "$headers_file" ]; then
        python3 << ENDCURL
import json
with open('$headers_file') as f:
    headers = json.load(f)
cmd = 'curl -s -L -m 30'
for k, v in headers.items():
    cmd += f' -H "{k}: {v}"'
cmd += f' -o "{output_file}" "{url}"'
with open('/tmp/curl_cmd', 'w') as f:
    f.write(cmd)
ENDCURL
        bash /tmp/curl_cmd
    else
        curl -s -L -m 30 -o "$output_file" "$url"
    fi
done <<< "$video_segments"
echo ""

log "Downloaded $video_count video segments"

# Download audio segments if present
if [ -n "$audio_segments" ]; then
    log "Downloading audio segments..."
    mkdir -p audio
    audio_count=0
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        audio_count=$((audio_count + 1))
        output_file="audio/seg_${audio_count}.mp4"

        echo -n "."

        if [ -f "$headers_file" ]; then
            python3 << ENDCURL
import json
with open('$headers_file') as f:
    headers = json.load(f)
cmd = 'curl -s -L -m 30'
for k, v in headers.items():
    cmd += f' -H "{k}: {v}"'
cmd += f' -o "{output_file}" "{url}"'
with open('/tmp/curl_cmd', 'w') as f:
    f.write(cmd)
ENDCURL
            bash /tmp/curl_cmd
        else
            curl -s -L -m 30 -o "$output_file" "$url"
        fi
    done <<< "$audio_segments"
    echo ""
    log "Downloaded $audio_count audio segments"
fi

# Merge segments with ffmpeg
log "Merging segments with ffmpeg..."

# Create concat demuxer file for video
echo "Creating ffmpeg concat file..."
ls -1 video/seg_*.mp4 | while read f; do echo "file '$work_dir/$f'"; done > concat_video.txt

# Create concat file for audio if it exists
if [ -d audio ] && [ -n "$(ls audio/seg_*.mp4 2>/dev/null)" ]; then
    ls -1 audio/seg_*.mp4 | while read f; do echo "file '$work_dir/$f'"; done > concat_audio.txt
    log "Remuxing video and audio..."
    ffmpeg -f concat -safe 0 -i concat_video.txt -f concat -safe 0 -i concat_audio.txt -c copy -map 0 -map 1 "video_${selected_res}.mp4" > /dev/null 2>&1
else
    log "Concatenating video only..."
    ffmpeg -f concat -safe 0 -i concat_video.txt -c copy "video_${selected_res}.mp4" > /dev/null 2>&1
fi

if [ -f "video_${selected_res}.mp4" ]; then
    log "✓ Video saved: video_${selected_res}.mp4"
    # Move to original directory
    mv "video_${selected_res}.mp4" -
    pwd
else
    error "Failed to create output video"
fi

# Cleanup
cd - > /dev/null
log "Cleaning up temporary files..."
rm -rf "$work_dir"
