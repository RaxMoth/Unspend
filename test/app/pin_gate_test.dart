import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/features/app_blocker/data/repositories/pin_repository.dart';

import '../support/app_harness.dart';

/// The cooldown-and-PIN gate, exercised through deactivating a profile.
void main() {
  const social = 'Social media and endless scrolling';

  Future<AppHarness> start(WidgetTester tester, {String? pin}) =>
      pumpUnspend(tester, profiles: sampleProfiles(), pin: pin);

  /// Opens the gate and waits out the 3-second test cooldown.
  Future<void> openGate(WidgetTester tester, AppHarness app) async {
    await tester.tap(
      find.bySemanticsLabel('${app.s.deactivateShield}, $social'),
    );
    await tester.pump();
    await app.elapse(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Future<void> submitPin(
    WidgetTester tester,
    AppHarness app,
    String pin,
  ) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.tap(find.widgetWithText(TextButton, app.s.deactivateAction));
    await tester.pumpAndSettle();
  }

  testWidgets('no PIN field is shown before the cooldown has passed', (
    tester,
  ) async {
    final app = await start(tester, pin: '2468');

    await tester.tap(
      find.bySemanticsLabel('${app.s.deactivateShield}, $social'),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(
      find.widgetWithText(TextButton, app.s.deactivateAction),
      findsNothing,
    );
    expect(find.text(app.s.cooldownDescription), findsOneWidget);
  });

  testWidgets('the right PIN deactivates', (tester) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);
    expect(find.text(app.s.enterPinToDeactivate), findsOneWidget);

    await submitPin(tester, app, '2468');

    expect(app.profile('social').isActive, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a wrong PIN is refused and the block stays', (tester) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);

    await submitPin(tester, app, '1111');

    expect(find.text(app.s.incorrectPin), findsOneWidget);
    expect(app.profile('social').isActive, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
      reason: 'the wrong PIN is cleared for the next try',
    );
  });

  testWidgets('an empty PIN asks for one without counting as an attempt', (
    tester,
  ) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);

    await submitPin(tester, app, '  ');

    expect(find.text(app.s.enterYourPin), findsOneWidget);
    for (var i = 0; i < PinRepository.attemptsPerLockout - 1; i++) {
      await submitPin(tester, app, '0000');
    }
    expect(find.text(app.s.incorrectPin), findsOneWidget, reason: 'not locked');
  });

  testWidgets('five wrong PINs lock the gate, even with the right PIN after', (
    tester,
  ) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);

    for (var i = 0; i < PinRepository.attemptsPerLockout; i++) {
      await submitPin(tester, app, '0000');
    }
    expect(find.text(app.s.pinLockedOut(30)), findsOneWidget);

    await submitPin(tester, app, '2468');
    expect(app.profile('social').isActive, isTrue);
    expect(find.textContaining(RegExp(r'\d+')), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('closing and reopening the gate does not reset the lockout', (
    tester,
  ) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);
    for (var i = 0; i < PinRepository.attemptsPerLockout; i++) {
      await submitPin(tester, app, '0000');
    }
    await tester.tap(find.text(app.s.cancel));
    await tester.pumpAndSettle();

    await openGate(tester, app);
    expect(
      find.text(app.s.pinLockedOut(27)),
      findsOneWidget,
      reason: 'three seconds of the lockout passed during the cooldown',
    );
    await submitPin(tester, app, '2468');
    expect(app.profile('social').isActive, isTrue);

    app.now = app.now.add(const Duration(seconds: 31));
    await submitPin(tester, app, '2468');
    expect(app.profile('social').isActive, isFalse);
  });

  testWidgets('the PIN can be shown while typing', (tester) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);
    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().obscureText, isTrue);

    await tester.tap(find.byTooltip(app.s.showPin));
    await tester.pump();

    expect(field().obscureText, isFalse);
    expect(find.byTooltip(app.s.hidePin), findsOneWidget);
  });

  testWidgets('submitting from the keyboard checks the PIN', (tester) async {
    final app = await start(tester, pin: '2468');
    await openGate(tester, app);

    await tester.enterText(find.byType(TextField), '2468');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(app.profile('social').isActive, isFalse);
  });
}
