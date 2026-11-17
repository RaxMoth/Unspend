import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/content_width.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/presentation/profile_actions.dart';
import 'package:unspend/features/app_blocker/presentation/providers/authorization_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/device_mode_provider.dart';
import 'package:unspend/features/app_blocker/presentation/widgets/device_mode_options.dart';

/// First-run introduction. Three pages explain the app, the fourth asks
/// whose phone this is, and the last one asks for Screen Time access — for
/// the owner, or for a parent on a child's phone. Access can be postponed;
/// the dashboard keeps reminding.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 5;
  static const _permissionPage = _pageCount - 1;

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
        .setBool(kHasSeenOnboardingKey, true);
    if (mounted) context.go(AppRoutes.dashboard);
  }

  void _next() => _pageController.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  void _chooseMode(DeviceMode mode) {
    HapticFeedback.selectionClick();
    ref.read(deviceModeProvider.notifier).set(mode);
    // A refusal belonged to the previous choice.
    setState(() => _refusal = null);
  }

  Future<void> _requestAccess() async {
    setState(() => _requesting = true);
    final result = await ref.read(authorizationProvider.notifier).request();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _refusal = result.approved
          ? null
          : accessRefusedMessage(S.current, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final onPermissionPage = _page == _permissionPage;
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
        noteColor: approved ? kSuccessText : kTextSecondary,
      ),
    ];

    final String primaryLabel;
    final VoidCallback? primaryAction;
    if (!onPermissionPage) {
      primaryLabel = s.next;
      primaryAction = _next;
    } else if (approved) {
      primaryLabel = s.getStarted;
      primaryAction = _finish;
    } else {
      primaryLabel = s.authAllow;
      primaryAction = _requesting ? null : _requestAccess;
    }

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    onPermissionPage && !approved ? s.notNow : s.skip,
                    style: TextStyle(color: kTextSecondary, fontSize: 14),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? kAccent : kBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ContentGutter(
              minimum: 24,
              builder: (context, gutter) => Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: primaryAction,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final Color? noteColor;

  /// Controls shown below the text, such as a choice.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Less decoration when vertical space is tight or the page carries
        // controls of its own.
        final compact = constraints.maxHeight < 360 || footer != null;
        final iconBox = compact ? 64.0 : 100.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(iconBox * 0.28),
                      ),
                      child: Icon(icon, size: iconBox * 0.52, color: kAccent),
                    ),
                    SizedBox(height: compact ? 16 : 40),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        note!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: noteColor ?? kTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 24),
                      footer!,
                    ],
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
