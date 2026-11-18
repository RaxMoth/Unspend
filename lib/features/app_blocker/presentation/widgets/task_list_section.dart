import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../domain/entities/blocker_profile.dart';
import '../providers/profiles_provider.dart';
import 'task_tile.dart';

/// The tasks of a task-mode profile: tick them off, and while the profile
/// is inactive add and remove them.
class TaskListSection extends ConsumerStatefulWidget {
  const TaskListSection({
    super.key,
    required this.profile,
    required this.accent,
  });

  final BlockerProfile profile;
  final Color accent;

  @override
  ConsumerState<TaskListSection> createState() => _TaskListSectionState();
}

class _TaskListSectionState extends ConsumerState<TaskListSection> {
  final _taskController = TextEditingController();

  ProfilesNotifier get _notifier => ref.read(profilesProvider.notifier);

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _addTask() {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;
    AppHaptics.selection();
    _notifier.addTask(widget.profile.id, title);
    _taskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final profile = widget.profile;
    final accent = widget.accent;
    final tasks = profile.tasks;
    final done = profile.doneTaskCount;
    final allDone = profile.allTasksDone;
    final progressColor = allDone ? colors.success : accent;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: AppSizes.iconMd,
                      color: colors.readable(accent),
                    ),
                    Gap.hSm,
                    Expanded(child: Text(s.tasks, style: text.label)),
                    if (tasks.isNotEmpty)
                      Semantics(
                        label: s.tasksProgress(done, tasks.length),
                        excludeSemantics: true,
                        child: AppChip(
                          label: '$done / ${tasks.length}',
                          color: progressColor,
                        ),
                      ),
                  ],
                ),
                Gap.vMd,
                if (tasks.isNotEmpty)
                  AppProgressBar(
                    value: done / tasks.length,
                    color: progressColor,
                  )
                else
                  Text(
                    s.emptyTasksHint,
                    style: text.caption.tone(colors.textSecondary),
                  ),
              ],
            ),
          ),
          Gap.vXs,
          for (final task in tasks)
            Padding(
              padding: EdgeInsets.only(
                right: profile.isActive ? AppSpacing.sm : 0,
              ),
              child: TaskTile(
                key: ValueKey(task.id),
                task: task,
                onToggle: () => _notifier.toggleTask(profile.id, task.id),
                onDelete: profile.isActive
                    ? null
                    : () => _notifier.removeTask(profile.id, task.id),
              ),
            ),
          if (!profile.isActive) ...[
            Gap.vSm,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    style: text.body,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: s.addTaskHint,
                      hintStyle: text.body.tone(colors.textSecondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                Gap.hXs,
                IconButton(
                  tooltip: s.addTask,
                  onPressed: _addTask,
                  style: IconButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: AppOpacity.tint),
                    foregroundColor: colors.readable(accent),
                    shape: AppRadius.controlShape,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ] else if (tasks.isNotEmpty) ...[
            Gap.vSm,
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: AppSizes.iconXs),
                  Gap.hSm,
                  Expanded(
                    child: Text(
                      allDone
                          ? s.allTasksDoneNote
                          : s.tasksRemainingNote(profile.pendingTaskCount),
                      style: text.caption
                          .tone(colors.textSecondary)
                          .copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
