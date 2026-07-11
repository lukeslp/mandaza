# Mandaza — Apple signing & provisioning

This repo already sets **Automatic signing** and **Development Team** in XcodeGen ([project.yml](project.yml)). Anything that says *“your team has no devices”* or *“no provisioning profile”* is resolved in **Apple Developer** + **Xcode** with your Apple ID — not in Git.

## Values from this project (use as reference)

| Field | Value |
|--------|--------|
| **Development Team ID** | `596T7J7FB6` |
| **App Group** (entitlements) | `group.com.lukesteuber.mandaza` |
| **iOS/tvOS app** | `com.lukesteuber.mandaza` |
| **iOS widgets** | `com.lukesteuber.mandaza.widgets` |
| **watchOS app** | `com.lukesteuber.mandaza.watchkitapp` |
| **Unit tests** | `com.lukesteuber.mandaza.tests` |

Portal: [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/)

---

## A. Run on Simulator only (no physical device)

1. Open `Mandaza.xcodeproj` (after `xcodegen`).
2. Scheme **Mandaza** → destination **iPhone / Apple TV … Simulator** (not a gray “Any … Device”).
3. **Signing & Capabilities** for that target → **Automatically manage signing** → Team **Luke Steuber** (or the team for `596T7J7FB6`).

Simulator builds do **not** require a registered Apple TV.

---

## B. Run Mandaza on a physical Apple TV (fixes “no devices” / “no profile”)

Apple only creates an **tvOS App Development** profile if your team has **at least one registered Apple TV** (or you add its UDID manually).

### 1) Register the Apple TV

1. On **Apple TV**: **Settings → General → Apple TV** (or **Remotes and Devices**) — note **serial** if needed; for UDID Apple documents vary by tvOS version. Easiest: use **Xcode**.
2. **Mac**: **Xcode → Window → Devices and Simulators** → **Devices** tab.
3. Connect the Apple TV (USB-C to Mac on supported models, or **pair over network** per [Apple’s pairing doc](https://developer.apple.com/documentation/xcode/pairing-and-unlocking-apple-tv)).
4. When the device appears, select it — Xcode shows **Identifier (UDID)**. Copy it.
5. Browser: [Devices](https://developer.apple.com/account/resources/devices/list) → **+** → **tvOS** → paste **UDID**, name the device → **Continue** → **Register**.

Until this step succeeds, you will keep seeing *“Your team has no devices from which to generate a provisioning profile”*.

### 2) Shared App ID for tvOS

The unified target uses the same **App ID** as iOS,
`com.lukesteuber.mandaza`, but its tvOS build does not include the App Group
entitlement. tvOS settings are local `UserDefaults.standard` values.

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** (or select existing).
2. Edit the **App ID** for **`com.lukesteuber.mandaza`** and ensure tvOS is enabled for it.
3. Do not add an App Group entitlement to the tvOS build configuration.

If the App Group identifier does not exist yet: [Identifiers → App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup) → **+** → `group.com.lukesteuber.mandaza`.

### 3) Xcode on the Mandaza target

1. Select **Mandaza** target → **Signing & Capabilities**.
2. **Team**: same team as `596T7J7FB6`.
3. **Automatically manage signing**: ON.
4. Run destination: your **physical Apple TV** (not Simulator).

Xcode should create or refresh the tvOS development profile for `com.lukesteuber.mandaza`. If not: **File → Workspace Settings** (or Project) → **Accounts** → download profiles; or toggle **Automatically manage signing** off/on.

---

## C. iOS device / widget extension

Same pattern: register each iPhone, iPad, and Apple Watch used for development.
Ensure App IDs for `com.lukesteuber.mandaza`,
`com.lukesteuber.mandaza.widgets`, and
`com.lukesteuber.mandaza.watchkitapp` include the
`group.com.lukesteuber.mandaza` App Group. The widget and watch App IDs must
exist independently even though the watch companion ships inside the iOS app.

---

## D. Distribution (TestFlight / App Store)

- **Archive** still needs **Distribution** certificates and **App Store** provisioning profiles — Xcode **Organizer** + **Distribute App** usually handles this with automatic signing once the shared app record exists in App Store Connect.

---

## Quick links

| Task | URL |
|------|-----|
| Devices | https://developer.apple.com/account/resources/devices/list |
| Identifiers (App IDs) | https://developer.apple.com/account/resources/identifiers/list |
| App Groups | https://developer.apple.com/account/resources/identifiers/list/applicationGroup |
| Profiles (inspect) | https://developer.apple.com/account/resources/profiles/list |

---

## What cannot be automated from this repo

- Logging into **developer.apple.com** with your Apple ID  
- Registering **UDIDs** without you (or Xcode) providing them  
- Creating **certificates** on your Mac’s Keychain (Xcode does this when you pick a Team)

After devices and App IDs are correct, **no further `project.yml` changes** are usually required.
