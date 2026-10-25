#!/usr/bin/env python3
"""Narrow static multiplayer safety guard. Does not run Godot, installer or any client."""
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
findings=[]
for path in (ROOT/'offline').rglob('*.gd'):
    text=path.read_text()
    for pattern in [r'TLSOptions\.client_unsafe',r'bytes_to_var',r'get_var\(',r'OS\.execute',r'OS\.create_process',r'Expression\.new',r'GDScript\.new',r'@rpc']:
        if re.search(pattern,text): findings.append({'file':str(path.relative_to(ROOT)),'rule':pattern})
    for i,line in enumerate(text.splitlines(),1):
        if re.search(r'(?:password|secret|api_key|control_key)\s*[:=]\s*[\"\x27][^\"\x27\n]{8,}[\"\x27]',line,re.I): findings.append({'file':str(path.relative_to(ROOT)),'line':i,'rule':'literal secret'})
        if ('print(' in line or 'push_error(' in line) and re.search(r'\b(?:admission|_key|ticket|_launch)\s*[,\)]',line): findings.append({'file':str(path.relative_to(ROOT)),'line':i,'rule':'credential logging'})
hud=(ROOT/'offline/scripts/hud.gd').read_text()
if '_name_input' in hud or 'set_display_name' in hud: findings.append({'rule':'local identity editor remains'})
transport=(ROOT/'offline/scripts/secure_transport.gd').read_text()
for token in ['dtls_server_setup','dtls_client_setup','TLSOptions.client(certificate','MAX_PACKET := 32768','127.0.0.1']:
    if token not in transport: findings.append({'rule':'missing transport boundary','token':token})
handler=(ROOT/'distribution/protocol_launch.py').read_text()
for token in ["p.netloc!='launch'","os.memfd_create","NoRedirect","os.execv"]:
    if token not in handler: findings.append({'rule':'missing protocol boundary','token':token})
print(json.dumps({'findings':findings,'source_only':True,'client_gameplay_executed':False},indent=2))
raise SystemExit(bool(findings))
