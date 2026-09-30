import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';
import 'equal_height_row.dart';

/// Placeholder shaped like the profile while it loads.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your profile',
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            AppTokens.space16,
            AppTokens.gutter,
            AppTokens.space40,
          ),
          children: [
            Center(child: GaSkeleton.circle(size: 132)),
            const SizedBox(height: AppTokens.space16),
            Center(child: GaSkeleton(width: 180, height: 28, radius: 10)),
            const SizedBox(height: AppTokens.space8),
            Center(child: GaSkeleton(width: 110, height: 14)),
            const SizedBox(height: AppTokens.space12),
            Center(
              child: GaSkeleton(
                width: 170,
                height: 30,
                radius: AppTokens.radiusPill,
              ),
            ),
            const SizedBox(height: AppTokens.space32),
            GaSkeleton(width: 140, height: 22, radius: 8),
            const SizedBox(height: AppTokens.space12),
            const StatSkeletonRow(),
            const SizedBox(height: AppTokens.space12),
            const StatSkeletonRow(),
            const SizedBox(height: AppTokens.space24),
            GaSkeleton(height: 132, radius: AppTokens.radiusLg),
          ],
        ),
      ),
    );
  }
}

/// Two stat-tile placeholders side by side.
class StatSkeletonRow extends StatelessWidget {
  const StatSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return EqualHeightRow(
      spacing: AppTokens.space12,
      children: [
        GaSkeleton(height: 112, radius: AppTokens.radiusLg),
        GaSkeleton(height: 112, radius: AppTokens.radiusLg),
      ],
    );
  }
}
