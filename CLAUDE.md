# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Kiwify Video Downloader** — A tool to download HLS video streams from Kiwify using Chrome DevTools HAR (HTTP Archive) exports. The project uses a modular three-script architecture with separate concerns for parsing, authentication, and downloading.

## How to Run

### Main command
```bash
./download.sh --har <path/to/video.har>
```

The user interactively selects a resolution (1-5) from available options. The script then orchestrates the download and merge.

### Direct alternatives (less common)
```bash
./download.sh --html '<video src="..."></video>'   # From HTML video element
./download.sh --url <m3u8_url>                      # Direct m3u8 playlist URL
```

## Architecture

The project follows a **modular, single-responsibility pattern** with clear separation of concerns. It supports two major streaming protocols: HLS (Kiwify) and DASH (Finclass).

### File Responsibilities

| File | Purpose |
|------|---------|
| **download.sh** | Orchestration layer: parses input (HAR/HTML/URL), auto-detects HLS or DASH, extracts URLs/manifests, detects resolutions, prompts user, routes to appropriate helper |
| **helper_hls.sh** | HLS download/merge: downloads .ts segments using curl with auth headers, creates ffmpeg concat playlist, merges into MP4 |
| **helper_dash.sh** | DASH download/merge: downloads video/audio segments from manifest, creates concat playlists, remuxes with ffmpeg |
| **extract_headers_from_har.py** | Auth extraction: parses HAR JSON, finds CloudFront requests, extracts HTTP headers (User-Agent, Referer, etc.) for curl |

### Data Flow

**HLS (Kiwify):**
```
HAR File
  ↓ download.sh (detects .m3u8)
  ├─ Extracts m3u8 URL
  ├─ Calls extract_headers_from_har.py → headers.json
  ├─ Fetches master.m3u8 playlist
  ├─ Parses resolutions
  ├─ Prompts user for selection
  ↓
helper_hls.sh
  ├─ Downloads all .ts segments (with auth headers)
  ├─ Creates ffmpeg concat playlist
  ├─ Merges into MP4
  ↓
video_<resolution>.mp4
```

**DASH (Finclass):**
```
HAR File
  ↓ download.sh (detects .mpd)
  ├─ Extracts DASH manifest
  ├─ Parses available resolutions
  ├─ Prompts user for selection
  ↓
helper_dash.sh
  ├─ Downloads video segments from manifest
  ├─ Downloads audio segments from manifest
  ├─ Creates ffmpeg concat playlists
  ├─ Remuxes video + audio into MP4
  ↓
video_<resolution>.mp4
```

## Key Design Decisions

1. **HAR-based approach** — Eliminates manual URL hunting; captures auth automatically
2. **Modular scripts** — Each script has a single responsibility; can be debugged/improved independently
3. **Temporary directories** — Segments downloaded to `/tmp/hls_download_*` and cleaned up automatically
4. **Auth header extraction as separate step** — Makes debugging easier; provides audit trail of what headers are used
5. **Interactive resolution selection** — User chooses quality preference; script enforces valid choices

## External Dependencies

- **curl** — downloads .ts segments with authentication
- **ffmpeg** — merges video segments into MP4
- **Python 3** — parses HAR JSON files
- **jq** — JSON parsing (optional fallback to inline Python)

All are documented in README.md. Users should have these installed before running.

## Important Context for Modifications

### HAR File Handling
- HAR files contain sensitive auth tokens and cookies; they expire in hours
- Always extract from fresh capture (user should do immediately before download)
- Script searches for CloudFront requests to identify m3u8 URLs

### Resolution Detection
- Resolutions are parsed from the master m3u8 playlist (m3u8 defines available resolutions)
- Not all resolutions are available for all videos; script shows only what exists
- User is given interactive menu (1-5 options) to prevent invalid selection

### Error Handling Philosophy
- Errors should surface at component boundaries: if curl fails to download a segment, that's user's problem (expired auth/no internet)
- No silent retries; let user see and fix the actual issue
- Temporary directories are cleaned up even on failure

### Testing Approach
Testing this project requires actual Kiwify videos and valid HAR files (no mock data exists). Manual testing with real videos is the only practical verification method. Documentation (README, KIWIFY_GUIDE) serves as the specification for expected behavior.

## Documentation

- **README.md** — User-facing: quick start, features, troubleshooting
- **KIWIFY_GUIDE.md** — User-facing: step-by-step walkthrough with screenshots
- **ARCHITECTURE.md** — Technical: deep dive into file interactions, data flow, design decisions
- **This file** — For Claude Code: implementation context and modification guidance
