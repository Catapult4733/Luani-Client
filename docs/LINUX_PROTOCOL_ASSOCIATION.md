# Linux luani:// association reset

The current installer at https://new.luani.fyi/client/install.sh refreshes the current user's `luani://` protocol registration on every install/update, including when the native release is already installed.

```bash
curl -fsSL https://new.luani.fyi/client/install.sh | bash
```

It registers `org.luani.Client.desktop`, then:

- Scans the configured XDG application/config directories for existing `luani://` handlers, including nested desktop IDs and system-installed apps. It reads system files but never modifies them.
- Makes Luani the only default/added `x-scheme-handler/luani` association in per-user generic `mimeapps.list` files. It masks competing desktop IDs with `Removed Associations`, so compliant desktop choosers do not offer them for this protocol.
- Refreshes user desktop-specific default overrides and existing legacy defaults files. It only writes Added/Removed groups in generic `mimeapps.list`, as required by the Freedesktop specification.
- Preserves other protocols, application files, comments, client settings and immutable game releases. Existing preference files receive hidden `.FILENAME.luani-backup-...` backups before changes. Rerunning without changes is idempotent; rerunning after a newly installed competing handler reclaims the protocol again.
- Uses `xdg-mime query default x-scheme-handler/luani` to check the result when that command exists. It never opens a URL or starts the game. A conflicting desktop result is reported as an error rather than silent success.
- Backs up and clears only `desktop-used-apps` / `x-scheme-handler/luani` from the current user's desktop-portal PermissionStore, then verifies its absence. This is a separate remembered browser app choice that can override correct MIME defaults. Other protocols, portal permissions and browser profile files are left alone. A missing portal utility/session is reported; a failed reset of an existing entry is an error, not silent success.

Run without sudo. This is a **per-user Linux desktop association reset**, not an uninstall of competing applications and not a system-wide change for other users. Unmanaged/symlinked target preference files are rejected rather than overwritten unsafely. It clears only the named Luani desktop-portal entry, not browser-private profile choices or other sandbox preferences. It cannot stop an app installed later from registering the protocol again. If the browser still selects an old app, inspect its actual routing rather than deleting browser profiles or repeating logout blindly.

Installer-only changes are published at the moving website installer URL and on the client source branch. They do not rewrite an already-published native archive/tag or require rebuilding/restarting the game server.

## Verification

`python3 tools/test_installer_associations.py` exercises the actual installer association functions under temporary XDG homes, including a native GLib/GIO query when available: the old handler is selected before reset; afterward Luani is both the default and the only associated choice. It also covers preserved unrelated protocols/system app files, desktop-specific overrides, backup contents, repeated refresh/new competitors, symlink safety and unconditional installer wiring.

These are installer-function/MIME-backend checks, **not** an executed full installer, browser launch or gameplay test. Gemini owns actual owner-desktop acceptance.

### Older xdg-utils versus GIO

Some Ubuntu/GNOME installations can report the new `org.luani.Client.desktop` through `gio mime`, but still select the attempt-1 `luani-protocol.desktop` through `xdg-mime`. Older xdg-utils checks `Exec` with a `first_word` helper that does not parse quotes. Our previously generated `Exec="/absolute/path/to/luani" %u` was valid for GIO but failed that older executable lookup, which then fell through to the legacy `mimeinfo.cache`.

The installer now generates `Exec=/usr/bin/env "/absolute/path/to/luani" %u` (or `/bin/env`): the first executable token is unquoted and valid for older xdg-utils, while the actual launcher argument stays safely quoted. This does not use shell evaluation or change authentication. The regression test generates the real desktop entry from installer source, includes an attempt-1 cache, and queries both GIO and an actual xdg-mime script. Set `LUANI_TEST_XDG_MIME` to its path when it is outside PATH. No URL/client is opened.

After reinstalling, both `xdg-mime query default x-scheme-handler/luani` and `gio mime x-scheme-handler/luani` should identify `org.luani.Client.desktop`. A disagreement is diagnostic evidence, not a reason to keep logging out or blindly remove old programs.

### Desktop-portal choice overrides

Brave/Chromium can open custom schemes through xdg-desktop-portal. Its PermissionStore is independent of MIME defaults: for example, `desktop-used-apps` / `x-scheme-handler/luani` can contain `org.chromium.Chromium: [luani-protocol, 3, 3]`. The portal can automatically prefer that existing old application after its remembered-choice threshold, even when xdg-mime, xdg-settings and GIO all identify the new client.

The installer uses the session PermissionStore API to save the exact Luani `Lookup` reply under `luani-client/protocol-backups` with mode0600, `Delete` only that MIME key, then verify `NotFound`. It never opens a URI, edits browser profiles, clears cookies or deletes the old application. Missing service/tool/session and denied deletion are distinguished. Tests cover the scoped call sequence, backup, idempotence, permission failure and missing utility; real owner-machine portal readback remains separate evidence from fixtures.

Reference: https://specifications.freedesktop.org/mime-apps/latest/
Portal selection logic: https://github.com/flatpak/xdg-desktop-portal/blob/1.21.1/src/open-uri.c
