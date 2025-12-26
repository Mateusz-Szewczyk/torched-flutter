import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

// Web-specific utilities

/// Replace browser URL without page reload (removes OAuth tokens from URL)
void replaceUrlState(String newUrl) {
  if (!kIsWeb) return;

  try {
    // Use Web API to call history.replaceState
    web.window.history.replaceState(null, '', newUrl);
  } catch (e) {
    // Ignore errors - URL cleanup is not critical
  }
}

