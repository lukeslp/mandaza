# Mandaza Clocks / Music Reactivity / Tilt Parallax Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give mandaza expanded clock styles, genuinely impactful music reactivity, and device-tilt parallax, then produce framed App Store hero screenshots.

**Architecture:** All shared state lives in `MandazaCore/MandazaSettings.swift` (an `@Observable` App-Group-backed store with write-through `didSet` props and a `Key` enum). Rendering is `MandazaCore/MandazaCanvas.swift` (a `TimelineView`/`Canvas` reading an optional `MandazaModulationSource`). The app shell is `Mandaza/ContentView.swift`. New cross-cutting pieces: a `TiltProvider` (CoreMotion) and expanded `ZenClock*` enums/forms. Music reactivity is applied in the canvas presentation transform, not the engine, so geometry stays stable.

**Tech Stack:** Swift 6, SwiftUI, xcodegen, CoreMotion, AVFoundation (existing AudioReactor), MandazaCore SPM package (iOS 17 / watchOS 10 / tvOS 17).

## Global Constraints

- Swift 6 language mode; MandazaCore platforms: `.iOS(.v17), .tvOS(.v17), .watchOS(.v10)`.
- MandazaCore's `MandazaEngine` has `#if canImport(UIKit)` UIKit code — it does NOT build for macOS. No macOS render path.
- All new persisted settings go through `MandazaSettings` write-through props + a new `Key` case + hydration in `init()`.
- `#if os(tvOS)` guards: NO CoreMotion, NO mic/AudioReactor references reachable on tvOS.
- App Store copy rule: never "AI" as a noun / "AI-powered". Honest claims only.
- Screenshot sizes: iPhone 6.9" = **1320×2868** (capture on iPhone 17 Pro Max sim); Apple Watch Ultra = 422×514 (reuse existing).
- Ship target: editable **iOS v1.3** (`com.lukesteuber.mandaza`), `PREPARE_FOR_SUBMISSION`. Stage only — **never submit** in this plan.
- Commit after every task. Build for the sim between phases: `xcodebuild build -project Mandaza.xcodeproj -scheme Mandaza -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`.

---

## Phase 1 — Settings foundation (enums + props)

### Task 1: Expand clock enums + add new settings props

**Files:**
- Modify: `MandazaCore/MandazaSettings.swift`
- Test: `MandazaCore/Tests/MandazaCoreTests/SettingsTests.swift` (create if absent)

**Interfaces:**
- Produces:
  - `enum ZenClockPosition: String, CaseIterable, Codable, Sendable { case top, upperThird, center, lowerThird, topLeading, topTrailing, bottomLeading, bottomTrailing }`
  - `enum ZenClockFontStyle: String, CaseIterable, Codable, Sendable { case system, rounded, monospaced, serif, condensed }`
  - `enum ZenClockForm: String, CaseIterable, Codable, Sendable { case digital, stacked, editorial }`
  - `enum ZenTiltIntensity: String, CaseIterable, Codable, Sendable { case off, subtle, pronounced }`
  - New `MandazaSettings` props: `var musicResponsivity: Bool`, `var reactivity: Double`, `var zenClockSizeScale: Double`, `var zenClockFormRaw: String` (+ typed `zenClockForm`), `var zenTiltIntensityRaw: String` (+ typed `zenTiltIntensity`).

- [ ] **Step 1: Write failing tests** — defaults + round-trip.

```swift
import XCTest
@testable import MandazaCore

@MainActor
final class SettingsNewFieldsTests: XCTestCase {
    func testDefaults() {
        let s = MandazaSettings.shared
        XCTAssertEqual(s.reactivity, 0.35, accuracy: 0.001)
        XCTAssertTrue(s.musicResponsivity)          // on by default (iOS/watchOS)
        XCTAssertEqual(s.zenTiltIntensity, .subtle)
        XCTAssertEqual(s.zenClockForm, .digital)
    }
    func testClockPositionCasesExpanded() {
        XCTAssertEqual(ZenClockPosition.allCases.count, 8)
        XCTAssertEqual(ZenClockFontStyle.allCases.count, 5)
    }
}
```

- [ ] **Step 2: Run — expect FAIL** (`property/case not found`).
  Run: `swift test --package-path MandazaCore --filter SettingsNewFieldsTests`

