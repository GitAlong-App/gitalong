import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'src/depth_surface.dart';
import 'src/pressable.dart';

/// A pill of mutually exclusive segments; the active one is a white tile
/// with a bottom edge that slides between segments. Each segment is a
/// 52 px touch target. Labels are shown UPPERCASE.
///
/// ```dart
/// GaSegmentedTabs(
///   labels: const ['New', 'All'],
///   selectedIndex: _tab,
///   onChanged: (i) => setState(() => _tab = i),
/// )
/// ```
class GaSegmentedTabs extends StatelessWidget {
  const GaSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const double _height = 52;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = labels.length;
    if (count == 0) return const SizedBox.shrink();
    final selected = selectedIndex.clamp(0, count - 1).toInt();
    final x = count == 1 ? 0.0 : -1 + 2 * selected / (count - 1);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: p.border, width: AppTokens.borderWidth),
      ),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(x, 0),
                duration: AppTokens.motion(context, AppTokens.medium),
                curve: AppTokens.curve,
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(_inset),
                    child: DepthSurface(
                      color: p.card,
                      edgeColor: p.borderStrong,
                      borderColor: p.border,
                      edge: AppTokens.tileEdge,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: Pressable(
                      onTap: i == selected ? () {} : () => onChanged(i),
                      haptic: PressHaptic.selection,
                      semanticLabel: labels[i],
                      selected: i == selected,
                      inMutuallyExclusiveGroup: true,
                      builder: (context, pressed, focused) => DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusPill),
                          border: focused
                              ? Border.all(
                                  color: AppColors.greenBright,
                                  width: AppTokens.focusRingWidth,
                                )
                              : null,
                        ),
                        child: SizedBox(
                          height: _height,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 8,
                                bottom: AppTokens.tileEdge,
                              ),
                              child: Text(
                                labels[i].toUpperCase(),
                                style: AppTextStyles.caption(
                                  i == selected ? p.ink : p.inkMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
