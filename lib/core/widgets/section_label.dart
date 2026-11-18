import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Small heading above a group of settings.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  /// Slightly spaced letters set the label apart from body text.
  static const double _letterSpacing = 0.5;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: context.text.bodySmall.strong
            .tone(context.colors.textSecondary)
            .copyWith(letterSpacing: _letterSpacing),
      ),
    );
  }
}
