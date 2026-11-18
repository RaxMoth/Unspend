import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/app_sheet.dart';
import 'package:unspend/core/widgets/app_snackbar.dart';
import 'package:unspend/core/widgets/app_switch.dart';
import 'package:unspend/shared/providers/locale_provider.dart';
import 'package:unspend/shared/providers/theme_mode_provider.dart';

import '../../data/datasources/screen_time_datasource.dart';
import '../../data/repositories/pin_repository.dart';
import '../profile_actions.dart';
import '../providers/authorization_provider.dart';
import '../providers/device_mode_provider.dart';
import '../providers/profiles_provider.dart';
import '../providers/uninstall_protection_provider.dart';
import 'device_mode_options.dart';
import 'diagnostics_sheet.dart';
import 'pin_gate.dart';
import 'pin_setup_dialog.dart';

const _languages = [
  (code: 'en', name: 'English'),
  (code: 'de', name: 'Deutsch'),
  (code: 'es', name: 'Español'),
  (code: 'fr', name: 'Français'),
  (code: 'hr', name: 'Hrvatski'),
];

String _themeName(ThemeMode mode) => switch (mode) {
  ThemeMode.system => S.current.themeSystem,
  ThemeMode.light => S.current.themeLight,
  ThemeMode.dark => S.current.themeDark,
};

IconData _themeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_rounded,
  ThemeMode.light => Icons.light_mode_rounded,
  ThemeMode.dark => Icons.dark_mode_rounded,
};

/// Opens the settings sheet. [context] must outlive the sheet (the screen
/// behind it): the entries close the sheet and continue from there.
Future<void> showSettingsSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  title: S.current.settings,
  builder: (_) => _SettingsList(host: context),
);

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.host});

  /// Context of the screen that opened the sheet.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.current;
    final languageName = _languages
        .firstWhere(
          (l) => l.code == ref.watch(localeProvider),
          orElse: () => _languages.first,
        )
        .name;

    /// Closes the sheet, then runs [next] from the screen behind it.
    void then(void Function() next) {
      Navigator.of(context).pop();
      next();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsTile(
          icon: Icons.lock_rounded,
          title: s.changePin,
          subtitle: s.changePinSubtitle,
          onTap: () => then(() => _changePin(host)),
        ),
        _SettingsTile(
          icon: Icons.family_restroom_rounded,
          title: s.whoUsesLabel,
          subtitle: ref.watch(deviceModeProvider) == DeviceMode.child
              ? s.modeChildShort
              : s.modePersonalShort,
          showChevron: true,
          onTap: () => then(() => _showDeviceMode(host)),
        ),
        _SettingsTile(
          icon: Icons.gpp_good_outlined,
          title: s.uninstallProtection,
          subtitle: ref.watch(uninstallProtectionProvider)
              ? s.stateOn
              : s.stateOff,
          showChevron: true,
          onTap: () => then(() => _showUninstallProtection(host)),
        ),
        _SettingsTile(
          icon: Icons.brightness_6_rounded,
          title: s.themeLabel,
          subtitle: _themeName(ref.watch(themeModeProvider)),
          showChevron: true,
          onTap: () => then(() => _showThemePicker(host)),
        ),
        _SettingsTile(
          icon: Icons.language_rounded,
          title: s.languageLabel,
          subtitle: languageName,
          showChevron: true,
          onTap: () => then(() => _showLanguagePicker(host)),
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: s.privacyPolicyTitle,
          subtitle: s.privacyPolicySubtitle,
          showChevron: true,
          onTap: () => then(() => _showPrivacyPolicy(host)),
        ),
        if (kDebugMode)
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Diagnostics',
            subtitle: 'Screen Time state and event log (debug builds only)',
            showChevron: true,
            onTap: () => then(() => showDiagnosticsSheet(host)),
          ),
        _SettingsTile(
          icon: Icons.delete_forever_rounded,
          title: s.deleteAllData,
          subtitle: s.deleteAllDataSubtitle,
          destructive: true,
          onTap: () => then(() => _deleteAllData(host)),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: destructive ? kAccent : kTextSecondary),
        title: Text(
          title,
          style: TextStyle(color: destructive ? kAccentText : kTextPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: kTextSecondary, fontSize: 12),
        ),
        trailing: showChevron
            ? Icon(Icons.chevron_right_rounded, color: kTextSecondary)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: kBg,
        onTap: onTap,
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kAccent : kTextSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        selected: selected,
        leading: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          color: color,
        ),
        title: Text(label, style: TextStyle(color: kTextPrimary)),
        trailing: icon == null ? null : Icon(icon, color: color, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: kBg,
        selectedTileColor: kBg,
        onTap: onTap,
      ),
    );
  }
}

// ── Flows started from the sheet ─────────────────────────────────────────
//
// They run after the sheet has closed, so they use the provider container
// of the screen behind it rather than a WidgetRef of the (gone) sheet.

bool _anyProfileActive(ProviderContainer container) =>
    (container.read(profilesProvider).valueOrNull ?? const []).any(
      (profile) => profile.isActive,
    );

