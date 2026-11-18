# Unspend

App blocker for iPhone, with an Android version in progress
([Android](#android)). Pick the apps that eat your day, set rules, get out
of the way.

Blocks are enforced by Apple's Family Controls + ManagedSettings frameworks
— so they're real, not a willpower test. Profiles can stack four kinds of
rules: a manual on/off, a daily time-of-day schedule, a daily usage budget,
and a "task list must be done" gate. Lifting a block takes a 5-minute
cooldown and a PIN.

It works on your own iPhone (a trusted person holds the PIN) or on your
child's iPhone (a parent approves it through Family Sharing, and iOS keeps
the child from deleting it). While a block is running, apps cannot be
deleted from the phone.

| | |
|---|---|
| Platform | iPhone, iOS 16+, portrait and landscape. Android 8+ in progress |
| Languages | English · German · Spanish · French · Croatian |
| Storage | 100% on-device. No accounts, no analytics, no network. |
| PIN | SHA-256 + per-install salt, stored in iOS Keychain |

## Architecture

```
lib/
├── main.dart                 # production entrypoint
├── main_dev.dart             # development entrypoint (fake Screen Time)
├── bootstrap.dart, app.dart  # startup, MaterialApp, text-scale cap
├── config/                   # GoRouter (provider)
├── core/
│   ├── theme/                # design tokens: colour, type, spacing, shape,
│   │                         #   motion, haptics, and the Material theme
│   ├── widgets/              # shared components every screen is built from
│   ├── constants/strings.dart  # all user-facing text, 5 languages
│   ├── storage_keys.dart     # every key anything is stored under
│   └── providers.dart        # infrastructure seams (prefs, clock, cooldown)
├── dev/                      # demo data for the development entrypoint
├── features/app_blocker/
│   ├── domain/               # BlockerProfile, ShieldPolicy (the blocking rule)
│   ├── data/                 # ScreenTimeDatasource (interface, MethodChannel
│   │                         #   implementation, in-memory fake), repositories
│   └── presentation/         # screens, widgets, Riverpod providers
├── features/onboarding/
└── shared/providers/         # language + theme mode

ios/
├── Runner/                   # Flutter host, ScreenTimeChannel, app picker
├── FocusMonitor/             # DeviceActivityMonitor extension
├── AppBlocker/               # ShieldAction extension (shield button)
├── ShieldConfigurationExtension/  # text and look of the shield
└── Shared/                   # rule engine shared by the app and extensions
    ├── Sources/ShieldCore/   #   Foundation-only: policy, rules, App Group store
    ├── ShieldEnforcer.swift  #   applies the policy to ManagedSettings
    └── Tests/                #   `swift test` (the package exists only for this)
```

### How blocking works

A profile's apps are blocked while **any** of its enabled rules says so:

```
blocked = manual only
       || schedule and inside its window
       || task mode and today's tasks not all done
       || usage limit and today's limit used up
```

iOS enforces this, not the app. When a profile is activated the app writes a
snapshot of its rules into the App Group and registers DeviceActivity
monitors. From then on the monitor extension re-evaluates the rule on every
boundary (schedule start/end, midnight, limit reached) — also while the app
is closed. The rule lives once in Swift (`ShieldPolicy.swift`) and is mirrored
in Dart (`shield_policy.dart`) for display; keep the two in sync.

Each profile owns its own `ManagedSettingsStore(named: "unspend.<profileId>")`,
so overlapping profiles block independently. A separate store,
`unspend.guard`, holds the "apps cannot be deleted" restriction while any
profile is active. Dart talks to the native side
through intent-level calls (`activate`, `deactivate`, `setTasksDone`, `sync`, …)
on `com.maxroth.backyourtime/screentime`; the app picker has its own channel.

## Running locally

Requirements: Flutter 3.41+, Xcode 26+, and for a real device an Apple
Developer account with the Family Controls entitlement.

```bash
# One-time setup (installs Homebrew Ruby + CocoaPods via bundler)
./tools/setup-ios-toolchain.sh
```

**In the Simulator** — Family Controls does not work there, so use the
development entrypoint. It runs the whole app on an in-memory Screen Time
that follows the same rule, with a 10-second cooldown:

```bash
flutter run -t lib/main_dev.dart
```

Add sample profiles (handy for screenshots):

```bash
flutter run -t lib/main_dev.dart --dart-define=DEMO=true
```

**On an iPhone** — the real thing:

```bash
flutter run -d <your-device>
```

Use `--release` when the app has to survive being closed (a debug build only
starts from the tooling). In Settings, press and hold the version line at the
bottom to open Diagnostics: what the OS side is doing, with a Copy button.

If you build from Xcode directly after `flutter run` on a device and get
`Framework 'Pods_Runner' not found`, run this once and build again:

```bash
flutter build ios --config-only
```

If `pod install` fails with a Unicode error, `LANG` is not set;
`tools/setup-ios-toolchain.sh` takes care of it.

Xcode project settings that are tedious to keep right by hand (iPhone-only,
extension versions, shared source membership) are applied by a script. Run it
after adding a Swift file under `ios/Shared`:

```bash
cd ios && bundle exec ruby ../tools/ios_project.rb
```

## Android

The same app, the same rules, a different way of enforcing them. Android
has no Screen Time API for third-party apps, so Unspend ships an
**accessibility service** (`BlockerService`) that is told which app comes to
the front. If an active profile blocks that app, the service puts the block
screen (`BlockActivity`) over it. The service cannot read what is on screen
(`canRetrieveWindowContent` is off) and the user switches it on in Android's
settings after the app has explained what it is for.

```
android/app/src/main/kotlin/com/maxroth/backyourtime/
├── core/                  # the rule engine, pure Kotlin, unit-tested
│   ├── ShieldPolicy.kt    #   same rule as ShieldPolicy.swift
│   ├── Blocker.kt         #   which profile blocks the app in front
│   └── SharedStore.kt     #   selections, rules, today's usage, event log
├── ChannelContract.kt     # the bridge's names (third copy, see Dart/Swift)
├── ScreenTimeChannel.kt   # answers the same calls as the iOS bridge
├── BlockerService.kt      # notices the app in front, counts limit time
├── BlockActivity.kt       # the block screen
└── AppPickerActivity.kt   # choosing apps (Android has no system picker)
```

The Dart side is shared. Where it has to differ it asks
`appPlatformProvider`; wording that names the platform's way of blocking is
overridden in `lib/core/constants/strings_android.dart`.

```bash
flutter run -d <android-device-or-emulator>
cd android && ./gradlew :app:testDebugUnitTest   # the Kotlin rule engine
```

Unlike the iOS Simulator, an **Android emulator blocks for real**. To walk
through flows quickly, keep the real bridge and shorten the cooldown:

```bash
flutter run -t lib/main_dev.dart --dart-define=NATIVE=true --dart-define=COOLDOWN_SECONDS=5
```

**Where Android stands.** Works, checked on an Android 14 emulator: picking
apps, blocking, the daily limit, deactivating, the access flow, release
build. Not there yet:

- Uninstall protection and the child's-phone mode (their settings are
  hidden on Android). Without them a block can be ended by switching the
  service off or removing the app.
