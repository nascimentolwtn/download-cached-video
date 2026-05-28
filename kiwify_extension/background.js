let harData = null;
let isCapturing = false;
let captureStartTime = null;
const networkLog = {};

// Initialize HAR structure
function initHAR() {
  return {
    log: {
      version: '1.2',
      creator: {
        name: 'Kiwify Video Downloader',
        version: '1.0.0'
      },
      pages: [],
      entries: []
    }
  };
}

// Start capturing network traffic
function startCapture() {
  if (isCapturing) return;

  isCapturing = true;
  captureStartTime = new Date().toISOString();
  harData = initHAR();
  harData.log.pages.push({
    startedDateTime: captureStartTime,
    id: 'page_1',
    title: 'Kiwify Video',
    pageTimings: {
      onContentLoad: -1,
      onLoad: -1
    }
  });

  console.log('[Background] Started capturing HAR');
}

// Stop capturing
function stopCapture() {
  isCapturing = false;
  console.log('[Background] Stopped capturing. Entries:', harData?.log?.entries?.length || 0);
}

// Format request headers for HAR
function formatHeaders(headers) {
  return Object.entries(headers).map(([name, value]) => ({
    name: name.toLowerCase(),
    value: String(value)
  }));
}

// Capture request details
chrome.webRequest.onBeforeSendHeaders.addListener(
  (details) => {
    if (!isCapturing || !harData) return;

    const { tabId, requestId, url, method, requestHeaders } = details;

    networkLog[requestId] = {
      url,
      method,
      requestHeaders,
      startTime: new Date(details.timeStamp).toISOString(),
      tabId
    };
  },
  { urls: ['<all_urls>'] },
  ['requestHeaders']
);

// Capture response details
chrome.webRequest.onCompleted.addListener(
  (details) => {
    if (!isCapturing || !harData) return;

    const request = networkLog[details.requestId];
    if (!request) return;

    const entry = {
      pageref: 'page_1',
      startedDateTime: request.startTime,
      time: details.timeStamp - (new Date(request.startTime).getTime()),
      request: {
        method: request.method,
        url: request.url,
        httpVersion: 'HTTP/1.1',
        headers: formatHeaders(request.requestHeaders),
        queryString: [],
        cookies: [],
        headersSize: -1,
        bodySize: -1
      },
      response: {
        status: details.statusCode,
        statusText: details.statusLine || '',
        httpVersion: 'HTTP/1.1',
        headers: details.responseHeaders ? formatHeaders(
          details.responseHeaders.reduce((acc, h) => ({
            ...acc,
            [h.name]: h.value
          }), {})
        ) : [],
        cookies: [],
        content: {
          size: 0,
          mimeType: details.type
        },
        redirectURL: '',
        headersSize: -1,
        bodySize: -1,
        _error: null
      },
      cache: {},
      timings: {
        blocked: -1,
        dns: -1,
        connect: -1,
        send: -1,
        wait: -1,
        receive: -1,
        ssl: -1
      }
    };

    harData.log.entries.push(entry);
    delete networkLog[details.requestId];
  },
  { urls: ['<all_urls>'] }
);

// Handle errors
chrome.webRequest.onErrorOccurred.addListener(
  (details) => {
    if (networkLog[details.requestId]) {
      delete networkLog[details.requestId];
    }
  },
  { urls: ['<all_urls>'] }
);

// Listen for messages from content script and popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'startCapture') {
    startCapture();
    sendResponse({ success: true });
  } else if (request.action === 'stopCapture') {
    stopCapture();
    sendResponse({ success: true });
  } else if (request.action === 'getHAR') {
    sendResponse({ har: harData, isCapturing });
  } else if (request.action === 'resetCapture') {
    isCapturing = false;
    harData = null;
    networkLog = {};
    sendResponse({ success: true });
  }
});
