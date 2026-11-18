import 'package:flutter/material.dart';

import '../constants/strings.dart';
import 'app_snackbar.dart';

/// Runs something the user started. A failure nobody anticipated is logged
/// and answered with a plain "please try again" instead of leaving the user
/// in front of a screen that silently did nothing.
///
/// Expected failures (Screen Time refusing an action, a wrong PIN) are
/// handled where they happen, with a message that says what to do.
Future<void> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error, stack) {
    debugPrint('[Unspend] Unexpected failure: $error\n$stack');
    if (context.mounted) showAppSnackBar(context, S.current.errorTryAgain);
  }
}
