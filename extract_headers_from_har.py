#!/usr/bin/env python3
"""
Extract HTTP headers from HAR file for video requests
Useful for including auth/cookies in downloads
"""

import sys
import json
from pathlib import Path

def extract_headers_from_har(har_file, target_domain="cloudfront"):
    """Extract headers from HAR requests to a specific domain"""

    try:
        with open(har_file, 'r') as f:
            har_data = json.load(f)
    except Exception as e:
        print(f"Error reading HAR: {e}", file=sys.stderr)
        return {}

    entries = har_data.get('log', {}).get('entries', [])

    # Find video/cloudfront requests and extract headers
    headers = {}

    for entry in entries:
        request = entry.get('request', {})
        url = request.get('url', '')

        # Look for video-related requests to cloudfront
        if target_domain in url and ('.m3u8' in url or '.ts' in url):
            request_headers = request.get('headers', [])

            # Extract useful headers
            for header in request_headers:
                name = header.get('name', '').lower()
                value = header.get('value', '')

                # Skip content-related headers that change per request
                if name in ['authorization', 'cookie', 'referer', 'user-agent', 'accept', 'accept-language', 'accept-encoding']:
                    if name not in headers:  # Keep first occurrence
                        headers[name] = value

                # Keep X- headers (often auth/custom headers)
                if name.startswith('x-'):
                    if name not in headers:
                        headers[name] = value

            # If we found headers, we can stop
            if headers:
                break

    return headers

def format_curl_headers(headers):
    """Format headers for curl command"""
    curl_args = []
    for name, value in headers.items():
        curl_args.append(f"-H '{name}: {value}'")
    return ' '.join(curl_args)

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_headers_from_har.py <har_file> [domain]")
        print("\nExample:")
        print("  extract_headers_from_har.py network.har cloudfront")
        sys.exit(1)

    har_file = sys.argv[1]
    domain = sys.argv[2] if len(sys.argv) > 2 else "cloudfront"

    if not Path(har_file).exists():
        print(f"File not found: {har_file}", file=sys.stderr)
        sys.exit(1)

    print(f"Extracting headers from {har_file}...", file=sys.stderr)
    headers = extract_headers_from_har(har_file, domain)

    if not headers:
        print(f"No headers found for domain: {domain}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(headers)} relevant headers:\n", file=sys.stderr)
    for name, value in headers.items():
        # Mask sensitive values
        if name in ['authorization', 'cookie']:
            masked_value = value[:20] + "..." if len(value) > 20 else value
            print(f"  {name}: {masked_value}", file=sys.stderr)
        else:
            print(f"  {name}: {value}", file=sys.stderr)

    print("\n# Curl headers for download script:", file=sys.stderr)
    print(format_curl_headers(headers), file=sys.stderr)

    # Output headers as JSON for scripting
    print(json.dumps(headers, indent=2))

if __name__ == '__main__':
    main()
