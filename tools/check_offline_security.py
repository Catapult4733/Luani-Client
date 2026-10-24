#!/usr/bin/env python3
"""Static code/text scan. Does not execute the Godot project."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'offline'
PATTERNS = {
    'runtime_network': re.compile(r'HTTPRequest|HTTPClient|ENetMultiplayerPeer|WebSocketPeer'),
    'dynamic_code_or_process': re.compile(r'OS\.execute|OS\.create_process|GDScript\.new|Expression\.new'),
    'literal_credential': re.compile(r'''(?:api_key|password|secret)\s*=\s*["'][^"'\n]{6,}["']''', re.I),
}
findings = []
files = sorted(ROOT.rglob('*.gd'))
for path in files:
    for number, line in enumerate(path.read_text().splitlines(), 1):
        for category, pattern in PATTERNS.items():
            if pattern.search(line):
                findings.append({'file': str(path.relative_to(ROOT)), 'line': number, 'category': category})
print(json.dumps({'gdscript_files_scanned': len(files), 'findings': findings, 'game_executed': False}, indent=2))
raise SystemExit(bool(findings))
