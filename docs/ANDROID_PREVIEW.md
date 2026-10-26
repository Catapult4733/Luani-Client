# Android preview 0.5.0-android.1

Package: `fyi.luani.client.preview`, version code `50001`. Android 7/API24 minimum; target API35. Includes ARM64, ARMv7 and x86-64. Exported with Godot4.7.1 stable and an isolated JDK17/SDK35 build environment, using official prebuilt Android engine libraries. This is separate from the existing Linux0.5.0-multiplayer.1 release.

## Install and join

1. Download the signed APK from https://new.luani.fyi/downloads. Allow your browser to install this APK when Android asks; disabling Play Protect is not required.
2. On that phone, open https://new.luani.fyi/games/baseplate in the browser, log in, then choose **Join game** and select Luani Client.
3. Use **different Luani accounts** on the phone and computer for multiplayer checks. A second admission for the same account is intentionally fenced.

The app receives a short-lived opaque, one-use `luani://launch?ticket=…` code and redeems it over HTTPS. It never receives your browser cookies or reusable browser session. Existing pinned-DTLS admission, server-owned identity and authoritative game state are reused.

## Controls

- Left joystick: move.
- Drag the right side: look.
- JUMP, RUN (toggle), PICK, USE, DROP: actions.
- Touch a hotbar slot to equip it. The menu/inventory retain their compact controls.

Offline practice is explicitly separate from an online account session. Its items do not upload to your online inventory.

## Build and signing

`distribution/android/build_on_linux.py` is the isolated owner-machine export harness. It preserves the stock Godot activity and adds a separate Android activity-alias: Godot's generated release manifest otherwise replaces filters inside the main activity. Final APK inspection must check the actual packaged URI filter, not only source XML. Only Internet permission is requested; backups and cleartext HTTP are disabled.

The preview has its own stable RSA3072 signing key, stored outside the project under the build user's private Luani build folder. Keep that key/password safe for compatible future updates; never commit or package them. APKs are aligned and verified with signature schemes v2/v3. The build report and separate runtime receipt distinguish packaging verification from actual runtime checks.

## Download freshness

The website checks a no-store Android channel manifest on every download, then uses an immutable version-and-SHA filename with a fresh download query. A scoped Worker bypasses the upstream cache and sets browser/CDN no-store headers while stripping validators. It fails rather than falling back to cached release metadata. Do not combine Cloudflare `fetch(cache:'no-store')` with `cf.cacheTtl` options: the provider rejects that combination.

## Acceptance boundaries

A successful export/signature is not multiplayer acceptance. The physical phone still needs a real authenticated join alongside the PC, checking both canonical identities/avatars, shared movement, pickups, disconnect/rejoin and server-owned persistence. Record the exact APK SHA and actual device/Android version. Do not claim cross-device gameplay based on source or HTTP fixtures.
