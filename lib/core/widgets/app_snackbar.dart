import 'package:flutter/material.dart';

/// Shows a short message at the bottom of the screen, replacing any message
/// that is still visible. Its look comes from the theme.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
