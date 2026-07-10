# Mandaza — clocks, music reactivity, tilt parallax (+ framed screenshots)

Date: 2026-07-09
Status: approved design, pre-implementation

A feature pass on the mandaza generative-mandala app (iOS + watchOS + tvOS;
engine in `MandazaCore`) ahead of new App Store hero screenshots. Four
workstreams, then marketing captures.

## Goals

1. **Zen Mode owns the center button; music folds into Zen.** The dock's large
   center button toggles Zen Mode. Zen enables music responsivity *only* when
   the setting is on and the platform has a mic. Remove the separate music
   footer icon and the long-press-on-New trigger.
2. **Music reactivity that actually reads** — beat-punch + flow. Beats drive a
   scale-throb + glow burst; loudness drives animation speed. One scalable
   `reactivity` intensity, minimalist default.
3. **Clocks, expanded but restrained** — more positions, more type styles, two
   new forms that suit the neon-line aesthetic, and legibility robustness.
   Borrow only what fits mandaza from `ambient-time`.
4. **Tilt parallax** (net-new) — CoreMotion attitude → layered parallax on
   iPhone + Apple Watch, with an Off / Subtle / Pronounced setting.
5. **Framed hero screenshots** — capture the improved visuals at 1320×2868 and
   frame them with device + promo copy via the `app-store-screenshots` tool.

Non-goals: porting ambient-time's full face engine; ornate clock faces (rings,
dials, word clocks); tvOS tilt/mic; changing the mandala generation algorithm.

## A. Zen Mode & the footer button

- **Center dock button** → `toggleZenMode()` (was "New"/long-press-for-music).
  The other dock actions (recents, settings, favorite, share, new-pattern) move
  to the surrounding dock buttons; "new pattern" keeps a control but is no
  longer the center's primary role. Center button label/icon reflects Zen state.
- **Entering Zen**: if `settings.musicResponsivity == true` AND
  `AudioReactor.micAvailable` (iOS/watchOS), start the reactor; else Zen is the
  clean fullscreen view. Leaving Zen always stops the reactor.
- **Remove**: `MusicModeLongPress` modifier + the dedicated music footer icon.
  The `MANDAZA_MUSIC_DEMO` screenshot hook stays (drives synthetic reactivity
  for captures) and now implies Zen + responsivity when set.
- **Settings** gains a **Music responsivity** section: a toggle (default on for
  iOS/watchOS, hidden/off on tvOS) + a **Reactivity** slider (0…1, default ~0.35
  "minimalist"). Persisted in `MandazaSettings` via the App-Group suite.

## B. Music reactivity (MandazaModulation → visuals)

Today `MandazaCanvas` (≈188-213) only maps modulation to line width, glow, and
color phase. Add the two missing sensations, all scaled by `settings.reactivity`
(`r`):

- **Flow (continuous speed):** the per-frame `advance(timeMs:)` delta is
  multiplied by `1 + r * k_speed * level` (k_speed ≈ 1.5). Louder → the mandala
  animates faster. Clamped so silence == current speed.
- **Punch (discrete scale-throb):** on a detected beat, a decaying envelope
  `beatEnv` (attack ~1 frame, release ~250 ms) scales the whole drawing about
  center by `1 + r * k_pulse * beatEnv` (k_pulse tuned so `r=1` ≈ 1.3×, default
  `r=0.35` ≈ 1.06×) and adds a glow burst (shadow radius/opacity bump).
- Existing line-width/color-phase mapping stays but is also scaled by `r` so the
  single slider governs the whole feel; `r=0` ≈ inert.

Beat detection: reuse `AudioReactor`/`SpectrumAnalyzer`'s `beatPulse`; if it's
too soft, add a simple onset threshold on bass flux to emit crisp beats. Keep
the scale-throb in the canvas transform (not the engine) so geometry stays
stable and only the presentation pulses. Unit-test the mapping math
(`reactivity=0` → identity; a synthetic beat → expected scale/speed factors).

## C. Clocks (`ZenClockOverlay`, `ZenClock*` in MandazaSettings)

- **Positions** — extend `ZenClockPosition`: `top, upperThird, center` +
  `lowerThird, topLeading, topTrailing, bottomLeading, bottomTrailing`. All
  safe-area aware.
