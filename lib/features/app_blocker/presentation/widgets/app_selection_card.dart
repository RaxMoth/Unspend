import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';

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
    final empty = !profile.hasAppsSelected;
    return Material(
      color: accent.withValues(alpha: empty ? 0.06 : 0.10),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(
              color: accent.withValues(alpha: empty ? 0.45 : 0.30),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  empty ? Icons.add_rounded : Icons.apps_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      empty
                          ? S.current.selectAppsToBlock
                          : S.current.appsSelected(profile.appCount),
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty
                          ? S.current.tapToChooseApps
                          : S.current.tapToEditSelection,
                      style: TextStyle(color: kTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                empty ? Icons.add_circle_rounded : Icons.edit_rounded,
                color: accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
