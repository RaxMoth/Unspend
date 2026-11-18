import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';
import 'package:unspend/shared/providers/locale_provider.dart';

import '../../domain/entities/blocker_profile.dart';
import '../profile_actions.dart';
import '../profile_formatters.dart';
import '../providers/current_minute_provider.dart';
import '../providers/profiles_provider.dart';
import '../widgets/app_selection_card.dart';
import '../widgets/appearance_pickers.dart';
import '../widgets/locked_section.dart';
import '../widgets/rule_toggle_card.dart';
import '../widgets/schedule_card.dart';
import '../widgets/task_list_section.dart';
import '../widgets/usage_limit_sheet.dart';

/// Route target for one profile: follows the stored profile and shows the
/// editor for it. Leaves the route when the profile no longer exists (it
/// was deleted, or the id is unknown).
class ProfileDetailPageShell extends ConsumerStatefulWidget {
  const ProfileDetailPageShell({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProfileDetailPageShell> createState() =>
      _ProfileDetailPageShellState();
}

class _ProfileDetailPageShellState
    extends ConsumerState<ProfileDetailPageShell> {
  bool _leaving = false;

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.dashboard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only this profile is watched: unchanged profiles keep their identity
    // across updates, so edits to other profiles do not rebuild this screen.
    final profile = ref.watch(
      profilesProvider.select(
        (profiles) => profiles.whenData(
          (list) => list.where((p) => p.id == widget.profileId).firstOrNull,
        ),
      ),
    );
    return profile.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (_, _) {
        _leave();
        return const Scaffold();
      },
      data: (profile) {
        if (profile == null) {
          _leave();
          return const Scaffold();
        }
        return ProfileDetailScreen(profile: profile);
      },
    );
  }
}

/// Editor for one profile: appearance, apps, block rules and the button
/// that turns the block on or off. Changes are saved as they are made.
class ProfileDetailScreen extends ConsumerStatefulWidget {
  const ProfileDetailScreen({super.key, required this.profile});

  final BlockerProfile profile;

  @override
  ConsumerState<ProfileDetailScreen> createState() =>
      _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> {
  // Held so a pending save can still be flushed while disposing.
  late final ProfilesNotifier _notifier = ref.read(profilesProvider.notifier);
  final _nameController = TextEditingController();

  late bool _scheduleEnabled;
  late bool _usageLimitEnabled;
  late bool _taskModeEnabled;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _usageLimitMinutes;
  late int _colorValue;
  late String _iconLabel;

  Timer? _pendingSave;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _readFrom(widget.profile);
  }