- [ ] **Step 3: Implement** — extend the two enums; add `ZenClockForm` + `ZenTiltIntensity` near them; add `Key` cases (`musicResponsivity, reactivity, zenClockSizeScale, zenClockFormRaw, zenTiltIntensityRaw`); add write-through props following the existing `didSet { write(...) }` pattern; hydrate in `init()` with defaults `reactivity: 0.35`, `musicResponsivity: true`, `zenClockSizeScale: 1.0`, `zenClockFormRaw: ZenClockForm.digital.rawValue`, `zenTiltIntensityRaw: ZenTiltIntensity.subtle.rawValue`; add typed computed accessors mirroring `zenClockFontStyle`/`zenClockPosition`.

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit** — `git add -A MandazaCore && git commit -m "feat(settings): clock forms/positions/styles + music+tilt settings"`

---

## Phase 2 — Interaction model (Zen owns center button; music folds in)

### Task 2: Center dock button toggles Zen; remove music icon + long-press

**Files:**
- Modify: `Mandaza/ContentView.swift` (dock/controlBar center button; remove music icon), `Mandaza/MusicModeControls.swift` (delete `MusicModeLongPress`).
- Modify: `Mandaza/SettingsView.swift` — add a "Music responsivity" section (toggle bound to `settings.musicResponsivity` + a `Slider` for `settings.reactivity`, 0…1). On tvOS the section is hidden (`#if !os(tvOS)`).

**Interfaces:**
- Consumes: `settings.musicResponsivity`, `settings.reactivity`, `settings.zenMode`.
- Produces: `func toggleZen()` on ContentView that sets `settings.zenMode.toggle()` and starts/stops the reactor per the rule below.

