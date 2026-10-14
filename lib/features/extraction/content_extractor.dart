import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../core/utils/url_parser.dart';

class ExtractionResult {
  final String? title;
  final String? caption;
  final String? thumbnailUrl;
  final bool isCaptionComplete;
  final bool requiresTranscription;
  final bool isFallbackRequired;
  final String platform;

  const ExtractionResult({
    this.title,
    this.caption,
    this.thumbnailUrl,
    required this.isCaptionComplete,
    required this.requiresTranscription,
    this.isFallbackRequired = false,
    required this.platform,
  });
}

class ContentExtractor {
  final http.Client _httpClient;

  ContentExtractor({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Attempts to extract accessible metadata and caption from social reel or web link
  Future<ExtractionResult> extract(String rawUrl) async {
    final cleanUrl = UrlParser.normalizeUrl(rawUrl);
    final platform = UrlParser.identifyPlatform(cleanUrl);

    AppLogger.info('Extracting metadata for $platform URL: $cleanUrl');

    // 1. For Instagram, prioritize InstaUstad caption service to bypass login walls
    if (platform == 'instagram') {
      final instaustadCaption = await _extractViaInstaUstad(cleanUrl);
      if (instaustadCaption != null && instaustadCaption.isNotEmpty) {
        final isComplete = checkCompleteness(instaustadCaption);
        return ExtractionResult(
          title: 'Instagram Reel Recipe',
          caption: instaustadCaption,
          thumbnailUrl: null,
          isCaptionComplete: isComplete,
          requiresTranscription: !isComplete,
          isFallbackRequired: false,
          platform: platform,
        );
      }
    }

    // 2. Direct web extraction via OpenGraph / meta tags
    try {
      final uri = Uri.parse(cleanUrl);
      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final html = response.body;
        final title = _extractMetaTag(html, 'og:title') ?? _extractTitleTag(html);
        var description = _extractMetaTag(html, 'og:description') ??
            _extractMetaTag(html, 'twitter:description') ??
            _extractMetaTag(html, 'description');
        final image = _extractMetaTag(html, 'og:image') ?? _extractMetaTag(html, 'twitter:image');

        if (description != null && _isValidSocialCaption(description)) {
          description = _cleanInstagramDescription(description);

          final isComplete = checkCompleteness(description);
          return ExtractionResult(
            title: title,
            caption: description.trim(),
            thumbnailUrl: image,
            isCaptionComplete: isComplete,
            requiresTranscription: !isComplete,
            isFallbackRequired: false,
            platform: platform,
          );
        }
      }
    } catch (e) {
      AppLogger.info('Automatic web extraction encountered network/restriction: $e');
    }

    // Fallback: When content is restricted by platform login or blocked
    return ExtractionResult(
      title: null,
      caption: null,
      thumbnailUrl: null,
      isCaptionComplete: false,
      requiresTranscription: true,
      isFallbackRequired: true,
      platform: platform,
    );
  }

  bool _isValidSocialCaption(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;
    if (lower.contains('welcome back to instagram') ||
        lower.contains('login • instagram') ||
        lower.contains('see photos and videos that will disappear') ||
        lower.contains('create an account or log in to instagram') ||
        lower.contains('log into facebook') ||
        lower.contains('page not found') ||
        lower.contains("content isn't available right now")) {
      return false;
    }
    return true;
  }

  String _cleanInstagramDescription(String raw) {
    // 1. Match: "1,234 likes, 56 comments - @user on Date: "Actual caption...""
    final fullMetaQuote = RegExp(r'^[\d,\.KMkm\s]+likes?,\s*[\d,\.KMkm\s]+comments?\s*-\s*[^:]+?:\s*["“]([\s\S]+)["”]\s*$', caseSensitive: false).firstMatch(raw);
    if (fullMetaQuote != null && fullMetaQuote.group(1) != null) {
      return fullMetaQuote.group(1)!.trim();
    }

    // 2. Match: "1,234 likes, 56 comments - @user: Actual caption..."
    final fullMetaColon = RegExp(r'^[\d,\.KMkm\s]+likes?,\s*[\d,\.KMkm\s]+comments?\s*-\s*[^:]+?:\s*([\s\S]+)$', caseSensitive: false).firstMatch(raw);
    if (fullMetaColon != null && fullMetaColon.group(1) != null) {
      return fullMetaColon.group(1)!.trim();
    }

    // 3. Match: "@user on Date: "Actual caption...""
    final authorDateQuote = RegExp(r'^[^:]+?\s+on\s+[A-Za-z]+\s+\d+(?:,\s*\d{4})?:\s*["“]([\s\S]+)["”]\s*$', caseSensitive: false).firstMatch(raw);
    if (authorDateQuote != null && authorDateQuote.group(1) != null) {
      return authorDateQuote.group(1)!.trim();
    }

    return raw;
  }

  /// Extracts caption from public Instagram reels using InstaUstad service
  Future<String?> _extractViaInstaUstad(String instagramUrl) async {
    try {
      AppLogger.info('Attempting Instagram caption extraction via InstaUstad...');
      final response = await _httpClient.post(
        Uri.parse('https://instaustad.com/?service=caption'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Referer': 'https://instaustad.com/instagram-reel-caption.php',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
        body: jsonEncode({'url': instagramUrl}),
      ).timeout(const Duration(seconds: 14));

      if (response.statusCode == 200) {
        final dynamic rawDecoded = jsonDecode(response.body);
        if (rawDecoded is Map) {
          final decoded = Map<String, dynamic>.from(rawDecoded);
          if (decoded['success'] == true && decoded['caption'] != null) {
            final caption = decoded['caption']?.toString() ?? '';
            if (caption.trim().isNotEmpty) {
              AppLogger.info('Successfully extracted Instagram caption via InstaUstad (${caption.length} chars)');
              return caption.trim();
            }
          }
        }
      }
    } catch (e) {
      AppLogger.info('InstaUstad caption extraction error: $e');
    }
    return null;
  }

  /// Stage B: Completeness detection
  /// Determines whether the caption already contains sufficient ingredients & instructions
  bool checkCompleteness(String text) {
    if (text.length < 80) return false;
    final lower = text.toLowerCase();

    // Check for ingredient indicators
    final hasIngredientKeywords = lower.contains('ingredient') ||
        lower.contains('cup') ||
        lower.contains('tbsp') ||
        lower.contains('tsp') ||
        lower.contains('gram') ||
        lower.contains('clove') ||
        lower.contains('pinch') ||
        lower.contains('ml') ||
        lower.contains('oz');

    // Check for cooking method / step indicators
    final hasStepKeywords = lower.contains('instruction') ||
        lower.contains('method') ||
        lower.contains('step') ||
        lower.contains('directions') ||
        lower.contains('bake') ||
        lower.contains('fry') ||
        lower.contains('heat') ||
        lower.contains('mix') ||
        lower.contains('cook') ||
        lower.contains('serve') ||
        lower.contains('boil') ||
        RegExp(r'\d+\.|\bstep\s*\d+', caseSensitive: false).hasMatch(text);

    return hasIngredientKeywords && hasStepKeywords;
  }

  String? _extractMetaTag(String html, String propertyName) {
    final pattern = RegExp(
      '<meta\\s+(?:property|name)=["\']$propertyName["\']\\s+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    if (match != null) {
      return _decodeHtmlEntities(match.group(1));
    }

    // Try alternate attribute order: content="..." property="..."
    final altPattern = RegExp(
      '<meta\\s+content=["\']([^"\']+)["\']\\s+(?:property|name)=["\']$propertyName["\']',
      caseSensitive: false,
    );
    final altMatch = altPattern.firstMatch(html);
    if (altMatch != null) {
      return _decodeHtmlEntities(altMatch.group(1));
    }
    return null;
  }

  String? _extractTitleTag(String html) {
    final match = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
    return match != null ? _decodeHtmlEntities(match.group(1)) : null;
  }

  String? _decodeHtmlEntities(String? str) {
    if (str == null) return null;
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
