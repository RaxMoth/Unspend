# App Review Notes & Questionnaire Answers

The "Notes" field in App Store Connect → Version → App Review Information.
This is where you proactively head off review questions.

---

## Review Notes (paste into "Notes")

```
ABOUT UNSPEND

Unspend blocks distracting apps with rules the user sets (schedule, daily
limit, task list). It can be used in two ways, chosen on first launch:

• "This is my iPhone" — self-control. The user blocks apps for themselves.
  Uses Family Controls authorization for .individual.
• "This is my child's iPhone" — parental control. A parent or guardian
  approves the app with their Apple Account on a child's device in Family
  Sharing and decides what is blocked. Uses authorization for .child.

To review without a child account, choose "This is my iPhone"; every
feature is the same in both modes.

TESTING INSTRUCTIONS

1. On first launch the app shows a short introduction. Choose "This is my
   iPhone" when asked who uses the phone. The last page asks for Screen Time
   access: tap "Allow access" and approve the system prompt. (If skipped, a
   banner on the dashboard offers it again.)
2. Tap "+" on the dashboard and name a profile.
3. On the profile screen tap "Select Apps to Block" — Apple's
   FamilyActivityPicker appears. Select 1–2 apps (e.g. Safari, Mail) and
   tap "Save". The app then offers to set a PIN; choose one (e.g. 1234) or
   tap "Not now".
4. Tap "Activate Shield". The selected apps are now blocked by iOS. Opening
   one shows our shield screen.
5. To unblock: tap "Deactivate Shield" (or the switch on the dashboard). A
   5-minute cooldown runs; afterwards enter the PIN (or confirm, if no PIN
   was set).
6. Optional: on an inactive profile, switch on Schedule, Usage Limit or
   Task Mode. The rules combine: the apps are blocked while any of them
   applies.
7. Note: while a profile is active, iOS does not offer "Delete App" for any
   app (uninstall protection, ManagedSettings denyAppRemoval). It can be
   switched off under Settings (gear icon) → Uninstall protection, and it
   ends when the last profile is deactivated.

WHY WE USE FAMILY CONTROLS

We use Apple's FamilyControls + ManagedSettings + DeviceActivity frameworks
to enforce blocks at the OS level — the Apple-sanctioned way to build both
a focus app and a parental-control app. On the user's own phone we request
authorization for .individual; on a child's phone a parent approves
authorization for .child. The only restrictions we apply are shields on the
apps, categories and websites the user (or parent) selected, and, while a
profile is active, the restriction on deleting apps.

PRIVACY

We collect zero user data. All storage is on-device (SharedPreferences,
iOS Keychain). No network requests are made for user data. No analytics,
no tracking, no ads, no third-party SDKs.

DEMO ACCOUNT

None needed — the app has no login.

LANGUAGES

English, German, Spanish, French, Croatian. The app starts in the device
language; it can be changed in the app under Settings (gear icon) → Language.
The shield screen follows the same choice.

DEVICES

iPhone only, portrait and landscape.

CONTACT

If you have questions during review please reach out to: support@unspend.app
We respond within 24 hours.
```

---

## App Privacy Questionnaire

App Store Connect → App Privacy → "Data Types Collected".

Answer for each category: **We do not collect this data**.

- Contact Info: Not collected
- Health & Fitness: Not collected
- Financial Info: Not collected
- Location: Not collected
- Sensitive Info: Not collected
- Contacts: Not collected
- User Content: Not collected
- Browsing History: Not collected
- Search History: Not collected
- Identifiers: Not collected
- Purchases: Not collected
- Usage Data: Not collected
- Diagnostics: Not collected
- Other Data: Not collected

Resulting privacy label: **Data Not Collected**.

---

## Export Compliance (`ITSAppUsesNonExemptEncryption`)

Already set to `false` in `Info.plist`. App Store Connect will *not* ask
the encryption questionnaire when uploading.

If asked anyway:
- Does your app use encryption? → **Yes** (incidentally — HTTPS, the system Keychain).
- Is your app exempt? → **Yes**.
- Reason for exemption: *"App uses only encryption that is exempt from export
  compliance under §740.17(b) of the U.S. Export Administration Regulations
  (standard cryptography for authentication / digital signatures). The app
  uses iOS Keychain (standard system crypto) and SHA-256 hashing for PIN
  verification."*

---

## Content Rights

App Store Connect → "Content Rights Information".

- Does your app contain, show, or access third-party content?
  → **No** (the FamilyActivityPicker shows installed apps to the user, but
  those tokens never leave Apple's framework — we don't access third-party
  content programmatically).

---

## Advertising Identifier (IDFA)

App Store Connect → "Does this app use the Advertising Identifier (IDFA)?"
- → **No**

(`NSUserTrackingUsageDescription` is intentionally absent from Info.plist
for this reason.)

---

## Common Review Rejections to Watch For

Family-Controls apps occasionally get hit with these. Pre-emptive responses:

**"Your app uses Family Controls but doesn't appear to need it."**
> Family Controls is the only Apple-sanctioned way to apply system-level
> app shields. Unspend's core functionality is enforcing user-chosen blocks
> at the OS level — without this entitlement the app cannot function.

**"Your app uses Family Controls for purposes other than parental controls."**
> Family Controls is documented by Apple for both parental controls AND
> self-blocking productivity / wellness apps. Apple's own Screen Time
> feature uses the same APIs for self-blocking. On the user's own phone we
> use the Individual authorization mode
> (`AuthorizationCenter.shared.requestAuthorization(for: .individual)`),
> the documented mode for self-application; on a child's phone a parent
> approves with `.child`, the documented mode for parental controls.

**"Users cannot delete apps while your app is active."**
> That is the uninstall protection (`ManagedSettings` `denyAppRemoval`),
> which keeps a running block from being bypassed by deleting Unspend. iOS
> offers this restriction only for all apps at once. It applies only while
> a profile is active, is explained in the app, and can be switched off
> under Settings → Uninstall protection.

**"We need more information about how Family Controls is used."**
> See "Why we use Family Controls" in our review notes above. Happy to
> provide a screen recording — please email support@unspend.app.