- [ ] **Step 1**: Replace the center dock button's action with `toggleZen()`; update its icon/label to reflect `settings.zenMode` (e.g. `sparkles` ↔ `sparkles.slash` / "Zen"). Keep New-pattern reachable from another dock control.
- [ ] **Step 2**: `toggleZen()` — on entering Zen, `if settings.musicResponsivity, AudioReactor.micAvailable { reactor.start() }`; on leaving, `reactor.stop()`. (`micAvailable` = `#if os(tvOS) false #else true #endif` for now; real permission check can refine later.)
- [ ] **Step 3**: Delete `MusicModeLongPress` + its `.musicModeLongPress()` call site and the dedicated music footer icon. Keep `MANDAZA_MUSIC_DEMO` behavior: when set, `toggleZen()`/launch forces Zen + reactor via the demo source.
- [ ] **Step 4**: Add the Settings "Music responsivity" section (toggle + reactivity slider).
- [ ] **Step 5**: Build the sim app; launch; verify center button toggles Zen and the music icon is gone.
  Run: `xcodebuild build -project Mandaza.xcodeproj -scheme Mandaza -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
- [ ] **Step 6: Commit** — `git commit -am "feat(zen): center button toggles Zen; music folds into Zen via setting"`

---

## Phase 3 — Music reactivity (the real fix)

### Task 3: Speed + scale-throb + glow burst from modulation, scaled by reactivity

**Files:**
- Modify: `MandazaCore/MandazaCanvas.swift` (modulation region ≈115-215).
- Modify: `MandazaCore/MandazaModulation.swift` (add a `beatEnv` decay helper if needed) / `AudioReactor` (crisper onset if `beatPulse` too soft).
- Test: `MandazaCore/Tests/MandazaCoreTests/ReactivityTests.swift`

**Interfaces:**
- Consumes: `MandazaModulation { level, bass, mid, treble, beatPulse, colorPhaseMs }`, `settings.reactivity` (passed into the canvas as `reactivity: Double`).
- Produces: pure helpers `func speedFactor(level: Double, reactivity r: Double) -> Double` (`1 + r*1.5*level`), `func scaleThrob(beatEnv: Double, reactivity r: Double) -> Double` (`1 + r*0.86*beatEnv`, so r=1→~1.86 raw but the canvas applies it as a bounded ≤1.3 pump — clamp in the helper: `min(1 + r*0.30*beatEnv/max(r,0.001)... )` → simpler: return `1 + (0.06 + r*0.24) * beatEnv` giving r=0.35→~1.06, r=1→~1.30).

- [ ] **Step 1: Failing tests** for the pure math:

```swift
func testSpeedFactorIdentityAtSilence() {
    XCTAssertEqual(speedFactor(level: 0, reactivity: 0.35), 1.0, accuracy: 1e-9)
}
func testSpeedFactorScalesWithLevel() {
    XCTAssertEqual(speedFactor(level: 1, reactivity: 1.0), 2.5, accuracy: 1e-9)
}
func testScaleThrobDefaultIsGentle() {
    XCTAssertEqual(scaleThrob(beatEnv: 1, reactivity: 0.35), 1.06, accuracy: 0.005)
}
func testScaleThrobMaxIsDramatic() {
    XCTAssertEqual(scaleThrob(beatEnv: 1, reactivity: 1.0), 1.30, accuracy: 0.005)
}
func testReactivityZeroIsInert() {
    XCTAssertEqual(scaleThrob(beatEnv: 1, reactivity: 0), 1.0, accuracy: 1e-9)
    XCTAssertEqual(speedFactor(level: 1, reactivity: 0), 1.0, accuracy: 1e-9)
}
```

- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement** the two free helpers in MandazaCanvas (or a small `Reactivity.swift`), formulas:
  - `speedFactor(level:reactivity:) = 1 + reactivity * 1.5 * max(0, min(1, level))`
  - `scaleThrob(beatEnv:reactivity:) = 1 + (0.06 + reactivity * 0.24) * clamp01(beatEnv) - (reactivity == 0 ? (0.06)*clamp01(beatEnv) : 0)` → simplest correct form: `reactivity == 0 ? 1 : 1 + (0.06 + reactivity*0.24)*clamp01(beatEnv)`.
- [ ] **Step 4**: Wire into the render: multiply the accumulated `timeMs` advance by `speedFactor(level, r)`; wrap the drawing transform with `ctx.scaleBy(scaleThrob(beatEnv, r))` about center; add glow burst (`shadowOpacity += r*0.2*beatEnv`). Derive `beatEnv` from `beatPulse` with a ~250ms release (store last-beat time in the source).
- [ ] **Step 5: Run tests — expect PASS.**
- [ ] **Step 6**: Visual check — launch with `SIMCTL_CHILD_MANDAZA_MUSIC_DEMO=1 SIMCTL_CHILD_MANDAZA_PALETTE=aurora`, capture, confirm visible throb + speed.
- [ ] **Step 7: Commit** — `git commit -am "feat(music): beat scale-throb + glow + loudness speed, scaled by reactivity"`

---

## Phase 4 — Clocks (positions, styles, forms, robustness)

### Task 4: Render new positions + styles + size in ZenClockOverlay

**Files:**
- Modify: `MandazaCore/ZenClockOverlay*.swift` (the overlay view — locate via `grep -rl "struct ZenClockOverlay"`), `MandazaCore/ZenClockTypography.swift`.
- Test: `MandazaCore/Tests/MandazaCoreTests/ClockLayoutTests.swift`

**Interfaces:**
- Consumes: `ZenClockPosition` (8 cases), `ZenClockFontStyle` (5 cases), `ZenClockForm`, `zenClockSizeScale`.
- Produces: `func alignment(for: ZenClockPosition) -> Alignment`, `func fontDesign(for: ZenClockFontStyle) -> Font.Design?` (serif/condensed handled via `Font.system(...).width(.condensed)` / `.serif`), and form-specific subviews `DigitalClock`, `StackedClock`, `EditorialClock`.

- [ ] **Step 1: Failing tests** — `alignment(for:)` maps all 8 positions; `fontDesign(for:)` maps serif→.serif etc.; form switch returns the right view type marker.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** the alignment/design maps + the `ZenClockForm` switch producing `DigitalClock` (existing inline), `StackedClock` (HH over MM, large), `EditorialClock` (big hour + small minute/date). Apply `zenClockSizeScale` to base point sizes. Add a subtle text shadow always; honor `zenClockContainerOpacity` scrim.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5**: Add Settings controls (position picker, style picker, form picker, size slider) in `SettingsView` (and compact variants in `WatchSettingsView`).
- [ ] **Step 6**: Sim build + capture each form to eyeball legibility over the mandala.
- [ ] **Step 7: Commit** — `git commit -am "feat(clock): 8 positions, serif/condensed, stacked+editorial forms, size scale"`

Borrow note: adapt proportions from `~/workspace/ambient-time` stacked/editorial typographic treatments only — do not add a MandazaCore dependency on it.

---

## Phase 5 — Tilt parallax (net-new)

### Task 5: TiltProvider + layered parallax offsets

**Files:**
- Create: `MandazaCore/TiltProvider.swift`
- Modify: `Mandaza/ContentView.swift` (apply offsets to mandala + clock layers), `SettingsView`/`WatchSettingsView` (Off/Subtle/Pronounced picker).
- Test: `MandazaCore/Tests/MandazaCoreTests/TiltTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor @Observable final class TiltProvider { var offset: CGSize = .zero; func start(intensity: ZenTiltIntensity); func stop() }`
  - pure `func tiltOffset(pitch: Double, roll: Double, intensity: ZenTiltIntensity, viewSize: CGSize) -> CGSize` with clamping.

- [ ] **Step 1: Failing tests** — `tiltOffset` returns `.zero` for `.off`; clamps to a max fraction of viewSize for `.pronounced`; sign is opposite to roll (mandala shifts against tilt).
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** the pure function + a `CMMotionManager`-backed `TiltProvider`. `#if os(tvOS)` → `start` is a no-op, `offset` stays `.zero`. Max offset fractions: subtle ≈ 0.02, pronounced ≈ 0.05 of min(view w,h). Smooth with a low-pass filter.
- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5**: In ContentView, drive `TiltProvider` only while Zen visible + intensity≠off; apply `mandala.offset(offset)` and `clock.offset(offset * 0.5)` (shallower depth). Add the Settings picker.
- [ ] **Step 6**: watchOS: gate behind `#if os(watchOS)` using `CMMotionManager` device motion; verify it compiles for the MandazaWatch scheme.
- [ ] **Step 7: Commit** — `git commit -am "feat(tilt): CoreMotion parallax on iPhone+Watch, Off/Subtle/Pronounced"`

