# TestFlight Setup

Everything in this doc is one-time user-side work in Apple's web consoles.
Once it's done, the local scripts (`scripts/archive.sh` → `scripts/export-ipa.sh`
→ `scripts/upload-testflight.sh`) handle every subsequent upload.

**Status today (2026-05-10):**

| Step | Status |
|---|---|
| App Icon (1024×1024) | ✅ Generated programmatically (`scripts/render-icon.swift`) |
| Bundle IDs | ✅ `com.lukesteuber.mandaza`, `com.lukesteuber.mandaza.widgets`, `com.lukesteuber.mandaza.tv` |
| Team ID | ✅ `596T7J7FB6` |
| App Group entitlement | ✅ `group.com.lukesteuber.mandaza` |
| Photos permission usage string | ✅ |
| Export compliance flag | ✅ `ITSAppUsesNonExemptEncryption = false` |
| Privacy nutrition label | ⏳ Needs setting in App Store Connect (we collect nothing) |
| Distribution archive | ✅ Local archive works |
| Distribution provisioning profile | ❌ Needs App Store Connect app record first |
| TestFlight beta review | ❌ Submitted after first upload |
| Public TestFlight link | ❌ Generated after beta review passes |
| **tvOS app** (`com.lukesteuber.mandaza.tv`) | ⏳ Separate App Store Connect record + upload (see below) |
| Microphone permission usage string (1.3, music responsivity) | ✅ On iOS + watchOS targets |
| Apple Watch companion app | ✅ Ships embedded in the iOS build (`WKCompanionAppBundleIdentifier` set); gets its own `APP_WATCH_ULTRA` screenshot set in the iOS listing, not a separate record |

## tvOS (MandazaTV) — App Store Connect & upload

The Apple TV app uses bundle id **`com.lukesteuber.mandaza.tv`** (not the iOS app’s id). You need a **second app** in App Store Connect for tvOS, with its own TestFlight / App Review track.

### A. Developer Portal (Identifiers)

1. Confirm an **App ID** exists for `com.lukesteuber.mandaza.tv` with **App Groups** enabled and **`group.com.lukesteuber.mandaza`** checked (same group as iOS — see [PROVISIONING.md](PROVISIONING.md)).
2. Register a physical Apple TV for **development** if you need on-device debugging (optional for store upload).

### B. App Store Connect — new tvOS app

1. **My Apps** → **+** → **New App**
2. **Platforms**: **tvOS** (not iOS).
3. **Name**: Mandaza (or “Mandaza TV” if the plain name is taken).
4. **Primary Language**: English (U.S.)
5. **Bundle ID**: `com.lukesteuber.mandaza.tv`
6. **SKU**: e.g. `mandaza-tv-001` (unique; not user-visible)
7. **Privacy** → same as iOS: **Data collected: None**, same **Privacy Policy URL** as the iOS app.

### C. Build, export, upload (command line)

