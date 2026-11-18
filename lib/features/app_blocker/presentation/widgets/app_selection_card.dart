import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../domain/entities/blocker_profile.dart';

/// Shows how many apps a profile blocks and opens the app picker.
///
/// iOS keeps the selected apps opaque to the app (only the picker and the
/// shield can show them), so the card can show a count but not names.
class AppSelectionCard extends StatelessWidget {
  const AppSelectionCard({
    super.key,
    required this.profile,
    required this.accent,
    required this.onTap,
  });

  final BlockerProfile profile;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final empty = !profile.hasAppsSelected;
    final foreground = colors.readable(accent);
    return AppCard(
      tint: accent,
      emphasized: true,
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(
            icon: empty ? Icons.add_rounded : Icons.apps_rounded,
            size: IconBadge.small,
            color: foreground,
            background: accent.withValues(alpha: AppOpacity.tint),
            circular: true,
          ),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  empty
                      ? s.selectAppsToBlock
                      : s.appsSelected(profile.appCount),
                  style: text.subheading,
                ),
                Gap.vXxs,
                Text(
                  empty ? s.tapToChooseApps : s.tapToEditSelection,
                  style: text.caption.tone(colors.textSecondary),
                ),
              ],
            ),
          ),
          Gap.hSm,
          Icon(
            empty ? Icons.add_circle_rounded : Icons.edit_rounded,
            size: AppSizes.iconMd,
            color: foreground,
          ),
        ],
      ),
    );
  }
}
