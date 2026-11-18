import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/app.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/core/time/day_key.dart';
import 'package:unspend/features/app_blocker/data/datasources/fake_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/method_channel_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/repositories/pin_repository.dart';
import 'package:unspend/features/app_blocker/data/repositories/profiles_repository.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';
import 'package:unspend/features/app_blocker/presentation/providers/device_mode_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/profiles_provider.dart';

/// A phone the app has to hold up on: screen size in points and the insets
/// taken by notch, Dynamic Island and home indicator.
class Device {
  const Device(this.name, this.size, {this.padding = EdgeInsets.zero});

  final String name;
  final Size size;
  final EdgeInsets padding;

  @override
  String toString() => name;
}

/// Smallest and largest iPhones, upright and on their side. The 320-point
/// width covers Display Zoom on the smaller models.
const devices = [
  Device('320×568 portrait', Size(320, 568), padding: EdgeInsets.only(top: 20)),
  Device('375×667 portrait', Size(375, 667), padding: EdgeInsets.only(top: 20)),
  Device(
    '430×932 portrait',
    Size(430, 932),
    padding: EdgeInsets.only(top: 59, bottom: 34),
  ),
  Device('568×320 landscape', Size(568, 320)),
  Device('667×375 landscape', Size(667, 375)),
  Device(
    '932×430 landscape',
    Size(932, 430),
    padding: EdgeInsets.only(left: 59, right: 59, bottom: 21),
  ),
];

const defaultDevice = Device(
  '375×667 portrait',
  Size(375, 667),
  padding: EdgeInsets.only(top: 20),
);

/// The moment every app test starts at: a Tuesday at noon.
final testNow = DateTime(2026, 11, 17, 12);

/// Profiles covering every kind of card: active with all three rules and
/// tasks (and names long enough to wrap), plain manual, and limit-only
/// without apps.
List<BlockerProfile> sampleProfiles({DateTime? now}) {
  final at = now ?? testNow;
  return [
    BlockerProfile(
      id: 'social',
      name: 'Social media and endless scrolling',
      iconLabel: 'Social',
      hasAppsSelected: true,
      appCount: 12,
      scheduleEnabled: true,
      scheduleStartHour: 9,
      scheduleStartMinute: 0,
      scheduleEndHour: 17,
      scheduleEndMinute: 30,
      usageLimitEnabled: true,
      usageLimitMinutes: 90,
      taskModeEnabled: true,
      tasks: const [
        BlockerTask(
          id: 't1',
          title: 'Read twenty pages of the book on the nightstand',
          isDone: true,
        ),
        BlockerTask(id: 't2', title: 'Go for a run'),
      ],
      isActive: true,
      shieldActivatedAt: at
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      tasksLastResetDate: dayKey(at),
    ),
    BlockerProfile(
      id: 'games',
      name: 'Games',
      colorValue: 0xFF43A047,
      iconLabel: 'Games',
      hasAppsSelected: true,
      appCount: 3,
      tasksLastResetDate: dayKey(at),
    ),
    BlockerProfile(
      id: 'news',
      name: 'News',
      colorValue: 0xFFFFC107,
      iconLabel: 'News',
      usageLimitEnabled: true,
      usageLimitMinutes: 45,
      tasksLastResetDate: dayKey(at),
    ),
  ];
}

/// The running app plus everything a test needs to look behind it.
class AppHarness {
  AppHarness._(this.tester, this.container, this.screenTime, this.prefs);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeScreenTimeDatasource screenTime;
  final SharedPreferences prefs;

  /// What the app's clock returns; tests move it forward.
  DateTime now = testNow;
  bool _disposed = false;

  S get s => S.current;

  List<BlockerProfile> get profiles =>
      container.read(profilesProvider).requireValue;

  BlockerProfile profile(String id) => profiles.singleWhere((p) => p.id == id);

  PinRepository get pins => container.read(pinRepositoryProvider);

