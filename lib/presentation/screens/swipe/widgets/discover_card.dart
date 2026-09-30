import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/constants/collab_constants.dart';
import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/user_entity.dart';
import '../../../widgets/ui/ui.dart';
import 'candidate_avatar.dart';

/// Compact counts for stats: 950, 1.2k, 12k, 3.4M.
String compactCount(int n) {
  if (n < 1000) return '$n';
  String trim(String text) =>
      text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  if (n < 1000000) {
    final k = n / 1000;
    return '${trim(k < 10 ? k.toStringAsFixed(1) : k.toStringAsFixed(0))}k';
  }
  return '${trim((n / 1000000).toStringAsFixed(1))}M';
}

/// The Discover card: a hero (avatar inside the match-% ring, name, handle,
/// location), the pitch in a speech bubble, intent chips, "why you matched"
/// rows, language chips and GitHub stats.
///
/// The card never scrolls (it would fight the swipe): details that don't
/// fit are clipped under a soft fade, and the stats stay pinned at the
/// bottom (dropped on very short cards). Screen readers get
/// [DiscoverCard.describe] instead of the individual pieces.
class DiscoverCard extends StatelessWidget {
  const DiscoverCard({
    super.key,
    required this.user,
    this.viewerIntents = const [],
  });

  final UserEntity user;

  /// The signed-in user's `looking_for`; intents that pair with it (same
  /// intent, or mentor ↔ mentee) are highlighted.
  final List<String> viewerIntents;

  /// Below this height the stats row is dropped so the essentials fit.
  static const double _statsMinHeight = 240;

  /// Below this height the hero shrinks (smaller ring, H3 name).
  static const double _compactBelow = 380;

  /// Diameter of the match ring around the avatar.
  static const double _ring = 92;
  static const double _compactRing = 76;

  /// The name to show: the user's name, or their username.
  static String displayNameOf(UserEntity user) {
    final name = user.name?.trim() ?? '';
    return name.isNotEmpty ? name : user.username;
  }

  /// The whole card as one sentence-per-part description for screen readers.
  static String describe(UserEntity user) {
    final parts = <String>[displayNameOf(user), '@${user.username}'];
    final score = user.matchScore;
    if (score != null) parts.add('${percentOf(score)}% match');
    final location = user.location?.trim() ?? '';
    if (location.isNotEmpty) parts.add(location);
    final pitch = user.pitch?.trim() ?? '';
    final bio = user.bio?.trim() ?? '';
    if (pitch.isNotEmpty) {
      parts.add('Building: $pitch');
    } else if (bio.isNotEmpty) {
      parts.add(bio);
    }
    final intents = intentsOf(user);
    if (intents.isNotEmpty) {
      parts.add('Looking for: ${intents.map((i) => i.label).join(', ')}');
    }
    final reasons = reasonsOf(user);
    if (reasons.isNotEmpty) {
      parts.add('Why you matched: ${reasons.join('. ')}');
    }
    final languages = languagesOf(user);
    if (languages.isNotEmpty) {
      parts.add('Languages: ${languages.join(', ')}');
    }
    parts.add(
      '${user.publicRepos} repositories, ${user.totalStars} stars, '
      '${user.followers} followers',
    );
    return parts.join('. ');
  }

  /// A 0–100 match score as a whole percentage.
  static int percentOf(double score) => score.clamp(0, 100).round();

  /// Known collaboration intents, in the user's order.
  static List<CollabIntent> intentsOf(UserEntity user) => user.lookingFor
      .map(CollabConstants.intentFor)
      .whereType<CollabIntent>()
      .toList();

  /// Up to three non-empty "why you matched" reasons.
  static List<String> reasonsOf(UserEntity user) => user.matchReasons
      .map((reason) => reason.trim())
      .where((reason) => reason.isNotEmpty)
      .take(3)
      .toList();

  /// Up to five languages.
  static List<String> languagesOf(UserEntity user) => user.languages
      .map((language) => language.trim())
      .where((language) => language.isNotEmpty)
      .take(5)
      .toList();

