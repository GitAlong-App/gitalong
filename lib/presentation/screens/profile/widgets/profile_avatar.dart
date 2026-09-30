import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// Round avatar with a friendly illustrated fallback while loading, on error
/// or when the user has no photo. Decorative: the name next to it is the
/// accessible label.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.url, this.size = 96});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      color: palette.greenTint,
      alignment: Alignment.center,
      child: Illustration(Illustrations.technologist, size: size * 0.56),
    );
    final imageUrl = url?.trim() ?? '';

    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  // Cross-fades are fine under reduced motion (spec §4).
                  fadeInDuration: AppTokens.medium,
                  fadeOutDuration: AppTokens.fast,
                  placeholder: (_, url) => fallback,
                  errorWidget: (_, url, error) => fallback,
                ),
        ),
      ),
    );
  }
}
