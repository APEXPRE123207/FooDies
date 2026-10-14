import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/utils/url_parser.dart';

void main() {
  group('UrlParser Tests', () {
    test('extractUrl correctly extracts URL from messy social share text', () {
      const shareText =
          'Check out this incredible pasta recipe by Chef Luigi! https://www.instagram.com/reel/C8XYZ123/?igsh=MWQ123456789 and save it for dinner.';
      final extracted = UrlParser.extractUrl(shareText);
      expect(extracted, 'https://www.instagram.com/reel/C8XYZ123/?igsh=MWQ123456789');
    });

    test('extractUrl returns direct URL when already clean', () {
      const url = 'https://www.facebook.com/reel/987654321';
      final extracted = UrlParser.extractUrl(url);
      expect(extracted, url);
    });

    test('identifyPlatform identifies social platforms correctly', () {
      expect(UrlParser.identifyPlatform('https://www.instagram.com/reel/xyz123'), 'instagram');
      expect(UrlParser.identifyPlatform('https://instagr.am/p/xyz123'), 'instagram');
      expect(UrlParser.identifyPlatform('https://www.facebook.com/reel/123456'), 'facebook');
      expect(UrlParser.identifyPlatform('https://fb.watch/abcd123/'), 'facebook');
      expect(UrlParser.identifyPlatform('https://www.youtube.com/shorts/xyz'), 'youtube');
      expect(UrlParser.identifyPlatform('https://tiktok.com/@chef/video/123'), 'tiktok');
      expect(UrlParser.identifyPlatform('https://cooking.nytimes.com/recipes/123'), 'web');
    });

    test('normalizeUrl strips tracking parameters for reliable duplicate detection', () {
      const url1 = 'https://www.instagram.com/reel/C8XYZ123/?igsh=TRACKING_TOKEN_A';
      const url2 = 'https://www.instagram.com/reel/C8XYZ123/?igsh=TRACKING_TOKEN_B&utm_source=share';

      final norm1 = UrlParser.normalizeUrl(url1);
      final norm2 = UrlParser.normalizeUrl(url2);

      expect(norm1, 'https://www.instagram.com/reel/C8XYZ123');
      expect(norm2, 'https://www.instagram.com/reel/C8XYZ123');
      expect(norm1, equals(norm2));
    });

    test('isValidUrl detects valid and invalid URLs', () {
      expect(UrlParser.isValidUrl('https://instagram.com/reel/123'), isTrue);
      expect(UrlParser.isValidUrl('http://example.com/recipe'), isTrue);
      expect(UrlParser.isValidUrl('not a url'), isFalse);
      expect(UrlParser.isValidUrl('ftp://example.com'), isFalse);
    });
  });
}
