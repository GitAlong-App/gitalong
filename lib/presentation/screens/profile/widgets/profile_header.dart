import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/user_entity.dart';
import '../../../widgets/ui/ui.dart';
import 'external_link.dart';
import 'profile_avatar.dart';

/// Avatar inside a profile-strength ring (with the level badge when progress
/// is available), name, @username, strength pill, bio and details.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.strengthDone,
    required this.strengthTotal,
    this.level,
  });

  final UserEntity user;
  final int strengthDone;
  final int strengthTotal;

  /// Current level, or null to hide the badge (progress unavailable).
  final int? level;

  static const double _ringSize = 132;
  static const double _ringStroke = 6;
  static const double _ringGap = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = user.name?.trim() ?? '';
    final displayName = name.isEmpty ? user.username : name;
    final strength = strengthTotal == 0
        ? 0.0
        : (strengthDone / strengthTotal).clamp(0.0, 1.0).toDouble();
    final percent = (strength * 100).round();
    final complete = strengthTotal > 0 && strengthDone >= strengthTotal;
    final bio = user.bio?.trim() ?? '';
    final location = user.location?.trim() ?? '';
    final company = user.company?.trim() ?? '';
    final website = safeWebUri(user.websiteUrl);
    final level = this.level;
    final hasGitHub = user.githubUrl?.trim().isNotEmpty ?? false;

    return Column(
      children: [
        SizedBox(
          width: _ringSize,
          height: _ringSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ProgressRing(
                value: strength,
                size: _ringSize,
                strokeWidth: _ringStroke,
                animateOnMount: true,
                semanticLabel: 'Profile strength',
                semanticValue: '$percent percent',
                child: ProfileAvatar(
                  url: user.avatarUrl,
                  size: _ringSize - 2 * (_ringStroke + _ringGap),
                ),
              ),
              if (level != null)
                PositionedDirectional(
                  end: 0,
                  bottom: 2,
                  child: LevelBadge(level: level, size: 38),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        Text(
          displayName,
          style: AppTextStyles.h1(palette.ink),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppTokens.space4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasGitHub) ...[
              Icon(
                PhosphorIconsBold.githubLogo,
                size: 16,
                color: palette.inkMuted,
              ),
              const SizedBox(width: AppTokens.space4),
            ],
            Flexible(
              child: Text(
                '@${user.username}',
                style: AppTextStyles.bodySm(palette.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space12),
        _StrengthPill(percent: percent, complete: complete),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space12),
          Text(
            bio,
            style: AppTextStyles.body(palette.inkMuted),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (location.isNotEmpty || company.isNotEmpty || website != null) ...[
          const SizedBox(height: AppTokens.space8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTokens.space16,
            children: [
              if (location.isNotEmpty)
                _MetaItem(icon: PhosphorIconsBold.mapPin, text: location),
              if (company.isNotEmpty)
                _MetaItem(icon: PhosphorIconsBold.buildings, text: company),
              if (website != null) _WebsiteLink(uri: website),
            ],
          ),
        ],
      ],
    );
  }
}

class _StrengthPill extends StatelessWidget {
  const _StrengthPill({required this.percent, required this.complete});

  final int percent;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = complete ? palette.toneText(AppTone.green) : palette.inkMuted;

    // The ring above already announces the strength to screen readers.
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: complete ? palette.greenTint : palette.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: complete ? AppColors.green : palette.border,
            width: AppTokens.borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              complete
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsBold.circleDashed,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                complete ? 'PROFILE COMPLETE' : 'PROFILE $percent% COMPLETE',
                style: AppTextStyles.caption(color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.inkMuted),
          const SizedBox(width: AppTokens.space4),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodySm(palette.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteLink extends StatelessWidget {
  const _WebsiteLink({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette.toneText(AppTone.sky);
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;

    return MergeSemantics(
      child: Semantics(
        link: true,
        hint: 'Opens in your browser',
        child: InkWell(
          onTap: () => openExternalLink(context, uri.toString()),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTokens.space4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsBold.link, size: 16, color: color),
                  const SizedBox(width: AppTokens.space4),
                  Flexible(
                    child: Text(
                      host,
                      style: AppTextStyles.bodySm(color).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
