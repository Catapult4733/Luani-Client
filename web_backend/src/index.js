const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve static web portal frontend
app.use(express.static(path.join(__dirname, '../public')));

// Default place catalog
const places = [
  {
    id: 'place_default_01',
    name: 'Luani Starter World',
    creator: 'Luani Team',
    description: 'Welcome to the Luani platform default sandbox world.',
    maxPlayers: 16,
    version: 1,
    format_version: 1,
    parts: [
      {
        name: "Baseplate",
        primitive_type: 0,
        position: [0, -0.5, 0],
        rotation: [0, 0, 0],
        scale: [30, 0.5, 30],
        anchored: true,
        color: [0.2, 0.25, 0.35, 1.0]
      },
      {
        name: "WelcomeBlock",
        primitive_type: 0,
        position: [0, 2, 0],
        rotation: [0, 0, 0],
        scale: [2, 2, 2],
        anchored: true,
        color: [0.9, 0.4, 0.2, 1.0],
        luau_script: "print('Welcome to Luani Starter World!')\nrotate_y(15)"
      }
    ]
  }
];

const activeServers = [];

// Storage for uploaded place PCK / JSON files
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const placeId = req.body.placeId || `place_${Date.now()}`;
    cb(null, `${placeId}.pck`);
  }
});
const upload = multer({ storage });

// API Routes

// 1. Healthcheck
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'luani-web-backend', domain: 'luani.fyi', timestamp: new Date().toISOString() });
});

// 2. Game / Place Listings
app.get('/api/places', (req, res) => {
  res.json({ success: true, count: places.length, places });
});

// 3. Get Specific Place Data by ID
app.get('/api/places/:id', (req, res) => {
  const placeId = req.params.id;
  const found = places.find(p => p.id === placeId);
  if (found) {
    return res.json({ success: true, place: found });
  }

  res.json({
    success: true,
    place: {
      id: placeId,
      name: `Luani Dynamic World (${placeId})`,
      format_version: 1,
      parts: [
        {
          name: "Baseplate",
          primitive_type: 0,
          position: [0, -0.5, 0],
          rotation: [0, 0, 0],
          scale: [30, 0.5, 30],
          anchored: true,
          color: [0.25, 0.3, 0.4, 1.0]
        }
      ]
    }
  });
});

// 4. Publish Place file from Luani Studio
app.post('/api/places/publish', upload.single('placeFile'), (req, res) => {
  const { name, creator, description, maxPlayers, parts } = req.body;
  const placeId = `place_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

  let parsedParts = [];
  if (parts) {
    try {
      parsedParts = typeof parts === 'string' ? JSON.parse(parts) : parts;
    } catch (e) {
      console.warn('[Luani Web Backend] Could not parse parts JSON payload.');
    }
  }

  const newPlace = {
    id: placeId,
    name: name || 'Untitled Place',
    creator: creator || 'Anonymous Creator',
    description: description || '',
    maxPlayers: parseInt(maxPlayers) || 12,
    filePath: req.file ? req.file.path : null,
    createdAt: new Date().toISOString(),
    format_version: 1,
    parts: parsedParts
  };

  places.push(newPlace);
  console.log(`[Luani Web Backend] Published place file: ${newPlace.name} (${newPlace.id})`);

  res.json({
    success: true,
    message: 'Place published successfully to luani.fyi backend.',
    place: newPlace
  });
});

// 5. Request Server Spin-up (Ad-Gated Managed Server flow)
app.post('/api/servers/request', (req, res) => {
  const { placeId, userId, adWatchToken } = req.body;

  if (!placeId) {
    return res.status(400).json({ success: false, error: 'Missing placeId parameter.' });
  }

  if (!adWatchToken) {
    return res.status(403).json({
      success: false,
      error: 'Ad watch verification required for Luani Managed Server instance.',
      adRequired: true
    });
  }

  const requestId = `req_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  const port = 7700 + (activeServers.length % 100);

  const newServer = {
    requestId,
    placeId,
    serverIp: '127.0.0.1',
    serverPort: port,
    authToken: `tok_${Math.random().toString(36).substring(2, 15)}`,
    status: 'SPAWNING',
    launchedAt: new Date().toISOString()
  };

  activeServers.push(newServer);

  const joinUri = `luani://join?server=${newServer.serverIp}:${newServer.serverPort}&auth=${newServer.authToken}`;

  res.json({
    success: true,
    requestId,
    server: newServer,
    joinUri
  });
});

// 6. Daemon Tunnel Signaling
app.get('/api/daemon/pending-tasks', (req, res) => {
  const spawning = activeServers.filter(s => s.status === 'SPAWNING');
  res.json({ pendingCount: spawning.length, tasks: spawning });
});

app.post('/api/daemon/update-status', (req, res) => {
  const { requestId, status } = req.body;
  const srv = activeServers.find(s => s.requestId === requestId);
  if (srv) {
    srv.status = status;
    console.log(`[Luani Web Backend] Daemon updated server ${requestId} status to: ${status}`);
    return res.json({ success: true });
  }
  res.status(404).json({ success: false, error: 'Server instance request not found.' });
});

app.listen(PORT, () => {
  console.log(`[Luani Web Backend] Running on http://localhost:${PORT} (Domain target: luani.fyi)`);
});
