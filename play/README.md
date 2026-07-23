# Mandaza Google Play handoff

This directory contains the complete English (United States) listing and
closed-testing handoff for `app.mandaza.android`.

## Upload order

1. Verify that `https://mandaza.app/privacy.html` serves the Mandaza policy.
2. In Google Play Console, open Mandaza and complete App content using
   `compliance/console-answers.md`.
3. Populate the Main store listing from `listing/en-US/` and upload every asset
   listed in `listing/en-US/graphics/ASSET-MANIFEST.txt`.
4. Create or open the phone/tablet **Closed testing** track. Do not use the
   Internal testing track for this handoff.
5. Upload the final AAB from
   `artifacts/google-play/app.mandaza.android/1.3.3-10305/`.
6. Add testers, paste `testing/what-to-test.txt`, review the generated release,
   and start the closed test manually.

Google Play Console login, upload, tester management, submission, and publish
are intentionally manual actions.

## Release identity

- Package: `app.mandaza.android`
- Version: `1.3.3`
- Play version code: `10305`
- Track: phone/tablet closed testing
- Direct-update behavior: absent from the Play flavor
- Required device capabilities: none
- Optional sensitive capability: microphone, requested only when the tester
  enables Music responsivity

Version code `10304` is a superseded local candidate retained only because
artifact handoffs are immutable. Do not upload it.
