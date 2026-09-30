import 'package:flutter/material.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_palette.dart';

/// A 3D illustration from `assets/illustrations/` (see [Illustrations]).
///
/// Decorative by default (hidden from screen readers); pass [semanticLabel]
/// when the image carries meaning. Shows a soft placeholder if the asset is
/// missing instead of throwing.
///
/// ```dart
/// Illustration(Illustrations.handshake, size: 120)
/// ```
class Illustration extends StatelessWidget {
  const Illustration(
    this.name, {
    super.key,
    this.size = 48,
    this.semanticLabel,
    this.grayscale = false,
    this.opacity = 1,
    this.fit = BoxFit.contain,
  });

  /// Illustration name, e.g. [Illustrations.rocket].
  final String name;

  /// Width and height in logical pixels.
  final double size;

  /// Accessible description; null = decorative.
  final String? semanticLabel;

  /// Desaturate (locked achievements, inactive streak).
  final bool grayscale;

  /// 0..1.
  final double opacity;

  final BoxFit fit;

  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      Illustrations.path(name),
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) =>
          _IllustrationFallback(size: size),
    );

    if (grayscale) {
      image = ColorFiltered(colorFilter: _grayscaleFilter, child: image);
    }
    if (opacity < 1) {
      image = Opacity(opacity: opacity.clamp(0.0, 1.0).toDouble(), child: image);
    }

    final label = semanticLabel;
    if (label == null) return image;
    return Semantics(image: true, label: label, child: image);
  }
}

class _IllustrationFallback extends StatelessWidget {
  const _IllustrationFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(color: p.border, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.45,
        color: p.inkSubtle,
      ),
    );
  }
}
