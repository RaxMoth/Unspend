import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/content_width.dart';
import 'package:unspend/shared/providers/locale_provider.dart';

import '../../domain/entities/blocker_profile.dart';
import '../profile_actions.dart';
import '../profile_formatters.dart';
import '../providers/current_minute_provider.dart';
import '../providers/profiles_provider.dart';
import '../widgets/app_selection_card.dart';
import '../widgets/appearance_pickers.dart';
import '../widgets/rule_toggle_card.dart';
import '../widgets/schedule_card.dart';
import '../widgets/section_widgets.dart';
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
    final placeholder = Scaffold(backgroundColor: kBg);
    return profile.when(
      loading: () => Scaffold(
        backgroundColor: kBg,
        body: const Center(child: CircularProgressIndicator(color: kAccent)),
      ),
      error: (_, _) {
        _leave();
        return placeholder;
      },
      data: (profile) {
        if (profile == null) {
          _leave();
          return placeholder;
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
      hour: profile.scheduleStartHour ?? 9,
      minute: profile.scheduleStartMinute ?? 0,
    );
    _endTime = TimeOfDay(
      hour: profile.scheduleEndHour ?? 17,
      minute: profile.scheduleEndMinute ?? 0,
    );
    _usageLimitMinutes = profile.usageLimitMinutes ?? 30;
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
    _pendingSave = Timer(const Duration(milliseconds: 500), _save);
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
    setState(() => _activating = true);
    // The rules on screen are the rules that get enforced.
    await _save();
    if (mounted) await activateWithFeedback(context, ref, widget.profile);
    if (mounted) setState(() => _activating = false);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: kSurface,
        title: Text(
          S.current.deleteProfile,
          style: TextStyle(color: kTextPrimary, fontSize: 18),
        ),
        content: Text(
          S.current.deleteProfileConfirm(widget.profile.name),
          style: TextStyle(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              S.current.cancel,
              style: TextStyle(color: kTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _pendingSave?.cancel();
    // The page shell leaves the route once the profile is gone.
    await _notifier.deleteProfile(widget.profile.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final s = S.current;
    final profile = widget.profile;
    final accent = Color(_colorValue);
    final locked = profile.isActive;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: Icon(Icons.arrow_back_rounded, color: kTextPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (!locked)
                    IconButton(
                      tooltip: s.deleteProfile,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: kTextSecondary,
                      ),
                      onPressed: _confirmDelete,
                    ),
                ],
              ),
            ),
            Expanded(
              child: ContentGutter(
                builder: (context, gutter) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Name ───────────────────────────────────────────
                      Center(
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              ProfileIcon.fromLabel(_iconLabel).icon,
                              size: 40,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        maxLength: 40,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          hintText: s.profileNamePlaceholder,
                          hintStyle: TextStyle(color: kTextSecondary),
                        ),
                        onChanged: (_) => _saveSoon(),
                        onSubmitted: (_) => _save(),
                      ),
                      if (locked) ...[
                        _BlockingStatus(profile: profile),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),

                      // ── Appearance ─────────────────────────────────────
                      SectionLabel(s.sectionColor),
                      const SizedBox(height: 4),
                      ProfileColorPicker(
                        selectedValue: _colorValue,
                        onSelected: (value) =>
                            _change(() => _colorValue = value),
                      ),
                      const SizedBox(height: 16),
                      SectionLabel(s.sectionIcon),
                      const SizedBox(height: 6),
                      ProfileIconPicker(
                        selectedLabel: _iconLabel,
                        accent: accent,
                        onSelected: (label) =>
                            _change(() => _iconLabel = label),
                      ),
                      const SizedBox(height: 24),

                      // ── Apps ───────────────────────────────────────────
                      SectionLabel(s.sectionApps),
                      const SizedBox(height: 8),
                      LockedSection(
                        locked: locked,
                        child: AppSelectionCard(
                          profile: profile,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            pickAppsWithFeedback(context, ref, profile);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Rules ──────────────────────────────────────────
                      SectionLabel(s.sectionBlockRules),
                      const SizedBox(height: 4),
                      Text(
                        locked
                            ? s.settingsLockedWhileActive
                            : s.blockRulesDescription,
                        style: TextStyle(
                          color: locked ? kAccentText : kTextSecondary,
                          fontSize: 12,
                          fontStyle: locked
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 12),

                      RuleToggleCard(
                        icon: Icons.calendar_today_rounded,
                        title: s.scheduleTitle,
                        description: s.scheduleDescription,
                        enabled: _scheduleEnabled,
                        accent: accent,
                        locked: locked,
                        onToggle: (on) => _change(() => _scheduleEnabled = on),
                      ),
                      if (_scheduleEnabled) ...[
                        const SizedBox(height: 8),
                        LockedSection(
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
                      ],
                      const SizedBox(height: 12),

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
                      if (_usageLimitEnabled) ...[
                        const SizedBox(height: 8),
                        LockedSection(
                          locked: locked,
                          child: UsageLimitCard(
                            minutes: _usageLimitMinutes,
                            accent: accent,
                            onTap: () => _pickUsageLimit(accent),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      RuleToggleCard(
                        icon: Icons.checklist_rounded,
                        title: s.taskModeTitle,
                        description: s.taskModeDescription,
                        enabled: _taskModeEnabled,
                        accent: accent,
                        locked: locked,
                        onToggle: (on) => _change(() => _taskModeEnabled = on),
                      ),
                      if (_taskModeEnabled) ...[
                        const SizedBox(height: 8),
                        TaskListSection(profile: profile, accent: accent),
                      ],
                      const SizedBox(height: 24),

                      // ── Activate / deactivate ──────────────────────────
                      if (locked)
                        FullWidthButton(
                          label: s.deactivateShield,
                          icon: Icons.shield_outlined,
                          color: kTextSecondary,
                          bgColor: kSurface,
                          borderColor: kBorder,
                          onPressed: () =>
                              deactivateWithGate(context, ref, profile.id),
                        )
                      else
                        _ActivateButton(
                          accent: accent,
                          hasApps: profile.hasAppsSelected,
                          busy: _activating,
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
    final now = ref.watch(currentMinuteProvider);
    final limitReached = ref.watch(
      shieldStatusProvider.select(
        (statuses) => statuses[profile.id]?.limitReachedToday ?? false,
      ),
    );
    final blocking = profile.isBlockingAt(now, limitReachedToday: limitReached);
    final color = kReadable(blocking ? profile.color : kSuccess);
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            blocking ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              profile.requirementReason(
                S.current,
                now,
                limitReachedToday: limitReached,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivateButton extends StatelessWidget {
  const _ActivateButton({
    required this.accent,
    required this.hasApps,
    required this.busy,
    required this.onPressed,
  });

  final Color accent;
  final bool hasApps;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Without apps the button stays tappable: tapping it explains what is
    // missing instead of leaving the user guessing.
    final filled = kFilled(accent);
    return FullWidthButton(
      label: hasApps
          ? S.current.activateShield
          : S.current.selectAppsToActivate,
      icon: hasApps ? Icons.shield_rounded : Icons.apps_rounded,
      color: hasApps ? filled.onFill : kTextSecondary,
      bgColor: hasApps ? filled.fill : kSurface,
      borderColor: hasApps ? null : kBorder,
      onPressed: busy ? null : onPressed,
    );
  }
}