- **Type styles** — extend `ZenClockFontStyle`: `system, rounded, monospaced` +
  `serif, condensed`. Add a `zenClockSize` scale (compact…hero) driving the base
  point size.
- **New forms** — a `ZenClockForm` enum: `digital` (current inline HH:MM AM/PM),
  `stacked` (HH over MM, big), `editorial` (large hour, small minute + date
  baseline). Just these two new forms; nothing ornate.
- **Robustness** — auto-contrast: sample nothing (mandala is sparse on black) but
  keep an optional container scrim (`zenClockContainerOpacity`) and a subtle
  text shadow for legibility over bright strokes; keep the clock out of the
  mandala's bright center by honoring position + a small inset. Same overlay
  compiles for watch/tv (watch uses compact defaults).
- Borrow from `ambient-time`: adapt the typographic proportions of its clean
  digital/stacked/editorial treatments only — no face-engine dependency.

## D. Tilt parallax (net-new)

- New `TiltProvider` (MandazaCore): wraps `CMMotionManager` (iOS) /
  `CMMotionManager` on watchOS; publishes a smoothed, clamped
  `(pitch, roll)` → normalized offset. `#if os(tvOS)` → no-op (inert).
- **Layered parallax** in `ContentView`/`MandazaCanvas`: the mandala layer
  offsets opposite to tilt; the clock overlay rides a shallower depth; optional
  glow layer a deeper one. Offsets are small fractions of the view size.
- **Setting** `zenTiltIntensity`: `off, subtle, pronounced` (enum), default
  `subtle` on phone/watch. Scales the max offset. Persisted in settings.
- Motion updates only while Zen is visible and intensity ≠ off (battery). Stop
  on background/leave-Zen.

## E. Framed hero screenshots

1. **Capture** raw mandalas at **1320×2868** on the iPhone 17 Pro Max sim using
   the DEBUG hooks (`MANDAZA_PALETTE=<id>`, `MANDAZA_MUSIC_DEMO=1` for a
   mid-throb frame), across a few palettes and a couple of clock forms.
2. **Frame** them with device bezel + big promo copy via the
   `app-store-screenshots` skill (scaffolds a Next.js editor; exports store
   sizes). Copy is short, honest, no "AI" as a noun. Headlines e.g. "Generative
   mandalas, endlessly", "Your art reacts to the music", "A living clock face".
3. **Export** the 1320×2868 iPhone set (and reuse existing watch shots), then
   upload to the editable **iOS v1.3** via `asc_ship.py screenshots`. Do NOT
   submit.

## Touch points (files)

- `Mandaza/ContentView.swift` — center button → Zen toggle; remove music icon;
  parallax offsets; clock form wiring.
- `Mandaza/MusicModeControls.swift` — delete `MusicModeLongPress`; music now via
  Zen + setting.
- `Mandaza/SettingsView`/`WatchSettingsView` — Music responsivity section, clock
  form/size/position controls, tilt intensity.
- `MandazaCore/MandazaSettings.swift` — new enums/props (`reactivity`,
  `musicResponsivity`, `ZenClockPosition`+, `ZenClockFontStyle`+, `zenClockSize`,
  `ZenClockForm`, `zenTiltIntensity`).
- `MandazaCore/MandazaCanvas.swift` — speed + scale-throb + glow from modulation.
- `MandazaCore/MandazaModulation.swift` / `AudioReactor` / `SpectrumAnalyzer` —
  crisper beat onset if needed.
- `MandazaCore/ZenClockOverlay` + `ZenClockTypography` — new styles/forms/positions.
- `MandazaCore/TiltProvider.swift` — new.
- `Mandaza/PrivacyInfo.xcprivacy` — already added.

## Testing

- Unit: reactivity mapping (`r=0` identity; synthetic beat → expected factors);
  clock position/form resolution; tilt offset clamping.
- Visual: sim capture per palette/clock-form; confirm the throb + speed read on a
  music-demo capture; confirm parallax shifts layers on simulated attitude.
- Regression: existing MandazaCore tests still pass; tvOS build has no CoreMotion
  / mic references (compile guards).
