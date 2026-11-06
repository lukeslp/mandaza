# Mandaza 1.3.6 Amazon tablet packet

This is a local draft for `app.mandaza.android` 1.3.6 (10312). No Amazon draft,
upload or submission was created. The live listing named Mandaza is the separate
TV package `app.mandaza.tv`, confirmed in Chrome on November 5, 2026.

The packet contains Amazon-specific title, descriptions, five feature bullets
and reviewer notes. It excludes Apple widgets, Watch, TV and untested fold claims.
The [candidate sheet](../../AMAZON-1.3.6-READINESS.md) records signed build checks.

## Current requirements

Checked November 5, 2026, against Amazon's
[Appstore details guide](https://developer.amazon.com/docs/app-submission/appstore-details.html):

- Tablet icons: 114×114 and 512×512 transparent PNG.
- Screenshots: three to ten PNG/JPEG images from the tablet experience.
  Allowed sizes include 1280×800 and its portrait orientation. The existing
  800×1280 captures belong to 10308 and cannot be used for this new candidate.
- An optional promotional image is 1024×500. It can wait; it is not a release
  requirement.
- Short description: at most 2,000 bytes. Long description: at most 4,000
  characters, plain text. Product features: three to five separate lines.

The canonical icon source is retained. The existing TV 114px and 512px files
are opaque, and the Play 512px file has the same opaque bytes as the TV file.
They do not meet the current transparent-PNG requirement. Amazon-sized exports
and visual review remain open. Capture at least three fresh Fire scenes from
the final tested candidate before adding them here. Keep capture model, Fire OS
version, date, APK hash, captions and image hashes together. Check the images
without relying on hue. The first exact-10312 Paper Zen capture is QA evidence:
it exposed a contrast issue that needs a higher-code correction before release.

## Privacy and targeting

The public [privacy page](https://mandaza.app/privacy.html) returns HTTP 200, but
its current July 22 text covers Apple platforms only. The
[Amazon privacy addendum](PRIVACY-ADDENDUM-DRAFT.md) is prepared for review and
integration into the public policy before this listing is submitted. It has not
been published. Confirm the support and privacy URLs in the final console form.

Select Fire tablets for this package; do not select TV or automotive devices.
Use the actual upload's manifest filtering and review the selected models.
Minimum API 24 and optional microphone/accelerometer declarations do not prove
compatibility with every eligible tablet. See Amazon's
[device-filtering guide](https://developer.amazon.com/docs/app-submission/device-filtering-and-compatibility.html).

The existing TV record unexpectedly selects 12 tablets and two automotive
entries as well as 100 TV entries. Its touch answer is No and offline answer is
No. Prepare a reviewed TV-targeting correction independently; creating this
tablet listing must not reuse or overwrite the TV identity.

## Remaining work

1. Test exact 10312 on Fire: install/upgrade and saved state, touch, Back,
   rotation, offline/resume, microphone denial, VoiceView, text scaling,
   reduced motion and one-hour stability.
2. Capture the tested build and finish icon exports; review listing images.
3. Publish the reviewed privacy coverage and verify its served text.
4. Review the separate tablet record, model selections and final metadata.
5. Complete the human upload/submission checkpoint and retain its receipt.
6. Test the Amazon-delivered package and signing identity after approval.

Amazon's [submission guide](https://developer.amazon.com/docs/app-submission/understanding-submission.html)
states that Amazon re-signs uploaded apps. Do not promise cross-channel updates
from an upstream APK solely because the uploaded package and signer match.
