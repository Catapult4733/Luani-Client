# Android preview 0.5.0-android.3

Package `fyi.luani.client.preview`, version code `50003`. Android 7/API24 minimum; target API35. ARM64, ARMv7 and x86-64; Godot4.7.1 stable, isolated JDK17/SDK35 and official prebuilt engine libraries. The original private signing key is retained, so install this APK **over** Android1 or Android2 without uninstalling.

## Open, log in and play

1. Download the current signed APK from https://new.luani.fyi/downloads and install the update. Android may ask to allow installation from the downloading browser; disabling Play Protect is not required.
2. Open **Luani Client**. On Android the app displays a dark Luani splash and a centered **connecting** screen with no native top toolbar or offline-practice launcher menu, then opens https://new.luani.fyi full-screen inside the app. Log in there once, visit Baseplate and choose **Join game**. In-app website login storage persists; external-browser cookies are deliberately not imported.
3. The website hands a short-lived opaque one-use `luani://launch?ticket=…` code to the native game. While redeeming the launch ticket and connecting to the server, the app shows the **connecting** state; if connection or ticket redemption fails, it provides bounded error feedback and **Retry** / website recovery rather than hanging. Only the one-use code is redeemed over fixed HTTPS; reusable website sessions are never passed into the Godot game or launch URL. Pinned DTLS and server-owned identity/inventory remain unchanged.
4. Use Menu → **Leave** to return to the same website view. External browser launch links still work.

Desktop keeps its browser/protocol workflow, offline practice launcher and original fixed UI geometry (`0.5.0-multiplayer.2`); old releases remain available.

## Branding and rendering workload

- Android main, adaptive foreground/background and monochrome launcher icons plus the Android system splash icon use Luani orbital artwork (`offline/assets/branding/luani-*.svg`), and `splash_screen/disable_godot_boot_splash=true` suppresses the stock Godot boot splash on Android without altering desktop startup. Required Godot, third-party and font license files (`Godot-LICENSE.txt`, `Godot-COPYRIGHT.txt`, `OFL.txt`) remain packaged in the APK.
- Android frame pacing (`offline/scripts/mobile_performance.gd` + `LuaniWebsitePlugin.prefer60Hz`) enables VSync, requests a 60 Hz display mode where supported, caps active gameplay at 60 FPS and drops the hidden Godot loop to 15 FPS with `OS.low_processor_usage_mode=true` while the WebView overlay is visible; hiding the WebView pauses its timers (`browser.pauseTimers()`).
- Android 3D workload optimizations batch rigid tool and pickup-pedestal primitive meshes by material (`ItemVisual.compact_for_mobile`), disable shadow casting on flat baseplate grid lines, pickup pedestals/rings and sub-centimeter avatar face details, bound avatar eye sphere tessellation and use single-pass orthogonal directional shadows (`DirectionalLight3D.SHADOW_ORTHOGONAL`) on Android. In the isolated non-shipping offline render benchmark (`tools/godot/android_render_profile.gd`, 18 pickups, 5 targets, 1 avatar), mean draw calls per frame dropped from **420.0** to **108.0** (-74.3%) and mean primitives per frame dropped from **82,556.0** to **14,356.0** (-82.6%).
- **Measured vs. target boundary:** Emulator/benchmark reductions and a 60 FPS cap do **not** prove smooth 60 FPS on a physical Samsung Galaxy A16 (whose exact LTE/5G variant, SoC and RAM were not provided). On-device physical-phone frame-time verification remains required.

## Touch controls

- Android HUD/menu controls are larger; Android-only logical canvas scaling keeps them usable on dense displays.
- Menu → Settings → **Joystick** selects **Fixed joystick** or **Floating left-side joystick**. This preference is saved across app restarts.
- Fixed keeps a visible lower-left pad. Floating starts at any eligible touch in the left half, stays at that touch origin and allows the thumb to stretch beyond the ring. Movement is still normalized to the same maximum speed. Menu, chat, inventory, leaderboard and hotbar touches are excluded from joystick capture.
- Drag the right side to look. JUMP, RUN (toggle), PICK, USE and DROP retain their actions.
- **Camera lock** is a separate saved mobile setting: off faces movement and retains body direction while orbiting the camera idle; on faces camera aim. The server sends body facing separately from tool aim, so other clients receive the intended orientation.
- Android Back opens/closes the game menu. Website Back navigates its page history; at its root, Android Back backgrounds the app.

## Embedded website trust boundary

The native Godot v2 plugin is `LuaniWebsitePlugin`, registered as `LuaniWebsite`. It preserves the stock Godot activity/lifecycle and overlays a full-screen WebView with native `connecting` and error-only `Retry` states. Only HTTPS `new.luani.fyi`, no userinfo and default443 may navigate inside it. Strict canonical one-use launch links must be main-frame handoffs from a trusted current page. External HTTPS links/downloads go to the system browser. DOM storage and first-party cookies remain in WebView; there is no JavaScript/native secret interface or cookie extraction. File/content access, mixed content, third-party cookies and WebView debugging are disabled; TLS errors cancel and runtime web permission requests are denied. No embedded credentials, browser profile copying or SSL bypasses are used.

## Build, signing and focused checks

`distribution/android/build_on_linux.py` targets the isolated owner-machine `android-preview-3` root (and supports `--render-profile` in separate `-baseline`/`-profile` roots). It writes `res://android/.gdignore` so custom exported icon/splash `.webp` resources are never re-imported into Gradle's `res/` merger, compiles the native plugin and JVM URL-policy test, verifies packaged plugin metadata, separate URI activity-alias and exported Luani icon/splash `.webp` digests, and requires the original certificate fingerprint.

Focused source guards: `python tools/test_android_source.py`, `python tools/test_facing_contract.py`, `python tools/test_mobile_controls.py`, `python tools/test_embedded_website.py`, `python tools/test_android_chrome.py`, `python tools/test_android_branding.py`, `python tools/test_android_build_contract.py`, `python tools/test_mobile_performance.py`. `tools/java/WebsitePolicyTest.java` runs against the actual policy with the task JDK. `tools/godot/interaction_regression.gd` and `tools/godot/android_render_contracts.gd` run in isolated test scenes on the authorized dev machine, never on the website/password-manager Pi.

## Download freshness and acceptance boundaries

Each download re-fetches a no-store channel and uses an immutable version-and-SHA APK URL with a fresh download query. The scoped Worker bypasses upstream caching, sets browser/CDN no-store and strips validators. See `docs/GEMINI_ANDROID2_HANDOFF.md` for the bounded remaining physical-phone and two-account review checklist.
