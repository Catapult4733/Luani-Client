# Gemini review: Android2 and movement-facing update

Review Catapult4733/Luani-Client branch `feat/android-preview`; immutable release refs `v0.5.0-android.2` and `v0.5.0-multiplayer.2` identify the exact shared source. Resolve and report their commit with `git rev-parse <tag>^{commit}` before testing; do not replace a different local checkout or erase worlds/untracked work. Website copy lives in Catapult4733/Luani branch `feat/android-downloads`.

## Scope and safety

The owner permits APK compilation/emulator/runtime checks on edward, while desktop gameplay review remains delegated to Gemini. Do not run clients/Godot/gameplay on the Raspberry Pi. Do not change Supabase, Cloudflare, production hosting, Tailscale, Playit, Docker or either Vaultwarden. Hermes owns privileged deployment. Do not replay migrations, merge PRs, modify stable signing keys or bypass SSL/DTLS/admission. Never copy browser cookies or paste reusable login credentials/tokens into reports or launch URLs. Use different accounts on phone and PC; report only public usernames and versions, never codes/passwords.

## What changed

- `offline/scripts/facing.gd`, `player.gd`, `network_client.gd`, `dedicated_server.gd`: camera/tool aim stays separate from body facing. New optional `look_locked` flag; free movement faces its world travel vector, idle orbit keeps the prior body direction, locked/first-person follows aim. Existing14-field snapshots and protocol1 remain. Legacy clients that omit the flag retain their previous aim-facing behavior, so update desktop clients for the fix rather than expecting old clients to infer a mode they never send.
- `mobile_ui.gd`, `mobile_controls.gd`, `touch_geometry.gd`, `session_state.gd`, HUD/widgets: Android-only scaling and larger buttons, fixed/floating saved joystick and saved camera lock, UI hit exclusions, unlimited floating-thumb displacement but movement magnitude<=1. Desktop fixed pixel geometry remains.
- `distribution/android/java/org/luani/client/`: real native WebView; trusted HTTPS first-party pages, bounded strict one-use main-frame handoff, no JS secret bridge/cookie extraction/file access/mixed content/TLS bypass. In-app auth storage persists in WebView. External browser launch still works. Native website Back/Refresh/Practice and game Leave return lifecycle are connected in `bootstrap.gd`/`android_launch.gd`/`hud.gd`.

## Checks already performed by Hermes

The signed APK builds on edward with the original certificate, code50002, API24/35 and ARM64/ARMv7/x86_64. Focused source guards, actual JVM URI-policy checks and22 real Godot math/packet/physics contracts pass in an isolated unit scene with no main game/network/admission. Native Android14 x86_64 APK checks and screenshots are recorded separately by exact APK SHA. See the release's `runtime-verification.json` for what actually passed; do not infer missing tests from these notes. Android1 was owner-confirmed working on a real phone; this is not physical acceptance of Android2.

## Remaining acceptance

1. Install Android2 over Android1 without uninstalling. Open Luani Client directly: live new.luani.fyi must appear inside it, not Brave. Log in normally in-app once; background/restart and check session retention. Do not import external browser cookies.
2. Navigate profiles, catalogue, Baseplate and Downloads in-app; exercise native Back/Refresh. Join Baseplate from the authenticated website. Confirm it enters the native game in the same app with canonical username/avatar. Leave returns to the same page/history/session. Test external cold/warm browser launch as a compatibility path.
3. On physical ARM phone, inspect HUD/menu/chat/inventory/leaderboard across supported densities/aspect ratios. Desktop geometry must be unchanged. Joystick must not capture menu/chat/hotbar touches. Settings fit with no clipped footer. Check Android Back, background/resume and keyboard focus.
4. Fixed mode remains visible and works. Floating starts anywhere eligible on the left, follows that touch origin, stretches freely even past the screen half, vanishes on release and cannot increase walk/run speed. Simultaneously use right-look and jump with other fingers. Change modes/open a modal/background during a hold: no stuck movement or sprint. Persist both mode and camera lock after force-stop/restart.
5. Update the PC with `curl -fsSL https://new.luani.fyi/client/install.sh | bash` as the normal user, no sudo; the command must not auto-launch. Keep the working MIME/portal handler. Join with a second account. Observe each other walking forward/back/sideways with free camera, idle orbit, shift/camera lock and first person. Remote body must follow travel when free and aim when locked, with no tool-aim/range regression. Verify pickup/equip/use/drop, disconnect/rejoin and server-owned persistence.
6. Negative cases: malformed/expired/replayed/non-minted launch code must not create a world or fallback to guest online. Untrusted origins, userinfo, non443 ports, extra launch query parameters, fragment/path variants, file/content/javascript navigation and SSL errors fail closed. Check a slow redemption followed by cancel/Practice; obsolete completion must not interrupt the new view.

## Focused commands

Run in the selected source checkout: `python tools/test_android_source.py`; `python tools/test_facing_contract.py`; `python tools/test_mobile_controls.py`; `python tools/test_embedded_website.py`. Use the isolated owner-machine build harness only with its task SDK/JDK/templates and retained private signing material; do not create a replacement key or alter owner AVD/global settings. The pure Java test is `org.luani.client.WebsitePolicyTest`; the Godot fixture is `tools/godot/interaction_regression.gd` in a minimal test project with SessionState autoload, not `--script` without autoload registration.

Return exact commit/tag/APK SHA, device/Android/PC versions, commands, result per acceptance item, screenshots for visual failures, sanitized runtime logs and a narrowly scoped diff for any routine fixes. Distinguish observed results, source-only review and anything not exercised. Stop before infrastructure/publishing; hand consequential fixes back to Hermes.
