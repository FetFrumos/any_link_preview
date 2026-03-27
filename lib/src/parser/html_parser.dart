import 'package:html/dom.dart';

import 'base.dart';
import 'util.dart';

/// Parses [Metadata] from `<meta>`, `<title>`, and `<img>` tags.
class HtmlMetaParser with BaseMetaInfo {
  /// The [Document] to parse.
  final Document? _document;

  HtmlMetaParser(this._document);

  /// Max number of <img> candidates to evaluate.
  static const int _maxCandidates = 3;

  /// Minimum pixel area (width * height) to consider an image as content.
  /// Filters out tracking pixels, spacers, 1x1 gifs, tiny icons.
  static const int _minArea = 32 * 32;

  /// Get the [Metadata.title] from the <title> tag.
  @override
  String? get title => _document?.head?.querySelector('title')?.text;

  /// Get the [Metadata.desc] from the content of the
  /// <meta name="description"> tag.
  @override
  String? get desc => _document?.head
      ?.querySelector("meta[name='description']")
      ?.attributes
      .get('content');

  /// Get the [Metadata.image] from the <img> tags in the body.
  ///
  /// FORKED: Instead of returning the first <img> src, collects up to
  /// [_maxCandidates] images, filters out likely non-content images,
  /// and picks the one with the largest dimensions (from HTML attributes)
  /// or file size (via HEAD request).
  @override
  String? get image => _findBestImageSync();

  /// Get the [Metadata.siteName] from the content of the
  /// <meta name="site_name"> meta tag.
  @override
  String? get siteName => _document?.head
      ?.querySelector("meta[name='site_name']")
      ?.attributes
      .get('content');

  @override
  String toString() => parse().toString();

  // ---------------------------------------------------------------------------
  // Forked image selection logic
  // ---------------------------------------------------------------------------

  /// Synchronously selects the best image from HTML attributes only.
  /// This avoids making the getter async (which would break the BaseMetaInfo
  /// contract). Uses width/height attributes and filtering heuristics.
  String? _findBestImageSync() {
    final imgs = _document?.body?.querySelectorAll('img');
    if (imgs == null || imgs.isEmpty) return null;

    String? bestSrc;
    var bestArea = -1;
    var candidateCount = 0;

    for (final img in imgs) {
      if (candidateCount >= _maxCandidates) break;

      final src = img.attributes['src'];
      if (src == null || src.isEmpty) continue;

      // Skip obvious non-content images
      if (_isNonContentImage(src, img)) continue;

      candidateCount++;

      final area = _getArea(img);

      if (area != null) {
        // Has explicit dimensions — compare by area
        if (area > bestArea) {
          bestArea = area;
          bestSrc = src;
        }
      } else {
        bestSrc ??= src;
      }
    }

    return bestSrc;
  }

  /// Returns pixel area (width × height) from HTML attributes, or null.
  static int? _getArea(Element img) {
    final w = int.tryParse(img.attributes['width'] ?? '');
    final h = int.tryParse(img.attributes['height'] ?? '');
    if (w != null && h != null && w > 0 && h > 0) return w * h;
    return null;
  }

  /// Heuristic filter: returns true for images that are likely not
  /// meaningful page content (tracking pixels, icons, spacers, logos, etc.)
  static bool _isNonContentImage(String src, Element img) {
    final srcLower = src.toLowerCase();

    // Data URIs (usually tiny inline images)
    if (srcLower.startsWith('data:')) return true;

    // SVG files (usually icons/logos, not photos)
    if (srcLower.endsWith('.svg')) return true;

    // Common non-content path segments
    const skipPatterns = [
      'favicon',
      'icon',
      'pixel',
      'spacer',
      'tracking',
      'badge',
      'spinner',
      'loader',
      'avatar',
      '1x1',
      'blank.gif',
      'transparent.gif',
      'shim.gif',
    ];
    for (final pattern in skipPatterns) {
      if (srcLower.contains(pattern)) return true;
    }

    // Explicitly tiny images (from HTML attributes)
    final w = int.tryParse(img.attributes['width'] ?? '');
    final h = int.tryParse(img.attributes['height'] ?? '');
    if (w != null && h != null && w * h < _minArea) return true;
    // Also catch single-dimension tiny hints like width="1" or height="1"
    if (w != null && w <= 2) return true;
    if (h != null && h <= 2) return true;

    return false;
  }
}
