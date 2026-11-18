# Changelog

All notable changes to Unspend are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 2026-11-18 — Android foundation

The app now runs on Android and blocks apps there. iOS behaviour is
unchanged.

#### Added
- **Android blocking engine** (Kotlin). An accessibility service
  (`BlockerService`) learns which app comes to the front and puts a block
  screen over it when an active profile blocks it; it re-checks an open app
  every 10 seconds, so a schedule that starts, a daily limit that runs out
  or the midnight reset apply without reopening the app. It cannot read
  screen content.
- **Same bridge, third implementation.** `ScreenTimeChannel.kt` answers the
  calls `ScreenTimeChannel.swift` answers; the Dart side is shared.
- **Kotlin rule engine** (`android/.../core`) mirroring the Swift one, with
  31 unit tests; daily limits are counted by the service itself, from the
  moment a profile is activated.
- **App picker for Android** (the system has none): every app with a
  launcher icon except the home screen, phone, settings and Unspend itself,
  which can never be blocked.
- **Consent before access.** Before the user is sent to Android's
  accessibility settings, the app says what the service is used for and asks
  for a yes (required by Google Play).
- Android wording in all five languages for everything that names Screen
  Time or the iPhone (`strings_android.dart`).
- `appPlatformProvider`: the one place the app asks which platform it is on.
- CI job that builds the Android app and runs the Kotlin tests.
- `lib/main_dev.dart --dart-define=NATIVE=true` keeps the real bridge and
  only shortens the cooldown (for the Android emulator).

#### Changed
- Status and navigation bars take the app's background colour (both
  platforms).
- "1 app selected" instead of "1 apps selected", in every language
  (Croatian now has its three plural forms).

#### Not on Android yet
- Uninstall protection, the child's-phone mode, blocking websites, release
  signing and the Google Play listing.

### 2026-11-18 — Pre-launch polish

#### Added
- **Version line** at the end of Settings ("Unspend 1.0.0 (1)").
- **Diagnostics in every build**: press and hold the version line. It was
  debug-only, but a debug build cannot be reopened from the Home Screen of a
  real iPhone, which made it useless for the overnight checks. The report now
  starts with the app and iOS version and can be copied.
- The app declares its five languages to iOS (`CFBundleLocalizations`), so
  the system's own screens inside the app — the Screen Time prompt, the app
  picker's list — follow the phone's language instead of always being
  English, and the App Store lists the languages.

#### Changed
- The launch screen has the app's background colour in light and dark mode
  (it was white, a flash before the dark app).
- The blocked-app screen's button is the app's red instead of system blue.
- The daily limit on a profile card reads like everywhere else
  ("45 min limit", "1 h 30 min limit").

### 2026-11-18 — Design system and robustness

No change in what the app does; a change in how it is built and how it
behaves when something goes wrong.

#### Added
- **Design system** (`docs/DESIGN_SYSTEM.md`). Colours are a `ThemeExtension`
  with four palettes (light, dark, and an increased-contrast variant of each);
  type scale, spacing, radii, sizes, motion and haptics are tokens in
  `lib/core/theme/`. Shared components in `lib/core/widgets/` (`AppCard`,
  `IconBadge`, `AppButton`, `AppChip`, `AppDialog`, `Reveal`, …) replace
  per-screen copies.
- Follows the system's **Increase Contrast** (stronger outlines and text,
  AAA contrast for coloured text) and **Reduce Motion** settings.
- System text size is followed up to **2×** (was 1.6×).
- Rule settings slide in and out instead of jumping; buttons show progress
  while working; haptics have one meaning each.
- `lib/main_dev.dart --dart-define=DEMO=true` starts with sample profiles.
- One registry for stored keys (`storage_keys.dart`) and one for the native
  bridge's names (`screen_time_contract.dart`, `ChannelContract.swift`).

#### Fixed
- A double tap could open two unlock dialogs or two sheets.
- If the Keychain could not be read, the unlock dialog stayed on a spinner
  forever; it now says so and offers to retry (and never treats that as
  "no PIN").
- An unexpected error while activating left the button disabled; unexpected
  errors in any user-started action now end in a plain message.
- With Reduce Motion, expanding a rule's settings would have tripped a layout
  assertion.
- A malformed reply from the native side can no longer crash the Dart side.
- The daily-limit keypad overflowed at the largest text size on small phones.

#### Changed
- Stricter static analysis (no implicit `dynamic`, no dropped futures).
- 443 Dart tests (was 357).

#### Removed
- Global colour getters and the brightness-sync workaround that kept them
  current; ~100 inline text styles and ~250 literal sizes and colours.


### 2026-11-17 — Production hardening

Blocking is now decided by one rule, enforced by iOS, and covered by tests.
**Not yet verified on a physical device** — see the checklist at the top of
`docs/PUBLISH.md`.