- Blocking websites.
- Everything for Google Play: release signing (the release build is signed
  with the debug key), store listing, the Accessibility API declaration in
  the Play Console, an adaptive launcher icon.
- A run on real phones, especially ones with aggressive battery savers.

## Design system

Screens are composed from tokens (`lib/core/theme/`) and shared components
(`lib/core/widgets/`); they contain no colours, sizes or text styles of their
own. [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) is the guide: the
tokens, the components, the accessibility requirements and how to add a
screen.

## Tests

```bash
flutter test                              # unit + widget tests (~1.5 min)
swift test --package-path ios/Shared      # the iOS rule engine (seconds)
(cd android && ./gradlew :app:testDebugUnitTest)   # the Android rule engine
flutter test integration_test -d <simulator>   # one end-to-end run
```

- `test/app/responsive_layout_test.dart` pumps every screen, sheet and dialog
  on the smallest and largest iPhones, portrait and landscape, at default and
  largest supported text size (2×), in all five languages, and fails on any
  layout error.
- `test/app/accessibility_test.dart` checks tap-target size, labels and text
  contrast in all four themes (light, dark, each with increased contrast).
- `test/app/robustness_test.dart` covers what must not break the app: double
  taps, a Keychain that cannot be read, errors nobody planned for.
- `test/presentation/profiles_notifier_test.dart` covers every rule
  combination against the fake Screen Time.

What no test can cover is iOS itself — see the device checklist at the top
of [`docs/PUBLISH.md`](docs/PUBLISH.md).

## Building for the App Store

```bash
./tools/build-release.sh
```

This checks formatting, runs `flutter analyze`, `flutter test` and the Swift
tests, regenerates pods, then produces a signed `.ipa` at `build/ios/ipa/`
ready to upload via Transporter.

## Submission prep

Everything you need is in [`store/`](store/):

- `privacy-policy.html` — hostable privacy page
- `app-store-listing.md` — paste-ready description, keywords, what's new
- `review-notes.md` — App Review notes covering the Family Controls usage
- `screenshot-spec.md` — what screenshots to take and at what size

See [`docs/PUBLISH.md`](docs/PUBLISH.md) for the short checklist and
[`docs/LAUNCH_TODO.md`](docs/LAUNCH_TODO.md) for the detailed one.

## License

All rights reserved.
