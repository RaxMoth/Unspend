import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

/// The shared building blocks, on their own.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await S.setLocale('en');
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    double width = 375,
    bool reduceMotion = false,
  }) async {
    tester.view
      ..physicalSize = Size(width, 667)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.dark,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: app!,
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('AppButton', () {
    testWidgets('calls back when tapped', (tester) async {
      var taps = 0;
      await pump(
        tester,
        AppButton.primary(label: 'Save', onPressed: () => taps++),
      );

      await tester.tap(find.text('Save'));

      expect(taps, 1);
    });

    testWidgets('while loading it shows a spinner and ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        AppButton.primary(
          label: 'Save',
          icon: Icons.check,
          loading: true,
          onPressed: () => taps++,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      await tester.tap(find.text('Save'));
      expect(taps, 0);
    });

    testWidgets('without a callback it is disabled', (tester) async {
      await pump(
        tester,
        const AppButton.secondary(label: 'Later', onPressed: null),
      );

      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a long label wraps instead of overflowing', (tester) async {
      await pump(
        tester,
        AppButton.primary(
          label: 'Wähle zuerst Apps aus, um den Schild zu aktivieren',
          icon: Icons.apps,
          onPressed: () {},
        ),
        width: 280,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThan(AppSizes.tapTarget),
      );
    });

    testWidgets('a profile colour gets readable text', (tester) async {
      const amber = Color(0xFFFFC107);
      await pump(
        tester,
        AppButton.primary(label: 'Activate', color: amber, onPressed: () {}),
      );

      final label = tester.widget<Text>(find.text('Activate'));
      expect(
        contrastRatio(label.style!.color!, amber),
        greaterThanOrEqualTo(kTextContrastAA),
      );
    });
  });

  group('AppCard', () {
    testWidgets('is a button only when it has a tap handler', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppCard(child: Text('Plain')),
            AppCard(onTap: () => taps++, child: const Text('Tappable')),
          ],
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('Tappable'));
      expect(taps, 1);
    });
  });

  group('AppChip', () {
    testWidgets('keeps a pale colour readable', (tester) async {
      const amber = Color(0xFFFFC107);
      await pump(
        tester,
        const AppChip(label: 'Schedule', color: amber),
        theme: AppTheme.light,
      );

      final label = tester.widget<Text>(find.text('Schedule'));
      expect(
        contrastRatio(label.style!.color!, AppColors.light.surface),
        greaterThanOrEqualTo(kTextContrastAA),
      );
    });
  });

  group('AppSwitch', () {
    testWidgets('reports the opposite value when tapped', (tester) async {
      bool? reported;
      await pump(
        tester,
        AppSwitch(
          value: false,
          semanticLabel: 'Uninstall protection',
          onChanged: (value) => reported = value,
        ),
      );

      await tester.tap(find.byType(AppSwitch));

      expect(reported, isTrue);
      expect(
        tester.getSize(find.byType(AppSwitch)).height,
        greaterThanOrEqualTo(AppSizes.tapTarget),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Uninstall protection')),
        matchesSemantics(
          label: 'Uninstall protection',
          hasToggledState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('does nothing when disabled', (tester) async {
      await pump(tester, const AppSwitch(value: true, onChanged: null));

      await tester.tap(find.byType(AppSwitch));

      expect(tester.takeException(), isNull);
    });
  });

  group('Reveal', () {
    testWidgets('hidden content is not built', (tester) async {
      await pump(tester, const Reveal(visible: false, child: Text('Details')));

      expect(find.text('Details'), findsNothing);
    });

    testWidgets('content slides in, or appears at once with Reduce Motion', (
      tester,
    ) async {
      Future<double> heightAfterFirstFrame({required bool reduceMotion}) async {
        const content = SizedBox(height: 100, child: Text('Details'));
        await pump(
          tester,
          const Reveal(visible: false, child: content),
          reduceMotion: reduceMotion,
        );
        await pump(
          tester,
          const Reveal(visible: true, child: content),
          reduceMotion: reduceMotion,
        );
        await tester.pump(const Duration(milliseconds: 16));
        final height = tester.getSize(find.byType(Reveal)).height;
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(Reveal)).height, 100);
        return height;
      }

      expect(await heightAfterFirstFrame(reduceMotion: false), lessThan(100));
      expect(await heightAfterFirstFrame(reduceMotion: true), 100);
    });
  });

  group('dialogs and sheets', () {
    testWidgets('a confirmation answers true or false', (tester) async {
      late BuildContext context;
      await pump(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      Future<bool> ask() => showConfirmDialog(
        context,
        title: 'Delete profile',
        message: 'Really?',
        confirmLabel: 'Delete',
        destructive: true,
      );

      var answer = ask();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);

      answer = ask();
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.cancel));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('a second request while one is open is ignored', (
      tester,
    ) async {
      late BuildContext context;
      await pump(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      Future<void> open() => showAppSheet<void>(
        context: context,
        title: 'Settings',
        builder: (_) => const Text('Content'),
      );

      final first = open();
      final second = open();
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      await second; // returned at once with nothing
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await first;
      expect(find.text('Settings'), findsNothing);
    });
  });

  group('runGuarded', () {
    testWidgets('an unexpected failure becomes a plain message', (
      tester,
    ) async {
      late BuildContext context;
      await pump(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );

      await runGuarded(context, () async => throw StateError('disk full'));
      await tester.pump();

      expect(find.text(S.current.errorTryAgain), findsOneWidget);
      expect(find.textContaining('disk full'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a successful action shows nothing', (tester) async {
      late BuildContext context;
      await pump(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      var ran = false;

      await runGuarded(context, () async => ran = true);
      await tester.pump();

      expect(ran, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('a progress bar never shows more than full or less than empty', (
    tester,
  ) async {
    await pump(tester, const AppProgressBar(value: 1.7));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );

    await pump(tester, const AppProgressBar(value: -3));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
  });

  testWidgets('an icon badge is as large as asked, icon half as large', (
    tester,
  ) async {
    await pump(
      tester,
      const IconBadge(
        icon: Icons.shield,
        color: Colors.red,
        size: IconBadge.hero,
      ),
    );

    expect(
      tester.getSize(find.byType(IconBadge)),
      const Size.square(IconBadge.hero),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.shield)).size,
      IconBadge.hero / 2,
    );
  });
}
