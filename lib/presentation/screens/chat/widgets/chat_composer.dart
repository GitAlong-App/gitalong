import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// The message composer: a rounded pill text field and a round 3D send
/// button.
///
/// The field grows to six lines and then scrolls, is limited to
/// [maxLength] characters (the `messages.content` limit) and shows a
/// counter near the limit. Send is enabled only when [canSend] and there is
/// something besides whitespace to send.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.hintText,
    required this.onSend,
  });

  /// `messages.content` holds 1–4000 characters.
  static const int maxLength = 4000;

  /// Show the character counter from here on.
  static const int _counterFrom = 3600;

  final TextEditingController controller;

  /// Whether the text field accepts input.
  final bool enabled;

  /// Whether a message can be sent (e.g. the recipient has loaded).
  final bool canSend;

  final String hintText;
  final VoidCallback onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _sendEnabled(TextEditingValue value) =>
      widget.enabled && widget.canSend && value.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      // messages.content is limited to 4000 characters.
      inputFormatters: [
        LengthLimitingTextInputFormatter(ChatComposer.maxLength),
      ],
      cursorColor: AppColors.green,
      style: AppTextStyles.body(palette.ink),
      onSubmitted: (_) {
        if (_sendEnabled(widget.controller.value)) widget.onSend();
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintMaxLines: 2,
        hintStyle: AppTextStyles.body(palette.inkMuted),
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      ),
    );

    final pill = ListenableBuilder(
      listenable: _focusNode,
      builder: (context, child) {
        final focused = _focusNode.hasFocus;
        return AnimatedContainer(
          duration: AppTokens.motion(context, AppTokens.fast),
          curve: AppTokens.curve,
          decoration: BoxDecoration(
            // Same fill when disabled so the hint keeps AA contrast; the
            // hint and the disabled send button say why.
            color: palette.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: focused ? AppColors.green : palette.border,
              width: AppTokens.borderWidth,
            ),
          ),
          child: child,
        );
      },
      child: field,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(
          top: BorderSide(color: palette.border, width: AppTokens.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            child: pill,
            builder: (context, value, child) {
              final length = value.text.length;
              final atLimit = length >= ChatComposer.maxLength;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (length >= ChatComposer._counterFrom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, right: 6),
                      child: Text(
                        '$length / ${ChatComposer.maxLength}',
                        textAlign: TextAlign.end,
                        style: AppTextStyles.bodySmall(
                          atLimit
                              ? palette.toneText(AppTone.danger)
                              : palette.inkMuted,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: child ?? pill),
                      const SizedBox(width: 10),
                      CircleActionButton(
                        icon: PhosphorIconsFill.paperPlaneTilt,
                        semanticLabel: 'Send message',
                        onPressed: _sendEnabled(value) ? widget.onSend : null,
                        size: 52,
                        // The screen plays the "message sent" feedback.
                        haptics: false,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
