# Screenshot Spec

Apple requires screenshots for at least one device size: the **iPhone 6.9"**
slot, which takes 1320 × 2868 (what the iPhone 17 Pro Max simulator
produces) or 1290 × 2796. Unspend is iPhone-only, so no iPad set is needed.

## Sizes you actually need

| Device class | Resolution (px) | Min count | Used for |
|---|---|---|---|
| iPhone 6.9" (iPhone 16/17 Pro Max) | 1320 × 2868 or 1290 × 2796 | 3 (Apple allows up to 10) | Required |
| iPhone 6.5" (older Pro Max) | 1242 × 2688 | 0 | Apple reuses the 6.9" set if not provided |

## Suggested screenshots (5 recommended)

Take these on the iPhone 17 Pro Max simulator (or your device). For each,
add a 1-line caption baked into the image (App Store Connect doesn't have
a separate caption field).

1. **Dashboard with active profile**
   - Caption: *"Block what's eating your day"*
   - Show: dashboard with 1–2 profiles, one with shield active

2. **Profile detail screen — rule toggles**
   - Caption: *"Schedule, budget, or task-list. Stack them."*
   - Show: profile detail with Schedule + Task Mode toggles on

3. **The shield in action (custom block screen)**
   - Caption: *"A real block, not a willpower test"*
   - Show: ShieldConfigurationExtension UI when opening a blocked app
   - HOW: open a blocked app on device, screenshot the shield. Crop to phone-frame.

4. **Task mode — earn your access**
   - Caption: *"Finish your list to unlock"*
   - Show: profile with 3 tasks, 1 checked off

5. **Settings / Delete All Data / Privacy**
   - Caption: *"Yours alone. Nothing leaves your device."*
   - Show: Settings sheet with "Delete All Data" + privacy policy entries visible

## How to capture cleanly

Option A — On device (most realistic for the shield screenshot):
```
# Hold Volume Up + Side button on iPhone
# Then transfer via AirDrop / Photos
```

Option B — Simulator (fastest). The demo build starts with sample profiles
and has no debug banner:
```
flutter build ios --simulator --debug -t lib/main_dev.dart --dart-define=DEMO=true
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl ui booted appearance dark
xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.maxroth.backyourtime
# open the screen you want, then:
xcrun simctl io booted screenshot store/screenshots/iphone-6.9/02-rules.png
```
`01-dashboard.png` was taken this way. The shield (screenshot 3) only exists
on a real iPhone.

Option C — Use a screenshot framing tool (adds a phone bezel + caption):
- https://app-mockup.com (free, in-browser)
- Figma device frames
- `fastlane frameit` (CLI)

## Naming convention (for your sanity)

```
store/screenshots/
  iphone-6.9/
    01-dashboard.png       (1320×2868)
    02-rules.png
    03-shield.png
    04-tasks.png
    05-settings.png
```

Upload order in App Store Connect matters — the first screenshot is the
"hero" image users see in search results.
