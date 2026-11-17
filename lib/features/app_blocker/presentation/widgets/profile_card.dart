import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/app_switch.dart';

import '../../domain/entities/blocker_profile.dart';
import '../profile_formatters.dart';
import '../providers/current_minute_provider.dart';
import '../providers/profiles_provider.dart';

/// Small label naming one of a profile's rules.
class ModeChip extends StatelessWidget {
  const ModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final chipColor = isActive ? kReadable(color) : kTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: chipColor, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.current;
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

    void open() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        onTap: open,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(
              color: profile.isActive
                  ? profile.color.withValues(alpha: 0.4)
                  : kBorder,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: profile.isActive
                                  ? profile.color.withValues(alpha: 0.15)
                                  : kBorder,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              profile.profileIcon.icon,
                              size: 24,
                              color: profile.isActive
                                  ? profile.color
                                  : kTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: kTextPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: kTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (profile.isActive) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: reason,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (blocking ? profile.color : kSuccess)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  blocking
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                                  size: 18,
                                  color: blocking ? profile.color : kSuccess,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
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
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ExcludeSemantics(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (profile.scheduleEnabled)
                          ModeChip(
                            icon: Icons.schedule_rounded,
                            label: s.scheduleTitle,
                            color: profile.color,
                            isActive: profile.isActive,
                          ),
                        if (profile.usageLimitEnabled)
                          ModeChip(
                            icon: Icons.timer_rounded,
                            label: s.usageLimitTitle,
                            color: profile.color,
                            isActive: profile.isActive,
                          ),
                        if (profile.taskModeEnabled)
                          ModeChip(
                            icon: Icons.checklist_rounded,
                            label: s.taskModeTitle,
                            color: profile.color,
                            isActive: profile.isActive,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (profile.taskModeEnabled && profile.tasks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Divider(color: kBorder, height: 1),
                ),
                const SizedBox(height: 4),
                for (final task in profile.tasks)
                  _CardTaskRow(
                    task: task,
                    color: profile.color,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(profilesProvider.notifier)
                          .toggleTask(profile.id, task.id);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTaskRow extends StatelessWidget {
  const _CardTaskRow({
    required this.task,
    required this.color,
    required this.onTap,
  });

  final BlockerTask task;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: task.isDone,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Icon(
                    task.isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: task.isDone ? color : kTextSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: task.isDone ? kTextSecondary : kTextPrimary,
                        fontSize: 13,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: kTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
