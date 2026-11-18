# Unspend — Design System

How the app looks, moves and stays consistent, and where each decision lives
in code. Read this before adding a screen or a widget.

The short version: **screens are composed from tokens and shared components;
they do not contain colours, sizes or text styles of their own.** If a screen
needs a number that is not a token, either a token is missing or the number
has a meaning and deserves a named constant next to the widget.

```dart
import 'package:unspend/core/theme/theme.dart';     // every token
import 'package:unspend/core/widgets/widgets.dart';  // every shared component
```

## Tokens

All tokens are in `lib/core/theme/`.

### Colour — `app_colors.dart`

Colours are a `ThemeExtension`, read with `context.colors`. There are four
palettes — light, dark, and an increased-contrast variant of each — and
Flutter selects one from the user's theme choice and the system's
*Increase Contrast* setting. A widget never picks a palette.

| Token | Use |
|---|---|
| `background` | Behind everything |
| `surface` | Cards, sheets, dialogs |
| `border` | Hairlines; track of switches and progress bars |
| `textPrimary`, `textSecondary` | Text |
| `accent` | The brand red as a **graphic**: icons, outlines |
| `accentText` | The brand red as **text** |
| `accentFill` / `onAccentFill` | The brand red as a **button** and the text on it |
| `accentContainer` | Soft red surface (active summary badge) |
| `success` / `successText` | Done, not blocking — graphic / text |
| `activeGradient` | Summary card while something is active |

Three rules keep text readable in every theme:

1. **A colour used as text goes through `colors.readable(color)`.** Profiles
   come in nine colours; amber on white or indigo on black are not readable
   as they are. `readable` keeps the hue and moves the lightness until the
   text reaches WCAG AA (4.5:1), or AAA (7:1) with increased contrast.
2. **A colour used as a button goes through `colors.filled(color)`**, which
   returns the fill and the text colour to put on it (white on a slightly
   darkened fill, or black on orange and amber).
3. **Tints use `AppOpacity`**, never a literal alpha: `wash` (card
   background), `tint` (badges, chips), `outline` (highlighted border),
   `disabled`.

`test/core/theme_test.dart` checks every palette and every profile colour
against these targets.

### Type — `app_typography.dart`

Read with `context.text`. Styles carry the primary text colour; change it with
`.tone(color)`, make it semibold with `.strong`, give paragraphs air with
`.relaxed`.

| Style | Size / weight | Use |
|---|---|---|
| `display` | 40 bold, fixed-width digits | Cooldown countdown |
| `numeral` | 32 bold | Numbers being entered |
| `hero` | 26 bold | Onboarding headline |
| `screenTitle` | 24 bold | Name at the top of a screen |
| `title` | 20 bold | Sheet and page titles |
| `heading` | 18 semibold | Section and dialog titles |
| `subheading` | 16 semibold | Card titles, primary buttons |
| `label` | 15 semibold | Row titles |
| `bodyLarge` | 16 | Typed text, list rows |
| `body` | 14 | Running text |
| `bodySmall` | 13 | Descriptions |
| `caption` | 12 | Hints, counters, badges |
| `micro` | 11 | Labels in small chips and tiles |

Text follows the system text size from 0.9× to 2× (`AppTextScale`). Never
fix a height around text; let it wrap.

### Space, shape, size — `app_spacing.dart`, `app_radius.dart`, `app_sizes.dart`

