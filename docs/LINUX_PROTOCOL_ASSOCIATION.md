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

Run without sudo. This is a **per-user Linux desktop association reset**, not an uninstall of competing applications and not a system-wide change for other users. Unmanaged/symlinked target preference files are rejected rather than overwritten unsafely. It cannot erase browser-private remembered choices, session/portal caches, sandbox-specific preferences or prevent an app installed later from registering the protocol again. Restart the browser/session or reset its saved external-protocol choice if it continues to offer an old app.

Installer-only changes are published at the moving website installer URL and on the client source branch. They do not rewrite an already-published native archive/tag or require rebuilding/restarting the game server.

## Verification

`python3 tools/test_installer_associations.py` exercises the actual installer association functions under temporary XDG homes, including a native GLib/GIO query when available: the old handler is selected before reset; afterward Luani is both the default and the only associated choice. It also covers preserved unrelated protocols/system app files, desktop-specific overrides, backup contents, repeated refresh/new competitors, symlink safety and unconditional installer wiring.

These are installer-function/MIME-backend checks, **not** an executed full installer, browser launch or gameplay test. Gemini owns actual owner-desktop acceptance.

### Older xdg-utils versus GIO

Some Ubuntu/GNOME installations can report the new `org.luani.Client.desktop` through `gio mime`, but still select the attempt-1 `luani-protocol.desktop` through `xdg-mime`. Older xdg-utils checks `Exec` with a `first_word` helper that does not parse quotes. Our previously generated `Exec="/absolute/path/to/luani" %u` was valid for GIO but failed that older executable lookup, which then fell through to the legacy `mimeinfo.cache`.

The installer now generates `Exec=/usr/bin/env "/absolute/path/to/luani" %u` (or `/bin/env`): the first executable token is unquoted and valid for older xdg-utils, while the actual launcher argument stays safely quoted. This does not use shell evaluation or change authentication. The regression test generates the real desktop entry from installer source, includes an attempt-1 cache, and queries both GIO and an actual xdg-mime script. Set `LUANI_TEST_XDG_MIME` to its path when it is outside PATH. No URL/client is opened.

After reinstalling, both `xdg-mime query default x-scheme-handler/luani` and `gio mime x-scheme-handler/luani` should identify `org.luani.Client.desktop`. A disagreement is diagnostic evidence, not a reason to keep logging out or blindly remove old programs.

Reference: https://specifications.freedesktop.org/mime-apps/latest/
