import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/url_parser.dart';

class HeadlessWebviewResult {
  final String? caption;
  final String? transcript;
  final String? title;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String extractionMethod;

  const HeadlessWebviewResult({
    this.caption,
    this.transcript,
    this.title,
    this.thumbnailUrl,
    this.videoUrl,
    required this.extractionMethod,
  });
}

/// 100% on-device headless in-app WebView extractor.
/// Loads social media pages in the device's Chromium engine, allowing
/// JavaScript to render the DOM without triggering cloud bot blocks.
class HeadlessWebviewExtractor {
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.179 Mobile Safari/537.36';

  static const String _jsExtractionScript = r'''
(function() {
  try {
    var extractedCaption = null;
    var extractedTitle = null;
    var extractedThumbnail = null;
    var extractedVideoUrl = null;
    var extractedTranscript = null;
    var method = 'unknown';

    // 0. Extract direct Video URL and video subtitle tracks if available
    var video = document.querySelector('video');
    if (video) {
      extractedVideoUrl = video.src || (video.querySelector('source') ? video.querySelector('source').src : null);
      if (video.textTracks && video.textTracks.length > 0) {
        var cuesList = [];
        for (var t = 0; t < video.textTracks.length; t++) {
          var track = video.textTracks[t];
          if (track.cues) {
            for (var c = 0; c < track.cues.length; c++) {
              cuesList.push(track.cues[c].text);
            }
          }
        }
        if (cuesList.length > 0) {
          extractedTranscript = cuesList.join(' ');
        }
      }
    }

    // 0.1 Check for closed caption elements / video subtitles in DOM
    if (!extractedTranscript) {
      var ccNodes = document.querySelectorAll('.caption-track, .ytp-caption-segment, [class*="CaptionText"], [aria-label*="Captions"], [data-testid="audio-transcript"]');
      if (ccNodes && ccNodes.length > 0) {
        var ccTexts = [];
        for (var k = 0; k < ccNodes.length; k++) {
          var ct = ccNodes[k].innerText || ccNodes[k].textContent;
          if (ct && ct.trim().length > 0) ccTexts.push(ct.trim());
        }
        if (ccTexts.length > 0) {
          extractedTranscript = ccTexts.join(' ');
        }
      }
    }

    // Click any "more" / "see more" buttons to uncollapse long Instagram/TikTok captions
    try {
      var moreBtns = document.querySelectorAll('div[role="button"], span[role="button"], a.CaptionComments, a[class*="more"], span[class*="more"], button');
      for (var b = 0; b < moreBtns.length; b++) {
        var txt = (moreBtns[b].innerText || moreBtns[b].textContent || '').toLowerCase().trim();
        if (txt === 'more' || txt.includes('... more') || txt.includes('view more') || txt.includes('see more')) {
          moreBtns[b].click();
        }
      }
    } catch(e) {}

    // 1. Check Instagram Embed format
    var embedCaption = document.querySelector('.Caption, div.Caption');
    if (embedCaption && embedCaption.innerText && embedCaption.innerText.trim().length > 15) {
      var embedUser = document.querySelector('.CaptionUsername');
      var embedImg = document.querySelector('img.EmbeddedMediaImage');
      extractedCaption = embedCaption.innerText.trim();
      extractedTitle = embedUser ? embedUser.innerText.trim() : null;
      extractedThumbnail = embedImg ? embedImg.src : null;
      method = 'instagram-embed';
    }

    // 1.1 Check raw Instagram JSON in script tags (edge_media_to_caption) for full untruncated text
    if (!extractedCaption) {
      try {
        var allScripts = document.querySelectorAll('script:not([src])');
        for (var s = 0; s < allScripts.length; s++) {
          var sc = allScripts[s].innerText || '';
          if (sc.indexOf('edge_media_to_caption') !== -1) {
            var m = sc.match(/"edge_media_to_caption":\s*\{\s*"edges":\s*\[\s*\{\s*"node":\s*\{\s*"text":\s*"([^"]+)"/);
            if (m && m[1]) {
              extractedCaption = JSON.parse('"' + m[1] + '"');
              method = 'script-edge-caption';
              break;
            }
          }
        }
      } catch(e) {}
    }

    // 2. Check JSON-LD script tags
    if (!extractedCaption) {
      var scripts = document.querySelectorAll('script[type="application/ld+json"]');
      for (var i = 0; i < scripts.length; i++) {
        try {
          var data = JSON.parse(scripts[i].innerText);
          if (data) {
            var cap = data.articleBody || data.caption || data.description;
            if (cap && cap.trim().length > 20) {
              extractedCaption = cap.trim();
              extractedTitle = data.headline || data.name || null;
              extractedThumbnail = data.thumbnailUrl || (data.image ? (Array.isArray(data.image) ? data.image[0] : data.image) : null);
              if (data.transcript) {
                extractedTranscript = data.transcript;
              }
              if (data.contentUrl) {
                extractedVideoUrl = data.contentUrl;
              }
              method = 'json-ld';
              break;
            }
          }
        } catch(e) {}
      }
    }

    // 3. Check article/main post DOM content
    if (!extractedCaption) {
      var article = document.querySelector('article, main');
      if (article) {
        var spans = article.querySelectorAll('span, p, h1, div[data-testid="post-comment-root"]');
        var bestText = '';
        for (var j = 0; j < spans.length; j++) {
          var text = spans[j].innerText || '';
          if (text.length > bestText.length && 
              !text.includes('Log in') && 
              !text.includes('Sign up') && 
              !text.includes('See more photos') &&
              !text.includes('Welcome back to Instagram')) {
            bestText = text;
          }
        }
        if (bestText.length > 30) {
          extractedCaption = bestText.trim();
          extractedTitle = document.title || null;
          method = 'dom-article';
        }
      }
    }

    // 4. Check OpenGraph / Twitter meta tags
    var ogDesc = document.querySelector('meta[property="og:description"]');
    var twDesc = document.querySelector('meta[name="twitter:description"]');
    var stdDesc = document.querySelector('meta[name="description"]');
    var ogTitle = document.querySelector('meta[property="og:title"]');
    var ogImg = document.querySelector('meta[property="og:image"]');
    var ogVideo = document.querySelector('meta[property="og:video"], meta[property="og:video:url"], meta[property="og:video:secure_url"], meta[name="twitter:player:stream"]');

    if (!extractedCaption) {
      var desc = (ogDesc ? ogDesc.content : null) || 
                 (twDesc ? twDesc.content : null) || 
                 (stdDesc ? stdDesc.content : null);

      if (desc && desc.trim().length > 10) {
        extractedCaption = desc.trim();
        extractedTitle = ogTitle ? ogTitle.content : (document.title || null);
        extractedThumbnail = ogImg ? ogImg.content : null;
        method = 'meta-tags';
      }
    }

    // 5. Ensure Video URL is captured from meta tags or scripts if not already set
    if (!extractedVideoUrl && ogVideo && ogVideo.content) {
      extractedVideoUrl = ogVideo.content;
    }

    if (!extractedVideoUrl) {
      try {
        var allScripts = document.querySelectorAll('script:not([src])');
        for (var s = 0; s < allScripts.length; s++) {
          var sc = allScripts[s].innerText || '';
          if (sc.indexOf('video_url') !== -1 || sc.indexOf('playable_url') !== -1) {
            var vm = sc.match(/"video_url":\s*"([^"]+)"/) || sc.match(/"playable_url":\s*"([^"]+)"/);
            if (vm && vm[1]) {
              extractedVideoUrl = JSON.parse('"' + vm[1] + '"');
              break;
            }
          }
        }
      } catch(e) {}
    }

    if (extractedCaption || extractedTranscript || extractedVideoUrl) {
      return JSON.stringify({
        caption: extractedCaption,
        transcript: extractedTranscript,
        title: extractedTitle,
        thumbnail: extractedThumbnail,
        videoUrl: extractedVideoUrl,
        method: method
      });
    }

    return JSON.stringify({ error: 'No caption, transcript, or video found in DOM' });
  } catch (err) {
    return JSON.stringify({ error: err.toString() });
  }
})();
''';

