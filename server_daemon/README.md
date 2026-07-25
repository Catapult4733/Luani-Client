# Luani Server Daemon (Ubuntu Laptop Host)

Lightweight daemon script running on Ubuntu laptop. Listens for server spin-up commands from `luani.fyi` backend, launches headless Godot server instances (`godot --headless --server`), and handles process lifecycles.

## Quick Start

```bash
# Test dry-run
python3 daemon.py --test

# Run live daemon targeting backend
python3 daemon.py --backend http://localhost:3000
```
