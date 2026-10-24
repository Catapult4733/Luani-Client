# Gemini 3.8 Flash High — Luani 0.3.0-offline.3 verification

Hermes implemented and published this compact-UI update WITHOUT launching Godot, an exporter, the installer or a headless game. Source parsing and distribution checks are not runtime evidence. You may run the client on the owner's development computer; do not access Pi/Vaultwarden, Docker, backend, Cloudflare, production website settings or credentials, and do not push/deploy.

## Source and installation

Repository: https://github.com/Catapult4733/Luani-Client
Branch: `feat/linux-offline-client`; record the exact SHA before testing.
Project: `offline/project.godot`, entry `offline/main.tscn`.
Changed code: `offline/scripts/hud.gd`, `offline/project.godot`, `offline/assets/ui/compact/`.
Camera implementation: `offline/scripts/player.gd` is unchanged from the preceding release.
Do not launch historical client/Studio, daemon or web_backend code.

Record actual Linux distribution, architecture, GPU/driver and desktop session. Ask before installing system dependencies, modifying graphics drivers or deleting existing installations. Do not call Windows-only checks Linux verification.

Quit the old client, inspect the installer, then update as the normal desktop user:

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
```

Confirm installation never auto-launches; then launch Luani Client from the app menu or `~/.local/bin/luani`. The bundled runtime is official Godot 4.7.2 with a source-runtime project, not an exported PCK. Test fresh resource/script loading without relying on editor import caches.

## Priority: compact fixed-size UI

The owner rejected the previous large circular icons, centered Luani/camera badge, bottom control strip and large purple menu/leaderboard. The new layout uses original neutral line icons and general screenshot-inspired hierarchy, NOT copied Roblox logos/assets.

1. Confirm the Luani/offline-baseplate/camera badge and bottom control strip are completely absent. The center aiming dot may remain in first person/shift lock.
2. Confirm original 20px menu/chat/list line icons in compact 36×32 logical-pixel hit targets. Old owner-designed circular icons must not display. Hover/open state should remain readable.
3. Compare actual control rectangles at 800×600, 1280×720 and 1920×1080, while keeping OS DPI settings constant. Window resize must NOT scale fonts, icons, buttons or panel sizes. Anchored panels may move; text fields/sliders may fill their fixed parent. Normal OS DPI scaling is not the window-relative scaling the owner rejected.
4. Intended fixed sizes: menu 560×452, chat 300×220, leaderboard 220×76, avatar viewer 360×420. Verify actual minimum-size/container behavior does not force them larger. Check long 24-character names; the leaderboard must clip/ellipsize rather than widen.
5. Menu: flat neutral translucent dark panel, Players then Settings tabs with selected underline; default Settings page; compact Leave / Respawn / blue Resume bottom row always visible. No decorative heading, slogan or version footer. Test both tabs, settings scroll, keyboard focus and Escape/resume.
6. Players: only the actual local name, View avatar, and truthful disabled Block/Friend/Report. Do not fabricate online players, cards, scores or friend activity. Back from the avatar viewer must select Players, now tab index 0.
7. Leaderboard: compact top-right panel with Players header, count 1 and the local name, not the previous large card. Tab and the list icon must toggle it. Chat should stay compact with readable plain text and usable input/Send controls.
8. Capture actual native-game screenshots at the tested sizes. Do not substitute an HTML mockup for a Godot screenshot. Report clipping, overlap, low contrast, platform font issues and mismatches to the requested compact style.

## Functional regression checks

- Original six-part humanoid, procedural animations, empty baseplate, WASD, grounded Space jump, held Shift run and fall/respawn remain functional.
- Camera: unrestricted horizontal look, approximately ±89° vertical guard, RMB orbit and collision. Full inward zoom enters eye-height first person, hides local avatar/name and captures mouse without RMB. Scroll outward returns to third person; Ctrl permission is independent of first-person capture.
- Menus/chat/dialogs and application focus loss release mouse capture appropriately. Closing/resuming restores gameplay capture. No movement/look input should leak through text fields or overlays. Keep the reticle centered after window resize.
- Settings: shift-lock permission, actual sound volume/mute, editable offline name and persistence across restart. Resume, Respawn and Leave confirmation/cancel work.
- Chat: Enter or `/` focuses, button toggles, Enter/Send adds `Username : message`, empty messages ignored, markup literal. It is local-only, unmoderated and non-persistent. Closing/submitting must release typing focus correctly.
- Avatar viewer remains animated and independent of the hidden local character in first person.
- No runtime HTTP, ENet, login, telemetry, voice capture or legacy daemon integration is introduced.
- Same-command reinstallation is idempotent; a real update from a previous installed version preserves preferences and old releases. If unavailable, mark cross-version update NOT TESTED rather than inventing a result.

## Return

Provide exact OS/hardware, source SHA/version, PASS/FAIL/NOT TESTED per item, measured UI sizes, real logs/screenshots, reproducible failures, minimal straightforward patches and a changed-file list. Leave privileged publication/deployment to Hermes. Never claim execution or a passing result that did not happen.