  /// Extracts caption and metadata using an in-memory WebViewController
  Future<HeadlessWebviewResult?> extract(String rawUrl, {Duration timeout = const Duration(seconds: 14)}) async {
    final cleanUrl = UrlParser.normalizeUrl(rawUrl);
    final platform = UrlParser.identifyPlatform(cleanUrl);

    // Prepare candidate URLs (e.g. prioritize captioned embed for Instagram reels)
    final urlsToTry = <String>[];
    if (platform == 'instagram') {
      final shortcodeMatch = RegExp(r'(?:reel|reels|p)\/([A-Za-z0-9_-]+)', caseSensitive: false).firstMatch(cleanUrl);
      if (shortcodeMatch != null && shortcodeMatch.group(1) != null) {
        final code = shortcodeMatch.group(1)!;
        urlsToTry.add('https://www.instagram.com/p/$code/embed/captioned/');
      }
    }
    urlsToTry.add(cleanUrl);

    HeadlessWebviewResult? bestResult;
    for (final targetUrl in urlsToTry) {
      try {
        AppLogger.info('HeadlessWebView attempting extraction for: $targetUrl');
        final result = await _extractSingle(targetUrl, timeout);
        if (result != null) {
          if (bestResult == null) {
            bestResult = result;
          } else {
            bestResult = HeadlessWebviewResult(
              caption: (bestResult.caption != null && bestResult.caption!.trim().isNotEmpty)
                  ? bestResult.caption
                  : result.caption,
              transcript: (bestResult.transcript != null && bestResult.transcript!.trim().isNotEmpty)
                  ? bestResult.transcript
                  : result.transcript,
              title: bestResult.title ?? result.title,
              thumbnailUrl: bestResult.thumbnailUrl ?? result.thumbnailUrl,
              videoUrl: bestResult.videoUrl ?? result.videoUrl,
              extractionMethod: '${bestResult.extractionMethod}+${result.extractionMethod}',
            );
          }

          // If we have both caption AND videoUrl (or transcript), we have everything needed
          if (bestResult.caption != null && (bestResult.videoUrl != null || bestResult.transcript != null)) {
            AppLogger.info('HeadlessWebView successfully gathered caption and media via ${bestResult.extractionMethod}');
            return bestResult;
          }
        }
      } catch (e) {
        AppLogger.info('HeadlessWebView single attempt exception: $e');
      }
    }

    if (bestResult != null &&
        ((bestResult.caption != null && bestResult.caption!.trim().isNotEmpty) ||
         (bestResult.transcript != null && bestResult.transcript!.trim().isNotEmpty) ||
         (bestResult.videoUrl != null && bestResult.videoUrl!.trim().isNotEmpty))) {
      AppLogger.info('HeadlessWebView returning accumulated extraction via ${bestResult.extractionMethod}');
      return bestResult;
    }

    return null;
  }

