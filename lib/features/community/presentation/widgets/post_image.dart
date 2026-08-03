import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A community post photo with proper loading, fade-in and error states.
///
/// A bare `Image.network` shows nothing while it downloads (so a freshly-posted
/// photo looks missing until the CDN responds) and, worse, hid failures behind
/// a zero-size box. This shows a spinner while loading and a visible
/// "Image unavailable" tile on failure, so an image is never silently blank.
class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.url, this.radius = 12});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final value = progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null;
          return _Placeholder(
            child: CircularProgressIndicator(strokeWidth: 2, value: value),
          );
        },
        errorBuilder: (_, __, ___) => _Placeholder(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.broken_image,
                  color: AppColors.onSurfaceVariant),
              const SizedBox(height: 4),
              Text('Image unavailable',
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      alignment: Alignment.center,
      color: AppColors.surfaceContainer,
      child: child,
    );
  }
}