  @override
  Widget build(BuildContext context) {
    return GaTile(
      // Only the 2 px border: the sections pad themselves.
      padding: const EdgeInsets.all(AppTokens.borderWidth),
      radius: AppTokens.radiusXl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < _compactBelow;
          final ring = compact ? _compactRing : _ring;
          final showStats = constraints.maxHeight >= _statsMinHeight;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHero(user: user, ring: ring, compact: compact),
              Expanded(
                child: _CardDetails(
                  user: user,
                  viewerIntents: viewerIntents,
                  // Hero and details share the 14 px inset, so the ring's
                  // centre is half its size in from the bubble's edge.
                  tailX: ring / 2,
                ),
              ),
              if (showStats) _CardStats(user: user),
            ],
          );
        },
      ),
    );
  }
}

/// Avatar (in the match ring), name, @username and location or company.
class _CardHero extends StatelessWidget {
  const _CardHero({
    required this.user,
    required this.ring,
    required this.compact,
  });

  final UserEntity user;

  /// Diameter of the match ring.
  final double ring;

  /// Short card: tighter padding and an H3 name.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = DiscoverCard.displayNameOf(user);
    final location = user.location?.trim() ?? '';
    final company = user.company?.trim() ?? '';
    final place = location.isNotEmpty ? location : company;
    final IconData placeIcon = location.isNotEmpty
        ? PhosphorIconsFill.mapPin
        : PhosphorIconsFill.briefcase;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 10.0 : 14.0,
        14,
        compact ? 8.0 : 12.0,
      ),
      child: Row(
        children: [
          _HeroAvatar(user: user, name: name, ring: ring),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: compact ? AppTextStyles.h3(p.ink) : AppTextStyles.h2(p.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: AppTextStyles.bodySm(p.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space4),
                  Row(
                    children: [
                      Icon(placeIcon, size: 16, color: p.inkMuted),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Text(
                          place,
                          style: AppTextStyles.bodySm(p.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar inside a ring that fills up to the match score, with a
/// "87% MATCH" pill on the ring. Without a score: a plain framed avatar.
class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.user,
    required this.name,
    required this.ring,
  });

  final UserEntity user;
  final String name;

  /// Outer diameter of the ring (or frame).
  final double ring;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final score = user.matchScore;

    if (score == null) {
      return Container(
        width: ring,
        height: ring,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.border, width: AppTokens.borderWidth),
        ),
        // Inside 6 px padding + 2 px border on each side.
        child: CandidateAvatar(
          name: name,
          imageUrl: user.avatarUrl,
          size: ring - 16,
        ),
      );
    }

    final percent = DiscoverCard.percentOf(score);
    return SizedBox(
      width: ring,
      height: ring + 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ProgressRing(
            value: percent / 100,
            size: ring,
            semanticLabel: 'Match',
            semanticValue: '$percent%',
            // The ring insets its child by stroke + 4 on each side.
            child: CandidateAvatar(
              name: name,
              imageUrl: user.avatarUrl,
              size: ring - 20,
            ),
          ),
          Positioned(
            bottom: 0,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  // White on green-edge keeps small text above 4.5:1.
                  color: AppColors.greenEdge,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  border: Border.all(
                    color: p.card,
                    width: AppTokens.borderWidth,
                  ),
                ),
                child: Text(
                  '$percent% MATCH',
                  maxLines: 1,
                  softWrap: false,
                  style: AppTextStyles.caption(Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pitch (or bio), intents, reasons and languages, clipped under a fade.
class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.user,
    required this.viewerIntents,
    required this.tailX,
  });

  final UserEntity user;
  final List<String> viewerIntents;

  /// Where the pitch bubble's tail points (px from its left edge).
  final double tailX;

  /// Intents that pair with a different one (everything else pairs with
  /// itself) — docs/API_AND_DATA_CONTRACT.md §1.
  static const Map<String, String> _partnerIntent = {
    'mentor': 'mentee',
    'mentee': 'mentor',
  };

  static String? _artFor(String intentKey) => switch (intentKey) {
        'cofounder' => Illustrations.rocket,
        'side_project' => Illustrations.hammerAndWrench,
        'open_source' => Illustrations.globe,
        'hackathon' => Illustrations.highVoltage,
        'mentor' => Illustrations.graduationCap,
        'mentee' => Illustrations.seedling,
        _ => null,
      };

  bool _pairsWithViewer(String intentKey) =>
      viewerIntents.contains(_partnerIntent[intentKey] ?? intentKey);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pitch = user.pitch?.trim() ?? '';
    final bio = user.bio?.trim() ?? '';
    final intents = DiscoverCard.intentsOf(user);
    final reasons = DiscoverCard.reasonsOf(user);
    final languages = DiscoverCard.languagesOf(user);

    final sections = <Widget>[
      if (pitch.isNotEmpty)
        _PitchBubble(text: pitch, tailX: tailX)
      else if (bio.isNotEmpty)
        Text(
          bio,
          style: AppTextStyles.body(p.inkMuted),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      if (intents.isNotEmpty)
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: [
            for (final intent in intents)
              GaChip(
                label: intent.label,
                illustration: _artFor(intent.key),
                selected: _pairsWithViewer(intent.key),
              ),
          ],
        ),
      if (reasons.isNotEmpty) _WhyYouMatched(reasons: reasons),
      if (languages.isNotEmpty)
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: [
            for (final language in languages)
              GaChip(
                label: language,
                icon: PhosphorIconsBold.code,
                uppercase: false,
              ),
          ],
        ),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppTokens.space12),
                  sections[i],
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 28,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.card.withValues(alpha: 0), p.card],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pitch in a speech bubble whose tail points up at the avatar.
class _PitchBubble extends StatelessWidget {
  const _PitchBubble({required this.text, required this.tailX});

  final String text;

  /// Tail position, px from the bubble's left edge.
  final double tailX;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: _BubblePainter(
        fill: p.surface,
        border: p.border,
        tailX: tailX,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          10 + _BubblePainter.tailHeight,
          14,
          12,
        ),
        child: Text(
          text,
          style: AppTextStyles.body(p.ink),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.fill,
    required this.border,
    required this.tailX,
  });

  final Color fill;
  final Color border;

  /// Tail position, px from the left edge.
  final double tailX;

  static const double tailHeight = 10;
  static const double _tailHalfWidth = 9;
  static const double _radius = AppTokens.radiusMd;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AppTokens.borderWidth / 2;
    const left = inset;
    const top = tailHeight + inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final r = math.max(0.0, math.min(_radius, (bottom - top) / 2));
    final radius = Radius.circular(r);
    // Keep the tail on the straight part of the top edge.
    final tipX = math.max(
      left + r + _tailHalfWidth,
      math.min(tailX, right - r - _tailHalfWidth),
    );

    final path = Path()
      ..moveTo(left + r, top)
      ..lineTo(tipX - _tailHalfWidth, top)
      ..lineTo(tipX, inset)
      ..lineTo(tipX + _tailHalfWidth, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: radius)
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: radius)
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: radius)
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: radius)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color = fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTokens.borderWidth
        ..strokeJoin = StrokeJoin.round
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.border != border ||
      oldDelegate.tailX != tailX;
}

