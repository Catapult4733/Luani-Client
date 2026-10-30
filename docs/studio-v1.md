# Studio v1 native source

This change is implementation source, not an independently reviewed or published release.

Start desktop Studio through the managed launcher with `luani --studio`; the updated installer also creates a separate **Luani Studio** applications entry. It deliberately does not register another `luani://` handler. Website cloud open uses paired one-use `studio=edit` links, and native Playtest uses `studio=play` links. The existing client handler validates and redeems either kind into a private in-memory FD.

The native editor has the viewport, Explorer, Properties, select/move/rotate/scale, hierarchy editing, insert/duplicate/delete, undo/redo, local file open/save, cloud draft save, cloud publication, settings, cloud game open, playtest and guarded Exit. Camera: right mouse orbit, middle mouse pan, wheel zoom, F frame selection; focus the viewport for Q/W/E/R and Delete. Ctrl-S saves locally, Ctrl-Z/Shift-Ctrl-Z undo/redo, Ctrl-D duplicates. Cloud credentials are memory-only; opening a website draft does not import browser credentials, and cloud writes require native sign-in.

Supported instances are exactly Part/Model/Folder/SpawnPoint/Weld/PointLight/SpotLight/DirectionalLight. `offline/studio/instances.json` is shared byte-for-byte with the website registry. The native constructors only instantiate fixed trusted engine classes; world files cannot name scripts/resources/engine classes. Parts have Block/Ball/Cylinder shapes; Welds create rigid assemblies. World JSON has strict property types and bounds, hierarchy/reference validation and object/light/movable/byte budgets.

Local play uses a real loopback-only ENet/DTLS server with an ephemeral certificate/admission and a separate physics world, alongside the gameplay client in one process. It is not an animation or a separate OS service. It makes no production host pulse, inventory or datastore writes. Published creator-world rooms use the upgraded first-party dedicated server, immutable cloud revision pins and boot-bound capability checks.

Website/cloud/migration documentation is `docs/studio-v1.md` in Catapult4733/Luani. The paired implementation lives on `feat/studio-v1` in isolated native and website worktrees. Integrate with the latest public release without rolling back avatar/channel changes; no force-push or wholesale old-tree replacement.

## Checks

- `python3 tools/test_studio_contract.py`
- `python3 tools/test_studio_protocol.py`
- `bash -n distribution/install.sh`
- Engine import on edward: `godot --headless --editor --import --quit --path offline`
- Engine contract on edward: `godot --headless --path offline res://tests/test_studio.tscn`
- Real rendered/pointer capture in a private virtual display: `godot --audio-driver Dummy --display-driver x11 --rendering-method gl_compatibility --path offline res://tests/capture_studio.tscn`. Change the test capture path to a task-owned directory when moving machines; do not use the owner's desktop or close Brave.

The native test passed document edits, Properties rename/selection, file roundtrip, rigid Weld construction and actual DTLS admission/movement on Godot4.7.1. The capture passed actual pointer move/rotate events on Mesa llvmpipe. Release packaging pins Godot4.7.2 and must be retested as the exact packaged artifact. The local test still logs a certificate-export Unicode-NUL warning and a DTLS error during voluntary teardown; investigate/fix those, do not weaken DTLS or call the logs clean. There is no authenticated production Studio or published-world multiplayer evidence yet.

Gemini owns the full independent review, broader tests, native/Android builds and deployment. Candidate fresh versions are Linux0.6.0-studio.1, preview0.6.0-android.1/50007 and Play0.6.0-play.1/50008; confirm they are unused before publication and preserve all signing identities, package IDs, Android website-led UX, admission authority and existing avatar behavior. The Studio editing UI is Linux desktop-only; Android receives the creator-world gameplay support. AAB50006 and existing release assets stay immutable.
