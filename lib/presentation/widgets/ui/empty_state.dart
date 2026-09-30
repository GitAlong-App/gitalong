import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'illustration.dart';
import 'pressable_button.dart';

/// A friendly empty or waiting state: 120 px illustration, H2 title, body
/// text and an optional primary button. Never shame the user ("No one yet,
/// want to widen your filters?", not "No results").
///
/// ```dart
/// EmptyState(
///   illustration: Illustrations.thinkingFace,
///   title: 'No one yet',
///   message: 'Want to widen your filters?',
///   actionLabel: 'Refresh',
///   onAction: _reload,
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationSize = 120,
  });

  final String illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double illustrationSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduced = AppTokens.reduceMotion(context);
    final note = message;
    final label = actionLabel;

    final children = <Widget>[
      Illustration(illustration, size: illustrationSize),
      const SizedBox(height: AppTokens.space16),
      Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.h2(p.ink),
          textAlign: TextAlign.center,
        ),
      ),
      if (note != null && note.isNotEmpty) ...[
        const SizedBox(height: AppTokens.space8),
        Text(
          note,
          style: AppTextStyles.body(p.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
      if (label != null && onAction != null) ...[
        const SizedBox(height: AppTokens.space24),
        PressableButton(label: label, onPressed: onAction, fullWidth: false),
      ],
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reduced
              ? children
              : children
                  .animate(interval: AppTokens.stagger)
                  .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
                  .moveY(
                    begin: AppTokens.entranceOffset,
                    end: 0,
                    duration: AppTokens.medium,
                    curve: AppTokens.curve,
                  ),
        ),
      ),
    );
  }
}
