import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';

import '../../domain/entities/blocker_profile.dart';
import '../providers/profiles_provider.dart';
import 'section_widgets.dart';

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
    HapticFeedback.selectionClick();
    _notifier.addTask(widget.profile.id, title);
    _taskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final profile = widget.profile;
    final accent = widget.accent;
    final tasks = profile.tasks;
    final done = profile.doneTaskCount;
    final allDone = profile.allTasksDone;
    final progressColor = allDone ? kSuccess : accent;

    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.tasks,
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    Semantics(
                      label: s.tasksProgress(done, tasks.length),
                      excludeSemantics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: progressColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$done / ${tasks.length}',
                          style: TextStyle(
                            color: kReadable(progressColor),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: done / tasks.length,
                      backgroundColor: kBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Text(
                  s.emptyTasksHint,
                  style: TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ),

            for (final task in tasks)
              _TaskRow(
                task: task,
                onToggle: () {
                  HapticFeedback.selectionClick();
                  _notifier.toggleTask(profile.id, task.id);
                },
                onDelete: profile.isActive
                    ? null
                    : () => _notifier.removeTask(profile.id, task.id),
              ),

            if (!profile.isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      style: TextStyle(color: kTextPrimary, fontSize: 14),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: s.addTaskHint,
                        hintStyle: TextStyle(
                          color: kTextSecondary,
                          fontSize: 14,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _addTask(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: s.addTask,
                    onPressed: _addTask,
                    style: IconButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.15),
                      foregroundColor: accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 22),
                  ),
                ],
              ),
            ] else if (tasks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: kTextSecondary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        allDone
                            ? s.allTasksDoneNote
                            : s.tasksRemainingNote(profile.pendingTaskCount),
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final BlockerTask task;
  final VoidCallback onToggle;

  /// Null hides the delete button (tasks are fixed while active).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MergeSemantics(
            child: Semantics(
              checked: task.isDone,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: task.isDone
                              ? kSuccess.withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: task.isDone ? kSuccess : kTextSecondary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: task.isDone
                            ? const Icon(
                                Icons.check_rounded,
                                color: kSuccess,
                                size: 16,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            task.title,
                            style: TextStyle(
                              color: task.isDone
                                  ? kTextSecondary
                                  : kTextPrimary,
                              fontSize: 14,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: kTextSecondary,
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
            icon: Icon(Icons.close_rounded, color: kTextSecondary, size: 20),
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }
}
