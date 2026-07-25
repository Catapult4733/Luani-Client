# Luani Web Backend (luani.fyi)

Node.js API server for Raspberry Pi 5. Handles:
- User authentication & session tokens
- Place listings & place file publishing API (`/api/places/publish`)
- Managed server ad verification & Ubuntu laptop daemon launch signaling (`/api/servers/request`)
- Client URI protocol generation (`luani://join?server=IP:PORT&auth=TOKEN`)

## Getting Started

```bash
cd web_backend
npm install
npm run dev
```
