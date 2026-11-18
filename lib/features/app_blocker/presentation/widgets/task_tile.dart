import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';

import '../../domain/entities/blocker_profile.dart';

/// One task: tap to tick or untick it. Shown on the profile card and in
/// the profile's task list.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    this.onDelete,
    this.maxLines,
  });

  final BlockerTask task;
  final VoidCallback onToggle;

  /// Shows a delete button when set (tasks are fixed while a profile is
  /// active).
  final VoidCallback? onDelete;

  /// Limits the title to this many lines; unlimited when null.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: MergeSemantics(
            child: Semantics(
              checked: task.isDone,
              child: InkWell(
                onTap: () {
                  AppHaptics.selection();
                  onToggle();
                },
                borderRadius: AppRadius.chip,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.tapTarget,
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: context.motion(AppDurations.fast),
                        child: Icon(
                          task.isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(task.isDone),
                          size: AppSizes.iconMd,
                          color: task.isDone
                              ? colors.successText
                              : colors.textSecondary,
                        ),
                      ),
                      Gap.hMd,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            task.title,
                            maxLines: maxLines,
                            overflow: maxLines == null
                                ? null
                                : TextOverflow.ellipsis,
                            style: context.text.body
                                .tone(
                                  task.isDone
                                      ? colors.textSecondary
                                      : colors.textPrimary,
                                )
                                .copyWith(
                                  decoration: task.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: colors.textSecondary,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onDelete != null)
          IconButton(
            tooltip: S.current.deleteTaskLabel(task.title),
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: AppSizes.iconMd),
          ),
      ],
    );
  }
}
