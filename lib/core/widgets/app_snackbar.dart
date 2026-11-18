import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Shows a short message at the bottom of the screen, replacing any message
/// that is still visible.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: kTextPrimary)),
        backgroundColor: kSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kBorder),
        ),
        action: action,
      ),
    );
}
