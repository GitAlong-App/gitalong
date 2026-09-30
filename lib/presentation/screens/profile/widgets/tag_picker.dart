import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// A grid of toggle chips plus, optionally, a field to add an entry that
/// isn't in [options] (e.g. a language GitHub didn't detect).
class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.options,
    required this.isSelected,
    required this.onToggle,
    this.onAdd,
    this.addHint = 'Add another',
    this.addLabel = 'Add',
    this.maxLength = 40,
  });

  final List<String> options;
  final bool Function(String option) isSelected;
  final ValueChanged<String> onToggle;

  /// Adds a custom entry (already trimmed, never empty). No field when null.
  final ValueChanged<String>? onAdd;

  final String addHint;
  final String addLabel;

  /// Max characters of a custom entry.
  final int maxLength;

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final onAdd = widget.onAdd;
    final value = _controller.text.trim();
    if (onAdd == null || value.isEmpty) return;
    onAdd(value);
    _controller.clear();
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) =>
      null;

  @override
  Widget build(BuildContext context) {
    final onAdd = widget.onAdd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tappable chips already reserve a 48 px touch target (6 px above
        // and below), which doubles as the run spacing.
        Wrap(
          spacing: AppTokens.space8,
          children: [
            for (final option in widget.options)
              GaChip(
                label: option,
                selected: widget.isSelected(option),
                onTap: () => widget.onToggle(option),
              ),
          ],
        ),
        if (onAdd != null) ...[
          const SizedBox(height: AppTokens.space8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: widget.maxLength,
                  buildCounter: _noCounter,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: widget.addHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final entry = value.text.trim();
                  return PressableButton(
                    label: widget.addLabel,
                    size: PressableSize.small,
                    variant: PressableVariant.secondary,
                    icon: PhosphorIconsBold.plus,
                    fullWidth: false,
                    semanticLabel: entry.isEmpty
                        ? widget.addLabel
                        : '${widget.addLabel} $entry',
                    onPressed: entry.isEmpty ? null : _submit,
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
