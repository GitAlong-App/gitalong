import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import 'ga_tile.dart';
import 'illustration.dart';

/// The toast tile: an illustration in a tinted circle, an optional
/// UPPERCASE [eyebrow], a title and a message. Shown by [showGaToast].
class GaToast extends StatelessWidget {
  const GaToast({
    super.key,
    required this.title,
    this.message,
    this.illustration = Illustrations.sparkles,
    this.eyebrow,
    this.tone = AppTone.green,
    this.onTap,
  });

  final String title;
  final String? message;
  final String illustration;

  /// Small caption above the title, e.g. "Achievement unlocked".
  final String? eyebrow;

  final AppTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final kicker = eyebrow;
    final note = message;
    final parts = [
      if (kicker != null) kicker,
      title,
      if (note != null) note,
    ];

    return GaTile(
      onTap: onTap,
      haptics: false,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      semanticLabel: parts.join('. '),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.tint(tone),
              shape: BoxShape.circle,
              border: Border.all(color: tone.fill, width: AppTokens.borderWidth),
            ),
            alignment: Alignment.center,
            child: Illustration(illustration, size: 36),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kicker != null)
                  Text(
                    kicker.toUpperCase(),
                    style: AppTextStyles.caption(p.toneText(tone)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  title,
                  style: AppTextStyles.h3(p.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: AppTextStyles.bodySm(p.inkMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slides a [GaToast] down from the top (with a bounce), holds it for 3 s
/// and slides it back up. Toasts are queued and shown one at a time; tap or
/// swipe up to dismiss early. Completes when this toast is gone.
///
/// ```dart
/// showGaToast(
///   context,
///   title: 'Daily goal reached!',
///   message: '10 builders reviewed today',
///   illustration: Illustrations.trophy,
///   tone: AppTone.gold,
/// );
/// ```
Future<void> showGaToast(
  BuildContext context, {
  required String title,
  String? message,
  String illustration = Illustrations.sparkles,
  String? eyebrow,
  AppTone tone = AppTone.green,
}) {
  return enqueueToast(
    context,
    haptic: FeedbackService.lightTap,
    builder: (dismiss) => GaToast(
      title: title,
      message: message,
      illustration: illustration,
      eyebrow: eyebrow,
      tone: tone,
      onTap: dismiss,
    ),
  );
}

/// Queues any toast tile built by [builder] (which receives a dismiss
/// callback) in the root overlay. Used by [showGaToast] and
/// `showAchievementToast`.
Future<void> enqueueToast(
  BuildContext context, {
  required Widget Function(VoidCallback dismiss) builder,
  VoidCallback? haptic,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future<void>.value();
  final request = _ToastRequest(overlay, builder, haptic);
  _ToastQueue.requests.add(request);
  _ToastQueue.pump();
  return request.done.future;
}

class _ToastRequest {
  _ToastRequest(this.overlay, this.builder, this.haptic);

  final OverlayState overlay;
  final Widget Function(VoidCallback dismiss) builder;
  final VoidCallback? haptic;
  final Completer<void> done = Completer<void>();
}

/// One toast at a time, in order.
class _ToastQueue {
  _ToastQueue._();

  static final List<_ToastRequest> requests = [];
  static bool _showing = false;

  static void pump() {
    if (_showing || requests.isEmpty) return;
    final request = requests.removeAt(0);
    if (!request.overlay.mounted) {
      request.done.complete();
      pump();
      return;
    }

    _showing = true;
    late final OverlayEntry entry;
    var finished = false;

    void finish() {
      if (finished) return;
      finished = true;
      entry.remove();
      entry.dispose();
      _showing = false;
      if (!request.done.isCompleted) request.done.complete();
      pump();
    }

    entry = OverlayEntry(
      builder: (context) => _ToastHost(builder: request.builder, onDone: finish),
    );
    request.overlay.insert(entry);
    request.haptic?.call();
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({required this.builder, required this.onDone});

  final Widget Function(VoidCallback dismiss) builder;

  /// Called exactly once when the toast has left (or its overlay went away).
  final VoidCallback onDone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  static const Duration _enter = Duration(milliseconds: 450);
  static const Duration _exit = Duration(milliseconds: 250);

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Timer? _hold;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _enter,
      reverseDuration: _exit,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: AppTokens.bounceCurve,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
    _hold = Timer(_enter + AppTokens.toastHold, _dismiss);
  }

  void _dismiss() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _hold?.cancel();
    _controller.reverse().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _curve.dispose();
    _controller.dispose();
    // Safe to call again: the queue ignores repeats.
    widget.onDone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppTokens.reduceMotion(context);
    final top = MediaQuery.paddingOf(context).top + AppTokens.space8;

    final toast = Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -100) _dismiss();
          },
          child: widget.builder(_dismiss),
        ),
      ),
    );

    return Positioned(
      top: top,
      left: AppTokens.space16,
      right: AppTokens.space16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              final opacity = _controller.value.clamp(0.0, 1.0).toDouble();
              if (reduced) return Opacity(opacity: opacity, child: child);
              return Transform.translate(
                offset: Offset(0, -(top + 96) * (1 - _curve.value)),
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: toast,
          ),
        ),
      ),
    );
  }
}
