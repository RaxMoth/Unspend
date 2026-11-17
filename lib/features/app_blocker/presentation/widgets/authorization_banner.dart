import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/app_snackbar.dart';

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
    final notifier = ref.read(authorizationProvider.notifier);
    final denied = status == ScreenTimeAuthStatus.denied;

    Future<void> allow() async {
      final result = await notifier.request();
      if (result.approved || !context.mounted) return;
      showAppSnackBar(context, accessRefusedMessage(S.current, result));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kAccent.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_person_rounded, color: kAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.current.authBannerTitle,
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.current.authBannerBody,
                        style: TextStyle(color: kTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (denied)
                    TextButton(
                      onPressed: notifier.openSettings,
                      child: Text(S.current.openSettings),
                    ),
                  TextButton(
                    onPressed: allow,
                    child: Text(
                      S.current.authAllow,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
