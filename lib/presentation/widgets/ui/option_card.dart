import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'illustration.dart';
import 'src/depth_surface.dart';
import 'src/pressable.dart';

/// How an [OptionCard] behaves for assistive technology and visually.
enum OptionSelectionMode {
  /// A checkbox: one of several that can be selected together.
  multiple,

  /// A radio button: exactly one in the group is selected.
  single,

  /// An action card (e.g. an icebreaker): no check badge, reads as a button.
  none,
}

/// A selectable tile with an illustration, a title and an optional subtitle.
///
/// Selected: green border, green-tint fill, green-edge bottom edge, a check
/// badge top-right and a small bounce (1 → 1.03 → 1). Medium haptic on tap.
///
/// ```dart
/// OptionCard(
///   title: 'Co-founder',
///   subtitle: 'Build a company together',
///   illustration: Illustrations.rocket,
///   selected: selected.contains('cofounder'),
///   onTap: () => toggle('cofounder'),
/// )
/// ```
class OptionCard extends StatefulWidget {
  const OptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.illustration,
    this.leading,
    this.selected = false,
    required this.onTap,
    this.selectionMode = OptionSelectionMode.multiple,
    this.illustrationSize = 44,
  });

  final String title;
  final String? subtitle;

  /// Illustration name shown on the left.
  final String? illustration;

  /// Custom leading widget; takes precedence over [illustration].
  final Widget? leading;

  final bool selected;

  /// Null disables the card.
  final VoidCallback? onTap;

  final OptionSelectionMode selectionMode;

  /// 40–48 px per spec.
  final double illustrationSize;

  @override
  State<OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<OptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;
  bool _reduceMotion = false;

  bool get _isSelected =>
      widget.selected && widget.selectionMode != OptionSelectionMode.none;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1)
            .chain(CurveTween(curve: AppTokens.bounceCurve)),
        weight: 60,
      ),
    ]).animate(_bounce);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppTokens.reduceMotion(context);
  }

  @override
  void didUpdateWidget(covariant OptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasSelected =
        oldWidget.selected && oldWidget.selectionMode != OptionSelectionMode.none;
    if (_isSelected && !wasSelected && !_reduceMotion) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selected = _isSelected;
    final mode = widget.selectionMode;
    final reduced = _reduceMotion;

    final fill = selected ? p.greenTint : p.card;
    final border = selected ? AppColors.green : p.border;
    final edge = selected ? AppColors.greenEdge : p.borderStrong;

    final art = widget.illustration;
    final leading = widget.leading ??
        (art == null ? null : Illustration(art, size: widget.illustrationSize));
    final subtitle = widget.subtitle;
    final showBadgeSpace = mode != OptionSelectionMode.none;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: AppTextStyles.h3(p.ink)),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodySm(p.inkMuted)),
        ],
      ],
    );

    Widget badge = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
        border: Border.all(color: p.card, width: 2),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
    );
    if (!reduced) {
      badge = badge.animate().scaleXY(
            begin: 0.4,
            end: 1,
            duration: AppTokens.fast,
            curve: AppTokens.bounceCurve,
          );
    }

    Widget card(double pressed, bool focused) {
      return DepthSurface(
        color: fill,
        edgeColor: edge,
        borderColor: border,
        edge: AppTokens.tileEdge,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        pressed: pressed,
        focused: focused,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                showBadgeSpace ? 40 : 16,
                14,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading,
                    const SizedBox(width: 14),
                  ],
                  Expanded(child: text),
                ],
              ),
            ),
            if (selected) Positioned(top: 10, right: 10, child: badge),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: Pressable(
        onTap: widget.onTap,
        haptic: mode == OptionSelectionMode.none
            ? PressHaptic.light
            : PressHaptic.medium,
        semanticLabel: widget.title,
        semanticHint: subtitle,
        isButton: mode == OptionSelectionMode.none,
        checked: mode == OptionSelectionMode.none ? null : selected,
        inMutuallyExclusiveGroup:
            mode == OptionSelectionMode.single ? true : null,
        builder: (context, pressed, focused) => card(pressed, focused),
      ),
    );
  }
}
