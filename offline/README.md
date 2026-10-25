# Luani Client — multiplayer Baseplate preview

Version **0.5.0-multiplayer.1**, bundled official Godot **4.7.2**. Hermes is authorized to run the production headless server on the ThinkPad, but has **not run a gameplay client, installer, editor/import/export or desktop/headless gameplay test**. Production bootstrap, backend contracts and download integrity are distinct from two-player gameplay verification, which remains Gemini's responsibility.

## Install and join

As your normal Linux user, with the old client closed:

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
```

The installer never starts the game. It installs the per-user `luani://` desktop handler. Log in at https://new.luani.fyi/games/baseplate and choose **Join game**; accept your browser's request to open Luani. A direct app-menu/`~/.local/bin/luani` launch opens the website launcher and an explicit offline-practice option. A failed online join never silently becomes offline play.

Requires Linux x86_64 or ARM64, a graphical desktop/OpenGL, Python3 and curl. No separately installed editor or system-wide/sudo installation is required. ARM64 availability is not a claim of desktop/GPU testing on every Pi.

## Authentication and data

- The URL contains a random, one-use, 90-second launch code, **not a reusable browser cookie/JWT**. The handler redeems it over pinned-origin HTTPS and passes the resulting short-lived admission through anonymous inherited memory, not engine command lines, environment or disk.
- The client verifies the game server's DTLS certificate obtained over HTTPS. The server independently consumes the instance/host-bound admission before spawning. Client-supplied usernames, avatars, player IDs and positions are not authoritative.
- Both redemption and server admission load the canonical Luani username, original six-part avatar appearance and private per-user/per-game datastore. The client menu has no name editor; account names are managed on the website.
- Inventory is server-owned online and saved periodically and on normal leave. Data leases fence obsolete admissions; separate boot epochs fence delayed heartbeats after restarts. Offline practice remains session-local and cannot upload offline items.
- Only first-party Baseplate is hosted. No creator scripts, downloads of executable worlds, Studio, economy, voice or arbitrary server URLs are supported. Chat remains clearly labelled local-only notes, not a multiplayer messaging system.

## Servers and multiplayer

Matchmaking atomically fills an existing non-full logical server before creating another. Pending joins reserve seats, expire, and cannot overbook. Initial limits are **12 players/server, four logical servers** on a single sandboxed first-party ThinkPad process and one configured UDP relay. Full hardware capacity returns an explicit busy response rather than unlimited processes. Empty instances are reclaimed. Rosters/counts reflect admitted players; stale hosts disappear.

The server simulates movement/grounding/jumps and validates pickup distance/line of sight, bag capacity, equip/drop, tool cooldowns and practice-target hits. Clients predict local movement, receive corrections, interpolate remote characters and exchange bounded JSON over DTLS/ENet. No Variant/object deserialization or remote code execution is provided.

## UI and controls

Fixed36×32 Figma menu/chat/leaderboard/backpack controls,20px glyphs,6px gaps, local Nunito Sans and charcoal/lavender styling remain. Menu560×452, chat300×220, bounded multiplayer leaderboard240×280, avatar360×420 with320×244 preview, confirmations416×204. Resizing repositions controls, not fonts/sizes. No old branding badge/full-width bottom help strip.

WASD moves, Space jumps, held Shift runs, Ctrl optional shift lock, RMB orbit, inward scroll first person/outward orbit, existing ±89° pitch guard. **E** pickup, **I** inventory, **1–9** hotbar, **Q** drop, click use. Inventory has18 slots/nine hotbar positions. Sword hits shared practice targets (not PvP); lantern toggles light; equipped coil increases jump. Menus/text/app focus gate gameplay input. Respawn preserves online inventory. Local notes clear on exit.

## Distribution and operations

Versioned packages remain under `${XDG_DATA_HOME:-$HOME/.local/share}/luani-client/releases`; `current` switches atomically, preferences stay separate, old releases remain. The installer validates same-origin HTTPS, sizes, SHA256 and archive paths/types. These are delivery-integrity checks, not independent publisher signatures.

The packager reads verified official ZIPs/ELF headers and assembles bundles without running Godot. Font/SVG bytes load directly, without an editor import cache. Asset hashes/licences are retained. See `docs/GEMINI_OFFLINE_HANDOFF.md` (historical filename, now multiplayer checklist) for remaining real runtime verification.
