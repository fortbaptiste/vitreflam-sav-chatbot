(function() {
  'use strict';

  // Configuration
  var CHAT_URL = window.OLIVER_CHAT_URL || 'https://vitreflam-sav-chatbot.onrender.com';
  var BRAND_COLOR = '#dc2626'; // red-600

  // Prevent double-init
  if (window.__oliverWidgetLoaded) return;
  window.__oliverWidgetLoaded = true;

  // Create styles
  var style = document.createElement('style');
  style.textContent = [
    '#oliver-widget-bubble {',
    '  position: fixed;',
    '  bottom: 24px;',
    '  right: 24px;',
    '  width: 60px;',
    '  height: 60px;',
    '  border-radius: 50%;',
    '  background: ' + BRAND_COLOR + ';',
    '  color: white;',
    '  border: none;',
    '  cursor: pointer;',
    '  box-shadow: 0 4px 16px rgba(0,0,0,0.2);',
    '  z-index: 99998;',
    '  display: flex;',
    '  align-items: center;',
    '  justify-content: center;',
    '  transition: transform 0.2s ease, box-shadow 0.2s ease;',
    '}',
    '#oliver-widget-bubble:hover {',
    '  transform: scale(1.08);',
    '  box-shadow: 0 6px 24px rgba(0,0,0,0.3);',
    '}',
    '#oliver-widget-bubble .oliver-icon-chat,',
    '#oliver-widget-bubble .oliver-icon-close {',
    '  width: 28px;',
    '  height: 28px;',
    '  transition: opacity 0.2s ease, transform 0.2s ease;',
    '  position: absolute;',
    '}',
    '#oliver-widget-bubble .oliver-icon-close {',
    '  opacity: 0;',
    '  transform: rotate(-90deg);',
    '}',
    '#oliver-widget-bubble.oliver-open .oliver-icon-chat {',
    '  opacity: 0;',
    '  transform: rotate(90deg);',
    '}',
    '#oliver-widget-bubble.oliver-open .oliver-icon-close {',
    '  opacity: 1;',
    '  transform: rotate(0deg);',
    '}',
    '#oliver-widget-frame-container {',
    '  position: fixed;',
    '  bottom: 96px;',
    '  right: 24px;',
    '  width: 400px;',
    '  height: 580px;',
    '  max-height: calc(100vh - 120px);',
    '  max-width: calc(100vw - 32px);',
    '  border-radius: 16px;',
    '  overflow: hidden;',
    '  box-shadow: 0 8px 40px rgba(0,0,0,0.2);',
    '  z-index: 99999;',
    '  opacity: 0;',
    '  transform: translateY(16px) scale(0.95);',
    '  pointer-events: none;',
    '  transition: opacity 0.25s ease, transform 0.25s ease;',
    '}',
    '#oliver-widget-frame-container.oliver-visible {',
    '  opacity: 1;',
    '  transform: translateY(0) scale(1);',
    '  pointer-events: auto;',
    '}',
    '#oliver-widget-frame-container iframe {',
    '  width: 100%;',
    '  height: 100%;',
    '  border: none;',
    '  background: white;',
    '}',
    '#oliver-widget-badge {',
    '  position: fixed;',
    '  bottom: 88px;',
    '  right: 24px;',
    '  background: white;',
    '  color: #374151;',
    '  padding: 8px 16px;',
    '  border-radius: 8px;',
    '  box-shadow: 0 2px 12px rgba(0,0,0,0.15);',
    '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;',
    '  font-size: 14px;',
    '  z-index: 99997;',
    '  opacity: 0;',
    '  transform: translateY(8px);',
    '  pointer-events: none;',
    '  transition: opacity 0.3s ease, transform 0.3s ease;',
    '  white-space: nowrap;',
    '}',
    '#oliver-widget-badge.oliver-badge-show {',
    '  opacity: 1;',
    '  transform: translateY(0);',
    '  pointer-events: auto;',
    '}',
    '#oliver-widget-badge::after {',
    '  content: "";',
    '  position: absolute;',
    '  bottom: -6px;',
    '  right: 28px;',
    '  width: 12px;',
    '  height: 12px;',
    '  background: white;',
    '  transform: rotate(45deg);',
    '  box-shadow: 2px 2px 4px rgba(0,0,0,0.1);',
    '}',
    '@media (max-width: 480px) {',
    '  #oliver-widget-frame-container {',
    '    bottom: 0;',
    '    right: 0;',
    '    width: 100vw;',
    '    height: 100vh;',
    '    max-height: 100vh;',
    '    max-width: 100vw;',
    '    border-radius: 0;',
    '  }',
    '  #oliver-widget-bubble {',
    '    bottom: 16px;',
    '    right: 16px;',
    '  }',
    '  #oliver-widget-badge {',
    '    bottom: 80px;',
    '    right: 16px;',
    '  }',
    '}'
  ].join('\n');
  document.head.appendChild(style);

  // Chat icon SVG
  var chatIconSvg = '<svg class="oliver-icon-chat" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>';

  // Close icon SVG
  var closeIconSvg = '<svg class="oliver-icon-close" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';

  // Create badge tooltip
  var badge = document.createElement('div');
  badge.id = 'oliver-widget-badge';
  badge.textContent = 'Besoin d\'aide ? Discutez avec Oliver';
  document.body.appendChild(badge);

  // Create bubble button
  var bubble = document.createElement('button');
  bubble.id = 'oliver-widget-bubble';
  bubble.setAttribute('aria-label', 'Ouvrir le chat');
  bubble.innerHTML = chatIconSvg + closeIconSvg;
  document.body.appendChild(bubble);

  // Create frame container (lazy - iframe loaded on first open)
  var frameContainer = document.createElement('div');
  frameContainer.id = 'oliver-widget-frame-container';
  document.body.appendChild(frameContainer);

  var isOpen = false;
  var iframeLoaded = false;

  function toggleChat() {
    isOpen = !isOpen;

    // Hide badge when opened
    badge.classList.remove('oliver-badge-show');

    if (isOpen) {
      bubble.classList.add('oliver-open');
      bubble.setAttribute('aria-label', 'Fermer le chat');

      // Lazy load iframe on first open
      if (!iframeLoaded) {
        var iframe = document.createElement('iframe');
        iframe.src = CHAT_URL;
        iframe.title = 'Oliver - Assistance Vitreflam';
        iframe.setAttribute('loading', 'lazy');
        frameContainer.appendChild(iframe);
        iframeLoaded = true;
      }

      frameContainer.classList.add('oliver-visible');
    } else {
      bubble.classList.remove('oliver-open');
      bubble.setAttribute('aria-label', 'Ouvrir le chat');
      frameContainer.classList.remove('oliver-visible');
    }
  }

  bubble.addEventListener('click', toggleChat);

  // Close on Escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && isOpen) {
      toggleChat();
    }
  });

  // Show badge tooltip after 3 seconds (only once)
  setTimeout(function() {
    if (!isOpen) {
      badge.classList.add('oliver-badge-show');
      // Auto-hide after 8 seconds
      setTimeout(function() {
        badge.classList.remove('oliver-badge-show');
      }, 8000);
    }
  }, 3000);

})();
