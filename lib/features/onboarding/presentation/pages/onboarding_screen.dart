import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/presentation/profile_actions.dart';
import 'package:unspend/features/app_blocker/presentation/providers/authorization_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/device_mode_provider.dart';
import 'package:unspend/features/app_blocker/presentation/widgets/device_mode_options.dart';

/// First-run introduction. Three pages explain the app, the fourth asks
/// whose phone this is (iPhone only), and the last one asks for the access
/// blocking needs — for the owner, or for a parent on a child's iPhone.
/// Access can be postponed; the dashboard keeps reminding.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _requesting = false;

  /// Why the last request was not granted; null until one was refused.
  String? _refusal;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.onboardingSeen, true);
    if (mounted) context.go(AppRoutes.dashboard);
  }

  void _next() {
    final duration = context.motion(AppDurations.slow);
    if (duration == Duration.zero) {
      // Reduce Motion: change the page without sliding.
      _pageController.jumpToPage(_page + 1);
    } else {
      _pageController.nextPage(duration: duration, curve: AppCurves.standard);
    }
  }

  void _chooseMode(DeviceMode mode) {
    AppHaptics.selection();
    ref.read(deviceModeProvider.notifier).set(mode);
    // A refusal belonged to the previous choice.
    setState(() => _refusal = null);
  }

  Future<void> _requestAccess() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final result = await requestAccess(context, ref);
      if (!mounted || result == null) return;
      setState(() {
        _refusal = result.approved
            ? null
            : accessRefusedMessage(S.current, result);
      });
      if (result.approved) AppHaptics.confirm();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = context.colors;
    final ios = ref.watch(appPlatformProvider) == AppPlatform.ios;
    final mode = ref.watch(deviceModeProvider);
    final approved =
        ref.watch(authorizationProvider).valueOrNull ==
        ScreenTimeAuthStatus.approved;

    final pages = [
      _OnboardingPage(
        icon: Icons.shield_rounded,
        title: s.onboardingTitle1,
        body: s.onboardingBody1,
      ),
      _OnboardingPage(
        icon: Icons.block_rounded,
        title: s.onboardingTitle2,
        body: s.onboardingBody2,
      ),
      _OnboardingPage(
        icon: Icons.check_circle_rounded,
        title: s.onboardingTitle3,
        body: s.onboardingBody3,
      ),
      // Only the iPhone knows a child's device; Android skips the question.
      if (ios)
        _OnboardingPage(
          icon: Icons.family_restroom_rounded,
          title: s.whoUsesTitle,
          body: s.whoUsesBody,
          footer: DeviceModeOptions(selected: mode, onSelected: _chooseMode),
        ),
      _OnboardingPage(
        icon: approved
            ? Icons.verified_user_rounded
            : Icons.lock_person_rounded,
        title: s.onboardingTitle4,
        body: mode == DeviceMode.child
            ? s.onboardingBody4Child
            : s.onboardingBody4,
        note: approved ? s.authGranted : _refusal,
        noteColor: approved ? colors.successText : colors.textSecondary,
      ),
    ];
    final onPermissionPage = _page == pages.length - 1;

    final String primaryLabel;
    final VoidCallback primaryAction;
    if (!onPermissionPage) {
      primaryLabel = s.next;
      primaryAction = _next;
    } else if (approved) {
      primaryLabel = s.getStarted;
      primaryAction = () => runGuarded(context, _finish);
    } else {
      primaryLabel = s.authAllow;
      primaryAction = () => runGuarded(context, _requestAccess);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  0,
                ),
                child: TextButton(
                  onPressed: () => runGuarded(context, _finish),
                  child: Text(
                    onPermissionPage && !approved ? s.notNow : s.skip,
                    style: context.text.body.tone(colors.textSecondary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: pages,
              ),
            ),
            ExcludeSemantics(
              child: _PageDots(count: pages.length, current: _page),
            ),
            Gap.vLg,
            ContentGutter(
              minimum: AppSpacing.xxl,
              builder: (context, gutter) => Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.lg),
                child: AppButton.primary(
                  label: primaryLabel,
                  // The iPhone's prompt appears over the button. On Android
                  // a dialog and then the system settings are in front, and
                  // a spinner behind them would say nothing.
                  loading: _requesting && ios,
                  onPressed: primaryAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows which page of the introduction is on screen.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  static const double _dot = AppSpacing.sm;
  static const double _currentWidth = AppSpacing.xl;

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: context.motion(AppDurations.medium),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == current ? _currentWidth : _dot,
            height: _dot,
            decoration: ShapeDecoration(
              color: i == current ? colors.accent : colors.border,
              shape: const StadiumBorder(),
            ),
          ),
      ],
    );
  }
}

/// One page of the introduction. Centred when there is room; scrolls when
/// there is not (landscape, large text).
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.note,
    this.noteColor,
    this.footer,
  });

  /// Below this height the illustration shrinks to leave room for text.
  static const double _compactHeight = 360;

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final Color? noteColor;

  /// Controls shown below the text, such as a choice.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Less decoration when vertical space is tight or the page carries
        // controls of its own.
        final compact =
            constraints.maxHeight < _compactHeight || footer != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.sm,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 2 * AppSpacing.sm,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.maxContentWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBadge(
                      icon: icon,
                      color: colors.accent,
                      size: compact
                          ? IconBadge.illustrationCompact
                          : IconBadge.illustration,
                    ),
                    compact ? Gap.vLg : Gap.vHuge,
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: text.hero,
                      ),
                    ),
                    Gap.vLg,
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge.relaxed.tone(colors.textSecondary),
                    ),
                    if (note != null) ...[
                      Gap.vLg,
                      Text(
                        note!,
                        textAlign: TextAlign.center,
                        style: text.bodySmall.strong.tone(
                          noteColor ?? colors.textSecondary,
                        ),
                      ),
                    ],
                    if (footer != null) ...[Gap.vXxl, footer!],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
