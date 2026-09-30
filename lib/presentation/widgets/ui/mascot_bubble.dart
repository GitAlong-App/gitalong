import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'illustration.dart';

/// Octo next to a speech bubble (tile style, tail pointing at Octo). Octo
/// bounces in and the text types on quickly (≤ 600 ms). Under reduced motion
/// everything appears at once. Screen readers get the full message.
///
/// ```dart
/// MascotBubble(message: "Hi! I'm Octo. Let's find your people.")
/// ```
class MascotBubble extends StatefulWidget {
  const MascotBubble({
    super.key,
    required this.message,
    this.mascotSize = 80,
    this.typeOn = true,
    this.mascot = Illustrations.octopus,
  });

  final String message;

  /// 72–96 px per spec.
  final double mascotSize;

  /// Reveal the message character by character.
  final bool typeOn;

  /// Illustration name of the speaker.
  final String mascot;

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _typing = AnimationController(vsync: this, duration: _durationFor(''));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppTokens.reduceMotion(context);
    if (!_started) {
      _started = true;
      _startTyping();
    } else if (_reduceMotion) {
      _typing.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant MascotBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.typeOn != widget.typeOn) {
      _startTyping();
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  static Duration _durationFor(String message) {
    final ms = math.min(
      math.max(message.length * 18, 150),
      AppTokens.typeOnMax.inMilliseconds,
    );
    return Duration(milliseconds: ms);
  }

  void _startTyping() {
    if (!widget.typeOn || _reduceMotion) {
      _typing.value = 1;
      return;
    }
    _typing.duration = _durationFor(widget.message);
    _typing.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = AppTextStyles.body(p.ink);

    Widget mascot = Illustration(widget.mascot, size: widget.mascotSize);
    if (!_reduceMotion) {
      mascot = mascot
          .animate()
          .fadeIn(duration: AppTokens.fast)
          .scaleXY(
            begin: 0.6,
            end: 1,
            duration: const Duration(milliseconds: 800),
            curve: AppTokens.elasticCurve,
          );
    }

    Widget bubble = CustomPaint(
      painter: _BubblePainter(
        fill: p.card,
        border: p.border,
        edge: p.borderStrong,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _BubblePainter.tailWidth + 14,
          12,
          16,
          12 + _BubblePainter.edgeHeight,
        ),
        child: AnimatedBuilder(
          animation: _typing,
          builder: (context, _) {
            final text = widget.message;
            final visible = (text.length * _typing.value).round();
            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text.substring(0, visible)),
                  // The rest is laid out invisibly so the bubble never
                  // changes size while typing.
                  TextSpan(
                    text: text.substring(visible),
                    style: const TextStyle(color: Colors.transparent),
                  ),
                ],
              ),
              style: style,
            );
          },
        ),
      ),
    );
    if (!_reduceMotion) {
      bubble = bubble
          .animate()
          .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
          .moveX(begin: -8, end: 0, duration: AppTokens.medium);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mascot,
        const SizedBox(width: 4),
        Expanded(child: bubble),
      ],
    );
  }
}

/// A rounded bubble with a tail on its left edge and a 3 px bottom edge.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.fill, required this.border, required this.edge});

  static const double tailWidth = 12;
  static const double edgeHeight = 3;
  static const double _radius = 18;
  static const double _tailHalf = 9;

  final Color fill;
  final Color border;
  final Color edge;

  Path _bubble(Size size) {
    const left = tailWidth;
    final right = size.width;
    const top = 0.0;
    final bottom = size.height - edgeHeight;
    final r = math.min(_radius, (bottom - top) / 2);

    // Tail centred on the first line of text, clamped to the straight edge.
    final minY = top + r;
    final maxY = bottom - r;
    final half = math.max(0.0, math.min(_tailHalf, (maxY - minY) / 2));
    final tailY = (minY + half <= maxY - half)
        ? (28.0).clamp(minY + half, maxY - half).toDouble()
        : (minY + maxY) / 2;

    return Path()
      ..moveTo(left + r, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
      ..lineTo(left, tailY + half)
      ..lineTo(0, tailY)
      ..lineTo(left, tailY - half)
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= tailWidth || size.height <= edgeHeight) return;
    final path = _bubble(size);
    final paint = Paint()..isAntiAlias = true;

    canvas.drawPath(
      path.shift(const Offset(0, edgeHeight)),
      paint..color = edge,
    );
    canvas.drawPath(path, paint..color = fill);
    canvas.drawPath(
      path,
      paint
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.border != border ||
      oldDelegate.edge != edge;
}
