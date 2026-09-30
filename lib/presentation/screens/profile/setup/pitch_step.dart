import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';
import 'setup_step_layout.dart';

/// Setup step 5: the pitch. A big text area with a live counter (in code
/// points, like the database) and a tip from Octo.
class PitchStep extends StatelessWidget {
  const PitchStep({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.controller,
    required this.maxRunes,
    this.enabled = true,
  });

  final int stepNumber;
  final int stepCount;
  final TextEditingController controller;

  /// `users.pitch` limit (`char_length(pitch) <= 280`).
  final int maxRunes;

  /// False while saving.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SetupStepLayout(
      stepNumber: stepNumber,
      stepCount: stepCount,
      title: 'What are you building?',
      subtitle: 'A line or two about your project and who you need. It shows '
          'on your card.',
      optional: true,
      children: [
        MascotBubble(
          message: "Tip: be specific! Say what you're building and who would "
              'make it better.',
          mascotSize: 72,
        ),
        const SizedBox(height: AppTokens.space20),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [RuneLimitingTextInputFormatter(maxRunes)],
          style: AppTextStyles.body(p.ink),
          decoration: const InputDecoration(
            hintText: 'e.g. An open-source Flutter UI kit for dashboards. '
                'Looking for a designer who codes.',
            hintMaxLines: 4,
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        _PitchCounter(controller: controller, maxRunes: maxRunes),
      ],
    );
  }
}

/// "123 / 280", turning orange near the limit and red at it.
class _PitchCounter extends StatelessWidget {
  const _PitchCounter({required this.controller, required this.maxRunes});

  final TextEditingController controller;
  final int maxRunes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final used = value.text.runes.length;
        final left = maxRunes - used;
        final color = left <= 0
            ? p.toneText(AppTone.danger)
            : left <= 20
                ? p.toneText(AppTone.flame)
                : p.inkMuted;
        return Semantics(
          label: '$used of $maxRunes characters used',
          excludeSemantics: true,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '$used / $maxRunes',
              style: AppTextStyles.caption(color),
            ),
          ),
        );
      },
    );
  }
}

/// Limits text to [maxRunes] Unicode code points (`String.runes`), the unit
/// the database checks (`char_length(pitch) <= 280`). `TextField.maxLength`
/// counts grapheme clusters instead, which lets multi-code-point emoji slip
/// past the limit.
///
/// Behaves like `LengthLimitingTextInputFormatter`: typing at the limit is
/// ignored, a longer paste is cut after the last whole character that fits
/// (never inside an emoji), and IME composition may finish first.
class RuneLimitingTextInputFormatter extends TextInputFormatter {
  const RuneLimitingTextInputFormatter(this.maxRunes)
      : assert(maxRunes > 0, 'maxRunes must be positive');

  final int maxRunes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= maxRunes) return newValue;

    // Already full and trying to add more: keep what was there.
    if (oldValue.text.runes.length >= maxRunes &&
        oldValue.selection.isCollapsed &&
        !oldValue.composing.isValid) {
      return oldValue;
    }

    // Let the IME finish composing; the limit applies once it commits.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    return _truncate(newValue);
  }

  TextEditingValue _truncate(TextEditingValue value) {
    final buffer = StringBuffer();
    var runes = 0;
    for (final character in value.text.characters) {
      final length = character.runes.length;
      if (runes + length > maxRunes) break;
      buffer.write(character);
      runes += length;
    }
    final truncated = buffer.toString();
    return TextEditingValue(
      text: truncated,
      selection: value.selection.copyWith(
        baseOffset: math.min(value.selection.start, truncated.length),
        extentOffset: math.min(value.selection.end, truncated.length),
      ),
    );
  }
}
