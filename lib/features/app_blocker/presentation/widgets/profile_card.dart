import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../domain/entities/blocker_profile.dart';
import '../profile_formatters.dart';
import '../providers/current_minute_provider.dart';
import '../providers/profiles_provider.dart';
import 'task_tile.dart';

/// A profile on the dashboard: what it blocks, whether it is active and
/// blocking right now, a switch to turn it on or off and, in task mode,
/// today's tasks.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
    required this.onToggle,
  });

  final BlockerProfile profile;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  /// Size of the "blocking / not blocking" indicator.
  static const double _statusBadgeSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final now = ref.watch(currentMinuteProvider);
    final limitReached = ref.watch(
      shieldStatusProvider.select(
        (statuses) => statuses[profile.id]?.limitReachedToday ?? false,
      ),
    );
    final blocking = profile.isBlockingAt(now, limitReachedToday: limitReached);
    final reason = profile.requirementReason(
      s,
      now,
      limitReachedToday: limitReached,
    );
    final subtitle = profile.subtitle(s);
    final status = profile.isActive
        ? '${s.statusActive}, $reason'
        : s.statusInactive;
    final chipColor = profile.isActive ? profile.color : colors.textSecondary;

    void open() {
      AppHaptics.selection();
      onTap();
    }

    return AppCard(
      outline: profile.isActive
          ? profile.color.withValues(alpha: AppOpacity.outline)
          : null,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      onTap: open,
      excludeTapFromSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  label: '${profile.name}, $subtitle, $status',
                  excludeSemantics: true,
                  onTap: open,
                  child: Row(
                    children: [
                      IconBadge(
                        icon: profile.profileIcon.icon,
                        color: colors.readable(profile.color),
                        background: profile.isActive
                            ? profile.color.withValues(alpha: AppOpacity.tint)
                            : null,
                        muted: !profile.isActive,
                      ),
                      Gap.hMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.subheading,
                            ),
                            Gap.vXs,
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.caption.tone(colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (profile.isActive) ...[
                        Gap.hSm,
                        Tooltip(
                          message: reason,
                          child: AnimatedSwitcher(
                            duration: context.motion(AppDurations.medium),
                            child: IconBadge(
                              key: ValueKey(blocking),
                              icon: blocking
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: _statusBadgeSize,
                              color: colors.readable(
                                blocking ? profile.color : colors.success,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Gap.hXs,
              AppSwitch(
                value: profile.isActive,
                activeColor: profile.color,
                semanticLabel:
                    '${profile.isActive ? s.deactivateShield : s.activateShield}, ${profile.name}',
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          if (!profile.isManualOnly) ...[
            Gap.vSm,
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (profile.scheduleEnabled)
                      AppChip(
                        icon: Icons.schedule_rounded,
                        label: s.scheduleTitle,
                        color: chipColor,
                      ),
                    if (profile.usageLimitEnabled)
                      AppChip(
                        icon: Icons.timer_rounded,
                        label: s.usageLimitTitle,
                        color: chipColor,
                      ),
                    if (profile.taskModeEnabled)
                      AppChip(
                        icon: Icons.checklist_rounded,
                        label: s.taskModeTitle,
                        color: chipColor,
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (profile.taskModeEnabled && profile.tasks.isNotEmpty) ...[
            Gap.vSm,
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: Divider(height: 1),
            ),
            Gap.vXs,
            for (final task in profile.tasks)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: TaskTile(
                  key: ValueKey(task.id),
                  task: task,
                  maxLines: 2,
                  onToggle: () => ref
                      .read(profilesProvider.notifier)
                      .toggleTask(profile.id, task.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
