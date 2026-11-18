import 'package:flutter/material.dart';

import '../constants/strings.dart';
import '../theme/theme.dart';

/// The app's dialog: a title, scrolling content and a row of buttons.
/// Content scrolls when it does not fit (small phones, large text, the
/// keyboard).
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.destructive = false,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  /// Shows the title in the warning colour.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        title,
        style: destructive
            ? context.text.heading.tone(context.colors.accentText)
            : null,
      ),
      content: content,
      actions: actions,
    );
  }
}

/// A button in an [AppDialog]. [DialogButton.cancel] is the quiet way out;
/// the default is the action the dialog is about.
class DialogButton extends StatelessWidget {
  const DialogButton({super.key, required this.label, required this.onPressed})
    : _quiet = false;

  const DialogButton.cancel({super.key, required this.label, this.onPressed})
    : _quiet = true;

  final String label;

  /// Null disables an action button; a cancel button without a callback
  /// closes the dialog with `false`.
  final VoidCallback? onPressed;
  final bool _quiet;

  @override
  Widget build(BuildContext context) {
    if (_quiet) {
      return TextButton(
        onPressed: onPressed ?? () => Navigator.of(context).pop(false),
        child: Text(
          label,
          style: context.text.body.tone(context.colors.textSecondary),
        ),
      );
    }
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

/// Whether [context]'s route is the one in front. Used to ignore a second
/// tap that arrives while a sheet or dialog opened by the first is already
/// on its way in.
bool isFrontmost(BuildContext context) =>
    ModalRoute.of(context)?.isCurrent ?? true;

/// Asks the user to confirm an action. Returns true when they did.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  if (!isFrontmost(context)) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      destructive: destructive,
      content: Text(message),
      actions: [
        DialogButton.cancel(label: S.current.cancel),
        DialogButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
