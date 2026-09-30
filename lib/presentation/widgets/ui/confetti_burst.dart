import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A one-shot confetti burst in the brand colours: particles fly up and out
/// from the upper middle, then fall with gravity, spin and flutter, and fade
/// out at the end (1.8 s by default).
///
/// Fills its parent and ignores touches — place it in a `Stack` with
/// `Positioned.fill`. Renders nothing under reduced motion.
///
/// ```dart
/// Stack(children: [content, const Positioned.fill(child: ConfettiBurst())])
/// ```
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.particleCount = 80,
    this.duration = AppTokens.confettiDuration,
    this.onComplete,
  });

  final int particleCount;
  final Duration duration;

  /// Called once the burst is over (right away under reduced motion).
  final VoidCallback? onComplete;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Particle> _particles = const [];
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete?.call();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = AppTokens.reduceMotion(context);
    if (_reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete?.call();
      });
      return;
    }
    _particles = _Particle.burst(math.max(0, widget.particleCount));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion || _particles.isEmpty) return const SizedBox.expand();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            animation: _controller,
            seconds: widget.duration.inMilliseconds / 1000,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.originX,
    required this.originY,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.spin,
    required this.flutterSpeed,
    required this.flutterPhase,
    required this.size,
    required this.aspect,
    required this.circle,
    required this.color,
  });

  /// Start, as a fraction of the canvas.
  final double originX;
  final double originY;

  /// Initial velocity in "canvas short sides" per second.
  final double vx;
  final double vy;

  final double rotation;
  final double spin;
  final double flutterSpeed;
  final double flutterPhase;
  final double size;
  final double aspect;
  final bool circle;
  final Color color;

  static List<_Particle> burst(int count) {
    final random = math.Random();
    double between(double a, double b) => a + random.nextDouble() * (b - a);
    const colors = AppColors.confetti;

    return List<_Particle>.generate(count, (i) {
      // Mostly upward, fanning out to both sides.
      final angle = between(-math.pi * 0.92, -math.pi * 0.08);
      final speed = between(0.9, 1.9);
      return _Particle(
        originX: between(0.42, 0.58),
        originY: between(0.26, 0.34),
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        rotation: between(0, math.pi * 2),
        spin: between(-9, 9),
        flutterSpeed: between(6, 14),
        flutterPhase: between(0, math.pi * 2),
        size: between(6, 11),
        aspect: between(0.35, 0.7),
        circle: random.nextDouble() < 0.25,
        color: colors[i % colors.length],
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.animation,
    required this.seconds,
  }) : super(repaint: animation);

  final List<_Particle> particles;
  final Animation<double> animation;
  final double seconds;

  /// Linear air drag and gravity, in short sides per second (squared).
  static const double _drag = 1.3;
  static const double _gravity = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0 || progress >= 1) return;

    final t = progress * seconds;
    final unit = math.min(size.width, size.height);
    final decay = (1 - math.exp(-_drag * t)) / _drag;
    final opacity = progress < 0.72 ? 1.0 : (1 - (progress - 0.72) / 0.28);
    final paint = Paint()..isAntiAlias = true;

    for (final p in particles) {
      // Closed-form motion with linear drag: v' = -k·v + g.
      final dx = p.vx * decay;
      final dy = p.vy * decay +
          _gravity / _drag * (t - decay);
      final x = p.originX * size.width + dx * unit;
      final y = p.originY * size.height + dy * unit;
      if (y > size.height + 20) continue;

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);
      // Flutter: squash on one axis to fake a 3D flip.
      canvas.scale(1, math.cos(p.flutterPhase + p.flutterSpeed * t));
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * p.aspect,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.animation != animation;
}
