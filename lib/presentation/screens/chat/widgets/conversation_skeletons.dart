import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// Placeholder for one `ConversationTile` while the list loads.
class ConversationTileSkeleton extends StatelessWidget {
  const ConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GaTile(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GaSkeleton.circle(size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GaSkeleton(width: 140, height: 16),
                const SizedBox(height: 10),
                GaSkeleton(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A non-scrolling column of [ConversationTileSkeleton]s, announced once as
/// [semanticLabel].
class ConversationListSkeleton extends StatelessWidget {
  const ConversationListSkeleton({
    super.key,
    this.count = 6,
    this.semanticLabel = 'Loading conversations',
  });

  final int count;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            AppTokens.space16,
            AppTokens.gutter,
            AppTokens.space24,
          ),
          itemCount: count,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppTokens.space12),
          itemBuilder: (context, index) => const ConversationTileSkeleton(),
        ),
      ),
    );
  }
}