/// Changing the PIN requires the current one. While a profile is blocking
/// it also takes the cooldown: otherwise swapping the PIN would be the fast
/// way out.
Future<void> _changePin(BuildContext host) async {
  final container = ProviderScope.containerOf(host, listen: false);
  if (await container.read(pinRepositoryProvider).hasPin()) {
    if (!host.mounted) return;
    final passed = await showPinGate(
      host,
      purpose: PinGatePurpose.changePin,
      withCooldown: _anyProfileActive(container),
    );
    if (!passed) return;
  }
  if (!host.mounted) return;
  final saved = await showPinSetupDialog(host, cancelLabel: S.current.cancel);
  if (saved && host.mounted) showAppSnackBar(host, S.current.pinSaved);
}

/// Deleting everything also lifts every block, so while a profile is active
/// it goes through the same cooldown and PIN as deactivating.
Future<void> _deleteAllData(BuildContext host) async {
  final container = ProviderScope.containerOf(host, listen: false);
  final confirmed = await showDialog<bool>(
    context: host,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      backgroundColor: kSurface,
      title: Text(
        S.current.deleteAllData,
        style: TextStyle(color: kAccentText, fontSize: 18),
      ),
      content: Text(
        S.current.deleteAllDataWarning,
        style: TextStyle(color: kTextSecondary, fontSize: 13),
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
          child: Text(
            S.current.deleteAllDataConfirm,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !host.mounted) return;

  if (_anyProfileActive(container)) {
    final passed = await showPinGate(
      host,
      purpose: PinGatePurpose.deleteAllData,
      withCooldown: true,
    );
    if (!passed) return;
  }

  await container.read(profilesProvider.notifier).deleteAllData();
  container.invalidate(themeModeProvider);
  // Preferences are gone, so the router sends this back to onboarding.
  if (host.mounted) host.go(AppRoutes.dashboard);
}

void _showDeviceMode(BuildContext host) {
  showAppSheet<void>(
    context: host,
    title: S.current.whoUsesLabel,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(deviceModeProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.current.whoUsesChangeInfo,
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            DeviceModeOptions(
              selected: current,
              onSelected: (chosen) {
                if (chosen == current) return;
                Navigator.of(sheetContext).pop();
                _changeDeviceMode(host, chosen);
              },
            ),
          ],
        );
      },
    ),
  );
}

/// "My phone" and "my child's phone" use different kinds of Screen Time
/// access, so switching gives the current access back and asks again. iOS
/// lifts every block when access goes away, which is why nothing may be
/// active, and why a PIN — if set — is asked for first.
Future<void> _changeDeviceMode(BuildContext host, DeviceMode mode) async {
  final container = ProviderScope.containerOf(host, listen: false);
  if (_anyProfileActive(container)) {
    showAppSnackBar(host, S.current.deactivateAllFirst);
    return;
  }
  if (await container.read(pinRepositoryProvider).hasPin()) {
    if (!host.mounted) return;
    final passed = await showPinGate(
      host,
      purpose: PinGatePurpose.changeDeviceMode,
      withCooldown: false,
    );
    if (!passed) return;
  }
  final AccessRequestResult result;
  try {
    result = await container
        .read(authorizationProvider.notifier)
        .changeDeviceMode(mode);
  } on ScreenTimeException catch (e) {
    if (host.mounted) {
      showAppSnackBar(host, screenTimeErrorMessage(S.current, e));
    }
    return;
  }
  if (!host.mounted) return;
  showAppSnackBar(
    host,
    result.approved
        ? S.current.authGranted
        : accessRefusedMessage(S.current, result),
  );
}

void _showUninstallProtection(BuildContext host) {
  showAppSheet<void>(
    context: host,
    title: S.current.uninstallProtection,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final enabled = ref.watch(uninstallProtectionProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.current.uninstallProtectionBody,
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        enabled ? S.current.stateOn : S.current.stateOff,
                        style: TextStyle(color: kTextPrimary, fontSize: 16),
                      ),
                    ),
                  ),
                  AppSwitch(
                    value: enabled,
                    semanticLabel: S.current.uninstallProtection,
                    onChanged: (on) => _setUninstallProtection(context, on),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Switching the protection on is always allowed. Switching it off weakens
/// a block, so it takes the PIN if one is set and, while a profile is
/// active, the cooldown as well.
Future<void> _setUninstallProtection(BuildContext context, bool enable) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!enable) {
    final anyActive = _anyProfileActive(container);
    if (anyActive || await container.read(pinRepositoryProvider).hasPin()) {
      if (!context.mounted) return;
      final passed = await showPinGate(
        context,
        purpose: PinGatePurpose.uninstallProtection,
        withCooldown: anyActive,
      );
      if (!passed) return;
    }
  }
  final changed = await container
      .read(uninstallProtectionProvider.notifier)
      .set(enable);
  if (!changed && context.mounted) {
    showAppSnackBar(context, S.current.errorTryAgain);
  }
}

void _showThemePicker(BuildContext host) {
  showAppSheet<void>(
    context: host,
    title: S.current.themeLabel,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(themeModeProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              _ChoiceTile(
                label: _themeName(mode),
                icon: _themeIcon(mode),
                selected: mode == current,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        );
      },
    ),
  );
}

void _showLanguagePicker(BuildContext host) {
  showAppSheet<void>(
    context: host,
    title: S.current.languageLabel,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(localeProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in _languages)
              _ChoiceTile(
                label: language.name,
                selected: language.code == current,
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(language.code);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        );
      },
    ),
  );
}

void _showPrivacyPolicy(BuildContext host) {
  showAppSheet<void>(
    context: host,
    title: S.current.privacyPolicyTitle,
    builder: (_) => Text(
      S.current.privacyPolicyBody,
      style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.6),
    ),
  );
}
