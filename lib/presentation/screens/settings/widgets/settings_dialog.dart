import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// A friendly on-brand dialog: an illustration (or an [icon] in a tinted
/// circle), a title, a message and stacked 3D buttons.
///
/// Resolves to true only when the confirm button is pressed.
Future<bool> showSettingsDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  PressableVariant confirmVariant = PressableVariant.primary,
  IconData? confirmIcon,
  String? cancelLabel,
  String? illustration,
  IconData? icon,
  AppTone iconTone = AppTone.danger,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _SettingsDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmVariant: confirmVariant,
      confirmIcon: confirmIcon,
      cancelLabel: cancelLabel,
      illustration: illustration,
      icon: icon,
      iconTone: iconTone,
    ),
  );
  return confirmed ?? false;
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmVariant,
    required this.confirmIcon,
    required this.cancelLabel,
    required this.illustration,
    required this.icon,
    required this.iconTone,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final PressableVariant confirmVariant;
  final IconData? confirmIcon;
  final String? cancelLabel;
  final String? illustration;
  final IconData? icon;
  final AppTone iconTone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final illustration = this.illustration;
    final icon = this.icon;
    final cancelLabel = this.cancelLabel;

    Widget? art;
    if (illustration != null) {
      art = Illustration(illustration, size: 72);
    } else if (icon != null) {
      art = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: palette.tint(iconTone),
          shape: BoxShape.circle,
          border: Border.all(
            color: iconTone.fill,
            width: AppTokens.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 36, color: palette.toneText(iconTone)),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(AppTokens.space24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space24,
            28,
            AppTokens.space24,
            AppTokens.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (art != null) ...[
                Center(child: art),
                const SizedBox(height: AppTokens.space16),
              ],
              Semantics(
                header: true,
                namesRoute: true,
                child: Text(
                  title,
                  style: AppTextStyles.h2(palette.ink),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                message,
                style: AppTextStyles.body(palette.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space24),
              PressableButton(
                label: confirmLabel,
                variant: confirmVariant,
                icon: confirmIcon,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              if (cancelLabel != null) ...[
                const SizedBox(height: AppTokens.space8),
                PressableButton(
                  label: cancelLabel,
                  variant: PressableVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
