# Gemini 3.8 Flash High — Luani Linux offline verification handoff

You are testing a deliberately runtime-untested Luani offline client on the owner's development computer. Hermes implemented and published it but, at the user's explicit request, DID NOT run Godot, an exporter, the game, headless execution or gameplay tests. Do not treat static syntax/package checks as runtime evidence.

## Source and scope

Repository: https://github.com/Catapult4733/Luani-Client
Branch: `feat/linux-offline-client` (record exact commit before testing).
New project: `offline/project.godot`; entry scene `offline/main.tscn`.
Code: `offline/scripts/{session_state,avatar,player,hud,world}.gd`.
Distribution: `distribution/{install.sh,luani,package_linux.py,release.json,icon.svg}`.
Do not modify or launch historical `client_and_studio/`, `server_daemon/`, `web_backend/`, nested clones or old production-linked scripts.

## Permissions / boundaries

The user explicitly delegates game execution/testing to you on this development computer. Prefer a real Linux graphical desktop; do not call Windows-only testing “Linux passed”. Ask before installing system dependencies, changing graphics drivers or deleting any existing installation. Do not access Pi/Vaultwarden, configure Docker/firewalls/tunnels, alter Supabase, publish GitHub releases, change the website or use credentials. Hermes owns privileged publishing/deployment.

## Installation and initial launch

1. Record Linux distribution, CPU architecture, desktop session, GPU/driver, exact source SHA and published manifest/version. Never invent hardware or output.
2. Inspect `https://new.luani.fyi/client/install.sh`, then install as the normal desktop user using:
   `curl -fsSL https://new.luani.fyi/client/install.sh | bash`
3. Confirm that the installer DOES NOT launch Godot or a game. Check the app-menu entry, `~/.local/bin/luani`, current symlink, package receipt, architecture and executable permissions.
4. Launch the app-menu entry or `~/.local/bin/luani` and capture actual game output/errors. This preview uses a bundled official Godot 4.7.2 binary with `--path` to a source-runtime project; it was not exported/PCK-packed. Confirm a fresh installation can load all GDScript classes/resources without editor imports or a preexisting `.godot` cache. If not, report and fix the source/runtime packaging; do not claim success based on a warmed editor cache.
5. For source-only fixes, run the matching bundled engine against the checkout's `offline/` directory, or use a confirmed matching Godot installation. Record exact commands. Do not silently replace the official runtime with a different version.

## Acceptance checklist (real execution required)

- Launch opens an empty gridded baseplate directly, not the old launcher/Studio or an invented online game.
- Original six-part humanoid is visible, standing above the baseplate with correctly attached head/torso/arms/legs and face. Check idle, walk, run, jumping and falling animation; no detached body pieces or upside-down motion.
- WASD is camera-relative. Space jumps only from the ground. Holding Shift runs faster and releasing it restores walking. Diagonal movement is not faster. Falling off respawns.
- RMB orbit, wheel zoom, camera collision and pitch limits work. Ctrl toggles shoulder-camera shift lock and crosshair, without changing the run key.
- Settings shift-lock toggle controls whether Ctrl is allowed. Disabling it while locked immediately unlocks. Merely enabling the setting does not force lock on.
- Menu galaxy emoji and Chat button are on the left; Leaderboard button is on the right. Check window resize, 1280×720 and minimum-size layout, fonts/glyph fallback and keyboard focus.
- Escape opens/resumes menu. Settings and Players tabs work. Resume, Respawn and Leave confirmation work. Cancelling Leave returns to the menu. Mouse capture returns correctly after overlays close and after focus loss/regain.
- Menu/avatar overlays and focused text inputs prevent WASD, jump, run and camera motion from accidentally controlling the player. Shift lock must not make the menu unusable.
- Volume changes actual synthesized footsteps/jump audio; zero mutes and restore works. Display name and shift-lock/volume preferences persist across restart, without credentials or network use.
- Chat button toggles chat; Enter or `/` focuses it. Send by Enter and button. `Hello World` appears as `Username : Hello World`. Empty messages do not send. Text resembling BBCode/HTML is displayed literally. Closing/submitting chat releases keyboard capture. It is clearly local-only and has no profanity moderation; no remote message delivery is claimed.
- Leaderboard toggles via button/Tab and shows only the one actual local player, without fake scores.
- Players page shows the current local name; View avatar opens an animated independent preview and Back returns to Players. Block/Friend/Report are visibly disabled with truthful offline/self-action explanations. Do not fabricate peers to make them appear functional.
- Confirm no gameplay HTTP, ENet, account login, voice capture, telemetry, daemon calls or old-domain requests originate from this project.
- Run the same installer command again and confirm idempotence, preserved preferences and no auto-launch. Inspect safe archive extraction and atomic update logic; do NOT manufacture a fake live release or modify the production channel to simulate an update. If a true cross-version update cannot be tested, mark that explicitly unverified.

## Deliverables

Return: exact OS/hardware and source SHA; PASS/FAIL/NOT TESTED per checklist; reproduction steps and real logs for failures; screenshots at desktop/minimum sizes; minimal patches for straightforward fixes; changed-file list; remaining complex blockers; and what still needs Hermes publication. Do not push/deploy without the user's separate instruction. Preserve existing user data and old releases. Never synthesize passing logs or claim tests that were not executed.
