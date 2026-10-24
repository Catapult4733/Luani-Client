#!/usr/bin/env python3
"""Source/artifact checks ONLY. Does not execute GDScript, Godot, a game or installer."""
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'offline'
REQUIRED = ['ui_theme.gd','ui_controls.gd','item_catalog.gd','inventory.gd','item_visual.gd','pickup.gd','practice_target.gd']
errors = []
for name in REQUIRED:
    if not (ROOT/'scripts'/name).is_file(): errors.append('Missing implementation module: '+name)
for path in ROOT.rglob('*.gd'):
    for resource in re.findall(r'(?:preload|load)\("(res://[^"\n]+)"\)', path.read_text()):
        if not (ROOT/resource.removeprefix('res://')).is_file(): errors.append(f'{path.name}: missing resource {resource}')
project=(ROOT/'project.godot').read_text()
if 'window/stretch/mode="disabled"' not in project: errors.append('Project must retain fixed logical-pixel UI')
manifest=ROOT/'assets/ui/figma/asset-manifest.json'
if not manifest.is_file(): errors.append('Missing Figma asset provenance')
else:
    for item in json.loads(manifest.read_text())['assets']:
        path=ROOT/item['file']
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:
            errors.append('Asset integrity mismatch: '+item['file'])
for name in ['menu','chat','leaderboard']:
    path=ROOT/'assets/ui/figma'/(name+'.svg')
    if path.is_file():
        xml=ET.parse(path).getroot()
        if xml.get('width')!='20' or xml.get('height')!='20': errors.append('HUD glyph must remain20px: '+name)
if errors:
    print('\n'.join(errors),file=sys.stderr)
    raise SystemExit(1)
print('Source/resource integrity checks passed; no engine/game/installer executed.')
