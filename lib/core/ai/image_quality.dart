import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why a photo was rejected before it ever reached the AI. Mirrors the server's
/// reject reasons so the two gates speak the same language.
enum ImageRejectReason { tooSmall, tooDark, tooBright, blurry, unreadable }

class ImageQuality {
  const ImageQuality._(this.ok, {this.reason, this.message, this.decoded});

  final bool ok;
  final ImageRejectReason? reason;
  final String? message;

  /// The decoded image, kept so a passing check can be resized without a second
  /// decode.
  final img.Image? decoded;

  const ImageQuality.pass(img.Image image)
      : this._(true, decoded: image);

  const ImageQuality.fail(ImageRejectReason reason, String message)
      : this._(false, reason: reason, message: message);
}

/// Cheap, on-device photo gate. Runs before any upload or AI call, so obviously
/// unusable photos (dark, tiny, badly out of focus) cost the farmer nothing.
///
/// Deliberately lenient — it only blocks the clearly-bad; the server's Gemini
/// pass makes the finer "multiple plants / not a plant" call.
class ImageQualityChecker {
  static const _minEdge = 400; // px on the shorter side
  static const _darkMean = 40; // 0-255 average luminance floor
  static const _brightMean = 245; // washed-out ceiling
  static const _blurThreshold = 90.0; // variance-of-Laplacian floor

  /// Analyse raw image [bytes]. Returns a pass (with the decoded image) or a
  /// fail carrying a farmer-friendly [message].
  static ImageQuality inspect(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return const ImageQuality.fail(
        ImageRejectReason.unreadable,
        "That file isn't a readable photo. Please take a new picture.",
      );
    }

    final shorter = image.width < image.height ? image.width : image.height;
    if (shorter < _minEdge) {
      return const ImageQuality.fail(
        ImageRejectReason.tooSmall,
        'The photo is too small or too far away. Move closer and retake.',
      );
    }

    // Downscale to a fixed working size — keeps luminance/blur maths fast and
    // resolution-independent.
    final work = img.copyResize(image, width: 256);
    final gray = img.grayscale(work);

    final mean = _meanLuminance(gray);
    if (mean < _darkMean) {
      return const ImageQuality.fail(
        ImageRejectReason.tooDark,
        'The photo is too dark. Retake it in better light.',
      );
    }
    if (mean > _brightMean) {
      return const ImageQuality.fail(
        ImageRejectReason.tooBright,
        'The photo is washed out by glare. Retake it out of direct sun.',
      );
    }

    if (_laplacianVariance(gray) < _blurThreshold) {
      return const ImageQuality.fail(
        ImageRejectReason.blurry,
        'The photo looks blurry. Hold steady and retake it.',
      );
    }

    return ImageQuality.pass(image);
  }

  static double _meanLuminance(img.Image gray) {
    var sum = 0.0;
    final n = gray.width * gray.height;
    for (final p in gray) {
      sum += p.r; // grayscale → r == g == b
    }
    return n == 0 ? 0 : sum / n;
  }

  /// Variance of a 3×3 Laplacian over the luminance channel — the standard
  /// cheap focus metric. Low variance ⇒ few sharp edges ⇒ blurry.
  static double _laplacianVariance(img.Image gray) {
    final w = gray.width, h = gray.height;
    final lum = List<double>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        lum[y * w + x] = gray.getPixel(x, y).r.toDouble();
      }
    }
    final resp = <double>[];
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final v = -4 * lum[i] +
            lum[i - 1] +
            lum[i + 1] +
            lum[i - w] +
            lum[i + w];
        resp.add(v);
      }
    }
    if (resp.isEmpty) return 0;
    final mean = resp.reduce((a, b) => a + b) / resp.length;
    var varSum = 0.0;
    for (final v in resp) {
      final d = v - mean;
      varSum += d * d;
    }
    return varSum / resp.length;
  }

  /// Resize + JPEG-encode a passing image for upload. Caps the long edge so a
  /// phone photo shrinks from megabytes to a few hundred KB before it crosses
  /// the network.
  static Uint8List compressForUpload(img.Image image, {int maxEdge = 1280}) {
    final longEdge = image.width > image.height ? image.width : image.height;
    final resized = longEdge > maxEdge
        ? img.copyResize(
            image,
            width: image.width >= image.height ? maxEdge : null,
            height: image.height > image.width ? maxEdge : null,
          )
        : image;
    return img.encodeJpg(resized, quality: 82);
  }
}