  /// Navigates to [location] as a deep link would.
  Future<void> open(String location) async {
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  /// The vertical scroll view in front: a sheet's if one is open, else the
  /// screen's. Text fields contain small scrollables of their own, so the
  /// largest one that can be touched is taken.
  Finder get frontScrollable {
    final candidates = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .hitTestable();
    Element? front;
    var largest = 0.0;
    for (final element in candidates.evaluate()) {
      final size = element.size;
      if (size != null && size.width * size.height > largest) {
        largest = size.width * size.height;
        front = element;
      }
    }
    return find.byElementPredicate((element) => element == front);
  }

  /// Taps the first match of [finder], scrolling it into view first: list
  /// items below the fold are not built (or not exposed to accessibility)
  /// until they are scrolled to, and the floating button covers the corner.
  Future<void> tap(Finder finder) async {
    await tester.tap(await _reveal(finder));
    await tester.pumpAndSettle();
  }

  /// Presses and holds the first match of [finder], scrolling it into view
  /// first.
  Future<void> longPress(Finder finder) async {
    await tester.longPress(await _reveal(finder));
    await tester.pumpAndSettle();
  }

  /// Scrolls the first match of [finder] to the middle of the screen and
  /// returns it.
  Future<Finder> _reveal(Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      final scrollable = frontScrollable;
      if (scrollable.evaluate().isEmpty) break;
      await tester.drag(scrollable, const Offset(0, -120), warnIfMissed: false);
      await tester.pump();
    }
    final target = finder.first;
    // Centre it: a tap lands on the middle of a widget, and with very large
    // text a card can be taller than what is visible of the page.
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    return target;
  }

  /// Lets [duration] pass one second at a time, as a running countdown
  /// would see it.
  Future<void> elapse(Duration duration) async {
    for (var i = 0; i < duration.inSeconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
  }

  /// Takes the app down so another one can be started in the same test.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }
}

/// Starts the real app (router, theme, lifecycle host) on top of a fake
/// Screen Time and in-memory storage.
Future<AppHarness> pumpUnspend(
  WidgetTester tester, {
  List<BlockerProfile> profiles = const [],
  bool onboardingSeen = true,
  Device device = defaultDevice,
  double textScale = 1,
  String locale = 'en',
  Brightness brightness = Brightness.dark,
  ScreenTimeAuthStatus auth = ScreenTimeAuthStatus.approved,
  ScreenTimeAuthStatus authAfterRequest = ScreenTimeAuthStatus.approved,
  DeviceMode mode = DeviceMode.personal,
  bool isChildAccount = true,
  Duration cooldown = const Duration(seconds: 3),
  String? pin,
  DateTime? now,
  bool highContrast = false,
  bool reduceMotion = false,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = device.size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(
      left: device.padding.left,
      top: device.padding.top,
      right: device.padding.right,
      bottom: device.padding.bottom,
    );
  tester.platformDispatcher
    ..textScaleFactorTestValue = textScale
    ..platformBrightnessTestValue = brightness
    ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      highContrast: highContrast,
      disableAnimations: reduceMotion,
    );
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  SharedPreferences.setMockInitialValues({
    PrefKeys.profilesSchemaVersion: ProfilesRepository.currentSchemaVersion,
    if (profiles.isNotEmpty)
      PrefKeys.profiles: jsonEncode([
        for (final profile in profiles) profile.toJson(),
      ]),
    if (onboardingSeen) PrefKeys.onboardingSeen: true,
    if (mode != DeviceMode.personal) PrefKeys.deviceMode: mode.name,
  });
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await S.setLocale(locale);

  late final AppHarness harness;
  final screenTime = FakeScreenTimeDatasource(
    authStatus: auth,
    statusAfterRequest: authAfterRequest,
    isChildAccount: isChildAccount,
    clock: () => harness.now,
  );
  // The OS side already knows the stored profiles.
  for (final profile in profiles) {
    if (profile.hasAppsSelected) {
      screenTime.selections[profile.id] = profile.appCount;
    }
    if (profile.isActive) {
      screenTime.active[profile.id] = ActivationRequest.fromProfile(profile);
    }
  }

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => harness.now),
      cooldownDurationProvider.overrideWithValue(cooldown),
      screenTimeDatasourceProvider.overrideWithValue(screenTime),
      ...overrides,
    ],
  );
  harness = AppHarness._(tester, container, screenTime, prefs);
  if (now != null) harness.now = now;
  addTearDown(harness.dispose);
  if (pin != null) await harness.pins.setPin(pin);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UnspendApp()),
  );
  await tester.pumpAndSettle();
  screenTime.calls.clear();
  return harness;
}
