import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/feedback_service.dart';

/// Haptic played when a [Pressable] goes down.
enum PressHaptic { none, light, medium, selection }

/// Builds the visual for a press amount (0 resting → 1 pressed, may
/// overshoot a little on release) and the keyboard-focus state.
typedef PressableBuilder = Widget Function(
  BuildContext context,
  double pressed,
  bool focused,
);

/// Shared press behaviour for the kit's 3D controls: press-down and spring
/// back, haptics, keyboard activation (Enter/Space), a focus flag and a
/// single semantics node.
///
/// Disabled when [onTap] is null.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    required this.onTap,
    this.onLongPress,
    this.haptic = PressHaptic.light,
    this.semanticLabel,
    this.semanticHint,
    this.semanticValue,
    this.isButton = true,
    this.selected,
    this.checked,
    this.inMutuallyExclusiveGroup,
    this.customSemanticsActions,
    this.autofocus = false,
  });

  final PressableBuilder builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final PressHaptic haptic;

  /// When set, replaces the semantics of the content; otherwise the
  /// content's semantics are merged into one node.
  final String? semanticLabel;
  final String? semanticHint;
  final String? semanticValue;
  final bool isButton;
  final bool? selected;
  final bool? checked;
  final bool? inMutuallyExclusiveGroup;

  /// Secondary actions exposed to screen readers (e.g. "Remove" on a chip).
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _press;
  bool _down = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.pressDuration,
      reverseDuration: AppTokens.releaseDuration,
    )..addStatusListener(_onStatus);
    // easeInBack on the way up = a small spring past the resting position.
    _press = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeInBack,
    );
  }

  @override
  void didUpdateWidget(covariant Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && (_down || _controller.value != 0)) {
      _down = false;
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    // A quick tap releases before the press finished: finish it, then
    // spring back, so every tap is visible.
    if (status == AnimationStatus.completed && !_down) {
      _controller.reverse();
    }
  }

  void _handleDown() {
    if (!_enabled) return;
    _down = true;
    switch (widget.haptic) {
      case PressHaptic.none:
        break;
      case PressHaptic.light:
        FeedbackService.lightTap();
      case PressHaptic.medium:
        FeedbackService.mediumTap();
      case PressHaptic.selection:
        FeedbackService.selectionTick();
    }
    if (AppTokens.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _handleUp() {
    if (!_down) return;
    _down = false;
    if (AppTokens.reduceMotion(context)) {
      _controller.value = 0;
    } else if (_controller.status != AnimationStatus.forward) {
      _controller.reverse();
    }
  }

  void _handleTap() {
    if (!_enabled) return;
    widget.onTap?.call();
  }

  void _handleKeyboardActivate() {
    if (!_enabled) return;
    if (widget.haptic != PressHaptic.none) FeedbackService.selectionTick();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    final onLongPress = widget.onLongPress;
    if (!_enabled || onLongPress == null) return;
    FeedbackService.mediumTap();
    onLongPress();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final label = widget.semanticLabel;

    Widget content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: enabled ? (_) => _handleDown() : null,
      onTapUp: enabled ? (_) => _handleUp() : null,
      onTapCancel: enabled ? _handleUp : null,
      onTap: enabled ? _handleTap : null,
      onLongPress:
          enabled && widget.onLongPress != null ? _handleLongPress : null,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) =>
            widget.builder(context, enabled ? _press.value : 0, _focused),
      ),
    );

    content = FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus,
      includeFocusSemantics: false,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (value) {
        if (value != _focused) setState(() => _focused = value);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleKeyboardActivate();
            return null;
          },
        ),
      },
      child: content,
    );

    final node = Semantics(
      container: true,
      button: widget.isButton,
      enabled: enabled,
      focusable: enabled,
      focused: _focused,
      selected: widget.selected,
      checked: widget.checked,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: label,
      hint: widget.semanticHint,
      value: widget.semanticValue,
      excludeSemantics: label != null,
      onTap: enabled ? _handleTap : null,
      onLongPress:
          enabled && widget.onLongPress != null ? _handleLongPress : null,
      customSemanticsActions: enabled ? widget.customSemanticsActions : null,
      child: content,
    );

    return label != null ? node : MergeSemantics(child: node);
  }
}
