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

// In-memory User accounts database (Username + Password only, no email)
const users = [
  { id: 'usr_01', username: 'Player_Local', password: 'password123', createdAt: new Date().toISOString() },
  { id: 'usr_02', username: 'LuauDeveloper', password: 'password123', createdAt: new Date().toISOString() },
  { id: 'usr_03', username: 'BuilderPro', password: 'password123', createdAt: new Date().toISOString() }
];

const sessions = new Map(); // token -> user profile

// Friends graph
const friends = [
  { id: 'usr_02', username: 'LuauDeveloper', status: 'ONLINE', game: 'Luani Starter World', serverIp: '127.0.0.1', serverPort: 7777 },
  { id: 'usr_03', username: 'BuilderPro', status: 'OFFLINE', game: null }
];

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
  },
  {
    id: 'place_demo_02',
    name: 'Speedway Track',
    creator: 'LuauDeveloper',
    description: 'High speed physics racing sandbox world.',
    maxPlayers: 8,
    version: 1,
    format_version: 1,
    parts: [
      {
        name: "Baseplate",
        primitive_type: 0,
        position: [0, -0.5, 0],
        rotation: [0, 0, 0],
        scale: [50, 0.5, 50],
        anchored: true,
        color: [0.15, 0.18, 0.2, 1.0]
      }
    ]
  }
];

// Active game servers list
const activeServers = [
  {
    requestId: 'req_system_main',
    name: 'Luani Main Official Server',
    placeId: 'place_default_01',
    serverIp: '127.0.0.1',
    serverPort: 7777,
    playerCount: 3,
    maxPlayers: 16,
    ping: 12,
    isUserHosted: false,
    status: 'RUNNING'
  },
  {
    requestId: 'req_user_hosted_01',
    name: 'BuilderPro\'s Local Server',
    placeId: 'place_demo_02',
    serverIp: '127.0.0.1',
    serverPort: 7788,
    playerCount: 1,
    maxPlayers: 8,
    ping: 25,
    isUserHosted: true,
    status: 'RUNNING'
  }
];

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

// --- API ROUTES ---

// Healthcheck
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'luani-web-backend', domain: 'luani.fyi', timestamp: new Date().toISOString() });
});

// AUTH SYSTEM (Username + Password only, no email)
app.post('/api/auth/register', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, error: 'Username and password are required.' });
  }

  const existing = users.find(u => u.username.toLowerCase() === username.trim().toLowerCase());
  if (existing) {
    return res.status(400).json({ success: false, error: 'Username is already taken.' });
  }

  const newUser = {
    id: `usr_${Date.now()}`,
    username: username.trim(),
    password: password,
    createdAt: new Date().toISOString()
  };

  users.push(newUser);
  const token = `luani_token_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  sessions.set(token, { id: newUser.id, username: newUser.username });

  console.log(`[Luani Auth] Registered user: ${newUser.username}`);
  res.json({ success: true, token, user: { id: newUser.id, username: newUser.username } });
});

app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, error: 'Username and password are required.' });
  }

  const user = users.find(u => u.username.toLowerCase() === username.trim().toLowerCase() && u.password === password);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Invalid username or password.' });
  }

  const token = `luani_token_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  sessions.set(token, { id: user.id, username: user.username });

  console.log(`[Luani Auth] Logged in user: ${user.username}`);
  res.json({ success: true, token, user: { id: user.id, username: user.username } });
});

app.get('/api/auth/me', (req, res) => {
  const authHeader = req.headers.authorization;
  const token = authHeader ? authHeader.replace('Bearer ', '') : req.query.token;

  if (token && sessions.has(token)) {
    return res.json({ success: true, user: sessions.get(token) });
  }
  res.status(401).json({ success: false, error: 'Not authenticated.' });
});

// FRIENDS SYSTEM
app.get('/api/friends', (req, res) => {
  res.json({ success: true, friends });
});

// GLOBAL SEARCH SYSTEM (Places + Users)
app.get('/api/search', (req, res) => {
  const query = (req.query.q || '').trim().toLowerCase();

  if (!query) {
    return res.json({ success: true, places: places.slice(0, 5), users: users.map(u => ({ id: u.id, username: u.username })) });
  }

  const matchedPlaces = places.filter(p => p.name.toLowerCase().includes(query) || p.creator.toLowerCase().includes(query) || p.description.toLowerCase().includes(query));
  const matchedUsers = users.filter(u => u.username.toLowerCase().includes(query)).map(u => ({ id: u.id, username: u.username }));

  res.json({ success: true, query, places: matchedPlaces, users: matchedUsers });
});

// ACTIVE MULTIPLAYER SERVERS LIST
app.get('/api/servers/active', (req, res) => {
  const running = activeServers.filter(s => s.status === 'RUNNING' || s.status === 'SPAWNING');
  res.json({ success: true, count: running.length, servers: running });
});

// Game / Place Listings
app.get('/api/places', (req, res) => {
  res.json({ success: true, count: places.length, places });
});

// Get Specific Place Data by ID
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

// Publish Place file from Luani Studio
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

// Request Server Spin-up (Ad-Gated Managed Server flow)
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
    name: `Managed Server (${placeId})`,
    placeId,
    serverIp: '127.0.0.1',
    serverPort: port,
    playerCount: 1,
    maxPlayers: 16,
    ping: 15,
    isUserHosted: false,
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

// Daemon Tunnel Signaling
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