/// "Why you matched" caption and ✓ rows.
class _WhyYouMatched extends StatelessWidget {
  const _WhyYouMatched({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final check = p.toneText(AppTone.green);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Illustration(Illustrations.lightBulb, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'WHY YOU MATCHED',
                style: AppTextStyles.caption(p.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final reason in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    PhosphorIconsFill.checkCircle,
                    size: 18,
                    color: check,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                Expanded(
                  child: Text(
                    reason,
                    style: AppTextStyles.bodySm(p.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Repos, stars and followers, pinned to the bottom of the card.
class _CardStats extends StatelessWidget {
  const _CardStats({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.border, width: AppTokens.borderWidth),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                icon: PhosphorIconsFill.folderSimple,
                color: p.toneText(AppTone.sky),
                value: user.publicRepos,
                label: 'Repos',
              ),
            ),
            Expanded(
              child: _Stat(
                icon: PhosphorIconsFill.star,
                color: AppColors.gold,
                value: user.totalStars,
                label: 'Stars',
              ),
            ),
            Expanded(
              child: _Stat(
                icon: PhosphorIconsFill.users,
                color: p.toneText(AppTone.purple),
                value: user.followers,
                label: 'Followers',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                compactCount(value),
                style: AppTextStyles.h3(p.ink).copyWith(height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label.toUpperCase(),
                style: AppTextStyles.caption(p.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
