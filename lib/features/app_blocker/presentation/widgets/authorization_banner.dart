import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../data/datasources/screen_time_datasource.dart';
import '../profile_actions.dart';
import '../providers/authorization_provider.dart';

/// Shown on the dashboard while Screen Time access is missing: nothing can
/// be blocked without it, so the user should not have to discover that by
/// a failing activation. Hidden once access is approved.
class AuthorizationBanner extends ConsumerWidget {
  const AuthorizationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authorizationProvider).valueOrNull;
    if (status == null || status == ScreenTimeAuthStatus.approved) {
      return const SizedBox.shrink();
    }
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final notifier = ref.read(authorizationProvider.notifier);

    Future<void> allow() async {
      final result = await notifier.request();
      if (result.approved || !context.mounted) return;
      showAppSnackBar(context, accessRefusedMessage(s, result));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        tint: colors.accent,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_person_rounded, color: colors.accent),
                Gap.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.authBannerTitle, style: text.label),
                      Gap.vXs,
                      Text(
                        s.authBannerBody,
                        style: text.bodySmall.tone(colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap.vXs,
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (status == ScreenTimeAuthStatus.denied)
                    TextButton(
                      onPressed: notifier.openSettings,
                      child: Text(s.openSettings),
                    ),
                  TextButton(onPressed: allow, child: Text(s.authAllow)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
