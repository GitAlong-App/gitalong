import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';

/// A round avatar: the GitHub picture when there is one, otherwise the
/// person's initials on a tinted circle (also shown while the picture loads
/// and if it fails).
class CandidateAvatar extends StatelessWidget {
  const CandidateAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.size,
    this.tone = AppTone.green,
  });

  /// Used for the initials fallback.
  final String name;

  final String? imageUrl;

  /// Diameter.
  final double size;

  /// Tint of the initials fallback.
  final AppTone tone;

  /// Up to two initials: "Ada Lovelace" → "AL", "octo-dev" → "OD".
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'[\s_.\-]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first.toUpperCase();
    if (words.length == 1) return first;
    return '$first${words.last.characters.first.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(color: p.tint(tone), shape: BoxShape.circle),
      child: Center(
        child: Text(
          initialsOf(name),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTextStyles.h2(p.toneText(tone)).copyWith(
            fontSize: size * 0.36,
            height: 1,
          ),
        ),
      ),
    );

    final url = imageUrl?.trim() ?? '';
    final Widget content = url.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth:
                (size * MediaQuery.devicePixelRatioOf(context)).round(),
            fadeInDuration: AppTokens.motion(context, AppTokens.fast),
            placeholder: (context, src) => fallback,
            errorWidget: (context, src, error) => fallback,
          );

    return SizedBox.square(
      dimension: size,
      child: ClipOval(child: content),
    );
  }
}
