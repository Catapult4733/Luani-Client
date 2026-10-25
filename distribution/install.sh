#!/usr/bin/env bash
# Installs or updates Luani Client for the current user. Never launches the game.
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' 'Luani requires Python 3. Install python3 with your Linux package manager first.' >&2
  exit 1
fi
exec python3 - "$@" <<'PY'
import fcntl
import hashlib
import json
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path, PurePosixPath

ORIGIN = 'https://new.luani.fyi'
MANIFEST_URL = ORIGIN + '/client/channel.json'
MAX_DOWNLOAD = 512 * 1024 * 1024
MAX_UNPACKED = 1024 * 1024 * 1024
MANAGED = '# Luani Client managed launcher'

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlsplit(newurl)
        if parsed.scheme != 'https' or parsed.netloc != 'new.luani.fyi':
            raise RuntimeError('Refusing an unexpected download redirect')
        return super().redirect_request(req, fp, code, msg, headers, newurl)

opener = urllib.request.build_opener(SafeRedirect())
def fetch(url):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.netloc != 'new.luani.fyi':
        raise RuntimeError('Download must use the official HTTPS host')
    return opener.open(urllib.request.Request(url, headers={'User-Agent':'Luani-Installer/1.0'}), timeout=45)

def atomic_text(path, text, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name('.' + path.name + '-' + uuid.uuid4().hex)
    try:
        with open(temporary, 'x', encoding='utf-8') as output:
            output.write(text)
            output.flush()
            os.fsync(output.fileno())
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)

def mime_values(text, section, key):
    values, current = [], ''
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith('[') and stripped.endswith(']'):
            current = stripped[1:-1]
        elif current == section and '=' in stripped and not stripped.startswith(('#', ';')):
            name, value = stripped.split('=', 1)
            if name.strip() == key:
                values.extend(item.strip() for item in value.split(';') if item.strip())
    return values


def with_mime_entry(text, section, value):
    # Preserve every unrelated setting/comment; normalize only this protocol's key.
    key, current, found, output = 'x-scheme-handler/luani', '', False, []
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith('[') and stripped.endswith(']'):
            current = stripped[1:-1]
            output.append(line)
            if current == section and not found:
                if not line.endswith('\n'):
                    output.append('\n')
                output.append(key + '=' + value + '\n')
                found = True
        elif current == section and '=' in stripped and stripped.split('=', 1)[0].strip() == key:
            continue
        else:
            output.append(line)
    if not found:
        if output and not output[-1].endswith('\n'):
            output.append('\n')
        output.append('\n[' + section + ']\n' + key + '=' + value + '\n')
    return ''.join(output)


def configure_luani_protocol(applications):
    """Reclaim only this user's luani scheme, never delete another application."""
    mime, desktop = 'x-scheme-handler/luani', 'org.luani.Client.desktop'
    home = Path.home()
    config_home = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config').expanduser()
    if not config_home.is_absolute():
        raise RuntimeError('XDG_CONFIG_HOME must be an absolute path.')
    def directories(variable, fallback):
        return [Path(item) for item in (os.environ.get(variable) or fallback).split(':')
                if item and Path(item).is_absolute()]
    configs = [config_home] + directories('XDG_CONFIG_DIRS', '/etc/xdg')
    app_dirs = [applications] + [path / 'applications' for path in
                                directories('XDG_DATA_DIRS', '/usr/local/share:/usr/share')]
    handlers = set()
    for directory in dict.fromkeys(configs + app_dirs):
        candidates = [directory / 'mimeapps.list', directory / 'defaults.list']
        candidates.extend(sorted(directory.glob('*-mimeapps.list')))
        for path in candidates:
            if path.is_file():
                text = path.read_text(encoding='utf-8')
                for section in ('Default Applications', 'Added Associations', 'Removed Associations'):
                    handlers.update(mime_values(text, section, mime))
    for directory in dict.fromkeys(app_dirs):
        for path in directory.rglob('*.desktop'):
            if path.is_file() and mime in mime_values(path.read_text(encoding='utf-8'), 'Desktop Entry', 'MimeType'):
                identifier = '-'.join(path.relative_to(directory).parts)
                if not any(ord(char) < 32 or char == ';' for char in identifier):
                    handlers.add(identifier)
    handlers.discard(desktop)
    removed = ''.join(identifier + ';' for identifier in sorted(handlers))
    changes = []
    generic = [config_home / 'mimeapps.list', applications / 'mimeapps.list']
    targets = list(generic)
    for directory in (config_home, applications):
        targets.extend(sorted(directory.glob('*-mimeapps.list')))
        if (directory / 'defaults.list').exists():
            targets.append(directory / 'defaults.list')
    for name in os.environ.get('XDG_CURRENT_DESKTOP', '').split(':'):
        if re.fullmatch(r'[A-Za-z0-9_-]+', name):
            targets.append(config_home / (name.lower() + '-mimeapps.list'))
    for path in dict.fromkeys(targets):
        if path.is_symlink() or (path.exists() and (not path.is_file() or path.stat().st_uid != os.getuid())):
            raise RuntimeError('Refusing an unmanaged or symlinked protocol configuration: ' + str(path))
        original = path.read_text(encoding='utf-8') if path.exists() else ''
        updated = with_mime_entry(original, 'Default Applications', desktop + ';')
        if path in generic:
            # Freedesktop permits Added/Removed only in generic mimeapps.list.
            updated = with_mime_entry(updated, 'Added Associations', desktop + ';')
            updated = with_mime_entry(updated, 'Removed Associations', removed)
        if updated != original:
            changes.append((path, original, updated))
    for path, original, updated in changes:
        if path.exists():
            atomic_text(path.with_name('.' + path.name + '.luani-backup-' + uuid.uuid4().hex), original, 0o600)
        atomic_text(path, updated, 0o600)
    return {'removed_handlers': sorted(handlers), 'changed_files': [str(path) for path, _, _ in changes]}


