import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/features/app_blocker/data/repositories/pin_repository.dart';
import 'package:unspend/features/app_blocker/data/repositories/profiles_repository.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

import '../support/app_harness.dart';

/// Things that must not break the app: taps arriving twice, storage that
/// fails, errors nobody planned for.
void main() {
  const social = 'Social media and endless scrolling';

  group('taps arriving twice', () {
    testWidgets('two taps on the switch open one unlock dialog', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      final toggle = find.bySemanticsLabel(
        '${app.s.deactivateShield}, $social',
      );

      await tester.tap(toggle);
      await tester.tap(toggle, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('two taps on the add button open one sheet', (tester) async {
      final app = await pumpUnspend(tester);
      final add = find.byTooltip(app.s.newProfile);

      await tester.tap(add);
      await tester.tap(add, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text(app.s.createProfileDescription), findsOneWidget);
    });

    testWidgets('two taps on Activate send one request', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await app.open(AppRoutes.profile('games'));
      final activate = find.text(app.s.activateShield);
      await tester.ensureVisible(activate);
      await tester.pumpAndSettle();

      await tester.tap(activate);
      await tester.tap(activate, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        app.screenTime.calls.where((c) => c == 'activate:games'),
        hasLength(1),
      );
      expect(app.profile('games').isActive, isTrue);
    });
  });

  group('errors nobody planned for', () {
    testWidgets('a crash while activating becomes a plain message', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await app.open(AppRoutes.profile('games'));
      app.screenTime.crashNext = 'kaboom';

      await app.tap(find.text(app.s.activateShield));

      expect(find.text(app.s.errorTryAgain), findsOneWidget);
      expect(find.textContaining('kaboom'), findsNothing);
      expect(app.profile('games').isActive, isFalse);
      expect(tester.takeException(), isNull);

      // The button is usable again, and the next attempt works (once the
      // message that covers it has gone).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await app.tap(find.text(app.s.activateShield));
      expect(app.profile('games').isActive, isTrue);
    });

    testWidgets('a crash while picking apps becomes a plain message', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await app.open(AppRoutes.profile('news'));
      app.screenTime.crashNext = StateError('picker gone');

      await app.tap(find.text(app.s.selectAppsToBlock));

      expect(find.text(app.s.errorTryAgain), findsOneWidget);
      expect(app.profile('news').hasAppsSelected, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a crash during sync leaves the app as it was', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      app.screenTime.crashNext = StateError('daemon gone');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(app.profile('social').isActive, isTrue);
      expect(find.text('Games'), findsOneWidget);
    });
  });

  group('a Keychain that cannot be read', () {
    testWidgets('the unlock dialog says so and never lets the user through', (
      tester,
    ) async {
      final pins = _FlakyPins();
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        overrides: [pinRepositoryProvider.overrideWithValue(pins)],
      );
      pins.broken = true;

      await tester.tap(
        find.bySemanticsLabel('${app.s.deactivateShield}, $social'),
      );
      await tester.pump();
      await app.elapse(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text(app.s.errorTryAgain), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.widgetWithText(TextButton, app.s.deactivateAction),
        findsNothing,
        reason: 'an unreadable PIN must not count as "no PIN"',
      );
      expect(app.profile('social').isActive, isTrue);

      // Once the Keychain answers again, Retry carries on.
      pins.broken = false;
      await tester.tap(find.text(app.s.retry));
      await tester.pumpAndSettle();
      expect(find.text(app.s.enterTrustedPersonPin), findsOneWidget);
    });

    testWidgets('a failing check keeps the dialog open with a message', (
      tester,
    ) async {
      final pins = _FlakyPins();
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        overrides: [pinRepositoryProvider.overrideWithValue(pins)],
      );
      await tester.tap(
        find.bySemanticsLabel('${app.s.deactivateShield}, $social'),
      );
      await tester.pump();
      await app.elapse(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      pins.broken = true;

      await tester.enterText(find.byType(TextField), '2468');
      await tester.tap(find.widgetWithText(TextButton, app.s.deactivateAction));
      await tester.pumpAndSettle();

      expect(find.text(app.s.errorTryAgain), findsOneWidget);
      expect(app.profile('social').isActive, isTrue);
    });

    testWidgets('Change PIN reports the failure instead of doing nothing', (
      tester,
    ) async {
      final pins = _FlakyPins()..broken = true;
      final app = await pumpUnspend(
        tester,
        overrides: [pinRepositoryProvider.overrideWithValue(pins)],
      );

      await tester.tap(find.byTooltip(app.s.settings));
      await tester.pumpAndSettle();
      await app.tap(find.text(app.s.changePin));

      expect(find.text(app.s.errorTryAgain), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('profiles that cannot be loaded', () {
    testWidgets('the dashboard offers to try again', (tester) async {
      late _FlakyRepository repository;
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        overrides: [
          profilesRepositoryProvider.overrideWith(
            (ref) => repository = _FlakyRepository(
              ref.watch(sharedPreferencesProvider),
            ),
          ),
        ],
      );

      expect(find.text(app.s.errorTryAgain), findsOneWidget);
      expect(find.text('Games'), findsNothing);
      expect(repository.loads, 1);

      await tester.tap(find.text(app.s.retry));
      await tester.pumpAndSettle();

      expect(find.text('Games'), findsOneWidget);
      expect(find.text(app.s.errorTryAgain), findsNothing);
    });
  });
}

/// A PIN repository whose Keychain can be switched off. The PIN is 2468.
class _FlakyPins implements PinRepository {
  bool broken = false;

  void _touchKeychain() {
    if (broken) throw StateError('Keychain unavailable');
  }

  @override
  Future<bool> hasPin() async {
    _touchKeychain();
    return true;
  }

  @override
  Future<Duration?> lockoutRemaining() async {
    _touchKeychain();
    return null;
  }

  @override
  Future<PinCheck> verify(String pin) async {
    _touchKeychain();
    return pin == '2468' ? const PinCorrect() : const PinWrong();
  }

  @override
  Future<void> setPin(String pin) async => _touchKeychain();

  @override
  Future<void> clear() async => _touchKeychain();
}

/// Fails the first time profiles are loaded, as a damaged store would.
class _FlakyRepository extends ProfilesRepository {
  _FlakyRepository(super.prefs);

  int loads = 0;

  @override
  Future<List<BlockerProfile>> load() {
    if (loads++ == 0) throw StateError('store unreadable');
    return super.load();
  }
}
