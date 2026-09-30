import 'package:flutter/material.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';
import 'candidate_avatar.dart';

/// The match celebration's centrepiece: both avatars slide together and
/// tilt in, then a handshake pops up between them. Static under reduced
/// motion. Decorative: the celebration's title and message say who matched.
class MatchAvatars extends StatefulWidget {
  const MatchAvatars({
    super.key,
    required this.myName,
    required this.myAvatarUrl,
    required this.theirName,
    required this.theirAvatarUrl,
  });

  final String myName;
  final String? myAvatarUrl;
  final String theirName;
  final String? theirAvatarUrl;

  @override
  State<MatchAvatars> createState() => _MatchAvatarsState();
}

class _MatchAvatarsState extends State<MatchAvatars>
    with SingleTickerProviderStateMixin {
  static const double _avatar = 116;
  static const double _overlap = 30;
  static const double _badge = 60;
  static const double _width = _avatar * 2 - _overlap;
  static const double _height = _avatar + _badge / 2;

  /// How far apart the avatars start.
  static const double _spread = 40;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppTokens.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [t] mapped into the [begin]..[end] window, 0..1.
  static double _window(double t, double begin, double end) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return (t - begin) / (end - begin);
  }

  Widget _ringed(AppPalette p, AppTone tone, String name, String? url) {
    return Container(
      width: _avatar,
      height: _avatar,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: tone.fill, shape: BoxShape.circle),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
        child: CandidateAvatar(
          name: name,
          imageUrl: url,
          size: _avatar - 14,
          tone: tone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = _ringed(p, AppTone.green, widget.myName, widget.myAvatarUrl);
    final them =
        _ringed(p, AppTone.purple, widget.theirName, widget.theirAvatarUrl);
    final badge = Container(
      width: _badge,
      height: _badge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 3),
      ),
      child: const Illustration(Illustrations.handshake, size: 38),
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: _width,
        height: _height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final together = Curves.easeOutBack.transform(_window(t, 0, 0.65));
            final pop = Curves.elasticOut.transform(_window(t, 0.45, 1));
            final apart = _spread * (1 - together);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Transform.translate(
                    offset: Offset(-apart, 0),
                    child: Transform.rotate(angle: -0.1 * together, child: me),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Transform.translate(
                    offset: Offset(apart, 0),
                    child: Transform.rotate(angle: 0.1 * together, child: them),
                  ),
                ),
                Positioned(
                  left: (_width - _badge) / 2,
                  bottom: 0,
                  child: Transform.scale(scale: pop, child: badge),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
