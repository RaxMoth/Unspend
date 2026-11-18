import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

/// Headline of the dashboard: how many profiles are active right now.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.totalProfiles,
    required this.activeCount,
  });

  final int totalProfiles;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final allActive = totalProfiles > 0 && activeCount == totalProfiles;
    final anyActive = activeCount > 0;

    final title = anyActive
        ? allActive
              ? s.allShieldsActive
              : s.someShieldsActive(activeCount, totalProfiles)
        : totalProfiles == 0
        ? s.noProfiles
        : s.shieldsInactive;
    final subtitle = anyActive
        ? s.blockingDistractingApps
        : totalProfiles == 0
        ? s.createProfileToStart
        : s.noProfilesAreActive;

    return MergeSemantics(
      child: AppCard(
        tint: anyActive ? colors.accent : null,
        gradient: anyActive
            ? LinearGradient(
                colors: colors.activeGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.shield_rounded,
              size: IconBadge.large,
              color: colors.accent,
              muted: !anyActive,
              background: anyActive ? colors.accentContainer : null,
            ),
            Gap.hLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.heading),
                  Gap.vXs,
                  Text(
                    subtitle,
                    style: text.bodySmall.tone(colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (anyActive) ...[Gap.hMd, const _ActiveDot()],
          ],
        ),
      ),
    );
  }
}

/// The glowing dot that says "something is on".
class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  static const double _size = 12;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: AppOpacity.outline),
            blurRadius: AppSpacing.sm,
            spreadRadius: AppSpacing.xxs,
          ),
        ],
      ),
    );
  }
}
