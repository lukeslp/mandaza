# Apple metadata staging

The iOS app, widgets, and Watch companion are prepared as Mandaza 1.4. The
standalone Apple TV product remains MandazaTV 1.3.

The files in this directory are the iOS metadata source of truth for
`com.lukesteuber.mandaza`. Check App Store Connect immediately before staging;
repository state does not prove whether metadata has already been uploaded.

MandazaTV uses its existing separate record, bundle ID
`com.lukesteuber.mandaza.tv`, and Apple ID `6768536771`. Its metadata lives in
`../tvOS/en-US/`, with screenshots in `../../screenshots/tvOS/en-US/`.

Before running the ship pipeline for real:
1. Confirm iPhone 1320×2868 heroes + Watch Ultra faces in
   `../../screenshots/en-US/` (see `NOTES.md` there — currently ASC-ready).
2. Confirm the four 3840×2160 MandazaTV images in
   `../../screenshots/tvOS/en-US/` remain attached to the standalone TV record.
3. Confirm with the owner whether this is a stage-only pass or a submit-for-review
   pass; that boundary must be explicit before touching App Store Connect.