Same API key and `ASC_API_ISSUER` as iOS ([step 5](#5-generate-an-app-store-connect-api-key)). Then:

```bash
scripts/archive-tvos.sh        # build/MandazaTV.xcarchive
scripts/export-ipa-tvos.sh     # build/export-tvos/MandazaTV.ipa
scripts/upload-testflight.sh --tvos   # uses altool --type appletvos
```

`CFBundleVersion` is still driven by `git rev-list --count HEAD` so iOS and tvOS builds stay in sync numerically if you deploy from the same commit.

### D. TestFlight / review notes for tvOS

- **What to test:** fullscreen mandala, **Play/Pause** = new pattern, **Menu** = show/hide dock, Zen sheet from dock, deep link `mandaza://seed/<UUID>` if you test from iOS handoff.
- **No Photos / no widgets** on tvOS — reviewers should not expect iOS-only strings.

## One-time user steps

### 1. Register App ID with App Groups capability

→ https://developer.apple.com/account/resources/identifiers/list

For **each** of these App IDs:
- `com.lukesteuber.mandaza`
- `com.lukesteuber.mandaza.widgets`
- `com.lukesteuber.mandaza.tv` (tvOS — App Groups must match iOS)

Either confirm it exists (Xcode likely auto-registered during dev signing) or
click `+` → App IDs → App → fill in:
- **Description**: "Mandaza" / "Mandaza Widgets"
- **Bundle ID**: explicit value above
- **Capabilities**: tick **App Groups**

### 2. Register the App Group

→ https://developer.apple.com/account/resources/identifiers/list/applicationGroup

Click `+` → App Groups → fill in:
- **Description**: "Mandaza App Group"
- **Identifier**: `group.com.lukesteuber.mandaza`

Then for **each** App ID (Mandaza and MandazaWidgets) go back to its detail
page → Capabilities → App Groups → **Configure** → tick
`group.com.lukesteuber.mandaza`.

### 3. Create the app in App Store Connect

→ https://appstoreconnect.apple.com/apps

Click `+` → New App → fill in:
- **Platforms**: iOS
- **Name**: Mandaza
- **Primary Language**: English (U.S.)
- **Bundle ID**: `com.lukesteuber.mandaza` (should appear in the dropdown after step 1)
- **SKU**: `mandaza-001` (any unique identifier; not user-visible)
- **User Access**: Full Access

After creation, in the new app's left sidebar:

- **App Information**:
  - **Subtitle**: "Generative ambient mandalas" (or your preferred copy)
  - **Category**: Graphics & Design (primary), Lifestyle (secondary)
  - **Content Rights**: Tick "Does not contain, show, or access third-party content"
- **Privacy** → **App Privacy** → **Get Started**:
  - **Data Types Collected**: select **None**. (Mandaza collects zero data.)
  - **Privacy Policy URL**: required. Quickest: enable GitHub Pages on the
    `lukeslp/mandaza` repo and host `PRIVACY.md` (see step 4).

### 4. Privacy policy (one file in the repo)

Mandaza collects no data. A two-paragraph policy is sufficient. From the
repo root:

```bash
mkdir -p docs
cat > docs/index.md <<'EOF'
# Mandaza — Privacy Policy

Mandaza does not collect, store, or transmit any personal data. The app
runs entirely on your device. It makes no network requests, includes no
analytics SDKs, and does not create an account.

The only system permission Mandaza requests is one-time write access to
your Photo Library, used solely to save the image you tap "Save"
on. No image data is sent off-device.

For questions: luke@lukesteuber.com
EOF
```

Then on GitHub:
- Repo Settings → Pages → Source: deploy from branch → `main` / `/docs`
- Wait ~30s. Privacy URL: `https://lukeslp.github.io/mandaza/`

Paste that URL into App Store Connect → App Privacy → Privacy Policy URL.

### 5. Generate an App Store Connect API key

→ https://appstoreconnect.apple.com/access/integrations/api

Click `+` (next to "Active") → fill in:
- **Name**: "Mandaza uploads" (or any descriptive name)
- **Access**: **App Manager** is sufficient

Click **Generate**, then **Download** the `.p8` file. **You can only download it
once** — if you lose it you'll need to regenerate.

Save it locally:

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
```

Then on the API page, copy the **Issuer ID** (UUID at top) and add it to your shell:

```bash
echo 'export ASC_API_ISSUER="<paste-issuer-uuid-here>"' >> ~/.zshrc
source ~/.zshrc
```

### 6. First upload

```bash
scripts/archive.sh           # runs unit tests, then archives (~few min)
scripts/export-ipa.sh        # ~30 seconds — this is the step that needs the App Store record
scripts/upload-testflight.sh # ~5 minutes (Apple is doing notarization + scanning)
```

`scripts/archive.sh` runs `xcodebuild test` on the **iPhone 17** simulator first (set `SKIP_TESTS=1` to skip for a local-only archive). `scripts/archive-tvos.sh` runs a Debug **tvOS Simulator** build smoke before the Release archive (same `SKIP_TESTS=1` escape hatch).

Apple emails you when the build finishes processing (~10-30 min). Once it does:

- App Store Connect → My Apps → Mandaza → TestFlight → confirm the build appears
- Fill in TestFlight metadata: **Test Information** (what to test, demo notes, contact email)
- **Export Compliance**: confirm "No encryption" (matches `ITSAppUsesNonExemptEncryption=false` in Info.plist)
- Submit for **Beta App Review** (Apple reviews TestFlight builds before public links go live; this is usually faster than App Store review — hours, not days)

### 7. Enable public TestFlight link

After Beta App Review approves the build:

App Store Connect → Mandaza → TestFlight → **Public Link** → toggle on.
Apple generates a `https://testflight.apple.com/join/<code>` URL. Anyone with
the link can install the beta.

Optional cap: set a max-tester count (default is 10,000).

## Subsequent uploads

After the first upload works once, every subsequent build is just:

```bash
scripts/archive.sh && scripts/export-ipa.sh && scripts/upload-testflight.sh
```

Apple TV (same API key; separate App Store Connect app — see [tvOS section](#tvos-mandazatv--app-store-connect--upload)):

```bash
scripts/archive-tvos.sh && scripts/export-ipa-tvos.sh && scripts/upload-testflight.sh --tvos
```

- `CFBundleVersion` auto-increments from `git rev-list --count HEAD` so every
  build is unique without manual bumping.
- Marketing version (`0.2.0`, etc.) is held in `project.yml` and changes only
  when you decide.

## Troubleshooting

**Export fails with "No profiles for 'com.lukesteuber.mandaza' were found"**
→ The App Store Connect record doesn't exist yet (step 3) or Xcode hasn't
synced provisioning yet. Open Xcode → Settings → Accounts → select your
team → Download Manual Profiles, or just retry after step 3 is complete.

**Upload fails with "Invalid Bundle: Missing required icon file"**
→ Re-run `swift scripts/render-icon.swift` to regenerate the icon, then archive
again.

**Upload succeeds but Apple emails "Missing Compliance"**
→ App Store Connect → TestFlight → build → click the warning → confirm
"Does not use non-exempt encryption" → Save.

**Beta App Review rejects with "App crashes on launch"**
→ The App Group `group.com.lukesteuber.mandaza` may not be registered for
the distribution profile. Re-do step 2, regenerate the distribution
provisioning profile from developer.apple.com → Profiles, download it,
and re-archive.

**Long-press regenerate gesture doesn't work for Beta reviewer**
→ It's auto-disabled when VoiceOver or Switch Control is active (by design).
Reviewers may have VO on. The Regenerate button in the bar works
unconditionally — make sure the demo notes mention the button as the
canonical way to advance.

## What's NOT in this doc

- App Store Marketing assets (screenshots, description, keywords) — for full
  App Store release, not TestFlight. TestFlight only requires the metadata
  fields listed above.
- StoreKit / IAP — Mandaza has no paid tier yet.
- Custom symbols / SF Pro overrides — system fonts only.
- CI automation (GitHub Actions / Xcode Cloud) — `scripts/*.sh` are
  shell-only; wrap them with whatever CI you prefer when ready.
