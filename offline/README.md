# Luani Client — Linux offline preview

Version: **0.3.0-offline.2**. The owner reported the previous preview working. This camera/UI update has not been gameplay-tested by Hermes: no Godot, exporter or headless game was launched. Gemini must verify these changes on a Linux desktop.

## Install / update

Run as your normal desktop user, **without sudo**:

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
```

Run the same command to update. Installation does not start the game. Launch **Luani Client** from the applications menu or run `~/.local/bin/luani`.

Requires 64-bit Linux (x86_64 or ARM64), a working graphical desktop/OpenGL driver, Python 3, curl, and normal system libraries required by Godot 4.7.2. A 32-bit OS is unsupported. ARM64 packaging is not a claim that a particular Raspberry Pi graphics setup has been tested.

The installer downloads a pinned native Godot runtime bundled with the project source. This packaging avoids running an exporter or game during delivery; no separate Godot installation is needed. The supplied menu/chat/leaderboard SVGs are decoded directly at runtime, without editor imports or a preexisting import cache. The baseplate, character, animations and sounds are procedural. No creator scripts or legacy online modules are loaded.

## Implemented controls and UI

- WASD: camera-relative movement. Space: jump. Hold Shift: run.
- Ctrl: toggle shoulder-camera shift lock, if the Settings permission is enabled.
- Third person: hold right mouse to look around. Horizontal rotation is unrestricted; vertical look is widened to almost straight up/down (89 degrees each way), retaining a small anti-flip guard.
- Scroll completely inward to enter first person: eye-height camera, hidden local body/name tag, centered reticle and captured mouse without holding RMB. Scroll outward to return to third person. First person does not depend on the shift-lock setting.
- Esc/menu and focused chat release mouse capture; closing the overlay restores the active camera mode. Focus loss also releases capture. Esc: menu/resume.
- Original six-part block humanoid with idle, walk, run and airborne procedural animation, blinking and synthesized movement sounds. No Roblox assets, logos or animation files are used.
- Empty gridded baseplate; falling off its edge respawns you.
- Left: the owner's supplied galaxy/menu and chat SVG buttons, with hover/open-state outlines. The supplied leaderboard SVG sits on the right. The HUD has a camera-mode badge, compact controls strip, translucent rounded panels, clearer settings groups and persistent Resume/Respawn/Leave actions outside the scrolling tabs.
- Enter or `/` focuses chat. Messages display `Username : message`. Chat is local-only, unmoderated, non-persistent and capped to recent messages for memory use; text is not interpreted as markup.
- Right: leaderboard toggle, also available with Tab. It lists the actual single local player, without fake scores or invented users.
- Menu Settings: shift-lock permission, master game volume, editable offline display name, Resume, Respawn and confirmed Leave.
- Menu Players: current local player, animated avatar viewer, and explicitly disabled Block / Send friend request / Report controls. Those are online actions and cannot be performed on yourself in an offline build; nothing pretends to reach a server.

Device-local preferences are saved under Godot's `user://` directory for “Luani Client”, outside the installed releases. Updates preserve them. Chat is discarded on exit. There is no website login, multiplayer, voice chat, Studio, publishing, telemetry or runtime network request in this offline project.

## Installation layout and rollback

- `${XDG_DATA_HOME:-$HOME/.local/share}/luani-client/releases/`: versioned bundles.
- `.../luani-client/current`: atomically switched release symlink.
- `~/.local/bin/luani`: managed launcher.
- `${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.luani.Client.desktop`: app-menu entry.

The installer checks HTTPS origin, package size/SHA-256, archive paths/types and required files before switching releases. It does not request root or alter system packages. Hashes provide integrity against the published HTTPS manifest; they are not an independent digital signature. Old releases remain available for manual rollback. Running the same command with the same published release refreshes launchers without starting the game.

To uninstall, remove only the managed launcher, app-menu entry and `luani-client` install directory above. This does not remove Godot's separate user settings unless you choose to delete those too.

## Source and packaging

This `offline/` project is independent of the historical `client_and_studio/` project. Existing checkouts and attempt-1 deployments are not overwritten.

`distribution/package_linux.py` verifies pinned official Godot ZIP hashes and assembles x86_64/ARM64 archives without running an engine. `distribution/install.sh` is the installer served by the website. See `docs/GEMINI_OFFLINE_HANDOFF.md` for the required interactive verification.
