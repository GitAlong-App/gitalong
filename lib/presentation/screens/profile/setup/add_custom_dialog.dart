import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/ui/ui.dart';

/// Asks for one custom chip value ("Add your own"). Resolves to the trimmed,
/// single-spaced text, or null when cancelled.
///
/// Commas and line breaks are blocked: Edit profile stores these lists as
/// comma-separated text, so a comma would split the entry in two there.
Future<String?> showAddCustomDialog(
  BuildContext context, {
  required String title,
  required String hint,
  int maxLength = 30,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AddCustomDialog(
      title: title,
      hint: hint,
      maxLength: maxLength,
    ),
  );
}

class _AddCustomDialog extends StatefulWidget {
  const _AddCustomDialog({
    required this.title,
    required this.hint,
    required this.maxLength,
  });

  final String title;
  final String hint;
  final int maxLength;

  @override
  State<_AddCustomDialog> createState() => _AddCustomDialogState();
}

class _AddCustomDialogState extends State<_AddCustomDialog> {
  final TextEditingController _controller = TextEditingController();

  static final RegExp _whitespace = RegExp(r'\s+');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim().replaceAll(_whitespace, ' ');

  void _submit() {
    final value = _value;
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[,\n]'))],
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        PressableButton(
          label: 'Cancel',
          variant: PressableVariant.ghost,
          size: PressableSize.small,
          fullWidth: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => PressableButton(
            label: 'Add',
            size: PressableSize.small,
            fullWidth: false,
            onPressed: value.text.trim().isEmpty ? null : _submit,
          ),
        ),
      ],
    );
  }
}
