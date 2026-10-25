#!/usr/bin/env python3
"""Stage a checked native server on the ThinkPad; do not start it or alter other services."""
import argparse
import hashlib
import json
import os
import shutil
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

p=argparse.ArgumentParser(); p.add_argument('--source-sha',required=True); p.add_argument('--candidate',required=True); a=p.parse_args()
root=Path.home()/'luani-multiplayer'; source=root/('source-'+a.candidate+'.tar.gz'); runtime=root/'runtime.zip'
assert hashlib.sha256(source.read_bytes()).hexdigest()==a.source_sha
assert hashlib.sha256(runtime.read_bytes()).hexdigest()=='cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4'
release=root/'releases'/('server-'+a.candidate)
release.mkdir(parents=True,exist_ok=False,mode=0o700)
with tarfile.open(source,'r:gz') as archive:
    members=archive.getmembers()
    assert all(m.isfile() and not PurePosixPath(m.name).is_absolute() and '..' not in PurePosixPath(m.name).parts and m.name.startswith('game/') for m in members)
    assert sum(m.size for m in members)<32*1024*1024
    archive.extractall(release,filter='data')
engine=release/'engine'; engine.mkdir()
with zipfile.ZipFile(runtime) as archive:
    entry='Godot_v4.7.2-stable_linux.x86_64'
    with archive.open(entry) as src,(engine/'godot').open('wb') as dst: shutil.copyfileobj(src,dst)
(engine/'godot').chmod(0o755)
assert (engine/'godot').read_bytes()[:4]==b'\x7fELF'
assert (release/'game/scripts/dedicated_server.gd').is_file()
assert (release/'game/main.tscn').is_file()
unit=root/'luani-baseplate.service'; dest=Path.home()/'.config/systemd/user/luani-baseplate.service'
if dest.exists() and 'Description=Luani first-party Baseplate multiplayer' not in dest.read_text(): raise RuntimeError('Unmanaged unit exists; no replacement')
dest.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(unit,dest)
link=root/'.current-next'; link.unlink(missing_ok=True); link.symlink_to(release.relative_to(root),target_is_directory=True); os.replace(link,root/'current')
receipt={'candidate':a.candidate,'source_sha256':a.source_sha,'runtime_sha256':'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4','release':str(release),'unit':str(dest),'started':False}
(root/('stage-'+a.candidate+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
