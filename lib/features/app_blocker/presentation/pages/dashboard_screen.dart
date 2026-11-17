import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/shared/providers/locale_provider.dart';

import '../providers/profiles_provider.dart';
import '../widgets/create_profile_sheet.dart';
import '../widgets/dashboard_body.dart';

/// Home screen: every profile at a glance and the button to add one.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _createProfile(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final name = await showCreateProfileSheet(context);
    if (name == null) return;
    final id = await ref
        .read(profilesProvider.notifier)
        .createProfile(name: name);
    if (context.mounted) context.push(AppRoutes.profile(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccentFill,
        foregroundColor: Colors.white,
        tooltip: S.current.newProfile,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _createProfile(context, ref),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: profiles.when(
          data: (profiles) => DashboardBody(profiles: profiles),
          loading: () =>
              const Center(child: CircularProgressIndicator(color: kAccent)),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                S.current.errorTryAgain,
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
