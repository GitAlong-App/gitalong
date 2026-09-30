import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';

/// A round profile picture with an initials fallback (while loading, on
/// error, or without a URL).
///
/// Decorative: the tile, button or app bar around it carries the semantics.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
  });

  /// Used for the initials fallback.
  final String name;
  final String? imageUrl;

  /// Diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = _InitialsAvatar(name: name, size: size);
    final url = imageUrl?.trim() ?? '';

    Widget avatar = fallback;
    if (url.isNotEmpty) {
      final decodeWidth =
          (size * MediaQuery.devicePixelRatioOf(context)).round();
      avatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: decodeWidth,
          fadeInDuration: AppTokens.motion(context, AppTokens.fast),
          fadeOutDuration: AppTokens.motion(context, AppTokens.fast),
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(width: size, height: size, child: avatar),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.greenTint,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(name),
        maxLines: 1,
        // The circle has a fixed size, so the initials must not grow with
        // the text scale.
        textScaler: TextScaler.noScaling,
        style: AppTextStyles.h3(palette.toneText(AppTone.green)).copyWith(
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );
  }
}

/// Up to two initials, e.g. "Ada Lovelace" → "AL", "octocat" → "O".
String _initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String firstLetter(String part) => String.fromCharCode(part.runes.first);
  final initials = parts.length == 1
      ? firstLetter(parts.first)
      : '${firstLetter(parts.first)}${firstLetter(parts.last)}';
  return initials.toUpperCase();
}
