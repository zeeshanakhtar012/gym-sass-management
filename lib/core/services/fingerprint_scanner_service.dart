import 'dart:typed_data';

class FingerprintMatchResult {
  /// Index into the candidate list that produced this match.
  final int templateIndex;

  /// Raw match score from the biometric matcher (dartafis range 0-100).
  final double score;

  /// The threshold used for this match.
  final double threshold;

  /// True when [score] >= [threshold].
  bool get isMatched => score >= threshold;

  FingerprintMatchResult({
    required this.templateIndex,
    required this.score,
    required this.threshold,
  });

  @override
  String toString() =>
      'FingerprintMatchResult(index=$templateIndex, '
      'score=${score.toStringAsFixed(1)}, '
      'threshold=$threshold, matched=$isMatched)';
}

abstract class FingerprintScannerService {
  /// Check whether a ZKTeco fingerprint scanner is connected and usable.
  Future<bool> isScannerConnected();

  /// Enroll a fingerprint.
  ///
  /// Returns a map with two keys:
  ///   - `'rawImage'` (`Uint8List`): the raw 300×375 grayscale image (used
  ///     internally for template extraction, **not** persisted to the database).
  ///   - `'template'` (`Uint8List`): the ZK SDK template (stored for legacy
  ///     `fingerprint_template` column, but **not** used for dartafis matching).
  ///
  /// Returns `null` on failure.
  Future<Map<String, dynamic>?> enrollFingerprint();

  /// Load ZK templates into the SDK’s in-memory DB for ZK-based matching
  /// (currently broken on the ZK9500 – kept for diagnostic use only).
  void loadTemplates(List<Uint8List> templates);

  /// ZK SDK 1:N identification (broken on ZK9500 – use [identifyByDartafis]).
  Future<FingerprintMatchResult?> identifyFingerprint({int threshold = 40});

  /// Capture a raw 300×375 grayscale image from the scanner.
  Future<Uint8List?> captureRawImage();

  /// Identify a live fingerprint against a list of pre-enrolled,
  /// serialised dartafis templates.
  ///
  /// [candidateTemplates] must be a list of byte strings previously produced
  /// by [DartafisService.serializeTemplate] (or equivalently, stored in the
  /// `fingerprint_data` database column).
  ///
  /// The returned [FingerprintMatchResult.templateIndex] is an index into
  /// [candidateTemplates], allowing the caller to map back to the matching
  /// user record.
  Future<FingerprintMatchResult?> identifyByDartafis({
    required List<Uint8List> candidateTemplates,
    double scoreThreshold = 30.0,
  });

  /// Release scanner resources.
  Future<void> disconnect();
}