  @override
  void didUpdateWidget(covariant ProfileDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) _readFrom(widget.profile);
  }

  @override
  void dispose() {
    // Leaving the screen within the debounce window must not lose the edit.
    if (_pendingSave?.isActive ?? false) {
      _pendingSave!.cancel();
      _notifier.updateProfile(_edited);
    }
    _nameController.dispose();
    super.dispose();
  }

  void _readFrom(BlockerProfile profile) {
    _nameController.text = profile.name;
    _scheduleEnabled = profile.scheduleEnabled;
    _usageLimitEnabled = profile.usageLimitEnabled;
    _taskModeEnabled = profile.taskModeEnabled;
    _startTime = TimeOfDay(
      hour:
          profile.scheduleStartHour ?? BlockerProfile.defaultScheduleStartHour,
      minute: profile.scheduleStartMinute ?? 0,
    );
    _endTime = TimeOfDay(
      hour: profile.scheduleEndHour ?? BlockerProfile.defaultScheduleEndHour,
      minute: profile.scheduleEndMinute ?? 0,
    );
    _usageLimitMinutes =
        profile.usageLimitMinutes ?? BlockerProfile.defaultUsageLimitMinutes;
    _colorValue = profile.colorValue;
    _iconLabel = profile.iconLabel;
  }

  /// The profile with everything currently shown on screen applied.
  BlockerProfile get _edited {
    final name = _nameController.text.trim();
    return widget.profile.copyWith(
      name: name.isEmpty ? S.current.untitled : name,
      colorValue: _colorValue,
      iconLabel: _iconLabel,
      scheduleEnabled: _scheduleEnabled,
      scheduleStartHour: _startTime.hour,
      scheduleStartMinute: _startTime.minute,
      scheduleEndHour: _endTime.hour,
      scheduleEndMinute: _endTime.minute,
      usageLimitEnabled: _usageLimitEnabled,
      usageLimitMinutes: _usageLimitMinutes,
      taskModeEnabled: _taskModeEnabled,
    );
  }

  Future<void> _save() {
    _pendingSave?.cancel();
    return _notifier.updateProfile(_edited);
  }

  /// For text input: save once typing pauses.
  void _saveSoon() {
    _pendingSave?.cancel();
    _pendingSave = Timer(AppDurations.typingDebounce, _save);
  }

  void _change(VoidCallback change) {
    setState(change);
    _save();
  }

  Future<void> _pickUsageLimit(Color accent) async {
    final minutes = await showUsageLimitSheet(
      context,
      initialMinutes: _usageLimitMinutes,
      accent: accent,
    );
    if (minutes == null || !mounted) return;
    _change(() => _usageLimitMinutes = minutes);
  }

  Future<void> _activate() async {
    if (_activating) return;
    setState(() => _activating = true);
    try {
      // The rules on screen are the rules that get enforced.
      await _save();
      if (mounted) await activateWithFeedback(context, ref, widget.profile);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.current.deleteProfile,
      message: S.current.deleteProfileConfirm(widget.profile.name),
      confirmLabel: S.current.delete,
      destructive: true,
    );
    if (!confirmed) return;
    _pendingSave?.cancel();
    // The page shell leaves the route once the profile is gone.
    await _notifier.deleteProfile(widget.profile.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final profile = widget.profile;
    final accent = Color(_colorValue);
    final locked = profile.isActive;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (!locked)
                    IconButton(
                      tooltip: s.deleteProfile,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => runGuarded(context, _confirmDelete),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ContentGutter(
                builder: (context, gutter) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    AppSpacing.sm,
                    gutter,
                    AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Name ───────────────────────────────────────────
                      Center(
                        child: ExcludeSemantics(
                          child: IconBadge(
                            icon: ProfileIcon.fromLabel(_iconLabel).icon,
                            size: IconBadge.hero,
                            color: colors.readable(accent),
                            background: accent.withValues(
                              alpha: AppOpacity.tint,
                            ),
                          ),
                        ),
                      ),
                      Gap.vSm,
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        maxLength: BlockerProfile.maxNameLength,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        style: text.screenTitle,
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          hintText: s.profileNamePlaceholder,
                          hintStyle: text.screenTitle.tone(
                            colors.textSecondary,
                          ),
                        ),
                        onChanged: (_) => _saveSoon(),
                        onSubmitted: (_) => _save(),
                      ),
                      Reveal(
                        visible: locked,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _BlockingStatus(profile: profile),
                        ),
                      ),
                      Gap.vSm,

                      // ── Appearance ─────────────────────────────────────
                      SectionLabel(s.sectionColor),
                      Gap.vXs,
                      ProfileColorPicker(
                        selectedValue: _colorValue,
                        onSelected: (value) =>
                            _change(() => _colorValue = value),
                      ),
                      Gap.vLg,
                      SectionLabel(s.sectionIcon),
                      Gap.vSm,
                      ProfileIconPicker(
                        selectedLabel: _iconLabel,
                        accent: accent,
                        onSelected: (label) =>
                            _change(() => _iconLabel = label),
                      ),
                      Gap.vXxl,

                      // ── Apps ───────────────────────────────────────────
                      SectionLabel(s.sectionApps),
                      Gap.vSm,
                      LockedSection(
                        locked: locked,
                        child: AppSelectionCard(
                          profile: profile,
                          accent: accent,
                          onTap: () {
                            AppHaptics.selection();
                            pickAppsWithFeedback(context, ref, profile);
                          },
                        ),
                      ),
                      Gap.vXxl,

                      // ── Rules ──────────────────────────────────────────
                      SectionLabel(s.sectionBlockRules),
                      Gap.vXs,
                      Text(
                        locked
                            ? s.settingsLockedWhileActive
                            : s.blockRulesDescription,
                        style: text.caption
                            .tone(
                              locked ? colors.accentText : colors.textSecondary,
                            )
                            .copyWith(
                              fontStyle: locked
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                      ),
                      Gap.vMd,

                      RuleToggleCard(
                        icon: Icons.calendar_today_rounded,
                        title: s.scheduleTitle,
                        description: s.scheduleDescription,
                        enabled: _scheduleEnabled,
                        accent: accent,
                        locked: locked,
                        onToggle: (on) => _change(() => _scheduleEnabled = on),
                      ),
                      Reveal(
                        visible: _scheduleEnabled,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: LockedSection(
                            locked: locked,
                            child: ScheduleCard(
                              start: _startTime,
                              end: _endTime,
                              accent: accent,
                              onStartChanged: (time) =>
                                  _change(() => _startTime = time),
                              onEndChanged: (time) =>
                                  _change(() => _endTime = time),
                            ),
                          ),
                        ),
                      ),
                      Gap.vMd,

                      RuleToggleCard(
                        icon: Icons.timer_rounded,
                        title: s.usageLimitTitle,
                        description: s.usageLimitDescription,
                        enabled: _usageLimitEnabled,
                        accent: accent,
                        locked: locked,
                        onToggle: (on) =>
                            _change(() => _usageLimitEnabled = on),
                      ),
                      Reveal(
                        visible: _usageLimitEnabled,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: LockedSection(
                            locked: locked,
                            child: UsageLimitCard(
                              minutes: _usageLimitMinutes,
                              accent: accent,
                              onTap: () => _pickUsageLimit(accent),
                            ),
                          ),
                        ),
                      ),
                      Gap.vMd,

                      RuleToggleCard(
                        icon: Icons.checklist_rounded,
                        title: s.taskModeTitle,
                        description: s.taskModeDescription,
                        enabled: _taskModeEnabled,
                        accent: accent,
                        locked: locked,
                        onToggle: (on) => _change(() => _taskModeEnabled = on),
                      ),
                      Reveal(
                        visible: _taskModeEnabled,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: TaskListSection(
                            profile: profile,
                            accent: accent,
                          ),
                        ),
                      ),
                      Gap.vXxl,

                      // ── Activate / deactivate ──────────────────────────
                      if (locked)
                        AppButton.secondary(
                          label: s.deactivateShield,
                          icon: Icons.shield_outlined,
                          onPressed: () =>
                              deactivateWithGate(context, ref, profile.id),
                        )
                      else if (profile.hasAppsSelected)
                        AppButton.primary(
                          label: s.activateShield,
                          icon: Icons.shield_rounded,
                          color: accent,
                          loading: _activating,
                          onPressed: _activate,
                        )
                      else
                        // Stays tappable: tapping it explains what is
                        // missing instead of leaving the user guessing.
                        AppButton.secondary(
                          label: s.selectAppsToActivate,
                          icon: Icons.apps_rounded,
                          loading: _activating,
                          onPressed: _activate,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Blocking now" / "not blocking right now", with the reason, for an
/// active profile.
class _BlockingStatus extends ConsumerWidget {
  const _BlockingStatus({required this.profile});

  final BlockerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(currentMinuteProvider);
    final limitReached = ref.watch(
      shieldStatusProvider.select(
        (statuses) => statuses[profile.id]?.limitReachedToday ?? false,
      ),
    );
    final blocking = profile.isBlockingAt(now, limitReachedToday: limitReached);
    final color = colors.readable(blocking ? profile.color : colors.success);
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            blocking ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: AppSizes.iconSm,
            color: color,
          ),
          Gap.hSm,
          Flexible(
            child: Text(
              profile.requirementReason(
                S.current,
                now,
                limitReachedToday: limitReached,
              ),
              textAlign: TextAlign.center,
              style: context.text.bodySmall.strong.tone(color),
            ),
          ),
        ],
      ),
    );
  }
}
