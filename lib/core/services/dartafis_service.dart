import 'dart:developer';
import 'dart:typed_data';

import 'package:dartafis/dartafis.dart';

class DartafisService {
  static const int _imgWidth = 300;
  static const int _imgHeight = 375;

  /// Extract a SearchTemplate from a raw grayscale fingerprint image.
  Future<SearchTemplate> extractTemplate(Uint8List rawImage) async {
    final image = FingerImage(
      width: _imgWidth,
      height: _imgHeight,
      bytes: rawImage,
      dpi: 500,
    );
    return await featureExtract(image);
  }

  /// Extract a template from a raw image and serialize it to bytes for storage.
  Future<Uint8List> extractAndSerialize(Uint8List rawImage) async {
    final template = await extractTemplate(rawImage);
    return serializeTemplate(template);
  }

  /// Find the best matching template among candidate raw images.
  /// Returns the index and score, or null if no match above threshold.
  Future<({int index, double score})?> findBestMatch(
    Uint8List probeRawImage,
    List<Uint8List> candidateRawImages, {
    double threshold = 20,
  }) async {
    final probe = await extractTemplate(probeRawImage);

    double bestScore = 0;
    int bestIndex = -1;

    for (int i = 0; i < candidateRawImages.length; i++) {
      try {
        final candidate = await extractTemplate(candidateRawImages[i]);
        final matcher = SearchMatcher(probe);
        final score = await matcher.match(candidate);
        if (score > bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      } catch (e) {
        continue;
      }
    }

    if (bestIndex >= 0 && bestScore >= threshold) {
      return (index: bestIndex, score: bestScore);
    }
    return null;
  }

  /// Identify a live probe image against a list of pre-extracted and serialized
  /// candidate templates.  This is the production path: candidate templates are
  /// deserialised directly without re-extracting features from raw images.
  ///
  /// Returns the index into [candidateTemplates] and the match score,
  /// or null when no candidate exceeds [threshold].
  Future<({int index, double score})?> identify(
    Uint8List probeImage,
    List<Uint8List> candidateTemplates, {
    double threshold = 30.0,
  }) async {
    log('[DartafisService] identify: extracting probe template '
        'from ${probeImage.length} byte image');
    final probe = await extractTemplate(probeImage);
    log('[DartafisService] identify: probe extracted, '
        'matching against ${candidateTemplates.length} candidates');

    for (int i = 0; i < candidateTemplates.length; i++) {
      try {
        final candidate = deserializeTemplate(candidateTemplates[i]);
        final matcher = SearchMatcher(probe);
        final score = await matcher.match(candidate);
        if (score >= threshold) {
          log('[DartafisService] identify: matched candidate #$i '
              'score=${score.toStringAsFixed(1)} threshold=$threshold');
          return (index: i, score: score);
        }
      } catch (e) {
        log('[DartafisService] identify: candidate #$i error: $e');
        continue;
      }
    }

    log('[DartafisService] identify: no match above threshold=$threshold');
    return null;
  }

  /// Serialize a SearchTemplate to bytes for DB storage.
  /// Format (binary):
  ///   offset 0: width (int32)
  ///   offset 4: height (int32)
  ///   offset 8: minutiae count (int32)
  ///   offset 12+: each minutia = x(int32) + y(int32) + direction(float64) + type(uint8)
  Uint8List serializeTemplate(SearchTemplate template) {
    final minutiae = template.minutiae;
    final count = minutiae.length;
    final buf = ByteData(12 + count * 17);
    buf.setInt32(0, template.width);
    buf.setInt32(4, template.height);
    buf.setInt32(8, count);
    for (int i = 0; i < count; i++) {
      final m = minutiae[i];
      final off = 12 + i * 17;
      buf.setInt32(off, m.x);
      buf.setInt32(off + 4, m.y);
      buf.setFloat64(off + 8, m.direction);
      buf.setUint8(off + 16, m.type == MinutiaType.ending ? 0 : 1);
    }
    return buf.buffer.asUint8List();
  }

  /// Deserialize bytes back to SearchTemplate.
  SearchTemplate deserializeTemplate(Uint8List data) {
    final buf = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final width = buf.getInt32(0);
    final height = buf.getInt32(4);
    final count = buf.getInt32(8);
    final minutiae = List<FeatureMinutia>.generate(count, (i) {
      final off = 12 + i * 17;
      return (
        x: buf.getInt32(off),
        y: buf.getInt32(off + 4),
        direction: buf.getFloat64(off + 8),
        type: buf.getUint8(off + 16) == 0
            ? MinutiaType.ending
            : MinutiaType.bifurcation,
      );
    });
    return SearchTemplate((
      width: width,
      height: height,
      minutiae: minutiae,
    ));
  }

  /// Attempt to parse [data] as a serialized dartafis template.
  /// Returns `true` if the binary header is consistent (positive dimensions
  /// and a plausible minutia count).
  bool isValidTemplate(Uint8List data) {
    if (data.length < 12) return false;
    try {
      final buf = ByteData.view(data.buffer, data.offsetInBytes, data.length);
      final w = buf.getInt32(0);
      final h = buf.getInt32(4);
      final cnt = buf.getInt32(8);
      return w > 0 && h > 0 && cnt >= 0 && (12 + cnt * 17) <= data.length;
    } catch (_) {
      return false;
    }
  }

  /// Migrate a legacy raw fingerprint image to a serialized dartafis template.
  /// Returns the serialized template bytes, or null if extraction fails.
  Future<Uint8List?> migrateLegacyImage(Uint8List rawImage) async {
    try {
      if (rawImage.length != _imgWidth * _imgHeight) {
        log('[DartafisService] migrateLegacyImage: unexpected image size '
            '${rawImage.length} (expected $_imgWidth × $_imgHeight)');
        return null;
      }
      final serialized = await extractAndSerialize(rawImage);
      log('[DartafisService] migrateLegacyImage: extracted template '
          '${serialized.length} bytes from legacy image');
      return serialized;
    } catch (e) {
      log('[DartafisService] migrateLegacyImage error: $e');
      return null;
    }
  }
}