def main():
    if len(sys.argv) != 1:
        raise RuntimeError('No arguments are needed. Run the same command to install or update.')
    if os.geteuid() == 0:
        raise RuntimeError('Run this installer as your normal desktop user, without sudo.')
    if platform.system() != 'Linux':
        raise RuntimeError('This preview supports Linux only.')
    machine = platform.machine().lower()
    arch = {'x86_64':'x86_64','amd64':'x86_64','aarch64':'arm64','arm64':'arm64'}.get(machine)
    if arch is None:
        raise RuntimeError('Supported architectures: 64-bit x86_64 and ARM64; found ' + machine)
    home = Path.home()
    data = Path(os.environ.get('XDG_DATA_HOME', str(home / '.local/share'))).expanduser()
    if not data.is_absolute():
        raise RuntimeError('XDG_DATA_HOME must be an absolute path.')
    base = data / 'luani-client'
    if base.is_symlink():
        raise RuntimeError('Refusing a symlink as the installation directory.')
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    if base.stat().st_uid != os.getuid():
        raise RuntimeError('The installation directory must belong to your current user.')
    base.chmod(0o700)
    lock = open(base / 'install.lock', 'a')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise RuntimeError('Another Luani install/update is already running.') from None
    # Unique manifest request prevents an old CDN cache entry hiding an update.
    with fetch(MANIFEST_URL + '?check=' + str(time.time_ns())) as response:
        raw = response.read(262145)
    if len(raw) > 262144:
        raise RuntimeError('Release manifest is too large.')
    manifest = json.loads(raw)
    if manifest.get('schema') != 1:
        raise RuntimeError('Unsupported release manifest. Installer may need updating.')
    version = manifest.get('version', '')
    if not isinstance(version, str) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.-]+)?', version):
        raise RuntimeError('Invalid release version.')
    asset = manifest.get('linux', {}).get(arch)
    if not isinstance(asset, dict):
        raise RuntimeError('No package is published for ' + arch)
    url, checksum, size = asset.get('url'), asset.get('sha256'), asset.get('size')
    if not isinstance(url, str) or not url.startswith(ORIGIN + '/client/releases/' + version + '/'):
        raise RuntimeError('Unexpected package location.')
    if not isinstance(checksum, str) or not re.fullmatch(r'[a-f0-9]{64}', checksum):
        raise RuntimeError('Invalid package checksum.')
    if type(size) is not int or not 0 < size <= MAX_DOWNLOAD:
        raise RuntimeError('Invalid package size.')
    release_name = version + '-' + arch + '-' + checksum[:12]
    releases = base / 'releases'
    releases.mkdir(exist_ok=True)
    if releases.is_symlink():
        raise RuntimeError('Refusing a symlink as the releases directory.')
    destination = releases / release_name
    current = base / 'current'
    if current.exists() and not current.is_symlink():
        raise RuntimeError('Installation current path is not a managed symlink.')
    receipt = destination / 'install-receipt.json'
    reusable = False
    if destination.is_dir() and not destination.is_symlink() and receipt.is_file():
        try:
            saved = json.loads(receipt.read_text())
            reusable = saved.get('sha256') == checksum and all((destination / p).is_file() for p in ['luani','engine/godot','game/project.godot','protocol_launch.py'])
        except (ValueError, OSError):
            reusable = False
    print('Luani Client ' + version + ' · Linux ' + arch)
    print('Multiplayer preview. Desktop gameplay verification is pending; the installer never starts the game.')
    if not reusable:
        with tempfile.TemporaryDirectory(prefix='.stage-', dir=base) as temporary:
            temporary = Path(temporary)
            archive = temporary / 'package.tar.gz'
            digest = hashlib.sha256()
            downloaded = 0
            print('Downloading the client and bundled Godot runtime…')
            with fetch(url) as response, open(archive, 'xb') as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    downloaded += len(chunk)
                    if downloaded > size or downloaded > MAX_DOWNLOAD:
                        raise RuntimeError('Download exceeded its declared size.')
                    digest.update(chunk)
                    output.write(chunk)
            if downloaded != size or digest.hexdigest() != checksum:
                raise RuntimeError('Download verification failed. The existing installation was not changed.')
            staging = temporary / 'unpacked'
            staging.mkdir()
            seen = set()
            unpacked = 0
            expected_root = 'luani-client-' + version
            with tarfile.open(archive, 'r:gz') as package:
                members = package.getmembers()
                if len(members) > 1000:
                    raise RuntimeError('Too many archive entries.')
                for member in members:
                    name = PurePosixPath(member.name)
                    if name.is_absolute() or '..' in name.parts or not name.parts or name.parts[0] != expected_root:
                        raise RuntimeError('Unsafe archive path.')
                    if not (member.isdir() or member.isfile()):
                        raise RuntimeError('Links and special files are not permitted in packages.')
                    relative = Path(*name.parts[1:])
                    if str(relative) in seen:
                        raise RuntimeError('Duplicate archive entry.')
                    seen.add(str(relative))
                    target = staging / relative
                    if member.isdir():
                        target.mkdir(parents=True, exist_ok=True)
                        continue
                    unpacked += member.size
                    if unpacked > MAX_UNPACKED:
                        raise RuntimeError('Unpacked package exceeds its size limit.')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    source = package.extractfile(member)
                    if source is None:
                        raise RuntimeError('Unreadable package entry.')
                    with source, open(target, 'xb') as output:
                        shutil.copyfileobj(source, output, 1024 * 1024)
                    target.chmod(0o755 if str(relative) in ['luani','engine/godot'] else 0o644)
            for required in ['luani','engine/godot','game/project.godot','game/main.tscn','icon.svg','protocol_launch.py']:
                if not (staging / required).is_file():
                    raise RuntimeError('Incomplete package: ' + required)
            atomic_text(staging / 'install-receipt.json', json.dumps({'version':version,'arch':arch,'sha256':checksum}, indent=2) + '\n')
            if destination.exists() or destination.is_symlink():
                if destination.is_symlink():
                    raise RuntimeError('Refusing a symlink at the release destination.')
                os.replace(destination, releases / (release_name + '.previous-' + uuid.uuid4().hex[:8]))
            os.replace(staging, destination)
    else:
        print('This release is already installed; refreshing launchers.')
    bin_dir = home / '.local/bin'
    launcher = bin_dir / 'luani'
    if launcher.exists() or launcher.is_symlink():
        if launcher.is_symlink() or MANAGED not in launcher.read_text(errors='replace'):
            raise RuntimeError('~/.local/bin/luani belongs to another installation; move it aside first.')
    applications = data / 'applications'
    desktop = applications / 'org.luani.Client.desktop'
    if desktop.exists() and 'X-Luani-Managed=true' not in desktop.read_text(errors='replace'):
        raise RuntimeError('An unmanaged Luani desktop entry already exists.')
    next_link = base / ('.current-' + uuid.uuid4().hex)
    try:
        next_link.symlink_to(Path('releases') / release_name, target_is_directory=True)
        os.replace(next_link, current)
    finally:
        next_link.unlink(missing_ok=True)
    atomic_text(launcher, '#!/bin/sh\n' + MANAGED + '\nexec ' + shlex.quote(str(current / 'luani')) + ' "$@"\n', 0o755)
    executable = str(launcher)
    if any(c in executable for c in '\n\r'):
        raise RuntimeError('Unsupported newline in installation path.')
    desktop_exec = '"' + executable.replace('\\','\\\\').replace('"','\\"').replace('`','\\`').replace('$','\\$').replace('%','%%') + '"'
    desktop_text = '[Desktop Entry]\nType=Application\nName=Luani Client\nComment=Luani multiplayer client\nExec=' + desktop_exec + ' %u\nIcon=' + str(current / 'icon.svg') + '\nTerminal=false\nCategories=Game;\nMimeType=x-scheme-handler/luani;\nStartupWMClass=Luani Client\nX-Luani-Managed=true\n'
    atomic_text(desktop, desktop_text)
    # Reset on BOTH install and update, including an already-installed release.
    # Mask competing handlers per user; never delete/disable other applications.
    if shutil.which('update-desktop-database'):
        subprocess.run(['update-desktop-database', str(applications)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    association = configure_luani_protocol(applications)
    if shutil.which('xdg-mime'):
        result = subprocess.run(['xdg-mime', 'query', 'default', 'x-scheme-handler/luani'], check=False,
                                capture_output=True, text=True, timeout=15)
        if result.returncode == 0 and result.stdout.strip() != 'org.luani.Client.desktop':
            raise RuntimeError('Client installed, but the desktop still reports another luani:// handler. '
                               'Restart your desktop session and rerun this command.')
        if result.returncode:
            print('Protocol settings were written, but xdg-mime could not verify the desktop association.')
    print('Configured luani:// for this user; removed ' + str(len(association['removed_handlers'])) + ' competing associations.')
    print('Installed. Launch “Luani Client” from your applications menu, or run:')
    print('  ' + shlex.quote(str(launcher)))
    print('Run the same install command again to update. Device-local settings and older releases are retained.')
    if str(bin_dir) not in os.environ.get('PATH', '').split(os.pathsep):
        print('~/.local/bin is not on this shell’s PATH; use the full launch path above or log in again.')

try:
    main()
except Exception as error:
    print('Luani installer: ' + str(error), file=sys.stderr)
    sys.exit(1)
PY
