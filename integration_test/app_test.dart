import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/app.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/widgets/app_switch.dart';
import 'package:unspend/features/app_blocker/data/datasources/fake_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/method_channel_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';

/// The whole app on a simulator or device, from first launch to lifting a
/// block again:
///
///     flutter test integration_test -d <simulator>
///
/// Screen Time itself is replaced by the in-memory fake (Family Controls
/// does not work in the Simulator), and storage is in memory so the run
/// leaves nothing behind. Everything else is the real app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch to an unlocked block', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await S.setLocale('en');
    final s = S.current;
    final screenTime = FakeScreenTimeDatasource(
      authStatus: ScreenTimeAuthStatus.notDetermined,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          screenTimeDatasourceProvider.overrideWithValue(screenTime),
          cooldownDurationProvider.overrideWithValue(
            const Duration(seconds: 2),
          ),
        ],
        child: const UnspendApp(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    // ── Onboarding, ending with the Screen Time permission ──────────────
    expect(find.text(s.onboardingTitle1), findsOneWidget);
    for (var page = 0; page < 3; page++) {
      await tap(find.text(s.next));
    }
    expect(find.text(s.whoUsesTitle), findsOneWidget);
    await tap(find.text(s.next));
    await tap(find.text(s.authAllow));
    expect(find.text(s.authGranted), findsOneWidget);
    await tap(find.text(s.getStarted));
    expect(find.text(s.noProfilesYet), findsOneWidget);

    // ── Create a profile ────────────────────────────────────────────────
    await tap(find.byTooltip(s.newProfile));
    await tester.enterText(find.byType(TextField), 'Evening');
    await tap(find.text(s.create));
    expect(find.text(s.sectionBlockRules), findsOneWidget);

    // ── Pick apps; the app suggests a PIN ───────────────────────────────
    await tap(find.text(s.selectAppsToBlock));
    expect(find.text(s.setPinTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '2468');
    await tester.enterText(find.byType(TextField).at(2), '2468');
    await tap(find.text(s.savePin));
    expect(find.text(s.appsSelected(3)), findsOneWidget);

    // ── Activate ────────────────────────────────────────────────────────
    await tap(find.text(s.activateShield));
    expect(find.text(s.deactivateShield), findsOneWidget);
    expect(screenTime.isShielded(screenTime.active.keys.single), isTrue);

    await tap(find.byIcon(Icons.arrow_back_rounded));
    expect(find.text(s.allShieldsActive), findsOneWidget);

    // ── Deactivate: cooldown, wrong PIN, right PIN ──────────────────────
    await tester.tap(find.byType(AppSwitch));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(s.cooldownDescription), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(s.enterPinToDeactivate), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0000');
    await tap(find.widgetWithText(TextButton, s.deactivateAction));
    expect(find.text(s.incorrectPin), findsOneWidget);
    expect(screenTime.active, isNotEmpty);

    await tester.enterText(find.byType(TextField), '2468');
    await tap(find.widgetWithText(TextButton, s.deactivateAction));
    expect(find.text(s.shieldsInactive), findsOneWidget);
    expect(screenTime.active, isEmpty);
  });
}
