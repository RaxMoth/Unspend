import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../data/datasources/screen_time_datasource.dart';
import '../data/repositories/pin_repository.dart';
import '../domain/entities/blocker_profile.dart';
import 'native_strings.dart';
import 'providers/authorization_provider.dart';
import 'providers/profiles_provider.dart';
import 'widgets/pin_gate.dart';
import 'widgets/pin_setup_dialog.dart';

/// The actions on a profile that need a conversation with the user: a
/// dialog first, a message when something goes wrong. Shared by the
/// dashboard and the profile screen so both behave the same.
///
/// None of them throws: a refusal by Screen Time is explained in the user's
/// language, anything unexpected ends in a plain "please try again".

/// What to tell the user when the OS refuses an action. Never a code.
String screenTimeErrorMessage(S s, ScreenTimeException exception) =>
    switch (exception.error) {
      ScreenTimeError.notAuthorized => s.errorNotAuthorized,
      ScreenTimeError.noSelection => s.noAppsWarning,
      ScreenTimeError.tooManyApps => s.pickerTooManyApps,
      ScreenTimeError.scheduleTooShort => s.errorScheduleTooShort,
      ScreenTimeError.tooManyActivities => s.errorTooManyActivities,
      ScreenTimeError.taskModeNeedsTasks => s.noTasksWarning,
      ScreenTimeError.profileActive => s.settingsLockedWhileActive,
      ScreenTimeError.unavailable => s.errorUnavailable,
      ScreenTimeError.notChildAccount => s.authNotChildAccount,
      ScreenTimeError.authorizationConflict => s.authConflict,
      ScreenTimeError.network => s.authNetwork,
      ScreenTimeError.unknown => s.errorTryAgain,
    };

/// What to tell the user when Screen Time access was not granted.
String accessRefusedMessage(S s, AccessRequestResult result) =>
    switch (result.error) {
      ScreenTimeError.notChildAccount => s.authNotChildAccount,
      ScreenTimeError.authorizationConflict => s.authConflict,
      ScreenTimeError.network => s.authNetwork,
      _ => s.authDeniedHint,
    };

void _showError(
  BuildContext context,
  WidgetRef ref,
  ScreenTimeException exception,
) {
  AppHaptics.reject();
  final authorization = ref.read(authorizationProvider.notifier);
  final notAuthorized = exception.error == ScreenTimeError.notAuthorized;
  // Access may have been withdrawn in Settings since the last check.
  if (notAuthorized) authorization.refresh();
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    screenTimeErrorMessage(S.current, exception),
    action: notAuthorized
        ? SnackBarAction(
            label: S.current.openSettings,
            onPressed: authorization.openSettings,
          )
        : null,
  );
}

/// Activates [profile], telling the user why if that is not possible.
Future<void> activateWithFeedback(
  BuildContext context,
  WidgetRef ref,
  BlockerProfile profile,
) => runGuarded(context, () async {
  try {
    await ref.read(profilesProvider.notifier).activateProfile(profile.id);
    AppHaptics.confirm();
  } on ScreenTimeException catch (e) {
    if (context.mounted) _showError(context, ref, e);
  }
});

/// Deactivates a profile after the cooldown and the PIN.
Future<void> deactivateWithGate(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) => runGuarded(context, () async {
  final passed = await showPinGate(
    context,
    purpose: PinGatePurpose.deactivate,
    withCooldown: true,
  );
  if (!passed) return;
  try {
    await ref.read(profilesProvider.notifier).deactivateProfile(profileId);
    AppHaptics.confirm();
  } on ScreenTimeException {
    AppHaptics.reject();
    if (context.mounted) {
      showAppSnackBar(context, S.current.deactivationFailed);
    }
  }
});

/// Opens the app picker for [profile]. The first time apps are chosen the
/// user is invited to have a PIN set.
Future<void> pickAppsWithFeedback(
  BuildContext context,
  WidgetRef ref,
  BlockerProfile profile,
) => runGuarded(context, () async {
  final bool changed;
  try {
    changed = await ref
        .read(profilesProvider.notifier)
        .pickAppsForProfile(profile.id, labels: appPickerLabels(S.current));
  } on ScreenTimeException catch (e) {
    if (context.mounted) _showError(context, ref, e);
    return;
  }
  if (!changed || !context.mounted) return;
  if (await ref.read(pinRepositoryProvider).hasPin()) return;
  if (!context.mounted) return;
  await showPinSetupDialog(context, cancelLabel: S.current.notNow);
});
