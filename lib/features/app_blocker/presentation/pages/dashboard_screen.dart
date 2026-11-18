import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';
import 'package:unspend/shared/providers/locale_provider.dart';

import '../providers/profiles_provider.dart';
import '../widgets/create_profile_sheet.dart';
import '../widgets/dashboard_body.dart';

/// Home screen: every profile at a glance and the button to add one.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _createProfile(BuildContext context, WidgetRef ref) async {
    AppHaptics.selection();
    final name = await showCreateProfileSheet(context);
    if (name == null) return;
    final id = await ref
        .read(profilesProvider.notifier)
        .createProfile(name: name);
    if (context.mounted) unawaited(context.push(AppRoutes.profile(id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: S.current.newProfile,
        onPressed: () =>
            runGuarded(context, () => _createProfile(context, ref)),
        child: const Icon(Icons.add_rounded, size: AppSizes.iconXl),
      ),
      body: SafeArea(
        child: profiles.when(
          data: (profiles) => DashboardBody(profiles: profiles),
          loading: () => const AppLoader(),
          error: (_, _) =>
              _LoadFailed(onRetry: () => ref.invalidate(profilesProvider)),
        ),
      ),
    );
  }
}

/// Shown when the profiles could not be read, with a way to try again.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.current.errorTryAgain,
              textAlign: TextAlign.center,
              style: context.text.body.tone(context.colors.textSecondary),
            ),
            Gap.vLg,
            TextButton(onPressed: onRetry, child: Text(S.current.retry)),
          ],
        ),
      ),
    );
  }
}