---

## Phase 6 — Framed hero screenshots + upload (stage only)

### Task 6: Capture, frame, upload to iOS v1.3

**Files:**
- Add captures under `screenshots/en-US/` (replace the 1206×2622 iPhone shots).
- Use `~/.claude/skills/app-store-ship/scripts/asc_ship.py`.
- Framing via `npx skills add ParthJadhav/app-store-screenshots` scaffold (a Next.js editor); export 1320×2868.

- [ ] **Step 1**: Build the Debug app to `build/dd-sim`; boot iPhone 17 Pro Max sim; capture 4-6 frames varying `SIMCTL_CHILD_MANDAZA_PALETTE` (aurora, ember, cyberpunk, vaporwave) and `SIMCTL_CHILD_MANDAZA_MUSIC_DEMO=1` for one mid-throb frame; one with an editorial clock. All must read 1320×2868.
- [ ] **Step 2**: Scaffold the framing editor (`npx skills add ParthJadhav/app-store-screenshots`), import the raw captures, add device frame + short honest promo headlines ("Generative mandalas, endlessly"; "Your art moves to the music"; "A living clock, your way"). Export the 1320×2868 iPhone set.
- [ ] **Step 3**: Stage into `screenshots/en-US/` (correct names/order); keep the 2 watch shots (422×514).
- [ ] **Step 4**: `source ~/.appstoreconnect/env.sh`; verify state: `python3 ~/.claude/skills/app-store-ship/scripts/asc_ship.py state com.lukesteuber.mandaza`. Confirm iOS v1.3 editable.
- [ ] **Step 5**: Upload: `asc_ship.py screenshots com.lukesteuber.mandaza IOS 1.3 screenshots/en-US`. Dedup via a spaceship keep-first pass if deliver races. Verify counts. **Do NOT submit.**
- [ ] **Step 6: Commit** — `git commit -am "chore(screenshots): framed 1320x2868 hero set for iOS 1.3"`

---

## Self-review notes

- Spec coverage: A→Task 2, B→Task 3, C→Tasks 1+4, D→Tasks 1+5, E→Task 6, foundation→Task 1. All spec sections covered.
- tvOS guards called out in Tasks 2/3/5. Watch handled in Tasks 4/5.
- Reactivity math has explicit test values (identity at silence, r=0 inert, default 1.06×, max 1.30×).
- Screenshots stage-only; never submit (Global Constraints + Task 6 Step 5).
