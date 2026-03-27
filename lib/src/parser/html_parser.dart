import 'package:html/dom.dart';

import 'base.dart';

/// Parses [Metadata] from `<meta>`, `<title>`, and `<img>` tags.
///
/// This parser acts as a fallback when richer metadata sources
/// (like Open Graph / Twitter Card / JSON-LD) are not available.
class HtmlMetaParser with BaseMetaInfo {
  final Document? _document;

  HtmlMetaParser(this._document);

  /// How many valid image candidates to inspect.
  static const int _maxCandidates = 4;

  /// Skip images smaller than 32x32 px.
  static const int _minArea = 32 * 32;

  @override
  String? get title => _document?.head?.querySelector('title')?.text.trim();

  @override
  String? get desc =>
      _document?.head
          ?.querySelector("meta[name='description']")
          ?.attributes['content']
          ?.trim() ??
      _document?.head
          ?.querySelector("meta[property='og:description']")
          ?.attributes['content']
          ?.trim();

  @override
  String? get image => _findBestImage();

  @override
  String? get siteName =>
      _document?.head
          ?.querySelector("meta[property='og:site_name']")
          ?.attributes['content']
          ?.trim() ??
      _document?.head
          ?.querySelector("meta[name='site_name']")
          ?.attributes['content']
          ?.trim();

  @override
  String toString() => parse().toString();

  /// Checks the first few valid `<img>` candidates and returns the largest one.
  ///
  /// If dimensions are not available, the first non-junk image is used as a
  /// fallback.
  String? _findBestImage() {
    final imgs = _document?.body?.querySelectorAll('img');
    if (imgs == null || imgs.isEmpty) return null;

    String? bestSrc;
    int bestArea = -1;
    int candidateCount = 0;

    for (final img in imgs) {
      if (candidateCount >= _maxCandidates) break;

      final src = _extractImageSrc(img);
      if (src == null || src.isEmpty) continue;

      if (_isJunkImage(src, img)) continue;

      candidateCount++;

      final area = _getArea(img);

      if (area != null) {
        if (area > bestArea) {
          bestArea = area;
          bestSrc = src;
        }
      } else
        bestSrc ??= src;
    }

    return bestSrc;
  }

  /// Tries to extract image URL from common attributes used in regular and
  /// lazy-loaded images.
  static String? _extractImageSrc(Element img) {
    return img.attributes['src'] ??
        img.attributes['data-src'] ??
        img.attributes['data-lazy-src'];
  }

  /// Returns width * height from HTML attributes, or null if unavailable.
  static int? _getArea(Element img) {
    final w = int.tryParse(img.attributes['width'] ?? '');
    final h = int.tryParse(img.attributes['height'] ?? '');

    if (w != null && h != null && w > 0 && h > 0) {
      return w * h;
    }

    return null;
  }

  /// Returns true if this image is likely junk / decorative / tracking-related.
  static bool _isJunkImage(String src, Element img) {
    final s = src.toLowerCase();

    if (s.startsWith('data:')) return true;
    if (s.endsWith('.svg')) return true;

    const junkPatterns = [
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

    for (final pattern in junkPatterns) {
      if (s.contains(pattern)) return true;
    }

    final w = int.tryParse(img.attributes['width'] ?? '');
    final h = int.tryParse(img.attributes['height'] ?? '');

    if (w != null && h != null && w * h < _minArea) return true;
    if (w != null && w <= 2) return true;
    if (h != null && h <= 2) return true;

    return false;
  }
}
