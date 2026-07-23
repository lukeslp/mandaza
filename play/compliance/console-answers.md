# Google Play Console answers

## App access

- Reviewers can reach every feature without special access.
- Reviewers need no account, login, membership, location exception, or
  credential.

## Ads

- Contains ads: No.

## Data safety

- Does the app collect or share required user-data categories: No.
- Data shared with third parties: None.
- Data collected by the developer: None.
- Data encrypted in transit: Not applicable; the Play flavor makes no network
  requests.
- Users can request data deletion: Not applicable; no developer-held user data
  or account exists.
- Independent security review: No.

Mandaza processes microphone input ephemerally on-device only while Music
responsivity is active. The app does not retain, transmit, collect, or share it.
Generated images, settings, favorites, and history remain on the device unless
the user explicitly saves or exports an image.

## Permissions declaration

- `android.permission.RECORD_AUDIO`: optional feature permission. Requested
  only when the user activates Music responsivity. Live amplitude and beat
  values affect the visual animation; raw audio is never recorded or retained.
- `android.permission.WRITE_EXTERNAL_STORAGE` with `maxSdkVersion=28`: used
  only for user-initiated image export on older supported Android releases.
- `android.permission.READ_EXTERNAL_STORAGE` with `maxSdkVersion=28`: Android's
  compatibility manifest adds this for the same legacy media-library path.
- Internet permission: absent from the Google Play flavor.

## Content and audience

- App category: Art & Design.
- Target audience recommendation: ages 13 and older; the app is not designed
  specifically for children.
- News app: No.
- Government app: No.
- Health app: No.
- Financial features: None.
- User-generated public content: None.
- Social or communication features: None.
- Purchases, gambling, violence, sexual content, controlled substances, and
  location sharing: None.

Complete the IARC questionnaire truthfully from these answers; Google Play
assigns the rating.

## Privacy and contact

- Privacy policy source: `docs/index.md`
- Public URL: `https://mandaza.app/privacy.html`
- Support email: `luke@lukesteuber.com`
- Public URL status on 2026-07-22: **HTTP 200 and verified.**
