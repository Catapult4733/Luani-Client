# Luani Cloudflare Tunnels (`cloudflared`) Setup Guide

This guide details configuring **Cloudflare Tunnels** to expose the Raspberry Pi 5 web backend (`luani.fyi`) and the Ubuntu laptop server host instance ports over public DNS securely.

---

## Architecture Topology

```
                  ┌─────────────────────────────────────────┐
                  │          Cloudflare Edge Network        │
                  │              (luani.fyi)                │
                  └────────────────────┬────────────────────┘
                                       │
                ┌──────────────────────┴──────────────────────┐
                │                                             │
      (HTTP Port 3000)                                (UDP / Game Ports 7700-7800)
                │                                             │
                ▼                                             ▼
     ┌──────────────────────┐                      ┌──────────────────────┐
     │   Raspberry Pi 5     │                      │    Ubuntu Laptop     │
     │   (web_backend)      │                      │   (server_daemon)    │
     └──────────────────────┘                      └──────────────────────┘
```

---

## 1. Raspberry Pi 5 Web Backend Tunnel (`luani.fyi`)

### Step 1: Install `cloudflared` on Pi 5
```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared.deb
```

### Step 2: Authenticate and Create Tunnel
```bash
cloudflared tunnel login
cloudflared tunnel create luani-pi5-backend
```

### Step 3: Configure `~/.cloudflared/config.yml`
```yaml
tunnel: <TUNNEL_UUID>
credentials-file: /root/.cloudflared/<TUNNEL_UUID>.json

ingress:
  - hostname: luani.fyi
    service: http://localhost:3000
  - hostname: api.luani.fyi
    service: http://localhost:3000
  - service: http_status:404
```

### Step 4: Route DNS & Start Service
```bash
cloudflared tunnel route dns luani-pi5-backend luani.fyi
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

---

## 2. Ubuntu Laptop Server Host Daemon Routing

For hosting dynamic ENet UDP multiplayer game server ports (7700-7800):

### Option A: Cloudflare Spectrum (TCP/UDP Tunneling)
1. In Cloudflare Dashboard, navigate to **Spectrum** -> **Add Application**.
2. Select **UDP / Custom Port** range `7700-7800`.
3. Target IP: Ubuntu Laptop local IP / tunnel endpoint.

### Option B: Router Port Forwarding / UPnP
1. Forward UDP port range `7700-7800` on host router to Ubuntu Laptop local IP.
2. In `server_daemon/config.json`, configure `"publicIp"` to point to host WAN IP or DDNS hostname.
