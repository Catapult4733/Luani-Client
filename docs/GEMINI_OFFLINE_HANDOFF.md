# Gemini — Luani0.5.0-multiplayer.1 desktop verification

Hermes implemented multiplayer, deployed the control plane and is authorized to run the production headless server on the ThinkPad. Hermes did not run a gameplay client, editor/import/export, installer or desktop/headless gameplay test. Source checks, real rollback-only SQL/HTTP contracts, server bootstrap and verified external DTLS are NOT proof that two gameplay clients work. You own that verification on the development computer.

## Exact source and boundaries

- Client repo https://github.com/Catapult4733/Luani-Client ; branch `feat/website-multiplayer`, tag `v0.5.0-multiplayer.1`. Resolve/report the tag's exact SHA. Do not test an old offline branch or assume an old checkout is current.
- Website/backend repo https://github.com/Catapult4733/Luani ; branch `feat/baseplate-launch`. Key files: `Luani-Website/Dummy/{game,app,catalog}.js`, game.css and index.html; `Luani-Server/functions/luani-play/`; additive multiplayer migrations/validation.
- Source project `offline/project.godot`, entry `offline/main.tscn` -> bootstrap.gd; bundled native runtime Godot4.7.2. Main modules: secure_transport, network_client, dedicated_server, online_world, remote_player, player, hud, inventory, avatar and session_state.
- Run only on the owner's development computer. No Pi/ThinkPad SSH, Vaultwarden, Docker, credentials, backend/DB mutations, DNS, Cloudflare, production service changes, pushes or deployment. Do not weaken TLS/auth to make a test pass. Ask before installing packages, changing drivers, deleting installs or editing outside the checkout. Use owner-controlled test accounts; do not create bulk/fake activity.

## Install / browser protocol — first gate

1. Close the old client. Inspect the installer; run as the normal user, without sudo:

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
xdg-mime query default x-scheme-handler/luani
```

2. Installer must report0.5.0-multiplayer.1, not auto-launch, and register `org.luani.Client.desktop` for `luani://`. Repeat installation/update and verify idempotence and unchanged preferences. A direct app-menu/`~/.local/bin/luani` launch should show a website-launch screen, not pretend to be online.
3. Open https://new.luani.fyi/games/baseplate . Verify the real thumbnail upper left, title/Created by Luani upper right, description below left and live server list below right. Check mobile layout, direct navigation/reload, back/forward, catalogue card and old profile/downloads routes.
4. Logged-out Join must request website login. After login, Join should prompt the browser to open Luani; test its explicit fallback Open Luani Client link if activation is blocked. Cancelled/no-handler launches must give usable install/update guidance, not claim success.
5. Capture real native first-launch logs/screenshots, without `.godot` import cache. Ensure SVG/font/script preloads load and there are no parse errors (especially the old native `shortcut` collision). Do not record/copy full launch/admission codes or access tokens in the report.
6. Measure click-to-authenticated-world time and record real network/GPU environment. Do not invent latency figures or call a browser mockup a native screenshot.

## Two-player / server-authority acceptance

Use two owner-controlled accounts and separate browser profiles/client processes. The same account is intentionally limited to one live admission per game; a second same-account join should fail clearly rather than overwrite its datastore.

- Two accounts using Join game should share an existing server until capacity. Both must see the other username/avatar, movement, jumps, equipped gear and lantern/sword state. Players leaving disappear and server counts update. Names come from website accounts, not OS username or old local name settings; no display-name editor remains.
- Test first/third-person, camera, walking/running/jump/coil on both clients; record correction/jitter and frame rate. Client movement prediction must not let forged position/speed claims become authoritative. Verify player input stops while UI/text is focused or application focus is lost.
- Race both clients for one pickup: exactly one receives it; no duplication or disappearance on full bags. Equip/put-away/drop reflected on both sides; empty/invalid slots rejected; server full-world/pose updates never leak another logical instance.
- Eighteen inventory slots/nine hotbar slots; repeated1–9 puts away. Offline practice cannot upload its items. Online pickup/equipment survives leave/rejoin and respawn under the same account. Drop a tool and confirm it leaves saved inventory. Test normal leave, forced close/rejoin after lease expiry and transient network loss. Backend failures must fail closed, not become an online-looking offline world.
- Sword hits only shared practice targets within reach/facing/line of sight, with0.45s cooldown, three hits and five-second reset. No PvP was added. Lantern emission/light syncs without duplicate lights; coil effect stops on unequip/drop.
- Verify actual server list distinguishes active players and reserved joins, explicit selected-server Join, full/offline handling and automatic new logical instance creation at capacity. Do not fill production with fake users/load to force this without owner approval; mark capacity load testing NOT TESTED when not permitted. Initial cap:12/server, four logical instances on one bounded process.
- Run negative checks with scoped local code changes/fixtures on YOUR computer: malformed JSON/oversized packets, bad/reused/expired launch/admission code, wrong host/instance, forged name/avatar/peer ID, out-of-range pickup/drop/equip, inventory creation, movement speed and cooldown floods. Invalid authentication must never spawn or reveal another player's private datastore. Do not attack arbitrary hosts or expose cookies/credentials.
- Chat is intentionally **local-only notes**, not shared/moderated chat. Confirm its label, plain text,100-message bound and no accidental sword use from Send. In-game reporting remains explicitly unimplemented; use website support, do not fake report success.

## UI / focused regressions

Main glyphs20px, buttons36×32,6px gaps, fixed dimensions (no window-relative scaling); charcoal/lavender/Nunito Sans. Menu560×452, chat300×220, leaderboard240×280 with bounded scrolling, avatar360×420/320×244 preview, confirmations416×204. Test800×600,1280×720,1920×1080; long names ellipsize. Actual roster count/YOU badge must be truthful. Avatar view uses canonical appearance. Volume/mute/shift-lock work; no name entry. No old branding badge/full-width help strip. Test Escape layering, I, hotbar, E/Q, mouse capture/focus loss, ±89° pitch, first-person body visibility and reticle centering.

## Commands (desktop only)

Source-only checks, no engine:

```bash
python3 tools/check_offline_source.py
python3 tools/check_multiplayer_source.py
python3 tools/test_ui_member_names.py
python3 tools/test_protocol_launch.py
```

Optional actual engine contracts on YOUR desktop (Hermes did not execute them):

```bash
godot --headless --path offline --script res://tests/test_inventory.gd
godot --headless --path offline --script res://tests/test_ui_controls.gd
```

Use the installed release's `engine/godot` with its `game` directory if no system Godot4.7.2 exists. The old `check_offline_security.py` prohibits all networking and is an offline-only historical check; use the new multiplayer guard here. Website's targeted HTTP-fixture tests: `node --test tests/unit/multiplayer-auth.test.mjs`. Full website suite/build/review is yours, not evidence Hermes already obtained.

## Return

Report environment, exact source/release SHA, PASS/FAIL/NOT TESTED for each group, real native/browser screenshots and redacted logs, measured join time/UI rectangles, exact repros, changed files and diff for straightforward scoped fixes. No fabricated clients, users, screenshots or CI results. Leave privileged publication, backend/Cloudflare/Pi/ThinkPad operations to Hermes.
