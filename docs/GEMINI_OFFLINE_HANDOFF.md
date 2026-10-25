# Gemini 3.8 Flash High — Luani0.4.0-offline.2 runtime verification

Hermes implemented this source and distributed an explicitly runtime-untested preview. **Hermes has not launched Godot, the editor, imports/exports, a headless game, an engine version probe or the installer.** Source grammar/resource/security and distribution-byte checks are not runtime evidence. You are the desktop runtime verifier.

## Source / provenance

- Repository: https://github.com/Catapult4733/Luani-Client
- Branch: `feat/figma-inventory-client`, release tag `v0.4.0-offline.2`. Resolve the tag to its exact commit SHA, check the checkout and report it before testing. Do not use `feat/linux-offline-client`: that checkout had overlapping edits and is not this implementation.
- Project: `offline/project.godot`, entry: `offline/main.tscn`; bundled/pinned native runtime: official Godot4.7.2.
- Main code: `hud.gd`, `ui_theme.gd`, `ui_controls.gd`, `item_catalog.gd`, `inventory.gd`, `item_visual.gd`, `pickup.gd`, `practice_target.gd`, `world.gd`, `player.gd`, `avatar.gd` under `offline/scripts/`.
- Actual Figma exports/hashes: `offline/assets/ui/figma/asset-manifest.json`; font in `offline/assets/fonts/`, new inventory/item icons in `offline/assets/ui/items/`.
- Figma: https://www.figma.com/design/s2h0NnfLdAFDeYN3WfSBKd/Sin-t%C3%ADtulo?node-id=12-373 ; Settings6:19, Players7:60, Chat7:245, Leaderboard7:256, Avatar7:375, confirmations7:474/7:482.

## Boundaries

Run on the owner's development computer only. Do not access/change Pi services, Vaultwarden, Docker, backend, DNS, Cloudflare, production website, credentials, or legacy client/Studio/daemon code. Do not push or deploy. Ask before installing packages, changing drivers, removing installs or editing files outside this checkout. Keep all modifications scoped and report them.

## Install / real first launch

