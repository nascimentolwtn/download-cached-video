// Detect video playback on Kiwify pages
(function() {
  let isCapturing = false;

  // Listen for all video elements on the page
  function initVideoDetection() {
    const videos = document.querySelectorAll('video');

    videos.forEach(video => {
      video.addEventListener('play', () => {
        if (!isCapturing) {
          isCapturing = true;
          chrome.runtime.sendMessage({ action: 'startCapture' }, response => {
            if (response?.success) {
              console.log('[Kiwify] Video detected - started capturing HAR');
            }
          });
        }
      });

      video.addEventListener('pause', () => {
        // Don't stop on pause, only on stop/end
      });

      video.addEventListener('ended', () => {
        if (isCapturing) {
          isCapturing = false;
          chrome.runtime.sendMessage({ action: 'stopCapture' }, response => {
            if (response?.success) {
              console.log('[Kiwify] Video ended - stopped capturing');
            }
          });
        }
      });
    });
  }

  // Initial detection
  initVideoDetection();

  // Watch for dynamically added video elements
  const observer = new MutationObserver(() => {
    initVideoDetection();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
