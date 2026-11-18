# Publish Unspend — Short Checklist

For the detailed version of each portal step, see [LAUNCH_TODO.md](LAUNCH_TODO.md).

## 0. Verify blocking on a real iPhone first

Screen Time does not work in the Simulator, so the automated tests cover the
rules, the app's logic and every screen, but **not** what iOS actually does.
The blocking engine was rewritten in November 2026. It first ran on an
iPhone on 18 November 2026, which found a bug in the app picker (fixed); the
checks below are still open. Do this before anything else; each item is a
few minutes.

Install a **release** build: `flutter run --release -d <your-iphone>`. A debug
build only starts while it is connected to the computer — iOS refuses to
open it from the Home Screen afterwards — and several checks below need the
app closed for hours.

For the checks that do not depend on the cooldown, a test variant with the
real blocking and a 5-second cooldown saves a lot of waiting:
`flutter run --release -t lib/main_dev.dart --dart-define=NATIVE=true
--dart-define=COOLDOWN_SECONDS=5 -d <your-iphone>`. Never ship it; install
the normal build again afterwards.

**Diagnostics:** open Settings in the app and **press and hold the version
line** at the bottom ("Unspend 1.0.0 (1)"). It shows the authorization state,
the registered monitors and the last 30 decisions of the app and its
background extension — look there first when something does not start or
stop when expected. **Copy** puts the whole report on the clipboard; paste it
into a note (or to whoever is helping you debug) before and after a check
that fails.

- [ ] **Permission.** Fresh install: onboarding's last page shows the Screen
      Time prompt. Deny it → the dashboard shows a banner → "Open Settings" →
      allow → banner disappears when you come back.
- [ ] **Manual block.** Pick two apps, activate: both are blocked at once. The
      shield text is in the app's language (switch to German in Settings and
      open a blocked app again).
- [ ] **Two profiles sharing an app.** Activate both, deactivate one: the shared
      app stays blocked and the shield names the remaining profile.
- [ ] **Schedule.** Activate inside the window (blocked now), before it (blocked
      when it starts), let it end (unblocked), and one overnight window
      (22:00–06:00) across midnight.
- [ ] **Usage limit** (set 2 minutes). Not blocked right after activating;
      blocked after 2 minutes of use; still blocked after a schedule on the same
      profile ends; open again the next day.
- [ ] **Task mode.** Finishing the last task unblocks. Leave the app closed
      overnight: the apps are blocked again in the morning.
- [ ] **Websites.** Pick a website in the picker: it is blocked in Safari.
      Cancel and Save in the picker both return to the app.
- [ ] **Deleting.** Delete a profile, and Delete All Data with a profile
      active (cooldown + PIN): every block is gone, and the app asks for
      Screen Time access again afterwards.
- [ ] **Uninstall protection.** With a profile active, long-press any app on
      the Home Screen: "Delete App" is missing. Deactivate the profile: it is
      back. Switch the protection off in Settings → Uninstall protection with
      a profile active: it takes the cooldown (and PIN), then "Delete App" is
      back while the block stays.
- [ ] **Screen Time passcode (your own iPhone).** In iOS Settings → Screen
      Time, let the trusted person set a Screen Time passcode, then try to
      switch off Unspend's access under Screen Time. Expected: iOS asks for
      that passcode. Without one, the access can be switched off freely,
      which lifts every block — tell users of "my iPhone" mode to set it.
- [ ] **Child's iPhone.** On an iPhone signed in with a child's Apple Account
      in your Family Sharing group: choose "This is my child's iPhone" and
      approve as the parent. Then, as the child, try to delete Unspend and to
      switch off its Screen Time access — both should need the parent. Also
      try the choice on a phone that is *not* a child's: the app should say
      so and let you go back.
- [ ] **Switching who uses the iPhone.** Settings → Who uses this iPhone, with
      nothing active: access is given back and requested again for the other
      kind of user.
- [ ] **Edge cases.** Restart the phone with a profile active (still blocked).
      Pick more than 50 single apps (the picker asks for categories instead).
- [ ] **Release build.** `./tools/build-release.sh`, then check in Xcode's
      Organizer that the app and its three extensions carry the same version
      and build number. Try VoiceOver and the largest text size once.

## 1. Apple Developer Portal
- [ ] **Family Controls (Distribution) approved** for team `7DYCS4FJ2Y`. This is the
      longest wait (days). Request it at developer.apple.com/contact/request/family-controls-distribution.
      Describe both uses in the request: self-control on the user's own
      iPhone and parental control on a child's iPhone
- [ ] All 4 App IDs registered, each with **Family Controls** + **App Group** `group.com.maxroth.backyourtime`:
      `com.maxroth.backyourtime`, `.FocusMonitor`, `.AppBlocker`, `.ShieldConfigurationExtension`
- [ ] Apple Distribution certificate installed (or use automatic signing)

## 2. App Store Connect
- [ ] Create the app record (bundle ID `com.maxroth.backyourtime`, name "Unspend")
- [ ] Host `store/privacy-policy.html` publicly (e.g. Netlify Drop) and paste the URL
- [ ] Fill in description, keywords, subtitle, and support URL from `store/app-store-listing.md`
- [ ] App Privacy: **Data Not Collected**. Age rating: 4+. Category: Productivity
- [ ] Upload at least 2 iPhone 6.7" screenshots (1290×2796); see `store/screenshot-spec.md`.
      `flutter run -t lib/main_dev.dart` on the iPhone 17 Pro Max simulator gives
      you a fully clickable app to take them from.

## 3. Build & upload
- [ ] `./tools/build-release.sh` to produce the `.ipa` in `build/ios/ipa/`
- [ ] Upload with Transporter (or `xcrun altool` with an App Store Connect API key)
- [ ] Bump `version: 1.0.0+N` in `pubspec.yaml` before every re-upload (the
      extensions follow automatically)

## 4. TestFlight
- [ ] Install from TestFlight on a real iPhone and repeat section 0 with the
      release build
- [ ] The app is iPhone-only. App Review may still open it on an iPad in
      compatibility mode — install it on one once if you can

## 5. Submit
- [ ] Select the build, paste `store/review-notes.md` into Review Notes, then **Submit for Review**
- [ ] Expect 1–7 days for review. If rejected, the replies are in `store/review-notes.md`
