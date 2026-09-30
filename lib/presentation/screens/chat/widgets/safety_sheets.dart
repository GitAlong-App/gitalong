import 'package:flutter/material.dart';

import '../../../../core/constants/collab_constants.dart';
import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// What the user picked in the chat's safety tools.
enum SafetyAction { unmatch, block, report }

/// What the user chose in the report dialog.
class ReportResult {
  const ReportResult({
    required this.reason,
    required this.details,
    required this.alsoBlock,
  });

  /// One of `CollabConstants.reportReasons` keys.
  final String reason;

  /// Trimmed free text, or null when empty.
  final String? details;

  /// Also block the reported person.
  final bool alsoBlock;
}

/// A bottom sheet with Unmatch / Block / Report. Returns the chosen action,
/// or null when dismissed.
Future<SafetyAction?> showSafetySheet(
  BuildContext context, {
  required String name,
  required bool canUnmatch,
  required bool canBlockOrReport,
}) {
  return showModalBottomSheet<SafetyAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.palette.card,
    builder: (context) => _SafetySheet(
      name: name,
      canUnmatch: canUnmatch,
      canBlockOrReport: canBlockOrReport,
    ),
  );
}

/// A confirm dialog for a destructive safety action. Resolves to true only
/// when the user confirms.
Future<bool> showSafetyConfirmDialog(
  BuildContext context, {
  required String illustration,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _ConfirmDialog(
      illustration: illustration,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    ),
  );
  return result ?? false;
}

/// The report form: a reason (required), optional details and "Also block"
/// (on by default). Returns null when cancelled.
Future<ReportResult?> showReportDialog(
  BuildContext context, {
  required String name,
}) {
  return showDialog<ReportResult>(
    context: context,
    builder: (context) => _ReportDialog(name: name),
  );
}

class _SafetySheet extends StatelessWidget {
  const _SafetySheet({
    required this.name,
    required this.canUnmatch,
    required this.canBlockOrReport,
  });

  final String name;
  final bool canUnmatch;
  final bool canBlockOrReport;

  @override
  Widget build(BuildContext context) {
    void choose(SafetyAction action) => Navigator.pop(context, action);

    // The sheet's own safe area leaves out the bottom inset.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          0,
          AppTokens.gutter,
          AppTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MascotBubble(
              message: "Something feel off? You're in control here.",
              mascotSize: 64,
            ),
            const SizedBox(height: AppTokens.space20),
            _SafetyOption(
              enabled: canUnmatch,
              child: OptionCard(
                title: 'Unmatch',
                subtitle: 'Remove the match and this chat for both of you.',
                illustration: Illustrations.wavingHand,
                selectionMode: OptionSelectionMode.none,
                onTap: canUnmatch ? () => choose(SafetyAction.unmatch) : null,
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            _SafetyOption(
              enabled: canBlockOrReport,
              child: OptionCard(
                title: 'Block $name',
                subtitle: "You won't see each other again. They won't be "
                    'notified.',
                illustration: Illustrations.locked,
                selectionMode: OptionSelectionMode.none,
                onTap:
                    canBlockOrReport ? () => choose(SafetyAction.block) : null,
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            _SafetyOption(
              enabled: canBlockOrReport,
              child: OptionCard(
                title: 'Report $name',
                subtitle: 'Tell us what happened. We review every report.',
                illustration: Illustrations.shield,
                selectionMode: OptionSelectionMode.none,
                onTap:
                    canBlockOrReport ? () => choose(SafetyAction.report) : null,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            PressableButton(
              label: 'Cancel',
              variant: PressableVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims an option that can't be used right now (OptionCard itself only
/// changes its semantics when disabled).
class _SafetyOption extends StatelessWidget {
  const _SafetyOption({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;
    return Opacity(opacity: 0.45, child: child);
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.illustration,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String illustration;
  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Illustration(illustration, size: 72)),
            const SizedBox(height: AppTokens.space16),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2(palette.ink),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(palette.inkMuted),
            ),
            const SizedBox(height: AppTokens.space24),
            PressableButton(
              label: confirmLabel,
              variant: PressableVariant.danger,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            PressableButton(
              label: 'Cancel',
              variant: PressableVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reason picker + optional details. Owns its TextEditingController so it is
/// disposed only after the dialog's exit animation.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.name});

  final String name;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String? _reason;
  bool _alsoBlock = true;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) return;
    final details = _detailsController.text.trim();
    Navigator.pop(
      context,
      ReportResult(
        reason: reason,
        details: details.isEmpty ? null : details,
        alsoBlock: _alsoBlock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Illustration(Illustrations.shield, size: 64)),
            const SizedBox(height: AppTokens.space12),
            Semantics(
              header: true,
              child: Text(
                'Report ${widget.name}',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2(palette.ink),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Why are you reporting this person? Reports are private.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(palette.inkMuted),
            ),
            const SizedBox(height: AppTokens.space16),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              alignment: WrapAlignment.center,
              children: [
                for (final reason in CollabConstants.reportReasons)
                  GaChip(
                    label: reason.label,
                    selected: _reason == reason.key,
                    onTap: () => setState(() => _reason = reason.key),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            TextField(
              controller: _detailsController,
              maxLength: CollabConstants.reportDetailsMaxLength,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.body(palette.ink),
              decoration: InputDecoration(
                hintText: 'Add details (optional)',
                hintStyle: AppTextStyles.body(palette.inkMuted),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _alsoBlock,
              activeColor: AppColors.green,
              checkColor: Colors.white,
              title: Text(
                'Also block ${widget.name}',
                style: AppTextStyles.body(palette.ink),
              ),
              onChanged: (value) => setState(() => _alsoBlock = value ?? false),
            ),
            const SizedBox(height: AppTokens.space12),
            PressableButton(
              label: 'Report',
              variant: PressableVariant.danger,
              onPressed: _reason == null ? null : _submit,
            ),
            const SizedBox(height: 10),
            PressableButton(
              label: 'Cancel',
              variant: PressableVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
