# Gemini review: Android3 chrome-free startup, Luani branding, render-workload reduction and movement-facing

Review Catapult4733/Luani-Client branch `feat/android-preview`; immutable release refs `v0.5.0-android.3` (Android code `50003`) and `v0.5.0-multiplayer.2` (Linux desktop/server) identify the exact source. Resolve and report their commits with `git rev-parse <tag>^{commit}` before testing; do not replace a different local checkout or erase worlds/untracked work. Website copy lives in Catapult4733/Luani branch `feat/android-downloads`.

## Scope and safety

The owner permits APK compilation/emulator/runtime checks on edward, while desktop gameplay review and physical-phone verification remain separated from emulator checks. Do not run clients/Godot/gameplay on the Raspberry Pi. Do not close or attach to the owner's Brave browser. Do not change Supabase, Cloudflare, production hosting, Tailscale, Playit, Docker or either Vaultwarden. Hermes owns privileged deployment. Do not replay migrations, merge PRs, modify stable signing keys or bypass SSL/DTLS/admission. Never copy browser cookies or paste reusable login credentials/tokens into reports or launch URLs. Use different accounts on phone and PC; report only public usernames and versions, never codes/passwords.

## What changed in 0.5.0-android.3

- `distribution/android/java/org/luani/client/LuaniWebsitePlugin.java`, `offline/scripts/connecting_screen.gd`, `offline/scripts/bootstrap.gd`, `offline/scripts/android_launch.gd`: removed the native Android top toolbar (`Back`, `Refresh`, `Practice`) and removed the Android native launcher menu (`Open Luani website`, `Offline practice`). Android now shows a centered `connecting` screen during startup and launch-ticket redemption, opens https://new.luani.fyi full-screen inside the WebView, and provides bounded error + `Retry` recovery on page-load, HTTP, TLS or ticket-redemption failure. Desktop launcher and offline practice remain unchanged on Linux.
- `offline/assets/branding/luani-{icon,foreground,background,monochrome}.svg`, `distribution/android/export_presets.cfg`, `distribution/android/build_on_linux.py`: replaced stock Godot Android launcher/adaptive/monochrome icons and splash artwork with Luani orbital branding and enabled `splash_screen/disable_godot_boot_splash=true` on Android while keeping required engine/font license files in the APK and desktop startup unchanged.
- `offline/scripts/mobile_performance.gd`, `offline/scripts/mobile_ui.gd`, `offline/scripts/item_visual.gd`, `offline/scripts/world.gd`, `offline/scripts/pickup.gd`, `offline/scripts/avatar.gd`, `offline/scripts/practice_target.gd`: added Android-only active-game (60 FPS + VSync + 60 Hz display mode preference) vs. visible-website (15 FPS + low-processor mode + paused WebView timers when hidden) pacing, batched rigid tool and pickup-pedestal meshes by material on Android, disabled shadow casting on flat baseplate grid lines/pickup rings/avatar face decals, bounded eye sphere tessellation, and switched Android directional sun shadows to single-pass `SHADOW_ORTHOGONAL`.

## Checks already performed by Hermes

1. **Source & unit contracts:** 8 Python test suites (20 tests), 22 JVM `WebsitePolicyTest` checks, 23 Godot `interaction_regression.gd` checks, and 25 Godot `android_render_contracts.gd` checks passed.
2. **Measured render workload (isolated non-shipping `fyi.luani.client.preview.renderqa` fixture on edward):** In the identical stationary world scenario (`18 pickups; 5 targets; 1 offline avatar`), mean draw calls per frame dropped from **420.0** (baseline) to **108.0** (candidate, **-74.3%**), and mean primitives per frame dropped from **82,556.0** to **14,356.0** (**-82.6%**).
3. **Signed `0.5.0-android.3` (`50003`) APK & emulator verification:** Built and signed with the retained certificate (`3b2d0f7a69043c6d61a4264f3258ae3fbbb2625678c841c03a42066ffa7b64a2`), verified packaged Luani `.webp` icon/splash digests and license notices, updated in-place over `0.5.0-android.2` on the Android 14 x86_64 emulator (`emulator-5580`), and verified chrome-free full-screen website overlay, `connecting` state, system Back behavior, OS launcher icon and cold/warm invalid-ticket recovery.
4. **Physical Samsung Galaxy A16 and two-account multiplayer boundary:** Emulator SWANGLE timings and a 60 FPS cap are **not** evidence of smooth 60 FPS on a physical Samsung Galaxy A16. Physical-phone and authenticated two-account gameplay remain to be verified on hardware.

## Remaining acceptance

1. Install `0.5.0-android.3` over `0.5.0-android.2` on the physical Samsung Galaxy A16 without uninstalling. Verify the Android home launcher, app drawer, recent-apps switcher and cold-boot splash show Luani branding rather than the stock Godot icon.
2. Confirm startup shows `connecting` (with no `Back / Refresh / Practice` top bar and no `Open Luani website / Offline practice` menu) and transitions to full-screen https://new.luani.fyi. Log in once, navigate pages, test Android system Back, and join Baseplate.
3. On the physical Samsung Galaxy A16, observe actual gameplay frame pacing and smoothness (~60 FPS target) during movement, camera orbit, camera lock and tool use; report exact phone model number (e.g. SM-A165F / SM-A166B), RAM, Android version and any observed stutter.
4. Verify fixed and floating left-side joystick modes, right-side look, HUD hit exclusions, Menu → Leave return to the in-app website, and two-account multiplayer facing replication alongside the Linux `0.5.0-multiplayer.2` client.

## Focused commands

Run in `/opt/data/projects/Luani-Client-android`:
`python3 tools/test_android_source.py && python3 tools/test_facing_contract.py && python3 tools/test_mobile_controls.py && python3 tools/test_embedded_website.py && python3 tools/test_android_chrome.py && python3 tools/test_android_branding.py && python3 tools/test_android_build_contract.py && python3 tools/test_mobile_performance.py`
