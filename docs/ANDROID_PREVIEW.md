# Android preview 0.5.0-android.2

Package `fyi.luani.client.preview`, version code `50002`. Android 7/API24 minimum; target API35. ARM64, ARMv7 and x86-64; Godot4.7.1 stable, isolated JDK17/SDK35 and official prebuilt engine libraries. The original private signing key is retained, so install this APK **over** Android1 without uninstalling.

## Open, log in and play

1. Download the current signed APK from https://new.luani.fyi/downloads and install the update. Android may ask to allow installation from the downloading browser; disabling Play Protect is not required.
2. Open **Luani Client**. On Android the live https://new.luani.fyi website now opens inside the app. Log in there once, visit Baseplate and choose **Join game**. In-app website login storage persists; external-browser cookies are deliberately not imported.
3. The website hands a short-lived opaque one-use `luani://launch?ticket=…` code to the native game. Only that code is redeemed over fixed HTTPS; reusable website sessions are never passed into the Godot game or launch URL. Pinned DTLS and server-owned identity/inventory remain unchanged.
4. Use Menu → **Leave** to return to the same website view. The native **Practice** toolbar button opens explicitly offline practice; its items never upload to the online inventory. External browser launch links still work.

Desktop keeps its browser/protocol workflow and original fixed UI geometry. Linux0.5.0-multiplayer.2 adds the matching movement/camera-lock input flag; old releases remain available and retain their previous aim-facing behavior.

## Touch controls

- Android HUD/menu controls are larger; Android-only logical canvas scaling keeps them usable on dense displays.
- Menu → Settings → **Joystick** selects **Fixed joystick** or **Floating left-side joystick**. This preference is saved across app restarts.
- Fixed keeps a visible lower-left pad. Floating starts at any eligible touch in the left half, stays at that touch origin and allows the thumb to stretch beyond the ring. Movement is still normalized to the same maximum speed. Menu, chat, inventory, leaderboard and hotbar touches are excluded from joystick capture.
- Drag the right side to look. JUMP, RUN (toggle), PICK, USE and DROP retain their actions.
- **Camera lock** is a separate saved mobile setting: off faces movement and retains body direction while orbiting the camera idle; on faces camera aim. The server sends body facing separately from tool aim, so other clients receive the intended orientation.
- Android Back opens/closes the game menu. Website Back navigates its page history; at its root, Android Back backgrounds the app.

## Embedded website trust boundary

The native Godot v2 plugin is `LuaniWebsitePlugin`, registered as `LuaniWebsite`. It preserves the stock Godot activity/lifecycle and overlays a real WebView. Only HTTPS `new.luani.fyi`, no userinfo and default443 may navigate inside it. Strict canonical one-use launch links must be main-frame handoffs from a trusted current page. External HTTPS links/downloads go to the system browser. DOM storage and first-party cookies remain in WebView; there is no JavaScript/native secret interface or cookie extraction. File/content access, mixed content, third-party cookies and WebView debugging are disabled; TLS errors cancel and runtime web permission requests are denied. No embedded credentials, browser profile copying or SSL bypasses are used.

## Build, signing and focused checks

`distribution/android/build_on_linux.py` targets the isolated owner-machine `android-preview-2` root. It compiles the native plugin and JVM URL-policy test, verifies the packaged plugin metadata and separate URI activity-alias, and requires the original certificate fingerprint. Official Gradle templates can replace activity children, so inspect the final APK, not only source XML. Internet is the only requested permission; backups and cleartext HTTP remain disabled. Godot/font third-party notices stay in the APK.

Private signing material stays outside source/archive/APK. Align and verify APK signatures v2/v3, version/code, ABIs, certificate and manifest. The build input archive, APK SHA and separate runtime receipt identify what actually ran.

Focused source guards: `python tools/test_android_source.py`, `python tools/test_facing_contract.py`, `python tools/test_mobile_controls.py`, `python tools/test_embedded_website.py`. `tools/java/WebsitePolicyTest.java` runs against the actual policy with the task JDK. `tools/godot/interaction_regression.gd` runs only in an isolated test scene with SessionState autoload, not the main game; it checks facing math, bounded touch geometry, real packet encode/validation, unchanged snapshot shape and remote orientation. Run engine/APK checks only on the authorized dev machine, never on the website/password-manager Pi.

## Download freshness and acceptance boundaries

Each download re-fetches a no-store channel and uses an immutable version-and-SHA APK URL with a fresh download query. The scoped Worker bypasses upstream caching, sets browser/CDN no-store and strips validators. Do not combine Cloudflare `fetch(cache:'no-store')` with `cf.cacheTtl` options.

Android1 was owner-confirmed working on a phone. That is not physical-phone acceptance of this update. Record current APK SHA/device/Android version when checking the update. Emulator, URL-policy and isolated packet tests do not prove an authenticated two-account game. Check phone and PC on different accounts for both identities/avatars, free movement and idle orbit facing, lock/first-person facing, pickups, disconnect/rejoin and persistence. See `docs/GEMINI_ANDROID2_HANDOFF.md` for the bounded remaining review checklist. Do not describe non-minted-code rejection as successful online admission.
