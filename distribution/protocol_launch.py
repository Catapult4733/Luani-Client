#!/usr/bin/env python3
"""Strict Linux URI handler. No passwords, browser sessions or configurable API URLs."""
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API='https://ffghvwuuqmvzvjuiynkn.supabase.co/functions/v1/luani-play'
CODE=re.compile(r'[A-Za-z0-9_-]{43}')

def parse_uri(uri):
    if not isinstance(uri,str) or len(uri)>256 or any(ord(c)<33 or ord(c)>126 for c in uri):
        raise ValueError('Invalid Luani launch link. Join from new.luani.fyi.')
    p=urllib.parse.urlsplit(uri)
    if p.scheme!='luani' or p.netloc!='launch' or p.path or p.fragment:
        raise ValueError('Invalid Luani launch link. Join from new.luani.fyi.')
    pairs=urllib.parse.parse_qsl(p.query,keep_blank_values=True,strict_parsing=True)
    if len(pairs)!=1 or pairs[0][0]!='ticket' or not CODE.fullmatch(pairs[0][1]):
        raise ValueError('Invalid launch ticket. Join again from the website.')
    return pairs[0][1]

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):
        raise ValueError('Unexpected authentication redirect.')

def redeem(ticket):
    request=urllib.request.Request(API,method='POST',data=json.dumps({'action':'redeem','ticket':ticket}).encode(),headers={'Content-Type':'application/json','User-Agent':'Luani-Client/0.5'})
    try:
        with urllib.request.build_opener(NoRedirect()).open(request,timeout=15) as response:
            raw=response.read(65537)
    except urllib.error.HTTPError as e:
        messages={401:'Launch authentication failed. Join again from the website.',409:'Launch expired, game unavailable, or this account is already playing. Close the game and join again.',429:'Too many launch attempts. Please wait.',503:'Game service temporarily unavailable.'}
        raise ValueError(messages.get(e.code,'Could not join the game. Try again from the website.')) from None
    except (OSError,urllib.error.URLError):
        raise ValueError('Could not reach Luani. Check your connection and join again.') from None
    if len(raw)>65536: raise ValueError('Authentication response too large.')
    data=json.loads(raw)
    if data.get('protocol')!=1 or not CODE.fullmatch(str(data.get('admission',''))) or not isinstance(data.get('endpoint'),dict):
        raise ValueError('Invalid authentication response.')
    return raw

def main():
    here=Path(__file__).resolve().parent
    args=[str(here/'engine/godot'),'--path',str(here/'game'),'--']
    if len(sys.argv)>2: raise ValueError('Use the website Join button; command-line options are not accepted.')
    if len(sys.argv)==2:
        raw=redeem(parse_uri(sys.argv[1]))
        # Keep admission/profile data off command lines, environment and disk.
        fd=os.memfd_create('luani-launch',0)
        os.write(fd,raw)
        os.lseek(fd,0,os.SEEK_SET)
        os.set_inheritable(fd,True)
        args+=['--launch-fd',str(fd)]
    os.execv(args[0],args)

if __name__=='__main__':
    try: main()
    except Exception as e:
        # Never echo the URI, bearer credentials, HTTP request or traceback.
        message=str(e) if isinstance(e,ValueError) else 'Could not launch Luani. Please reinstall or update the client.'
        print('Luani: '+message,file=sys.stderr)
        sys.exit(1)
