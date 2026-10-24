#!/usr/bin/env python3
"""Assemble native Linux source-runtime bundles WITHOUT invoking Godot or the game."""
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / 'distribution/release.json').read_text())

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def request(url, accept=None):
    headers = {'User-Agent':'Luani-Offline-Packager/1.0'}
    if accept:
        headers['Accept'] = accept
    # Public upstream download: never forward repository credentials to a CDN.
    return urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120)

def download(url, destination, checksum=None, fallback=None):
    if destination.is_file() and (checksum is None or digest(destination) == checksum):
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + '.part')
    try:
        try:
            source = request(url)
        except Exception:
            if not fallback:
                raise
            source = request(fallback, 'application/octet-stream')
        with source, temporary.open('wb') as output:
            shutil.copyfileobj(source, output, 1024 * 1024)
        if checksum and digest(temporary) != checksum:
            raise RuntimeError('Upstream checksum mismatch: ' + destination.name)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    args.cache.mkdir(parents=True, exist_ok=True)
    tag = CONFIG['engine_version']
    version = CONFIG['version']
    with request(f'https://api.github.com/repos/{CONFIG["engine_repository"]}/releases/tags/{tag}') as response:
        upstream = json.load(response)
    assets = {item['name']:item for item in upstream['assets']}
    notices = {}
    for filename in ['LICENSE.txt','COPYRIGHT.txt']:
        target = args.cache / (tag + '-' + filename)
        download(f'https://raw.githubusercontent.com/godotengine/godot/{tag}/{filename}', target)
        notices[filename] = target
    manifest = {'schema':1,'version':version,'channel':'offline-preview','runtime_verification':'not-run-by-request','engine':tag,'linux':{}}
    for arch, definition in CONFIG['linux'].items():
        asset = assets[definition['asset']]
        expected = definition['sha256']
        if asset.get('digest') and asset['digest'] != 'sha256:' + expected:
            raise RuntimeError('Pinned engine digest differs from GitHub release metadata')
        archive = args.cache / definition['asset']
        download(asset['browser_download_url'], archive, expected, asset['url'])
        with tempfile.TemporaryDirectory(prefix='luani-package-', dir=args.cache) as temporary:
            bundle = Path(temporary) / ('luani-client-' + version)
            (bundle / 'engine').mkdir(parents=True)
            with zipfile.ZipFile(archive) as source:
                binary_name = definition['asset'].removesuffix('.zip')
                candidates = [item for item in source.infolist() if not item.is_dir() and Path(item.filename).name == binary_name]
                if len(candidates) != 1:
                    raise RuntimeError('Unexpected upstream runtime ZIP layout')
                with source.open(candidates[0]) as input_file, (bundle / 'engine/godot').open('wb') as output:
                    shutil.copyfileobj(input_file, output, 1024 * 1024)
            engine = bundle / 'engine/godot'
            with engine.open('rb') as source:
                header = source.read(20)
            if header[:4] != b'\x7fELF' or header[4] != 2 or header[5] != 1:
                raise RuntimeError('Runtime is not a 64-bit little-endian ELF')
            if struct.unpack_from('<H', header, 18)[0] != {'x86_64':62,'arm64':183}[arch]:
                raise RuntimeError('Runtime architecture mismatch')
            engine.chmod(0o755)
            shutil.copytree(ROOT / 'offline', bundle / 'game', ignore=shutil.ignore_patterns('.godot','*.uid','*.tmp'))
            shutil.copy2(ROOT / 'distribution/luani', bundle / 'luani')
            (bundle / 'luani').chmod(0o755)
            shutil.copy2(ROOT / 'distribution/icon.svg', bundle / 'icon.svg')
            shutil.copy2(ROOT / 'offline/README.md', bundle / 'README.md')
            for filename, source in notices.items():
                shutil.copy2(source, bundle / ('GODOT-' + filename))
            shutil.copy2(ROOT / 'offline/NOTICE.md', bundle / 'NOTICE.md')
            name = f'luani-client-{version}-linux-{arch}.tar.gz'
            destination = args.output / name
            if destination.exists():
                raise RuntimeError('Refusing to overwrite an existing immutable package: ' + str(destination))
            with tarfile.open(destination, 'w:gz', compresslevel=6) as output:
                for source in sorted(bundle.rglob('*')):
                    if not source.is_file() or source.is_symlink():
                        continue
                    info = output.gettarinfo(str(source), str(source.relative_to(bundle.parent)))
                    info.uid = info.gid = 0
                    info.uname = info.gname = ''
                    info.mode = 0o755 if source in [engine,bundle / 'luani'] else 0o644
                    info.mtime = 0
                    with source.open('rb') as input_file:
                        output.addfile(info, input_file)
            manifest['linux'][arch] = {'url':f'https://new.luani.fyi/client/releases/{version}/{name}','sha256':digest(destination),'size':destination.stat().st_size}
            print(json.dumps({'archive':str(destination),'arch':arch,'sha256':manifest['linux'][arch]['sha256'],'game_executed':False}), flush=True)
    source_commit = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    manifest['source_commit'] = source_commit
    (args.output / 'channel.json').write_text(json.dumps(manifest,indent=2) + '\n')
    print('Packages assembled. No Godot process, export, game, test or installer was executed.')

if __name__ == '__main__':
    main()
