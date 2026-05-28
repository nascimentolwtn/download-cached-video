const statusEl = document.getElementById('status');
const statusText = document.getElementById('statusText');
const entryCount = document.getElementById('entryCount');
const stopBtn = document.getElementById('stopBtn');
const saveBtn = document.getElementById('saveBtn');
const resetBtn = document.getElementById('resetBtn');

// Update UI based on capture state
function updateUI(isCapturing, entryCountVal) {
  statusEl.className = 'status ' + (isCapturing ? 'capturing' : 'ready');
  statusText.textContent = isCapturing ? 'CAPTURING' : 'READY';
  entryCount.textContent = entryCountVal + ' entries captured';

  stopBtn.disabled = !isCapturing;
  saveBtn.disabled = entryCountVal === 0;
}

// Poll for status updates
function updateStatus() {
  chrome.runtime.sendMessage({ action: 'getHAR' }, (response) => {
    if (response) {
      const entries = response.har?.log?.entries?.length || 0;
      updateUI(response.isCapturing, entries);
    }
  });
}

// Initial status check
updateStatus();
const statusInterval = setInterval(updateStatus, 500);

// Stop capture
stopBtn.addEventListener('click', () => {
  chrome.runtime.sendMessage({ action: 'stopCapture' }, () => {
    updateStatus();
  });
});

// Save HAR to file
saveBtn.addEventListener('click', () => {
  chrome.runtime.sendMessage({ action: 'getHAR' }, (response) => {
    if (response.har && response.har.log.entries.length > 0) {
      const har = response.har;
      const timestamp = new Date().toISOString()
        .replace(/[T:.-]/g, '')
        .slice(0, 14);
      const filename = `kiwify_${timestamp}.har`;

      const dataStr = JSON.stringify(har, null, 2);
      const dataBlob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(dataBlob);

      chrome.downloads.download({
        url,
        filename,
        saveAs: true
      });

      // Show success feedback
      const originalText = saveBtn.textContent;
      saveBtn.textContent = '✓ Saved!';
      saveBtn.disabled = true;
      setTimeout(() => {
        saveBtn.textContent = originalText;
        updateStatus();
      }, 2000);
    }
  });
});

// Reset captured data
resetBtn.addEventListener('click', () => {
  if (confirm('Clear all captured data?')) {
    chrome.runtime.sendMessage({ action: 'resetCapture' }, () => {
      updateStatus();
    });
  }
});

// Cleanup
window.addEventListener('unload', () => {
  clearInterval(statusInterval);
});
