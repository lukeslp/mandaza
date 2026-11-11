# Android cover-screen direction (November 4, 2026)

Luke wants Mandaza's outer screen to show ambient art and a clock, following
the existing Ambient Time work. Build on Mandaza's current Zen mode and clock
overlay. The cover does not need a miniature copy of every editor control.

Current evidence is limited: the public 1.3.5 (10310) build cold-launched from
Samsung's actual closed-cover App Tray; artwork, footer controls and the
scrolling Tune sheet worked in the wide frame. No Mandaza source change was
needed for that check. This does not establish full-panel camera clearance,
physical folding continuity, TalkBack, or a dedicated cover-clock interaction.
Evidence: the coordinating Ambient Time review of flip-cover apps from
November 4, 2026, which is kept privately.

Next, preserve the clock/ambient mode across fold transitions, keep essential
controls clear of the measured camera area, and honor reduced motion and
lifecycle pausing. Test the actual cover App Tray launch, wide/tall/full sizes,
fold continuity and accessible operation on the physical device. Reuse Ambient
Time's measured policies only where Mandaza's actual window geometry matches.
No new cover layout is included in this F-Droid packaging change, and the
listing must not claim full cover support before those checks.
