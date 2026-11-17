import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';

import '../support/app_harness.dart';

/// Apple's and Flutter's accessibility guidelines on every main screen, in
/// both themes: tap targets of at least 44 × 44 points, a label on
/// everything tappable, and readable text contrast.
void main() {
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('onboarding', (tester) async {
        final app = await pumpUnspend(
          tester,
          brightness: brightness,
          onboardingSeen: false,
          auth: ScreenTimeAuthStatus.notDetermined,
        );
        await expectAccessible(tester);

        for (var page = 0; page < 3; page++) {
          await tester.tap(find.text(app.s.next));
          await tester.pumpAndSettle();
        }
        // "Who uses this iPhone?"
        await expectAccessible(tester);

        await tester.tap(find.text(app.s.next));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
      });

      testWidgets('dashboard', (tester) async {
        await pumpUnspend(
          tester,
          brightness: brightness,
          profiles: sampleProfiles(),
          auth: ScreenTimeAuthStatus.denied,
        );
        await expectAccessible(tester);
      });

      testWidgets('empty dashboard', (tester) async {
        await pumpUnspend(tester, brightness: brightness);
        await expectAccessible(tester);
      });

      testWidgets('new profile sheet', (tester) async {
        final app = await pumpUnspend(tester, brightness: brightness);
        await tester.tap(find.byTooltip(app.s.newProfile));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
      });

      testWidgets('settings', (tester) async {
        final app = await pumpUnspend(tester, brightness: brightness);
        await tester.tap(find.byTooltip(app.s.settings));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
      });

      testWidgets('profile screen with every rule on', (tester) async {
        final app = await pumpUnspend(
          tester,
          brightness: brightness,
          profiles: sampleProfiles(),
        );
        await app.open(AppRoutes.profile('games'));
        for (final title in [
          app.s.scheduleTitle,
          app.s.usageLimitTitle,
          app.s.taskModeTitle,
        ]) {
          await app.tap(find.bySemanticsLabel(RegExp('^$title')));
        }
        await expectAccessible(tester);
      });

      testWidgets('active profile screen', (tester) async {
        final app = await pumpUnspend(
          tester,
          brightness: brightness,
          profiles: sampleProfiles(),
        );
        await app.open(AppRoutes.profile('social'));
        await expectAccessible(tester);
      });

      testWidgets('unlock dialog', (tester) async {
        final app = await pumpUnspend(
          tester,
          brightness: brightness,
          profiles: sampleProfiles(),
          pin: '2468',
        );
        await tester.tap(
          find.bySemanticsLabel(RegExp('^${app.s.deactivateShield}')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await expectAccessible(tester);

        await app.elapse(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
      });

      testWidgets('PIN setup dialog', (tester) async {
        final app = await pumpUnspend(tester, brightness: brightness);
        await tester.tap(find.byTooltip(app.s.settings));
        await tester.pumpAndSettle();
        await app.tap(find.text(app.s.changePin));
        await expectAccessible(tester);
      });
    });
  }
}