- **`AppSpacing`**: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 ·
  xxxl 32 · huge 40`. A 4-point grid.
- **`Gap`**: ready-made gaps, `Gap.vMd` in a Column, `Gap.hSm` in a Row.
- **`AppInsets`**: paddings with a meaning — `card`, `sheet`, `chip`,
  `field`, `button`, `screenGutter`.
- **`AppRadius`**: `xs 4` (bars) · `sm 8` (chips) · `md 12` (controls) ·
  `lg 16` (cards, sheets, dialogs) · `xl 20`. Containers are rounder than the
  controls inside them.
- **`AppSizes`**: icon sizes (`iconXs 14` … `iconIllustration 64`),
  `tapTarget 48`, `maxContentWidth 560`.

### Motion and haptics — `app_motion.dart`, `app_haptics.dart`

- **`AppDurations`**: `fast 150 ms` (selection), `medium 250 ms` (content
  appearing), `slow 300 ms` (pages). Always wrap them:
  `context.motion(AppDurations.medium)` returns no time at all when the user
  turned on *Reduce Motion*.
- **`AppHaptics`**: `selection()` a choice changed · `tap()` a button ·
  `confirm()` something took effect · `reject()` an action was refused. One
  meaning per pattern.

## Components

All in `lib/core/widgets/`. Reach for these before building anything new.

| Component | Use it for |
|---|---|
| `AppCard` | Any grouped content. `tint:` highlights it in a colour, `inset:` makes a quiet tile inside a sheet, `onTap:` makes it a button |
| `IconBadge` | An icon on a tile of its colour: cards, screen heroes, empty states |
| `AppButton.primary` / `.secondary` | The main action of a screen or sheet. Wraps long labels; `loading:` shows a spinner and ignores taps |
| `AppChip` | A tag or a value on a tint of its colour |
| `AppSwitch` | Every on/off switch |
| `AppProgressBar` | Progress (always alongside the number as text) |
| `AppLoader` | Content that is still loading |
| `SectionLabel` | Heading above a group of settings |
| `Reveal` | Content that appears or disappears; the rest slides instead of jumping |
| `AppDialog`, `DialogButton`, `showConfirmDialog` | Every dialog |
| `showAppSheet` | Every bottom sheet (scrolls, avoids the keyboard) |
| `showAppSnackBar` | Short messages |
| `PinField` | Entering a PIN |
| `ContentGutter` | Side padding of a scrolling screen (caps content at 560 pt) |
| `runGuarded` | Running anything the user started (see *Robustness*) |

Flutter's own widgets (`TextField`, `TextButton`, `ListTile`, `FilledButton`,
snack bars, dialogs, sheets) are styled once in `app_theme.dart`. Use them
without per-widget styling.

## Accessibility

These are requirements, and most are enforced by tests.

| Requirement | Enforced by |
|---|---|
| Nothing overflows on any iPhone, portrait or landscape, up to 2× text, in all five languages | `test/app/responsive_layout_test.dart` |
| Tap targets are at least 44 × 44 pt (`AppSizes.tapTarget` is 48) | `test/app/accessibility_test.dart` |
| Everything tappable has a label | same |
| Text contrast meets WCAG AA in all four themes | same, and `test/core/theme_test.dart` |
| Increase Contrast and Reduce Motion are honoured | `test/app/lifecycle_test.dart` |
| VoiceOver labels are localized — no English in `Semantics` | review |
| Colour is never the only signal (blocking shows a lock, not just red) | review |
| A switch says what it switches (`semanticLabel`), a row of text plus control is one node | review |

When you add a screen, sheet or dialog, **add a scene for it to the layout
matrix** and, if it has controls, to the accessibility test.

## Robustness

- **The user never sees a code or an exception.** Screen Time refusals map to
  a sentence in `screenTimeErrorMessage`; anything else ends in "Something
  went wrong. Please try again."
- **Everything the user starts runs in `runGuarded`** (or a helper from
  `profile_actions.dart`, which does). A failure nobody anticipated is logged
  and answered, never silently swallowed and never a stuck spinner.
- **Sheets and dialogs do not stack.** `showAppSheet`, `showConfirmDialog`,
  `showPinGate` and `showPinSetupDialog` ignore a request that arrives while
  something is already in front (`isFrontmost`), so a double tap opens one.
- **Never treat a failed read as "nothing there".** An unreadable Keychain is
  not "no PIN"; a failed sync is not "nothing active".
- **Busy buttons say so**: pass `loading:` to `AppButton` and reset it in a
  `finally`.

`test/app/robustness_test.dart` covers these.

## Constants

Values with a meaning are named once, where they belong:

| What | Where |
|---|---|
| Keys under which anything is stored | `lib/core/storage_keys.dart` (`PrefKeys`, `SecureKeys`) |
| Method, argument, reply and error names of the native bridge | `screen_time_contract.dart` (Dart), `ChannelContract.swift` (iOS) and `ChannelContract.kt` (Android) — change all three together |
| Limits and defaults of a profile (name length, usage limit range, default schedule) | `BlockerProfile`, `ShieldPolicy` |
| PIN rules (length, attempts, lockout) | `PinRepository` |
| Cooldown length | `cooldownDurationProvider` |
| User-facing text | `lib/core/constants/strings.dart`, all five languages |

## Recipes

**A new screen**: `Scaffold` (no background colour — the theme has it) →
`SafeArea` → `ContentGutter` → a scroll view padded with the gutter. Compose
from components. Add it to the layout matrix.

**A new component**: put it in `lib/core/widgets/`, export it from
`widgets.dart`, read colours and text from `context`, wrap durations in
`context.motion`, give it a doc comment that says when to use it, add it to
the table above and to `test/core/widgets_test.dart`.

**A new colour**: add the field to `AppColors` with a value in all four
palettes, to `copyWith` and `lerp`, and a contrast check to `theme_test.dart`
if it is used for text.

**A new string**: add the getter to `S` and to all five languages.
`test/core/strings_test.dart` fails if one is missing.

**A new stored value**: add its key to `storage_keys.dart`; never rename an
existing key without a migration.

**A new native call**: add the names to the three contract files, the
method to `ScreenTimeDatasource`, its implementation, the fake, a case to
`method_channel_screen_time_datasource_test.dart`, and the handler on both
native sides (`ScreenTimeChannel.swift`, `ScreenTimeChannel.kt`).

**Something that differs between iPhone and Android**: read
`appPlatformProvider` (never `Platform` or `defaultTargetPlatform` in a
widget — tests could not switch it). Wording that names the platform's way
of blocking gets an override in `strings_android.dart`; add a scene for the
Android variant to the layout matrix.
