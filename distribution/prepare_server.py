#!/usr/bin/env python3
"""Create private credentials/certificates for this first-party service only; print public metadata."""
import hashlib
import json
import os
import secrets
import subprocess
from pathlib import Path

root=Path.home()/'luani-multiplayer'
root.mkdir(mode=0o700,exist_ok=True)
private=root/'private'; private.mkdir(mode=0o700,exist_ok=True)
state=root/'state'; state.mkdir(mode=0o700,exist_ok=True)
for child in ['tmp','data','cache']: (state/child).mkdir(mode=0o700,exist_ok=True)
key=private/'control-key'
if not key.exists():
    fd=os.open(key,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
    with os.fdopen(fd,'w') as f: f.write(secrets.token_urlsafe(32))
key.chmod(0o600)
certificate=private/'server.crt'; tls_key=private/'server.key'
if not certificate.exists() and not tls_key.exists():
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-noenc','-keyout',str(tls_key),'-out',str(certificate),'-days','365','-subj','/CN=luani-game','-addext','subjectAltName=DNS:luani-game'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
if not certificate.exists() or not tls_key.exists(): raise RuntimeError('Incomplete TLS material; preserve and inspect')
tls_key.chmod(0o600)
env=root/'server.env'
text='\n'.join(['LUANI_CONTROL_KEY='+key.read_text(),'LUANI_API_URL=https://ffghvwuuqmvzvjuiynkn.supabase.co/functions/v1/luani-play','LUANI_TLS_KEY='+str(tls_key),'LUANI_TLS_CERT='+str(certificate),'XDG_DATA_HOME='+str(state/'data'),'XDG_CACHE_HOME='+str(state/'cache'),'TMPDIR='+str(state/'tmp')])+'\n'
fd=os.open(env,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
with os.fdopen(fd,'w') as f: f.write(text)
print(json.dumps({'secret_hash':hashlib.sha256(key.read_bytes()).hexdigest(),'certificate':certificate.read_text(),'private_material_permissions':'0600','root':str(root)}))