#### Fixed
- **Schedules and usage limits could never fire**: the monitor and shield
  extensions declared extension-point identifiers iOS does not know
  (`com.apple.deviceactivity.monitor`, `com.apple.shieldconfiguration-service`).
  They are now `com.apple.deviceactivity.monitor-extension` and
  `com.apple.ManagedSettingsUI.shield-configuration-service`.
- **Rules cancelled each other.** The monitor extension blocked on every
  "interval started" and unblocked on every "interval ended", so a usage limit
  blocked at midnight without being used and a schedule ending lifted a block
  that tasks or a reached limit still required. Finishing the last task also
  stopped the profile's schedule and limit monitors. The extension now
  re-evaluates one shared rule on every event.
- **Task mode never re-locked** on a new day. Tasks reset daily, enforced by
  the OS even while the app is closed.
- **Usage counted from midnight**, so a limit could be "used up" before the
  profile was activated. Counting starts at activation (iOS 17.4+); events that
  arrive sooner than physically possible are ignored.
- **Websites** chosen in the picker were never blocked.
- **Cancelling the app picker** left the app waiting forever.
- **Bypasses closed**: Change PIN now requires the current PIN; Change PIN and
  Delete All Data go through the cooldown while a profile is active; an active
  profile cannot be deleted or have its apps changed (also enforced natively).
  Wrong-PIN lockout now survives closing the dialog and restarting the app.
- **Delete profile / Delete All Data** left app selections behind in the App
  Group and could leave blocks in place.
- The shield named the wrong profile when two were active, and was always in
  English; it now follows the in-app language, as does the app picker.
- `BlockerProfile.copyWith` could not clear nullable fields.
- A change made while the profile list was still loading could overwrite the
  stored profiles; rapid changes could lose updates.
- Simulator builds and `flutter build ipa` were broken by a build-directory
  pin in the xcconfig files; extension versions did not follow the app version.

#### Changed
- Screen Time permission is asked for on the last onboarding page instead of
  silently at startup; a dashboard banner explains what to do when it is
  missing.
- iPhone only (was universal); every screen works in portrait and landscape.
- System text size is honoured up to 1.6×; all screens, sheets and dialogs
  scroll instead of overflowing. Tap targets are at least 44 pt. Screen-reader
  labels are localized. Text colours meet WCAG AA in both themes, including
  text in profile colours.
- The app follows a system light/dark switch immediately.
- Setting a PIN after picking apps can be postponed ("Not now").
- `profile_detail_screen.dart` (1,258 lines) and `dashboard_body.dart` (697)
  were split into focused widgets; side effects sit behind providers.

#### Added
- **Child mode.** Onboarding asks who uses the iPhone. "My child's iPhone"
  requests Family Controls authorization for `.child`: a parent approves with
  their Apple Account and iOS keeps the child from deleting Unspend or
  withdrawing its access. Changeable in Settings while nothing is active
  (access is given back and requested again). Delete All Data now also gives
  Screen Time access back.
- **Uninstall protection.** While a profile is active, iOS does not allow
  deleting apps (`denyAppRemoval`), so removing Unspend is not a way around a
  block. On by default; switching it off takes the PIN, plus the cooldown while
  a profile is active.
- Shared Swift rule engine (`ios/Shared`) with 42 unit tests (`swift test`).
- 357 Dart tests (was 22): rule combinations, repositories, channel contract,
  every screen's behaviour, a responsive layout matrix and accessibility checks;
  one end-to-end integration test.
- `lib/main_dev.dart`: the full app in the Simulator on an in-memory Screen Time.
- Debug-only Diagnostics screen showing what the OS side did.
- `tools/ios_project.rb` keeps Xcode project settings consistent.
- Privacy manifests for the extensions; App Group reason added to the app's.

#### Removed
- Dead code: hand-rolled switches, `PressableCard`, unused strings and barrels.


### Fixed
- 2026-07-15: Missing `mounted` guards after `await` in `profile_detail_screen` —
  the usage-limit picker (`_pickUsageLimit`) and both schedule `showTimePicker`
  callbacks (start/end `TimeTile.onTap`) called `setState` across the async gap
  with no `if (!mounted) return;`. If the user popped the screen while a picker
  was open, `setState` would fire on a defunct `State` (a debug assertion / silent
  no-op in release). Added a `mounted` check after each `await`, matching the guard
  pattern the rest of the codebase already follows. No behaviour change; analyze +
  all 22 tests green.
- 2026-07-14: `TextEditingController` leak in the dashboard create-profile sheet —
  `_showCreateProfileSheet` (`dashboard_screen.dart`) allocated a controller per open
  but never disposed it (it's a method local, not a `State` field, so it slipped past
  the pattern every other controller in the tree follows). Attached
  `.whenComplete(controller.dispose)` to the `showModalBottomSheet` future so it's
  released when the sheet closes. No behaviour change; analyze + all 22 tests green.

