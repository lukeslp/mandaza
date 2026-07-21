# Android device evidence

Evidence collected from the Play debug variant on 2026-07-20.

## Phone

- Device: Google Pixel 9a
- adb serial: `54051JEBF00576`
- Screenshot size: 1080 × 2424
- Install: passed
- Launch: passed
- Main canvas, Zen clock, and Tune sheet: captured

## 7-inch tablet class

- AVD: `PulseTime_7in_API_35`
- adb serial during capture: `emulator-5554`
- Android API: 35
- Physical framebuffer: 1080 × 1920 at 280 dpi (approximately 7.9-inch
  diagonal)
- Install: passed
- Launch: passed
- Main canvas, Zen clock, and Tune sheet: captured

## Accessibility evidence

- The full-screen tap target exposes the spoken label `Mandaza canvas`.
- Footer actions expose visible labels: History, Favorite, Zen, Tune, and Save.
- Android lint completed successfully for `playDebug`.
- Touch targets observed in the UI hierarchy meet or exceed 48 dp.
- A manual TalkBack traversal and keyboard/switch-control pass remains a human
  pre-submission check; automated hierarchy inspection is not a substitute for
  assistive-technology testing.
