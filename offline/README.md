# Luani Client — Figma UI + inventory offline preview

Version **0.4.0-offline.1**. Runtime **NOT TESTED by Hermes**, by the owner's explicit request. No Godot, editor, import/export, engine version probe, headless game or installer has been executed by Hermes. Source grammar/resource/security checks and archive/public delivery checks are separate from gameplay verification. Gemini must launch and verify this build on the owner's Linux desktop.

## Install or update

Quit the running client. As your normal desktop user, without sudo:

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
```

The same command installs and updates. It never auto-launches. Start **Luani Client** from the applications menu or run `~/.local/bin/luani`.

Requires 64-bit Linux x86_64 or ARM64, a graphical desktop with working OpenGL drivers, Python3 and curl. The native runtime is pinned official Godot4.7.2, bundled with the source project. No separately installed editor is needed; ARM64 packaging does not imply that a particular Pi/GPU has been runtime-tested.

## Figma UI implementation

The owner-approved design is in Figma file `s2h0NnfLdAFDeYN3WfSBKd`. The refined control study is node `12:373`; reusable control is `12:368`.

- Actual Figma-exported orbital menu, chat and player-podium glyphs, local Nunito Sans font, charcoal panels and lavender actions.
- Fixed36×32 HUD controls, 36×30 faces, 20px glyphs and6px gaps. Separate resting, hover, depressed, open/open-hover, keyboard-focus and disabled appearances. No scale-on-hover. Real button callbacks toggle the corresponding views.
- Menu560×452 with Players/Settings pills, close, shift-lock switch, working volume/name fields and fixed Leave/Respawn/Resume footer. Chat300×220; leaderboard240×112; avatar360×420; custom leave/respawn confirmations416×204.
- The avatar stage is a live3D view in the same320×244 design slot rather than the static design placeholder. Volume is a native interactive slider, not a screenshot of70% volume.
- Fixed logical pixels with project stretching disabled. Window resizing repositions panels, not fonts or controls. The top branding/camera badge and old full-width bottom help strip remain absent.
- Actual local name, one player, no fake scores or online activity. Block/Friend/Report remain disabled and explained offline. Chat remains local-only, unmoderated plain text,100 recent messages, discarded on exit.

## Inventory and tools

- **I** or the backpack button opens/closes the18-slot inventory. Click a slot, then **Equip / Put away** or **Drop**. The first nine slots form a compact hotbar once you collect an item; **1–9** or slot clicks equip/put away those slots.
- Approach a floating item and press **E**. Selection is range/line-of-sight checked; a full bag never consumes a pickup. The first pickup auto-equips. **Q** drops the equipped item back onto the baseplate, with a short re-pick cooldown. Empty/invalid slots do nothing.
- Eighteen tools are scattered in fixed, varied locations around the240×240 baseplate, including one of each kind near spawn. They are finite session objects; pickups do not continuously duplicate or reappear.
- **Moonsteel Sword:** click to swing. Both third-person arm and first-person view-model animate. Face a nearby wooden practice target to hit it. Each target takes three hits, disappears and resets after five seconds; a0.45-second swing cooldown prevents repeated-frame hits. No PvP, damage to real people or multiplayer is implied.
- **Trail Lantern:** click to toggle actual warm3D light and the lantern's glow. It has a visible held model in both camera modes.
- **Spring Coil:** equip to increase jump impulse; put away/drop it to restore normal jumps. Holding a coil is not a permanent saved upgrade.
- Inventory and remaining world items survive **character respawn** within a session, without granting duplicate starting items. They reset when the game closes. They are not saved to an account or synced to the website.

## Existing movement/camera

WASD movement, Space jump, held Shift run, Ctrl shoulder-camera shift lock when allowed in Settings. Hold RMB to orbit in third person; scroll fully inward for captured-mouse first person, outward to return. Horizontal rotation remains unrestricted with the existing±89-degree vertical guard. Local avatar/name hide only in first person; the independent avatar viewer remains visible.

Menus, inventory, confirmations and focused chat block movement/tool actions and release capture. Esc closes the active view or opens the menu. Enter or `/` focuses chat; Tab toggles the leaderboard outside typing/modals. Text fields must not trigger I, hotbar, E, Q, movement or tool use. Application focus loss releases capture and gates tool input.

## Data, installation and rollback

Settings stay in the existing separate Godot `user://` directory for “Luani Client”; updates preserve them. No login, HTTP/ENet/WebSocket, telemetry, microphone, creator scripts, Studio, marketplace or backend integration is part of this offline project.

Versioned bundles live under `${XDG_DATA_HOME:-$HOME/.local/share}/luani-client/releases/`; `current` is switched atomically. The managed launcher is `~/.local/bin/luani`; the app-menu entry is under the user's applications directory. Old releases are retained for manual rollback. The installer validates same-origin HTTPS, bounded sizes, SHA256, archive paths/types and managed launcher ownership. HTTPS-manifest hashes are integrity checks, not independent signatures. No sudo or system-package changes are requested.

`distribution/package_linux.py` reads and verifies official runtime archives and assembles source-runtime bundles **without executing the engine**. Local SVG and font bytes are decoded directly at launch, without a pre-existing editor import cache. Asset provenance/hashes are in `assets/ui/figma/asset-manifest.json`; Nunito Sans's licence is in `assets/fonts/OFL.txt`. See `docs/GEMINI_OFFLINE_HANDOFF.md` for required runtime verification.