### Changed
- 2026-07-15: `.select()` narrowing in `ProfileDetailPageShell` — the profile detail
  shell watched the entire `profilesProvider` (`AsyncValue<List<BlockerProfile>>`) and
  extracted one profile by id, so editing *any* profile rebuilt the open detail screen.
  It now watches `profilesProvider.select((async) => async.whenData((list) => …))`,
  projecting only the matching profile. `ProfilesNotifier` preserves the identity of
  unchanged profiles across state updates (`list.map((p) => p.id == effective.id ? effective : p)`),
  so the selected `AsyncValue` compares equal when a sibling profile changes and the shell
  no longer rebuilds. Loading/error/not-found paths unchanged; analyze + all 22 tests green.
- 2026-07-14: `dart format` compliance + CI formatting gate — reformatted the tree
  (20 files drifted) and added a `dart format --output=none --set-exit-if-changed lib test`
  step to `ci.yml` ahead of Analyze, so formatting drift now fails the check. Pure
  formatting, no logic change; analyze + all 22 tests still green.
- 2026-07-14: Framework-lean picker controls — the color and icon pickers in
  `profile_detail_screen` and the add-task button in `task_list_section` now use
  `Material` + `InkWell` (touch ripple + keyboard-focus highlight) wrapped in
  `Semantics` (screen-reader `button` role, plus `selected` state on the pickers),
  replacing the hand-rolled `GestureDetector` + `Container` tap targets. Visuals are
  unchanged; this adds tap feedback and accessibility for free from the framework.

### Added
- 2026-07-14: CI workflow (`.github/workflows/ci.yml`) — runs `flutter analyze` and
  `flutter test` on pushes to `main` and on PRs targeting `main`, pinned to Flutter
  3.41.2 via `subosito/flutter-action@v2` (with pub-cache), plus concurrency-cancel
  for superseded runs. A broken analyze/test now fails the check. Filed a follow-up
  backlog item to reformat the 20 `dart format`-drifting files and add a formatting
  gate separately (kept out of this change to keep the reformat diff reviewable).
- 2026-07-14: PIN-hashing round-trip test coverage (7 tests) via a new pure
  `PinHasher` helper (`lib/core/security/pin_hasher.dart`) — `generateSalt`
  (16-byte hex, seedable for determinism) and `hash(salt, pin)` (SHA-256 over
  `'<salt>:<pin>'`). Wired `ProfilesNotifier.savePin`/`verifyPin` to call it,
  which also **fixed a broken build**: a prior run had swapped the `crypto`
  import for the helper but left inline `sha256.convert(...)` calls, so
  `flutter analyze` had 2 `undefined_identifier` errors. Behaviour unchanged.
- 2026-07-06: Unit-test coverage for `BlockerProfile` (15 tests) — JSON round-trip,
  corrupt-storage clamping, schedule overnight-window math, and requirement getters
  (`allTasksDone`, `pendingTaskCount`, `isManualOnly`, `areRequirementsMet`).
  Extracted the pure, time-independent `isMinuteInsideScheduleWindow(int)` from
  `isInsideScheduleWindow` so the overnight-window math is testable (behavior unchanged).

### Changed
- 2026-07-06: Localized the "Activation failed" snackbar (was hardcoded English in
  `profile_detail_screen` and `dashboard_body`) via a new `S.activationFailed` string
  across all 5 locales; unified success-green into a `kSuccess` design token
  (replaced hardcoded `Colors.green` / `Color(0xFF43A047)` in `task_list_section` and
  `profile_card`). Bootstrapped `CHANGELOG.md` and `FEATURES.md`.

## [1.0.0] — App Store readiness

Reconstructed from `git log`; grouped by theme rather than per-commit.

### Added
- Core app blocker built on Apple Family Controls + ManagedSettings, enforced natively.
- Four stackable rule types per profile: manual on/off, daily time-of-day schedule,
  daily usage budget, and a "task list must be done" gate.
- Four iOS extensions wired in: Runner, FocusMonitor (DeviceActivityMonitor),
  AppBlocker (ShieldAction), ShieldConfigurationExtension (custom shield UI).
- Per-profile `ManagedSettingsStore(named: "unspend.<profileId>")` so overlapping
  profiles don't trample each other's shields.
- Statistics page and improved profile setup flow.
- Dual-mode time picker (wheel + keypad).
- PIN protection: SHA-256 + per-install salt in iOS Keychain, behind a 5-minute cooldown.
- Five languages: English, German, Spanish, French, Croatian.
- Light mode and full theming (design tokens, Material 3).
- Haptic / tactile feedback across the app.
- Privacy manifest, privacy policy draft, and App Store submission artifacts under `store/`.
- Build + toolchain scripts under `tools/`.

### Fixed
- Shield deactivation bug on app resume.
- Settings sheet 72px overflow on standard iPhones.
- Deployment target and app-picker fixes; i18n for privacy / onboarding / delete-data flows.
