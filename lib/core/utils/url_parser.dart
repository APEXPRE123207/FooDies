class UrlParser {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  /// Extracts the first valid URL from raw text (handles shared text with descriptions)
  static String? extractUrl(String rawText) {
    final match = _urlRegex.firstMatch(rawText.trim());
    if (match != null) {
      return match.group(0);
    }
    final trimmed = rawText.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return null;
  }

  /// Identifies the platform from URL
  static String identifyPlatform(String rawUrl) {
    final lower = rawUrl.toLowerCase();
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      return 'instagram';
    } else if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com')) {
      return 'facebook';
    } else if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'youtube';
    } else if (lower.contains('tiktok.com')) {
      return 'tiktok';
    }
    return 'web';
  }

  /// Normalizes URL by stripping query tracking parameters (igsh, fbclid, utm_*, etc.)
  /// This ensures reliable duplicate detection even when query params differ.
  static String normalizeUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final filteredQueryParameters = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((key, _) =>
            key.startsWith('utm_') ||
            key == 'igsh' ||
            key == 'fbclid' ||
            key == 'ref' ||
            key == 'src' ||
            key == 's');

      Uri normalized;
      if (filteredQueryParameters.isEmpty) {
        normalized = uri.replace(query: '');
      } else {
        normalized = uri.replace(queryParameters: filteredQueryParameters);
      }

      var result = normalized.toString();
      if (result.endsWith('?')) {
        result = result.substring(0, result.length - 1);
      }
      if (result.endsWith('/') && normalized.path != '/') {
        result = result.substring(0, result.length - 1);
      }
      return result;
    } catch (_) {
      return rawUrl.trim();
    }
  }

  /// Validates whether a string is a valid web URL
  static bool isValidUrl(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }
}
