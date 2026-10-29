# Native avatar/store integration — review before release

Branch `feat/avatar-store-20261029`, based on `5f309d6862ac123a8b48f9e91fef124e37ff728b`. Exact final commit is recorded in the delivery manifest. Website companion is `Catapult4733/Luani` on the same branch, based on prepared Play policy source `d8188c6c556d1a6ad3c512725f19fb7deee84995`; read its `docs/AVATAR_STORE_REVIEW.md` for DTO, SQL and deployment boundaries.

## Changed contract

- `offline/assets/avatar/definition.json` must be byte-identical to the website definition. It is original data-only geometry, not a remote asset/script loader.
- Six independent colours live in `appearance.colors`; the existing accent stays part of the uniform. Older four-field appearance normalizes to six parts. A missing accessory list is empty, regardless of catalog contents.
- Saved accessory entries are `{id,position:[x,y,z],rotation:[x,y,z]}`. Offsets are local to the attached body pivot, Y up, forward -Z; Euler XYZ degrees. Only six known IDs and bounded finite vectors render. No scaling, collisions, item stats or ownership claims come from this visual data.
- `avatar.gd` retains the six original body pivots and changes materials/accessory-only children on refresh, preserving held tools and animation. `avatar_data.gd` is a rendering normalizer, not an ownership authority.
- The dedicated server adds known revision metadata and an opt-in flag to its existing authenticated HTTPS pulse. SQL returns at most16 changed active-admission appearances. `avatar_sync.gd` matches both the current admission and immutable public ID, ignores old revisions and returns only changed rooms. Admission, boot fencing, DTLS, lease and gameplay actions are unchanged.
- A room roster refresh updates canonical SessionState/avatar visuals for the local and existing remote player. It does not emit controls/audio preferences_changed or replace body/controller nodes. The player never sends avatar/ownership writes through UDP.
- Android presets include `*.json`; Linux packaging already copies offline assets. Native startup/chrome/branding, touch input, facing and game inventory logic are preserved.

## Checks and what remains unverified

Hermes ran only `python tools/test_avatar_contract.py` and GDScript syntax parsing with gdtoolkit4.5.0. This is not Godot semantic compilation, render execution, Android packaging, two-account multiplayer or physical-phone acceptance. The new runtime test below is authored but unexecuted by Hermes. No native process was started on the Pi.

On edward (not the Pi), locate the already verified4.7.1 runtime and use an isolated task checkout, not the owner's dirty workspace:

```sh
python3 tools/test_avatar_contract.py
# Set GODOT to the existing matching binary; do not install/run a game on Pi.
timeout 45 "$GODOT" --headless --path offline --script res://tests/test_avatar.gd
```

Require exit0 plus the explicit successful contract message; a parser/ASSERT log with a running process is not a pass. Test checks empty defaults, different left/right colours, each original SKU, local XYZ placement, material application, retained held-tool/pivot nodes, removal and admission/public-ID/stale-revision filtering. It uses fixture-only data and no accounts/network.

Independent acceptance must also exercise real browser Save → freshly admitted client and Save while both accounts are in-game → updated local/remote visuals on the next bounded host pulses. Verify cross-room isolation, no appearance claim from forged UDP messages, stale host boot rejection, malformed/large snapshots, all six accessory meshes and rotated attachments against the Three.js preview. Keep normal store item inventory distinct from cosmetic ownership. Check held tool, movement animation, camera/first-person/shift lock, mobile joystick and focus preferences throughout hot updates.

Do not claim sustained60 FPS on a physical Galaxy A16 from syntax, screenshots or an emulator. Avatar geometry adds bounded draw work and needs actual performance measurement.

## Immutable release boundary

The existing uploaded Play AAB50004 and public Android3/Linux releases are unchanged and do not include this feature. Export presets still carry the old release identifiers deliberately: **do not export or publish them as a new avatar release without Hermes selecting a new unused version/version code after review.** Never overwrite the old package paths, published tags, channel metadata, original signing keys or the delivered AAB. Build/package on edward only; no new signing identity.

Gemini reviews/tests and reports patches/evidence. Hermes alone handles GitHub publishing and privileged schema/edge/static/game-host deployment after the review gate. Do not launch production-linked servers, touch Vaultwarden/ThinkPad services, weaken TLS/admission, close the owner's Brave, or print/archive secrets or real launch tickets.
