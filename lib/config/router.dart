import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/features/app_blocker/presentation/pages/dashboard_screen.dart';
import 'package:unspend/features/app_blocker/presentation/pages/profile_detail_screen.dart';
import 'package:unspend/features/onboarding/presentation/pages/onboarding_screen.dart';

/// Route paths.
abstract final class AppRoutes {
  static const dashboard = '/';
  static const onboarding = '/onboarding';
  static String profile(String id) => '/profile/$id';
}

/// The app's router. Until onboarding is finished every route leads to it.
final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final seen = prefs.getBool(kHasSeenOnboardingKey) ?? false;
      final onOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!seen && !onOnboarding) return AppRoutes.onboarding;
      if (seen && onOnboarding) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        name: 'profileDetail',
        builder: (context, state) =>
            ProfileDetailPageShell(profileId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundPage(),
  );
});

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 56,
                  color: kTextSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  S.current.pageNotFound,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.dashboard),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(S.current.goHome),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
