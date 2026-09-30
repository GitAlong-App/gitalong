import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// A card-shaped shimmer placeholder while builders load: avatar, name,
/// pitch bubble, chips and a few lines, in the real card's layout.
class DiscoverCardSkeleton extends StatelessWidget {
  const DiscoverCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Finding builders for you',
      child: GaTile(
        radius: AppTokens.radiusXl,
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  GaSkeleton.circle(size: 88),
                  SizedBox(width: AppTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GaSkeleton(width: 150, height: 22),
                        SizedBox(height: 10),
                        GaSkeleton(width: 96, height: 14),
                        SizedBox(height: 8),
                        GaSkeleton(width: 120, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTokens.space20),
              GaSkeleton(height: 72, radius: AppTokens.radiusMd),
              SizedBox(height: AppTokens.space16),
              Row(
                children: [
                  GaSkeleton(width: 120, height: 36, radius: AppTokens.radiusPill),
                  SizedBox(width: AppTokens.space8),
                  GaSkeleton(width: 96, height: 36, radius: AppTokens.radiusPill),
                ],
              ),
              SizedBox(height: AppTokens.space20),
              GaSkeleton.lines(lines: 3),
            ],
          ),
        ),
      ),
    );
  }
}
