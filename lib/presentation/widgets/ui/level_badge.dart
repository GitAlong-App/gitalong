import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'src/depth_surface.dart';

/// A purple circle with the level number in white 900, on a small 3D edge.
///
/// ```dart
/// LevelBadge(level: p.level)
/// ```
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 32});

  final int level;

  /// Overall size (the circle plus its edge).
  final double size;

  @override
  Widget build(BuildContext context) {
    final edge = size >= 28 ? 3.0 : 2.0;
    final diameter = size - edge;

    return Semantics(
      label: 'Level $level',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: DepthSurface(
            circle: true,
            color: AppColors.purple,
            edgeColor: AppColors.purpleEdge,
            edge: edge,
            child: SizedBox.square(
              dimension: diameter,
              child: Padding(
                padding: EdgeInsets.all(diameter * 0.18),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$level',
                    style: AppTextStyles.h3(Colors.white).copyWith(
                      fontSize: diameter * 0.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