  Future<HeadlessWebviewResult?> _extractSingle(String url, Duration timeout) async {
    WebViewController controller;
    try {
      controller = WebViewController();
    } catch (e) {
      AppLogger.info('Headless WebView platform controller unavailable (running in unit test or unsupported OS): $e');
      return null;
    }

    final completer = Completer<HeadlessWebviewResult?>();
    var hasEvaluated = false;

    Future<void> evaluateJs() async {
      if (hasEvaluated || completer.isCompleted) return;
      hasEvaluated = true;

      // Allow a brief moment for DOM hydration
      await Future.delayed(const Duration(milliseconds: 1200));
      if (completer.isCompleted) return;

      try {
        final jsResult = await controller.runJavaScriptReturningResult(_jsExtractionScript);
        String rawJson = jsResult.toString();

        // Unwrap extra quotes or JSON encoding if returned as stringified object
        if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
          try {
            rawJson = jsonDecode(rawJson) as String;
          } catch (_) {}
        }

        final dynamic decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final caption = decoded['caption']?.toString();
          final transcript = decoded['transcript']?.toString();
          if ((caption != null && caption.trim().isNotEmpty) ||
              (transcript != null && transcript.trim().isNotEmpty)) {
            completer.complete(HeadlessWebviewResult(
              caption: caption?.trim(),
              transcript: transcript?.trim(),
              title: decoded['title']?.toString(),
              thumbnailUrl: decoded['thumbnail']?.toString(),
              videoUrl: decoded['videoUrl']?.toString(),
              extractionMethod: decoded['method']?.toString() ?? 'webview-dom',
            ));
            return;
          }
        }
      } catch (e) {
        AppLogger.info('Headless WebView JS evaluation error: $e');
      }

      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setUserAgent(_mobileUserAgent);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await evaluateJs();
          },
          onWebResourceError: (err) {
            AppLogger.info('Headless WebView resource error: ${err.description}');
          },
        ),
      );

      await controller.loadRequest(Uri.parse(url));

      // Fallback timer in case onPageFinished delays or page streams
      Timer(const Duration(seconds: 5), () {
        if (!hasEvaluated && !completer.isCompleted) {
          evaluateJs();
        }
      });
    } catch (e) {
      AppLogger.info('Headless WebView setup error: $e');
      if (!completer.isCompleted) completer.complete(null);
    }

    // Global safety timeout
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        AppLogger.info('Headless WebView extraction timed out after ${timeout.inSeconds}s');
        return null;
      },
    );
  }
}
