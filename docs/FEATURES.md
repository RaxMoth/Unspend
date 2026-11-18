# Unspend — Features

What ships, what is open, and what is queued. Last updated 2026-11-17.

## ✅ Shipped

**Blocking**
- Apps, app categories and websites blocked by iOS itself (Family Controls,
  ManagedSettings, DeviceActivity).
- Four stackable rules per profile: manual, daily schedule (also overnight),
  daily usage limit (1 min – 23 h 59 min), and task mode (blocked until today's
  tasks are done; resets every day).
- One rule decides: blocked while *any* enabled rule says so. Enforced by the
  monitor extension while the app is closed, including the midnight reset.
- Each profile has its own shield, so profiles sharing an app do not interfere.
- Custom shield screen in the app's language, naming the blocking profile.

**For yourself or for your child**
- Chosen on first launch (and changeable in Settings while nothing is
  active): "my iPhone" asks for Screen Time access for the user; "my child's
  iPhone" has a parent approve with their Apple Account (Family Sharing), after
  which iOS keeps the child from deleting Unspend or switching it off.
- Uninstall protection: while a profile is active, apps cannot be deleted
  from the phone. On by default; switching it off takes the PIN, and the
  cooldown while a profile is active.

**Protection against giving in**
- Deactivating takes a 5-minute cooldown, then the PIN (if one is set).
- PIN: salted SHA-256 in the Keychain; lockout after repeated wrong attempts
  that survives closing the dialog or the app.
- Changing the PIN requires the current one. While a profile is active,
  Change PIN and Delete All Data also take the cooldown, and the profile's
  rules, apps and tasks are locked.

**App**
- Onboarding that ends with the Screen Time permission; a dashboard banner
  when permission is missing.
- iPhone, portrait and landscape; system text size up to 2×.
- Follows the system's Increase Contrast and Reduce Motion settings.
- Light, dark and system theme. English, German, Spanish, French, Croatian.
- VoiceOver labels, 44 pt tap targets, WCAG AA text contrast.
- 100 % on-device: no account, no network, no analytics. Delete All Data
  removes everything, including the app selections held by iOS.

**Engineering**
- A design system (`docs/DESIGN_SYSTEM.md`): colour, type, spacing, shape,
  motion and haptic tokens, and shared components every screen is built from.
- 477 Dart tests, 42 Swift tests, 31 Kotlin tests, one integration test; CI
  on every push (Dart, iOS build, Android build).
- `lib/main_dev.dart` runs the whole app in the Simulator on a fake Screen Time.
- Diagnostics screen for what the OS side did (Settings → press and hold the
  version line), with a copyable report.

**Android (in progress)**
- The app runs on Android 8+ with the same profiles and rules. Blocking is
  done by an accessibility service the user switches on after an in-app
  explanation; apps are chosen on the app's own picker screen.
- Manual blocking, schedules, daily limits and task mode; the block screen
  speaks the app's language.
- Not on Android yet: uninstall protection, the child's-phone mode,
  websites, Google Play release work. See the README's Android section.

## 🚧 Open before release

- **Verify blocking on a physical iPhone** — the engine was rewritten and
  Screen Time cannot run in the Simulator. Checklist: `docs/PUBLISH.md`, section 0.
- Apple portal work (entitlement approval, App Store Connect) — `docs/LAUNCH_TODO.md`.

## 📋 Backlog

- **Statistics screen** — the app already records how long profiles were
  active and the daily peak of active profiles; nothing displays it yet.
- **Crash reporter** (Sentry or similar) — changes the privacy label and must
  be disclosed. Post-launch.
- **Freemium model** — e.g. one profile free. Product decision.
- **iPad layout** — the app is iPhone-only.
