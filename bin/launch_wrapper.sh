#!/bin/bash
echo "$(date): Received launch arguments: $@" >> ~/luani_debug.log
$HOME/luani-client/bin/LuaniClient.x86_64 "$@"