Record real OS/distribution, CPU architecture, GPU/driver and desktop session. Quit the old client; inspect the installer and update as the normal user, without sudo:

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
```

Check installed manifest/version is0.4.0-offline.2. Verify installation does not auto-launch. Launch from app menu or `~/.local/bin/luani`; capture real logs. This is a source-runtime bundle, not a PCK. Test with no pre-existing `.godot` import cache and ensure local SVG/font/script preloads load on a fresh installation. Do not substitute a browser mockup for a native screenshot.

If testing source directly, use your installed Godot4.7.2 with `--path offline`. The installer supplies a native binary under the installed release's `engine/godot`, with project at `game/`. Do not require a system editor solely to run the bundle.

## Startup hotfix regression — verify first

The owner reported that 0.4.0-offline.1 installed but failed before world startup:
`Could not resolve external class member "shortcut"` at hud.gd:159, followed by
world.gd dependency compilation and `.new()` failures. The custom HudButton
String field shadowed native BaseButton.shortcut (a Shortcut resource).
This version renames only the custom field and its two consumers to
`shortcut_hint`; do not change GPU drivers or the installer to treat this bug.

Run `python3 tools/test_ui_member_names.py` for the source-only collision guard.
On YOUR desktop, also run the actual Godot dependency/tooltip contract:

```bash
godot --headless --path offline --script res://tests/test_ui_controls.gd
```

Use the bundled executable if no matching system Godot is installed. Then
perform a fresh native launch, capture the complete log and verify that the
HUD and world load. Hermes has not executed this runtime contract. A passing
Python source guard does not prove Godot compilation or gameplay correctness.

## Source checks / inventory contracts

These inexpensive Python checks do not execute the game:

```bash
python3 tools/check_offline_source.py
python3 tools/check_offline_security.py
```

There is also a **Godot runtime** inventory contract, written but not run by Hermes. With a trusted Godot4.7.2 executable on YOUR desktop, run:

```bash
godot --headless --path offline --script res://tests/test_inventory.gd
```

For the installed bundle, replace `godot` with the release's `engine/godot` and `--path offline` with its `game` directory. Report the real result; do not infer a pass from a source parser. This checks empty/invalid slots and IDs, equip/put-away, copied snapshots, removal/unequip, capacity and atomic failed multi-item adds.

## Native UI / Figma acceptance

1. Compare actual native screenshots with the Figma references. Keep OS DPI constant and measure UI at800×600,1280×720,1920×1080. Expect fixed logical dimensions, not proportional window scaling.
2. Menu/chat/leaderboard/backpack controls must be36×32, faces36×30, original main glyphs20px. Left offset16 and6px gap; right controls16px from the edge with6px gap. Confirm hover, pressed depression, open indicator/tint, open-hover, keyboard focus and disabled rendering; no size animation.
3. Verify charcoal202229/field2B2E38, lavenderC1ADFF, Nunito Sans regular/600/700. Confirm actual exported icon shapes, no clipped/missing glyphs and no fallback boxes from font loading.
4. Fixed sizes: menu560×452, chat300×220, leaderboard240×112, avatar360×420 with320×244 live3D stage, leave/respawn416×204. Check native minimum sizes do not force growth. Long24-character names should ellipsize rather than widen panels.
5. Menu: Players then Settings pills; default Settings; proper close X and persistent Leave/Respawn/Resume game footer. Test switch, actual volume/mute/name edits, keyboard navigation, Escape and confirmations. Cancel must return to the menu. Respawn retains inventory; Leave clears the session.
6. Players/leaderboard show the single real local player; count1 and YOU are truthful. Block/Friend/Report remain disabled with offline explanation. Avatar Back returns to Players, independent of the hidden first-person body.
7. Chat stays local-only, unmoderated and plain text. Test `/`, Enter, click-to-open/close, Send, whitespace, literal markup, long messages and100-message bound. Sending/closing must restore camera controls, without triggering swords.
8. No old top branding/camera badge or bottom help strip. The new compact hotbar is contextual: hidden while empty and during modals, shown once items exist; it is not the removed full-width help strip.

## Inventory / pickups / interaction acceptance

1. Near spawn, find the sword around(4,-5), lantern around(-5,-4), coil around(2,6) in X/Z. Eighteen total pickups are spread around the baseplate. They float above small pads, never block movement, and only the nearest in-range/visible one shows the name/pickup prompt.
2. Press E to collect once. Holding/rapidly pressing E must not duplicate that world object. The first pickup auto-equips; later pickups do not replace the active tool. Empty/invalid/full operations are covered by the inventory contract; when a pickup cannot fit, it must remain in the world.
3. I/backpack opens/closes an18-slot inventory. Slot selection updates name/description; Equip/Put away is real; Drop returns that item to the map. Verify all18 grid slots are separate and fit, including the last row.
4. First nine slots map to1–9 and clickable hotbar cells. Repeating the selected number puts it away; empty numbers do nothing. Items equipped from slots10–18 still work and have an equipped caption even though those slots are not on the nine-slot hotbar.
5. Q drops the equipped tool at a bounded point on the baseplate. The bag slot clears, equipment/passive effects disappear immediately, and E can pick the dropped item after its short cooldown. No duplication/loss over repeated pickup/equip/drop cycles.
6. **Sword:** visible in the right hand in third person, lower-right view model in first person. LMB plays a short swing without scaling the HUD. Facing a target within reach gives one hit per swing; behind/out-of-range/occluded targets do not get hit. Each target has3 hits and resets after5 seconds. Verify0.45-second use cooldown and no hits from clicking UI.
7. **Lantern:** visible held model in both modes. LMB toggles actual light AND lamp emission; repeated clicks respect cooldown. Hidden duplicate models must not add duplicate lights or leave light behind after unequip/drop.
8. **Spring Coil:** holding it increases jump impulse. Switching away, putting away or dropping restores normal jump on the next jump; no permanent stat or stacking exploit.
9. Character respawn/falling preserves bag contents and remaining world pickups without duplicating them. Closing/relaunching resets the session inventory/map but keeps display name, shift-lock permission and volume preferences.

## Focus / camera regressions

WASD/Space/Shift remain functional; Ctrl permission independent of full-inward first person; unlimited horizontal look and existing±89° vertical guard; scroll outward restores orbit; hidden local avatar/name only in first person. Verify no movement/look/E/Q/number/tool input leaks while typing or in menus, avatar, inventory or confirmations. I must not close/open inventory while typing a letterI. Clicking hotbar or Send must not also swing. Escape closes the correct layer and restores mouse capture when appropriate. Focus loss must release capture and stop actions; focus return restores the correct mode. Check the reticle remains centered on resize.

## Return

Provide actual environment, release/source SHA, PASS/FAIL/NOT TESTED for each group, measured UI rectangles, real native screenshots/logs, exact repros and only straightforward scoped fixes. Do not invent runtime evidence. Leave GitHub publication, website, Cloudflare and privileged deployment to Hermes; report all changed files and the resulting diff.
