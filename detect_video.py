#!/usr/bin/env python3
"""
Detect video files using file magic and optional ffprobe
More reliable than extension-based detection for cache files
"""

import sys
import os
import subprocess
import struct
from pathlib import Path

# Common video file signatures (magic bytes)
VIDEO_SIGNATURES = {
    b'\x00\x00\x00\x20ftyp': 'MP4/QuickTime',  # MP4 variants
    b'\x00\x00\x00\x18ftyp': 'MP4/QuickTime',
    b'\xFF\xD8\xFF': 'JPEG (not video)',
    b'\x1A\x45\xDF\xA3': 'Matroska/WebM',  # MKV, WebM
    b'\x00\x00\x01\xBA': 'MPEG-PS',
    b'\x00\x00\x01\xB3': 'MPEG Video',
    b'RIFF': 'AVI/WAV',  # Need to check further
    b'ID3': 'MP3/Audio',
    b'\xFF\xFB': 'MP3',
    b'FLV': 'Flash Video',
}

def is_video_file(filepath, use_ffprobe=False):
    """
    Check if a file is a video file

    Args:
        filepath: Path to file to check
        use_ffprobe: Use ffprobe for more reliable detection (requires ffmpeg)

    Returns:
        tuple: (is_video, file_type_str)
    """
    filepath = Path(filepath)

    if not filepath.exists():
        return False, "File not found"

    if not filepath.is_file():
        return False, "Not a file"

    # Check file size (skip very small files)
    if filepath.stat().st_size < 1024 * 1024:  # Less than 1MB
        return False, "Too small"

    # Check magic bytes
    try:
        with open(filepath, 'rb') as f:
            header = f.read(512)
    except (IOError, OSError) as e:
        return False, f"Cannot read file: {e}"

    if not header:
        return False, "Empty file"

    # Check known signatures
    for signature, filetype in VIDEO_SIGNATURES.items():
        if header.startswith(signature):
            if 'JPEG' in filetype or 'MP3' in filetype or 'Audio' in filetype:
                continue
            if 'AVI' in filetype:
                # Need to check further for AVI
                if b'AVI ' in header[:200]:
                    return True, filetype
                continue
            return True, filetype

    # Try ffprobe if available
    if use_ffprobe:
        try:
            result = subprocess.run(
                ['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                 '-show_entries', 'stream=codec_type', '-of', 'default=noprint_wrappers=1:nokey=1:noprint_wrappers=1',
                 str(filepath)],
                capture_output=True,
                timeout=5,
                text=True
            )
            if result.returncode == 0 and 'video' in result.stdout:
                return True, "Detected by ffprobe"
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # Check by file command (if available)
    try:
        result = subprocess.run(
            ['file', '-b', str(filepath)],
            capture_output=True,
            timeout=2,
            text=True
        )
        if result.returncode == 0:
            output = result.stdout.lower()
            if any(keyword in output for keyword in ['video', 'mpeg', 'quicktime', 'matroska', 'webm', 'flv']):
                return True, f"file command: {result.stdout.strip()}"
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return False, "Unknown format"

def main():
    if len(sys.argv) < 2:
        print("Usage: detect_video.py <filepath> [--ffprobe]")
        print("Check if a file is a video file")
        sys.exit(1)

    filepath = sys.argv[1]
    use_ffprobe = '--ffprobe' in sys.argv

    is_video, filetype = is_video_file(filepath, use_ffprobe)

    if is_video:
        print(f"✓ Video file: {filetype}")
        sys.exit(0)
    else:
        print(f"✗ Not a video file: {filetype}")
        sys.exit(1)

if __name__ == '__main__':
    main()
